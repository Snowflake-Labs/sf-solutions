---
description: >
  List all available Snowflake industry solutions from the sf-solutions repository.
  Scans for manifest.json files and displays a table of installable solutions.
  Use when: browsing solutions, discovering what's available, choosing a demo.
---

# List Available Solutions

Scans the sf-solutions repository for all available solutions and presents them in a table.

## Instructions

### Step 1: Locate Repository

Search for sf-solutions in this order:
1. `~/project/sf-solutions/`
2. Current working directory
3. `./sf-solutions/`

If not found, clone: `git clone https://github.com/Snowflake-Labs/sf-solutions.git /tmp/sf-solutions`

### Step 2: Scan for Solutions

Find all `manifest.json` files in the repository:
```bash
find <repo> -maxdepth 2 -name "manifest.json" -not -path "*/node_modules/*" -not -path "*/.claude-plugin/*"
```

### Step 3: Present Solutions Table

Read each manifest.json and display:

```
Available Snowflake Industry Solutions:

| # | Slug | Name | Industry | Database | Features |
|---|------|------|----------|----------|----------|
| 1 | ltv-prediction | Customer Lifetime Value Prediction | Retail / CPG | SF_SOLUTIONS | Snowflake ML, Cortex AI |
| 2 | manufacturing-predictive-maintenance | Manufacturing Predictive Maintenance | Manufacturing | SF_SOLUTIONS | Cortex Analyst, Streamlit |
| ... | ... | ... | ... | ... | ... |

To install: /snowflake-solutions:install <slug>
To teardown: /snowflake-solutions:teardown <slug>
```

Sort by industry, then alphabetically by name.
