# Retail Demand Forecasting & Inventory Optimization

| | |
|---|---|
| **Solution Name** | Retail Demand Forecasting & Inventory Optimization |
| **Industry** | Retail / Consumer Packaged Goods (CPG) |

An end-to-end Snowflake solution demonstrating **ML-powered demand forecasting** and **automated inventory replenishment** for retail operations — built to showcase Cloud Agents / Cortex Code capabilities.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                             SF_SOLUTIONS                                 │
├──────────────────────────┬────────────────────────────┬──────────────────┤
│ RETAIL_DEMAND_FORECAST_  │ RETAIL_DEMAND_FORECAST_    │ RETAIL_DEMAND_   │
│ RAW Schema               │ ANALYTICS Schema           │ FORECAST_ML      │
│                          │                            │                  │
│ • STORES                 │ • WEEKLY_DEMAND            │ • DEMAND_FORECAST│
│ • PRODUCTS               │ • REPLENISHMENT_ALERTS     │   (predictions)  │
│ • DAILY_SALES            │ • ACTIVE_ALERTS            │                  │
│ • INVENTORY_SNAPSHOT     │ • ALERT_SUMMARY_BY_STORE   │ • demand_        │
│                          │ • DAILY_ALERTS (Task)      │   forecast_model │
└──────────────────────────┴────────────────────────────┴──────────────────┘
```

## Quick Start

### 1. Create sample data
```sql
-- Run the data generation script
-- Creates 2+ years of synthetic retail sales (8 stores × 12 products × ~850 days)
@data/01_create_sample_data.sql
```

### 2. Build forecast model
```sql
-- Trains Snowflake ML Forecasting on weekly demand
@models/02_build_forecast_model.sql
```

### 3. Set up inventory alerts
```sql
-- Creates alert logic + automated daily task
@models/03_replenishment_alerts.sql
```


## Demo Prompts

See [`prompts/demo_prompts.md`](prompts/demo_prompts.md) for curated prompts in **English** and **Japanese** that demonstrate Cloud Agents capabilities across:

| Category | Demonstrates |
|----------|-------------|
| Data Exploration | Table discovery, profiling, visualization |
| ML Forecasting | Model build, predict, evaluate |
| Inventory Logic | Alert system, dashboard queries |
| End-to-End | Full pipeline orchestration |

## Data Details

| Table | Rows (approx) | Description |
|-------|---------------|-------------|
| STORES | 8 | Store dimension (NY, Chicago, LA, SF, Austin, Miami, Seattle) |
| PRODUCTS | 12 | Product catalog with reorder params & shelf life |
| DAILY_SALES | ~80,000 | 2023-01 to 2025-04, daily store×product transactions |
| INVENTORY_SNAPSHOT | 96 | Current stock levels (30% intentionally below reorder point) |

### Sales patterns built into synthetic data:
- **Day-of-week**: Weekends +30-50% vs weekdays
- **Monthly seasonality**: Holiday peak (Dec +40%), summer boost, Jan dip
- **Store volume**: Flagship 2×, Express 0.6× of Standard
- **Growth trend**: +5% YoY
- **Random noise**: ±15%

## Prerequisites

- Snowflake account with SYSADMIN role access
- Warehouse (default: COMPUTE_WH)

## File Structure

```
retail-demand-forecasting/
├── README.md
├── data/
│   └── 01_create_sample_data.sql        # Synthetic data generation
├── models/
│   ├── 02_build_forecast_model.sql      # ML forecasting
│   └── 03_replenishment_alerts.sql      # Inventory alert logic
└── prompts/
    └── demo_prompts.md                  # EN + JP demo prompts
```
