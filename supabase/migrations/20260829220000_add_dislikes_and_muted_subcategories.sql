-- supabase/migrations/20260829220000_add_dislikes_and_muted_subcategories.sql
--
-- Backs the "Not interested" feature (article_dislikes already existed in
-- schema.sql — wired into migrate_user_data / selective_migrate_user_data /
-- account deletion — but nothing had ever written to it; feed.py now
-- excludes any article a user has explicitly disliked, permanently, unlike
-- the seen-filter which is TTL'd and only avoids repeats).
--
-- user_muted_subcategories is new here — an exact mirror of
-- user_sub_interests (same columns, RLS shape, index). A muted subcategory
-- is a personalization *choice*, not interaction history, so it's wired
-- into the guest<->account merge the same way sub_interests is: gated on
-- use_guest_settings in selective_migrate_user_data, NOT unconditionally
-- carried over like dislikes/views/favorites are.
--
-- Deliberately NOT touching update_user_interest_vector()'s embedding math
-- in this migration. The plan discussed adding a negative (dislike) pull
-- symmetric with the like-based pull, but pgvector has no normalize/divide
-- operator (confirmed in 20260824130000's notes), so doing that properly
-- means switching the whole function from "weighted average of likes" to
-- a weighted-sum steering vector + manual L2 renormalization — a bigger,
-- riskier rewrite of a function that's already had two production bugs
-- (20260824120000, 20260824130000). Shipping the exclusion (never show a
-- disliked article again) and the muted-subcategories feature now; the
-- vector-steering piece is better done as a follow-up once there's real
-- dislike data to sanity-check the math against, not guessed at tonight.

-- ── 1. user_muted_subcategories ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_muted_subcategories (
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sub_category TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, sub_category)
);

CREATE INDEX IF NOT EXISTS user_muted_subcategories_user_id_idx ON user_muted_subcategories (user_id);

ALTER TABLE user_muted_subcategories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own muted subcategories" ON user_muted_subcategories
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can view their own muted subcategories" ON user_muted_subcategories
    FOR SELECT USING (auth.uid() = user_id);

-- ── 2. Wire into account-linking migration (mirrors user_sub_interests) ───
-- Full CREATE OR REPLACE of migrate_user_data (schema.sql 4.4) — only the
-- Transfer Muted Subcategories block and its matching cleanup DELETE are
-- new, everything else reproduced verbatim so this stays a drop-in replace.
CREATE OR REPLACE FUNCTION migrate_user_data(old_uid uuid, new_uid uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    -- Transfer Interests
    INSERT INTO user_interests (user_id, category)
    SELECT new_uid, category FROM user_interests WHERE user_id = old_uid
    ON CONFLICT DO NOTHING;

    -- Transfer Sub-Interests
    INSERT INTO user_sub_interests (user_id, sub_category)
    SELECT new_uid, sub_category FROM user_sub_interests WHERE user_id = old_uid
    ON CONFLICT DO NOTHING;

    -- Transfer Muted Subcategories
    INSERT INTO user_muted_subcategories (user_id, sub_category)
    SELECT new_uid, sub_category FROM user_muted_subcategories WHERE user_id = old_uid
    ON CONFLICT DO NOTHING;

    -- Transfer View History
    INSERT INTO article_views (user_id, article_id)
    SELECT new_uid, article_id FROM article_views WHERE user_id = old_uid
    ON CONFLICT DO NOTHING;

    -- Transfer Dislikes
    INSERT INTO article_dislikes (user_id, article_id)
    SELECT new_uid, article_id FROM article_dislikes WHERE user_id = old_uid
    ON CONFLICT DO NOTHING;

    -- Transfer Favorites
    INSERT INTO article_favorites (user_id, article_id)
    SELECT new_uid, article_id FROM article_favorites WHERE user_id = old_uid
    ON CONFLICT DO NOTHING;

    -- Transfer Profile
    INSERT INTO user_profiles (user_id, preferred_country, updated_at)
    SELECT new_uid, preferred_country, updated_at FROM user_profiles WHERE user_id = old_uid
    ON CONFLICT (user_id) DO UPDATE
    SET preferred_country = EXCLUDED.preferred_country,
        updated_at = EXCLUDED.updated_at
    WHERE user_profiles.updated_at < EXCLUDED.updated_at;

    -- Cleanup old session
    DELETE FROM user_interests WHERE user_id = old_uid;
    DELETE FROM user_sub_interests WHERE user_id = old_uid;
    DELETE FROM user_muted_subcategories WHERE user_id = old_uid;
    DELETE FROM article_views WHERE user_id = old_uid;
    DELETE FROM article_dislikes WHERE user_id = old_uid;
    DELETE FROM article_favorites WHERE user_id = old_uid;
    DELETE FROM user_profiles WHERE user_id = old_uid;

EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'User data migration failed for old_uid: % to new_uid: %. Error: %', old_uid, new_uid, SQLERRM;
    RAISE;
END;
$$;

-- ── 3. Wire into selective guest<->account migration (the live path) ──────
-- Full CREATE OR REPLACE of selective_migrate_user_data
-- (20260402000000_selective_user_migration.sql) — only the Transfer Muted
-- Subcategories block (inside the use_guest_settings branch, alongside
-- Sub-Interests) and its matching cleanup DELETE are new.
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

        -- Muted Subcategories
        DELETE FROM user_muted_subcategories WHERE user_id = account_uid;
        INSERT INTO user_muted_subcategories (user_id, sub_category)
        SELECT account_uid, sub_category FROM user_muted_subcategories WHERE user_id = guest_uid
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
    DELETE FROM user_muted_subcategories WHERE user_id = guest_uid;
    DELETE FROM article_views WHERE user_id = guest_uid;
    DELETE FROM article_dislikes WHERE user_id = guest_uid;
    DELETE FROM article_favorites WHERE user_id = guest_uid;
    DELETE FROM user_profiles WHERE user_id = guest_uid;

EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Selective user data migration failed for guest_uid: % to account_uid: %. Error: %', guest_uid, account_uid, SQLERRM;
    RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
