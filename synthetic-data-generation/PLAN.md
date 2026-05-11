# Synthetic Data Generation Plan

## Overview
Generate synthetic data for a social media application with three tables: posts, users, and follows in the `main.social_media_sample` database.

## Steps

### 1. Setup
- Create database `main.social_media_sample` if it doesn't exist
- Set current database to `main.social_media_sample`

### 2. Table Creation
Create three tables with specified schema:

**users table:**
- id: INTEGER PRIMARY KEY
- username: VARCHAR
- role: VARCHAR  
- created_at: TIMESTAMP

**posts table:**
- id: INTEGER PRIMARY KEY
- title: VARCHAR
- body: TEXT
- user_id: INTEGER (FOREIGN KEY to users.id)
- status: VARCHAR
- created_at: TIMESTAMP

**follows table:**
- following_user_id: INTEGER (PART OF PRIMARY KEY)
- followed_user_id: INTEGER (PART OF PRIMARY KEY)
- created_at: TIMESTAMP
- PRIMARY KEY (following_user_id, followed_user_id)

### 3. Data Generation Strategy
Generate data in this order to satisfy foreign key constraints:
1. Generate 500K users
2. Generate 1M posts referencing random users
3. Generate 20K follow relationships between random users

### 4. Implementation Approach
Use Databricks SQL with Python Spark for efficient data generation:

**Users Table Generation:**
- Use `spark.range(500000)` to generate sequential IDs
- Generate random usernames (e.g., "user_" + id)
- Assign random roles from predefined set ('admin', 'moderator', 'user')
- Generate random timestamps within last 2 years

**Posts Table Generation:**
- Use `spark.range(1000000)` to generate sequential IDs
- Generate random titles and bodies using lorem ipsum or similar
- Randomly assign user_id from 1-500000
- Random status from ('active', 'archived', 'deleted')
- Random timestamps

**Follows Table Generation:**
- Generate 20K unique (follower, followed) pairs
- Ensure no self-follows (follower != followed)
- Generate random timestamps

### 5. Validation
- Verify row counts match requirements
- Check foreign key constraints
- Sample data inspection

## Estimated Execution Time
- Users: ~30 seconds
- Posts: ~60 seconds  
- Follows: ~20 seconds
- Total: ~2 minutes

## Requirements
- Databricks Unity Catalog access
- Sufficient compute resources (will use serverless or existing warehouse)