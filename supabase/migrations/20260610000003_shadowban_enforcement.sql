-- ============================================================
-- Migration: 20260610000003_shadowban_enforcement.sql
--
-- Adds is_shadowbanned to profiles and enforces it in:
--   - get_discovery_feed: shadowbanned profiles never appear in feeds
--   - get_likes_you: likes from shadowbanned users are hidden from the
--     target user
--   - handle_swipe_v2: a shadowbanned user's swipe is recorded normally
--     (so the profile doesn't keep resurfacing and wallet/limits behave
--     as usual), but it can never create a new match or trigger a
--     match notification for the other user
--
-- Existing matches/chats involving shadowbanned users are left
-- untouched.
-- ============================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_shadowbanned BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_profiles_is_shadowbanned
  ON public.profiles(is_shadowbanned)
  WHERE is_shadowbanned = true;

-- ============================================================
-- get_discovery_feed: hard-exclude shadowbanned profiles
-- ============================================================

DROP FUNCTION IF EXISTS public.get_discovery_feed(TEXT, TEXT, INTEGER);
CREATE OR REPLACE FUNCTION public.get_discovery_feed(
  p_user_id     TEXT,
  p_gender_pref TEXT,
  p_limit       INTEGER DEFAULT 40
)
RETURNS TABLE(profile_id TEXT, feed_priority INTEGER, is_super_like BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_my_rating     DOUBLE PRECISION;
  v_exclusion_ids TEXT[];
  v_used_ids      TEXT[];
  v_gender_filter TEXT;
  v_slot1_id      TEXT;
  v_slot2_ids     TEXT[];
  v_slot3_ids     TEXT[];
  v_slot4_ids     TEXT[];
  v_total_count   INTEGER;
BEGIN
  PERFORM public._apply_lazy_refill(p_user_id);

  SELECT COALESCE(glicko_rating, 1500.0)
  INTO v_my_rating
  FROM public.profiles
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    v_my_rating := 1500.0;
  END IF;

  -- Gender filter resolution
  v_gender_filter := CASE p_gender_pref
    WHEN 'Men'   THEN 'Man'
    WHEN 'Women' THEN 'Woman'
    ELSE NULL  -- 'Everyone' = no filter
  END;

  -- ── Build exclusion list ─────────────────────────────────────────────────
  SELECT ARRAY(
    SELECT DISTINCT t.uid FROM (
      -- All non-dislike swipes: permanent exclusions
      SELECT target_user_id AS uid
      FROM public.likes
      WHERE user_id = p_user_id AND type != 'dislike'

      UNION

      -- Dislikes within last 14 days only
      SELECT target_user_id AS uid
      FROM public.likes
      WHERE user_id    = p_user_id
        AND type       = 'dislike'
        AND created_at > now() - INTERVAL '14 days'

      UNION

      -- Already matched
      SELECT CASE WHEN user_a = p_user_id THEN user_b ELSE user_a END AS uid
      FROM public.matches
      WHERE user_a = p_user_id OR user_b = p_user_id

      UNION

      -- Blocked (bidirectional)
      SELECT CASE WHEN blocker_id = p_user_id THEN blocked_id ELSE blocker_id END AS uid
      FROM public.blocks
      WHERE blocker_id = p_user_id OR blocked_id = p_user_id

      UNION

      -- Shadowbanned users: never shown in anyone's feed
      SELECT id AS uid
      FROM public.profiles
      WHERE is_shadowbanned = true

      UNION

      SELECT p_user_id AS uid  -- exclude self
    ) t
    WHERE t.uid IS NOT NULL
  ) INTO v_exclusion_ids;

  v_used_ids := COALESCE(v_exclusion_ids, ARRAY[]::TEXT[]);

  -- ── SLOT 1 — Super-like / Pulse sender (priority 0) ──────────────────────
  SELECT l.user_id INTO v_slot1_id
  FROM public.likes l
  JOIN public.profiles p ON p.id = l.user_id
  WHERE l.target_user_id = p_user_id
    AND l.type IN ('super_like', 'pulse')
    AND l.user_id != ALL(v_used_ids)
    AND (v_gender_filter IS NULL OR p.gender = v_gender_filter)
    AND p.last_seen_at > now() - INTERVAL '7 days'
  ORDER BY l.created_at ASC
  LIMIT 1;

  IF v_slot1_id IS NOT NULL THEN
    v_used_ids := v_used_ids || ARRAY[v_slot1_id];
  END IF;

  -- ── SLOTS 2-3 — High-Probability (priority 1) ────────────────────────────
  -- Similar Glicko-2 rating (±200), premium-first, recency-sorted
  SELECT ARRAY(
    SELECT p.id
    FROM public.profiles p
    WHERE p.id != ALL(v_used_ids)
      AND (v_gender_filter IS NULL OR p.gender = v_gender_filter)
      AND p.last_seen_at > now() - INTERVAL '7 days'
      AND COALESCE(p.glicko_rating, 1500.0)
          BETWEEN v_my_rating - 200 AND v_my_rating + 200
    ORDER BY
      -- Premium boost
      COALESCE(p.is_premium = 'true', false) DESC,
      -- Profile completion penalty (soft: deprioritise, not hard-exclude)
      CASE WHEN COALESCE(p.profile_completion_percentage, 0) < 50 THEN 0 ELSE 1 END DESC,
      -- Ghost penalty: many matches, zero messages
      CASE WHEN COALESCE(p.total_matches, 0) > 10
                AND COALESCE(p.messages_sent, 0) = 0 THEN 0 ELSE 1 END DESC,
      COALESCE(p.glicko_rating, 1500.0) DESC,
      p.last_seen_at DESC
    LIMIT 2
  ) INTO v_slot2_ids;

  v_used_ids := v_used_ids || COALESCE(v_slot2_ids, ARRAY[]::TEXT[]);

  -- ── SLOTS 4-8 — Standard (priority 2) ────────────────────────────────────
  -- Broader pool, premium disproportionately represented via ORDER BY
  SELECT ARRAY(
    SELECT p.id
    FROM public.profiles p
    WHERE p.id != ALL(v_used_ids)
      AND (v_gender_filter IS NULL OR p.gender = v_gender_filter)
      AND p.last_seen_at > now() - INTERVAL '7 days'
    ORDER BY
      COALESCE(p.is_premium = 'true', false) DESC,
      CASE WHEN COALESCE(p.profile_completion_percentage, 0) < 50 THEN 0 ELSE 1 END DESC,
      CASE WHEN COALESCE(p.total_matches, 0) > 10
                AND COALESCE(p.messages_sent, 0) = 0 THEN 0 ELSE 1 END DESC,
      COALESCE(p.glicko_rating, 1500.0) DESC,
      p.last_seen_at DESC
    LIMIT 5
  ) INTO v_slot3_ids;

  v_used_ids := v_used_ids || COALESCE(v_slot3_ids, ARRAY[]::TEXT[]);

  -- ── SLOTS 9-10 — Wildcards (priority 3) ──────────────────────────────────
  -- New users (joined ≤30 days ago) OR rating outliers (> my_rating + 300)
  SELECT ARRAY(
    SELECT p.id
    FROM public.profiles p
    WHERE p.id != ALL(v_used_ids)
      AND (v_gender_filter IS NULL OR p.gender = v_gender_filter)
      AND (
        p.created_at > now() - INTERVAL '30 days'
        OR COALESCE(p.glicko_rating, 1500.0) > v_my_rating + 300
      )
    ORDER BY p.last_seen_at DESC
    LIMIT 2
  ) INTO v_slot4_ids;

  -- ── Empty-state / CURATING_BATCH check ───────────────────────────────────
  v_total_count :=
    COALESCE(array_length(v_slot2_ids, 1), 0) +
    COALESCE(array_length(v_slot3_ids, 1), 0) +
    COALESCE(array_length(v_slot4_ids, 1), 0) +
    CASE WHEN v_slot1_id IS NOT NULL THEN 1 ELSE 0 END;

  IF v_total_count < 3 THEN
    -- Sentinel row: tells Flutter to show "We're curating your introductions"
    RETURN QUERY SELECT NULL::TEXT, -1::INTEGER, false::BOOLEAN;
    RETURN;
  END IF;

  -- ── Emit in priority order ────────────────────────────────────────────────
  IF v_slot1_id IS NOT NULL THEN
    RETURN QUERY SELECT v_slot1_id::TEXT, 0::INTEGER, true::BOOLEAN;
  END IF;

  IF v_slot2_ids IS NOT NULL AND array_length(v_slot2_ids, 1) > 0 THEN
    RETURN QUERY
      SELECT unnest(v_slot2_ids)::TEXT, 1::INTEGER, false::BOOLEAN;
  END IF;

  IF v_slot3_ids IS NOT NULL AND array_length(v_slot3_ids, 1) > 0 THEN
    RETURN QUERY
      SELECT unnest(v_slot3_ids)::TEXT, 2::INTEGER, false::BOOLEAN;
  END IF;

  IF v_slot4_ids IS NOT NULL AND array_length(v_slot4_ids, 1) > 0 THEN
    RETURN QUERY
      SELECT unnest(v_slot4_ids)::TEXT, 3::INTEGER, false::BOOLEAN;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_discovery_feed(TEXT, TEXT, INTEGER) TO authenticated, anon;

-- ============================================================
-- get_likes_you: hide likes originating from shadowbanned users
-- ============================================================

DROP FUNCTION IF EXISTS public.get_likes_you(TEXT);
CREATE OR REPLACE FUNCTION public.get_likes_you(p_user_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row           RECORD;
  v_is_premium    BOOLEAN;
  v_blocked_ids   TEXT[];
  v_swiped_ids    TEXT[];
  v_profiles_json JSONB;
BEGIN
  SELECT is_premium, premium_expiry
  INTO v_row
  FROM public.profiles
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'is_premium', false, 'blur_photos', true, 'profiles', '[]'::JSONB
    );
  END IF;

  v_is_premium := COALESCE(v_row.is_premium = 'true', false)
                  AND (
                    v_row.premium_expiry IS NULL
                    OR v_row.premium_expiry = ''
                    OR v_row.premium_expiry::TIMESTAMPTZ > now()
                  );

  -- Blocked IDs (bidirectional)
  SELECT COALESCE(ARRAY(
    SELECT CASE WHEN blocker_id = p_user_id THEN blocked_id ELSE blocker_id END
    FROM public.blocks
    WHERE blocker_id = p_user_id OR blocked_id = p_user_id
  ), ARRAY[]::TEXT[])
  INTO v_blocked_ids;

  -- IDs I have already swiped on
  SELECT COALESCE(ARRAY(
    SELECT target_user_id FROM public.likes WHERE user_id = p_user_id
  ), ARRAY[]::TEXT[])
  INTO v_swiped_ids;

  -- Aggregate matching likes joined with profile_discovery for full data
  SELECT jsonb_agg(
    to_jsonb(pd) ||
    jsonb_build_object(
      'like_type',    l.type,
      'like_message', l.message
    )
    ORDER BY
      CASE WHEN l.type = 'pulse' THEN 0 ELSE 1 END ASC,
      l.created_at DESC
  )
  INTO v_profiles_json
  FROM public.likes l
  JOIN public.profile_discovery pd ON pd.id = l.user_id
  JOIN public.profiles liker ON liker.id = l.user_id
  WHERE l.target_user_id = p_user_id
    AND l.type IN ('like', 'super_like', 'pulse')
    AND l.user_id != ALL(v_swiped_ids)
    AND l.user_id != ALL(v_blocked_ids)
    AND liker.is_shadowbanned = false;

  RETURN jsonb_build_object(
    'is_premium',  v_is_premium,
    'blur_photos', NOT v_is_premium,
    'profiles',    COALESCE(v_profiles_json, '[]'::JSONB)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_likes_you(TEXT) TO authenticated, anon;

-- ============================================================
-- handle_swipe_v2: shadowbanned swiper's likes never create matches
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
  v_swiper_banned   BOOLEAN;
BEGIN
  PERFORM public._apply_lazy_refill(p_swiper_id);

  SELECT
    is_premium,
    premium_expiry,
    free_likes_used_today,
    free_super_likes_left,
    paid_super_likes,
    free_saves_left,
    paid_saves,
    is_shadowbanned
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

  v_swiper_banned := COALESCE(v_swiper.is_shadowbanned, false);

  -- Idempotency: if this exact swipe pair already exists, return silently
  IF EXISTS (
    SELECT 1 FROM public.likes
    WHERE user_id = p_swiper_id AND target_user_id = p_target_user_id
  ) THEN
    RETURN jsonb_build_object(
      'success', true, 'match', false, 'error', null, 'type', p_swipe_type
    );
  END IF;

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

    -- fall through to match check
  END IF;

  -- ── SUPER_LIKE / PULSE (Gem) ─────────────────────────────────────────────
  IF p_swipe_type IN ('super_like', 'pulse') THEN
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
  -- A shadowbanned swiper can never create a new match: their like is
  -- recorded above (so the profile won't resurface and wallet/limits behave
  -- normally), but no match row or notification is produced.
  IF v_swiper_banned THEN
    RETURN jsonb_build_object(
      'success', true, 'match', false, 'error', null, 'type', p_swipe_type
    );
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.likes
    WHERE user_id        = p_target_user_id
      AND target_user_id = p_swiper_id
      AND type IN ('like', 'super_like', 'pulse')
  ) INTO v_mutual;

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
