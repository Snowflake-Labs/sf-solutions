# Template Guide

This directory contains template files for creating new industry-vertical solution repositories (e.g., `sf-fsi-solutions`, `sf-rcg-solutions`).

## Template Variables

Replace these placeholders when creating a new repository:

| Variable | Description | Example (HCLS) | Example (MLEU) |
|----------|-------------|-----------------|-----------------|
| `{{REPO_NAME}}` | Repository name | `sf-hcls-solutions` | `sf-mleu-solutions` |
| `{{INDUSTRY_NAME}}` | Full industry name | `Healthcare & Life Sciences` | `Manufacturing, Logistics, Energy and Utilities` |
| `{{INDUSTRY_CODE}}` | Short code | `HCLS` | `MLEU` |
| `{{FILTER_KEYWORD}}` | CLI filter keyword | `hcls` | `mleu` |

## File Inventory

### Copy as-is (no variable substitution needed)

| File | Purpose |
|------|---------|
| `LICENSE` | Apache 2.0 license |
| `.markdownlint.yaml` | Markdown linter config |
| `.markdownlintignore` | Markdown lint ignore patterns |
| `.pre-commit-config.yaml` | Pre-commit hooks (json, markdown, ruff, sqruff, conventional commits) |
| `.github/workflows/lint.yml` | CI: markdownlint + ruff |
| `.github/workflows/sql-lint.yml` | CI: sqruff SQL linter |
| `.github/workflows/solution-structure.yml` | CI: verify solution required files |

### Template files (substitute variables)

| File | Purpose |
|------|---------|
| `README.md.template` | Main repo README with solution catalog |
| `AGENTS.md.template` | AI assistant instructions (CoCo/Claude Code) |
| `CONTRIBUTING.md.template` | Contributor guide |
| `pyproject.toml.template` | Python project config (ruff, sqruff) |

### Create manually (repo-specific)

| File | Purpose |
|------|---------|
| `local.README.md` | Internal-only planned solutions list |
| `solutions/` | Solution directories (empty initially) |
| `work/` | Working directory for development |

## New Repository Setup

```bash
# 1. Create the repository
gh repo create Snowflake-Labs/sf-<industry>-solutions --private

# 2. Clone and enter
git clone git@github.com:Snowflake-Labs/sf-<industry>-solutions.git
cd sf-<industry>-solutions

# 3. Copy as-is files
cp /path/to/sf-solutions/templates/LICENSE .
cp /path/to/sf-solutions/templates/.markdownlint.yaml .
cp /path/to/sf-solutions/templates/.markdownlintignore .
cp /path/to/sf-solutions/templates/.pre-commit-config.yaml .
cp -r /path/to/sf-solutions/templates/.github .

# 4. Generate files from templates (replace variables)
export REPO_NAME="sf-<industry>-solutions"
export INDUSTRY_NAME="<Full Industry Name>"
export INDUSTRY_CODE="<CODE>"
export FILTER_KEYWORD="<keyword>"

for tmpl in /path/to/sf-solutions/templates/*.template; do
    outfile=$(basename "$tmpl" .template)
    sed -e "s/{{REPO_NAME}}/$REPO_NAME/g" \
        -e "s/{{INDUSTRY_NAME}}/$INDUSTRY_NAME/g" \
        -e "s/{{INDUSTRY_CODE}}/$INDUSTRY_CODE/g" \
        -e "s/{{FILTER_KEYWORD}}/$FILTER_KEYWORD/g" \
        "$tmpl" > "$outfile"
done

# 5. Create directories
mkdir -p solutions work

# 6. Create local.README.md (manually — list planned solutions)

# 7. Install pre-commit hooks
pre-commit install
pre-commit install --hook-type commit-msg

# 8. Initialize uv for dev dependencies
uv sync

# 9. Initial commit
git add -A
git commit -m "feat: initialize repository from sf-solutions template"
git push -u origin main
```

## Branch Protection (GitHub Rulesets)

Each repository uses two rulesets on `main`. Apply them after the initial push:

### main-branch-protection: Branch safety

```bash
gh api repos/Snowflake-Labs/$REPO_NAME/rulesets \
  --method POST \
  --input - <<'EOF'
{
  "name": "main-branch-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": { "include": ["refs/heads/main"], "exclude": [] }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" }
  ],
  "bypass_actors": []
}
EOF
```

### pr-and-ci: PR requirements + CI checks

```bash
gh api repos/Snowflake-Labs/$REPO_NAME/rulesets \
  --method POST \
  --input - <<'EOF'
{
  "name": "pr-and-ci",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": { "include": ["refs/heads/main"], "exclude": [] }
  },
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "required_reviewers": [],
        "require_code_owner_review": true,
        "dismissal_restriction": { "enabled": false, "allowed_actors": [] },
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["merge", "squash", "rebase"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "do_not_enforce_on_create": false,
        "required_status_checks": [
          { "context": "markdownlint" },
          { "context": "ruff" },
          { "context": "sqruff-lint" },
          { "context": "check-solution-structure" }
        ]
      }
    }
  ],
  "bypass_actors": [
    { "actor_id": 4620750, "actor_type": "User", "bypass_mode": "always" }
  ]
}
EOF
```

> **Note:** `actor_id: 4620750` is the repo admin bypass. Update if a different user should bypass.

---

## Customization After Setup

After generating from templates, you may want to:

1. **AGENTS.md** — Add an "Existing Solutions" table entry after each solution is added
2. **README.md** — Populate the Solution Catalog table
3. **local.README.md** — Add your planned solution backlog
4. **pyproject.toml** — Add `extend-exclude` patterns if solutions contain non-lintable Python (e.g., app directories)
