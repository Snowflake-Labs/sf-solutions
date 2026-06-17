---
name: supply-chain-intelligence
description: >
  Install or teardown the Supply Chain Intelligence Platform solution.
  Usage: $snowflake-solutions:supply-chain-intelligence | $snowflake-solutions:supply-chain-intelligence teardown
  Triggers: supply chain, inventory, manufacturing, cortex agent, intelligence, orders, shipments.
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Bash
  - Read
  - Glob
  - Grep
  - WebFetch
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

1. Locate the sf-solutions repository:
   - Check `~/project/sf-solutions/`
   - Check current working directory
   - If not found: `git clone https://github.com/Snowflake-Labs/sf-solutions.git /tmp/sf-solutions`

2. Read `solutions/supply-chain-intelligence/manifest.json`.

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
   Group independent statements together with semicolons in a single `snowflake_sql_execute` call:

   **Batch 1 — Setup (DDL infrastructure):**
   ```sql
   USE ROLE ACCOUNTADMIN;
   ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"supply_chain_intelligence_platform","version":{"major":1,"minor":0},"attributes":{"is_quickstart":1,"source":"sql"}}';
   CREATE DATABASE IF NOT EXISTS SF_SOLUTIONS;
   CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES;
   CREATE WAREHOUSE IF NOT EXISTS SF_SOLUTIONS_WH WAREHOUSE_SIZE='LARGE' AUTO_SUSPEND=60 AUTO_RESUME=TRUE;
   USE WAREHOUSE SF_SOLUTIONS_WH;
   USE DATABASE SF_SOLUTIONS;
   USE SCHEMA SUPPLY_CHAIN_ENTITIES;
   CREATE STAGE IF NOT EXISTS SEMANTIC_STAGE ENCRYPTION=(TYPE='SNOWFLAKE_SSE') DIRECTORY=(ENABLE=TRUE);
   CREATE STAGE IF NOT EXISTS SCN_PDF ENCRYPTION=(TYPE='SNOWFLAKE_SSE') DIRECTORY=(ENABLE=TRUE);
   CREATE STAGE IF NOT EXISTS STREAMLIT_STAGE DIRECTORY=(ENABLE=TRUE) COMMENT='Stage for Supply Chain Streamlit app';
   CREATE FILE FORMAT IF NOT EXISTS CSVFORMAT SKIP_HEADER=1 FIELD_OPTIONALLY_ENCLOSED_BY='"' TYPE='CSV';
   ```

   **Batch 2 — Table DDL (Section 2):**
   Execute all 11 CREATE TABLE statements (SUPPLIERS, BILL_OF_MATERIALS, COMPONENT, PRODUCT, MFG_PLANT, MFG_INVENTORY, CUSTOMER, SHIPMENT, ORDERS, RAW_MATERIAL, TRANSPORT_COST_SURCHARGE, CONVERSATION_HISTORY).

   **Batch 3 — Demo Data + Date Normalization (Sections 3-4):**
   Read `solutions/supply-chain-intelligence/scripts/data.sql` and execute each INSERT/UPDATE statement via `sql_execute`. Group multiple statements per call where possible. Use `timeout_seconds: 300` per call.

   **Batch 4 — Semantic Model (Section 5):**
   Upload the semantic model YAML to the stage:
   ```sql
   PUT file://<repo_path>/solutions/supply-chain-intelligence/semantic/supply_chain_network.yaml @SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SEMANTIC_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
   ALTER STAGE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SEMANTIC_STAGE REFRESH;
   ```

   **Batch 5 — Cortex Search + Agent (Sections 6-7):**
   ```sql
   CREATE OR REPLACE CORTEX SEARCH SERVICE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_INFO ...;
   CREATE OR REPLACE AGENT SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_ASSISTANT ...;
   ```
   Use `timeout_seconds: 300`.

   **Batch 6 — Streamlit deploy:**
   Upload the Streamlit files to the stage:
   ```sql
   CREATE STAGE IF NOT EXISTS SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.STREAMLIT_STAGE DIRECTORY = (ENABLE = TRUE);
   PUT file://<repo_path>/solutions/supply-chain-intelligence/streamlit/streamlit_app.py @SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.STREAMLIT_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
   PUT file://<repo_path>/solutions/supply-chain-intelligence/streamlit/environment.yml @SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.STREAMLIT_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
   ```
   Then create the Streamlit app:
   ```sql
   CREATE OR REPLACE STREAMLIT SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_APP
       FROM '@SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.STREAMLIT_STAGE'
       MAIN_FILE = 'streamlit_app.py'
       QUERY_WAREHOUSE = SF_SOLUTIONS_WH;
   ALTER STREAMLIT SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_APP ADD LIVE VERSION FROM LAST;
   ```

   **Batch 7 — Verification (Section 8):**
   ```sql
   SELECT
       'Supply Chain Intelligence Platform deployed successfully!' AS STATUS,
       (SELECT COUNT(*) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLIERS) AS SUPPLIERS,
       (SELECT COUNT(*) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.MFG_PLANT) AS PLANTS,
       (SELECT COUNT(*) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.MFG_INVENTORY) AS INVENTORY_RECORDS,
       (SELECT COUNT(*) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.ORDERS) AS ORDERS,
       (SELECT COUNT(*) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.CUSTOMER) AS CUSTOMERS;
   ```

   Total: 7 batches instead of running the entire script statement by statement.

6. **[MANDATORY — DO NOT SKIP]** Retrieve and display the agent URL and Streamlit URL.
   Execute this query:
   ```sql
   SELECT
       'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
           || '/#/streamlit-apps/SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_APP' AS STREAMLIT_URL;
   ```
   Display to the user:
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Access your Supply Chain Assistant:
     Snowsight: AI & ML > Agents > SUPPLY_CHAIN_ASSISTANT

   Streamlit App (optional):
     <STREAMLIT_URL>
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

   This step is NON-OPTIONAL. The user must always see the access information after install.

7. Show final summary:
   ```
   Installation complete: Supply Chain Intelligence Platform v1.0.0

   Next Actions:
   1. Open Snowsight > AI & ML > Agents > SUPPLY_CHAIN_ASSISTANT
   2. Try: "Which manufacturing plants have low inventory for which raw materials?"
   3. Try: "How many orders did we receive in the last month?"

   Teardown: $snowflake-solutions:supply-chain-intelligence teardown
   ```

## Teardown

If `$ARGUMENTS` is "teardown":

1. Confirm with user: "This will drop SUPPLY_CHAIN_ENTITIES schema (all tables, agent, search service). Proceed?"
2. Read and execute `solutions/supply-chain-intelligence/scripts/teardown.sql` statement by statement.
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
  $snowflake-solutions:supply-chain-intelligence           — Install the solution
  $snowflake-solutions:supply-chain-intelligence teardown   — Remove the solution
```
