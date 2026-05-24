-- Viral Growth Social Media Synthetic Data Generator
-- Implements Option 3: Hybrid Approach (SQL Temporal Framework with UDF Enhancement)
-- Business Story: Viral video triggers exponential growth, platform struggles to scale
-- Target: main.social_media_sample database with users (500K), posts (1M), follows (20K)

-- ============================================================================
-- CONFIGURATION SECTION
-- ============================================================================

-- Set database context
CREATE DATABASE IF NOT EXISTS main.social_media_sample;
USE main.social_media_sample;

-- Clean slate - drop existing tables
DROP TABLE IF EXISTS follows;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS users;

-- Viral timeline parameters (adjust these to control the business story)
SET viral_start_date = '2026-01-15';      -- When the viral video hits
SET pre_viral_days = 30;                  -- Days of baseline before viral event
SET viral_peak_days = 7;                  -- Duration of peak viral period
SET post_viral_days = 60;                 -- Days of decay/churn after viral peak
SET total_simulation_days = pre_viral_days + viral_peak_days + post_viral_days;

-- Growth parameters
SET baseline_daily_registrations = 1000;  -- Normal daily user registrations
SET viral_multiplier = 50;                -- 50x increase during viral peak
SET engagement_multiplier = 10;           -- 10x increase in posts/follows during viral
SET churn_rate_post_viral = 0.15;         -- 15% of new users churn after excitement fades

-- ============================================================================
-- STEP 1: GENERATE USERS TABLE WITH TIME-AWARE REGISTRATION PATTERNS
-- ============================================================================

CREATE OR REPLACE TEMP VIEW user_registration_timeline AS
SELECT
    -- Generate sequential registration dates across the simulation period
    date_add('2025-12-01', seq) as registration_date,
    -- Calculate expected daily registrations based on viral timeline
    CASE
        -- Pre-viral period: baseline growth
        WHEN seq < pre_viral_days THEN baseline_daily_registrations
        -- Viral peak period: exponential growth
        WHEN seq < pre_viral_days + viral_peak_days
            THEN baseline_daily_registrations *
                 POW(viral_multiplier, (seq - pre_viral_days + 1) / viral_peak_days)
        -- Post-viral period: decay with churn
        ELSE baseline_daily_registrations *
             POW(viral_multiplier, 1) *
             EXP(-0.05 * (seq - pre_viral_days - viral_peak_days))
    END as expected_new_users_today
FROM
    (SELECT * FROM range(0, total_simulation_days)) t;

-- Generate actual users with realistic IDs and temporal distribution
CREATE TABLE users
USING DELTA
AS
WITH daily_registrations AS (
    SELECT
        registration_date,
        CAST(expected_new_users_today AS INT) as new_users_count
    FROM user_registration_timeline
    WHERE expected_new_users_today > 0
),
user_sequence AS (
    SELECT
        registration_date,
        -- Generate sequence of user IDs for each day
        posexplode(
            split(repeat('1,', new_users_count), ',')
        ) as (user_seq_offset, dummy)
    FROM daily_registrations
    WHERE new_users_count > 0
),
user_base AS (
    SELECT
        registration_date,
        user_seq_offset + 1000000 +
        (ROW_NUMBER() OVER (PARTITION BY registration_date ORDER BY user_seq_offset) - 1) as user_id,
        registration_date
    FROM user_sequence
)
SELECT
    -- Core user fields with temporal awareness
    user_id as id,
    -- Enhanced username would come from UDF in practice: CONCAT('user_', Faker.username())
    CONCAT('user_', LPAD(user_id, 8, '0')) as username,
    -- Role distribution changes over time (more moderators needed during viral spike)
    CASE
        WHEN registration_date < date_add('${viral_start_date}', -pre_viral_days) THEN
            CASE WHEN RAND() < 0.85 THEN 'member' WHEN RAND() < 0.95 THEN 'moderator' ELSE 'admin' END
        WHEN registration_date < date_add('${viral_start_date}', viral_peak_days) THEN
            CASE WHEN RAND() < 0.70 THEN 'member' WHEN RAND() < 0.90 THEN 'moderator' ELSE 'admin' END
        ELSE
            CASE WHEN RAND() < 0.90 THEN 'member' WHEN RAND() < 0.98 THEN 'moderator' ELSE 'admin' END
    END as role,
    registration_date as created_at
FROM user_base
WHERE user_id IS NOT NULL
LIMIT 500000;  -- Ensure we get exactly 500K users

-- ============================================================================
-- STEP 2: GENERATE POSTS TABLE WITH VIRAL ENGAGEMENT PATTERNS
-- ============================================================================

