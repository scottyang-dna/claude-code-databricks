-- Final Social Media Synthetic Data Generation
-- Using the range function which we know works

-- First, clear existing tables
DROP TABLE IF EXISTS main.social_media_sample.users;
DROP TABLE IF EXISTS main.social_media_sample.posts;
DROP TABLE IF EXISTS main.social_media_sample.follows;

-- Create users table with 500K records
CREATE TABLE main.social_media_sample.users
USING DELTA
AS
SELECT
    (id + 1) as user_id,
    -- Generate username
    LOWER(CONCAT(
        SUBSTRING(CAST(((id + 1) * 123457) AS STRING), 1, 3),
        '_',
        SUBSTRING(CAST(((id + 1) * 890123) AS STRING), 1, 5),
        CASE WHEN (((id + 1) * 777) % 10) < 3 THEN CAST((((id + 1) * 13) % 90) + 10 AS STRING) ELSE '' END
    )) as username,
    -- Role distribution: 80% regular, 15% creator, 5% influencer
    CASE
        WHEN (((id + 1) * 17) % 100) < 80 THEN 'regular_user'
        WHEN (((id + 1) * 17) % 100) < 95 THEN 'content_creator'
        ELSE 'influencer'
    END as role,
    -- Timestamp with viral growth pattern
    TIMESTAMPADD(
        DAY,
        CASE
            WHEN (((id + 1) * 19) % 100) < 50 THEN  -- 50% baseline
                CASE WHEN (((id + 1) * 23) % 100) < 60 THEN (((id + 1) * 7) % 60) ELSE 105 + (((id + 1) * 11) % 75) END
            WHEN (((id + 1) * 19) % 100) < 80 THEN  -- 30% viral spike
                60 + (((id + 1) * 13) % 15)
            ELSE  -- 20% post-viral
                75 + (((id + 1) * 17) % 30)
        END,
        TIMESTAMPADD(
            SECOND,
            (((id + 1) * 31) % 86400),
            TIMESTAMPADD(DAY, -180, CURRENT_TIMESTAMP())
        )
    ) as created_at
FROM
    range(0, 500000);

-- Create posts table with 1M records
CREATE TABLE main.social_media_sample.posts
USING DELTA
AS
SELECT
    (id + 1) as post_id,
    -- Title generation
    CASE
        WHEN (((id + 1) * 29) % 100) < 10 THEN CONCAT('Just watched this amazing video: ', SUBSTRING(CAST(((id + 1) * 37) AS STRING), 1, 20))
        WHEN (((id + 1) * 29) % 100) < 20 THEN CONCAT('Check out my ', SUBSTRING(CAST(((id + 1) * 41) AS STRING), 1, 8), ' photo!')
        WHEN (((id + 1) * 29) % 100) < 30 THEN CONCAT('Interesting article: ', SUBSTRING(CAST(((id + 1) * 43) AS STRING), 1, 15))
        WHEN (((id + 1) * 29) % 100) < 40 THEN CONCAT('Quick question: ', SUBSTRING(CAST(((id + 1) * 47) AS STRING), 1, 12), '?')
        WHEN (((id + 1) * 29) % 100) < 50 THEN CONCAT('Proud to announce: ', SUBSTRING(CAST(((id + 1) * 53) AS STRING), 1, 10), ' milestone reached!')
        WHEN (((id + 1) * 29) % 100) < 60 THEN CONCAT('My thoughts on ', SUBSTRING(CAST(((id + 1) * 59) AS STRING), 1, 15), ':')
        WHEN (((id + 1) * 29) % 100) < 70 THEN CONCAT('Something happened today... ', SUBSTRING(CAST(((id + 1) * 61) AS STRING), 1, 18))
        WHEN (((id + 1) * 29) % 100) < 80 THEN CONCAT('When ', SUBSTRING(CAST(((id + 1) * 67) AS STRING), 1, 8), ' meets ', SUBSTRING(CAST(((id + 1) * 71) AS STRING), 1, 6), ' ', SUBSTRING(CAST(((id + 1) * 73) AS STRING), 1, 6))
        ELSE SUBSTRING(CAST(((id + 1) * 79) AS STRING), 1, (((id + 1) * 83) % 30) + 10)
    END as title,
    -- Body generation
    CASE
        WHEN (((id + 1) * 31) % 100) < 40 THEN SUBSTRING(CAST(((id + 1) * 89) AS STRING), 1, (((id + 1) * 97) % 100) + 50)  -- Short
        WHEN (((id + 1) * 31) % 100) < 80 THEN SUBSTRING(CAST(((id + 1) * 101) AS STRING), 1, (((id + 1) * 103) % 300) + 100)  -- Medium
        ELSE SUBSTRING(CAST(((id + 1) * 107) AS STRING), 1, (((id + 1) * 109) % 800) + 200)  -- Long
    END as body,
    -- Assign to user (using modulo for distribution)
    ((((id + 1) * 113) % 500000) + 1) as user_id,
    -- Status distribution: 70% published, 20% draft, 10% archived
    CASE
        WHEN (((id + 1) * 37) % 100) < 70 THEN 'published'
        WHEN (((id + 1) * 37) % 100) < 90 THEN 'draft'
        ELSE 'archived'
    END as status,
    -- Timestamp with viral pattern for posts (showing 10x increase during viral period)
    TIMESTAMPADD(
        DAY,
        CASE
            WHEN (((id + 1) * 41) % 100) < 40 THEN  -- 40% baseline
                CASE WHEN (((id + 1) * 43) % 100) < 50 THEN (((id + 1) * 47) % 60) ELSE 105 + (((id + 1) * 53) % 75) END
            WHEN (((id + 1) * 41) % 100) < 80 THEN  -- 40% elevated (viral+post-viral)
                CASE WHEN (((id + 1) * 43) % 100) < 50 THEN 60 + (((id + 1) * 59) % 15) ELSE 75 + (((id + 1) * 61) % 30) END
            ELSE  -- 20% spread
                (((id + 1) * 67) % 180)
        END,
        TIMESTAMPADD(
            SECOND,
            (((id + 1) * 71) % 86400),
            TIMESTAMPADD(DAY, -180, CURRENT_TIMESTAMP())
        )
    ) as created_at
