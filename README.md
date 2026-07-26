# Snowflake Industry Solutions

End-to-end solution accelerators built on Snowflake, Coretex Code, showcasing Cortex AI, Snowflake ML, and the modern data platform.

---

## Solution Catalog

### [sf-hcls-solutions](https://github.com/Snowflake-Labs/sf-hcls-solutions) — Healthcare & Life Sciences

| # | Solution | Description | Key Snowflake Features |
|---|----------|-------------|----------------------|
| 1 | [Clinical Quality Agent](https://github.com/Snowflake-Labs/sf-hcls-solutions/tree/main/solutions/clinical-quality-agent) | AI-powered Cortex Agent for Chief Quality Officers to analyze patient outcomes, infections, mortality rates, and safety indicators using natural language | Cortex Agent, Cortex Analyst, Cortex Search, Notifications |
| 2 | [Medical Device Streaming](https://github.com/Snowflake-Labs/sf-hcls-solutions/tree/main/solutions/medical-device-streaming) | Real-time medical device data streaming platform for ECG, EDA, and PPG biosignal data with live analytics | Snowpipe Streaming, ASOF Joins, Dynamic Tables |

### [sf-mleu-solutions](https://github.com/Snowflake-Labs/sf-mleu-solutions) — Manufacturing, Logistics, Energy & Utilities

| # | Solution | Description | Key Snowflake Features |
|---|----------|-------------|----------------------|
| 1 | [GNN Supply Chain Risk](https://github.com/Snowflake-Labs/sf-mleu-solutions/tree/main/solutions/gnn-supply-chain-risk) | AI-driven N-tier supply chain resilience using Graph Neural Networks. Identifies hidden Tier-2+ supplier dependencies and concentration risks | PyTorch Geometric, GPU Compute (SPCS), Cortex Agent, Semantic Model |
| 2 | [Predictive Maintenance](https://github.com/Snowflake-Labs/sf-mleu-solutions/tree/main/solutions/predictive-maintenance) | Predictive maintenance solution for industrial equipment using Snowflake ML | Snowflake ML, Cortex AI Functions |
| 3 | [Supply Chain Intelligence](https://github.com/Snowflake-Labs/sf-mleu-solutions/tree/main/solutions/supply-chain-intelligence) | Agentic AI platform for supply chain management with multi-agent orchestration | Cortex Agent, Cortex Analyst, Cortex Search, Streamlit |

### [sf-marketing-solutions](https://github.com/Snowflake-Labs/sf-marketing-solutions) — Advertising, AdTech & MarTech

| # | Solution | Description | Key Snowflake Features |
|---|----------|-------------|----------------------|
| 1 | [OpenRTB Analyst Agent](https://github.com/Snowflake-Labs/sf-marketing-solutions/tree/main/solutions/openrtb-analyst-agent) | Programmatic advertising analytics with OpenRTB bid request data and natural language queries | Cortex Agent, Semantic View, Dynamic Tables |
| 2 | [SSP Impression Analytics](https://github.com/Snowflake-Labs/sf-marketing-solutions/tree/main/solutions/ssp-impression-analytics) | SSP impression analytics with Cortex Agent and Semantic View | Cortex Agent, Semantic View |

### [sf-rcg-solutions](https://github.com/Snowflake-Labs/sf-rcg-solutions) — Retail, CPG & General

| # | Solution | Description | Key Snowflake Features |
|---|----------|-------------|----------------------|
| 1 | [Customer Lifetime Value Prediction](https://github.com/Snowflake-Labs/sf-rcg-solutions/tree/main/solutions/ltv-prediction) | Predict customer lifetime value using Snowflake ML regression models | Snowflake ML Regression, Cortex AI Functions |

---

## Quick Install (via Cortex Code)

<!-- TBA: Install method under development -->

```bash
# TBA
```

Then run a solution by name:

```
$sf-solutions:<solution-name>
```

## Getting Started

Each solution is self-contained in its own directory with:

```
<solution-name>/
├── README.md          # Overview, architecture, prerequisites
├── manifest.json      # Solution metadata
├── scripts/
│   ├── setup.sql      # Install script
│   └── teardown.sql   # Cleanup script
└── semantic/          # Semantic models (optional)
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
