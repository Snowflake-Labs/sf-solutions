---
name: convert-solution
description: >
  Convert an industry-plugin-construct plugin directory into the sf-*-solutions format.
  Reads source plugin, adapts to SF_SOLUTIONS conventions, and generates all required files.
  Usage: $sf-solutions:convert-solution <source-plugin-path> [--target <solutions-dir>]
  Triggers: convert solution, import plugin, plugin to solution, industry plugin to solution.
tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Write
  - snowflake_sql_execute
---

# Convert Industry Plugin to Solution

Convert an `industry-plugin-construct` plugin directory into the standard `sf-*-solutions`
format with all required files.

## Input

`$ARGUMENTS` must contain a path to the source plugin directory.

Optionally, `--target <path>` specifies the target solutions directory.
Default target: `../sf-mleu-solutions/solutions`

If no source path provided, ask the user.

## Security Rules (MANDATORY)

Before creating ANY file, these rules are enforced by the `check-no-credentials` hook:

1. **NO CREDENTIALS** — Never include RSA/SSH keys, API tokens, or passwords in committed files.
2. **NO INTERNAL URLS** — No Snowflake internal hostnames (`sfcdev`, `.int.snowflakecomputing.com`).
3. **NO ACCOUNT LOCATORS** — No account-specific URLs (e.g., `xy12345.us-east-1.snowflakecomputing.com`).
4. **PLACEHOLDER ONLY** — Any `.env.example` must use generic placeholders only.

## Phase 0: Select Target Industry Repo

Before analyzing the source, ask the user which industry repo to create the solution in:

```
Which industry repository should this solution be created in?

  1. sf-hcls-solutions    — Healthcare & Life Sciences
  2. sf-mleu-solutions    — Manufacturing, Logistics, Energy & Utilities
  3. sf-rcg-solutions     — Retail, CPG & General

Enter number or path (e.g., ../sf-mleu-solutions/solutions):
```

Set `target_dir` based on the user's selection. Do NOT proceed without confirmation.

## Phase 1: Source Analysis

### 1.1 Parse arguments

```
source_path = first positional argument
target_dir  = selected industry repo path + "/solutions"  (e.g., "../sf-mleu-solutions/solutions")
solution_name = basename of source_path (e.g., "my-solution-name")
output_dir = target_dir / solution_name
```

### 1.2 Read plugin metadata

Read `.cortex-plugin/plugin.json` and extract:

- `name` → solution name (kebab-case)
- `displayName` → display name
- `description` → solution description
- `version` → version
- `keywords` → infer industry label (first domain keyword)

### 1.3 Analyze SQL files

Read all `scripts/*.sql` files. Detect and record:

**Source database names** — any of:
- `CREATE DATABASE <name>`
- `USE DATABASE <name>`
- FQN references `<name>.<schema>.<object>` (where name is not SF_SOLUTIONS)

**Source warehouse names** — any of:
- `CREATE WAREHOUSE <name>`
- `USE WAREHOUSE <name>`

**Object inventory:**
- Schema names (from `CREATE SCHEMA`, `USE SCHEMA`, or FQN)
- Object types present: ROLE, WAREHOUSE, DYNAMIC TABLE, SEMANTIC VIEW, AGENT, CORTEX SEARCH SERVICE, STAGE, UDF, PROCEDURE

### 1.4 Write .convert-meta.json

Write a temporary metadata file that the conformance hook reads:

```json
{
  "source_databases": ["<detected DB names>"],
  "source_warehouses": ["<detected WH names>"],
  "solution_name": "<name>",
  "target_dir": "<output_dir>"
}
```

This file is used by `check-solution-conformance.sh` for generic validation.
Delete it after Phase 4 validation completes.

### 1.5 Inventory other assets

- `skills/` — list skill names
- `agents/` — list agent files
- `references/` — list reference docs
- `hooks/` — note existing hooks
- Check for `scripts/semantic_view.yaml`

### 1.6 Report analysis

```
=== Source Analysis ===
Plugin:         <solution-name>  (v<version>)
Source DB(s):   <SOURCE_DB> → SF_SOLUTIONS
Source WH(s):   <SOURCE_WH> → SF_SOLUTIONS_WH
Schemas:        [inferred from SQL]
Objects:        ROLE, DYNAMIC TABLE x3, SEMANTIC VIEW
Skills:         <skill-1>, <skill-2>, ...
Agents:         <agent-name> (if any)
References:     <N> docs
Semantic YAML:  scripts/semantic_view.yaml ✓
Security scan:  PASS (no credentials detected)
```

## Phase 2: Confirm Mapping

Present the conversion plan and wait for user confirmation:

