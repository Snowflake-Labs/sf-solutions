# Snowflake Industry Solutions

A **plugin catalog** for Snowflake industry solution accelerators. Each solution lives in its own dedicated repository; this repo provides the plugin skills that bootstrap and install them into your Snowflake account via Cortex Code or Claude Code.

Solution metadata is maintained in [`catalog.yaml`](catalog.yaml). The catalog grows as solutions are added via `$snowflake-solutions:add-solution`.

---

## Solution Catalog

The catalog is managed in `catalog.yaml`. To see the current list with full metadata (industry, Snowflake features, tags, status):

```
$snowflake-solutions:list
```

To add a new solution:

```
$snowflake-solutions:add-solution
```

---

## Quick Install (via Cortex Code)

```bash
# Install the plugin
cortex plugin install https://github.com/Snowflake-Labs/sf-solutions.git

# Or load locally during development
cortex --plugin-dir /path/to/sf-solutions
```

Then in a Cortex Code session:

```
# List all solutions with metadata
$snowflake-solutions:list

# Install a solution (slug from catalog)
$snowflake-solutions:<slug>
$snowflake-solutions:<slug> teardown
$snowflake-solutions:<slug> next

# Add a new solution to the catalog
$snowflake-solutions:add-solution
```

## Quick Install (via Claude Code)

```bash
# Add the marketplace
claude plugin marketplace add https://github.com/Snowflake-Labs/sf-solutions.git

# Install the plugin
claude plugin install snowflake-solutions
```

Then run:

```
/snowflake-solutions:list
/snowflake-solutions:<slug>
/snowflake-solutions:add-solution
```

Requires the [snowflake-cortex-code](https://claude.com/plugins/snowflake-cortex-code) plugin (auto-installed as dependency).

---

## Repository Structure

```
sf-solutions/
├── .cortex-plugin/
│   ├── plugin.json               # CoCo plugin manifest (skills[] array)
│   └── skills                    # SYMLINK → ../skills
├── .cortex/
│   └── skills/
│       └── <name>                # SYMLINK → ../../skills/<name>
├── .claude-plugin/
│   ├── plugin.json               # Claude marketplace manifest
│   └── marketplace.json
├── .claude/
│   └── commands/
│       └── <name>.md             # thin Claude adapters
├── skills/                       # CANONICAL skill content
│   ├── list/                     # catalog browser (reads catalog.yaml)
│   └── add-solution/             # scaffolds new solution skills
├── catalog.yaml                  # solution metadata (slug, industry, features, tags, repo)
├── hooks/
│   ├── hooks.json
│   └── allow-solution-commands.sh
├── CONTRIBUTING.md
└── README.md
```

Skills use sparse checkout to clone solution runtime code from per-solution repos at invocation time — no solution code lives in this repo.

---

## Prerequisites

- Snowflake account (Enterprise edition recommended)
- Appropriate role with `CREATE DATABASE` / `SCHEMA` privileges
- Warehouse (default: `COMPUTE_WH`)

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide on adding a new solution, including the PR checklist and Claude marketplace requirements.

---

## Framework Skills

| Skill | Purpose |
|-------|---------|
| [solutions-scaffold](skills/solutions-scaffold/SKILL.md) | Shared engineering conventions (SKILL.md structure, plan mode gate, manifest schema, snow CLI rules) for building sf-solutions skills |

---

## Related Resources

- [Snowflake ML](https://docs.snowflake.com/en/developer-guide/snowflake-ml/overview)
- [Cortex AI Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)
- [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)
- [Snowflake Notebooks](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks)
