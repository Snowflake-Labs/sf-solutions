# Contributing to sf-solutions

Thank you for contributing to Snowflake Industry Solutions!

## Repository Structure

```
sf-solutions/
├── .claude-plugin/           # Root marketplace manifest for Claude Code
├── plugins/
│   ├── claude-code/          # Claude Code plugin (skills + manifests)
│   │   ├── .claude-plugin/
│   │   └── skills/<solution-name>/
│   └── cortex-code/          # Cortex Code plugin (skills + manifest)
│       ├── .cortex-plugin/
│       └── skills/<solution-name>/
├── solutions/
│   └── <solution-name>/      # Solution assets (SQL, Streamlit, prompts)
│       ├── manifest.json
│       ├── scripts/setup.sql
│       ├── scripts/teardown.sql
│       └── streamlit/        # Optional dashboard
└── README.md
```

## Adding a New Solution

When adding a new solution, you must create files in **three** places:

### 1. `solutions/<solution-name>/`

All SQL scripts, Streamlit apps, data, and prompts go here.

Required files:
- `manifest.json` — solution metadata (name, industry, database, schemas, features)
- `scripts/setup.sql` — full installation script (idempotent, uses CREATE OR REPLACE)
- `scripts/teardown.sql` — cleanup script (drops all created objects)

Optional:
- `streamlit/` — Streamlit dashboard files
- `prompts/` — demo prompts for Cortex Code or Snowflake Intelligence

### 2. `plugins/cortex-code/skills/<solution-name>/`

Required:
- `SKILL.md` — Cortex Code skill definition (frontmatter + install/teardown instructions)
- `NEXT_ACTIONS.md` — post-install guidance (what to do after installation)

### 3. `plugins/claude-code/skills/<solution-name>/`

Required:
- `SKILL.md` — Claude Code skill definition (same structure, different tool names)
- `NEXT_ACTIONS.md` — post-install guidance (same content as cortex-code version)

## File Descriptions

| File | Purpose |
|------|---------|
| `SKILL.md` | Defines the install/teardown workflow. The agent reads this to know how to execute the solution. |
| `NEXT_ACTIONS.md` | Answers "what should I do next?" after installation. Progressive guidance from exploration to production. |
| `manifest.json` | Machine-readable metadata: name, version, industry, database, schemas, features, script paths. |
| `setup.sql` | The single SQL script that creates everything (database, schemas, tables, models, Streamlit). |
| `teardown.sql` | Drops all objects created by setup.sql. |

## SKILL.md Guidelines

- Use `$ARGUMENTS` to differentiate install vs teardown
- The **last two steps** before teardown must always be:
  1. **Retrieve and display the Streamlit URL** (if applicable) — marked as `[MANDATORY — DO NOT SKIP]`
  2. **Show the final summary with Next Actions**
- Include a `## Next Actions` section that references NEXT_ACTIONS.md
- The step numbers will vary by solution (e.g., a simple solution may use Steps 5-6, a complex one Steps 9-10)

## NEXT_ACTIONS.md Guidelines

This file is read when the user asks "what next?" or "what should I do?" after installing. Structure it as progressive phases:

1. **Quick Exploration** — immediate things to try (open dashboard, run queries)
2. **Customize with Your Data** — how to replace demo data
3. **Tune the Model** — adjust parameters, add features
4. **Production Deployment** — scheduling, monitoring, RBAC

## Streamlit URL Format

Always use this format for Snowsight URLs:
```
https://app.snowflake.com/<org>/<account>/#/streamlit-apps/<DB>.<SCHEMA>.<STREAMLIT_NAME>
```

SQL to generate:
```sql
SELECT 'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
    || '/#/streamlit-apps/<DB>.<SCHEMA>.<NAME>' AS STREAMLIT_URL;
```

## Naming Conventions

- Solution directory: `kebab-case` (e.g., `ltv-prediction`, `clinical-quality-agent`)
- Database: `SF_SOLUTIONS` (shared across all solutions)
- Schemas: `UPPER_SNAKE_CASE` (e.g., `LTV_RAW`, `LTV_ANALYTICS`, `LTV_ML`)
- Streamlit apps: `UPPER_SNAKE_CASE` (e.g., `LTV_PREDICTION_DASHBOARD`)

## Testing

Before submitting a PR:
1. Load plugin in Cortex Code CLI
2. Load plugin in Claude Code CLI
3. Run `setup.sql` end-to-end on a clean account
4. Verify all objects are created (check INFORMATION_SCHEMA)
5. Open the Streamlit dashboard URL and confirm it loads without errors
6. Run `teardown.sql` and verify everything is removed
7. Test both Cortex Code (`$snowflake-solutions:<name>`) and Claude Code (`/snowflake-solutions:<name>`) skill execution
