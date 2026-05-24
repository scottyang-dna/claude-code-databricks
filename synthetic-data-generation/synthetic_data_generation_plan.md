# Synthetic Data Generation Plan - Social Media Platform

**📍 Output Location: main.social_media_sample**
   Volume: /Volumes/main/social_media_sample/raw_data/

## 📖 Business Story: Viral Video Triggers Platform Growth & Scaling Challenges

A social media platform experiences exponential growth after a user posts a viral video. The sudden surge in activity exposes scaling limitations, leading to:
- **Sudden spike in new user registrations** (500% increase during viral period)
- **Explosive growth in posts and follows** (10x increase in posting/following activity)
- **Engagement metrics show 10x increase during viral period** (likes, shares, comments per post)
- **Some users churn after initial excitement fades** (15% of new viral users leave within 30 days)
- **Demonstrates need for scalable analytics** to understand growth patterns, retention, and platform health

This story demonstrates Databricks' value for:
- Root cause analysis of scaling issues
- Cohort analysis of user retention
- Growth pattern identification
- Predictive analytics for future viral events

## 📊 Table Specifications & Assumptions

| Table | Description | Rows | Key Assumptions & Distributions |
|-------|-------------|------|---------------------------------|
| **users** | Platform user profiles | 500,000 | - **Growth pattern**: Baseline users + viral surge cohort<br>- **Username**: Realistic patterns (first_last, hobby_prefix, etc.)<br>- **Role Distribution**: 80% regular_user, 15% content_creator, 5% influencer<br>- **Creation Timeline**: Non-uniform - viral spike period shows 5x normal registration rate |
| **posts** | User-generated content | 1,000,000 | - **User Relationship**: Many-to-1 (each post belongs to one user)<br>- **Content Patterns**: Mix of text posts, video references, shares<br>- **Viral Impact**: 10x increase in posts/day during viral period<br>- **Status Distribution**: 70% published, 20% draft, 10% archived<br>- **Creation Timeline**: Follows user growth + additional viral posting burst |
| **follows** | User-to-user relationships | 20,000 | - **Relationship Pattern**: Many-to-many (users following other users)<br>- **Power Law Distribution**: 80/20 rule - 20% of users get 80% of follows (influencer effect)<br>- **Temporal Pattern**: Follow bursts during viral period (3x normal rate)<br>- **Reciprocity**: 30% of follows are mutual (both users follow each other)<br>- **Referential Integrity**: Valid foreign keys to users table |

## 📈 Viral Growth Timeline Details

**Timeline Assumptions** (180-day window):
- **Days 1-60**: Baseline growth period
  - User registrations: ~250/day 
  - Posts per day: ~1,500
  - Follows per day: ~80
- **Day 61**: Viral video posted by mid-tier influencer
- **Days 62-75**: Viral explosion period (14 days)
  - User registrations: ~1,500/day (500% increase)
  - Posts per day: ~15,000 (10x increase) 
  - Follows per day: ~400 (5x increase)
  - New user engagement: Very high (3-5 posts/user/day)
- **Days 76-105**: Post-viral adjustment period
  - User registrations: ~500/day (settling to 2x baseline)
  - Posts per day: ~3,000 (settling to 2x baseline)
  - Follows per day: ~120 (settling to 1.5x baseline)
  - **Churn**: 15% of viral-period new users become inactive
- **Days 106-180**: New normal growth
  - Stabilized at elevated baseline levels

## 💰 Business Metrics Embedded in Data

- **User Acquisition Cost**: Implied through growth patterns
- **Content Virality Coefficient**: Posts per user during viral vs baseline
- **Network Effect Strength**: Follows growth vs user growth ratio
- **Retention Rate**: Cohort analysis possible from creation dates + activity patterns
- **Influence Distribution**: Power law visible in follows data

## 🔧 Technical Implementation Approach

1. **Master Tables First**: Generate users table → write to Delta → read back for FK joins
2. **Temporal Patterns**: Use date ranges with non-uniform distributions for viral spike
3. **Referential Integrity**: Ensure all foreign keys reference existing records
4. **Realistic Data**: Use Faker for usernames, text content with appropriate variability
5. **Spark Optimization**: Proper partitioning for serverless execution
6. **Volume Storage**: Write raw parquet files to Unity Catalog volume for maximum flexibility

## 🎯 Data Features to Include

- [x] **Skew (non-uniform distributions)** - Essential for viral growth story
- [x] **Joins (referential integrity)** - Critical for table relationships
- [ ] Bad data injection - Not needed for this business story
- [ ] Multi-language text - English sufficient for demo
- [ ] Incremental mode - Overwrite for clean generation

## ⚠️ Pre-Generation Checklist

- [x] **Catalog confirmed**: main (explicitly selected)
- [x] **Schema confirmed**: social_media_sample (created)
- [x] **Output location shown**: main.social_media_sample
- [x] **Table specification shown**: Above with business story
- [x] **Assumptions confirmed**: Viral growth timeline and distributions
- [x] **Compute preference**: Databricks Connect Serverless (recommended for skill)
- [x] **Data features selected**: Skew and joins enabled

**Ready to proceed with code generation upon your approval.**