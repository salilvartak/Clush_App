-- ============================================================
-- Fix likes_type_check constraint to allow 'save'
--
-- handle_swipe_v2 (see 20260601000001_matchmaking_rpcs.sql) inserts
-- rows into public.likes with type = 'save' when a profile is saved
-- for later, but the existing check constraint predates that RPC and
-- rejects 'save', causing:
--   PostgrestException: new row for relation "likes" violates check
--   constraint "likes_type_check" (code 23514)
--
-- Valid types in use across the matchmaking RPCs are:
--   'like', 'dislike', 'super_like', 'pulse', 'save'
-- ============================================================

ALTER TABLE public.likes
  DROP CONSTRAINT IF EXISTS likes_type_check;

ALTER TABLE public.likes
  ADD CONSTRAINT likes_type_check
  CHECK (type IN ('like', 'dislike', 'super_like', 'pulse', 'save'));
