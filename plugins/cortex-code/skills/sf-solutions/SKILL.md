---
name: sf-solutions
description: "Discover, install, and teardown Snowflake industry solution accelerators. Usage: $sf-solutions (list all), $sf-solutions retail (filter by industry), $sf-solutions:predictive-maintenance (install), $sf-solutions:predictive-maintenance teardown, $sf-solutions:predictive-maintenance next (post-install guidance). Triggers: solutions, industry, MLEU, manufacturing, predictive maintenance, supply chain, energy, utilities, logistics, IoT, OEE, GNN, retail, demand forecasting, LTV, customer lifetime value, healthcare, clinical, patient safety, next steps, what to do next."
user-invocable: true
metadata:
  author: Snowflake
  version: 1.0.1
---

# Snowflake Industry Solutions

Install pre-built Snowflake solution accelerators from multiple industry repositories. Solutions are registered in `registry.json` alongside this skill.

## Parse Arguments

Parse the action from `$ARGUMENTS`:
- If `$ARGUMENTS` is empty → run **List** flow (all industries)
- If `$ARGUMENTS` matches an industry name in registry.json → run **List** flow (filtered)
- If `$ARGUMENTS` contains a solution name (e.g., `predictive-maintenance`) → run **Install** flow
- If `$ARGUMENTS` contains a solution name followed by `teardown` → run **Teardown** flow
- If `$ARGUMENTS` contains a solution name followed by `next` → run **Next Actions** flow
- Otherwise → show usage help

## Step 1: Load the Registry

Read `registry.json` from the same directory as this skill file. The registry has this structure:

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

## Step 2: List Available Solutions

If no solution name was provided (or an industry name was provided as a filter):

1. Read registry.json
2. If an industry filter is specified, include only matching entries
3. Present a table dynamically generated from registry.json in this format:

```
Available Solutions:
┌───┬──────────────────────┬───────────────┬─────────────────────────────┐
│ # │ Solution             │ Industry      │ Description                 │
├───┼──────────────────────┼───────────────┼─────────────────────────────┤
│   │ (from registry.json) │               │                             │
└───┴──────────────────────┴───────────────┴─────────────────────────────┘

Commands:
• Install:               $sf-solutions:<solution-name>
• Remove:                $sf-solutions:<solution-name> teardown
• Post-install guidance: $sf-solutions:<solution-name> next
• Filter by industry:    $sf-solutions <industry-name>
```

**STOP** after listing. Do not install anything unless explicitly requested.

## Step 3: Resolve Repository for a Solution

When a solution name is provided (e.g., `$sf-solutions:predictive-maintenance`):

1. Search registry.json for the solution name across all industries
2. Identify the matching industry entry and its `repo` URL
3. If not found, show available solutions and stop

Store the resolved values:
- `$REPO_URL` — the GitHub repository URL
- `$INDUSTRY` — the industry identifier
- `$SOLUTION_NAME` — the solution name

## Step 4: Locate or Clone the Repository

Search for the repository locally using the Bash tool. The following logic is cross-platform:

```python
import os, subprocess
from pathlib import Path

repo_dir_name = REPO_URL.rstrip("/").split("/")[-1].removesuffix(".git")

# Use a private per-user cache directory (not world-writable /tmp)
cache_dir = Path.home() / ".cache" / "sf-solutions"
cache_dir.mkdir(parents=True, exist_ok=True)
os.chmod(str(cache_dir), 0o700)

search_paths = [
    Path.cwd() / repo_dir_name,
    Path.cwd().parent / repo_dir_name,
    Path.home() / repo_dir_name,
    cache_dir / repo_dir_name,
]

repo_root = None
for d in search_paths:
    if (d / "solutions").is_dir():
        # Verify git remote matches expected REPO_URL before trusting
        result = subprocess.run(
            ["git", "-C", str(d), "remote", "get-url", "origin"],
            capture_output=True, text=True
        )
        if result.returncode == 0 and REPO_URL in result.stdout.strip():
            repo_root = d
            break

if repo_root is None:
    clone_target = cache_dir / repo_dir_name
    result = subprocess.run(["git", "clone", REPO_URL, str(clone_target)], capture_output=True, text=True)
    if result.returncode == 0:
        repo_root = clone_target
```

If the clone fails (private repo, no git, no network), show a clear error:

> Could not locate or clone the repository. Either:
> 1. Clone it manually: `git clone <repo-url>`
> 2. Or navigate to the directory containing it before invoking this skill.

**STOP** — do not proceed without the repository.

Once `$REPO_ROOT` is resolved, log the path inline (e.g., "Using repo at: /path/to/repo") and proceed.

## Step 5: Install a Solution

Read and follow `references/install.md` from this skill's directory. It contains the full install workflow (validate → manifest → account info → plan → confirm → execute → verify).

## Step 6: Teardown a Solution

Read and follow `references/teardown.md` from this skill's directory. It contains the full teardown workflow (manifest → show removal plan → confirm → execute → verify).

## Step 7: Next Actions

When `next` is specified (e.g., `$sf-solutions:ltv-prediction next`):

1. Resolve the repository using Steps 3 and 4 (registry lookup + locate/clone)
2. Read the next actions guide with the Read tool:

```
$REPO_ROOT/solutions/$SOLUTION_NAME/NEXT_ACTIONS.md
```

3. If the file exists, present its contents to the user and answer any follow-up questions based on it
4. If the file does not exist, suggest the user check the solution's README or manifest for guidance

## Performance Rules

- **Do NOT read SQL files line by line into context.** Use the subagent strategy below.
- **Do NOT ask for repo confirmation** — just log the path and proceed.
- **Do NOT read setup.sql/data.sql into the main conversation.** Only read manifest.json and NEXT_ACTIONS.md directly.
- **Use a Task subagent for SQL execution** — see `references/install.md` for the full SQL execution strategy.

## Notes

- This skill requires `git` on the user's machine for the clone fallback
- Solutions are self-contained — each has its own SQL scripts and sample data
- The registry.json file is the source of truth for which solutions exist and where they live
- Each industry repository follows the same convention: `solutions/<name>/manifest.json`
- Each solution may include a `NEXT_ACTIONS.md` with post-install guidance
- To add a new solution: update registry.json with the solution entry under the appropriate industry
