-- supabase/migrations/20260907000000_normalize_sub_interest_slugs.sql
--
-- The Flutter app used to write `user_sub_interests.sub_category` as the
-- `NewsSubCategory` Dart enum identifier (camelCase, e.g. `americanFootball`),
-- a hand-maintained list that never matched the canonical taxonomy slugs in
-- `taxonomy/taxonomy.json` that `articles.subcategories` is tagged from
-- (`american_football`). The feed's subcategory-boost (`subcategories && $n`)
-- therefore silently never matched for almost every row.
--
-- The client now reads/writes canonical L2 slugs (from the bundled taxonomy
-- asset) for both `user_sub_interests` (boost) and `user_muted_subcategories`
-- (hard filter). This migration brings existing `user_sub_interests` rows onto
-- the same vocabulary:
--   1. copy the unambiguous legacy values to their canonical slug
--   2. delete everything that is not a canonical slug (the legacy names just
--      copied, plus ~30 enum values that have no taxonomy equivalent)
--
-- Impact is minimal: the boost these rows fed has never functioned, and any
-- dropped selection re-materialises as the smart default (all subcategories of
-- an enabled category active) the next time the user opens Personalization.
--
-- `user_muted_subcategories` is left untouched — its values only ever came from
-- the "Not interested" mute sheet, which already passed canonical slugs.

BEGIN;

-- 1. Normalise legacy enum-name values to canonical taxonomy L2 slugs.
WITH mapping(old_value, new_slug) AS (
    VALUES
        ('elections', 'elections_voting'),
        ('policy', 'government_policy'),
        ('government', 'government_policy'),
        ('internationalRelations', 'international_relations'),
        ('lawJustice', 'law_justice'),
        ('military', 'military_defense'),
        ('diplomacy', 'international_relations'),
        ('cybersecurity', 'cybersecurity_privacy'),
        ('startups', 'startups_venture'),
        ('socialMedia', 'social_media'),
        ('software', 'software_platforms'),
        ('spaceTech', 'space_tech'),
        ('semiconductors', 'semiconductors_hardware'),
        ('space', 'space_astronomy'),
        ('physics', 'physics_quantum'),
        ('biology', 'biology_genetics'),
        ('archaeology', 'paleontology_archaeology'),
        ('psychology', 'neuroscience_psychology'),
        ('astronomy', 'space_astronomy'),
        ('genetics', 'biology_genetics'),
        ('neuroscience', 'neuroscience_psychology'),
        ('markets', 'markets_investing'),
        ('investing', 'markets_investing'),
        ('economy', 'economy_macro'),
        ('realEstate', 'real_estate'),
        ('retail', 'agriculture_retail'),
        ('laborJobs', 'trade_labor'),
        ('finance', 'corporate_finance'),
        ('football', 'football_soccer'),
        ('soccer', 'football_soccer'),
        ('americanFootball', 'american_football'),
        ('athletics', 'athletics_olympics'),
        ('olympics', 'athletics_olympics'),
        ('combatSports', 'combat_sports'),
        ('movies', 'film_movies'),
        ('tvStreaming', 'tv_streaming'),
        ('celebrity', 'celebrity_culture'),
        ('theater', 'theatre_arts'),
        ('mentalHealth', 'mental_health'),
        ('nutrition', 'nutrition_fitness'),
        ('fitness', 'nutrition_fitness'),
        ('medicalResearch', 'medical_research'),
        ('publicHealth', 'public_health_outbreaks'),
        ('longevity', 'maternal_child_health'),
        ('internationalTrade', 'trade_labor'),
        ('conflict', 'conflict_security'),
        ('climateChange', 'climate_change'),
        ('energy', 'energy_environment'),
        ('renewableEnergy', 'energy_environment'),
        ('conservation', 'conservation_wildlife'),
        ('wildlife', 'conservation_wildlife'),
        ('localGovernment', 'local_government')
        -- Already-canonical enum names (crypto, gaming, robotics, fintech,
        -- motorsport, basketball, tennis, cricket, anime, music, community,
        -- events, traffic) need no row here.
)
INSERT INTO user_sub_interests (user_id, sub_category)
SELECT DISTINCT usi.user_id, m.new_slug
FROM user_sub_interests usi
JOIN mapping m ON m.old_value = usi.sub_category
ON CONFLICT (user_id, sub_category) DO NOTHING;

-- 2. Drop every value that is not a canonical taxonomy slug. This removes the
--    legacy names just copied above and the enum values with no equivalent
--    (aiMl, gadgets, books, art, photography, wellness, parenting, biohacking,
--    africa, asia, europe, middleEast, humanitarianAid, globalSummits,
--    northAmerica, latinAmerica, oceania, naturalDisasters, sustainability, …).
DELETE FROM user_sub_interests
WHERE sub_category <> ALL (ARRAY[
    'elections_voting', 'national_politics', 'government_policy', 'international_relations',
    'law_justice', 'corruption_political_violence', 'military_defense', 'immigration',
    'civil_liberties_protests', 'artificial_intelligence',
    'artificial_intelligence.ai_research', 'artificial_intelligence.ai_policy_regulation',
    'artificial_intelligence.ai_safety_ethics', 'artificial_intelligence.ai_infrastructure',
    'artificial_intelligence.ai_industry_applications', 'gaming', 'gaming.core_gaming',
    'gaming.mobile_gaming', 'gaming.gaming_hardware', 'cybersecurity_privacy',
    'consumer_devices', 'software_platforms', 'social_media',
    'autonomous_electric_vehicles', 'space_tech', 'semiconductors_hardware', 'robotics',
    'crypto', 'startups_venture', 'space_astronomy',
    'space_astronomy.astronomy_observation', 'space_astronomy.spaceflight_launches',
    'space_astronomy.planetary_exploration', 'earth_geology', 'paleontology_archaeology',
    'physics_quantum', 'biology_genetics', 'neuroscience_psychology', 'markets_investing',
    'real_estate', 'urban_development', 'economy_macro', 'corporate_finance', 'fintech',
    'trade_labor', 'agriculture_retail', 'industry_transport', 'football_soccer',
    'football_soccer.transfers', 'football_soccer.top_leagues',
    'football_soccer.international_competitions', 'american_football', 'basketball',
    'baseball', 'tennis', 'golf', 'combat_sports', 'motorsport', 'cricket', 'rugby',
    'athletics_olympics', 'celebrity_culture', 'film_movies', 'tv_streaming', 'music',
    'anime', 'theatre_arts', 'fashion', 'awards_events', 'public_health_outbreaks',
    'medical_research', 'mental_health', 'nutrition_fitness', 'maternal_child_health',
    'healthcare_system_policy', 'crime_justice', 'conflict_security', 'accidents_disasters',
    'climate_change', 'weather_extreme', 'wildfires', 'conservation_wildlife',
    'sustainable_urban_living', 'energy_environment', 'community', 'events', 'traffic',
    'local_government'
]::text[]);

COMMIT;
