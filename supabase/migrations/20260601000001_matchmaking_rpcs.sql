-- ============================================================
-- Migration: 20260601000001_matchmaking_rpcs.sql
--
-- Corrections applied from pre-flight schema inspection:
--   - profiles.id            → TEXT (no ::uuid casts needed)
--   - profiles.is_premium    → TEXT ('true'/'false', not boolean)
--   - profiles.premium_expiry → TEXT (cast to timestamptz for comparisons)
--   - likes.type             → uses 'dislike' (not 'pass')
--   - profile_discovery      → already has last_seen_at, created_at (skip those)
--   - profiles wallet cols   → already exist (free_likes_used_today etc.)
--   - glicko/behavioral cols → added by migration 000, present now
-- ============================================================

-- ============================================================
-- SECTION 1a: Performance indexes
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_likes_target_user_type
  ON public.likes(target_user_id, user_id, type);

CREATE INDEX IF NOT EXISTS idx_likes_user_created
  ON public.likes(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_profiles_last_seen
  ON public.profiles(last_seen_at DESC);

CREATE INDEX IF NOT EXISTS idx_profiles_glicko
  ON public.profiles(glicko_rating DESC);

-- ============================================================
-- SECTION 1b: Sync trigger — profiles → profile_discovery
-- Keeps the 4 new tracking columns in sync automatically.
-- ============================================================

CREATE OR REPLACE FUNCTION public._sync_profile_to_discovery()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profile_discovery
  SET
    glicko_rating                 = NEW.glicko_rating,
    profile_completion_percentage = NEW.profile_completion_percentage,
    total_matches                 = NEW.total_matches,
    messages_sent                 = NEW.messages_sent,
    last_seen_at                  = NEW.last_seen_at
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_sync_profile_to_discovery ON public.profiles;
CREATE TRIGGER tr_sync_profile_to_discovery
  AFTER UPDATE OF
    glicko_rating,
    profile_completion_percentage,
    total_matches,
    messages_sent,
    last_seen_at
  ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public._sync_profile_to_discovery();

-- ============================================================
-- SECTION 1c: messages_sent counter trigger
-- ============================================================

CREATE OR REPLACE FUNCTION public._increment_messages_sent()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET messages_sent = messages_sent + 1
  WHERE id = NEW.sender;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_increment_messages_sent ON public.messages;
CREATE TRIGGER tr_increment_messages_sent
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public._increment_messages_sent();

-- ============================================================
-- SECTION 2: Helper — _apply_lazy_refill(p_user_id text)
-- Private: NOT granted to anon/authenticated.
--
-- IMPORTANT: is_premium is TEXT ('true'/'false') in this schema.
-- premium_expiry is TEXT — cast to timestamptz for comparisons.
-- All time arithmetic uses Asia/Kolkata (IST).
-- ============================================================

CREATE OR REPLACE FUNCTION public._apply_lazy_refill(p_user_id TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile            RECORD;
  v_now_ist            TIMESTAMP;
  v_today_4am_ist      TIMESTAMP;
  v_last_friday_3am    TIMESTAMP;
  v_dow                INTEGER;
  v_days_since_friday  INTEGER;
  v_is_premium         BOOLEAN;
BEGIN
  SELECT
    is_premium,
    premium_expiry,
    free_likes_used_today,
    last_daily_reset_time,
    last_weekly_reset_time
  INTO v_profile
  FROM public.profiles
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Effective premium: is_premium text = 'true' AND expiry not passed
  v_is_premium := COALESCE(v_profile.is_premium = 'true', false)
                  AND (
                    v_profile.premium_expiry IS NULL
                    OR v_profile.premium_expiry = ''
                    OR v_profile.premium_expiry::TIMESTAMPTZ > now()
                  );

  v_now_ist       := now() AT TIME ZONE 'Asia/Kolkata';
  v_today_4am_ist := date_trunc('day', v_now_ist) + INTERVAL '4 hours';

  -- ── Daily reset: after 4:00 AM IST, if not yet reset today ──────────────
  IF v_now_ist >= v_today_4am_ist
     AND (v_profile.last_daily_reset_time AT TIME ZONE 'Asia/Kolkata') < v_today_4am_ist
  THEN
    UPDATE public.profiles
    SET
      free_likes_used_today = 0,
      last_daily_reset_time = now()
    WHERE id = p_user_id;
  END IF;

  -- ── Weekly reset: every Friday at 03:00 AM IST ───────────────────────────
  v_dow               := EXTRACT(DOW FROM v_now_ist)::INTEGER; -- 0=Sun…5=Fri…6=Sat
  v_days_since_friday := MOD(v_dow - 5 + 7, 7);

  v_last_friday_3am := date_trunc('day', v_now_ist)
                       - (v_days_since_friday || ' days')::INTERVAL
                       + INTERVAL '3 hours';

  -- If today IS Friday but before 03:00, roll back to the previous Friday
  IF v_now_ist < v_last_friday_3am THEN
    v_last_friday_3am := v_last_friday_3am - INTERVAL '7 days';
  END IF;

  IF v_last_friday_3am > (v_profile.last_weekly_reset_time AT TIME ZONE 'Asia/Kolkata') THEN
    UPDATE public.profiles
    SET
      free_likes_used_today  = 0,
      free_saves_left        = 2,
      free_rewinds_left      = 2,
      -- CAP to exact value — never add on top; never touch paid inventory
      free_super_likes_left  = CASE WHEN v_is_premium THEN 3 ELSE 1 END,
      last_weekly_reset_time = now()
    WHERE id = p_user_id;
  END IF;
END;
$$;

-- ============================================================
-- SECTION 3: Helper — _apply_glicko2_match(a text, b text)
-- Private: NOT granted to anon/authenticated.
-- Both users are treated as winners (mutual match = outcome 1.0).
-- ============================================================

CREATE OR REPLACE FUNCTION public._apply_glicko2_match(p_user_a TEXT, p_user_b TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_a            RECORD;
  v_b            RECORD;
  v_q            DOUBLE PRECISION := ln(10.0) / 400.0;
  v_g_b          DOUBLE PRECISION;
  v_g_a          DOUBLE PRECISION;
  v_E_a          DOUBLE PRECISION;
  v_E_b          DOUBLE PRECISION;
  v_d2_a         DOUBLE PRECISION;
  v_d2_b         DOUBLE PRECISION;
  v_new_rating_a DOUBLE PRECISION;
  v_new_rating_b DOUBLE PRECISION;
  v_new_rd_a     DOUBLE PRECISION;
  v_new_rd_b     DOUBLE PRECISION;
BEGIN
  SELECT glicko_rating, glicko_rd
  INTO v_a
  FROM public.profiles
  WHERE id = p_user_a
  FOR UPDATE;

  SELECT glicko_rating, glicko_rd
  INTO v_b
  FROM public.profiles
  WHERE id = p_user_b
  FOR UPDATE;

  IF v_a IS NULL OR v_b IS NULL THEN
    RETURN;
  END IF;

  -- g(RD) = 1 / sqrt(1 + 3·q²·RD² / π²)
  v_g_b := 1.0 / sqrt(1.0 + 3.0 * v_q^2 * v_b.glicko_rd^2 / (pi()^2));
  v_g_a := 1.0 / sqrt(1.0 + 3.0 * v_q^2 * v_a.glicko_rd^2 / (pi()^2));

  -- E = 1 / (1 + 10^(−g_j·(r − r_j)/400))
  v_E_a := 1.0 / (1.0 + power(10.0, -v_g_b * (v_a.glicko_rating - v_b.glicko_rating) / 400.0));
  v_E_b := 1.0 / (1.0 + power(10.0, -v_g_a * (v_b.glicko_rating - v_a.glicko_rating) / 400.0));

  -- d² = 1 / (q²·g_j²·E·(1−E))
  v_d2_a := 1.0 / (v_q^2 * v_g_b^2 * v_E_a * (1.0 - v_E_a));
  v_d2_b := 1.0 / (v_q^2 * v_g_a^2 * v_E_b * (1.0 - v_E_b));

  -- new_rating = r + (q / (1/RD² + 1/d²)) · g_j · (s − E),  s=1.0
  v_new_rating_a := v_a.glicko_rating
                    + (v_q / (1.0/v_a.glicko_rd^2 + 1.0/v_d2_a))
                    * v_g_b * (1.0 - v_E_a);
  v_new_rating_b := v_b.glicko_rating
                    + (v_q / (1.0/v_b.glicko_rd^2 + 1.0/v_d2_b))
                    * v_g_a * (1.0 - v_E_b);

  -- new_RD = sqrt(1 / (1/RD² + 1/d²)), clamped to [30, 350]
  v_new_rd_a := GREATEST(30.0, LEAST(350.0,
                  sqrt(1.0 / (1.0/v_a.glicko_rd^2 + 1.0/v_d2_a))));
  v_new_rd_b := GREATEST(30.0, LEAST(350.0,
                  sqrt(1.0 / (1.0/v_b.glicko_rd^2 + 1.0/v_d2_b))));

  UPDATE public.profiles
  SET glicko_rating = v_new_rating_a, glicko_rd = v_new_rd_a
  WHERE id = p_user_a;

  UPDATE public.profiles
  SET glicko_rating = v_new_rating_b, glicko_rd = v_new_rd_b
  WHERE id = p_user_b;
END;
$$;

-- ============================================================
-- SECTION 4: RPC — get_user_wallet
-- ============================================================

DROP FUNCTION IF EXISTS public.get_user_wallet(TEXT);
CREATE OR REPLACE FUNCTION public.get_user_wallet(p_user_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row                   RECORD;
  v_is_premium            BOOLEAN;
  v_daily_limit           INTEGER;
  v_likes_remaining       INTEGER;
  v_super_likes_remaining INTEGER;
  v_rewinds_remaining     INTEGER;
  v_saves_remaining       INTEGER;
BEGIN
  PERFORM public._apply_lazy_refill(p_user_id);

  SELECT
    is_premium,
    premium_expiry,
    free_likes_used_today,
    free_saves_left,
    free_rewinds_left,
    free_super_likes_left,
    paid_saves,
    paid_rewinds,
    paid_super_likes
  INTO v_row
  FROM public.profiles
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'likes_remaining',         6,
      'super_likes_remaining',   1,
      'rewinds_remaining',       2,
      'profile_saves_remaining', 2,
      'is_premium',              false
    );
  END IF;

  -- is_premium is TEXT: NULL-safe cast to boolean
  v_is_premium := COALESCE(v_row.is_premium = 'true', false)
                  AND (
                    v_row.premium_expiry IS NULL
                    OR v_row.premium_expiry = ''
                    OR v_row.premium_expiry::TIMESTAMPTZ > now()
                  );

  v_daily_limit           := CASE WHEN v_is_premium THEN 20 ELSE 6 END;
  v_likes_remaining       := GREATEST(0, v_daily_limit - v_row.free_likes_used_today);
  v_super_likes_remaining := COALESCE(v_row.free_super_likes_left, 0)
                             + COALESCE(v_row.paid_super_likes, 0);
  v_rewinds_remaining     := COALESCE(v_row.free_rewinds_left, 0)
                             + COALESCE(v_row.paid_rewinds, 0);
  v_saves_remaining       := COALESCE(v_row.free_saves_left, 0)
                             + COALESCE(v_row.paid_saves, 0);

  RETURN jsonb_build_object(
    'likes_remaining',         v_likes_remaining,
    'super_likes_remaining',   v_super_likes_remaining,
    'rewinds_remaining',       v_rewinds_remaining,
    'profile_saves_remaining', v_saves_remaining,
    'is_premium',              v_is_premium
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_wallet(TEXT) TO authenticated, anon;

-- ============================================================
-- SECTION 5: RPC — handle_swipe_v2
--
-- Swipe types: 'like', 'dislike', 'super_like', 'pulse', 'save'
-- NOTE: 'dislike' is the correct type (not 'pass') per schema inspection.
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

-- ============================================================
-- SECTION 6: RPC — undo_swipe_v2
-- Rewinds the most recent 'dislike' for the given pair.
-- Deducts one rewind credit (free first, then paid).
-- ============================================================

DROP FUNCTION IF EXISTS public.undo_swipe_v2(TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.undo_swipe_v2(p_user_id TEXT, p_target_user_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet     RECORD;
  v_deleted_id TEXT;
BEGIN
  PERFORM public._apply_lazy_refill(p_user_id);

  SELECT free_rewinds_left, paid_rewinds
  INTO v_wallet
  FROM public.profiles
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'user_not_found');
  END IF;

  IF COALESCE(v_wallet.free_rewinds_left, 0) = 0
     AND COALESCE(v_wallet.paid_rewinds, 0) = 0
  THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_rewinds');
  END IF;

  -- Delete the most recent 'dislike' for this pair
  DELETE FROM public.likes
  WHERE id = (
    SELECT id FROM public.likes
    WHERE user_id        = p_user_id
      AND target_user_id = p_target_user_id
      AND type           = 'dislike'
    ORDER BY created_at DESC
    LIMIT 1
  )
  RETURNING id::TEXT INTO v_deleted_id;

  IF v_deleted_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_found');
  END IF;

  -- Deduct rewind credit: free first, then paid
  IF COALESCE(v_wallet.free_rewinds_left, 0) > 0 THEN
    UPDATE public.profiles
    SET free_rewinds_left = free_rewinds_left - 1
    WHERE id = p_user_id;
  ELSE
    UPDATE public.profiles
    SET paid_rewinds = paid_rewinds - 1
    WHERE id = p_user_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'error', null);
END;
$$;

GRANT EXECUTE ON FUNCTION public.undo_swipe_v2(TEXT, TEXT) TO authenticated, anon;

-- ============================================================
-- SECTION 7: RPC — get_discovery_feed
--
-- Returns up to 10 curated profiles per batch.
-- Sentinel row (NULL, -1, false) = CURATING_BATCH signal.
--
-- Exclusion rules:
--   - All non-dislike swipes: permanent
--   - Dislikes within last 14 days only (older ones can resurface)
--   - Matched users
--   - Blocked users (bidirectional)
--   - Self
--   - Inactive > 7 days (recency bias)
--
-- 10-profile batch slots:
--   Slot 1    (priority 0): 1 oldest super_like/pulse sender
--   Slots 2-3 (priority 1): 2 high-probability (similar Glicko ±200)
--   Slots 4-8 (priority 2): 5 standard (premium-boosted, sorted by rating)
--   Slots 9-10(priority 3): 2 wildcards (new users or high-rating outliers)
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
-- SECTION 8: RPC — get_likes_you
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
  WHERE l.target_user_id = p_user_id
    AND l.type IN ('like', 'super_like', 'pulse')
    AND l.user_id != ALL(v_swiped_ids)
    AND l.user_id != ALL(v_blocked_ids);

  RETURN jsonb_build_object(
    'is_premium',  v_is_premium,
    'blur_photos', NOT v_is_premium,
    'profiles',    COALESCE(v_profiles_json, '[]'::JSONB)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_likes_you(TEXT) TO authenticated, anon;

-- ============================================================
-- SECTION 9: RPC — get_blocked_ids_by_phone
-- ============================================================

DROP FUNCTION IF EXISTS public.get_blocked_ids_by_phone(TEXT[]);
CREATE OR REPLACE FUNCTION public.get_blocked_ids_by_phone(phones TEXT[])
RETURNS TABLE(id TEXT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.id::TEXT
  FROM public.profiles p
  WHERE p.phone = ANY(phones)
    AND p.id IS NOT NULL;
$$;

GRANT EXECUTE ON FUNCTION public.get_blocked_ids_by_phone(TEXT[]) TO authenticated, anon;

-- ============================================================
-- SECTION 10: RPC — unmatch_user_v2
-- ============================================================

DROP FUNCTION IF EXISTS public.unmatch_user_v2(TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.unmatch_user_v2(p_user_id TEXT, p_target_user_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.matches
  WHERE (user_a = p_user_id      AND user_b = p_target_user_id)
     OR (user_a = p_target_user_id AND user_b = p_user_id);

  -- Log the unmatch action (action_log columns: user_id, target_user_id, type, created_at)
  INSERT INTO public.action_log(user_id, target_user_id, type, created_at)
  VALUES(p_user_id, p_target_user_id, 'unmatch', now());

  RETURN '{"success":true}'::JSONB;
END;
$$;

GRANT EXECUTE ON FUNCTION public.unmatch_user_v2(TEXT, TEXT) TO authenticated, anon;
