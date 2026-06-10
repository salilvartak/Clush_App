-- profile_discovery is a plain view (SELECT ... FROM public.profiles WHERE
-- is_paused IS DISTINCT FROM 'true') so it always reflects profiles directly
-- and needs no sync trigger. The trigger also referenced columns
-- (glicko_rating, profile_completion_percentage, total_matches,
-- messages_sent) that 20260609000000_fix_discovery_privacy.sql removed from
-- the view, causing every UPDATE of those columns on `profiles` — e.g. the
-- total_matches bump in handle_swipe_v2 — to fail with
-- "column glicko_rating of relation profile_discovery does not exist" and
-- roll back the whole transaction (no like row, no match row created).

DROP TRIGGER IF EXISTS tr_sync_profile_to_discovery ON public.profiles;
DROP FUNCTION IF EXISTS public._sync_profile_to_discovery();
