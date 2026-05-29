---
description: >
  Install a pre-built Snowflake industry solution from the sf-solutions repository.
  Reads manifest.json, presents an installation plan, then executes setup SQL against
  your Snowflake account via the snowflake-cortex-code plugin.
  Use when: installing a solution, deploying a demo, setting up an industry accelerator.
---

# Install Snowflake Industry Solution

Installs a pre-built industry solution from the
[sf-solutions](https://github.com/Snowflake-Labs/sf-solutions) repository into the user's Snowflake
account. Each solution contains a `manifest.json` describing its metadata and a
`scripts/` directory with SQL setup files.

## Prerequisites

- The `snowflake-cortex-code` plugin must be installed (provides Snowflake SQL execution)
- User must have ACCOUNTADMIN role (or the role specified in manifest.json)

## Instructions

### Step 0: Parse the Solution Slug

Extract the solution slug from user input: `/snowflake-solutions:install <slug>`

If no slug is provided, run `/snowflake-solutions:list` logic instead (scan for manifest.json files and show available solutions).

### Step 1: Locate the sf-solutions Repository

Search for the repository in this order:
1. `~/project/sf-solutions/`
2. The current working directory (if it contains solution directories with manifest.json)
3. `./sf-solutions/`

If not found locally, clone it:
```bash
git clone https://github.com/Snowflake-Labs/sf-solutions.git /tmp/sf-solutions
```

### Step 2: Read manifest.json and Present Plan

1. Read `<repo>/<slug>/manifest.json`
2. Validate required fields: name, display_name, database, schemas, role, install_scripts
3. Check for `requires_marketplace` — if present, show the marketplace URLs and instruct the user to install them FIRST before proceeding
4. Read `<slug>/README.md` for additional context

**STOP HERE** — Present the installation plan to the user:

```
Solution: <display_name> (v<version>)
Industry: <industry>
Database: <database>
Schemas:  <schemas>
Role:     <role>
Features: <features>

Marketplace prerequisites:
  - <name>: <url> (if requires_marketplace exists)

Scripts to execute:
  1. <install_scripts[0]>

Proceed with installation?
```

Wait for user confirmation before proceeding.

### Step 3: Execute Install Scripts

For each script in `install_scripts`:
1. Read the SQL file content
2. Execute the SQL against Snowflake using the snowflake-cortex-code plugin's SQL execution capability
3. For large scripts (>100 statements), split into logical sections and execute section by section
4. Log progress after each major section:
   - "Created database/schema..."
   - "Tables created..."
   - "Data loaded..."
   - "Agent created..."

**Error handling:**
- "insufficient privileges": Show the required role, ask user to switch
- "object already exists": Ask user whether to skip or drop-and-recreate
- Other errors: Show the error and failing SQL, ask user for guidance

### Step 4: Verify Installation

Run verification queries:
```sql
SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
FROM <database>.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN (<schemas>)
ORDER BY TABLE_SCHEMA, TABLE_NAME;
```

Check that all schemas from manifest.json exist and contain objects.

### Step 5: Post-Install Summary

```
Solution installed: <display_name> v<version>

Objects created:
  Database: <database>
  Schemas:  <list with object counts>
  Tables:   <count> tables (<total rows> total rows)

Features enabled: <features>

Next steps:
  - See README: <slug>/README.md
  - Teardown: /snowflake-solutions:teardown <slug>
```

## Examples

User: /snowflake-solutions:install clinical-quality-agent
Assistant:
1. Finds repo at ~/project/sf-solutions/
2. Reads clinical-quality-agent/manifest.json
3. Shows marketplace prerequisite: PubMed Biomedical Research Corpus (with URL)
4. Presents plan: Database SF_SOLUTIONS, schema CLINICAL_QUALITY_SAFETY, role ACCOUNTADMIN
5. User confirms -> executes scripts/setup.sql
6. Verifies tables, shows row counts
7. Shows summary with next steps
