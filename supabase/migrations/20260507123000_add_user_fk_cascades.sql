-- supabase/migrations/20260507123000_add_user_fk_cascades.sql
-- Ensure user-linked tables reference auth.users with ON DELETE CASCADE.
-- This prevents orphaned rows when users (including anonymous guests) are deleted.

-- 1) Cleanup orphaned rows (in case previous deletes removed auth.users)
DELETE FROM public.user_interests ui
WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = ui.user_id);

DELETE FROM public.user_sub_interests usi
WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = usi.user_id);

DELETE FROM public.article_views av
WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = av.user_id);

DELETE FROM public.article_dislikes ad
WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = ad.user_id);

DELETE FROM public.article_favorites af
WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = af.user_id);

DELETE FROM public.article_likes al
WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = al.user_id);

-- user_profiles may exist for guests/accounts
DELETE FROM public.user_profiles up
WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = up.user_id);

-- user_ai_usage may not exist in some environments; ignore if missing.
DO $$
BEGIN
  DELETE FROM public.user_ai_usage uau
  WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = uau.user_id);
EXCEPTION WHEN undefined_table THEN
  NULL;
END $$;


-- 2) Add FK constraints (idempotent via duplicate_object exception)
DO $$
BEGIN
  ALTER TABLE public.user_interests
    ADD CONSTRAINT user_interests_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.user_sub_interests
    ADD CONSTRAINT user_sub_interests_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.article_views
    ADD CONSTRAINT article_views_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.article_dislikes
    ADD CONSTRAINT article_dislikes_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.article_favorites
    ADD CONSTRAINT article_favorites_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.article_likes
    ADD CONSTRAINT article_likes_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.user_profiles
    ADD CONSTRAINT user_profiles_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.user_ai_usage
    ADD CONSTRAINT user_ai_usage_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
EXCEPTION 
  WHEN undefined_table THEN
    NULL;
  WHEN duplicate_object THEN
    NULL;
END $$;
