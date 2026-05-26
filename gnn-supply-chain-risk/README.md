# GNN Supply Chain Risk Intelligence

**AI-Driven N-Tier Supply Chain Resilience using Graph Neural Networks on Snowflake**

## Overview

Modern supply chains are brittle because visibility typically ends at Tier-1 — the direct suppliers. This solution uses Graph Neural Networks (GNN) with PyTorch Geometric to map hidden Tier-2+ supplier dependencies and quantify concentration risk that traditional ERP analytics cannot detect.

## The Business Problem

A manufacturing company may source a critical component from three different vendors across three different countries — and believe their supply chain is resilient. However, all three vendors may unknowingly source their raw materials from the same single refinery. This "Tier-N Blindness" means disruptions at Tier-3 blindside manufacturers weeks later with sudden shortages.

## Solution Architecture

| Component | Technology |
|-----------|------------|
| **Data Platform** | Snowflake (SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK) |
| **ML Runtime** | Snowflake Notebooks with GPU (SPCS GPU_NV_S) |
| **Graph ML** | PyTorch Geometric (GraphSAGE) |
| **AI Assistant** | Cortex Agent with Cortex Analyst |
| **Visualization** | Streamlit in Snowflake (8 pages) |

## Data Model

### Input Tables

| Table | Description | Rows |
|-------|-------------|------|
| `VENDORS` | Tier-1 supplier master data | 50 |
| `MATERIALS` | Parts/products catalog | 26 |
| `PURCHASE_ORDERS` | Supplier-to-material transactions | 120 |
| `BILL_OF_MATERIALS` | Component assembly hierarchy | 23 |
| `TRADE_DATA` | External bills of lading for Tier-2+ inference | 150 |
| `REGIONS` | Geographic risk factors | 9 |

### Output Tables (populated by GNN notebook)

| Table | Description |
|-------|-------------|
| `RISK_SCORES` | GNN-propagated risk scores per node |
| `PREDICTED_LINKS` | Inferred Tier-2+ supplier relationships with probability |
| `BOTTLENECKS` | Single points of failure with impact scores |

## Installation

### Prerequisites

- Snowflake account with ACCOUNTADMIN access
- Snowpark Container Services enabled (for GPU notebook)
- External Access Integration support (for PyPI packages)

> **Note:** If SPCS or EAI is not available, comment out **Sections 13 and 14** in `scripts/setup.sql`. The Streamlit dashboard and Cortex Agent will still work; only the GNN notebook requires SPCS.

### Run Setup

Execute `scripts/setup.sql` in Snowsight using the ACCOUNTADMIN role.

This creates:
- Schema `SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK` with all tables
- Demo data (50 vendors, 26 materials, 120 POs, 150 trade records)
- Analytics views
- `ANALYZE_RISK_SCENARIO` SQL UDF
- Semantic model stage with `supply_chain_risk.yaml`
- GPU compute pool (`GNN_SUPPLY_CHAIN_COMPUTE_POOL`)
- External Access Integration for PyPI
- `SUPPLY_CHAIN_RISK_AGENT` Cortex Agent

### Run the GNN Notebook (required for risk scoring)

After setup, deploy and execute the GNN notebook from `notebooks/gnn_supply_chain_risk.ipynb`. This:

1. Loads ERP + trade data from Snowflake
2. Builds a heterogeneous graph (Vendors, Materials, Regions, External Suppliers)
3. Trains a GraphSAGE model for link prediction
4. Computes propagated risk scores for all nodes
5. Identifies bottlenecks (single points of failure)
6. Writes results to `RISK_SCORES`, `PREDICTED_LINKS`, `BOTTLENECKS`

> Notebook runtime: ~10-15 minutes on first run (GPU cold start adds ~3-5 minutes).

### Deploy Streamlit

Deploy `streamlit/` as a Streamlit in Snowflake app using the Snowflake CLI or Snowsight UI.

## Streamlit Dashboard Pages

| Page | Description |
|------|-------------|
| **Home** | Storytelling landing page with concentration risk visualization |
| **Executive Summary** | Portfolio health scores and strategic KPIs |
| **Exploratory Analysis** | Data coverage and visibility gap analysis |
| **Supply Network** | Interactive multi-tier graph visualization |
| **Tier-2 Analysis** | GNN-predicted hidden links and bottleneck deep-dive |
| **Scenario Simulator** | What-if disruption analysis |
| **Command Center** | Operational monitoring and alerts |
| **Risk Mitigation** | Prioritized actions with AI-assisted analysis |
| **About** | Technical documentation |

## Cortex Agent

The `SUPPLY_CHAIN_RISK_AGENT` answers natural language questions using:

- **`SUPPLY_CHAIN_ANALYTICS`** — Cortex Analyst via semantic model for structured data queries
- **`RISK_SCENARIO_ANALYZER`** — SQL UDF for scenario simulation (regional disruption, vendor failure, portfolio summary)

Example queries:
- "What is our overall portfolio risk?"
- "Which regions have the highest supply chain risk?"
- "What are our biggest bottlenecks?"
- "Simulate a vendor failure for V10006"

## Teardown

Execute `scripts/teardown.sql` to remove all solution objects. The shared `SF_SOLUTIONS` database and warehouse are preserved.

## License

MIT
