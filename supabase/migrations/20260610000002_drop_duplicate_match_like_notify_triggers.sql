-- Remove legacy push-engine triggers that duplicate notifications already sent by
-- the dedicated match_notification and like_notification edge functions
-- (wired via database webhooks on public.matches / public.likes inserts).
-- Without this, users receive two "It's a Match!" / "New Like" notifications per event.

DROP TRIGGER IF EXISTS tr_match_notify ON public.matches;
DROP FUNCTION IF EXISTS public.on_match_notify();

DROP TRIGGER IF EXISTS tr_like_notify ON public.likes;
DROP FUNCTION IF EXISTS public.on_like_notify();
