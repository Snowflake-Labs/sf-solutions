---
name: add-solution
description: >
  Convert an existing solution repository into the sf-hcls-solutions plugin format.
  Handles SQL-only, Python-only (extract DDL), and hybrid solutions.
  Usage: $sf-hcls-solutions:add-solution <path-to-source-repo>
  Triggers: add solution, convert solution, new solution, import solution, onboard solution.
tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Write
  - snowflake_sql_execute
---

# Add Solution to sf-hcls-solutions

Convert an existing solution repository into the standard sf-hcls-solutions plugin format.

## Input

`$ARGUMENTS` should be a path to the source repository (local path or git URL).

If no arguments provided, ask the user for the source repository location.

## Security Rules (MANDATORY)

Before creating ANY file, enforce these rules:

1. **NO CREDENTIALS** — Never include RSA keys, SSH keys, API tokens, passwords, or `.env` values in committed files.
2. **NO SNOWFLAKE INTERNAL INFO** — This is a public repo. No internal URLs, internal account names, org-specific details, or proprietary information.
3. **PLACEHOLDER ONLY** — Any `.env.example` must use generic placeholders: `<your-account-locator>`, `<your-username>`, `<path-to-key>`.
4. **TRIAL COMPATIBLE** — All SQL must work on Snowflake Trial accounts. Use standard DDL only.

## Step 1: Analyze Source Repository

Read the source repo and classify the solution type:

| Signal | Type |
|--------|------|
| Has `.sql` files with CREATE/DROP statements | SQL-only |
| Has Python files with `execute_sql()`, `session.sql()`, `cursor.execute()` | Python-only |
| Both | Hybrid |

Identify:
- What database objects are created (tables, views, pipes, stages, functions, procedures)
- What schemas are used
- What external dependencies exist (Marketplace datasets, external APIs)
- What credentials/auth is needed (key pair, OAuth, password)
- Whether the solution requires AI features (Cortex, ML, Agents)

## Step 2: Plan the Conversion

Map the source structure to sf-hcls-solutions conventions:

| Source | Target |
|--------|--------|
| Standalone database | `SF_SOLUTIONS` (shared) |
| Custom warehouse | `SF_SOLUTIONS_WH` (shared, LARGE) |
| Schema names | Keep but shorten if verbose (e.g., `MEDICAL_DEVICE_CLINICAL_DATA` -> `MEDICAL_DEVICE_CLINICAL`) |
| Python DDL | Extract to `setup.sql` |
| Teardown logic | Extract to `teardown.sql` |
| App code (Streamlit, client) | `solutions/<name>/app/` |

Present the plan to the user for confirmation:
```
Source: <path>
Solution name: <kebab-case-name>
Type: SQL-only | Python-only | Hybrid
Database: SF_SOLUTIONS
Schemas: <list>
Tables: <count>
Views: <count>
Pipes: <count>
External deps: <list>
```

## Step 3: Generate setup.sql

For **SQL-only** solutions:
- Copy SQL files and adapt database/schema references to SF_SOLUTIONS convention
- Ensure idempotency (CREATE OR REPLACE for views/pipes/stages, CREATE IF NOT EXISTS for tables)
- Add `USE ROLE ACCOUNTADMIN;` at top

For **Python-only** solutions:
- Read all Python files containing SQL execution
- Extract all DDL statements (CREATE TABLE, CREATE VIEW, CREATE PIPE, GRANT, etc.)
- Preserve the execution order
- Adapt all references to SF_SOLUTIONS convention
- Write as a single idempotent `setup.sql`

For **Hybrid** solutions:
- Merge SQL from both sources, deduplicating
- Python-extracted DDL fills gaps not covered by existing SQL files

### Data Files (CSV, JSON, Parquet, etc.)

If the source repo contains data files (`.csv`, `.json`, `.parquet`, sample datasets, seed files):

1. **Convert to `scripts/data.sql`** — Transform data files into INSERT statements
2. **Do NOT commit raw data files** to the repo (keep solutions SQL-only for portability)
3. **Conversion rules:**
   - CSV/JSON: Read each row and generate `INSERT INTO ... VALUES (...)` statements
   - Keep batches under 200 lines per INSERT for reliability
   - If total data exceeds ~1000 rows, use `INSERT INTO ... SELECT` with `GENERATOR` + randomization (see clinical-quality-agent for example)
   - For very large datasets (>5000 rows), use synthetic data generation via SQL instead of raw INSERT
