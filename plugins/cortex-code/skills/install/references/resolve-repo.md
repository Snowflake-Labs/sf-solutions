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

The repository contains SQL and plugin files that will be executed or installed, so it MUST come from an approved source. Run the following with the Bash tool:

```python
import os, re, subprocess
from pathlib import Path

ALLOWED_OWNER = "Snowflake-Labs"

# 1. Allowlist: only https://github.com/Snowflake-Labs/<repo> is accepted from the registry
m = re.fullmatch(r"https://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+?)(?:\.git)?/?", REPO_URL)
if not m or m.group(1) != ALLOWED_OWNER:
    raise SystemExit(f"REJECTED: {REPO_URL} is not an approved {ALLOWED_OWNER} GitHub repository")
expected = f"{m.group(1)}/{m.group(2)}".lower()
repo_dir_name = m.group(2)

def resolve_host(host):
    # Resolve SSH host aliases (e.g. github-sfc) to the real hostname
    if host in ("github.com", "www.github.com"):
        return "github.com"
    r = subprocess.run(["ssh", "-G", host], capture_output=True, text=True)
    for line in r.stdout.splitlines():
        if line.startswith("hostname "):
            return line.split(None, 1)[1].strip().lower()
    return host

def normalize_remote(url):
    # Accepts https://host/owner/repo(.git), git@host:owner/repo(.git), ssh://git@host/owner/repo(.git), alias:owner/repo(.git)
    url = url.strip()
    m = re.fullmatch(r"(?:https?|ssh)://(?:[^@/]+@)?([^/:]+)(?::\d+)?/([^/]+)/([^/]+?)(?:\.git)?/?", url) \
        or re.fullmatch(r"(?:[^@/]+@)?([^/:]+):([^/]+)/([^/]+?)(?:\.git)?/?", url)
    if not m:
        return None
    return resolve_host(m.group(1).lower()), f"{m.group(2)}/{m.group(3)}".lower()

def is_expected_remote(d):
    r = subprocess.run(["git", "-C", str(d), "remote", "get-url", "origin"], capture_output=True, text=True)
    if r.returncode != 0:
        return False
    parsed = normalize_remote(r.stdout)
    # 2. Exact match on host and owner/repo (no substring matching)
    return parsed == ("github.com", expected)

cache_dir = Path.home() / ".cache" / "sf-solutions"
cache_dir.mkdir(parents=True, exist_ok=True)
os.chmod(str(cache_dir), 0o700)
cache_repo = cache_dir / repo_dir_name

search_paths = [
    Path.cwd() / repo_dir_name,
    Path.cwd().parent / repo_dir_name,
    Path.home() / repo_dir_name,
    cache_repo,
]

repo_root = None
for d in search_paths:
    if (d / "solutions").is_dir() and is_expected_remote(d):
        repo_root = d
        break

if repo_root is None:
    if cache_repo.exists():
        raise SystemExit(f"REJECTED: {cache_repo} exists but its origin is not {expected}. Remove it and retry.")
    r = subprocess.run(["git", "clone", "--depth", "1", REPO_URL, str(cache_repo)], capture_output=True, text=True)
    if r.returncode == 0:
        repo_root = cache_repo
elif repo_root == cache_repo:
    # 3. Refresh the managed cache so a stale copy is not executed
    subprocess.run(["git", "-C", str(cache_repo), "pull", "--ff-only"], capture_output=True, text=True)

if repo_root is not None:
    # 4. Record exactly what will be executed
    git = lambda *a: subprocess.run(["git", "-C", str(repo_root), *a], capture_output=True, text=True).stdout.strip()
    REPO_COMMIT = git("rev-parse", "HEAD")
    REPO_BRANCH = git("rev-parse", "--abbrev-ref", "HEAD")
    REPO_DIRTY = bool(git("status", "--porcelain", "--", f"solutions/{SOLUTION_NAME}"))
    print(f"REPO_ROOT={repo_root}\nREPO_COMMIT={REPO_COMMIT}\nREPO_BRANCH={REPO_BRANCH}\nREPO_DIRTY={REPO_DIRTY}")
```

If the script prints `REJECTED`, show the message to the user and **STOP**. Do NOT fall back to any other URL or path.

If clone fails, show:

> Could not locate or clone the repository. Either:
> 1. Clone it manually: `git clone <repo-url>`
> 2. Or navigate to the directory containing it before invoking this skill.

**STOP** — do not proceed without the repository.

Store `$REPO_ROOT`, `$REPO_COMMIT`, `$REPO_BRANCH`, and `$REPO_DIRTY`. These MUST be shown in the confirmation plan of the calling workflow (install, install-plugin, teardown) so the user approves the exact source being executed.

If `$REPO_DIRTY` is true, the solution directory has uncommitted local changes. Show this warning in the confirmation plan:

> **WARNING:** `solutions/<SOLUTION_NAME>/` has uncommitted local changes. The files that will run differ from the published commit.

Log the path inline (e.g., "Using repo at: /path/to/repo @ <short commit>") and proceed.
