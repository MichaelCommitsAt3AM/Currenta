-- supabase/migrations/20260402000000_selective_user_migration.sql

-- 1. Function to check personalization conflict
-- This helps fetch both guest and account data in a single call via SECURITY DEFINER
CREATE OR REPLACE FUNCTION check_personalization_conflict(guest_uid UUID, account_uid UUID)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
    guest_interests TEXT[];
    account_interests TEXT[];
    guest_country TEXT;
    account_country TEXT;
BEGIN
    -- Fetch Guest Data
    SELECT ARRAY_AGG(category) INTO guest_interests FROM user_interests WHERE user_id = guest_uid;
    SELECT preferred_country INTO guest_country FROM user_profiles WHERE user_id = guest_uid;

    -- Fetch Account Data
    SELECT ARRAY_AGG(category) INTO account_interests FROM user_interests WHERE user_id = account_uid;
    SELECT preferred_country INTO account_country FROM user_profiles WHERE user_id = account_uid;

    result = jsonb_build_object(
        'guest', jsonb_build_object(
            'interests', COALESCE(guest_interests, ARRAY[]::TEXT[]),
            'country', guest_country
        ),
        'account', jsonb_build_object(
            'interests', COALESCE(account_interests, ARRAY[]::TEXT[]),
            'country', account_country
        )
    );

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Function for selective migration
CREATE OR REPLACE FUNCTION selective_migrate_user_data(
    guest_uid UUID, 
    account_uid UUID, 
    use_guest_settings BOOLEAN
)
RETURNS VOID AS $$
BEGIN
    -- Always merge additive data (Views, Dislikes, Favorites)
    -- This ensures the user's history is preserved regardless of personalization choice.
    
    -- View History
    INSERT INTO article_views (user_id, article_id)
    SELECT account_uid, article_id FROM article_views WHERE user_id = guest_uid
    ON CONFLICT DO NOTHING;

    -- Dislikes
    INSERT INTO article_dislikes (user_id, article_id)
    SELECT account_uid, article_id FROM article_dislikes WHERE user_id = guest_uid
    ON CONFLICT DO NOTHING;

    -- Favorites
    INSERT INTO article_favorites (user_id, article_id)
    SELECT account_uid, article_id FROM article_favorites WHERE user_id = guest_uid
    ON CONFLICT DO NOTHING;

    -- Personalization Choice (Interests & Region)
    IF use_guest_settings THEN
        -- Overwrite Account settings with Guest settings
        
        -- Interests
        DELETE FROM user_interests WHERE user_id = account_uid;
        INSERT INTO user_interests (user_id, category)
        SELECT account_uid, category FROM user_interests WHERE user_id = guest_uid
        ON CONFLICT DO NOTHING;

        -- Sub-Interests
        DELETE FROM user_sub_interests WHERE user_id = account_uid;
        INSERT INTO user_sub_interests (user_id, sub_category)
        SELECT account_uid, sub_category FROM user_sub_interests WHERE user_id = guest_uid
        ON CONFLICT DO NOTHING;

        -- Profile (Region)
        UPDATE user_profiles 
        SET preferred_country = (SELECT preferred_country FROM user_profiles WHERE user_id = guest_uid),
            updated_at = now()
        WHERE user_id = account_uid;
    END IF;

    -- Cleanup Guest Data
    DELETE FROM user_interests WHERE user_id = guest_uid;
    DELETE FROM user_sub_interests WHERE user_id = guest_uid;
    DELETE FROM article_views WHERE user_id = guest_uid;
    DELETE FROM article_dislikes WHERE user_id = guest_uid;
    DELETE FROM article_favorites WHERE user_id = guest_uid;
    DELETE FROM user_profiles WHERE user_id = guest_uid;

EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Selective user data migration failed for guest_uid: % to account_uid: %. Error: %', guest_uid, account_uid, SQLERRM;
    RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