4. **File structure:**
   ```
   solutions/<name>/scripts/
   ├── setup.sql       # DDL only (CREATE TABLE, VIEW, PIPE, GRANT)
   ├── data.sql        # INSERT statements for demo data (optional)
   └── teardown.sql    # DROP schemas
   ```
5. **In SKILL.md**, execute `data.sql` after `setup.sql` (tables must exist first)
6. **In manifest.json**, include: `"install_scripts": ["scripts/setup.sql", "scripts/data.sql"]`

If data is generated programmatically (Python generators, faker, etc.):
- Convert the generation logic to pure SQL using `GENERATOR()`, `UNIFORM()`, `RANDOM()`, `UUID_STRING()`
- Include the generation SQL in `data.sql` (not setup.sql) to keep DDL separate from data

**setup.sql structure:**
```sql
-- =============================================================================
-- Solution: <Display Name>
-- Industry: Healthcare & Life Sciences
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

-- Schema creation
CREATE SCHEMA IF NOT EXISTS <SCHEMA_NAME>;
USE SCHEMA SF_SOLUTIONS.<SCHEMA_NAME>;

-- Tables
-- Views
-- Pipes / Stages
-- Grants
```

### Component-Specific Patterns

When the source solution uses these Snowflake features, follow these proven patterns:

#### Semantic Model / Cortex Analyst

If the source has a YAML semantic model file:

1. Keep the YAML file at `solutions/<name>/scripts/semantic_model.yaml`
2. In setup.sql, create a stage for it:
   ```sql
   CREATE STAGE IF NOT EXISTS SEMANTIC_MODEL_STAGE
       DIRECTORY = (ENABLE = TRUE)
       COMMENT = 'Stage for Cortex Analyst semantic model YAML';
   ```
3. The PUT command CANNOT be in setup.sql (client-side only). In SKILL.md, document:
   - Cortex Code: `snowflake_sql_execute` with `PUT file://semantic_model.yaml @SEMANTIC_MODEL_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE` (after `USE SCHEMA`)
   - Claude Code: `snow sql -q "PUT file://semantic_model.yaml @DB.SCHEMA.SEMANTIC_MODEL_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"`
4. Reference in agent/analyst tool: `semantic_model_file: "@SF_SOLUTIONS.<SCHEMA>.SEMANTIC_MODEL_STAGE/semantic_model.yaml"`

#### Semantic View

If the source uses `CREATE SEMANTIC VIEW`:

1. Include the full `CREATE OR REPLACE SEMANTIC VIEW` in setup.sql
2. Grant access: `GRANT SELECT ON SEMANTIC VIEW <name> TO ROLE PUBLIC;`
3. Reference in agent tool_spec: `"semantic_view": "SF_SOLUTIONS.<SCHEMA>.<SV_NAME>"`
4. Requires `GRANT CREATE SEMANTIC VIEW ON SCHEMA ... TO ROLE ...` if not using ACCOUNTADMIN

#### Streamlit in Snowflake (SiS)

If the source has a Streamlit app to deploy in SiS:

1. Keep Streamlit files at `solutions/<name>/streamlit/streamlit_app.py` (+ `environment.yml`)
2. In setup.sql, create a stage:
   ```sql
   CREATE STAGE IF NOT EXISTS STREAMLIT_STAGE
       DIRECTORY = (ENABLE = TRUE)
       COMMENT = 'Stage for Streamlit app files';
   ```
3. PUT the files in SKILL.md execution (not in setup.sql):
   - `PUT file://streamlit_app.py @STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE`
   - `PUT file://environment.yml @STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE`
4. Create the Streamlit object:
   ```sql
   CREATE OR REPLACE STREAMLIT SF_SOLUTIONS.<SCHEMA>.<APP_NAME>
       ROOT_LOCATION = '@SF_SOLUTIONS.<SCHEMA>.STREAMLIT_STAGE'
       MAIN_FILE = 'streamlit_app.py'
       QUERY_WAREHOUSE = SF_SOLUTIONS_WH
       COMMENT = '<description>';
   ```
