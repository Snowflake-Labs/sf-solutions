# Customer Lifetime Value Prediction

| | |
|---|---|
| **Solution Name** | Customer Lifetime Value Prediction |
| **Industry** | Retail / CPG |

An end-to-end Snowflake solution that predicts customer lifetime value using **Snowflake ML Regression** and generates AI-powered segment insights with **Cortex AI Functions** — from loading raw transaction data, engineering customer-level features, training a regression model, segmenting customers into Platinum/Gold/Silver/Bronze tiers, and generating natural language business recommendations per segment.

## What's Included

### Data Pipeline

| Step | Schema | Contents |
|------|--------|----------|
| **Raw Data** | `LTV_RAW` | Transaction data loaded from S3 (customer_id, timestamp, amount, category, channel) |
| **Feature Engineering** | `LTV_ANALYTICS` | Customer-level features (13 features), train/test split views, segment view |
| **ML Predictions** | `LTV_ML` | Regression model predictions with actual vs predicted LTV, AI-generated segment insights |

### Key Objects Created

- **Database:** `SF_SOLUTIONS` (shared, created if not exists)
- **Schemas:** `LTV_RAW`, `LTV_ANALYTICS`, `LTV_ML`
- **Raw transactions** loaded from S3 stage
- **13 customer features:** spend, frequency, recency, tenure, channel mix, category diversity
- **Snowflake ML Regression model** (`LTV_REGRESSION_MODEL`)
- **Customer segments:** Platinum (top 10%), Gold, Silver, Bronze
- **AI Segment Insights** via `SNOWFLAKE.CORTEX.COMPLETE()` — LLM-generated business insights and actionable recommendations per segment

### ML Pipeline

| Component | Description |
|-----------|-------------|
| Target variable | `FUTURE_LTV` — sum of spend in last 20% of time period |
| Train/test split | 80/20 by customer ID hash |
| Model type | `SNOWFLAKE.ML.REGRESSION` (AutoML) |
| Segmentation | Percentile-based: P90 / P70 / P40 cutoffs |
| AI Insights | `SNOWFLAKE.CORTEX.COMPLETE()` generates business insights per segment |

## Quick Start

### Step 1. Run setup script

Execute `scripts/setup.sql` in a Snowsight SQL Worksheet (requires ACCOUNTADMIN):

```sql
-- Runs all steps: data load → features → model training → predictions → segments → AI insights
-- Takes ~2-5 minutes depending on warehouse size
```

### Step 2. Run demo prompts

Run prompts from `prompts/` in Cortex Code to explore data, evaluate the model, and analyze customer segments interactively.

- English: [`prompts/demo_prompts.md`](prompts/demo_prompts.md)
- 日本語: [`prompts/demo_prompts_JA.md`](prompts/demo_prompts_JA.md)

### Cleanup

```sql
@scripts/teardown.sql
```

## Prerequisites

- Snowflake account with **ACCOUNTADMIN** role
- Warehouse (default: `COMPUTE_WH`)

## File Structure

```
ltv-prediction/
├── README.md
├── manifest.json
├── scripts/
│   ├── setup.sql       # Full setup — data load, features, ML model, segments, AI insights
│   └── teardown.sql    # Cleanup — drops LTV schemas
└── prompts/
    ├── demo_prompts.md     # Demo prompts (English)
    └── demo_prompts_JA.md  # Demo prompts (日本語)
```
