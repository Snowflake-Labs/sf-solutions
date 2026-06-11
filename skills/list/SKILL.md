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
  - Glob
---

# List Available Solutions

## Routing

| Invocation | Action |
|---|---|
| `$snowflake-solutions:list` | Present full auto-discovered catalog |
| `$snowflake-solutions:list <industry>` | Filter by industry |
| `$snowflake-solutions:list <tag>` | Filter by tag |

## Instructions

The catalog is built by scanning skill frontmatter — there is no separate catalog file.

### Step 1: Discover solution skills

Use Glob to find all `skills/*/SKILL.md` files.

For each file found:
1. Read the file and parse the YAML frontmatter block (the `---` delimited section at the top).
2. Include the entry **only if** `skill_type: solution` is present in the frontmatter.
   Skills without `skill_type: solution` (e.g. `list`, `add-solution`, `solutions-scaffold`) are framework skills — exclude them.
3. Extract these fields from the frontmatter:
   - `name` — skill slug
   - `industry`
   - `snowflake_features` — YAML list
   - `tags` — YAML list
   - `repo` — URL
   - `status` — `available` | `coming-soon` | `deprecated`
   - `version`

### Step 2: If no solution skills found

Present:
```
No solutions registered yet.

To add the first solution:
  $snowflake-solutions:add-solution
```
Then stop.

### Step 3: Build and display the catalog

Present a header and rich table:

**Snowflake Industry Solutions** — *N solution(s) registered*

| # | Solution | Industry | Snowflake Features | Tags | Status | Repo |
|---|----------|----------|--------------------|------|--------|------|

For each entry (sorted by industry, then name):
- **#**: sequential number
- **Solution**: `name` in bold
- **Industry**: `industry` field
- **Snowflake Features**: `snowflake_features` list joined with ` · `
- **Tags**: each tag formatted as `` `tag` ``
- **Status**: `available` / `coming-soon` / `deprecated`
- **Repo**: `[source](repo_url)`

### Step 4: Grouped summaries

**By Industry:**
Group solution names under each industry heading.

**By Snowflake Feature:**
Group solution slugs under each feature they use.

### Step 5: Usage footer

```
To install a solution:
  $snowflake-solutions:<slug>
  $snowflake-solutions:<slug> teardown
  $snowflake-solutions:<slug> next

To add a new solution:
  $snowflake-solutions:add-solution
```

### Step 6: Apply filter (if $ARGUMENTS provided)

If `$ARGUMENTS` is non-empty, re-run the display showing only entries where
`industry` or any `tags` entry contains the argument string (case-insensitive).
Note how many entries were filtered out.

## Error Recovery

| Scenario | Action |
|---|---|
| No `skills/` directory found | Inform user the repo may be in an unexpected state; show `git status` suggestion |
| SKILL.md frontmatter is malformed YAML | Skip that file and note it in a warnings section at the bottom of output |
| `skill_type` field absent | Skip the file (treat as framework skill) |
