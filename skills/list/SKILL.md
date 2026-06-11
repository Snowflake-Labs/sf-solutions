---
name: list
description: >
  Lists all available Snowflake industry solutions in the catalog.
  Use when: "list solutions", "what solutions are available", "show solutions",
  "show catalog", "what can I install", "available solutions",
  "$snowflake-solutions:list", "what snowflake solutions exist".
tools:
  - Read
---

# List Available Solutions

## Routing

| Invocation | Action |
|---|---|
| `$snowflake-solutions:list` | Present full catalog |

## Instructions

Present the following solution catalog:

| # | Slug | Name | Industry | Key Features | Repo |
|---|------|------|----------|--------------|------|
| 1 | ltv-prediction | Customer Lifetime Value Prediction | Retail / CPG | Snowflake ML Regression, Cortex AI Functions, Customer Segmentation | [sf-solutions-ltv-prediction](https://github.com/Snowflake-Labs/sf-solutions-ltv-prediction) |
| 2 | clinical-quality-agent | Clinical Quality and Patient Safety Agent | Healthcare | Cortex Agent, Cortex Analyst, Cortex Search (PubMed), Snowflake Intelligence | [sf-solutions-clinical-quality-agent](https://github.com/Snowflake-Labs/sf-solutions-clinical-quality-agent) |
| 3 | manufacturing-predictive-maintenance | Manufacturing Predictive Maintenance | Manufacturing | Snowflake Intelligence, Cortex Analyst, Semantic View, Streamlit, SPCS | [sf-solutions-manufacturing-predictive-maintenance](https://github.com/Snowflake-Labs/sf-solutions-manufacturing-predictive-maintenance) |
| 4 | supply-chain-intelligence | Supply Chain Intelligence Platform | Manufacturing | Snowflake Intelligence, Cortex Analyst, Cortex Search, Semantic Model, Streamlit | [sf-solutions-supply-chain-intelligence](https://github.com/Snowflake-Labs/sf-solutions-supply-chain-intelligence) |
| 5 | gnn-supply-chain-risk | GNN Supply Chain Risk Intelligence | Manufacturing | Graph Neural Networks, PyTorch Geometric, Cortex Agent, SPCS GPU, Streamlit | [sf-solutions-gnn-supply-chain-risk](https://github.com/Snowflake-Labs/sf-solutions-gnn-supply-chain-risk) |

After the table, add:

```
To install a solution:
  $snowflake-solutions:<slug>

Examples:
  $snowflake-solutions:ltv-prediction
  $snowflake-solutions:ltv-prediction teardown
  $snowflake-solutions:ltv-prediction next

To add a new solution to this catalog:
  $snowflake-solutions:add-solution
```
