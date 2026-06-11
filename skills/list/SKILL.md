---
name: list
description: >
  Lists all available Snowflake industry solutions in the catalog with rich metadata.
  Use when: "list solutions", "what solutions are available", "show solutions",
  "show catalog", "what can I install", "available solutions",
  "solutions by industry", "what Snowflake features are used",
  "$snowflake-solutions:list", "what snowflake solutions exist".
tools:
  - Read
  - Bash
---

# List Available Solutions

## Routing

| Invocation | Action |
|---|---|
| `$snowflake-solutions:list` | Present full catalog from catalog.yaml |
| `$snowflake-solutions:list <industry>` | Filter catalog by industry |
| `$snowflake-solutions:list <tag>` | Filter catalog by tag |

## Instructions

1. Read `catalog.yaml` from the repo root.

2. If `solutions` is empty, present:
   ```
   No solutions registered yet.
   To add the first solution: $snowflake-solutions:add-solution
   ```
   Then stop.

3. Otherwise, present a rich catalog table:

   **Snowflake Industry Solutions**

   | # | Solution | Industry | Snowflake Features | Tags | Status | Repo |
   |---|----------|----------|--------------------|------|--------|------|
   | (one row per catalog.yaml entry) | | | | | | |

   For each entry:
   - **#**: sequential number
   - **Solution**: `name` field, bold
   - **Industry**: `industry` field
   - **Snowflake Features**: `snowflake_features` list joined with ` · `
   - **Tags**: `tags` list formatted as `` `tag1` `tag2` ``
   - **Status**: `status` — render as `available`, `coming-soon`, or `deprecated`
   - **Repo**: link text = `source`, href = `repo` field

4. After the table, present grouped summaries:

   **By Industry:**
   (group solution names by industry field)

   **By Snowflake Feature:**
   (group solution slugs by each feature they use)

5. After the summaries, add:
   ```
   To install a solution:
     $snowflake-solutions:<slug>
     $snowflake-solutions:<slug> teardown
     $snowflake-solutions:<slug> next

   To add a new solution to this catalog:
     $snowflake-solutions:add-solution
   ```

6. If `$ARGUMENTS` contains a filter term (industry or tag), show only matching entries and note how many were filtered out.

## Error Recovery

| Scenario | Action |
|---|---|
| `catalog.yaml` not found | Inform user the catalog file is missing; suggest running `git status` to check repo state |
| YAML parse error | Show the parse error and line number; ask user to fix catalog.yaml |
| `solutions` key missing | Treat as empty catalog and show the empty-state message |
