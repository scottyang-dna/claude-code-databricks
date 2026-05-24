#!/usr/bin/env python3
"""
Synthetic data generation for social media platform with viral growth story.
Generates:
- users table: 500,000 records
- posts table: 1,000,000 records
- follows table: 20,000 records

Business story: Viral video triggers exponential growth and scaling challenges.
"""

from databricks.connect import DatabricksSession, DatabricksEnv
from pyspark.sql import functions as F
from pyspark.sql.types import StringType, IntegerType, TimestampType
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# Configuration
CATALOG = "main"
SCHEMA = "social_media_sample"

# Setup serverless with dependencies
env = DatabricksEnv().withDependencies("faker", "numpy", "pandas")
spark = DatabricksSession.builder.withEnvironment(env).serverless(True).getOrCreate()

# Ensure schema and volume exist
spark.sql(f"CREATE SCHEMA IF NOT EXISTS {CATALOG}.{SCHEMA}")
spark.sql(f"CREATE VOLUME IF NOT EXISTS {CATALOG}.{SCHEMA}.raw_data")

# Date ranges for viral growth story
END_DATE = datetime.now()
START_DATE = END_DATE - timedelta(days=180)
VIRAL_START = START_DATE + timedelta(days=60)  # Day 61
VIRAL_END = VIRAL_START + timedelta(days=14)   # 14-day viral period
POST_VIRAL_END = VIRAL_END + timedelta(days=30) # 30-day adjustment period

print(f"Generating data for period: {START_DATE} to {END_DATE}")
print(f"Viral period: {VIRAL_START} to {VIRAL_END}")

# ============================================================================
# 1. GENERATE USERS TABLE (500,000 records)
# ============================================================================
print("Generating users table...")

@F.pandas_udf(StringType())
def fake_username(ids: pd.Series) -> pd.Series:
    from faker import Faker
    fake = Faker()
    usernames = []
    for _ in range(len(ids)):
        # Generate realistic usernames with different patterns
        pattern = np.random.choice([
            'first_last',           # john_smith
            'firstlast',            # johnsmith
            'first_last_##',        # john_smith_23
            'hobby_first',          # photography_john
            'first_##',             # john_88
            'realname'              # johnsmith (no separator)
        ])

        if pattern == 'first_last':
            username = f"{fake.first_name().lower()}_{fake.last_name().lower()}"
        elif pattern == 'firstlast':
            username = f"{fake.first_name().lower()}{fake.last_name().lower()}"
        elif pattern == 'first_last_##':
            username = f"{fake.first_name().lower()}_{fake.last_name().lower()}_{np.random.randint(10, 99)}"
        elif pattern == 'hobby_first':
            hobbies = ['photo', 'video', 'art', 'music', 'sport', 'game', 'cook', 'travel']
            username = f"{np.random.choice(hobbies)}_{fake.first_name().lower()}"
        elif pattern == 'first_##':
            username = f"{fake.first_name().lower()}_{np.random.randint(10, 99)}"
        else:  # realname
            username = f"{fake.first_name().lower()}{fake.last_name().lower()}"

        usernames.append(username)
    return pd.Series(usernames)

@F.pandas_udf(StringType())
def fake_role(ids: pd.Series) -> pd.Series:
    # Role distribution: 80% regular_user, 15% content_creator, 5% influencer
    roles = np.random.choice(
        ['regular_user', 'content_creator', 'influencer'],
        size=len(ids),
        p=[0.80, 0.15, 0.05]
    )
    return pd.Series(roles)

# Generate user creation dates with viral growth pattern
def create_user_timestamps(n_users):
    """Generate timestamps with viral growth spike"""
    timestamps = []

    for i in range(n_users):
        # Determine if user joined during viral period based on temporal distribution
        # Baseline: uniform distribution
        # Viral spike: much higher probability during viral window
        rand_val = np.random.random()

        if rand_val < 0.7:  # 70% baseline period (days 0-60 and post-viral)
            # Baseline periods: days 0-60 and days 105-180
            baseline_weight = 0.7
            if np.random.random() < 0.6:  # 60% of baseline in first period
                # Days 0-60 (baseline)
                days_offset = np.random.uniform(0, 60)
            else:  # 40% of baseline in post-viral period
                # Days 105-180 (post-viral settling)
                days_offset = np.random.uniform(105, 180)
        else:  # 30% during viral and high-growth periods
            # Split between viral explosion and immediate post-viral
            if np.random.random() < 0.5:  # Half in viral explosion
                days_offset = np.random.uniform(60, 75)  # Viral period
            else:  # Half in immediate post-viral adjustment
                days_offset = np.random.uniform(75, 105)  # Adjustment period

        timestamp = START_DATE + timedelta(days=days_offset)
        # Add time-of-day variation
        timestamp += timedelta(
            hours=np.random.randint(0, 24),
            minutes=np.random.randint(0, 60),
            seconds=np.random.randint(0, 60)
        )
        timestamps.append(timestamp)

    return pd.Series(timestamps)

