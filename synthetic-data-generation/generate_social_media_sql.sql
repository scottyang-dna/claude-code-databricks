-- Social Media Synthetic Data Generation using Pure SQL
-- Generates users, posts, and follows tables with viral growth story

USE CATALOG main;
USE SCHEMA social_media_sample;

-- Drop tables if they exist to start fresh
DROP TABLE IF EXISTS follows;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS users;

-- ============================================================================
-- 1. GENERATE USERS TABLE (500,000 records)
-- ============================================================================
CREATE TABLE users (
    id BIGINT PRIMARY KEY,
    username STRING,
    role STRING,
    created_at TIMESTAMP
)
USING DELTA;

-- Generate 500K users with viral growth pattern
INSERT INTO users
SELECT
    monotically_increasing_id() + 1 as id,
    -- Generate realistic usernames
    LOWER(CONCAT(
        SUBSTRING(sha2(rand(), 256), 1, 3),
        '_',
        SUBSTRING(sha2(rand() + 1, 256), 1, 5),
        CASE WHEN rand() < 0.3 THEN CAST(FLOOR(rand() * 90) + 10 AS STRING) ELSE '' END
    )) as username,
    -- Role distribution: 80% regular_user, 15% content_creator, 5% influencer
    CASE
        WHEN rand() < 0.80 THEN 'regular_user'
        WHEN rand() < 0.95 THEN 'content_creator'
        ELSE 'influencer'
    END as role,
    -- Creation timestamps with viral growth pattern
    -- Base date: 180 days ago
    -- Viral spike: days 60-74 (14 days of 5x normal rate)
    -- Post-viral adjustment: days 75-104 (settling to 2x baseline)
    -- New normal: days 105-179
    TIMESTAMPADD(
        DAY,
        CASE
            -- Distribution: 50% baseline (days 0-59 and 105-179), 30% viral spike (days 60-74), 20% post-viral (days 75-104)
            WHEN rand() < 0.50 THEN
                -- Baseline periods
                CASE WHEN rand() < 0.6 THEN FLOOR(rand() * 60) ELSE 105 + FLOOR(rand() * 75) END
            WHEN rand() < 0.80 THEN
                -- Viral spike (days 60-74): 60 + FLOOR(rand() * 15)
                60 + FLOOR(rand() * 15)
            ELSE
                -- Post-viral adjustment (days 75-104)
                75 + FLOOR(rand() * 30)
        END,
        -- Add time-of-day variation
        TIMESTAMPADD(
            SECOND,
            FLOOR(rand() * 86400),
            TIMESTAMPADD(DAY, -180, CURRENT_TIMESTAMP())
        )
    ) as created_at
FROM
    -- Generate enough rows using cross join
    (SELECT 1 FROM TABLE(range(0, 1000))) t1,
    (SELECT 1 FROM TABLE(range(0, 1000))) t2,
    (SELECT 1 FROM TABLE(range(0, 1000))) t3
LIMIT 500000;

-- ============================================================================
-- 2. GENERATE POSTS TABLE (1,000,000 records)
-- ============================================================================
CREATE TABLE posts (
    id BIGINT PRIMARY KEY,
    title STRING,
    body TEXT,
    user_id BIGINT,
    status STRING,
    created_at TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
)
USING DELTA;

