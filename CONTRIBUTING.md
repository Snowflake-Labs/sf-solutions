# Contributing to sf-solutions

Thank you for contributing to Snowflake Industry Solutions!

## Repository Structure

```
sf-solutions/
├── skills/
│   ├── add-solution/         # Skill to scaffold new solutions
│   └── convert-solution/     # Skill to convert industry-plugin-construct plugins
├── templates/                # Shared config templates for industry repos
│   ├── .github/workflows/
│   ├── .pre-commit-config.yaml
│   ├── AGENTS.md.template
│   └── ...
├── docs/                     # Design documents and proposals
├── README.md
└── AGENTS.md
```

Solutions live in their respective industry repos:

- [sf-hcls-solutions](https://github.com/Snowflake-Labs/sf-hcls-solutions) — Healthcare & Life Sciences
- [sf-mleu-solutions](https://github.com/Snowflake-Labs/sf-mleu-solutions) — Manufacturing, Logistics, Energy & Utilities
- [sf-rcg-solutions](https://github.com/Snowflake-Labs/sf-rcg-solutions) — Retail, CPG & General

## Solution Structure (in industry repos)

Each solution follows this structure:

```
solutions/<solution-name>/
├── manifest.json              # Solution metadata
├── README.md                  # Public-facing documentation
├── NEXT_ACTIONS.md            # Post-install guidance
├── scripts/
│   ├── setup.sql              # Install script (idempotent)
│   ├── teardown.sql           # Cleanup script
│   └── data.sql               # Demo data (optional)
├── semantic/                  # Semantic models (optional)
├── streamlit/                 # Dashboard app (optional)
└── plugins/cortex-code/
    └── skills/<solution-name>/
        ├── SKILL.md           # Install/teardown skill
        └── NEXT_ACTIONS.md    # Post-install guidance
```

## Adding a New Solution

Use the `convert-solution` skill to convert an industry-plugin-construct plugin:

```
$sf-solutions:convert-solution /path/to/source-plugin
```

Or use `add-solution` to scaffold from an existing repo:

```
$sf-solutions:add-solution /path/to/source-repo
```

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
  1. **Retrieve and display a Snowsight URL** — marked as `[MANDATORY — DO NOT SKIP]`
  2. **Show the final summary with Next Actions**
- Include a `## Next Actions` section that references NEXT_ACTIONS.md

## NEXT_ACTIONS.md Guidelines

Structure as progressive phases:

1. **Quick Exploration** — immediate things to try (open dashboard, run queries)
2. **Use the Skills** — domain-specific skill workflows
3. **Connect Real Data** — how to replace demo data
4. **Production Deployment** — scheduling, monitoring, RBAC

## Naming Conventions

- Solution directory: `kebab-case` (e.g., `ltv-prediction`, `irops-intelligence-center`)
- Database: `SF_SOLUTIONS` (shared across all solutions)
- Schemas: `UPPER_SNAKE_CASE` (e.g., `LTV_RAW`, `IROPS_DATA_MART`)

## Testing

Before submitting a PR:

1. Run `setup.sql` end-to-end on a clean account
2. Verify all objects are created (check INFORMATION_SCHEMA)
3. Run the install SKILL.md via Cortex Code (`$sf-mleu-solutions:<name>`)
4. Open the Snowsight URL and confirm it loads without errors
5. Run `teardown.sql` and verify everything is removed