5. Apply SiS constraints from Known Pitfalls section (go.Figure, no st.connection, etc.)
6. All queries must use FQN: `SF_SOLUTIONS.<SCHEMA>.<TABLE>`
7. Cast Decimal/Number to `::FLOAT` before Plotly

**Converting a local Streamlit app to SiS:**

When the source repo has a local Streamlit app (runs on localhost), convert it to a SiS-compatible read-only dashboard:

1. **Strip client-side dependencies** — Remove `subprocess`, `signal`, `threading`, `requests`, `os.getenv`, `dotenv`, file I/O
2. **Replace connection** — Use `from snowflake.snowpark.context import get_active_session` instead of connector/env vars
3. **Make it read-only** — Remove start/stop streaming controls, database resets, process management
4. **Keep visualization** — Preserve the chart and metric display logic (using `go.Figure` + `.tolist()`)
5. **Use FQN everywhere** — All queries use `SF_SOLUTIONS.<SCHEMA>.<TABLE>`
6. **Cast numerics** — All NUMBER/DECIMAL columns cast to `::FLOAT` in SQL before passing to Plotly
7. **Create `environment.yml`** — Only include packages available in SiS (plotly, pandas — NOT neurokit2, requests, etc.)
8. **Save to `solutions/<name>/streamlit/streamlit_app.py`**

#### Cortex Agent (Snowflake Intelligence)

If the source has a Cortex Agent:

1. In setup.sql, create the agent with full specification:
   ```sql
   CREATE OR REPLACE AGENT <agent_name>
       COMMENT = '<description>'
       FROM SPECIFICATION
       $$
       models:
         orchestration: auto
       instructions:
         response: "<response instructions>"
       tools:
         - tool_spec:
             type: cortex_analyst_text_to_sql
             name: <TOOL_NAME>
             description: |
               <description>
             semantic_model_file: "@SF_SOLUTIONS.<SCHEMA>.SEMANTIC_MODEL_STAGE/<file>.yaml"
       $$;
   ```
2. Common tool types: `cortex_analyst_text_to_sql`, `cortex_search`, `sql_exec`, `data_to_chart`
3. Show the agent URL after install (MANDATORY):
   ```sql
   SELECT 'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
       || '/#/agents/database/SF_SOLUTIONS/schema/<SCHEMA>/agent/<AGENT_NAME>/details' AS AGENT_URL;
   ```

#### Cortex Search Service

If the source has a Cortex Search Service:

1. In setup.sql:
   ```sql
   CREATE OR REPLACE CORTEX SEARCH SERVICE SF_SOLUTIONS.<SCHEMA>.<SERVICE_NAME>
   ON <TEXT_COLUMN>
   WAREHOUSE = SF_SOLUTIONS_WH
   TARGET_LAG = '1 hour'
   AS (
       SELECT <columns> FROM <source_table>
   );
   ```
2. The source table must be populated BEFORE creating the search service
3. Reference in agent tool_spec as `cortex_search` type
4. For SiS apps, query via `SNOWFLAKE.CORTEX.SEARCH_PREVIEW()` (2 args: service name + JSON options)

#### SPCS (Snowpark Container Services)

If the source uses SPCS (GPU compute, containers):

1. Mark in manifest.json: `"requires_spcs": true`
2. In setup.sql, wrap SPCS sections with comments:
   ```sql
   -- ============================================================
   -- OPTIONAL: SPCS GPU Compute (requires Compute Pool access)
   -- Comment out this section if SPCS is not available
   -- ============================================================
   ```
3. Provide a non-SPCS fallback (stored procedure, SQL-only notebook) for Trial accounts
4. Document in manifest.json `notes` field which sections to comment out

## Step 4: Generate teardown.sql

```sql
USE ROLE ACCOUNTADMIN;
-- Drop solution schemas (preserves shared SF_SOLUTIONS database and warehouse)
DROP SCHEMA IF EXISTS SF_SOLUTIONS.<SCHEMA_1> CASCADE;
DROP SCHEMA IF EXISTS SF_SOLUTIONS.<SCHEMA_2> CASCADE;
```

NEVER drop the shared `SF_SOLUTIONS` database or `SF_SOLUTIONS_WH` warehouse.

## Step 5: Create manifest.json

