---
description: >
  Manage the GNN Supply Chain Risk Intelligence solution.
  Usage: /snowflake-solutions:gnn-supply-chain-risk install
         /snowflake-solutions:gnn-supply-chain-risk teardown
  AI-driven N-tier supply chain resilience using Graph Neural Networks.
  Triggers: gnn, supply chain risk, graph neural network, tier-2 visibility.
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
- **Features:** Graph Neural Networks, Cortex Agent, Cortex Analyst, Semantic Model, Streamlit in Snowflake
- **Role Required:** ACCOUNTADMIN
- **Note:** GPU Compute Pool and External Access Integration sections are commented out by default (Trial-compatible). Run the lite notebook after install to populate risk scores.

## Install

1. Locate the sf-solutions repository:
   - Check `~/project/sf-solutions/`
   - Check current working directory
   - If not found: `git clone https://github.com/Snowflake-Labs/sf-solutions.git /tmp/sf-solutions`

2. Present the installation plan:
   ```
   Solution: GNN Supply Chain Risk Intelligence v1.0.0
   Industry: Manufacturing
   Database: SF_SOLUTIONS
   Schema:   GNN_SUPPLY_CHAIN_RISK
   Role:     ACCOUNTADMIN

   What will be created:
     - 9 tables (VENDORS, MATERIALS, PURCHASE_ORDERS, BILL_OF_MATERIALS,
       TRADE_DATA, REGIONS, RISK_SCORES, PREDICTED_LINKS, BOTTLENECKS)
     - 4 analytics views
     - ANALYZE_RISK_SCENARIO UDF
     - Cortex Agent (SUPPLY_CHAIN_RISK_AGENT)
     - Semantic model
     - 50 vendors, 150 trade records demo data

   Post-install step:
     Run the lite notebook (notebooks/gnn_supply_chain_risk_lite.ipynb)
     to populate RISK_SCORES, PREDICTED_LINKS, BOTTLENECKS tables.

   Proceed with installation?
   ```

3. Wait for user confirmation.

4. Execute `gnn-supply-chain-risk/scripts/setup.sql` against Snowflake.

5. Verify installation:
   ```sql
   SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
   FROM SF_SOLUTIONS.INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA = 'GNN_SUPPLY_CHAIN_RISK'
   ORDER BY TABLE_NAME;
   ```

6. Show summary:
   ```
   Installed: GNN Supply Chain Risk Intelligence v1.0.0

   Next step: Run the GNN notebook to populate risk scores:
     notebooks/gnn_supply_chain_risk_lite.ipynb
     (or use: CALL SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RUN_RISK_ANALYSIS())

   Streamlit: Deploy streamlit/ directory as Streamlit in Snowflake app.

   Teardown: /snowflake-solutions:gnn-supply-chain-risk teardown
   ```

## Teardown

If `$ARGUMENTS` is "teardown":

1. Confirm with user: "This will drop SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK and all its objects. Proceed?"
2. Execute `gnn-supply-chain-risk/scripts/teardown.sql` against Snowflake.
3. Confirm: "GNN Supply Chain Risk Intelligence removed."

## Usage Help

If `$ARGUMENTS` is not recognized, show:
```
Usage:
  /snowflake-solutions:gnn-supply-chain-risk install    — Install the solution
  /snowflake-solutions:gnn-supply-chain-risk teardown   — Remove the solution
```
