# Snowflake Industry Solutions

A **plugin catalog** for Snowflake industry solution accelerators. Each solution lives in its own dedicated repository; this repo provides the plugin skills that bootstrap and install them into your Snowflake account via Cortex Code or Claude Code.

---

## Solution Catalog

| # | Solution | Industry | Key Features | Repo |
|---|----------|----------|--------------|------|
| 1 | **Customer Lifetime Value Prediction** | Retail / CPG | Snowflake ML Regression, Cortex AI Functions, Customer Segmentation | [sf-solutions-ltv-prediction](https://github.com/Snowflake-Labs/sf-solutions-ltv-prediction) |
| 2 | **Clinical Quality and Patient Safety Agent** | Healthcare | Cortex Agent, Cortex Analyst, Cortex Search (PubMed), Snowflake Intelligence | [sf-solutions-clinical-quality-agent](https://github.com/Snowflake-Labs/sf-solutions-clinical-quality-agent) |
| 3 | **Manufacturing Predictive Maintenance** | Manufacturing | Snowflake Intelligence, Cortex Analyst, Semantic View, Streamlit, SPCS | [sf-solutions-manufacturing-predictive-maintenance](https://github.com/Snowflake-Labs/sf-solutions-manufacturing-predictive-maintenance) |
| 4 | **Supply Chain Intelligence Platform** | Manufacturing | Snowflake Intelligence, Cortex Analyst, Cortex Search, Semantic Model, Streamlit | [sf-solutions-supply-chain-intelligence](https://github.com/Snowflake-Labs/sf-solutions-supply-chain-intelligence) |
| 5 | **GNN Supply Chain Risk Intelligence** | Manufacturing | Graph Neural Networks, PyTorch Geometric, Cortex Agent, SPCS GPU, Streamlit | [sf-solutions-gnn-supply-chain-risk](https://github.com/Snowflake-Labs/sf-solutions-gnn-supply-chain-risk) |

---

## Quick Install (via Cortex Code)

```bash
# Install the plugin
cortex plugin install https://github.com/Snowflake-Labs/sf-solutions.git

# Or load locally during development
cortex --plugin-dir ./plugins/cortex-code
```

Then in a Cortex Code session:

```
$snowflake-solutions:ltv-prediction
$snowflake-solutions:ltv-prediction teardown
```

List all available solutions:

```
$snowflake-solutions:list
```

## Quick Install (via Claude Code)

```bash
# Add the marketplace
claude plugin marketplace add https://github.com/Snowflake-Labs/sf-solutions.git --path plugins/claude-code

# Install the plugin
claude plugin install snowflake-solutions
```

Then run a solution:

```
/snowflake-solutions:ltv-prediction
/snowflake-solutions:ltv-prediction teardown
/snowflake-solutions:list
```

Requires the [snowflake-cortex-code](https://claude.com/plugins/snowflake-cortex-code) plugin (auto-installed as dependency).

---

## Repository Structure

```
sf-solutions/
├── plugins/
│   ├── cortex-code/          # Cortex Code plugin (skills + manifest)
│   │   ├── .cortex-plugin/plugin.json
│   │   └── skills/
│   │       └── <solution-name>/
│   │           ├── SKILL.md
│   │           └── NEXT_ACTIONS.md
│   └── claude-code/          # Claude Code plugin (skills + marketplace manifest)
│       ├── .claude-plugin/
│       │   ├── plugin.json
│       │   └── marketplace.json
│       └── skills/
│           ├── list/SKILL.md
│           └── <solution-name>/
│               ├── SKILL.md
│               └── NEXT_ACTIONS.md
├── hooks/
│   ├── hooks.json                    # CoCo PreToolUse hook config
│   └── allow-solution-commands.sh   # Bash command allowlist
├── CONTRIBUTING.md
└── README.md
```

Each skill clones the corresponding solution repo at invocation time via sparse checkout, so this catalog repo stays lean.

---

## Prerequisites

- Snowflake account (Enterprise edition recommended)
- Appropriate role with `CREATE DATABASE` / `SCHEMA` privileges
- Warehouse (default: `COMPUTE_WH`)

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide on adding a new solution, including the PR checklist and Claude marketplace requirements.

---

## Related Resources

- [Snowflake ML](https://docs.snowflake.com/en/developer-guide/snowflake-ml/overview)
- [Cortex AI Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)
- [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)
- [Snowflake Notebooks](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks)