```json
{
  "name": "<kebab-case-name>",
  "display_name": "<Human Readable Name>",
  "version": "1.0.0",
  "industry": "Healthcare & Life Sciences",
  "description": "<1-2 sentence description>",
  "database": "SF_SOLUTIONS",
  "schemas": ["<SCHEMA_1>", "<SCHEMA_2>"],
  "role": "ACCOUNTADMIN",
  "requires_warehouse": true,
  "requires_marketplace": [],
  "install_scripts": ["scripts/setup.sql"],
  "teardown_scripts": ["scripts/teardown.sql"],
  "features": ["<feature1>", "<feature2>"],
  "notes": "<any important notes>"
}
```

## Step 6: Create README.md

Write a public-facing README with:
- Solution overview and value proposition
- Architecture diagram (text-based)
- Key Snowflake features demonstrated
- Prerequisites (account type, role, optional Marketplace datasets)
- NO credentials, internal URLs, or proprietary info

## Step 7: Copy App Code (if applicable)

If the source has Python/Streamlit app code:

1. Copy to `solutions/<name>/app/`
2. Update config defaults to use `SF_SOLUTIONS` and new schema names
3. Create `.env.example` with ONLY generic placeholders
4. Keep `requirements.txt`
5. **AUDIT all files** — grep for:
   - Account locators (patterns like `xy12345.us-east-1`)
   - RSA/SSH key content (`-----BEGIN`)
   - Hardcoded passwords or tokens
   - Snowflake internal URLs (`.int.snowflakecomputing.com`, `sfcdev`, etc.)
   - Remove any matches found

## Step 8: Create Plugin Skills

Create SKILL.md and NEXT_ACTIONS.md in both:
- `plugins/cortex-code/skills/<name>/`
- `plugins/claude-code/skills/<name>/`

**SKILL.md** follows the pattern from `clinical-quality-agent`:
- Parse `$ARGUMENTS` for install vs teardown
- Locate repo, read manifest
- Present plan, wait for confirmation
- Execute setup.sql using **batch mode** (see below)
- Verify objects created
- Show summary + next actions

### Batch Execution Strategy (CRITICAL for performance)

Large setup.sql files cause slow installation if executed statement-by-statement. Use batch mode and parallel execution to maximize speed.

**Rules:**

1. **Group independent DDL into batches** — Multiple `CREATE TABLE`, `CREATE VIEW`, `GRANT` statements that don't depend on each other can be concatenated with `;` and sent as a single `snowflake_sql_execute` call.

2. **Batch sizing:** Aim for 5-20 statements per batch. Group by logical section:
   - Batch 1: Schema creation + table DDL
   - Batch 2: View creation
   - Batch 3: Pipe creation
   - Batch 4: Grants
   - Batch 5: Data inserts (if data.sql)

3. **Parallel execution with subagents** — When setup.sql has independent sections (no dependencies between them), use the Task tool to spawn multiple subagents that execute different sections simultaneously.

   **When to parallelize:**
   - Two schemas that don't reference each other (e.g., CLINICAL schema and TELEMETRY schema)
   - Views that reference different tables
   - Grants on different schemas
   - Data inserts into unrelated tables

   **Example: parallel execution plan**
   ```
   Sequential:
     Step 1: USE ROLE + CREATE DB/WH (must run first, shared context)

   Parallel (spawn 2 subagents):
     Subagent A: CREATE SCHEMA CLINICAL + all CLINICAL tables + CLINICAL views + CLINICAL pipes
     Subagent B: CREATE SCHEMA TELEMETRY + all TELEMETRY tables + TELEMETRY views + TELEMETRY pipes

   Sequential (after parallel completes):
     Step 3: Cross-schema views (if any reference both schemas)
     Step 4: GRANT statements (all schemas)
     Step 5: CREATE AGENT (may reference objects from both schemas)
   ```

   **How to parallelize in SKILL.md:**
   ```
   Use the Task tool to spawn subagents for independent sections:

   Task 1 (background): "Execute CLINICAL schema DDL"
     - Run lines 50-150 of setup.sql as a single snowflake_sql_execute call

   Task 2 (background): "Execute TELEMETRY schema DDL"
     - Run lines 151-250 of setup.sql as a single snowflake_sql_execute call

   Wait for both tasks to complete, then continue with sequential steps.
   ```

   **When NOT to parallelize:**
   - Sections that share session variables (SET)
   - Views/pipes that reference tables in another section
   - RESULT_SCAN chains
   - Agent/search service creation that references objects being created in parallel

