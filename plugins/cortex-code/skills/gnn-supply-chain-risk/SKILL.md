---
name: gnn-supply-chain-risk
description: >
  Install or teardown the GNN Supply Chain Risk Intelligence solution.
  Usage: $snowflake-solutions:gnn-supply-chain-risk | $snowflake-solutions:gnn-supply-chain-risk teardown
  Triggers: gnn, graph neural network, supply chain risk, tier-2, concentration risk, bottleneck, pytorch geometric.
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Bash
  - Read
  - Glob
  - Grep
  - WebFetch
---

# GNN Supply Chain Risk Intelligence

Parse the action from `$ARGUMENTS`:
- If `$ARGUMENTS` is "install" or empty → run **Install** flow
- If `$ARGUMENTS` is "teardown" → run **Teardown** flow
- Otherwise → show usage help

## Overview

- **Industry:** Manufacturing
- **Database:** SF_SOLUTIONS
- **Schema:** GNN_SUPPLY_CHAIN_RISK
- **Features:** Graph Neural Networks (PyTorch Geometric), SPCS GPU, Cortex Agent, Cortex Analyst, Semantic Model, Streamlit in Snowflake
- **Role Required:** ACCOUNTADMIN
- **Optional:** Snowpark Container Services (GPU compute pool), External Access Integration

## Install

1. Locate the sf-solutions repository:
   - Check `~/project/sf-solutions/`
   - Check current working directory
   - If not found: `git clone https://github.com/Snowflake-Labs/sf-solutions.git /tmp/sf-solutions`

2. Read `solutions/gnn-supply-chain-risk/manifest.json`.

3. Query the current account info and present the installation plan:
   ```sql
   SELECT CURRENT_ORGANIZATION_NAME() AS ORG, CURRENT_ACCOUNT_NAME() AS ACCOUNT, CURRENT_REGION() AS REGION, CURRENT_ROLE() AS ROLE;
   ```
   Show to the user:
   ```
   Solution: GNN Supply Chain Risk Intelligence v1.0.0
   Industry: Manufacturing
   Database: SF_SOLUTIONS
   Schema:   GNN_SUPPLY_CHAIN_RISK
   Role:     ACCOUNTADMIN

   Target Account:
     Organization: <ORG>
     Account:      <ACCOUNT>
     Region:       <REGION>
     Current Role: <ROLE>

   What will be created:
     - 9 tables (VENDORS, MATERIALS, PURCHASE_ORDERS, BILL_OF_MATERIALS, TRADE_DATA, REGIONS, RISK_SCORES, PREDICTED_LINKS, BOTTLENECKS)
     - Demo data (~378 rows: 50 vendors, 26 materials, 120 POs, 150 trade records, 9 regions)
     - 4 analytics views
     - ANALYZE_RISK_SCENARIO SQL UDF
     - Semantic model (staged YAML for Cortex Analyst)
     - Cortex Agent (SUPPLY_CHAIN_RISK_AGENT)
     - RUN_RISK_SCORING stored procedure (NetworkX, no GPU required)
     - [Optional] GPU Compute Pool + External Access Integration (for PyTorch Geometric notebook)

   Proceed with installation?
   ```

4. Wait for user confirmation.

