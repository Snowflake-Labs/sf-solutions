---
name: manufacturing-predictive-maintenance
description: >
  Install or teardown the Manufacturing Predictive Maintenance solution.
  Usage: $snowflake-solutions:manufacturing-predictive-maintenance | $snowflake-solutions:manufacturing-predictive-maintenance teardown
  Triggers: manufacturing, predictive maintenance, IoT, sensor, equipment health, OEE, SPCS.
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Bash
  - Read
  - Glob
  - Grep
  - WebFetch
---

# Manufacturing Predictive Maintenance

Parse the action from `$ARGUMENTS`:
- If `$ARGUMENTS` is "install" or empty → run **Install** flow
- If `$ARGUMENTS` is "teardown" → run **Teardown** flow
- Otherwise → show usage help

## Overview

- **Industry:** Manufacturing
- **Database:** SF_SOLUTIONS
- **Schemas:** MPM_BRONZE, MPM_SILVER, MPM_GOLD
- **Features:** Snowflake Intelligence, Cortex Analyst, Semantic View, Streamlit in Snowflake, SPCS
- **Role Required:** ACCOUNTADMIN
- **Source:** [sfguide-getting-started-with-predictive-maintenance](https://github.com/Snowflake-Labs/sfguide-getting-started-with-predictive-maintenance)

## Install

1. Locate the sf-solutions repository:
   - Check `~/project/sf-solutions/`
   - Check current working directory
   - If not found: `git clone https://github.com/Snowflake-Labs/sf-solutions.git /tmp/sf-solutions`

2. Read `solutions/manufacturing-predictive-maintenance/manifest.json`.

3. Present the installation plan:
   ```
   Solution: Manufacturing Predictive Maintenance v1.0.0
   Industry: Manufacturing
   Database: SF_SOLUTIONS
   Schemas:  MPM_BRONZE, MPM_SILVER, MPM_GOLD
   Role:     ACCOUNTADMIN

   What will be created:
     - Medallion architecture (Bronze/Silver/Gold) with IoT telemetry data
     - ~160K+ telemetry records across 18 assets and 3 facilities
     - Dimensional star schema (fact + dimension tables)
     - Semantic View for Cortex Analyst natural language queries
     - Cortex Agent (PREDICTIVE_MAINTENANCE_ASSISTANT) for Snowflake Intelligence
     - Warehouses: SF_SOLUTIONS_WH, SF_SOLUTIONS_STREAMLIT_WH

   Proceed with installation?
   ```

4. Wait for user confirmation.

5. Read `solutions/manufacturing-predictive-maintenance/scripts/setup.sql` and execute statement by statement using `snowflake_sql_execute`.
   - Data generation may take several minutes: use `timeout_seconds: 600`
   - Log progress after each major section (Bronze, Silver, Gold, Semantic View, Agent)

6. Verify:
   ```sql
   SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
   FROM SF_SOLUTIONS.INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA IN ('MPM_BRONZE', 'MPM_SILVER', 'MPM_GOLD')
   ORDER BY TABLE_SCHEMA, TABLE_NAME;
   ```

7. **[MANDATORY — DO NOT SKIP]** Retrieve and display the Snowflake Intelligence Agent URL.
   Execute this query to get the correct URL for the current account:
   ```sql
   SELECT
       CASE
           WHEN CURRENT_ORGANIZATION_NAME() IS NOT NULL AND CURRENT_ORGANIZATION_NAME() != ''
           THEN 'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
           ELSE 'https://app.snowflake.com/' || LOWER(REPLACE(REPLACE(REPLACE(CURRENT_REGION(), 'AWS_', ''), 'AZURE_', ''), '_', '-')) || '/' || LOWER(CURRENT_ACCOUNT())
       END || '/#/agents/database/SNOWFLAKE_INTELLIGENCE/schema/AGENTS/agent/PREDICTIVE_MAINTENANCE_ASSISTANT/details' AS AGENT_URL;
   ```
   Display it to the user:
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Snowflake Intelligence Agent:
   <paste the full URL here>
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

   This step is NON-OPTIONAL. The user must always see the Agent URL after install.

8. Show final summary:
   ```
   Installation complete: Manufacturing Predictive Maintenance v1.0.0

   Next Actions:
   1. Open the Snowflake Intelligence Agent URL above
   2. Try: "Show me assets with health scores below 70"
   3. Try: "What are the total maintenance costs this month?"
   4. Try: "Which assets are predicted to fail in the next 30 days?"
   5. (Optional) Deploy Streamlit dashboard from source repo

   Teardown: $snowflake-solutions:manufacturing-predictive-maintenance teardown
   ```

## Teardown

If `$ARGUMENTS` is "teardown":

1. Confirm with user: "This will drop the SF_SOLUTIONS database, warehouses, and role. Proceed?"
2. Read and execute `solutions/manufacturing-predictive-maintenance/scripts/teardown.sql` statement by statement.
3. Confirm: "Manufacturing Predictive Maintenance removed."

## Next Actions

If the user asks "what next?", "what can I do?", or "how to customize":

Read and present the content from `NEXT_ACTIONS.md` (located in this skill's directory).
Present the relevant section based on user intent:
- Just exploring → Quick Exploration section
- Wants to use own data → Customize with Your Data section
- Wants to extend → Extend the Solution section
- Ready for production → Production Deployment section

## Usage Help

```
Usage:
  $snowflake-solutions:manufacturing-predictive-maintenance           — Install the solution
  $snowflake-solutions:manufacturing-predictive-maintenance teardown   — Remove the solution
```
