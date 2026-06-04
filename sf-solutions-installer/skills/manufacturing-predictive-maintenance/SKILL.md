---
description: >
  Manage the Manufacturing Predictive Maintenance solution.
  Usage: /snowflake-solutions:manufacturing-predictive-maintenance install
         /snowflake-solutions:manufacturing-predictive-maintenance teardown
  IoT sensor analytics with predictive failure detection.
  Triggers: predictive maintenance, manufacturing, IoT, sensor analytics.
---

# Manufacturing Predictive Maintenance

Parse the action from `$ARGUMENTS`:
- If `$ARGUMENTS` is "install" or empty → run **Install** flow
- If `$ARGUMENTS` is "teardown" → run **Teardown** flow
- Otherwise → show usage help

## Overview

- **Industry:** Manufacturing
- **Database:** SNOWCORE_INDUSTRIES
- **Schemas:** BRONZE, SILVER, GOLD
- **Features:** Snowflake Intelligence, Cortex Analyst, Semantic View, Streamlit in Snowflake, SPCS
- **Role Required:** ACCOUNTADMIN

## Install

1. Locate the sf-solutions repository.

2. Present the installation plan:
   ```
   Solution: Manufacturing Predictive Maintenance v1.0.0
   Industry: Manufacturing
   Database: SNOWCORE_INDUSTRIES
   Schemas:  BRONZE, SILVER, GOLD
   Role:     ACCOUNTADMIN

   What will be created:
     - Medallion architecture (Bronze/Silver/Gold)
     - IoT sensor data tables
     - Snowflake Intelligence agent
     - Cortex Analyst with Semantic View
     - Streamlit dashboard

   Proceed with installation?
   ```

3. Wait for user confirmation.

4. Execute `manufacturing-predictive-maintenance/scripts/setup.sql` against Snowflake.

5. Verify installation:
   ```sql
   SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
   FROM SNOWCORE_INDUSTRIES.INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA IN ('BRONZE', 'SILVER', 'GOLD')
   ORDER BY TABLE_SCHEMA, TABLE_NAME;
   ```

6. Show summary with next steps.

## Teardown

If `$ARGUMENTS` is "teardown":

1. Confirm with user.
2. Execute `manufacturing-predictive-maintenance/scripts/teardown.sql` against Snowflake.
3. Confirm removal.

## Usage Help

```
Usage:
  /snowflake-solutions:manufacturing-predictive-maintenance install    — Install
  /snowflake-solutions:manufacturing-predictive-maintenance teardown   — Remove
```