# Generate 500K users
n_users = 500000
users_df = spark.range(0, n_users, numPartitions=32).select(
    (F.col("id") + 1).alias("id"),  # Start IDs from 1
    fake_username(F.col("id")).alias("username"),
    fake_role(F.col("id")).alias("role"),
    F.to_timestamp(F.lit(create_user_timestamps(n_users))).alias("created_at")
)

# Write users table
print(f"Writing {n_users:,} users to {CATALOG}.{SCHEMA}.users")
users_df.write.mode("overwrite").saveAsTable(f"{CATALOG}.{SCHEMA}.users")

# Read back for FK lookups (required for serverless - no caching)
print("Reading users back for foreign key lookups...")
user_lookup = spark.table(f"{CATALOG}.{SCHEMA}.users").select("id", "username")

# ============================================================================
# 2. GENERATE POSTS TABLE (1,000,000 records)
# ============================================================================
print("Generating posts table...")

@F.pandas_udf(StringType())
def fake_post_title(ids: pd.Series) -> pd.Series:
    from faker import Faker
    fake = Faker()
    titles = []
    post_types = ['Update', 'Thoughts', 'Video Share', 'Photo Share', 'Link Share',
                  'Question', 'Achievement', 'Opinion', 'Story', 'Meme']

    for _ in range(len(ids)):
        post_type = np.random.choice(post_types)
        if post_type == 'Video Share':
            title = f"Just watched this amazing video: {fake.catch_phrase()}"
        elif post_type == 'Photo Share':
            title = f"Check out my {fake.color_name()} {fake.word()} photo!"
        elif post_type == 'Link Share':
            title = f"Interesting article: {fake.bs().title()}"
        elif post_type == 'Question':
            title = f"Quick question: {fake.sentence(nb_words=6).rstrip('.')}?"
        elif post_type == 'Achievement':
            title = f"Proud to announce: {fake.job()} milestone reached!"
        elif post_type == 'Opinion':
            title = f"My thoughts on {fake.bs()}:"
        elif post_type == 'Story':
            title = f"Something happened today... {fake.sentence(nb_words=8)}"
        elif post_type == 'Meme':
            title = f"When {fake.job()} meets {fake.color_name()} {fake.word()}:"
        else:  # Update or Thoughts
            title = fake.sentence(nb_words=np.random.randint(3, 8))

        titles.append(title)
    return pd.Series(titles)

@F.pandas_udf(StringType())
def fake_post_body(ids: pd.Series) -> pd.Series:
    from faker import Faker
    fake = Faker()
    bodies = []

    for _ in range(len(ids)):
        # Vary body length and style
        length_choice = np.random.choice(['short', 'medium', 'long'], p=[0.4, 0.4, 0.2])

        if length_choice == 'short':
            body = fake.sentence(nb_words=np.random.randint(5, 15))
        elif length_choice == 'medium':
            body = fake.paragraph(nb_sentences=np.random.randint(2, 4))
        else:  # long
            body = fake.paragraph(nb_sentences=np.random.randint(4, 8))

        bodies.append(body)
    return pd.Series(bodies)

@F.pandas_udf(StringType())
def fake_post_status(ids: pd.Series) -> pd.Series:
    # Status distribution: 70% published, 20% draft, 10% archived
    statuses = np.random.choice(
        ['published', 'draft', 'archived'],
        size=len(ids),
        p=[0.70, 0.20, 0.10]
    )
    return pd.Series(statuses)

