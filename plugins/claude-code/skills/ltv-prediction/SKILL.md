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
- **Features:** Snowflake ML Forecast, Cortex AI Functions (COMPLETE), Customer Segmentation
- **Role Required:** ACCOUNTADMIN

## Install

1. Clone or locate the sf-solutions repository:
   ```bash
   git clone https://github.com/Snowflake-Labs/sf-solutions.git /tmp/sf-solutions
   ```
   Or check `~/project/sf-solutions/`, current directory.

2. Read `solutions/ltv-prediction/manifest.json` from the repository.

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
     - Raw transaction data loaded from S3 (~108K records)
     - Monthly customer spend time series
     - Snowflake ML Forecast model (per-customer LTV prediction)
     - Customer segments (Platinum/Gold/Silver/Bronze)
     - AI-generated segment insights via Cortex AI
     - Streamlit dashboard

   Proceed with installation?
   ```

4. Wait for user confirmation.

5. Read `solutions/ltv-prediction/scripts/setup.sql` and execute in BATCHES to minimize round-trips.
   Group independent statements together with semicolons in a single execution:

   **Batch 1 — Setup:** USE ROLE, CREATE DATABASE/SCHEMA/WAREHOUSE (all DDL together)
   **Batch 2 — Load data:** FILE FORMAT, STAGE, CREATE TABLE, COPY INTO
   **Batch 3 — Feature engineering:** CREATE TABLE CUSTOMER_MONTHLY_SPEND + CUSTOMER_FEATURES
   **Batch 4 — FORECAST training:** CREATE SNOWFLAKE.ML.FORECAST (timeout_seconds: 600)
   **Batch 5 — Predictions:** CREATE TABLE LTV_FORECAST_RAW + LTV_PREDICTIONS
   **Batch 6 — Segments + AI:** CREATE VIEW CUSTOMER_SEGMENTS + CREATE TABLE SEGMENT_INSIGHTS (timeout_seconds: 300)
   **Batch 7 — Streamlit deploy:**
   Upload the Streamlit files to the stage and create the app:
   ```bash
   snow sql -q "CREATE STAGE IF NOT EXISTS SF_SOLUTIONS.LTV_ML.STREAMLIT_STAGE DIRECTORY = (ENABLE = TRUE);"
   snow sql -q "PUT file://<repo_path>/solutions/ltv-prediction/streamlit/streamlit_app.py @SF_SOLUTIONS.LTV_ML.STREAMLIT_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
   snow sql -q "PUT file://<repo_path>/solutions/ltv-prediction/streamlit/environment.yml @SF_SOLUTIONS.LTV_ML.STREAMLIT_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
   ```
   Then execute the SQL in `solutions/ltv-prediction/scripts/deploy_streamlit.sql` (CREATE STREAMLIT + ALTER).

   Total: 7 batches instead of ~20 individual statements.

6. Verify installation:
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
   Installation complete: Customer Lifetime Value Prediction v2.0.0

   Next Actions:
   1. Open the Streamlit dashboard URL above
   2. Query segment insights: SELECT * FROM SF_SOLUTIONS.LTV_ML.SEGMENT_INSIGHTS;
   3. View top customers: SELECT * FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_SEGMENTS WHERE LTV_SEGMENT = 'Platinum' LIMIT 10;

   Teardown: /snowflake-solutions:ltv-prediction teardown
   ```

## Teardown

If `$ARGUMENTS` is "teardown":

1. Confirm with user: "This will drop LTV_RAW, LTV_ANALYTICS, LTV_ML schemas. Proceed?"
2. Read and execute `solutions/ltv-prediction/scripts/teardown.sql` from the repository.
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
  /snowflake-solutions:ltv-prediction install    — Install the solution
  /snowflake-solutions:ltv-prediction teardown   — Remove the solution
```
