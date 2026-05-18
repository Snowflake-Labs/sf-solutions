# Enterprise Clearing & Settlement Data Platform

Enterprise-scale clearing and settlement data pipeline using Snowflake Dynamic Tables. Processes 5.1M+ settlement transactions with real-time data quality management, multi-factor risk scoring, and a 4-layer Medallion Architecture.

## Architecture

```
RAW (Bronze)              DATA QUALITY             NORMALIZED (Silver)        CONSUMPTION (Gold)
Static Tables             Dynamic Tables           Dynamic Tables             Dynamic Tables
─────────────────────     ─────────────────────    ─────────────────────      ─────────────────────
Settlement Txns (5.1M+)  Quality Metrics (1min)   Validation (3min)          Risk Monitor (downstream)
Securities Master (25)    Cleansed Txns (3min)     Enrichment (3min)          Daily Dashboard (5min)
Participants (2,847)                               Business Rules (4min)
Transaction Fees (1.9M+)
Market Data (15K+)
```

## Prerequisites

- Snowflake account with ACCOUNTADMIN privileges
- Medium warehouse capacity for 5M+ record data generation (~5-10 min)

## Quick Start

1. Execute setup.sql in a Snowflake SQL worksheet:
   ```sql
   -- Run the entire script (creates DB, schemas, tables, data, and Dynamic Tables)
   -- File: scripts/setup.sql
   ```

2. Deploy Streamlit app:
   ```sql
   USE DATABASE SF_SOLUTIONS;
   USE SCHEMA CLEARING_SETTLEMENT_RAW;

   -- Upload streamlit/ directory contents to STREAMLIT_STAGE
   PUT file://streamlit/streamlit_app.py @STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
   PUT file://streamlit/environment.yml @STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
   PUT file://streamlit/pages/1_Data_Pipeline.py @STREAMLIT_STAGE/pages AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
   PUT file://streamlit/pages/2_Data_Quality.py @STREAMLIT_STAGE/pages AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
   PUT file://streamlit/pages/3_Customer_Products.py @STREAMLIT_STAGE/pages AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

   CREATE OR REPLACE STREAMLIT SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.ENTERPRISE_CLEARING_DASHBOARD
       ROOT_LOCATION = '@SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.STREAMLIT_STAGE'
       MAIN_FILE = 'streamlit_app.py'
       QUERY_WAREHOUSE = 'SF_SOLUTIONS_ANALYTICS_WH';
   ```

3. Open the Streamlit app in Snowsight (Projects > Streamlit Apps).

## Key Metrics

| Metric | Value |
|--------|-------|
| Settlement Transactions | 5,129,375 |
| Financial Participants | 2,847 |
| Transaction Fees | 1,891,256 |
| Dynamic Tables | 7 |
| Pipeline Layers | 4 |
| Quality Score | 99.2% |
| Settlement Success Rate | 99.8% |

## Schemas

| Schema | Purpose |
|--------|---------|
| `CLEARING_SETTLEMENT_RAW` | Raw source data (Bronze) |
| `CLEARING_SETTLEMENT_DQ` | Data quality Dynamic Tables |
| `CLEARING_SETTLEMENT_NORMALIZED` | Business rules pipeline (Silver) |
| `CLEARING_SETTLEMENT_CONSUMPTION` | Analytics-ready output (Gold) |

## Teardown

```sql
-- Run scripts/teardown.sql to remove all solution objects
-- Note: SF_SOLUTIONS database and SF_SOLUTIONS_WH are shared and NOT dropped
```

## License

Apache-2.0
