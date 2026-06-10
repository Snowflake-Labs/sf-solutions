# Snowflake Industry Solutions

End-to-end solution accelerators built on Snowflake, Coretex Code, showcasing Cortex AI, Snowflake ML, and the modern data platform.

---

## Solution Catalog

| # | Solution | Industry | Directory | Key Snowflake Features | Status |
|---|----------|----------|-----------|----------------------|--------|
| 1 | **Customer Lifetime Value Prediction** | Retail / CPG | `ltv-prediction/` | Snowflake ML Regression, Cortex AI Functions | ✅ Done |
| 2 | **Manufacturing Predictive Maintenance** | Manufacturing | `manufacturing-predictive-maintenance/` | Snowflake Intelligence, Cortex Analyst, Semantic View, Streamlit, SPCS | ✅ Done |
| 3 | **Supply Chain Intelligence Platform** | Manufacturing | `supply-chain-intelligence/` | Snowflake Intelligence, Cortex Analyst, Cortex Search, Semantic Model, Streamlit | ✅ Done |
| 4 | **GNN Supply Chain Risk Intelligence** | Manufacturing | `gnn-supply-chain-risk/` | Graph Neural Networks, PyTorch Geometric, Cortex Agent, Cortex Analyst, SPCS GPU, Streamlit | ✅ Done |
| 5 | **Clinical Quality and Patient Safety Agent** | Healthcare | `clinical-quality-agent/` | Cortex Agent, Cortex Analyst, Cortex Search (PubMed), Snowflake Intelligence | ✅ Done |

---

## Quick Install (via Cortex Code)

Install any solution using Cortex Code skills:

```bash
# Add the solution skill
cortex skill add ./plugins/cortex-code/skills/ltv-prediction

# Run the installer (in Cortex Code REPL)
cortex
> $ltv-prediction install
```

## Quick Install (via Claude Code)

```bash
# Add the marketplace
claude plugin marketplace add https://github.com/Snowflake-Labs/sf-solutions.git --path plugins/claude-code

# Install the plugin
claude plugin install snowflake-solutions

# Install a solution
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
