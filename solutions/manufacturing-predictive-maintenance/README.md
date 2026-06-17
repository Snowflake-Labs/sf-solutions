# Manufacturing Predictive Maintenance

| | |
|---|---|
| **Solution Name** | Manufacturing Predictive Maintenance (Snowcore Industries) |
| **Industry** | Manufacturing |

An end-to-end predictive maintenance solution using Snowflake — from ingesting raw IoT sensor telemetry and maintenance logs to building analytics-ready tables, deploying an interactive Streamlit dashboard, and querying with Snowflake CoWork.

## Source

This solution is based on [Getting Started with Predictive Maintenance](https://github.com/Snowflake-Labs/sfguide-getting-started-with-predictive-maintenance) from Snowflake-Labs (MIT License). Refer to the original repository for detailed walkthroughs, Streamlit app code, and notebook guides.

## What's Included

### Data Pipeline (Medallion Architecture)

| Layer | Schema | Contents |
|-------|--------|----------|
| **Bronze** | `MPM_BRONZE` | Raw IoT sensor telemetry, maintenance logs, equipment specs |
| **Silver** | `MPM_SILVER` | Dimensional star schema — fact tables (telemetry, maintenance, production) + dimension tables (assets, facilities, technicians, parts) |
| **Gold** | `MPM_GOLD` | Aggregated asset health metrics, ML feature store, semantic views, business KPIs |

### Key Objects Created

- **Database:** `SF_SOLUTIONS`
- **Warehouses:** `SF_SOLUTIONS_WH`, `SF_SOLUTIONS_STREAMLIT_WH`
- **Role:** `SF_SOLUTIONS_ROLE`
- **~160,000+** telemetry records across 18 assets and 3 facilities
- **12+ months** of maintenance history (Nov 2024 – current)
- **Semantic View** for Cortex Analyst natural language queries
- **Cortex Agent** (`PREDICTIVE_MAINTENANCE_ASSISTANT`) for Snowflake CoWork

### Streamlit Dashboard (6 pages)

| Page | Description |
|------|-------------|
| Executive Summary | Strategic KPIs and high-level insights |
| Fleet Operations Center | Real-time monitoring + AI-powered dispatch (Cortex Analyst) |
| OEE Drill-Down | Equipment effectiveness analysis |
| Financial Risk Drill-Down | Budget tracking and cost analysis |
| Asset Detail | Individual asset inspection and history |
| Line Visualization | Interactive production line maps |

> **Note:** The Streamlit app files are in the [original repository](https://github.com/Snowflake-Labs/sfguide-getting-started-with-predictive-maintenance/tree/main/streamlit). Run `setup.sql` first, then follow the original repo's Step 2–4 to deploy the Streamlit app.

## Quick Start

### Step 1. Run setup script

Execute `scripts/setup.sql` in a Snowsight SQL Worksheet (requires ACCOUNTADMIN):

```sql
-- Run all statements in setup.sql
-- This creates the database, schemas, tables, sample data,
-- semantic view, and Cortex agent
```

### Step 2. (Optional) Deploy Streamlit app

Follow the [original repository instructions](https://github.com/Snowflake-Labs/sfguide-getting-started-with-predictive-maintenance#step-2-upload-streamlit-files-to-stage) to upload and deploy the multi-page Streamlit dashboard.

### Step 3. Use Snowflake CoWork

Open [Snowflake CoWork](https://ai.snowflake.com/) and select the **Predictive Maintenance Analytics Agent** to ask natural language questions:

- "Show me assets with health scores below 70"
- "What are the total maintenance costs this month?"
- "Which assets are predicted to fail in the next 30 days?"

### Cleanup

```sql
-- Remove all created objects
@scripts/teardown.sql
```

## Prerequisites

- Snowflake account with **ACCOUNTADMIN** role
- Account in a region with Cortex models enabled (or cross-region inference enabled)

## File Structure

```
manufacturing-predictive-maintenance/
├── README.md
├── manifest.json
└── scripts/
    ├── setup.sql       # Full setup (3,265 lines) — database, data, semantic view, agent
    └── teardown.sql    # Cleanup — drops database, warehouse, role
```
