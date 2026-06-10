---
description: >
  List all available Snowflake industry solutions.
  Shows a table of installable solutions with their industry, database, and features.
  Triggers: list solutions, what solutions are available, show solutions.
---

# List Available Solutions

## Instructions

1. Clone or locate the sf-solutions repository:
   ```bash
   git clone https://github.com/Snowflake-Labs/sf-solutions.git /tmp/sf-solutions
   ```
   Or check if it exists at `~/project/sf-solutions/` or the current directory.

2. Find all `manifest.json` files under the `solutions/` directory only:
   ```bash
   find <repo>/solutions -maxdepth 2 -name "manifest.json"
   ```

3. Read each manifest and present:
   ```
   Available Snowflake Industry Solutions:

   | # | Slug | Name | Industry | Features |
   |---|------|------|----------|----------|
   | 1 | ltv-prediction | Customer Lifetime Value Prediction | Retail / CPG | Snowflake ML, Cortex AI |
   | ... | ... | ... | ... | ... |

   To install: /snowflake-solutions:<slug>
   ```
