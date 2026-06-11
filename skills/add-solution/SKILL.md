---
name: add-solution
description: >
  Scaffolds a new solution into the sf-solutions plugin catalog.
  Use when: "add a solution", "add new solution", "register a solution",
  "new solution skill", "scaffold solution skill", "add <name> to the catalog",
  "contribute a solution", "onboard a new solution",
  "$snowflake-solutions:add-solution".
tools:
  - Write
  - Edit
  - Read
  - Glob
  - Grep
  - Bash
  - ask_user_question
---

# Add Solution to Catalog

## Routing

| Invocation | Action |
|---|---|
| `$snowflake-solutions:add-solution` | Full scaffolding flow |

## Prohibitions

- Do NOT write any files before the user approves the plan in Phase 1.
- Do NOT guess repo URLs — always ask the user.
- Do NOT create the `.cortex/skills/<slug>` symlink directly — instruct the user to run the shell command.
- Do NOT skip the `skill-development` review in Phase 3 — it is mandatory.

## Phase 1: Gather and plan

Ask the user for the following details (use `ask_user_question` with type "text"):

1. **slug** — kebab-case identifier, e.g. `fraud-detection`
2. **name** — human-readable solution name, e.g. `Real-Time Fraud Detection`
3. **industry** — e.g. `Financial Services`
4. **snowflake_features** — comma-separated list of Snowflake products used
5. **tags** — comma-separated labels, e.g. `ml, cortex, streamlit`
6. **repo_url** — e.g. `https://github.com/Snowflake-Labs/sf-solutions-fraud-detection`
7. **status** — one of: `available`, `coming-soon` (default: `coming-soon`)

Then present a plan showing exactly which files will be created and which will be patched:

```
Files to create:
  skills/<slug>/SKILL.md
  skills/<slug>/NEXT_ACTIONS.md
  skills/<slug>/evals/evals.json
  .claude/commands/<slug>.md

Files to patch:
  catalog.yaml                    — add solution entry
  README.md                       — note new solution in catalog section (if status=available)
  .cortex-plugin/plugin.json      — add entry to skills[] array

Manual step required after scaffolding:
  ln -s ../../skills/<slug> .cortex/skills/<slug>
```

**HARD GATE: STOP. Present the plan to the user. Do NOT proceed until the user explicitly says "yes" or "proceed".**

## Phase 2: Execute

### Create skills/<slug>/SKILL.md

Read `skills/add-solution/templates/skill-md.md`. Replace all placeholders:
- `{{slug}}` → slug
- `{{name}}` → name
- `{{industry}}` → industry
- `{{features}}` → snowflake_features (comma-separated)
- `{{repo_url}}` → repo_url

Write to `skills/<slug>/SKILL.md`.

### Create skills/<slug>/NEXT_ACTIONS.md

Read `skills/add-solution/templates/next-actions.md`. Replace:
- `{{name}}` → name

Write to `skills/<slug>/NEXT_ACTIONS.md`.

### Create skills/<slug>/evals/evals.json

```json
{
  "skill_name": "<slug>",
  "evals": [
    {
      "id": 1,
      "prompt": "install <name>",
      "expected_output": "Skill clones solution repo, presents plan, waits for confirmation, executes setup.sql, shows completion summary",
      "expectations": [
        "Presents installation plan before executing any SQL",
        "Waits for explicit user confirmation"
      ]
    }
  ]
}
```

### Create .claude/commands/<slug>.md

```markdown
---
description: "Install or teardown the <name> solution"
---

Load and follow `skills/<slug>/SKILL.md`.

To install: say "install <slug>"
To teardown: say "<slug> teardown"
To see what's next: say "<slug> next actions"
```

### Patch catalog.yaml

Read `catalog.yaml`. Append to the `solutions:` list:

```yaml
- slug: <slug>
  name: <name>
  industry: <industry>
  snowflake_features:
    - <feature 1>
    - <feature 2>
  tags: [<tag1>, <tag2>]
  repo: <repo_url>
  status: <status>
  version: "1.0.0"
```

### Patch .cortex-plugin/plugin.json

Read the file. Add to `skills[]` array:
```json
{ "name": "<slug>", "path": "skills/<slug>/SKILL.md" }
```

## Phase 3: Review and verify

### Invoke skill-development for review

**MANDATORY — DO NOT SKIP.**

Invoke the bundled `skill-development` skill to review the generated `skills/<slug>/SKILL.md`:

```
skill(command="skill-development")
```

Pass the path `skills/<slug>/SKILL.md` for review. The skill-development skill will check:
- Frontmatter completeness (`name`, `description`)
- Description is "pushy" (enumerates trigger phrases)
- Required sections present (Routing, Error Recovery, Completion Criteria)
- No prohibited anti-patterns

Apply any findings before proceeding to the file-existence check.

### Verify file existence

Read back each created file and confirm it exists with correct content:
- `skills/<slug>/SKILL.md` — has `name:` frontmatter
- `skills/<slug>/NEXT_ACTIONS.md` — has content
- `.claude/commands/<slug>.md` — exists
- `catalog.yaml` — contains the new slug entry
- `.cortex-plugin/plugin.json` — contains the new skills[] entry

### Show summary and manual step

Present a summary table of created and patched files.

Then instruct the user to complete the one manual step:

```
One manual step required — run this from the sf-solutions repo root:

  ln -s ../../skills/<slug> .cortex/skills/<slug>

This registers the skill for CoCo local auto-discovery.
After running it, verify with:
  ls -la .cortex/skills/
```

## Error Recovery

| Scenario | Action |
|---|---|
| `skills/<slug>/` already exists | Show existing content; ask user whether to overwrite |
| YAML parse error in catalog.yaml | Show parse error and line number; ask user to fix before continuing |
| JSON parse error in plugin.json | Show current file; ask user to resolve before continuing |
| skill-development review finds blockers | Address each blocker before marking Phase 3 complete |
