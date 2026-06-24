---
description: >
  Show next actions after installing the Supply Chain Intelligence Platform.
  Guides the user from exploration to production deployment.
  Triggers: what next, next steps, what can I do, how to use this, customize.
---

# Next Actions: Supply Chain Intelligence Platform

After installation, guide the user through these progressive steps from exploration to production.

## Quick Exploration

1. **Access the Intelligence Agent**
   - Snowsight: AI & ML > Agents > SUPPLY_CHAIN_ASSISTANT
   - Start asking questions in natural language

2. **Try data questions (Cortex Analyst)**
   ```
   How many orders did we receive in the last month?
   Which manufacturing plants have low inventory for which raw materials?
   Who are our top 5 customers by order value?
   What is the total quantity of finished goods in our manufacturing plants?
   ```

3. **Try documentation questions (Cortex Search)**
   ```
   Explain how shipment tracking works in our business
   What are our business lines?
   How does our supply chain network operate?
   ```

4. **Try complex analysis**
   ```
   Which plants have low inventory AND which plants have excess of the same materials?
   Compare the cost of replenishing from a supplier vs transferring from another plant
   ```

5. **Query the data directly**
   ```sql
   -- Low inventory alerts
   SELECT MP.MFG_PLANT_NAME, RM.MATERIAL_NAME, MI.QUANTITY_ON_HAND, MI.SAFETY_STOCK_LEVEL
   FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.MFG_INVENTORY MI
   JOIN SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.MFG_PLANT MP ON MI.MFG_PLANT_ID = MP.MFG_PLANT_ID
   JOIN SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.RAW_MATERIAL RM ON MI.MATERIAL_ID = RM.MATERIAL_ID
   WHERE MI.QUANTITY_ON_HAND < MI.SAFETY_STOCK_LEVEL
   ORDER BY MI.QUANTITY_ON_HAND / MI.SAFETY_STOCK_LEVEL ASC;

   -- Order summary by business line
   SELECT C.BUSINESS_LINE, COUNT(*) AS ORDER_COUNT, SUM(O.TOTAL_PRICE) AS TOTAL_REVENUE
   FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.ORDERS O
   JOIN SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.CUSTOMER C ON O.CUSTOMER_ID = C.CUSTOMER_ID
   GROUP BY C.BUSINESS_LINE
   ORDER BY TOTAL_REVENUE DESC;
   ```

## Deploy Streamlit App (Optional)

6. **Upload and create the Streamlit app**
   ```sql
   USE ROLE ACCOUNTADMIN;
   USE DATABASE SF_SOLUTIONS;
   USE SCHEMA SUPPLY_CHAIN_ENTITIES;

   PUT file://<path-to-repo>/solutions/supply-chain-intelligence/streamlit/streamlit_app.py @STREAMLIT_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
   PUT file://<path-to-repo>/solutions/supply-chain-intelligence/streamlit/environment.yml @STREAMLIT_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

   CREATE OR REPLACE STREAMLIT SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_APP
       FROM '@SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.STREAMLIT_STAGE'
       MAIN_FILE = 'streamlit_app.py'
       QUERY_WAREHOUSE = SF_SOLUTIONS_WH;
   ALTER STREAMLIT SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_APP ADD LIVE VERSION FROM LAST;
   ```

## Customize with Your Data

7. **Replace demo data with your own supply chain data**
   - Your data needs tables matching the 11-table schema (SUPPLIERS, MFG_PLANT, CUSTOMER, ORDERS, etc.)
   - Truncate and reload:
   ```sql
   TRUNCATE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLIERS;
   -- Load from your stage or existing tables
   INSERT INTO SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLIERS
   SELECT * FROM your_database.your_schema.your_suppliers;
   ```

8. **Update the semantic model**
   - The semantic model YAML is staged at `@SEMANTIC_STAGE/supply_chain_network.yaml`
   - Modify it to reflect your column names, relationships, and business logic
   - Re-stage and recreate the agent to pick up changes

9. **Extend the Cortex Search content**
   - Add your own supply chain documentation to the `PARSED_PDFS` table
   - Recreate the search service to index new content:
   ```sql
   CREATE OR REPLACE CORTEX SEARCH SERVICE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_INFO
   ON PAGE_CONTENT
   WAREHOUSE = SF_SOLUTIONS_WH
   TARGET_LAG = '1 hour'
   AS (SELECT '' AS PAGE_URL, PAGE_CONTENT, TITLE, RELATIVE_PATH
       FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.PARSED_PDFS);
   ```

## Production Deployment

10. **Schedule data refresh**
    ```sql
    CREATE OR REPLACE TASK SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.REFRESH_INVENTORY
        WAREHOUSE = SF_SOLUTIONS_WH
        SCHEDULE = 'USING CRON 0 6 * * * America/Los_Angeles'
    AS
        -- Pull latest inventory from source systems
        CALL SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.REFRESH_INVENTORY_PROC();
    ```

11. **Grant access to operations team**
    ```sql
    CREATE ROLE IF NOT EXISTS SUPPLY_CHAIN_READER;
    GRANT USAGE ON DATABASE SF_SOLUTIONS TO ROLE SUPPLY_CHAIN_READER;
    GRANT USAGE ON SCHEMA SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES TO ROLE SUPPLY_CHAIN_READER;
    GRANT SELECT ON ALL TABLES IN SCHEMA SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES TO ROLE SUPPLY_CHAIN_READER;
    GRANT USAGE ON AGENT SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_ASSISTANT TO ROLE SUPPLY_CHAIN_READER;
    ```

12. **Set up alerts for critical inventory**
    ```sql
    CREATE OR REPLACE ALERT SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.LOW_INVENTORY_ALERT
        WAREHOUSE = SF_SOLUTIONS_WH
        SCHEDULE = 'USING CRON 0 8 * * * America/Los_Angeles'
        IF (EXISTS (
            SELECT 1 FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.MFG_INVENTORY
            WHERE QUANTITY_ON_HAND < SAFETY_STOCK_LEVEL * 0.5
        ))
        THEN
            CALL SYSTEM$SEND_EMAIL(...);
    ```

## Summary

| Phase | Actions |
|-------|---------|
| Explore | Access agent, try example questions, query data |
| Streamlit | Deploy optional chat UI |
| Customize | Load your data, update semantic model, extend search |
| Production | Schedule refresh, RBAC, inventory alerts |
