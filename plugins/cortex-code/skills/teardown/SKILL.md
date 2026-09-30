---
name: teardown
description: "Remove a previously installed Snowflake industry solution. Usage: $sf-solutions:teardown <solution-name>. Triggers: teardown, remove solution, uninstall solution, delete solution, drop solution."
user-invocable: true
metadata:
  author: Snowflake
  version: 1.0.0
---

# Teardown Solution

Remove a previously installed Snowflake industry solution accelerator.

## Step 1: Validate Arguments

`$ARGUMENTS` must contain a solution name. If empty, show:

> Usage: `$sf-solutions:teardown <solution-name>`
>
> To see available solutions: `$sf-solutions:list`

**STOP** if no solution name provided.

## Step 2: Resolve Repository

Read and follow `../install/references/resolve-repo.md` to:
1. Load the registry from `../install/registry.json`
2. Find the solution entry
3. Locate or clone the repository

## Step 3: Execute Teardown

Read and follow `../install/references/teardown.md` from the install skill directory. It contains the full teardown workflow (manifest → show removal plan → confirm → execute → verify).
