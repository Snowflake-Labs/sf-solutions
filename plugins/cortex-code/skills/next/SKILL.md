---
name: next
description: "Show post-install guidance for a Snowflake industry solution. Usage: $sf-solutions:next <solution-name>. Triggers: next steps, what to do next, post-install guidance, after install, next actions."
user-invocable: true
metadata:
  author: Snowflake
  version: 1.0.0
---

# Next Actions

Show post-install guidance for a Snowflake industry solution accelerator.

## Step 1: Validate Arguments

`$ARGUMENTS` must contain a solution name. If empty, show:

> Usage: `$sf-solutions:next <solution-name>`
>
> To see available solutions: `$sf-solutions:list`

**STOP** if no solution name provided.

## Step 2: Resolve Repository

Read and follow `../install/references/resolve-repo.md` to:
1. Load the registry from `../install/registry.json`
2. Find the solution entry
3. Locate or clone the repository

## Step 3: Show Next Actions

Read the next actions guide:

```
$REPO_ROOT/solutions/$SOLUTION_NAME/NEXT_ACTIONS.md
```

- If the file exists, present its contents to the user and answer any follow-up questions based on it
- If the file does not exist, suggest the user check the solution's README or manifest for guidance
