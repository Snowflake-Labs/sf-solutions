# Supply Chain Intelligence Platform

AI-powered supply chain assistant using Snowflake Intelligence, Cortex Analyst, and Cortex Search. Enables operations managers to query inventory, orders, shipments, and supply chain documentation through natural language.

## Architecture

```
Snowflake Intelligence Agent
├── Cortex Analyst (structured data: 11 tables, semantic model)
│   └── Inventory, Orders, Shipments, Plants, Suppliers, Customers
└── Cortex Search (unstructured: supply chain documentation)
    └── Business processes, policies, KPIs
```

## Prerequisites

- Snowflake account with ACCOUNTADMIN privileges
- Cortex Analyst, Cortex Search, and Snowflake Intelligence enabled in your region

## Quick Start

1. Execute setup.sql in a Snowflake SQL worksheet:
   ```sql
   -- Run the entire script (~2 minutes)
   -- Creates DB, schema, tables, demo data, semantic model, search service, and agent
   ```

2. Access the agent in Snowsight:
   - Navigate to AI & ML > Agents
   - Select `SUPPLY_CHAIN_ASSISTANT`
   - Start asking questions

3. (Optional) Deploy Streamlit app:
   ```sql
   USE DATABASE SF_SOLUTIONS;
   USE SCHEMA SUPPLY_CHAIN_ENTITIES;

   PUT file://streamlit/streamlit_app.py @STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

   CREATE OR REPLACE STREAMLIT SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_APP
       ROOT_LOCATION = '@SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.STREAMLIT_STAGE'
       MAIN_FILE = 'streamlit_app.py'
       QUERY_WAREHOUSE = 'SF_SOLUTIONS_WH';
   ```

## Example Questions

**Data Questions (Cortex Analyst):**
- "How many orders did we receive in the last month?"
- "Which manufacturing plants have low inventory for which raw materials?"
- "Who are our top 5 customers by order value?"
- "What is the total quantity of finished goods in our manufacturing plants?"

**Documentation Questions (Cortex Search):**
- "Explain how shipment tracking works in our business"
- "What are our business lines?"
- "How does our supply chain network operate?"

**Complex Analysis:**
- "Which plants have low inventory AND which plants have excess of the same materials?"
- "Compare the cost of replenishing from a supplier vs transferring from another plant"

## Key Metrics

| Metric | Value |
|--------|-------|
| Tables | 11 |
| Suppliers | 35 |
| Manufacturing Plants | 24 |
| Customers | 40 |
| Products | 40 |
| Raw Materials | 39 |
| Business Lines | 4 (Aerospace, Industrial, Buildings, Energy) |

## Teardown

```sql
-- Run scripts/teardown.sql to remove all solution objects
-- Note: SF_SOLUTIONS database and SF_SOLUTIONS_WH are shared and NOT dropped
```

## License

Apache-2.0
