---
description: >
  Manage the Supply Chain Intelligence Platform solution.
  Usage: /snowflake-solutions:supply-chain-intelligence install
         /snowflake-solutions:supply-chain-intelligence teardown
         /snowflake-solutions:supply-chain-intelligence (defaults to install)
  AI-powered supply chain assistant using Snowflake Intelligence, Cortex Analyst, and Cortex Search.
  Triggers: supply chain, inventory, manufacturing, cortex agent, intelligence, orders, shipments.
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

1. Clone or locate the sf-solutions repository:
   ```bash
   git clone https://github.com/Snowflake-Labs/sf-solutions.git /tmp/sf-solutions
   ```
   Or check `~/project/sf-solutions/`, current directory.

2. Read `solutions/supply-chain-intelligence/manifest.json` from the repository.

3. Query the current account info and present the installation plan together:
   ```sql
   SELECT CURRENT_ORGANIZATION_NAME() AS ORG, CURRENT_ACCOUNT_NAME() AS ACCOUNT, CURRENT_REGION() AS REGION, CURRENT_ROLE() AS ROLE;
   ```
   Show to the user:
   ```
   Solution: Supply Chain Intelligence Platform v1.0.0
   Industry: Manufacturing
   Database: SF_SOLUTIONS
   Schema:   SUPPLY_CHAIN_ENTITIES
   Role:     ACCOUNTADMIN

   Target Account:
     Organization: <ORG>
     Account:      <ACCOUNT>
     Region:       <REGION>
     Current Role: <ROLE>

   What will be created:
     - 11 tables with demo data (~1,100 rows across suppliers, plants, customers, orders, inventory)
     - Semantic Model (staged YAML for Cortex Analyst)
     - Cortex Search Service (supply chain documentation)
     - Snowflake Intelligence Agent (SUPPLY_CHAIN_ASSISTANT)
     - Streamlit app (optional)

   Proceed with installation?
   ```

4. Wait for user confirmation.

5. Read `solutions/supply-chain-intelligence/scripts/setup.sql` and execute in BATCHES to minimize round-trips.
   Group independent statements together with semicolons in a single execution:

   **Batch 1 — Setup:** USE ROLE, CREATE DATABASE/SCHEMA/WAREHOUSE(LARGE)/Stages/File Format (all DDL together)
   **Batch 2 — Table DDL:** All 11 CREATE TABLE statements
   **Batch 3 — Demo Data + Date Normalization (Sections 3-4):**
   Execute `solutions/supply-chain-intelligence/scripts/data.sql` directly:
   ```bash
   snow sql -f <repo_path>/solutions/supply-chain-intelligence/scripts/data.sql
   ```
   Use timeout 300 seconds.

   **Batch 4 — Semantic Model:**
   Upload the semantic model YAML to the stage:
   ```bash
   snow sql -q "PUT file://<repo_path>/solutions/supply-chain-intelligence/semantic/supply_chain_network.yaml @SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SEMANTIC_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
   snow sql -q "ALTER STAGE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SEMANTIC_STAGE REFRESH;"
   ```
   **Batch 5 — Cortex Search + Agent:** CREATE CORTEX SEARCH SERVICE + CREATE AGENT (timeout_seconds: 300)
   **Batch 6 — Streamlit deploy:**
   Upload the Streamlit files to the stage and create the app:
   ```bash
   snow sql -q "CREATE STAGE IF NOT EXISTS SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.STREAMLIT_STAGE DIRECTORY = (ENABLE = TRUE);"
   snow sql -q "PUT file://<repo_path>/solutions/supply-chain-intelligence/streamlit/streamlit_app.py @SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.STREAMLIT_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
   snow sql -q "PUT file://<repo_path>/solutions/supply-chain-intelligence/streamlit/environment.yml @SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.STREAMLIT_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
   ```
   Then execute the CREATE STREAMLIT:
   ```bash
   snow sql -q "CREATE OR REPLACE STREAMLIT SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_APP FROM '@SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.STREAMLIT_STAGE' MAIN_FILE = 'streamlit_app.py' QUERY_WAREHOUSE = SF_SOLUTIONS_WH;"
   snow sql -q "ALTER STREAMLIT SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_APP ADD LIVE VERSION FROM LAST;"
   ```
   **Batch 7 — Verification:** Final SELECT to confirm row counts

   Total: 7 batches instead of running the entire script statement by statement.

6. Verify installation:
   ```sql
   SELECT
       'Supply Chain Intelligence Platform deployed successfully!' AS STATUS,
       (SELECT COUNT(*) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLIERS) AS SUPPLIERS,
       (SELECT COUNT(*) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.MFG_PLANT) AS PLANTS,
       (SELECT COUNT(*) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.MFG_INVENTORY) AS INVENTORY_RECORDS,
       (SELECT COUNT(*) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.ORDERS) AS ORDERS,
       (SELECT COUNT(*) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.CUSTOMER) AS CUSTOMERS;
   ```

7. **[MANDATORY — DO NOT SKIP]** Retrieve and display access information.
   Execute this query:
   ```sql
   SELECT
       'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
           || '/#/agents/database/SF_SOLUTIONS/schema/SUPPLY_CHAIN_ENTITIES/agent/SUPPLY_CHAIN_ASSISTANT/details' AS AGENT_URL,
       'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
           || '/#/streamlit-apps/SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_APP' AS STREAMLIT_URL;
   ```
   Display to the user:
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Supply Chain Assistant:
     <AGENT_URL>

   Streamlit App (optional):
     <STREAMLIT_URL>
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

   This step is NON-OPTIONAL. The user must always see clickable URLs after install.

8. Show final summary:
   ```
   Installation complete: Supply Chain Intelligence Platform v1.0.0

   Next Actions:
   1. Open Snowsight > AI & ML > Agents > SUPPLY_CHAIN_ASSISTANT
   2. Try: "Which manufacturing plants have low inventory for which raw materials?"
   3. Try: "How many orders did we receive in the last month?"

   Teardown: /snowflake-solutions:supply-chain-intelligence teardown
   ```

## Teardown

If `$ARGUMENTS` is "teardown":

1. Confirm with user: "This will drop SUPPLY_CHAIN_ENTITIES schema (all tables, agent, search service). Proceed?"
2. Read and execute `solutions/supply-chain-intelligence/scripts/teardown.sql` from the repository.
3. Confirm: "Supply Chain Intelligence Platform removed."

## Next Actions

If the user asks "what next?", "what can I do?", or "how to customize":

Read and present the content from `NEXT_ACTIONS.md` (located in this skill's directory).
Present the relevant section based on user intent:
- Just exploring → Quick Exploration section
- Wants to use own data → Customize with Your Data section
- Ready for production → Production Deployment section

## Usage Help

```
Usage:
  /snowflake-solutions:supply-chain-intelligence install    — Install the solution
  /snowflake-solutions:supply-chain-intelligence teardown   — Remove the solution
```
