---
name: ltv-prediction
description: >
  Install or teardown the Customer Lifetime Value Prediction solution.
  Usage: $ltv-prediction install | $ltv-prediction teardown
  Triggers: ltv, lifetime value, customer prediction, retail ML.
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Bash
  - Read
  - Glob
  - Grep
  - WebFetch
---

# Customer Lifetime Value Prediction

Parse the action from `$ARGUMENTS`:
- If `$ARGUMENTS` is "install" or empty → run **Install** flow
- If `$ARGUMENTS` is "teardown" → run **Teardown** flow
- Otherwise → show usage help

## Overview

- **Industry:** Retail / CPG
- **Database:** SF_SOLUTIONS
- **Schemas:** LTV_RAW, LTV_ANALYTICS, LTV_ML
- **Features:** Snowflake ML Regression, Cortex AI Functions (COMPLETE), Customer Segmentation
- **Role Required:** ACCOUNTADMIN

## Install

1. Locate the sf-solutions repository:
   - Check `~/project/sf-solutions/`
   - Check current working directory
   - If not found: `git clone https://github.com/Snowflake-Labs/sf-solutions.git /tmp/sf-solutions`

2. Read `solutions/ltv-prediction/manifest.json`.

3. Present the installation plan:
   ```
   Solution: Customer Lifetime Value Prediction v1.0.0
   Industry: Retail / CPG
   Database: SF_SOLUTIONS
   Schemas:  LTV_RAW, LTV_ANALYTICS, LTV_ML
   Role:     ACCOUNTADMIN

   What will be created:
     - Raw transaction data from S3 (~108K records)
     - Customer feature table (15+ engineered features)
     - Snowflake ML Regression model
     - Customer segments (Platinum/Gold/Silver/Bronze)
     - AI-generated segment insights via Cortex AI

   Proceed with installation?
   ```

4. Wait for user confirmation.

5. Read `solutions/ltv-prediction/scripts/setup.sql` and execute statement by statement using `snowflake_sql_execute`.
   - ML model training: use `timeout_seconds: 600`
   - PREDICT call depends on RESULT_SCAN — execute immediately after model call
   - Log progress after each major section

6. Verify:
   ```sql
   SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
   FROM SF_SOLUTIONS.INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA IN ('LTV_RAW', 'LTV_ANALYTICS', 'LTV_ML')
   ORDER BY TABLE_SCHEMA, TABLE_NAME;
   ```

7. Show summary with next steps.

## Teardown

If `$ARGUMENTS` is "teardown":

1. Confirm with user.
2. Read and execute `solutions/ltv-prediction/scripts/teardown.sql` statement by statement.
3. Confirm removal.

## Usage Help

```
Usage:
  $ltv-prediction install    — Install the solution
  $ltv-prediction teardown   — Remove the solution
```
