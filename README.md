# Snowflake Industry Solutions

End-to-end solution accelerators built on Snowflake, Coretex Code, showcasing Cortex AI, Snowflake ML, and the modern data platform.

---

## Solution Catalog

| # | Solution | Industry | Directory | Key Snowflake Features | Status |
|---|----------|----------|-----------|----------------------|--------|
| 1 | **Retail Demand Forecasting & Inventory Optimization** | Retail / CPG | `retail-demand-forecasting/` | Snowflake ML Forecasting, Dynamic Tables | ✅ Done |
| 2 | **Customer Lifetime Value Prediction** | Retail / CPG | `customer-lifetime-value/` | Snowflake ML, Cortex AI Functions, Snowpark | 📋 Planned |
| 3 | **Predictive Maintenance** | Manufacturing | `predictive-maintenance/` | Anomaly Detection, Streams, Dynamic Tables, Snowpark | 📋 Planned |
| 4 | **Anti-Money Laundering (AML) Graph Analytics** | Finance, Public Sector | `aml-graph-analytics/` | Graph Analytics, Cortex Search, Streams | 📋 Planned |
| 5 | **OMOP CDM (Clinical Data Model)** | Life Science / Healthcare | `omop-cdm/` | Snowpark, Data Sharing, dbt | 📋 Planned |
| 6 | **Media Mix Modeling** | Media & Entertainment, Retail | `media-mix-modeling/` | Snowflake ML, Cortex AI Functions, Marketplace | 📋 Planned |
| 7 | **Cybersecurity IOC Matching** | Public Sector, Technology | `cybersecurity-ioc-matching/` | Cortex Search, Streams, Dynamic Tables | 📋 Planned |
| 8 | **GraphRAG** | Technology, Cross-Industry | `graphrag/` | Cortex Search, Cortex LLM, SPCS | 📋 Planned |

---

## Getting Started

Each solution is self-contained in its own directory with:

```
<solution-name>/
├── README.md          # Overview, architecture, prerequisites
├── data/              # Sample data generation scripts
├── models/            # ML model training / SQL logic
└── prompts/           # Demo prompts for Cortex Code / Cloud Agents (EN + JP)
```

## Prerequisites

- Snowflake account (Enterprise edition recommended)
- Appropriate role with CREATE DATABASE / SCHEMA privileges
- Warehouse (default: `COMPUTE_WH`)
