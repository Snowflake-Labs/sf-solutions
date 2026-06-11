---
name: {{slug}}
skill_type: solution
solution_type: bootstrap
industry: {{industry}}
snowflake_features:
{{snowflake_features_yaml}}
tags: [{{tags}}]
repo: {{repo_url}}
status: {{status}}
version: "1.0.0"
description: >
  Installs or tears down the {{name}} solution in Snowflake.
  Use when: "install {{slug}}", "set up {{slug}}", "{{slug}} solution",
  "{{name}} demo", "{{slug}} teardown", "remove {{slug}}",
  "{{slug}} next actions", "$snowflake-solutions:{{slug}}".
  Industry: {{industry}}. Features: {{features}}.
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Bash
  - Read
  - Glob
  - Grep
  - WebFetch
---

# {{name}}

This skill follows [[solutions-scaffold]] Tier 1 conventions.

## Routing

| Invocation | Action |
|---|---|
| `$snowflake-solutions:{{slug}}` | Install flow |
| `$snowflake-solutions:{{slug}} teardown` | Teardown flow |
| `$snowflake-solutions:{{slug}} next` | Present NEXT_ACTIONS.md |

Parse the action from `$ARGUMENTS`:
- If `$ARGUMENTS` is "install" or empty → run **Install** flow
- If `$ARGUMENTS` is "teardown" → run **Teardown** flow
- If `$ARGUMENTS` is "next" → run **Next Actions** flow
- Otherwise → show **Usage Help**

## Overview

- **Industry:** {{industry}}
- **Features:** {{features}}
- **Role Required:** ACCOUNTADMIN

## Install

1. Clone the solution repository:
   ```bash
   git clone --filter=blob:none --no-checkout \
     {{repo_url}}.git \
     /tmp/sf-solutions-{{slug}}
   cd /tmp/sf-solutions-{{slug}}
   git checkout main -- scripts/ manifest.json
   ```

2. Read `/tmp/sf-solutions-{{slug}}/manifest.json`.

3. Present the installation plan and wait for user confirmation.

   **STOP — do not execute any SQL until the user confirms.**

4. Read `/tmp/sf-solutions-{{slug}}/scripts/setup.sql` and execute statement by statement using `snowflake_sql_execute`.
   - Log progress after each major section.

5. Verify installation via `INFORMATION_SCHEMA.TABLES`.

6. Show final summary with teardown command.

7. Read `NEXT_ACTIONS.md` from this skill directory and present the **Quick Exploration** section.

## Teardown

1. Confirm with user: "This will remove all {{name}} objects. Proceed? (yes/no)"
2. **STOP — do not execute until confirmed.**
3. Read and execute `/tmp/sf-solutions-{{slug}}/scripts/teardown.sql` statement by statement.
4. Confirm: "{{name}} removed."

## Next Actions

Read `NEXT_ACTIONS.md` from this skill directory and present the relevant section:

| User intent | Section |
|---|---|
| Just exploring | Quick Exploration |
| Wants to use own data | Customize with Your Data |
| Wants better results | Tune and Optimize |
| Ready for production | Production Deployment |

## Error Recovery

| Scenario | Action |
|---|---|
| `git clone` fails (repo not found) | Inform user the solution repo has not been published yet; link to CONTRIBUTING.md |
| SQL error during setup | Stop; show the failing statement and error; ask user whether to retry or abort |
| Teardown — object not found | Skip the missing object and continue; list skipped items in the summary |

## Completion Criteria

Install is complete when:
- All expected schemas exist in INFORMATION_SCHEMA.TABLES
- A summary with the created objects has been shown to the user
- NEXT_ACTIONS.md Quick Exploration section has been presented

## Usage Help

```
Usage:
  $snowflake-solutions:{{slug}}           — Install the solution
  $snowflake-solutions:{{slug}} teardown   — Remove the solution
  $snowflake-solutions:{{slug}} next       — Show next actions and guides
```
