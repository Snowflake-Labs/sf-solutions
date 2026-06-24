---
description: >
  Show next actions after installing GNN Supply Chain Risk Intelligence.
  Guides the user from exploration to GNN notebook deployment.
  Triggers: what next, next steps, what can I do, how to use this, customize, notebook.
---

# Next Actions: GNN Supply Chain Risk Intelligence

After installation, guide the user through these progressive steps.

## Quick Exploration

1. **Access the Cortex Agent**
   - Snowsight: AI & ML > Agents > SUPPLY_CHAIN_RISK_AGENT
   - Start asking questions in natural language

2. **Try risk analysis questions**
   ```
   What is our overall portfolio risk?
   Which regions have the highest supply chain risk?
   What are our biggest bottlenecks?
   Which vendors are single points of failure?
   ```

3. **Try scenario simulation**
   ```
   Simulate a vendor failure for V10006
   What happens if we lose all suppliers in China?
   Show me a portfolio risk summary
   ```

4. **Query risk data directly**
   ```sql
   -- Top bottlenecks by impact score
   SELECT NODE_ID, NODE_TYPE, IMPACT_SCORE, AFFECTED_MATERIALS, AFFECTED_VENDORS
   FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.BOTTLENECKS
   ORDER BY IMPACT_SCORE DESC
   LIMIT 10;

   -- Predicted hidden Tier-2+ links
   SELECT SOURCE_ID, TARGET_ID, LINK_TYPE, PROBABILITY, EVIDENCE_SOURCE
   FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.PREDICTED_LINKS
   WHERE PROBABILITY > 0.7
   ORDER BY PROBABILITY DESC;

   -- Risk scores by node
   SELECT NODE_ID, NODE_TYPE, RISK_SCORE, CONCENTRATION_RISK, GEOGRAPHIC_RISK
   FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RISK_SCORES
   ORDER BY RISK_SCORE DESC
   LIMIT 20;
   ```

## GNN Notebook (Optional — requires SPCS)

5. **Deploy the PyTorch Geometric notebook for advanced risk scoring**

   If SPCS and EAI were enabled during install:
   - Upload `notebooks/gnn_supply_chain_risk.ipynb` to Snowsight
   - Attach to GPU compute pool `GNN_SUPPLY_CHAIN_COMPUTE_POOL`
   - Run all cells (~10-15 minutes with GPU cold start)

   The notebook:
   1. Builds a heterogeneous graph from ERP + trade data
   2. Trains a GraphSAGE model for link prediction
   3. Computes propagated risk scores
   4. Identifies bottlenecks (single points of failure)
   5. Writes results to RISK_SCORES, PREDICTED_LINKS, BOTTLENECKS

   > If SPCS is not available, `CALL RUN_RISK_SCORING()` provides equivalent results using NetworkX (CPU only).

## Deploy Streamlit Dashboard

6. **Upload and create the Streamlit app**
   ```sql
   USE ROLE ACCOUNTADMIN;
   USE DATABASE SF_SOLUTIONS;
   USE SCHEMA GNN_SUPPLY_CHAIN_RISK;

   CREATE STAGE IF NOT EXISTS STREAMLIT_STAGE DIRECTORY = (ENABLE = TRUE);
   PUT file://<path-to-repo>/solutions/gnn-supply-chain-risk/streamlit/streamlit_app.py @STREAMLIT_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
   PUT file://<path-to-repo>/solutions/gnn-supply-chain-risk/streamlit/environment.yml @STREAMLIT_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

   CREATE OR REPLACE STREAMLIT SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.SUPPLY_CHAIN_RISK_APP
       FROM '@SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.STREAMLIT_STAGE'
       MAIN_FILE = 'streamlit_app.py'
       QUERY_WAREHOUSE = SF_SOLUTIONS_WH;
   ALTER STREAMLIT SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.SUPPLY_CHAIN_RISK_APP ADD LIVE VERSION FROM LAST;
   ```

   The dashboard has 8 pages: Home, Executive Summary, Exploratory Analysis, Supply Network, Tier-2 Analysis, Scenario Simulator, Command Center, Risk Mitigation.

## Customize with Your Data

7. **Replace demo data with your own supply chain data**
   - Your data needs tables matching the schema (VENDORS, MATERIALS, PURCHASE_ORDERS, etc.)
   - Truncate and reload:
   ```sql
   TRUNCATE TABLE SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VENDORS;
   INSERT INTO SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VENDORS
   SELECT * FROM your_database.your_schema.your_vendors;
   ```

8. **Re-run risk scoring after data update**
   ```sql
   CALL SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RUN_RISK_SCORING();
   ```

9. **Update the semantic model**
   - The semantic model YAML is staged at `@SEMANTIC_MODELS/supply_chain_risk.yaml`
   - Modify to reflect your column names and business logic
   - Re-stage and recreate the agent to pick up changes

## Summary

| Phase | Actions |
|-------|---------|
| Explore | Access agent, try risk queries, run scenarios |
| GNN Notebook | Deploy to SPCS GPU for advanced graph-based scoring |
| Streamlit | Deploy 8-page risk intelligence dashboard |
| Customize | Load your data, re-run scoring, update semantic model |
