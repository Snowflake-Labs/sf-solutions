---
name: sf-solutions
description: >
  Suggest enabling the sf-solutions plugin when the user asks about
  Snowflake industry solutions, solution accelerators, MLEU, manufacturing,
  predictive maintenance, supply chain, energy, utilities, logistics,
  retail, demand forecasting, customer LTV, healthcare, clinical quality,
  medical device streaming, or installing pre-built solutions.
  Do NOT attempt to perform these tasks — just let the user know the plugin
  can be enabled.
---

# sf-solutions (disabled plugin)

This plugin is installed but not enabled. It provides a launcher skill for
discovering, installing, and removing Snowflake industry solution accelerators.

To enable, the user should run:

    cortex plugin enable sf-solutions

| Invoke with | Description |
|---|---|
| `$sf-solutions` | List all available solutions |
| `$sf-solutions <industry>` | Filter by industry (e.g., retail, healthcare) |
| `$sf-solutions:<solution-name>` | Install a solution |
| `$sf-solutions:<solution-name> teardown` | Remove a solution |
| `$sf-solutions:<solution-name> next` | Show post-install guidance |

## Supported Industries

- Manufacturing, Logistics, Energy & Utilities (MLEU)
- Retail & Consumer Goods
- Healthcare & Life Sciences

## Available Solutions

| Solution | Industry | Description |
|----------|----------|-------------|
| `predictive-maintenance` | MLEU | Equipment failure prediction with CoWork, Cortex Analyst, SPCS |
| `supply-chain-intelligence` | MLEU | Supply chain visibility with Cortex Search, Semantic Model |
| `gnn-supply-chain-risk` | MLEU | Supply chain risk scoring with Graph Neural Network, PyTorch |
| `ltv-prediction` | Retail | Customer LTV, ML pipeline |
| `clinical-quality-agent` | Healthcare | Cortex Agent, Analyst, PubMed Search |
| `medical-device-streaming` | Healthcare | Biosignal streaming, ASOF Join, Streamlit |