4. **Session-dependent statements MUST stay together** — `SET` variables + statements that reference those variables must be in ONE call (they share a session).

5. **Order-dependent statements must be sequential:**
   - Tables before views (views reference tables)
   - Tables before pipes (pipes reference tables)
   - Tables before search services (search indexes table data)
   - Data inserts before search services (search needs data to index)
   - `data.sql` after `setup.sql` (tables must exist)
   - `RESULT_SCAN` immediately after its predecessor

6. **Timeout guidance:**
   - DDL batches: default timeout (180s)
   - Data generation (GENERATOR + INSERT): `timeout_seconds: 1200`
   - ML model training: `timeout_seconds: 600`
   - Cortex Search Service creation: `timeout_seconds: 600` (indexing takes time)

7. **Log progress** after each batch/subagent completes (not after each statement).

8. **SKILL.md must document the execution plan** — Include a section like:
   ```
   Execution strategy:
   - Step 1 (sequential): USE ROLE + shared infrastructure — single call
   - Step 2 (parallel):
     - Subagent A: MEDICAL_DEVICE_CLINICAL schema (tables + views + pipes)
     - Subagent B: MEDICAL_DEVICE_TELEMETRY schema (tables + views + pipes)
   - Step 3 (sequential): Cross-schema grants — single call
   - Step 4 (sequential): PUT semantic_model.yaml
   - Step 5 (sequential): CREATE AGENT
   ```

**NEXT_ACTIONS.md** follows progressive phases:
- Phase 1: Quick Exploration (query tables, describe objects)
- Phase 2: Customize / Run Demo (if app code exists)
- Phase 3: Connect Real Data
- Phase 4: Production Deployment

Use `$sf-hcls-solutions:<name>` prefix for cortex-code, `/sf-hcls-solutions:<name>` for claude-code.

## Step 9: Update Repository Files

1. **README.md** — Add row to solution catalog table
2. **AGENTS.md** — Add row to existing solutions table

## Step 10: Validate

Run these checks:
```bash
uv run sqruff lint solutions/<name>/scripts/
uv run ruff check solutions/<name>/app/  # if app exists
markdownlint --config .markdownlint.yaml plugins/cortex-code/skills/<name>/*.md
markdownlint --config .markdownlint.yaml plugins/claude-code/skills/<name>/*.md
```

Grep for leaked secrets:
```bash
grep -r "-----BEGIN" solutions/<name>/
grep -rE "[a-z]{2}[0-9]{5}\." solutions/<name>/
grep -r "snowflakecomputing.com" solutions/<name>/
```

## Known Pitfalls (from past conversion experience)

These are real issues encountered when converting solutions. Apply these rules during conversion:

### SQL Pitfalls

| Pitfall | Rule |
|---------|------|
| PUT command in .sql files | PUT is a client-side command — CANNOT be in setup.sql or executed in Snowsight. For YAML/file uploads, use inline `SELECT` with `CHAR(10)` concatenation into a stage, or document as a manual step in SKILL.md. In CoCo use `snowflake_sql_execute` with PUT (relative stage path). In Claude Code use `snow sql -q "PUT file://..."`. |
| `SAMPLE` as CTE/alias name | `SAMPLE` is a reserved word in Snowflake SQL. Use `sample_data`, `data_sample`, etc. |
| Session variables (`SET`) | SET variables (e.g., `$num_patients`) only persist within a single session. If setup.sql uses SET + later INSERT/SELECT referencing those vars, they MUST be executed in a single `snowflake_sql_execute` call. Document this in SKILL.md execution strategy. |
| sqruff LT12 rule | SQL files MUST end with exactly one trailing newline (`;\n`). Two trailing newlines (`;\n\n`) will fail CI. |
| FORECAST SERIES column | FORECAST model output stores SERIES column as VARIANT. Always cast with `::VARCHAR` when joining. |
| Numeric columns for Plotly | Snowflake NUMBER/DECIMAL types must be cast to `::FLOAT` in SQL before passing to Plotly charts in Streamlit. |
| RESULT_SCAN dependencies | Any statement using `RESULT_SCAN(LAST_QUERY_ID())` must execute immediately after its predecessor in the same session. |