def create_post_timestamps(n_posts, user_lookup_df):
    """Generate post timestamps with viral growth pattern and user assignment"""
    # Collect user IDs for assignment (this is acceptable since we need the mapping)
    user_ids = [row.id for row in user_lookup_df.select("id").collect()]

    timestamps = []
    assigned_user_ids = []

    for i in range(n_posts):
        # Assign to random user
        user_id = np.random.choice(user_ids)
        assigned_user_ids.append(user_id)

        # Generate timestamp with viral pattern similar to users but with posting bursts
        rand_val = np.random.random()

        if rand_val < 0.5:  # 50% baseline posting
            if np.random.random() < 0.6:
                # First half baseline
                days_offset = np.random.uniform(0, 60)
            else:
                # Second half baseline
                days_offset = np.random.uniform(105, 180)
        else:  # 50% elevated posting
            if np.random.random() < 0.4:  # Viral explosion
                days_offset = np.random.uniform(60, 75)
            elif np.random.random() < 0.7:  # Post-viral adjustment
                days_offset = np.random.uniform(75, 105)
            else:  # New normal
                days_offset = np.random.uniform(15, 165)  # Spread throughout

        timestamp = START_DATE + timedelta(days=days_offset)
        timestamp += timedelta(
            hours=np.random.randint(0, 24),
            minutes=np.random.randint(0, 60),
            seconds=np.random.randint(0, 60)
        )
        timestamps.append(timestamp)

    return pd.Series(timestamps), pd.Series(assigned_user_ids)

# Generate 1M posts
n_posts = 1000000
posts_base = spark.range(0, n_posts, numPartitions=64).select(
    (F.col("id") + 1).alias("id")
)

# Add post content
posts_with_content = posts_base.select(
    F.col("id"),
    fake_post_title(F.col("id")).alias("title"),
    fake_post_body(F.col("id")).alias("body"),
    fake_post_status(F.col("id")).alias("status")
)

# For timestamp and user_id generation, we'll use a pandas UDF that can access broadcasted data
# Since we can't easily broadcast large data, we'll generate in batches or use a different approach

# Let's use a simpler approach: generate user_id assignment with reasonable distribution
# and then create timestamps based on overall patterns

@F.pandas_udf(IntegerType())
def assign_user_id(ids: pd.Series) -> pd.Series:
    # Load user IDs once (this creates a bottleneck but is necessary for FK integrity)
    # In practice, for 500K users this is manageable
    user_ids = list(range(1, 500001))  # IDs 1 to 500000
    return pd.Series([np.random.choice(user_ids) for _ in range(len(ids))])

@F.pandas_udf(TimestampType())
def create_post_timestamps_simple(ids: pd.Series) -> pd.Series:
    """Simplified timestamp generation for posts"""
    timestamps = []
    for _ in range(len(ids)):
        rand_val = np.random.random()

        if rand_val < 0.4:  # 40% baseline (lower to account for viral spike)
            if np.random.random() < 0.5:
                days_offset = np.random.uniform(0, 60)
            else:
                days_offset = np.random.uniform(105, 180)
        elif rand_val < 0.8:  # 40% elevated (viral + post-viral)
            if np.random.random() < 0.5:
                days_offset = np.random.uniform(60, 75)  # Viral
            else:
                days_offset = np.random.uniform(75, 105)  # Post-viral
        else:  # 20% spread throughout
            days_offset = np.random.uniform(0, 180)

        timestamp = START_DATE + timedelta(days=days_offset)
        timestamp += timedelta(
            hours=np.random.randint(0, 24),
            minutes=np.random.randint(0, 60),
            seconds=np.random.randint(0, 60)
        )
        timestamps.append(timestamp)

    return pd.Series(timestamps)

# Apply transformations
posts_final = posts_with_content.select(
    F.col("id"),
    F.col("title"),
    F.col("body"),
    assign_user_id(F.col("id")).alias("user_id"),
    create_post_timestamps_simple(F.col("id")).alias("created_at"),
    F.col("status")
)

print(f"Writing {n_posts:,} posts to {CATALOG}.{SCHEMA}.posts")
posts_final.write.mode("overwrite").saveAsTable(f"{CATALOG}.{SCHEMA}.posts")

# ============================================================================
# 3. GENERATE FOLLOWS TABLE (20,000 records)
# ============================================================================
print("Generating follows table...")

