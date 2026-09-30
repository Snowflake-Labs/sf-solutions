# Resolve Repository

Shared logic for resolving a solution's repository. Used by install, teardown, and next skills.

## Step 1: Load the Registry

Read `registry.json` from the `install` skill directory (sibling to this skill). The registry has this structure:

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

## Step 2: Find the Solution

Search registry.json for `$SOLUTION_NAME` across all industries. If not found, show available solutions and stop.

Store:
- `$REPO_URL` — the GitHub repository URL
- `$INDUSTRY` — the industry identifier
- `$SOLUTION_NAME` — the solution name

## Step 3: Locate or Clone the Repository

Search for the repository locally using the Bash tool:

```python
import os, subprocess
from pathlib import Path

repo_dir_name = REPO_URL.rstrip("/").split("/")[-1].removesuffix(".git")

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

If clone fails, show:

> Could not locate or clone the repository. Either:
> 1. Clone it manually: `git clone <repo-url>`
> 2. Or navigate to the directory containing it before invoking this skill.

**STOP** — do not proceed without the repository.

Log the path inline (e.g., "Using repo at: /path/to/repo") and proceed.