FROM
    range(0, 1000000);

-- Create follows table with 20K records
CREATE TABLE main.social_media_sample.follows
USING DELTA
AS
SELECT
    -- Following user ID with power-law bias (few users get many follows)
    ((500000 - FLOOR(500000 * POW(((id + 1) * 73) % 100 / 100.0, 2))) + 1) as following_user_id,
    -- Followed user ID with stronger power-law bias (people follow influencers)
    ((500000 - FLOOR(500000 * POW(((id + 1) * 79) % 100 / 100.0, 3))) + 1) as followed_user_id,
    -- Timestamp with viral pattern for follows
    TIMESTAMPADD(
        DAY,
        CASE
            WHEN (((id + 1) * 83) % 100) < 30 THEN  -- 30% baseline
                CASE WHEN (((id + 1) * 89) % 100) < 50 THEN (((id + 1) * 97) % 60) ELSE 105 + (((id + 1) * 101) % 75) END
            WHEN (((id + 1) * 83) % 100) < 70 THEN  -- 40% viral/post-viral
                CASE WHEN (((id + 1) * 89) % 100) < 50 THEN 60 + (((id + 1) * 103) % 15) ELSE 75 + (((id + 1) * 107) % 30) END
            ELSE  -- 30% spread
                (((id + 1) * 109) % 180)
        END,
        TIMESTAMPADD(
            SECOND,
            (((id + 1) * 113) % 86400),
            TIMESTAMPADD(DAY, -180, CURRENT_TIMESTAMP())
        )
    ) as created_at
FROM
    range(0, 20000);

-- Remove self-follows (where following_user_id = followed_user_id)
DELETE FROM main.social_media_sample.follows WHERE following_user_id = followed_user_id;

-- Final validation
SELECT
    'users' as table_name, COUNT(*) as row_count FROM main.social_media_sample.users
UNION ALL
SELECT
    'posts' as table_name, COUNT(*) as row_count FROM main.social_media_sample.posts
UNION ALL
SELECT
    'follows' as table_name, COUNT(*) as row_count FROM main.social_media_sample.follows;

-- Show data quality checks
SELECT
    'User Role Distribution' as metric,
    role,
    COUNT(*) as count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM main.social_media_sample.users), 2) as percentage
FROM main.social_media_sample.users
GROUP BY role
ORDER BY count DESC;

SELECT
    'Post Status Distribution' as metric,
    status,
    COUNT(*) as count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM main.social_media_sample.posts), 2) as percentage
FROM main.social_media_sample.posts
GROUP BY status
ORDER BY count DESC;