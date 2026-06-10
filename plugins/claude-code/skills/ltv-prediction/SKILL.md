---
description: >
  Manage the Customer Lifetime Value Prediction solution.
  Usage: /snowflake-solutions:ltv-prediction install
         /snowflake-solutions:ltv-prediction teardown
         /snowflake-solutions:ltv-prediction (defaults to install)
  ML-powered customer segmentation and lifetime value prediction.
  Triggers: ltv, lifetime value, customer prediction, retail ML.
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

1. Clone or locate the sf-solutions repository:
   ```bash
   git clone https://github.com/Snowflake-Labs/sf-solutions.git /tmp/sf-solutions
   ```
   Or check `~/project/sf-solutions/`, current directory.

2. Read `ltv-prediction/manifest.json` from the repository.

3. Present the installation plan:
   ```
   Solution: Customer Lifetime Value Prediction v1.0.0
   Industry: Retail / CPG
   Database: SF_SOLUTIONS
   Schemas:  LTV_RAW, LTV_ANALYTICS, LTV_ML
   Role:     ACCOUNTADMIN

   What will be created:
     - Raw transaction data loaded from S3 (~108K records)
     - Customer feature table with 15+ engineered features
     - Snowflake ML Regression model for LTV prediction
     - Customer segments (Platinum/Gold/Silver/Bronze)
     - AI-generated segment insights via Cortex AI

   Proceed with installation?
   ```

4. Wait for user confirmation.

5. Read `ltv-prediction/scripts/setup.sql` from the repository and execute it against Snowflake statement by statement.
   - The ML model training step may take 2-5 minutes (use timeout_seconds: 600)
   - The PREDICT call depends on RESULT_SCAN — execute immediately after

6. Verify installation:
   ```sql
   SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
   FROM SF_SOLUTIONS.INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA IN ('LTV_RAW', 'LTV_ANALYTICS', 'LTV_ML')
   ORDER BY TABLE_SCHEMA, TABLE_NAME;
   ```

7. Show summary:
   ```
   Installed: Customer Lifetime Value Prediction v1.0.0

   Objects created:
     LTV_RAW: ML_LTV_TRANSACTIONS (108K rows)
     LTV_ANALYTICS: CUSTOMER_FEATURES, TRAIN_DATA, TEST_DATA, CUSTOMER_SEGMENTS
     LTV_ML: LTV_PREDICTIONS, SEGMENT_INSIGHTS, LTV_REGRESSION_MODEL

   Try:
     SELECT * FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_SEGMENTS LIMIT 10;

   Teardown: /snowflake-solutions:ltv-prediction teardown
   ```

## Teardown

If `$ARGUMENTS` is "teardown":

1. Confirm with user: "This will drop LTV_RAW, LTV_ANALYTICS, LTV_ML schemas. Proceed?"
2. Read and execute `ltv-prediction/scripts/teardown.sql` from the repository.
3. Confirm: "Customer Lifetime Value Prediction removed."

## Usage Help

```
Usage:
  /snowflake-solutions:ltv-prediction install    — Install the solution
  /snowflake-solutions:ltv-prediction teardown   — Remove the solution
```
