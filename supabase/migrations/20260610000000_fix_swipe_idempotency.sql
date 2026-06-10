-- ============================================================
-- RPC: handle_swipe_v2 (fix)
-- The previous idempotency check short-circuited on ANY prior swipe row
-- between swiper and target (e.g. an old 'dislike'), returning match:false
-- without ever checking mutuality or creating a match — even when the
-- target had already liked the swiper. Now:
--   - A duplicate of the SAME swipe type is still a no-op (true idempotency).
--   - A prior 'dislike' (or other type) is replaced when the user changes
--     their mind (e.g. dislike -> like), and the normal flow + match check
--     proceeds.
-- ============================================================

DROP FUNCTION IF EXISTS public.handle_swipe_v2(TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.handle_swipe_v2(
  p_swiper_id      TEXT,
  p_target_user_id TEXT,
  p_swipe_type     TEXT,
  p_message        TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_swiper          RECORD;
  v_is_premium      BOOLEAN;
  v_daily_limit     INTEGER;
  v_mutual          BOOLEAN;
  v_already_matched BOOLEAN;
  v_target_swipe    TEXT;
  v_existing_type   TEXT;
BEGIN
  PERFORM public._apply_lazy_refill(p_swiper_id);

  SELECT
    is_premium,
    premium_expiry,
    free_likes_used_today,
    free_super_likes_left,
    paid_super_likes,
    free_saves_left,
    paid_saves
  INTO v_swiper
  FROM public.profiles
  WHERE id = p_swiper_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false, 'match', false,
      'error', 'user_not_found', 'type', p_swipe_type
    );
  END IF;

  -- Check for an existing swipe from this user toward this target
  SELECT type INTO v_existing_type
  FROM public.likes
  WHERE user_id = p_swiper_id AND target_user_id = p_target_user_id;

  -- True idempotency: an identical swipe already exists, return silently
  IF v_existing_type = p_swipe_type THEN
    RETURN jsonb_build_object(
      'success', true, 'match', false, 'error', null, 'type', p_swipe_type
    );
  END IF;

  -- The user changed their mind (e.g. previously disliked, now liking) —
  -- drop the old swipe row so the normal flow below can re-insert it.
  IF v_existing_type IS NOT NULL THEN
    DELETE FROM public.likes
    WHERE user_id = p_swiper_id AND target_user_id = p_target_user_id;
  END IF;

  -- Pre-check if target has already liked us (any right swipe)
  SELECT type INTO v_target_swipe
  FROM public.likes
  WHERE user_id = p_target_user_id
    AND target_user_id = p_swiper_id
    AND type IN ('like', 'super_like', 'pulse')
  ORDER BY created_at DESC
  LIMIT 1;

  v_mutual := v_target_swipe IS NOT NULL;

  -- ── DISLIKE ──────────────────────────────────────────────────────────────
  IF p_swipe_type = 'dislike' THEN
    INSERT INTO public.likes(user_id, target_user_id, type, created_at)
    VALUES(p_swiper_id, p_target_user_id, 'dislike', now());

    UPDATE public.profiles
    SET lifetime_swipes = COALESCE(lifetime_swipes, 0) + 1
    WHERE id = p_swiper_id;

    RETURN jsonb_build_object(
      'success', true, 'match', false, 'error', null, 'type', 'dislike'
    );
  END IF;

  -- ── LIKE ─────────────────────────────────────────────────────────────────
  IF p_swipe_type = 'like' THEN
    v_is_premium  := COALESCE(v_swiper.is_premium = 'true', false)
                     AND (
                       v_swiper.premium_expiry IS NULL
                       OR v_swiper.premium_expiry = ''
                       OR v_swiper.premium_expiry::TIMESTAMPTZ > now()
                     );
    v_daily_limit := CASE WHEN v_is_premium THEN 20 ELSE 6 END;

    IF v_mutual THEN
      -- Target already liked us, waive the daily limit cost!
      INSERT INTO public.likes(user_id, target_user_id, type, created_at)
      VALUES(p_swiper_id, p_target_user_id, 'like', now());

      UPDATE public.profiles
      SET
        lifetime_swipes = COALESCE(lifetime_swipes, 0) + 1,
        right_swipes    = COALESCE(right_swipes, 0) + 1
      WHERE id = p_swiper_id;
    ELSE
      -- Normal flow, check limit and charge a like
      IF COALESCE(v_swiper.free_likes_used_today, 0) >= v_daily_limit THEN
        RETURN jsonb_build_object(
          'success', false, 'match', false, 'error', 'daily_limit', 'type', 'like'
        );
      END IF;

      INSERT INTO public.likes(user_id, target_user_id, type, created_at)
      VALUES(p_swiper_id, p_target_user_id, 'like', now());

      UPDATE public.profiles
      SET
        free_likes_used_today = COALESCE(free_likes_used_today, 0) + 1,
        lifetime_swipes       = COALESCE(lifetime_swipes, 0) + 1,
        right_swipes          = COALESCE(right_swipes, 0) + 1
      WHERE id = p_swiper_id;
    END IF;

    -- fall through to match check
  END IF;

  -- ── SUPER_LIKE / PULSE (Gem) ─────────────────────────────────────────────
  IF p_swipe_type IN ('super_like', 'pulse') THEN
    IF v_mutual THEN
      -- Target already liked us, waive the super_like cost!
      INSERT INTO public.likes(user_id, target_user_id, type, message, created_at)
      VALUES(p_swiper_id, p_target_user_id, p_swipe_type, p_message, now());

      UPDATE public.profiles
      SET
        lifetime_swipes = COALESCE(lifetime_swipes, 0) + 1,
        right_swipes    = COALESCE(right_swipes, 0) + 1
      WHERE id = p_swiper_id;
    ELSE
      IF COALESCE(v_swiper.free_super_likes_left, 0) > 0 THEN
        UPDATE public.profiles
        SET free_super_likes_left = free_super_likes_left - 1
        WHERE id = p_swiper_id;
      ELSIF COALESCE(v_swiper.paid_super_likes, 0) > 0 THEN
        UPDATE public.profiles
        SET paid_super_likes = paid_super_likes - 1
        WHERE id = p_swiper_id;
      ELSE
        RETURN jsonb_build_object(
          'success', false, 'match', false, 'error', 'exhausted', 'type', 'super_like'
        );
      END IF;

      INSERT INTO public.likes(user_id, target_user_id, type, message, created_at)
      VALUES(p_swiper_id, p_target_user_id, p_swipe_type, p_message, now());

      UPDATE public.profiles
      SET
        lifetime_swipes = COALESCE(lifetime_swipes, 0) + 1,
        right_swipes    = COALESCE(right_swipes, 0) + 1
      WHERE id = p_swiper_id;
    END IF;

    -- fall through to match check
  END IF;

  -- ── SAVE ─────────────────────────────────────────────────────────────────
  IF p_swipe_type = 'save' THEN
    IF COALESCE(v_swiper.free_saves_left, 0) > 0 THEN
      UPDATE public.profiles
      SET free_saves_left = free_saves_left - 1
      WHERE id = p_swiper_id;
    ELSIF COALESCE(v_swiper.paid_saves, 0) > 0 THEN
      UPDATE public.profiles
      SET paid_saves = paid_saves - 1
      WHERE id = p_swiper_id;
    ELSE
      RETURN jsonb_build_object(
        'success', false, 'match', false, 'error', 'exhausted', 'type', 'save'
      );
    END IF;

    INSERT INTO public.likes(user_id, target_user_id, type, message, created_at)
    VALUES(p_swiper_id, p_target_user_id, 'save', p_message, now());

    INSERT INTO public.saved_profiles(user_id, saved_user_id, created_at)
    VALUES(p_swiper_id, p_target_user_id, now())
    ON CONFLICT DO NOTHING;

    RETURN jsonb_build_object(
      'success', true, 'match', false, 'error', null, 'type', 'save'
    );
  END IF;

  -- ── MATCH CHECK (like / super_like / pulse only) ──────────────────────────
  -- v_mutual is already computed above
  IF v_mutual THEN
    SELECT EXISTS(
      SELECT 1 FROM public.matches
      WHERE (user_a = p_swiper_id      AND user_b = p_target_user_id)
         OR (user_a = p_target_user_id AND user_b = p_swiper_id)
    ) INTO v_already_matched;

    IF NOT v_already_matched THEN
      INSERT INTO public.matches(user_a, user_b, created_at)
      VALUES(p_swiper_id, p_target_user_id, now());

      UPDATE public.profiles
      SET total_matches = COALESCE(total_matches, 0) + 1
      WHERE id IN (p_swiper_id, p_target_user_id);

      PERFORM public._apply_glicko2_match(p_swiper_id, p_target_user_id);
    END IF;

    RETURN jsonb_build_object(
      'success', true, 'match', true, 'error', null, 'type', p_swipe_type
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true, 'match', false, 'error', null, 'type', p_swipe_type
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.handle_swipe_v2(TEXT, TEXT, TEXT, TEXT) TO authenticated, anon;