-- Generate 1M posts with viral growth patterns
INSERT INTO posts
SELECT
    monotically_increasing_id() + 1 as id,
    -- Generate post titles based on type
    CASE
        WHEN rand() < 0.10 THEN CONCAT('Just watched this amazing video: ', SUBSTRING(sha2(rand(), 256), 1, 20))
        WHEN rand() < 0.20 THEN CONCAT('Check out my ', SUBSTRING(sha2(rand() + 100, 256), 1, 8), ' photo!')
        WHEN rand() < 0.30 THEN CONCAT('Interesting article: ', SUBSTRING(sha2(rand() + 200, 256), 1, 15))
        WHEN rand() < 0.40 THEN CONCAT('Quick question: ', SUBSTRING(sha2(rand() + 300, 256), 1, 12), '?')
        WHEN rand() < 0.50 THEN CONCAT('Proud to announce: ', SUBSTRING(sha2(rand() + 400, 256), 1, 10), ' milestone reached!')
        WHEN rand() < 0.60 THEN CONCAT('My thoughts on ', SUBSTRING(sha2(rand() + 500, 256), 1, 15), ':')
        WHEN rand() < 0.70 THEN CONCAT('Something happened today... ', SUBSTRING(sha2(rand() + 600, 256), 1, 18))
        WHEN rand() < 0.80 THEN CONCAT('When ', SUBSTRING(sha2(rand() + 700, 256), 1, 8), ' meets ', SUBSTRING(sha2(rand() + 800, 256), 1, 6), ' ', SUBSTRING(sha2(rand() + 900, 256), 1, 6))
        ELSE SUBSTRING(sha2(rand(), 256), 1, FLOOR(rand() * 30) + 10)
    END as title,
    -- Generate post bodies with variable length
    CASE
        WHEN rand() < 0.4 THEN SUBSTRING(sha2(rand(), 256), 1, FLOOR(rand() * 100) + 50)  -- Short
        WHEN rand() < 0.8 THEN SUBSTRING(sha2(rand(), 256), 1, FLOOR(rand() * 300) + 100)  -- Medium
        ELSE SUBSTRING(sha2(rand(), 256), 1, FLOOR(rand() * 800) + 200)  -- Long
    END as body,
    -- Assign to random user (we'll validate FK integrity later through queries)
    (FLOOR(rand() * 500000) + 1) as user_id,
    -- Status distribution: 70% published, 20% draft, 10% archived
    CASE
        WHEN rand() < 0.70 THEN 'published'
        WHEN rand() < 0.90 THEN 'draft'
        ELSE 'archived'
    END as status,
    -- Creation timestamps with viral growth pattern for posts
    -- Posts show 10x increase during viral period
    TIMESTAMPADD(
        DAY,
        CASE
            -- Distribution: 40% baseline, 40% elevated (viral+post-viral), 20% spread
            WHEN rand() < 0.40 THEN
                -- Baseline periods
                CASE WHEN rand() < 0.5 THEN FLOOR(rand() * 60) ELSE 105 + FLOOR(rand() * 75) END
            WHEN rand() < 0.80 THEN
                -- Elevated periods (viral + post-viral)
                CASE WHEN rand() < 0.5 THEN 60 + FLOOR(rand() * 15) ELSE 75 + FLOOR(rand() * 30) END
            ELSE
                -- Spread throughout
                FLOOR(rand() * 180)
        END,
        -- Add time-of-day variation
        TIMESTAMPADD(
            SECOND,
            FLOOR(rand() * 86400),
            TIMESTAMPADD(DAY, -180, CURRENT_TIMESTAMP())
        )
    ) as created_at
FROM
    -- Generate enough rows
    (SELECT 1 FROM TABLE(range(0, 1000))) t1,
    (SELECT 1 FROM TABLE(range(0, 1000))) t2,
    (SELECT 1 FROM TABLE(range(0, 1000))) t3,
    (SELECT 1 FROM TABLE(range(0, 10))) t4
LIMIT 1000000;

-- ============================================================================
-- 3. GENERATE FOLLOWS TABLE (20,000 records)
-- ============================================================================
CREATE TABLE follows (
    following_user_id BIGINT,
    followed_user_id BIGINT,
    created_at TIMESTAMP,
    PRIMARY KEY (following_user_id, followed_user_id),
    FOREIGN KEY (following_user_id) REFERENCES users(id),
    FOREIGN KEY (followed_user_id) REFERENCES users(id)
)
USING DELTA;

-- Generate 20K follows with power-law distribution and viral patterns
INSERT INTO follows
SELECT
    -- Following user ID with power-law bias (few users get many follows)
    (FLOOR(500000 * (1 - POW(rand(), 2))) + 1) as following_user_id,
    -- Followed user ID with even stronger power-law bias (people follow influencers)
    (FLOOR(500000 * (1 - POW(rand(), 3))) + 1) as followed_user_id,
    -- Creation timestamps with viral growth pattern for follows
    TIMESTAMPADD(
        DAY,
        CASE
            -- Distribution: 30% baseline, 40% viral/post-viral, 30% spread
            WHEN rand() < 0.30 THEN
                -- Baseline periods
                CASE WHEN rand() < 0.5 THEN FLOOR(rand() * 60) ELSE 105 + FLOOR(rand() * 75) END
            WHEN rand() < 0.70 THEN
                -- Viral + post-viral periods
                CASE WHEN rand() < 0.5 THEN 60 + FLOOR(rand() * 15) ELSE 75 + FLOOR(rand() * 30) END
            ELSE
                -- Spread throughout
                FLOOR(rand() * 180)
        END,
        -- Add time-of-day variation
        TIMESTAMPADD(
            SECOND,
            FLOOR(rand() * 86400),
            TIMESTAMPADD(DAY, -180, CURRENT_TIMESTAMP())
        )
    ) as created_at
FROM
    -- Generate enough rows
    (SELECT 1 FROM TABLE(range(0, 200))) t1,
    (SELECT 1 FROM TABLE(range(0, 200))) t2,
    (SELECT 1 FROM TABLE(range(0, 200))) t3
LIMIT 20000;

-- Remove self-follows (where following_user_id = followed_user_id)
DELETE FROM follows WHERE following_user_id = followed_user_id;

-- ============================================================================
-- 4. VALIDATE DATA COUNTS AND SHOW SAMPLES
-- ============================================================================

-- Validate row counts
SELECT
    'users' as table_name, COUNT(*) as row_count FROM users
UNION ALL
SELECT
    'posts' as table_name, COUNT(*) as row_count FROM posts
UNION ALL
SELECT
    'follows' as table_name, COUNT(*) as row_count FROM follows;

-- Show sample data from each table
SELECT 'users sample' as info, * FROM users LIMIT 3;
SELECT 'posts sample' as info, * FROM posts LIMIT 3;
SELECT 'follows sample' as info, * FROM follows LIMIT 3;

-- Show some basic statistics to validate the viral growth story
SELECT
    'User Registration Over Time' as metric,
    YEAR(created_at) as year,
    MONTH(created_at) as month,
    COUNT(*) as new_users
FROM users
GROUP BY YEAR(created_at), MONTH(created_at)
ORDER BY year, month
LIMIT 6;

SELECT
    'Post Volume Over Time' as metric,
    YEAR(created_at) as year,
    MONTH(created_at) as month,
    COUNT(*) as post_count
FROM posts
GROUP BY YEAR(created_at), MONTH(created_at)
ORDER BY year, month
LIMIT 6;

SELECT
    'Follows Volume Over Time' as metric,
    YEAR(created_at) as year,
    MONTH(created_at) as month,
    COUNT(*) as follow_count
FROM follows
GROUP BY YEAR(created_at), MONTH(created_at)
ORDER BY year, month
LIMIT 6;

-- Role distribution
SELECT
    role,
    COUNT(*) as user_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM users), 2) as percentage
FROM users
GROUP BY role
ORDER BY user_count DESC;

-- Post status distribution
SELECT
    status,
    COUNT(*) as post_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM posts), 2) as percentage
FROM posts
GROUP BY status
ORDER BY post_count DESC;