5. Read `solutions/gnn-supply-chain-risk/scripts/setup.sql` and execute in BATCHES:

   **Batch 1 — Infrastructure (Section 1-2):**
   ```sql
   USE ROLE ACCOUNTADMIN;
   CREATE DATABASE IF NOT EXISTS SF_SOLUTIONS;
   CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK;
   USE DATABASE SF_SOLUTIONS;
   USE SCHEMA GNN_SUPPLY_CHAIN_RISK;
   CREATE WAREHOUSE IF NOT EXISTS SF_SOLUTIONS_WH WAREHOUSE_SIZE='LARGE' AUTO_SUSPEND=60 AUTO_RESUME=TRUE;
   USE WAREHOUSE SF_SOLUTIONS_WH;
   ```
   Then create stages (MODELS_STAGE, DATA_STAGE, SEMANTIC_MODELS).

   **Batch 2 — Table DDL (Section 3):**
   Execute all CREATE TABLE statements (VENDORS, MATERIALS, PURCHASE_ORDERS, BILL_OF_MATERIALS, TRADE_DATA, REGIONS + output tables RISK_SCORES, PREDICTED_LINKS, BOTTLENECKS).

   **Batch 3 — Demo Data (Sections 4-9):**
   Execute INSERT statements for VENDORS, MATERIALS, REGIONS, BILL_OF_MATERIALS, PURCHASE_ORDERS, TRADE_DATA.
   Use `timeout_seconds: 300`.

   **Batch 4 — Analytics Views + UDF (Sections 10-11):**
   Execute CREATE VIEW and CREATE FUNCTION statements.

   **Batch 5 — Semantic Model (Section 12):**
   Upload the semantic model YAML to stage. The YAML is inline in setup.sql — execute the PUT/copy statements from the script.

   **Batch 6 — SPCS + EAI (Sections 13-14, OPTIONAL):**
   Ask the user: "Do you want to create the GPU Compute Pool and External Access Integration? (Required for PyTorch Geometric notebook, NOT required for stored procedure risk scoring)"
   - If yes: execute Sections 13-14
   - If no: skip

   **Batch 7 — Cortex Agent + Stored Procedure + Verification (Sections 15-17):**
   ```sql
   CREATE OR REPLACE AGENT SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.SUPPLY_CHAIN_RISK_AGENT ...;
   CREATE OR REPLACE PROCEDURE SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RUN_RISK_SCORING() ...;
   ```
   Then run verification query.
   Use `timeout_seconds: 300`.

6. **Run the risk scoring stored procedure** to populate output tables:
   ```sql
   CALL SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RUN_RISK_SCORING();
   ```
   Use `timeout_seconds: 600`.

7. **[MANDATORY — DO NOT SKIP]** Retrieve and display the agent URL:
   ```sql
   SELECT
       'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
           || '/#/agents/database/SF_SOLUTIONS/schema/GNN_SUPPLY_CHAIN_RISK/agent/SUPPLY_CHAIN_RISK_AGENT/details' AS AGENT_URL;
   ```
   Display to the user:
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Supply Chain Risk Agent:
     <AGENT_URL>
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

   This step is NON-OPTIONAL. The user must always see clickable URLs after install.

8. Show final summary:
   ```
   Installation complete: GNN Supply Chain Risk Intelligence v1.0.0

   Risk scoring completed — RISK_SCORES, PREDICTED_LINKS, and BOTTLENECKS tables populated.

   Next Actions:
   1. Open Snowsight > AI & ML > Agents > SUPPLY_CHAIN_RISK_AGENT
   2. Try: "What is our overall portfolio risk?"
   3. Try: "Which regions have the highest supply chain risk?"
   4. Try: "Simulate a vendor failure for V10006"

   Teardown: $snowflake-solutions:gnn-supply-chain-risk teardown
   ```

## Teardown

If `$ARGUMENTS` is "teardown":

1. Confirm with user: "This will drop GNN_SUPPLY_CHAIN_RISK schema, GPU compute pool, and external access integration. Proceed?"
2. Read and execute `solutions/gnn-supply-chain-risk/scripts/teardown.sql` statement by statement.
3. Confirm: "GNN Supply Chain Risk Intelligence removed."

## Next Actions

If the user asks "what next?", "what can I do?", or "how to customize":

Read and present the content from `NEXT_ACTIONS.md` (located in this skill's directory).
Present the relevant section based on user intent:
- Just exploring → Quick Exploration section
- Wants GNN notebook → GNN Notebook section
- Wants to use own data → Customize with Your Data section

## Usage Help

```
Usage:
  $snowflake-solutions:gnn-supply-chain-risk           — Install the solution
  $snowflake-solutions:gnn-supply-chain-risk teardown   — Remove the solution
```
