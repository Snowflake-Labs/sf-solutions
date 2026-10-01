# Plugin Type Conversion Reference

This reference is loaded by `convert-solution` SKILL.md when the solution type is "plugin".

## Phase 2: Source Analysis (Plugin-specific)

Read the plugin manifest:
- `.cortex-plugin/plugin.json` or `plugin.json` at source root

Inventory all plugin components:
- **Skills** — `skills/<name>/SKILL.md` files (list names and descriptions)
- **Agents** — `agents/<name>.md` files
- **References** — `references/<name>.md` files
- **Hooks** — `hooks/hooks.json` (list events and commands)
- **MCP Servers** — `.mcp.json` (list server names)

Scan SQL files (if `scripts/` exists) for source DB/WH names.

## Phase 4: File Generation (Plugin-specific)

### Directory structure

```
solutions/<solution-name>/
├── manifest.json                  # type: "plugin", plugin_path: "plugins/cortex-code"
├── README.md                      # With disclaimer
├── NEXT_ACTIONS.md                # Optional (if source has one)
├── scripts/
│   ├── setup.sql                  # Adapted SQL (if source has SQL)
│   └── teardown.sql               # Generated
└── plugins/cortex-code/
    ├── .cortex-plugin/
    │   └── plugin.json            # Copied from source
    ├── skills/
    │   └── <skill-name>/
    │       └── SKILL.md           # Copied from source
    ├── agents/                    # Copied from source (if present)
    │   └── <agent-name>.md
    └── references/                # Copied from source (if present)
        └── <ref-name>.md
```

### Copy plugin files

1. Copy `.cortex-plugin/plugin.json` to `plugins/cortex-code/.cortex-plugin/`
2. Copy all `skills/` directories to `plugins/cortex-code/skills/`
3. Copy all `agents/` files to `plugins/cortex-code/agents/`
4. Copy all `references/` files to `plugins/cortex-code/references/`
5. Do NOT copy `hooks/` — hooks need security review and may contain grandchild install logic

### Generate/adapt SQL files

If the source has `scripts/setup.sql`:
- Adapt database references to `SF_SOLUTIONS`
- Adapt warehouse references to `SF_SOLUTIONS_WH`
- Add `USE ROLE ACCOUNTADMIN;` at top

If the source has no SQL files but `manifest.json` lists `install_scripts`:
- Create a minimal `setup.sql` that creates the shared infrastructure

### Generate teardown.sql

```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE SF_SOLUTIONS;
USE WAREHOUSE SF_SOLUTIONS_WH;

DROP SCHEMA IF EXISTS <SCHEMA_1>;
-- NEVER drop SF_SOLUTIONS database or SF_SOLUTIONS_WH warehouse
```

### Adapt SKILL.md files

In each copied SKILL.md:
- Replace any source database/warehouse references with `SF_SOLUTIONS` / `SF_SOLUTIONS_WH`
- Verify no hardcoded paths or internal URLs remain

### manifest.json

Must include:

```json
{
  "type": "plugin",
  "plugin_path": "plugins/cortex-code",
  ...
}
```