CREATE OR REPLACE TEMP VIEW post_creation_timeline AS
SELECT
    -- Posts follow user registration with viral amplification
    u.registration_date as user_registration_date,
    date_add(u.registration_date,
             CAST(RAND() * 30 AS INT)) as post_creation_date,  -- Users post within 30 days of joining
    -- Base posting rate amplified by viral effects
    CASE
        -- Pre-viral: normal posting rate
        WHEN u.registration_date < date_add('${viral_start_date}', -pre_viral_days) THEN 1.5
        -- Viral peak: explosive posting (10x engagement increase)
        WHEN u.registration_date < date_add('${viral_start_date}', viral_peak_days) THEN 15.0
        -- Post-viral: elevated but decaying
        ELSE 3.0 * EXP(-0.02 * (datediff(u.registration_date, date_add('${viral_start_date}', viral_peak_days))))
    END as posts_per_user_daily_rate
FROM users u;

CREATE TABLE posts
USING DELTA
AS
WITH post_sequence AS (
    SELECT
        p.user_registration_date,
        p.post_creation_date,
        -- Generate multiple posts per user based on amplified rate
        posexplode(
            split(repeat('1,', CAST(p.posts_per_user_daily_rate AS INT)), ',')
        ) as (post_seq_offset, dummy)
    FROM post_creation_timeline p
    JOIN users u ON datediff(p.post_creation_date, u.created_at) BETWEEN 0 AND 30
    WHERE p.posts_per_user_daily_rate >= 1
),
post_base AS (
    SELECT
        -- Generate realistic post IDs
        user_seq_offset + 2000000 +
        (ROW_NUMBER() OVER (PARTITION BY user_registration_date, post_creation_date ORDER BY user_seq_offset)) as post_id,
        -- Random user from those active on post date
        (SELECT id FROM users
         WHERE created_at <= post_creation_date
         ORDER BY RAND()
         LIMIT 1) as user_id,
        post_creation_date as created_at
    FROM post_sequence
)
SELECT
    post_id as id,
    -- Enhanced title would come from UDF: Faker.sentence(nb_words=6)
    CONCAT('Post about topic ', FLOOR(RAND() * 1000),
           CASE WHEN RAND() < 0.1 THEN ' - VIDEO CONTENT' ELSE '' END) as title,
    -- Enhanced body would come from UDF: Faker.paragraph(nb=3) with viral variations
    CASE
        -- Viral video posts get special treatment
        WHEN RAND() < 0.001 THEN  -- 0.1% of posts are the actual viral video
            CONCAT('Check out this amazing video! ',
                   REPEAT('This is incredible content that everyone is sharing. ', FLOOR(RAND() * 5) + 1),
                   ' #viral #trending #mustwatch')
        -- Regular posts with varied content
        ELSE CONCAT('User post ', post_id, ': ',
                   REPEAT('Some interesting content here. ', FLOOR(RAND() * 4) + 1),
                   CASE WHEN RAND() < 0.3 THEN ' #discussion' ELSE '' END)
    END as body,
    -- Status varies by time period and content type
    CASE
        WHEN created_at < date_add('${viral_start_date}', -pre_viral_days) THEN
            CASE WHEN RAND() < 0.9 THEN 'published' ELSE 'draft' END
        WHEN created_at < date_add('${viral_start_date}', viral_peak_days) THEN
            CASE WHEN RAND() < 0.95 THEN 'published' WHEN RAND() < 0.98 THEN 'flagged' ELSE 'archived' END
        ELSE
            CASE WHEN RAND() < 0.85 THEN 'published' WHEN RAND() < 0.95 THEN 'draft' ELSE 'archived' END
    END as status,
    created_at
FROM post_base
LIMIT 1000000;  -- Ensure we get exactly 1M posts

-- ============================================================================
-- STEP 3: GENERATE FOLLOWS TABLE WITH NETWORK EFFECT MODELING
-- ============================================================================

CREATE TABLE follows
USING DELTA
AS
WITH active_users AS (
    SELECT id as user_id, created_at
    FROM users
),
follow_generation AS (
    SELECT
        -- Follower user (someone who decides to follow)
        f.user_id as follower_id,
        -- Followee user (someone being followed)
        (SELECT id FROM users
         WHERE id != f.user_id
         AND created_at <= date_add(f.created_at, 10)  -- Only follow users who joined reasonably before
         ORDER BY RAND()
         LIMIT 1) as followee_id,
        -- Follow timestamp with viral amplification
        date_add(f.created_at,
                 CAST(RAND() * 20 AS INT)) as follow_created_at
    FROM active_users f
    WHERE
        -- Base follow probability amplified by viral timeline
        RAND() <
        CASE
            WHEN f.created_at < date_add('${viral_start_date}', -pre_viral_days) THEN 0.02  -- 2% baseline
            WHEN f.created_at < date_add('${viral_start_date}', viral_peak_days) THEN 0.20  -- 20% during viral
            ELSE 0.05 * EXP(-0.01 * (datediff(f.created_at, date_add('${viral_start_date}', viral_peak_days))))  -- Decaying
        END
),
cleaned_follows AS (
    SELECT
        follower_id as following_user_id,
        followee_id as followed_user_id,
        follow_created_at as created_at
    FROM follow_generation
    WHERE follower_id != followee_id  -- No self-follows
      AND followee_id IS NOT NULL
)
SELECT
    following_user_id,
    followed_user_id,
    created_at
