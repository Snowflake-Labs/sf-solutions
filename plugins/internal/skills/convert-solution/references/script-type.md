# Script Type Conversion Reference

This reference is loaded by `convert-solution` SKILL.md when the solution type is "script".

## Phase 2: Source Analysis (Script-specific)

Classify the source as one of:

- **SQL-only** — contains `.sql` files with DDL/DML
- **Python-only** — contains `.py` files with embedded SQL execution (session.sql, cursor.execute)
- **Hybrid** — contains both `.sql` and `.py` files with DDL

For each type, identify:
- All CREATE statements (TABLE, VIEW, PIPE, STAGE, FUNCTION, PROCEDURE, STREAMLIT, AGENT)
- Schema names used
- External dependencies (Marketplace datasets, external stages, API integrations)
- Data files (CSV, JSON, Parquet) that need conversion to INSERT statements
- Streamlit app files

## Phase 4: File Generation (Script-specific)

### Generate setup.sql

**SQL-only sources:**
- Copy SQL files and adapt database/schema references to SF_SOLUTIONS
- Ensure idempotency (CREATE OR REPLACE for views/pipes/stages, CREATE IF NOT EXISTS for tables)
- Add `USE ROLE ACCOUNTADMIN;` at top

**Python-only sources:**
- Extract all DDL statements from Python files
- Preserve execution order
- Adapt all references to SF_SOLUTIONS
- Write as a single idempotent `setup.sql`

**Hybrid sources:**
- Merge SQL from both sources, deduplicating
- Python-extracted DDL fills gaps not covered by existing SQL files

**setup.sql structure:**

```sql
-- =============================================================================
-- Solution: <Display Name>
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

-- Tables, Views, Pipes, Stages, etc.
```

### Generate data.sql (if source has data files)

- Convert CSV/JSON/Parquet to INSERT statements
- Do NOT commit raw data files to the repo
- Keep batches under 200 lines per INSERT
- For large datasets (>5000 rows), use synthetic SQL generation with `GENERATOR()`, `UNIFORM()`, `RANDOM()`
- In manifest.json: `"install_scripts": ["scripts/setup.sql", "scripts/data.sql"]`

### Generate teardown.sql

```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE SF_SOLUTIONS;
USE WAREHOUSE SF_SOLUTIONS_WH;

DROP SCHEMA IF EXISTS <SCHEMA_1>;
DROP SCHEMA IF EXISTS <SCHEMA_2>;
-- NEVER drop SF_SOLUTIONS database or SF_SOLUTIONS_WH warehouse
```

### Generate NEXT_ACTIONS.md

Structure as progressive phases:

1. **Quick Exploration** — immediate things to try (open dashboard, run queries)
2. **Customize with Your Data** — how to replace demo data
3. **Tune the Model** — adjust parameters, add features
4. **Production Deployment** — scheduling, monitoring, RBAC

### Copy Streamlit app (if present)

Copy to `<solution>/streamlit/` with security audit:
- Replace hardcoded database/schema references with `SF_SOLUTIONS.<SCHEMA>`
- Use `plotly.graph_objects` (not `plotly.express`) for charts
- Use `get_active_session()` instead of `st.connection("snowflake")`
- Cast numeric Decimal columns to `::FLOAT` in SQL before passing to Plotly

### Copy semantic models (if present)

Copy `.yaml` files to `<solution>/semantic/` and adapt database references.