```
=== Conversion Plan ===
Output:         <output_dir>
DATABASE:       SF_SOLUTIONS  (was: <source_databases>)
WAREHOUSE:      SF_SOLUTIONS_WH  (was: <source_warehouses>)
Schemas:        <list>
Industry:       <inferred from keywords>

Files to create:
  manifest.json
  README.md
  NEXT_ACTIONS.md
  scripts/setup.sql      (merged from: <list of source sql files>)
  scripts/teardown.sql   (generated)
  semantic/<name>.yaml   (if semantic_view.yaml exists)
  plugins/cortex-code/skills/<skill>/SKILL.md  (x N)
  plugins/cortex-code/agents/<agent>.md        (x N)
  plugins/cortex-code/references/<ref>.md      (x N)
  plugins/cortex-code/hooks/                   (copied)

Proceed? (yes/no)
```

Wait for confirmation before writing any files.

## Phase 3: File Generation

### 3.1 Create directory structure

```bash
mkdir -p <output_dir>/scripts
mkdir -p <output_dir>/semantic
mkdir -p <output_dir>/plugins/cortex-code/skills
mkdir -p <output_dir>/plugins/cortex-code/agents
mkdir -p <output_dir>/plugins/cortex-code/references
mkdir -p <output_dir>/plugins/cortex-code/hooks
```

### 3.2 Generate scripts/setup.sql

Merge all `scripts/*.sql` (excluding `semantic_view.yaml`) in this order:
1. Source files sorted alphabetically (setup.sql first if exists)

Apply these transformations to the merged content:

- Replace all occurrences of each `source_databases[i]` → `SF_SOLUTIONS` (case-insensitive)
- Replace all occurrences of each `source_warehouses[i]` → `SF_SOLUTIONS_WH` (case-insensitive)
- Remove or replace `CREATE DATABASE` / `CREATE WAREHOUSE` statements for source names
  with the standard idempotent SF_SOLUTIONS header

Prepend the standard header:
```sql
-- =============================================================================
-- Solution: <display_name>
-- Industry: <industry>
-- Database: SF_SOLUTIONS
-- Schemas:  <list>
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Shared infrastructure (idempotent)
CREATE DATABASE IF NOT EXISTS SF_SOLUTIONS;
CREATE WAREHOUSE IF NOT EXISTS SF_SOLUTIONS_WH
    WITH WAREHOUSE_SIZE = 'LARGE'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE;

USE DATABASE SF_SOLUTIONS;
USE WAREHOUSE SF_SOLUTIONS_WH;
```

Note: If the source SQL includes `PUT` commands, they cannot run in setup.sql.
Document them as manual steps in Phase 3.7 (SKILL.md).

### 3.3 Generate scripts/teardown.sql

Parse setup.sql for `CREATE SCHEMA` statements. For each schema found:

```sql
USE ROLE ACCOUNTADMIN;
-- Drop solution schemas (preserves shared SF_SOLUTIONS database and warehouse)
DROP SCHEMA IF EXISTS SF_SOLUTIONS.<SCHEMA_1> CASCADE;
DROP SCHEMA IF EXISTS SF_SOLUTIONS.<SCHEMA_2> CASCADE;
```

Also include DROP ROLE if a custom role was created:
```sql
DROP ROLE IF EXISTS <ROLE_NAME>;
```

**NEVER** generate `DROP DATABASE SF_SOLUTIONS` or `DROP WAREHOUSE SF_SOLUTIONS_WH`.

### 3.4 Copy semantic YAML

If `scripts/semantic_view.yaml` exists:
- Copy to `<output_dir>/semantic/<solution_name>.yaml`
- Replace source DB/WH references in the YAML with SF_SOLUTIONS / SF_SOLUTIONS_WH

### 3.5 Generate manifest.json

```json
{
  "name": "<plugin.json.name>",
  "display_name": "<plugin.json.displayName>",
  "version": "<plugin.json.version>",
  "industry": "<inferred from keywords>",
  "description": "<plugin.json.description>",
  "source": "",
  "database": "SF_SOLUTIONS",
  "schemas": ["<inferred from SQL>"],
  "role": "ACCOUNTADMIN",
  "requires_warehouse": true,
  "requires_spcs": false,
  "install_scripts": ["scripts/setup.sql"],
  "teardown_scripts": ["scripts/teardown.sql"],
  "features": ["<inferred from SQL objects + keywords>"],
  "notes": ""
}
```

If `semantic_view.yaml` exists, add to `install_scripts` note about PUT step.

### 3.6 Generate README.md

Write a public-facing README:

