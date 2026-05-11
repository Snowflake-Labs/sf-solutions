# Retail Demand Forecasting & Inventory Optimization

| | |
|---|---|
| **Solution Name** | Retail Demand Forecasting & Inventory Optimization |
| **Industry** | Retail / Consumer Packaged Goods (CPG) |

An end-to-end Snowflake solution demonstrating **ML-powered demand forecasting** and **automated inventory replenishment** for retail operations.

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

### Step 1. Create sample data

Run the data generation script to populate the database:

```sql
-- Run the data generation script
-- Creates 2+ years of synthetic retail sales (8 stores × 12 products × ~850 days)
-- English version:
@data/01_create_sample_data.sql

-- Japanese version (日本市場データ):
@data/01_create_sample_data_JA.sql
```

### Step 2. Run demo prompts

Once the sample data is created, open Cortex Code and run prompts from the `prompts/` directory.
The prompts will guide you through building the forecast model, generating predictions, and creating inventory alerts interactively.

- English: [`prompts/demo_prompts.md`](prompts/demo_prompts.md)
- 日本語: [`prompts/demo_prompts_JA.md`](prompts/demo_prompts_JA.md)

> **Note:** The files in `models/` (`02_build_forecast_model.sql`, `03_replenishment_alerts.sql`) are reference implementations. The demo prompts will have Cortex Code produce equivalent results interactively.

## Demo Prompt Categories

| Category | Demonstrates |
|----------|-------------|
| Data Exploration | Table discovery, profiling, visualization |
| ML Forecasting | Model build, predict, evaluate |
| Inventory Logic | Alert system, dashboard queries |
| End-to-End | Full pipeline orchestration |

## Data Details

| Table | Rows (approx) | Description |
|-------|---------------|-------------|
| STORES | 8 (EN) / 5 (JA) | Store dimension |
| PRODUCTS | 12 (EN) / 15 (JA) | Product catalog with reorder params & shelf life |
| DAILY_SALES / SALES_HISTORY | ~80,000 | 2023-01 to 2025-04, daily store×product transactions |
| INVENTORY_SNAPSHOT / INVENTORY | 96 (EN) / 75 (JA) | Current stock levels (30% intentionally below reorder point) |

### Sales patterns built into synthetic data:
- **Day-of-week**: Weekends +30-50% vs weekdays
- **Monthly seasonality**: Holiday peak (Dec +40%), summer boost, Jan dip
- **Store volume**: Flagship/大型 2×, Express/小型 0.6× of Standard/中型
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
│   ├── 01_create_sample_data.sql       # Synthetic data (English / US market)
│   └── 01_create_sample_data_JA.sql    # Synthetic data (Japanese / JP market)
├── models/
│   ├── 02_build_forecast_model.sql     # Reference: ML forecasting
│   └── 03_replenishment_alerts.sql     # Reference: Inventory alert logic
└── prompts/
    ├── demo_prompts.md                 # Demo prompts (English)
    └── demo_prompts_JA.md              # Demo prompts (日本語)
```
