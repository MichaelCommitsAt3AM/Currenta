-- Function to delete anonymous users inactive for > 90 days.
-- Also schedules a daily cron job to run this cleanup.

CREATE OR REPLACE FUNCTION delete_inactive_guest_accounts()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    -- Delete anonymous users who haven't been active for 90 days.
    -- Criteria:
    -- 1. is_anonymous = true
    -- 2. last_sign_in_at < 90 days ago
    -- 3. No profile updates in last 90 days
    -- 4. No article views in last 90 days
    DELETE FROM auth.users
    WHERE is_anonymous = true
      AND (last_sign_in_at IS NULL OR last_sign_in_at < (now() - interval '90 days'))
      AND id NOT IN (
          SELECT user_id FROM public.user_profiles WHERE updated_at > (now() - interval '90 days')
          UNION
          SELECT user_id FROM public.article_views WHERE viewed_at > (now() - interval '90 days')
      );
END;
$$;

-- Schedule daily at 3:00 AM (server time)
-- Note: Requires pg_cron extension to be enabled in Supabase.
-- Using DO block to safely attempt scheduling if cron exists.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule(
            'delete-inactive-guest-accounts-daily',
            '0 3 * * *',
            'SELECT delete_inactive_guest_accounts();'
        );
    END IF;
END $$;