```markdown
# <display_name>

> **Industry:** <industry>

## Overview

<description from plugin.json>

## Architecture

<summarize from source README.md — remove internal URLs, account-specific details>

## Key Snowflake Features

<bullet list from features array>

## Prerequisites

- Snowflake account (Enterprise edition recommended)
- ACCOUNTADMIN role
- Warehouse: SF_SOLUTIONS_WH (created by setup.sql)

## Quick Install

Use Cortex Code:
\`\`\`
$sf-mleu-solutions:<solution-name>
\`\`\`

## Solution Objects

| Object | Type | Description |
|--------|------|-------------|
<table of key objects from setup.sql>
```

Strip from source README: internal URLs, account locators, provisioning instructions
that reference source-specific infrastructure.

### 3.7 Generate NEXT_ACTIONS.md

```markdown
---
description: >
  Show next actions after installing <display_name>.
  Triggers: what next, next steps, what can I do, how to use this.
---

# Next Actions: <display_name>

## Phase 1: Quick Exploration

1. **Access the solution objects**
   - Snowsight: Data > Databases > SF_SOLUTIONS > <SCHEMA>
   - Browse tables and views created by setup.sql

2. **Try core queries**
   <3-5 example queries based on objects detected in setup.sql>

## Phase 2: Use the Skills

<list each skill from source with brief description>

## Phase 3: Connect Real Data

1. Replace demo data with your production data
2. Update schema references in semantic model (if applicable)
3. Retrain/refresh ML models (if applicable)

## Phase 4: Production Deployment

1. Create a dedicated warehouse for production load
2. Set up row access policies and masking policies
3. Schedule Dynamic Table refresh intervals
4. Configure alerting and monitoring
```

### 3.8 Copy plugin skills

For each `skills/<skill-name>/SKILL.md` in the source:

- Copy to `<output_dir>/plugins/cortex-code/skills/<skill-name>/SKILL.md`
- Update any invocation examples that reference the old plugin name to use the new
  `$sf-mleu-solutions:<solution-name>` prefix

### 3.9 Copy agents, references, hooks

- Copy `agents/*.md` → `<output_dir>/plugins/cortex-code/agents/`
- Copy `references/*.md` → `<output_dir>/plugins/cortex-code/references/`
- Copy `hooks/` → `<output_dir>/plugins/cortex-code/hooks/`

## Phase 4: Validation

### 4.1 Run conformance check

```bash
bash skills/convert-solution/hooks/check-solution-conformance.sh \
     <output_dir> .convert-meta.json
```

Fix any errors reported before continuing.

### 4.2 Run SQL lint

```bash
uv run sqruff lint <output_dir>/scripts/
```

### 4.3 Run markdown lint

```bash
markdownlint --config .markdownlint.yaml \
    <output_dir>/plugins/cortex-code/skills/**/*.md
```

### 4.4 Security scan

```bash
grep -r "-----BEGIN" <output_dir>/
grep -rE "[a-z]{2}[0-9]{5,6}\.(us|eu|ap)-[a-z]+-[0-9]+\.snowflakecomputing\.com" <output_dir>/
grep -r "snowflakecomputing.com" <output_dir>/
```

### 4.5 Clean up

```bash
rm -f .convert-meta.json
```

### 4.6 Show summary

```
=== Conversion Complete ===
Output:   <output_dir>
Files:    <count> files created

  manifest.json              ✓
  scripts/setup.sql          ✓  (<N> lines)
  scripts/teardown.sql       ✓
  semantic/<name>.yaml       ✓  (if applicable)
  README.md                  ✓
  NEXT_ACTIONS.md            ✓
  plugins/cortex-code/
    skills/  (<N> skills)    ✓
    agents/  (<N> agents)    ✓
    references/ (<N> docs)   ✓

SQL lint:      PASSED
Markdown lint: PASSED
Conformance:   PASSED

Next: review the generated files, then commit to the target repo.
```

## Error Recovery

| Issue | Action |
|-------|--------|
| Source database name not detected | Manually specify in .convert-meta.json before running conformance check |
| PUT commands in source SQL | Note in SKILL.md as manual step; remove from setup.sql |
| Semantic YAML has heredoc control characters | Copy as file, use PUT in SKILL.md |
| Skill invocation prefix unclear | Use `$sf-mleu-solutions:<solution-name>` for cortex-code |
| sqruff LT12 trailing newline | Ensure each SQL file ends with exactly `;\n` |
| Conformance fails on source DB name | Check .convert-meta.json has the correct source_databases list |

## Known Pitfalls

| Pitfall | Rule |
|---------|------|
| Source SQL uses session variables (SET) | Must execute in a single `snowflake_sql_execute` call |
| Source SQL references both source and target DB | Replace ALL occurrences, including in comments |
| Source WAREHOUSE is XSMALL or custom size | Replace with SF_SOLUTIONS_WH (LARGE) |
| GRANT statements reference source role | Update to reference new scoped role in SF_SOLUTIONS context |
| `semantic_view.yaml` references source DB tables | Update base_table references to SF_SOLUTIONS FQN |
