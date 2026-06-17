# AGENTS.md

Project-level instructions for AI coding assistants working on this repository.

## Project Overview

This is the `sf-solutions` repository containing Snowflake industry solution accelerators. Each solution lives in `solutions/<name>/` with a standard structure (manifest.json, scripts/, streamlit/).

## Known Issues and Workarounds

### Streamlit in Snowflake (SiS) — Plotly Bug

SiS bundles an old Plotly version where `plotly.express` DataFrame column resolution is broken.

**Symptom:** `px.scatter(df, x="COL", y="COL")` and `px.bar(df, x="COL", y="COL")` plot DataFrame index numbers (0, 1, 2...) instead of actual column values.

**Fix:** Always use `plotly.graph_objects` with `.tolist()`:
```python
import plotly.graph_objects as go
fig = go.Figure(data=[go.Scatter(
    x=df["COL_X"].tolist(),
    y=df["COL_Y"].tolist(),
    mode="markers"
)])
```

Additional SiS constraints:
- `color_discrete_map` in `px` functions is buggy
- `hide_index=True` in `st.dataframe` is unsupported
- NUMBER/DECIMAL types must be cast to `::FLOAT` in SQL before passing to Plotly (Snowpark returns Python Decimal which Plotly cannot plot)

### PUT Command Behavior

- PUT is a client-side command — it cannot be executed inside SQL worksheets in Snowsight or inside `.sql` files.
- In Cortex Code, use `snowflake_sql_execute` with PUT, but the stage path must be relative. Use `USE SCHEMA` first, then `@STAGE_NAME/` (not `@DB.SCHEMA.STAGE/` which gives "Schema does not exist").
- In Claude Code CLI, use `snow sql -q "PUT file://... @DB.SCHEMA.STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"`.
- Always use `AUTO_COMPRESS=FALSE` for `.py` and `.yml` files.

### Snowflake SQL Reserved Words

- `SAMPLE` is a reserved word — cannot be used as a CTE name or alias. Use `top_customers`, `sample_data`, etc.

### FORECAST Model Output

- `CUSTOMER_ID` in FORECAST output (SERIES column) is stored as VARIANT. Always cast with `::VARCHAR` when joining.

### sqruff SQL Linter

- Rule `LT12`: Files must end with exactly one trailing newline (`;\n`). Two trailing newlines (`;\n\n`) will fail.
- Output format for CI: use `--format github-annotation-native` (not `github`).
- Runs on all `**/*.sql` files in the repo.

### ruff Python Linter

- Configured with Google style docstrings (`convention = "google"`).
- Line length: 120 characters.
- `D107` (missing `__init__` docstring) is ignored.
- `gnn-supply-chain-risk/` is excluded until migrated.
- CI runs both `ruff check` and `ruff format --check`.

### GitHub Actions — gh pr create in zsh

- Heredoc and multiline strings in `gh pr create --body` can get stuck in zsh.
- Workaround: use `$(cat <<'EOF' ... EOF)` syntax for the body.

## Coding Conventions

### SQL Style

- All solutions use `SF_SOLUTIONS` as the shared database.
- All solutions use `SF_SOLUTIONS_WH` (LARGE) as the shared warehouse. Do not create solution-specific warehouses.
- Teardown scripts drop solution schemas but NOT the shared SF_SOLUTIONS database or SF_SOLUTIONS_WH warehouse.
- Use `USE ROLE ACCOUNTADMIN` at the top of setup/teardown scripts.

### Python Style

- Google style docstrings on all public classes, methods, and functions.
- Import sorting via ruff (isort-compatible).
- No unused imports.

### Streamlit Apps

- Use fully qualified names (`SF_SOLUTIONS.<SCHEMA>.<TABLE>`) for all queries.
- Cast numeric columns to `::FLOAT` in SQL queries that feed Plotly charts.
- Use `plotly.graph_objects`, not `plotly.express`, for charts.

## Solution Structure

```
solutions/<name>/
├── manifest.json          # Metadata: name, version, industry, schemas, features
├── README.md              # Architecture overview, quick start, example usage
├── scripts/
│   ├── setup.sql          # Self-contained install (DDL + data + all objects)
│   └── teardown.sql       # Drop solution schemas only
└── streamlit/             # Optional
    ├── streamlit_app.py
    └── environment.yml
```

Plugin skills mirror this at:
- `plugins/cortex-code/skills/<name>/SKILL.md` + `NEXT_ACTIONS.md`
- `plugins/claude-code/skills/<name>/SKILL.md` + `NEXT_ACTIONS.md`

### Skill Invocation Prefixes

The two supported AI CLI platforms use different trigger characters:

| Platform | Prefix | Example |
|----------|--------|---------|
| Cortex Code | `$` | `$snowflake-solutions:ltv-prediction` |
| Claude Code CLI | `/` | `/snowflake-solutions:ltv-prediction` |

