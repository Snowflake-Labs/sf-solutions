# AGENTS.md

Project-level instructions for AI coding assistants working on this repository.

## Important Rules

- **Never commit or push without explicit user instruction.** Only run `git commit` or `git push` when the user explicitly says "commit", "push", or "commit push".

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

Additional SiS constraints — unavailable methods:

| Unavailable Method | Replacement |
|---|---|
| `st.connection("snowflake")` | `from snowflake.snowpark.context import get_active_session` |
| `st.rerun()` | `st.experimental_rerun()` |
| `st.chat_input()` | `st.text_input()` + `st.button()` |
| `st.chat_message()` | `st.markdown()` with role prefix (e.g. `**You:**`, `**Assistant:**`) |
| `st.dataframe(hide_index=True)` | `st.dataframe()` without `hide_index` parameter |
| `plotly.express` `color_discrete_map` | Avoid or use basic color args |
| `plotly.express` with Decimal columns | Cast to `::FLOAT` in SQL before passing to Plotly |
| `/snowflake/session/token` (SPCS only) | Not available in SiS warehouse runtime |
| `requests` to Cortex Agent REST API | Not available in SiS warehouse runtime |
| `SNOWFLAKE.CORTEX.AGENT()` SQL function | Does not exist — use Cortex Search + Complete directly |
| Cortex Agent API (any method) in SiS | **Not supported** — use Cortex Search + `snowflake.cortex.Complete` for RAG |
| `snowflake.core` (Python module) | Not available — use `session.sql()` with SQL functions directly |

**Important**: Cortex Agent API is explicitly not supported in SiS warehouse runtime (per Snowflake docs).
To build a chatbot in SiS, use `SNOWFLAKE.CORTEX.SEARCH_PREVIEW()` via `session.sql()` + `SNOWFLAKE.CORTEX.COMPLETE()`.

**`snowflake.core` module**: Not available in SiS warehouse runtime. Do not import `Root` from `snowflake.core`. Use `session.sql()` with SQL functions instead.

**`SNOWFLAKE.CORTEX.SEARCH_PREVIEW` signature** (2 args):
```sql
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        '<fully_qualified_service_name>',
        '{"query": "<search_text>", "columns": ["col1"], "limit": 5}'
    )
)['results'] AS results;
```
- Arg 1: service name (string literal)
- Arg 2: JSON object (string literal) containing `query`, `columns`, `limit`, `filter` etc.
- Do NOT pass query as a plain text string — it must be a JSON object.
- Do NOT pass 3 arguments — all options go inside the JSON object in arg 2.

### PUT Command Behavior

- PUT is a client-side command — it cannot be executed inside SQL worksheets in Snowsight or inside `.sql` files.
- In Cortex Code, use `snowflake_sql_execute` with PUT directly (it supports fully qualified stage paths).
- **Do NOT use `snow sql`** — it requires password/key-pair auth in `connections.toml`, which PAT-only environments lack.
- In SKILL.md files, always use the MCP SQL execution tool (not `snow sql` CLI).
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
- CI runs both `ruff check` and `ruff format --check`.

### GitHub Actions — gh pr create in zsh

- Heredoc and multiline strings in `gh pr create --body` can get stuck in zsh.
- Workaround: use `$(cat <<'EOF' ... EOF)` syntax for the body.

### Cortex Agent — CoWork Visibility

- After creating an Agent with `CREATE AGENT`, you must GRANT USAGE for it to appear in CoWork (Snowflake Intelligence).
- The Agent owner role can issue the GRANT without ACCOUNTADMIN:
  ```sql
  GRANT USAGE ON AGENT <db>.<schema>.<agent_name> TO ROLE PUBLIC;
  ```
- Without this GRANT, the Agent exists but is invisible in CoWork for other roles/users.
- Trial accounts may auto-grant visibility; Enterprise accounts do not.

### GitHub Actions — Required Status Checks with Path Filters

- Workflows with `paths:` filters do NOT trigger when no matching files change.
- If such a workflow is listed in a ruleset as a required status check, the PR gets stuck on "Waiting for status to be reported" forever.
- **Fix:** Remove `paths:` from the workflow trigger and add an early-exit check inside the job (e.g., "No SQL files found — skipping").

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
│   ├── setup.sql          # DDL + object creation (no large data inserts)
│   ├── data.sql           # Demo data INSERT statements (optional, for large datasets)
│   └── teardown.sql       # Drop solution schemas only
└── streamlit/             # Optional
    ├── streamlit_app.py
    └── environment.yml
