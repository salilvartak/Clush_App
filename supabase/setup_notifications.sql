-- 📋 CLUSH: UNIFIED NOTIFICATION STRATEGY
-- Execute this in your Supabase SQL Editor to link your DB events (likes, matches) 
-- to the new 'push-engine' Edge Function.

-- 1. EXTENSIONS (Ensure HTTP and Vault are enabled if needed)
-- CREATE EXTENSION IF NOT EXISTS "http";

-- 2. HELPER FUNCTION: call_push_engine
-- Replace 'YOUR_SERVICE_ROLE_KEY' with your actual key if needed, or it might be set via an environment variable.
-- Note: It is best practice to use a Secret for the auth header.

CREATE OR REPLACE FUNCTION public.notify_push_engine(
    target_id uuid,
    title text,
    body text,
    data jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    PERFORM
      net.http_post(
        url := 'https://roblwklgvyvjrgvyumqp.supabase.co/functions/v1/push-engine',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('vault.service_role_key', true)
        ),
        body := jsonb_build_object(
          'targetId', target_id,
          'title', title,
          'body', body,
          'data', data
        )
      );
END;
$$;

-- 3. TRIGGER FUNCTION: on_match_notify
CREATE OR REPLACE FUNCTION public.on_match_notify()
RETURNS TRIGGER AS $$
BEGIN
    -- Notify User A about the match
    PERFORM public.notify_push_engine(
        NEW.user_a,
        'It''s a Match! 🎉',
        'Check out your new match now!',
        jsonb_build_object('type', 'new_match', 'matchId', NEW.user_b)
    );
    
    -- Notify User B about the match
    PERFORM public.notify_push_engine(
        NEW.user_b,
        'It''s a Match! 🎉',
        'Check out your new match now!',
        jsonb_build_object('type', 'new_match', 'matchId', NEW.user_a)
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. TRIGGER FUNCTION: on_like_notify
CREATE OR REPLACE FUNCTION public.on_like_notify()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.type = 'like' OR NEW.type = 'super_like') THEN
        PERFORM public.notify_push_engine(
            NEW.target_user_id,
            CASE WHEN NEW.type = 'super_like' THEN 'Super Like! ⭐' ELSE 'New Like! ❤️' END,
            CASE WHEN NEW.type = 'super_like' THEN 'Someone gave you a Super Like!' ELSE 'Someone liked your profile!' END,
            jsonb_build_object('type', 'new_like', 'likerId', NEW.user_id)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. APPLY TRIGGERS
-- DROP TRIGGER IF EXISTS tr_match_notify ON public.matches;
CREATE TRIGGER tr_match_notify
    AFTER INSERT ON public.matches
    FOR EACH ROW
    EXECUTE FUNCTION public.on_match_notify();

-- DROP TRIGGER IF EXISTS tr_like_notify ON public.likes;
CREATE TRIGGER tr_like_notify
    AFTER INSERT ON public.likes
    FOR EACH ROW
    EXECUTE FUNCTION public.on_like_notify();
