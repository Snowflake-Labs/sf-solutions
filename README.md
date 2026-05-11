# Snowflake Industry Solutions

End-to-end solution accelerators built on Snowflake, Coretex Code, showcasing Cortex AI, Snowflake ML, and the modern data platform.

---

## Solution Catalog

| # | Solution | Industry | Directory | Key Snowflake Features | Status |
|---|----------|----------|-----------|----------------------|--------|
| 1 | **Retail Demand Forecasting & Inventory Optimization** | Retail / CPG | `retail-demand-forecasting/` | Snowflake ML Forecasting, Dynamic Tables | ✅ Done |
| 2 | **Customer Lifetime Value Prediction** | Retail / CPG | `customer-lifetime-value/` | Snowflake ML, Cortex AI Functions, Snowpark | 📋 Planned |
| 3 | **Predictive Maintenance** | Manufacturing | `predictive-maintenance/` | Anomaly Detection, Streams, Dynamic Tables, Snowpark | ✅ Done |
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

---

## Related Resources

### Web Pages

- [Snowflake ML](https://www.snowflake.com/en/data-cloud/snowflake-ml/) - Integrated set of capabilities for development, MLOps and inference leading with agentic ML
- [Snowflake Notebooks](https://www.snowflake.com/en/data-cloud/notebooks/) - Jupyter-based notebooks in Snowflake Workspaces
- [Cortex Code](https://www.snowflake.com/en/data-cloud/cortex/cortex-code/) - Snowflake's AI native coding agent that boosts ML productivity

### Technical Documentation

- [Cortex Code Documentation](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code) - Getting started with Cortex Code
- [Cortex Code in Snowsight](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-snowsight) - Browser-based experience
- [Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) - Command-line experience
- [Snowflake ML Documentation](https://docs.snowflake.com/en/developer-guide/snowflake-ml/overview) - Official Snowflake ML developer guide
- [Snowflake ML Quickstart](https://quickstarts.snowflake.com/guide/getting-started-with-snowflake-ml/) - Hands-on guides to get started with Snowflake ML
