---
description: >
  Manage the Customer Lifetime Value Prediction solution.
  Usage: /snowflake-solutions:ltv-prediction install
         /snowflake-solutions:ltv-prediction teardown
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
- **Features:** Snowflake ML Regression, Cortex AI Functions (COMPLETE), Customer Segmentation, Feature Engineering
- **Role Required:** ACCOUNTADMIN

## Install

1. Locate the sf-solutions repository.

2. Present the installation plan:
   ```
   Solution: Customer Lifetime Value Prediction v1.0.0
   Industry: Retail / CPG
   Database: SF_SOLUTIONS
   Schemas:  LTV_RAW, LTV_ANALYTICS, LTV_ML
   Role:     ACCOUNTADMIN

   What will be created:
     - 3 schemas with tables for raw data, analytics, and ML models
     - Snowflake ML regression model for LTV prediction
     - Cortex AI function for customer segmentation

   Proceed with installation?
   ```

3. Wait for user confirmation.

4. Execute `ltv-prediction/scripts/setup.sql` against Snowflake.

5. Verify installation:
   ```sql
   SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
   FROM SF_SOLUTIONS.INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA IN ('LTV_RAW', 'LTV_ANALYTICS', 'LTV_ML')
   ORDER BY TABLE_SCHEMA, TABLE_NAME;
   ```

6. Show summary with next steps.

## Teardown

If `$ARGUMENTS` is "teardown":

1. Confirm with user.
2. Execute `ltv-prediction/scripts/teardown.sql` against Snowflake.
3. Confirm removal.

## Usage Help

```
Usage:
  /snowflake-solutions:ltv-prediction install    — Install the solution
  /snowflake-solutions:ltv-prediction teardown   — Remove the solution
```