When writing SKILL.md files, always use the correct prefix for the target platform in usage help and examples.

### Snowsight URL Patterns

After installation, always output clickable URLs for deployed resources. Use SQL to construct them dynamically:

```sql
-- Base URL construction (handles both org accounts and legacy accounts)
SELECT
    CASE
        WHEN CURRENT_ORGANIZATION_NAME() IS NOT NULL AND CURRENT_ORGANIZATION_NAME() != ''
        THEN 'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
        ELSE 'https://app.snowflake.com/' || LOWER(REPLACE(REPLACE(REPLACE(CURRENT_REGION(), 'AWS_', ''), 'AZURE_', ''), '_', '-')) || '/' || LOWER(CURRENT_ACCOUNT())
    END AS BASE_URL;
```

There are two URL formats depending on the account type:

| Account Type | URL Format | Example |
|--------------|-----------|---------|
| Organization (Trial, standard) | `https://app.snowflake.com/<org_name>/<account_name>/` | `https://app.snowflake.com/iwqhwyc/mtb35883/` |
| Legacy (older accounts) | `https://app.snowflake.com/<region>/<account_locator>/` | `https://app.snowflake.com/sfdevrel/sfdevrel_enterprise/` |

The CASE expression above handles both. For simplicity, most setup scripts use just `CURRENT_ORGANIZATION_NAME() || '/' || CURRENT_ACCOUNT_NAME()` which works for modern accounts.

URL path patterns by resource type:

| Resource | URL Path |
|----------|----------|
| Streamlit App | `<BASE_URL>/#/streamlit-apps/<DB>.<SCHEMA>.<APP_NAME>` |
| Intelligence Agent | `<BASE_URL>/#/agents/database/<DB>/schema/<SCHEMA>/agent/<AGENT_NAME>/details` |
| Snowflake CoWork | `https://ai.snowflake.com/<org>/<account>/#/ai` (note: `ai.snowflake.com`, not `app.snowflake.com`) |

Examples:

```
Streamlit:  https://app.snowflake.com/myorg/myaccount/#/streamlit-apps/SF_SOLUTIONS.LTV_ML.LTV_PREDICTION_DASHBOARD
Agent:      https://app.snowflake.com/myorg/myaccount/#/agents/database/SF_SOLUTIONS/schema/SUPPLY_CHAIN_ENTITIES/agent/SUPPLY_CHAIN_ASSISTANT/details
CoWork:     https://ai.snowflake.com/myorg/myaccount/#/ai
```

SQL for Streamlit URL:

```sql
SELECT 'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
    || '/#/streamlit-apps/SF_SOLUTIONS.<SCHEMA>.<APP_NAME>' AS STREAMLIT_URL;
```

SQL for Agent URL:

```sql
SELECT 'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
    || '/#/agents/database/SF_SOLUTIONS/schema/<SCHEMA>/agent/<AGENT_NAME>/details' AS AGENT_URL;
```

## CI Checks

All PRs must pass:
1. **markdownlint** — all `*.md` files
2. **sqruff** — all `*.sql` files (`--format github-annotation-native`)
3. **ruff check + format** — all `*.py` files (excluding `gnn-supply-chain-risk/`)
4. **skills-purity** — no code files (`.py`, `.sql`) inside `skills/` directories

## Existing Solutions

Reference when creating new solutions to avoid schema name conflicts and to follow established patterns.

| Solution | Industry | Database | Schemas | Key Features |
|----------|----------|----------|---------|--------------|
| ltv-prediction | Retail / CPG | SF_SOLUTIONS | LTV_RAW, LTV_ANALYTICS, LTV_ML | ML Forecast, Cortex AI, Segmentation, Streamlit |
| supply-chain-intelligence | Manufacturing | SF_SOLUTIONS | SUPPLY_CHAIN_ENTITIES | Intelligence Agent, Cortex Analyst, Cortex Search, Streamlit |
| clinical-quality-agent | Healthcare | SF_SOLUTIONS | CLINICAL_QUALITY_SAFETY | Intelligence Agent, Cortex Analyst, Cortex Search |
| manufacturing-predictive-maintenance | Manufacturing | SF_SOLUTIONS | MPM_BRONZE, MPM_SILVER, MPM_GOLD | CoWork, Cortex Analyst, Semantic View, Streamlit, SPCS |
| gnn-supply-chain-risk | Manufacturing | SF_SOLUTIONS | GNN_SUPPLY_CHAIN_RISK | GNN, NetworkX, Risk Analysis, Streamlit |

Notes:
- All solutions use `SF_SOLUTIONS` database.
- All solutions use `SF_SOLUTIONS_WH` (LARGE) as the shared warehouse. Do not create separate warehouses per solution.
- Schema names must be unique across solutions to avoid conflicts.
