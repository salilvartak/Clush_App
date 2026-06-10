-- 1. Drop the profile_discovery view because it depends on is_verified
DROP VIEW IF EXISTS public.profile_discovery;

-- 2. Drop the boolean is_verified column
ALTER TABLE public.profiles DROP COLUMN IF EXISTS is_verified;

-- 3. Add verification_status and verification_score columns
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verification_status text DEFAULT 'pending';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verification_score integer DEFAULT 0;

-- 4. Recreate profile_discovery view with new columns
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
  verification_status,
  verification_score,
  is_paused,
  is_premium,
  public_key,
  (verification_status = 'approved') AS verified,
  last_seen_at,
  custom_message,
  glicko_rating,
  profile_completion_percentage,
  total_matches,
  messages_sent
FROM public.profiles
WHERE is_paused IS DISTINCT FROM 'true'::text;

-- 5. Re-grant SELECT on the view to the roles that need it
GRANT SELECT ON public.profile_discovery TO authenticated, anon;