```

When demo data exceeds ~200 lines, extract it into a separate `data.sql` file. This prevents CoCo CLI context overflow and allows direct execution via `snow sql -f scripts/data.sql`.

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
3. **ruff check + format** — all `*.py` files
4. **skills-purity** — no code files (`.py`, `.sql`) inside `skills/` directories

### Local Pre-commit Hooks

This repo uses [pre-commit](https://pre-commit.com/) to run lint checks before every commit. After cloning, install the hooks:

```bash
pre-commit install
pre-commit install --hook-type commit-msg
```

This enables:
- **check-json** — validates `.json` files
- **markdownlint** — lints `.md` files
- **no-code-in-skills** — ensures `skills/` contains only `.md`, `.json`, `.yaml`, `.yml`
- **conventional-pre-commit** — enforces [Conventional Commits](https://www.conventionalcommits.org/) message format

Commit messages must use one of: `feat`, `fix`, `chore`, `docs`, `refactor`, `ci`, `test`.

Examples:
```
feat: add supply-chain-intelligence solution
fix: correct SEARCH_PREVIEW argument format
docs: update AGENTS.md with PR template
chore: format files with ruff
```

## PR Test Template

Include the following checklist in PR descriptions. All items must pass before merging.

```markdown
## Test Plan

### CI (automated)
- [ ] `ruff check` passes
- [ ] `ruff format --check` passes
- [ ] `sqruff lint` passes (all `.sql` files)
- [ ] `markdownlint` passes (all `.md` files)
- [ ] `skills-purity` passes (no `.py`/`.sql` in `skills/` dirs)

### Setup / Teardown (manual)
- [ ] `scripts/setup.sql` completes successfully as ACCOUNTADMIN
- [ ] `scripts/teardown.sql` is idempotent (runs twice without error)
- [ ] Full round-trip works: teardown → setup → teardown

### Streamlit App (verify in SiS warehouse runtime)
- [ ] App launches without import errors in SiS warehouse runtime
- [ ] All pages/tabs navigate correctly
- [ ] Data displays correctly (tables, charts)
- [ ] Plotly charts render actual data values (not index numbers)
- [ ] User interactions (buttons, inputs) work
- [ ] Cortex features (Search/Complete/Analyst) return responses

### Cortex Agent / Intelligence (if applicable)
- [ ] Agent responds from Snowsight UI
- [ ] Cortex Analyst (semantic model) generates correct SQL
- [ ] Cortex Search Service is indexed (`SHOW CORTEX SEARCH SERVICES` shows ACTIVE)

### Data Integrity
- [ ] Demo data inserts correctly (verify row counts)
- [ ] Referential joins are not broken (JOIN results are non-empty)
- [ ] All DB/Schema/Table references use `SF_SOLUTIONS.<SCHEMA>.<TABLE>` format
```

### PR Description Template

```markdown
## Summary
<!-- 1-3 sentences describing the change -->

## Changes
- ...

## Test Plan
- [ ] Verify `uv run sqruff lint solutions/<solution-name>/scripts/` passes
- [ ] Run `$snowflake-solutions:<solution-name>` in Cortex Code to confirm install works
- [ ] Run `$snowflake-solutions:<solution-name> teardown` in Cortex Code to confirm teardown works
- [ ] Run `/snowflake-solutions:<solution-name>` to confirm install in Claude Code
- [ ] Run `/snowflake-solutions:<solution-name> teardown` to confirm teardown works in Claude Code

## Screenshots
<!-- SiS runtime screenshots if UI changes are included -->
```

## Existing Solutions

Reference when creating new solutions to avoid schema name conflicts and to follow established patterns.

| Solution | Industry | Database | Schemas | Key Features |
|----------|----------|----------|---------|--------------|
| ltv-prediction | Retail / CPG | SF_SOLUTIONS | LTV_RAW, LTV_ANALYTICS, LTV_ML | ML Forecast, Cortex AI, Segmentation, Streamlit |

Notes:
- All solutions use `SF_SOLUTIONS` database.
- All solutions use `SF_SOLUTIONS_WH` (LARGE) as the shared warehouse. Do not create separate warehouses per solution.
- Schema names must be unique across solutions to avoid conflicts.
