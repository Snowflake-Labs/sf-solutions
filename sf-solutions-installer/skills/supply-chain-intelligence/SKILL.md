---
description: >
  Manage the Supply Chain Intelligence Platform solution.
  Usage: /snowflake-solutions:supply-chain-intelligence install
         /snowflake-solutions:supply-chain-intelligence teardown
  Cortex Agent with Analyst + Search for supply chain optimization.
  Triggers: supply chain intelligence, cortex agent, supply chain optimization.
---

# Supply Chain Intelligence Platform

Parse the action from `$ARGUMENTS`:
- If `$ARGUMENTS` is "install" or empty → run **Install** flow
- If `$ARGUMENTS` is "teardown" → run **Teardown** flow
- Otherwise → show usage help

## Overview

- **Industry:** Manufacturing
- **Database:** SF_SOLUTIONS
- **Schema:** SUPPLY_CHAIN_ENTITIES
- **Features:** Snowflake Intelligence, Cortex Analyst, Cortex Search, Semantic Model, Streamlit in Snowflake
- **Role Required:** ACCOUNTADMIN

## Install

1. Locate the sf-solutions repository.

2. Present the installation plan:
   ```
   Solution: Supply Chain Intelligence Platform v1.0.0
   Industry: Manufacturing
   Database: SF_SOLUTIONS
   Schema:   SUPPLY_CHAIN_ENTITIES
   Role:     ACCOUNTADMIN

   What will be created:
     - 11 supply chain tables (suppliers, orders, materials, etc.)
     - ~1100 rows of demo data
     - Cortex Search service (pre-chunked PDF data)
     - Cortex Agent (SUPPLY_CHAIN_ASSISTANT)
     - Semantic model for Cortex Analyst
     - Streamlit app

   Proceed with installation?
   ```

3. Wait for user confirmation.

4. Execute `supply-chain-intelligence/scripts/setup.sql` against Snowflake.
   - Expected runtime: 1-3 minutes

5. Verify installation:
   ```sql
   SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
   FROM SF_SOLUTIONS.INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA = 'SUPPLY_CHAIN_ENTITIES'
   ORDER BY TABLE_NAME;
   ```

6. Show summary:
   ```
   Installed: Supply Chain Intelligence Platform v1.0.0

   Agent: SUPPLY_CHAIN_ASSISTANT
     → Open in Snowflake Intelligence: AI & ML > Agents

   Streamlit: Deploy streamlit/ directory as Streamlit in Snowflake app.

   Teardown: /snowflake-solutions:supply-chain-intelligence teardown
   ```

## Teardown

If `$ARGUMENTS` is "teardown":

1. Confirm with user.
2. Execute `supply-chain-intelligence/scripts/teardown.sql` against Snowflake.
3. Confirm removal.

## Usage Help

```
Usage:
  /snowflake-solutions:supply-chain-intelligence install    — Install the solution
  /snowflake-solutions:supply-chain-intelligence teardown   — Remove the solution
```
