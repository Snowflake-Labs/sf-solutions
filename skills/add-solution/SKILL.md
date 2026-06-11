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

## Phase 1: Gather and plan

Ask the user for the following details (use `ask_user_question` with type "text"):

1. **slug** — kebab-case identifier, e.g. `fraud-detection`
2. **name** — human-readable solution name, e.g. `Real-Time Fraud Detection`
3. **industry** — e.g. `Financial Services`
4. **key_features** — comma-separated, e.g. `Snowflake ML, Cortex Agent, Streamlit`
5. **repo_url** — e.g. `https://github.com/Snowflake-Labs/sf-solutions-fraud-detection`

Then present a plan showing exactly which files will be created and which will be patched:

```
Files to create:
  skills/<slug>/SKILL.md
  skills/<slug>/NEXT_ACTIONS.md
  skills/<slug>/evals/evals.json
  .claude/commands/<slug>.md

Files to patch:
  skills/list/SKILL.md    — add row to catalog table
  README.md               — add row to Solution Catalog table
  .cortex-plugin/plugin.json  — add entry to skills[] array

Manual step required after scaffolding:
  ln -s ../../skills/<slug> .cortex/skills/<slug>
```

**HARD GATE: STOP. Present the plan to the user. Do NOT proceed until the user explicitly says "yes" or "proceed".**

## Phase 2: Execute

### Create skills/<slug>/SKILL.md

Fill `skills/add-solution/templates/skill-md.md` with:
- `{{slug}}` → the slug provided
- `{{name}}` → the name provided
- `{{industry}}` → the industry provided
- `{{features}}` → the key_features provided
- `{{repo_url}}` → the repo_url provided

Write the result to `skills/<slug>/SKILL.md`.

### Create skills/<slug>/NEXT_ACTIONS.md

Fill `skills/add-solution/templates/next-actions.md` with:
- `{{name}}` → the name provided

Write the result to `skills/<slug>/NEXT_ACTIONS.md`.

### Create skills/<slug>/evals/evals.json

Write a minimal evals file:
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

### Patch skills/list/SKILL.md

Read the file. Locate the catalog table. Append a new row with the next sequential number, slug, name, industry, features, and repo link. Write the file.

### Patch README.md

Read the file. Locate the Solution Catalog table. Append a new row with the same values. Write the file.

### Patch .cortex-plugin/plugin.json

Read the file. Add a new entry to the `skills[]` array:
```json
{ "name": "<slug>", "path": "skills/<slug>/SKILL.md" }
```
Write the file.

## Phase 3: Verify and instruct

Read back each created file and confirm it exists and has correct content:
- `skills/<slug>/SKILL.md` — has `name:` frontmatter
- `skills/<slug>/NEXT_ACTIONS.md` — has content
- `.claude/commands/<slug>.md` — exists
- `skills/list/SKILL.md` — contains the new table row
- `.cortex-plugin/plugin.json` — contains the new skills[] entry

Show a summary table of created and patched files.

Then instruct the user to complete the one manual step:

```
One manual step required — run this from the sf-solutions repo root:

  ln -s ../../skills/<slug> .cortex/skills/<slug>

This registers the skill for CoCo local auto-discovery.
```

## Error Recovery

| Scenario | Action |
|---|---|
| `skills/<slug>/` already exists | Show existing content, ask user whether to overwrite |
| Table row insertion point not found | Show the file and ask user to confirm the correct location |
| JSON parse error in plugin.json | Show the current file and ask user to resolve before continuing |
