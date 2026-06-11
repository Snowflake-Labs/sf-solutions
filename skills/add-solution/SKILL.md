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

### Step 1 — Ask for solution type

Use `ask_user_question` (options type) to ask:

> What kind of solution is this?
>
> - **Bootstrap** — logic lives in an external GitHub repo; skill clones it at invocation time
> - **Self-contained** — all logic (SQL, steps, scripts) lives inside this skill directory; no external repo needed

Store the answer as `solution_type` (`bootstrap` | `self-contained`).

### Step 2 — Ask for common fields

Use `ask_user_question` (text type) for:

1. **slug** — kebab-case identifier, e.g. `fraud-detection`
2. **name** — human-readable solution name, e.g. `Real-Time Fraud Detection`
3. **industry** — e.g. `Financial Services`
4. **snowflake_features** — comma-separated list of Snowflake products used
5. **tags** — comma-separated labels, e.g. `ml, cortex, streamlit`
6. **status** — one of: `available`, `coming-soon` (default: `coming-soon`)

### Step 3 — Ask for bootstrap-only field

If `solution_type` is `bootstrap`, also ask:

1. **repo_url** — e.g. `https://github.com/Snowflake-Labs/sf-solutions-fraud-detection`

### Step 4 — Present plan

Present a plan showing exactly which files will be created and which will be patched.

**For bootstrap:**

```text
Solution type: bootstrap (clones external repo at invocation time)

Files to create:
  skills/<slug>/SKILL.md          — from templates/bootstrap-skill.md
  skills/<slug>/NEXT_ACTIONS.md
  skills/<slug>/evals/evals.json
  .claude/commands/<slug>.md

Files to patch:
  .cortex-plugin/plugin.json      — add entry to skills[] array

Manual step required after scaffolding:
  ln -s ../../skills/<slug> .cortex/skills/<slug>
```

**For self-contained:**

```text
Solution type: self-contained (all logic lives in the skill directory)

Files to create:
  skills/<slug>/SKILL.md          — from templates/selfcontained-skill.md
  skills/<slug>/NEXT_ACTIONS.md
  skills/<slug>/steps/step-1.md   — starter step file (fill in content)
  skills/<slug>/cleanup/SKILL.md  — teardown flow
  skills/<slug>/evals/evals.json
  .claude/commands/<slug>.md

Files to patch:
  .cortex-plugin/plugin.json      — add entry to skills[] array

Manual step required after scaffolding:
  ln -s ../../skills/<slug> .cortex/skills/<slug>
```

**HARD GATE: STOP. Present the plan to the user. Do NOT proceed until the user explicitly says "yes" or "proceed".**

## Phase 2: Execute

### Create skills/<slug>/SKILL.md

**If `solution_type` is `bootstrap`:**

Read `skills/add-solution/templates/bootstrap-skill.md`. Replace placeholders:

- `{{slug}}` → slug
- `{{name}}` → name
- `{{industry}}` → industry
- `{{features}}` → snowflake_features as comma-separated string
- `{{snowflake_features_yaml}}` → each feature as an indented YAML line:

  ```yaml
    - Snowflake ML Regression
    - Cortex AI Functions
  ```

- `{{tags}}` → comma-separated tag list
- `{{repo_url}}` → repo_url
- `{{status}}` → status

**If `solution_type` is `self-contained`:**

Read `skills/add-solution/templates/selfcontained-skill.md`. Replace same placeholders
(omit `{{repo_url}}` — not present in self-contained template).

Write to `skills/<slug>/SKILL.md`.

### Create skills/<slug>/NEXT_ACTIONS.md

Read `skills/add-solution/templates/next-actions.md`. Replace `{{name}}` → name.
Write to `skills/<slug>/NEXT_ACTIONS.md`.

### Create self-contained extras (only for self-contained type)

**`skills/<slug>/steps/step-1.md`** — starter step scaffold:

```markdown
# Step 1: (title)

## Why this matters

(Explain the teaching moment or business context for this step.)

## What we'll do

(Preview the actions for this step.)

## Actions

(SQL, configuration, or instructions go here.)

**STOP — present the plan above and wait for user confirmation before executing.**

## What we did

(Summary of completed work — fill in after execution.)
```

**`skills/<slug>/cleanup/SKILL.md`** — teardown:

```markdown
---
name: {{slug}}-cleanup
description: Remove all {{name}} objects (reverse of install).
---

# Cleanup: {{name}}

1. Confirm with user: "This will remove all {{name}} objects. Proceed? (yes/no)"
2. **STOP — do not execute until confirmed.**
3. Execute DROP statements for all created objects.
4. Confirm: "{{name}} removed."
```

### Create skills/<slug>/evals/evals.json

For bootstrap:

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

For self-contained:

```json
{
  "skill_name": "<slug>",
  "evals": [
    {
      "id": 1,
      "prompt": "$snowflake-solutions:<slug>",
      "expected_output": "Presents introduction with step overview; does not execute anything without user initiating a step",
      "expectations": [
        "Shows step overview",
        "Does not execute SQL before user starts a step"
      ]
    },
    {
      "id": 2,
      "prompt": "$snowflake-solutions:<slug> step 1",
      "expected_output": "Reads steps/step-1.md, presents Why/What/Do/Summary, waits for confirmation before SQL",
      "expectations": [
        "Reads the correct step file",
        "Waits for confirmation before any SQL execution"
      ]
    }
  ]
}
```

### Create .claude/commands/<slug>.md

For bootstrap:

```markdown
---
description: "Install or teardown the <name> solution"
---

Load and follow `skills/<slug>/SKILL.md`.

To install: say "install <slug>"
To teardown: say "<slug> teardown"
To see what's next: say "<slug> next actions"
```

For self-contained:

```markdown
---
description: "Run the <name> solution walkthrough"
---

Load and follow `skills/<slug>/SKILL.md`.

To start: say "start <slug>" or "<slug> step 1"
To clean up: say "<slug> cleanup"
```

### Patch .cortex-plugin/plugin.json

Add to `skills[]` array:

```json
{ "name": "<slug>", "path": "skills/<slug>/SKILL.md" }
```

## Phase 3: Review and verify

### Invoke skill-development for review

**MANDATORY — DO NOT SKIP.**

Invoke the bundled `skill-development` skill to review `skills/<slug>/SKILL.md`:

```text
skill(command="skill-development")
```

Checks: frontmatter completeness (`name`, `description`, `skill_type`, `solution_type`),
pushy description, required sections (Routing, Error Recovery, Completion Criteria),
no prohibited anti-patterns. Apply any findings before proceeding.

### Verify file existence

Read back each created file and confirm correct content:

- `skills/<slug>/SKILL.md` — has `skill_type: solution` and `solution_type` in frontmatter
- `skills/<slug>/NEXT_ACTIONS.md` — has content
- `.claude/commands/<slug>.md` — exists
- `.cortex-plugin/plugin.json` — contains the new skills[] entry
- (self-contained only) `skills/<slug>/steps/step-1.md` and `skills/<slug>/cleanup/SKILL.md` exist

### Show summary and manual step

Present a summary table of created and patched files.

Then instruct the user to complete the one manual step:

```text
One manual step required — run this from the sf-solutions repo root:

  ln -s ../../skills/<slug> .cortex/skills/<slug>

After running it, verify with:
  ls -la .cortex/skills/
```

## Error Recovery

| Scenario | Action |
|---|---|
| `skills/<slug>/` already exists | Show existing content; ask user whether to overwrite |
| JSON parse error in plugin.json | Show current file; ask user to resolve before continuing |
| skill-development review finds blockers | Address each blocker before marking Phase 3 complete |
