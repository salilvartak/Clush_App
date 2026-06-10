-- 1. Recreate profile_discovery view omitting sensitive columns
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
  public_key,
  (verification_status = 'approved') AS verified,
  last_seen_at,
  custom_message
FROM public.profiles
WHERE is_paused IS DISTINCT FROM 'true'::text;

-- 2. Re-grant SELECT on the view to the roles that need it
GRANT SELECT ON public.profile_discovery TO authenticated, anon;