### Streamlit in Snowflake (SiS) Pitfalls

If the solution includes a Streamlit app deployed in SiS:

| Pitfall | Rule |
|---------|------|
| `plotly.express` is broken | SiS has old Plotly. `px.scatter(df, x="COL", y="COL")` plots index numbers, not column values. ALWAYS use `plotly.graph_objects` with `.tolist()`. |
| `st.connection("snowflake")` | Not available. Use `from snowflake.snowpark.context import get_active_session`. |
| `st.rerun()` | Not available. Use `st.experimental_rerun()`. |
| `st.chat_input()` / `st.chat_message()` | Not available. Use `st.text_input()` + `st.button()` and `st.markdown()` with role prefix. |
| `st.dataframe(hide_index=True)` | `hide_index` parameter not available. Omit it. |
| `snowflake.core` module | Not available in SiS. Use `session.sql()` with SQL functions directly. |
| Cortex Agent API | NOT supported in SiS warehouse runtime. Use `SNOWFLAKE.CORTEX.SEARCH_PREVIEW()` + `SNOWFLAKE.CORTEX.COMPLETE()` for RAG. |
| `color_discrete_map` in px | Buggy in SiS. Avoid or use basic color arguments. |

### YAML / Semantic Model Upload

For solutions with YAML semantic models (Cortex Analyst):

- Cannot use `$$..$$` heredoc in COPY INTO — causes escaping issues
- Recommended: Read the YAML file content, then upload via PUT in the SKILL.md execution step
- Alternative: Use `CHAR(10)` concatenation to build YAML content inline in SQL
- In SKILL.md, document the PUT workaround:
  - Cortex Code: `USE SCHEMA` first, then `PUT file://... @STAGE_NAME/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE`
  - Claude Code: `snow sql -q "PUT file://... @DB.SCHEMA.STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"`

### Plugin Skill Conventions

| Rule | Detail |
|------|--------|
| Skill invocation prefix | Cortex Code uses `$sf-hcls-solutions:<name>`, Claude Code uses `/sf-hcls-solutions:<name>` |
| SKILL.md for cortex-code | Use `$` prefix in all examples and usage help |
| SKILL.md for claude-code | Use `/` prefix in all examples and usage help |
| `$ARGUMENTS` variable | Same in both platforms — do NOT change when adapting between platforms |
| Conventional commits | All commit messages must use: `feat`, `fix`, `chore`, `docs`, `refactor`, `ci`, `test` |
| NEXT_ACTIONS.md | Same content for both platforms (no platform-specific commands) |
| Mandatory final steps | SKILL.md install must always: (1) show deployed resource URL (Snowsight link), (2) show summary with next actions. Every solution MUST output at least one clickable URL — use Snowsight database/schema URL as fallback if no Streamlit/Agent exists. |

### Data Generation

| Rule | Detail |
|------|--------|
| Large data (>200 lines of INSERTs) | Extract to separate `data.sql` file to avoid CoCo context overflow |
| Session-dependent generation | If using SET vars + GENERATOR, document in SKILL.md that these must run in a single session call with `timeout_seconds: 1200` |
| CSV to INSERT conversion | When source uses CSV files, convert to INSERT statements. Keep under 200 lines per statement batch for reliability. |

## Error Recovery

| Issue | Action |
|-------|--------|
| Cannot determine solution type | Ask user which files contain DDL |
| Python DDL uses dynamic table names from config | Read config to resolve actual names |
| Source has credentials committed | Strip them, add to .gitignore, create .env.example |
| SQL uses features unavailable on Trial | Note in manifest.json `notes` field, use IF EXISTS guards |
| PUT fails with "Schema does not exist" | Use `USE SCHEMA` first, then relative stage path `@STAGE_NAME/` |
| YAML heredoc escaping fails | Switch to CHAR(10) concatenation or PUT command approach |
| Streamlit chart shows index numbers | Replace `plotly.express` with `plotly.graph_objects` + `.tolist()` |
| sqruff CI fails on trailing newline | Ensure file ends with exactly `;\n` (one newline, no blank line) |