def create_follow_timestamps(n_follows):
    """Generate follow timestamps with viral growth pattern"""
    timestamps = []
    for _ in range(n_follows):
        rand_val = np.random.random()

        if rand_val < 0.3:  # 30% baseline
            if np.random.random() < 0.5:
                days_offset = np.random.uniform(0, 60)
            else:
                days_offset = np.random.uniform(105, 180)
        elif rand_val < 0.7:  # 40% viral and post-viral
            if np.random.random() < 0.5:
                days_offset = np.random.uniform(60, 75)  # Viral
            else:
                days_offset = np.random.uniform(75, 105)  # Post-viral
        else:  # 30% spread
            days_offset = np.random.uniform(0, 180)

        timestamp = START_DATE + timedelta(days=days_offset)
        timestamp += timedelta(
            hours=np.random.randint(0, 24),
            minutes=np.random.randint(0, 60),
            seconds=np.random.randint(0, 60)
        )
        timestamps.append(timestamp)

    return pd.Series(timestamps)

# Generate follows with power-law distribution (few users get many follows)
n_follows = 20000
follows_base = spark.range(0, n_follows, numPartitions=16).select(
    (F.col("id") + 1).alias("follow_id")  # Just for uniqueness
)

@F.pandas_udf(IntegerType())
def generate_follower_id(ids: pd.Series) -> pd.Series:
    """Generate follower IDs with power-law distribution"""
    # Power law: few users have many followers (influencers), many users have few
    # Generate using exponential distribution then map to user ID range
    user_ids = list(range(1, 500001))

    follower_ids = []
    for _ in range(len(ids)):
        # Generate exponential variate (more small values, fewer large)
        exp_variate = np.random.exponential(scale=50)  # Mean of 50
        # Map to user ID range with bias toward lower IDs (more followers for popular users)
        rank = int(exp_variate) % len(user_ids)
        # Bias toward beginning of list (popular users with many followers)
        biased_rank = max(0, rank - np.random.exponential(scale=100))
        biased_rank = min(len(user_ids) - 1, int(biased_rank))
        follower_id = user_ids[biased_rank]
        follower_ids.append(follower_id)

    return pd.Series(follower_ids)

@F.pandas_udf(IntegerType())
def generate_followed_id(ids: pd.Series, follower_ids: pd.Series) -> pd.Series:
    """Generate followed IDs, avoiding self-follows and implementing power law"""
    user_ids = list(range(1, 500001))
    followed_ids = []

    for i in range(len(ids)):
        follower_id = follower_ids.iloc[i]

        # Power law for followed users too (people tend to follow influencers)
        exp_variate = np.random.exponential(scale=30)  # Even more biased toward popular users
        rank = int(exp_variate) % len(user_ids)
        biased_rank = max(0, rank - np.random.exponential(scale=150))
        biased_rank = min(len(user_ids) - 1, int(biased_rank))
        followed_id = user_ids[biased_rank]

        # Avoid self-follows (with retry limit)
        attempts = 0
        while followed_id == follower_id and attempts < 5:
            exp_variate = np.random.exponential(scale=30)
            rank = int(exp_variate) % len(user_ids)
            biased_rank = max(0, rank - np.random.exponential(scale=150))
            biased_rank = min(len(user_ids) - 1, int(biased_rank))
            followed_id = user_ids[biased_rank]
            attempts += 1

        # If still self-follow after attempts, shift by 1
        if followed_id == follower_id:
            followed_id = (followed_id % 500000) + 1

        followed_ids.append(followed_id)

    return pd.Series(followed_ids)

# Create intermediate DataFrame with follower IDs
follows_with_follower = follows_base.select(
    F.col("follow_id"),
    generate_follower_id(F.col("follow_id")).alias("following_user_id")
)

# Add followed user IDs
follows_final = follows_with_follower.select(
    F.col("follow_id"),
    F.col("following_user_id"),
    generate_followed_id(F.col("follow_id"), F.col("following_user_id")).alias("followed_user_id"),
    F.to_timestamp(F.lit(create_follow_timestamps(n_follows))).alias("created_at")
)

# Drop the temporary follow_id column (we don't need it in final table)
follows_final = follows_final.select(
    F.col("following_user_id"),
    F.col("followed_user_id"),
    F.col("created_at")
)

print(f"Writing {n_follows:,} follows to {CATALOG}.{SCHEMA}.follows")
follows_final.write.mode("overwrite").saveAsTable(f"{CATALOG}.{SCHEMA}.follows")

print("\n=== DATA GENERATION COMPLETE ===")
print(f"Generated:")
print(f"- Users: {n_users:,} records")
print(f"- Posts: {n_posts:,} records")
print(f"- Follows: {n_follows:,} records")
print(f"All tables written to {CATALOG}.{SCHEMA} schema")

# Stop Spark session
spark.stop()