---
name: ltv-prediction
description: >
  Installs or tears down the Customer Lifetime Value Prediction solution in Snowflake.
  Use when: "install ltv prediction", "set up ltv", "ltv prediction solution",
  "customer lifetime value demo", "retail ML solution", "ltv teardown",
  "remove ltv prediction", "ltv next actions", "what can I do after ltv",
  "$snowflake-solutions:ltv-prediction", "$snowflake-solutions:ltv-prediction teardown".
  Industry: Retail / CPG. Features: Snowflake ML Regression, Cortex AI COMPLETE, customer segmentation.
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

## Routing

| Invocation | Action |
|---|---|
| `$snowflake-solutions:ltv-prediction` | Install flow |
| `$snowflake-solutions:ltv-prediction teardown` | Teardown flow |
| `$snowflake-solutions:ltv-prediction next` | Present NEXT_ACTIONS.md |

Parse the action from `$ARGUMENTS`:
- If `$ARGUMENTS` is "install" or empty → run **Install** flow
- If `$ARGUMENTS` is "teardown" → run **Teardown** flow
- If `$ARGUMENTS` is "next" → run **Next Actions** flow
- Otherwise → show **Usage Help**

## Overview

- **Industry:** Retail / CPG
- **Database:** SF_SOLUTIONS
- **Schemas:** LTV_RAW, LTV_ANALYTICS, LTV_ML
- **Features:** Snowflake ML Regression, Cortex AI Functions (COMPLETE), Customer Segmentation
- **Role Required:** ACCOUNTADMIN

## Install

1. Clone the solution repository:
   ```bash
   git clone --filter=blob:none --no-checkout \
     https://github.com/Snowflake-Labs/sf-solutions-ltv-prediction.git \
     /tmp/sf-solutions-ltv-prediction
   cd /tmp/sf-solutions-ltv-prediction
   git checkout main -- scripts/ streamlit/ prompts/ manifest.json
   ```

2. Read `/tmp/sf-solutions-ltv-prediction/manifest.json`.

3. Present the installation plan and wait for user confirmation:
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

   Proceed with installation? (yes/no)
   ```

   **STOP — do not execute any SQL until the user confirms.**

4. Read `/tmp/sf-solutions-ltv-prediction/scripts/setup.sql` and execute statement by statement using `snowflake_sql_execute`.
   - ML model training: use `timeout_seconds: 600`
   - PREDICT call depends on RESULT_SCAN — execute immediately after model call
   - Log progress after each major section (e.g., "Loading raw data…", "Training model…")

5. Verify:
   ```sql
   SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
   FROM SF_SOLUTIONS.INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA IN ('LTV_RAW', 'LTV_ANALYTICS', 'LTV_ML')
   ORDER BY TABLE_SCHEMA, TABLE_NAME;
   ```

6. **[MANDATORY — DO NOT SKIP]** Retrieve and display the Streamlit dashboard URL:
   ```sql
   SELECT 'https://app.snowflake.com/'
       || LOWER(CURRENT_ORGANIZATION_NAME()) || '/'
       || LOWER(CURRENT_ACCOUNT_NAME())
       || '/#/streamlit-apps/SF_SOLUTIONS.LTV_ML.LTV_PREDICTION_DASHBOARD'
       AS STREAMLIT_URL;
   ```
   Display the result to the user:
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Streamlit Dashboard:
   <STREAMLIT_URL value here>
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

7. Show final summary:
   ```
   Installation complete: Customer Lifetime Value Prediction v1.0.0

   Objects created:
     LTV_RAW:       ML_LTV_TRANSACTIONS (108K rows)
     LTV_ANALYTICS: CUSTOMER_FEATURES, TRAIN_DATA, TEST_DATA, CUSTOMER_SEGMENTS
     LTV_ML:        LTV_PREDICTIONS, SEGMENT_INSIGHTS, LTV_REGRESSION_MODEL

   Teardown: $snowflake-solutions:ltv-prediction teardown
   ```

8. Read `NEXT_ACTIONS.md` from this skill directory and present the **Quick Exploration** section.

## Teardown

1. Confirm with user: "This will drop schemas LTV_RAW, LTV_ANALYTICS, LTV_ML. Proceed? (yes/no)"
2. **STOP — do not execute until confirmed.**
3. Read and execute `/tmp/sf-solutions-ltv-prediction/scripts/teardown.sql` statement by statement.
4. Confirm: "Customer Lifetime Value Prediction removed."

## Next Actions

Read `NEXT_ACTIONS.md` from this skill directory and present the relevant section:

| User intent | Section |
|---|---|
| Just exploring | Quick Exploration |
| Wants to use own data | Customize with Your Data |
| Wants better accuracy | Tune the Model |
| Ready for production | Production Deployment |

## Error Recovery

| Scenario | Action |
|---|---|
| `git clone` fails (repo not found) | Inform user the solution repo has not been published yet; link to CONTRIBUTING.md |
| SQL error during setup | Stop; show the failing statement and error message; ask user whether to retry or abort |
| ML model training timeout (>600s) | Retry once; if it fails again, suggest scaling up the warehouse size |
| Teardown — object not found | Skip the missing object and continue; list all skipped items in the summary |
| Streamlit URL query returns empty | Show the Snowsight apps URL pattern manually and ask user to locate the app |

## Completion Criteria

Install is complete when all of the following are true:
- `SF_SOLUTIONS.LTV_RAW`, `SF_SOLUTIONS.LTV_ANALYTICS`, `SF_SOLUTIONS.LTV_ML` schemas exist
- `SF_SOLUTIONS.LTV_ML.LTV_REGRESSION_MODEL` is present
- Streamlit dashboard URL has been displayed to the user

## Usage Help

```
Usage:
  $snowflake-solutions:ltv-prediction           — Install the solution
  $snowflake-solutions:ltv-prediction teardown   — Remove the solution
  $snowflake-solutions:ltv-prediction next       — Show next actions and guides
```
