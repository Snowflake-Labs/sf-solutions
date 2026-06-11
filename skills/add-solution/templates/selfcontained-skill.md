---
name: {{slug}}
skill_type: solution
solution_type: self-contained
industry: {{industry}}
snowflake_features:
{{snowflake_features_yaml}}
tags: [{{tags}}]
status: {{status}}
version: "1.0.0"
description: >
  {{name}} — a self-contained Snowflake solution skill.
  Use when: "run {{slug}}", "start {{slug}}", "{{slug}} solution",
  "{{name}} demo", "{{slug}} step 1", "{{slug}} cleanup",
  "$snowflake-solutions:{{slug}}".
  Industry: {{industry}}. Features: {{features}}.
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Read
  - Glob
  - ask_user_question
---

# {{name}}

This skill follows [[solutions-scaffold]] Tier 1 conventions.

## Routing

| Invocation | Action |
|---|---|
| `$snowflake-solutions:{{slug}}` | Introduction and step overview |
| `$snowflake-solutions:{{slug}} step 1` | → `steps/step-1.md` |
| `$snowflake-solutions:{{slug}} step N` | → `steps/step-N.md` |
| `$snowflake-solutions:{{slug}} cleanup` | → `cleanup/SKILL.md` |
| `$snowflake-solutions:{{slug}} next` | Present NEXT_ACTIONS.md |

Parse the action from `$ARGUMENTS`:

- If `$ARGUMENTS` is empty → run **Introduction** flow
- If `$ARGUMENTS` starts with "step" → route to the matching `steps/step-N.md`
- If `$ARGUMENTS` is "cleanup" → route to `cleanup/SKILL.md`
- If `$ARGUMENTS` is "next" → run **Next Actions** flow
- Otherwise → show **Usage Help**

## Overview

- **Industry:** {{industry}}
- **Features:** {{features}}
- **Role Required:** ACCOUNTADMIN
- **Steps:** (update count after adding step files)

## Introduction

Present to the user when invoked with no arguments:

```text
{{name}}

This solution will walk you through N steps:
  Step 1: (title)
  Step 2: (title)
  ...

To begin:
  $snowflake-solutions:{{slug}} step 1

To clean up:
  $snowflake-solutions:{{slug}} cleanup
```

**STOP — wait for the user to explicitly start a step.**

## Step Execution

For each step, read the corresponding `steps/step-N.md` file and follow
its instructions. Each step file must present:

1. **Why this matters** — the teaching moment or business context
2. **What we'll do** — preview of actions for this step
3. Execute actions (SQL, configuration, etc.)
4. **What we did** — summary of completed work

**STOP before executing any SQL — present the plan and wait for confirmation.**

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
| SQL error during a step | Stop; show the failing statement and error; ask user whether to retry or skip |
| Step file not found | Inform user which step file is missing; list available steps |
| Cleanup — object not found | Skip the missing object; list skipped items in the summary |

## Completion Criteria

The solution walkthrough is complete when:

- All steps have been executed and confirmed
- User has seen the completion summary
- NEXT_ACTIONS.md Quick Exploration section has been presented

## Usage Help

```text
Usage:
  $snowflake-solutions:{{slug}}           — Introduction and step overview
  $snowflake-solutions:{{slug}} step N    — Run step N
  $snowflake-solutions:{{slug}} cleanup   — Remove all created objects
  $snowflake-solutions:{{slug}} next      — Show next actions and guides
```
