---
name: install
description: "Install a Snowflake industry solution accelerator. Usage: $sf-solutions:install <solution-name>. Triggers: install solution, set up solution, deploy solution, sf-solutions install, solution accelerator, demo environment."
user-invocable: true
metadata:
  author: Snowflake
  version: 2.0.0
---

# Install Solution

Install a Snowflake industry solution accelerator into the user's account.

## Step 1: Validate Arguments

`$ARGUMENTS` must contain a solution name. If empty, show:

> Usage: `$sf-solutions:install <solution-name>`
>
> To see available solutions: `$sf-solutions:list`

**STOP** if no solution name provided.

## Step 2: Resolve Repository

Read and follow `references/resolve-repo.md` to:
1. Load the registry from `registry.json`
2. Find the solution entry
3. Locate or clone the repository

## Step 3: Install

Read and follow `references/install.md`. It contains the full install workflow (validate → manifest → type detection → plan → confirm → execute → verify). Solutions with `"type": "plugin"` in their manifest are automatically routed to `references/install-plugin.md` for CoCo plugin installation.

## Performance Rules

- **Do NOT read SQL files line by line into context.** Use the subagent strategy in `references/install.md`.
- **Do NOT ask for repo confirmation** — just log the path and proceed.
- **Do NOT read setup.sql/data.sql into the main conversation.** Only read manifest.json directly.
- **Use a Task subagent for SQL execution** — see `references/install.md`.

## Notes

- This skill requires `git` on the user's machine for the clone fallback
- Solutions are self-contained — each has its own SQL scripts and sample data
- The registry.json file is the source of truth for which solutions exist and where they live
- Each industry repository follows the same convention: `solutions/<name>/manifest.json`
- To add a new solution: update registry.json with the solution entry under the appropriate industry
