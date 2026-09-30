---
name: list
description: "List available Snowflake industry solution accelerators. Usage: $sf-solutions:list (all solutions), $sf-solutions:list retail (filter by industry). Triggers: solutions, list solutions, available solutions, industry solutions, what solutions, show solutions, MLEU, manufacturing, retail, healthcare, marketing."
user-invocable: true
metadata:
  author: Snowflake
  version: 1.0.0
---

# List Solutions

List available Snowflake industry solution accelerators from the registry.

## Step 1: Load the Registry

Read `registry.json` from the `install` skill directory (sibling to this skill at `../install/registry.json`). The registry structure:

```json
[
  {
    "industry": "<industry-id>",
    "description": "<industry description>",
    "repo": "<github-repo-url>",
    "solutions": [
      {"name": "<solution-name>", "description": "<short description>"}
    ]
  }
]
```

## Step 2: Filter

- If `$ARGUMENTS` is empty → show all solutions
- If `$ARGUMENTS` matches an industry name (case-insensitive partial match) → show only that industry
- Otherwise → show usage help

## Step 3: Display

Present a table dynamically generated from registry.json:

```
Available Solutions:
┌───┬──────────────────────┬───────────────┬─────────────────────────────┐
│ # │ Solution             │ Industry      │ Description                 │
├───┼──────────────────────┼───────────────┼─────────────────────────────┤
│   │ (from registry.json) │               │                             │
└───┴──────────────────────┴───────────────┴─────────────────────────────┘

Commands:
• Install a solution:    $sf-solutions:install <solution-name>
• Remove a solution:     $sf-solutions:teardown <solution-name>
• Post-install guidance: $sf-solutions:next <solution-name>
• Filter by industry:    $sf-solutions:list <industry-name>
```

**STOP** after listing. Do not install anything unless explicitly requested.