FROM cleaned_follows
LIMIT 20000;  -- Ensure we get exactly 20K follows

-- ============================================================================
-- STEP 4: ADD CONSTRAINTS AND VALIDATE
-- ============================================================================

ALTER TABLE users ADD CONSTRAINT users_pk PRIMARY KEY (id);
ALTER TABLE posts ADD CONSTRAINT posts_pk PRIMARY KEY (id);
ALTER TABLE follows ADD CONSTRAINT follows_pk PRIMARY KEY (following_user_id, followed_user_id);

ALTER TABLE posts ADD CONSTRAINT posts_users_fk FOREIGN KEY (user_id) REFERENCES users(id);
ALTER TABLE follows ADD CONSTRAINT follows_following_fk FOREIGN KEY (following_user_id) REFERENCES users(id);
ALTER TABLE follows ADD CONSTRAINT follows_followed_fk FOREIGN KEY (followed_user_id) REFERENCES users(id);

-- ============================================================================
-- STEP 5: BUSINESS STORY VALIDATION QUERIES
-- ============================================================================

-- Validate the viral growth story
SELECT
    'DAILY_REGISTRATIONS_PRE_VIRAL' as metric,
    AVG(daily_regs) as avg_value
FROM (
    SELECT
        date_trunc('DAY', created_at) as day,
        COUNT(*) as daily_regs
    FROM users
    WHERE created_at < date_add('${viral_start_date}', -pre_viral_days)
    GROUP BY date_trunc('DAY', created_at)
) t
UNION ALL
SELECT
    'DAILY_REGISTRATIONS_VIRAL_PEAK' as metric,
    AVG(daily_regs) as avg_value
FROM (
    SELECT
        date_trunc('DAY', created_at) as day,
        COUNT(*) as daily_regs
    FROM users
    WHERE created_at >= date_add('${viral_start_date}', -pre_viral_days)
      AND created_at < date_add('${viral_start_date}', viral_peak_days)
    GROUP BY date_trunc('DAY', created_at)
) t
UNION ALL
SELECT
    'DAILY_REGISTRATIONS_POST_VIRAL' as metric,
    AVG(daily_regs) as avg_value
FROM (
    SELECT
        date_trunc('DAY', created_at) as day,
        COUNT(*) as daily_regs
    FROM users
    WHERE created_at >= date_add('${viral_start_date}', viral_peak_days)
    GROUP BY date_trunc('DAY', created_at)
) t
UNION ALL
SELECT
    'TOTAL_USERS' as metric,
    COUNT(*) as avg_value
FROM users
UNION ALL
SELECT
    'TOTAL_POSTS' as metric,
    COUNT(*) as avg_value
FROM posts
UNION ALL
SELECT
    'TOTAL_FOLLOWS' as metric,
    COUNT(*) as avg_value
FROM follows
UNION ALL
SELECT
    'POSTS_PER_USER_RATIO' as metric,
    CAST(COUNT(*) AS DOUBLE) / (SELECT COUNT(*) FROM users) as avg_value
FROM posts;

-- Show timeline samples to verify business story
SELECT
    'PRE_VIRAL_USERS_SAMPLE' as period,
    date_format(created_at, 'yyyy-MM-dd') as date,
    COUNT(*) as new_users
FROM users
WHERE created_at < date_add('${viral_start_date}', -pre_viral_days)
GROUP BY date_format(created_at, 'yyyy-MM-dd')
ORDER BY date
LIMIT 5

UNION ALL

SELECT
    'VIRAL_PEAK_USERS_SAMPLE' as period,
    date_format(created_at, 'yyyy-MM-dd') as date,
    COUNT(*) as new_users
FROM users
WHERE created_at >= date_add('${viral_start_date}', -pre_viral_days)
  AND created_at < date_add('${viral_start_date}', viral_peak_days)
GROUP BY date_format(created_at, 'yyyy-MM-dd')
ORDER BY date
LIMIT 5

UNION ALL

SELECT
    'POST_VIRAL_USERS_SAMPLE' as period,
    date_format(created_at, 'yyyy-MM-dd') as date,
    COUNT(*) as new_users
FROM users
WHERE created_at >= date_add('${viral_start_date}', viral_peak_days)
GROUP BY date_format(created_at, 'yyyy-MM-dd')
ORDER BY date
LIMIT 5;