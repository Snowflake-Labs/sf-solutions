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

### [sf-rcg-solutions](https://github.com/Snowflake-Labs/sf-rcg-solutions) — Retail, CPG & General

| # | Solution | Description | Key Snowflake Features |
|---|----------|-------------|----------------------|
| 1 | [Customer Lifetime Value Prediction](https://github.com/Snowflake-Labs/sf-rcg-solutions/tree/main/solutions/ltv-prediction) | Predict customer lifetime value using Snowflake ML regression models | Snowflake ML Regression, Cortex AI Functions |

---

## Quick Install (via Cortex Code)

Install any solution using the Cortex Code plugin:

```bash
# TBA: Public install (available after repo goes public)
# cortex plugin install "Snowflake-Labs/sf-solutions/plugins/cortex-code"

# Or load locally during development (reads directly from disk, always up-to-date)
cortex --plugin-dir ./plugins/cortex-code
```

> **Note:** `cortex plugin install` copies the plugin into a local cache. If you add new skills later, you must `cortex plugin uninstall snowflake-solutions && cortex plugin install ...` to refresh. During development, use `--plugin-dir` instead — it always reads the latest files from disk without caching.

Then in a Cortex Code session, run a solution by name:

```
$snowflake-solutions:<solution-name>
```

Example:
```
$snowflake-solutions:ltv-prediction
$snowflake-solutions:ltv-prediction teardown
```

## Quick Install (via Claude Code)

```bash
## Add the marketplace
# TBA: Public install (available after repo goes public)


# Or load locally during development
claude --plugin-dir ./plugins/claude-code
```

Then in a Cortex Code session, run a solution by name:
```
# Install a solution in Claude Code
/snowflake-solutions:ltv-prediction
```

Requires the [snowflake-cortex-code](https://claude.com/plugins/snowflake-cortex-code) plugin (auto-installed as dependency).

---

## Alternative: solutions-installer skill

If you use the [cortex-code-skills](https://github.com/Snowflake-Labs/cortex-code-skills) repository:

```bash
cortex skill add https://github.com/Snowflake-Labs/cortex-code-skills.git
cortex -p "$solutions-install ltv-prediction"
```

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
