-- ============================================================
-- Migration: 20260601000000_matchmaking_schema.sql
-- Safe to re-run (all statements are idempotent).
-- ============================================================

-- 1. Drop the view that depends on elo_score so we can remove the column
DROP VIEW IF EXISTS public.profile_discovery;

-- 2. Drop legacy Elo score column
ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS elo_score;

-- 3. Add Glicko-2 Rating columns
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS glicko_rating     DOUBLE PRECISION DEFAULT 1500,
  ADD COLUMN IF NOT EXISTS glicko_rd         DOUBLE PRECISION DEFAULT 350,
  ADD COLUMN IF NOT EXISTS glicko_volatility DOUBLE PRECISION DEFAULT 0.06;

-- 4. Add Behavioral Tracking columns
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS lifetime_swipes               INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS right_swipes                  INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS messages_sent                 INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_matches                 INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS profile_completion_percentage INTEGER DEFAULT 0;

-- 5. Recreate profile_discovery view
--    - Removed: elo_score (replaced by Glicko-2)
--    - Added:   glicko_rating, profile_completion_percentage,
--               total_matches, messages_sent
--    - All other columns preserved exactly as before.
CREATE OR REPLACE VIEW public.profile_discovery AS
SELECT
  id,
  full_name,
  birthday,
  gender,
  intent,
  interests,
  foods,
  places,
  photo_urls,
  prompts,
  created_at,
  sexual_orientation,
  pronouns,
  ethnicity,
  height,
  religion,
  education,
  job_title,
  languages,
  political_views,
  kids,
  star_sign,
  pets,
  drink,
  smoke,
  weed,
  location,
  exercise,
  is_verified,
  is_paused,
  is_premium,
  public_key,
  is_verified AS verified,
  last_seen_at,
  custom_message,
  -- New columns replacing elo_score
  glicko_rating,
  profile_completion_percentage,
  total_matches,
  messages_sent
FROM public.profiles
WHERE is_paused IS DISTINCT FROM 'true'::text;

-- 6. Re-grant SELECT on the view to the roles that need it
GRANT SELECT ON public.profile_discovery TO authenticated, anon;

-- NOTE: Wallet columns (free_likes_used_today, free_saves_left, free_rewinds_left,
-- free_super_likes_left, paid_saves, paid_rewinds, paid_super_likes,
-- last_daily_reset_time, last_weekly_reset_time) already exist — no changes needed.
