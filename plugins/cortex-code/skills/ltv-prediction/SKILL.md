---
name: ltv-prediction
description: >
  Install or teardown the Customer Lifetime Value Prediction solution.
  Usage: $snowflake-solutions:ltv-prediction | $snowflake-solutions:ltv-prediction teardown
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
- **Features:** Snowflake ML Forecast, Cortex AI Functions (COMPLETE), Customer Segmentation
- **Role Required:** ACCOUNTADMIN

## Install

1. Locate the sf-solutions repository:
   - Check `~/project/sf-solutions/`
   - Check current working directory
   - If not found: `git clone https://github.com/Snowflake-Labs/sf-solutions.git /tmp/sf-solutions`

2. Read `solutions/ltv-prediction/manifest.json`.

3. Query the current account info and present the installation plan together:
   ```sql
   SELECT CURRENT_ORGANIZATION_NAME() AS ORG, CURRENT_ACCOUNT_NAME() AS ACCOUNT, CURRENT_REGION() AS REGION, CURRENT_ROLE() AS ROLE;
   ```
   Show to the user:
   ```
   Solution: Customer Lifetime Value Prediction v2.0.0
   Industry: Retail / CPG
   Database: SF_SOLUTIONS
   Schemas:  LTV_RAW, LTV_ANALYTICS, LTV_ML
   Role:     ACCOUNTADMIN

   Target Account:
     Organization: <ORG>
     Account:      <ACCOUNT>
     Region:       <REGION>
     Current Role: <ROLE>

   What will be created:
     - Raw transaction data from S3 (~108K records)
     - Monthly customer spend time series
     - Snowflake ML Forecast model (per-customer LTV prediction)
     - Customer segments (Platinum/Gold/Silver/Bronze)
     - AI-generated segment insights via Cortex AI
     - Streamlit dashboard

   Proceed with installation?
   ```

4. Wait for user confirmation.

5. Read `solutions/ltv-prediction/scripts/setup.sql` and execute statement by statement using `snowflake_sql_execute`.
   - FORECAST model training: use `timeout_seconds: 600`
   - FORECAST!FORECAST call and the CREATE TABLE from RESULT_SCAN must run consecutively (no query in between)
   - Log progress after each major section

6. Verify:
   ```sql
   SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
   FROM SF_SOLUTIONS.INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA IN ('LTV_RAW', 'LTV_ANALYTICS', 'LTV_ML')
   ORDER BY TABLE_SCHEMA, TABLE_NAME;
   ```

7. **[MANDATORY — DO NOT SKIP]** Retrieve and display the Streamlit dashboard URL.
   Execute this query:
   ```sql
   SELECT 'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
       || '/#/streamlit-apps/SF_SOLUTIONS.LTV_ML.LTV_PREDICTION_DASHBOARD' AS STREAMLIT_URL;
   ```
   Take the value of `STREAMLIT_URL` from the result and display it to the user exactly like this:

   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Streamlit Dashboard:
   <paste the full URL here>
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

   This step is NON-OPTIONAL. The user must always see the clickable URL after install.

8. Show final summary:
   ```
   Installation complete: Customer Lifetime Value Prediction v1.0.0

   Next Actions:
   1. Open the Streamlit dashboard URL above
   2. Query segment insights: SELECT * FROM SF_SOLUTIONS.LTV_ML.SEGMENT_INSIGHTS;
   3. View top customers: SELECT * FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_SEGMENTS WHERE LTV_SEGMENT = 'Platinum' LIMIT 10;

   Teardown: $snowflake-solutions:ltv-prediction teardown
   ```

## Teardown

If `$ARGUMENTS` is "teardown":

1. Confirm with user: "This will drop LTV_RAW, LTV_ANALYTICS, LTV_ML schemas. Proceed?"
2. Read and execute `solutions/ltv-prediction/scripts/teardown.sql` statement by statement.
3. Confirm: "Customer Lifetime Value Prediction removed."

## Next Actions

If the user asks "what next?", "what can I do?", or "how to customize":

Read and present the content from `NEXT_ACTIONS.md` (located in this skill's directory).
Present the relevant section based on user intent:
- Just exploring → Quick Exploration section
- Wants to use own data → Customize with Your Data section
- Wants better accuracy → Tune the Model section
- Ready for production → Production Deployment section

## Usage Help

```
Usage:
  $snowflake-solutions:ltv-prediction           — Install the solution
  $snowflake-solutions:ltv-prediction teardown   — Remove the solution
```
