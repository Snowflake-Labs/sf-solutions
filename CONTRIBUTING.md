# Contributing to sf-solutions

This repo is a **plugin catalog** — it contains the skill orchestration files that install Snowflake industry solutions, but no solution runtime code. Solution code lives in dedicated repos (one per solution).

---

## How It Works

When a user runs a solution skill (e.g., `$snowflake-solutions:ltv-prediction`), the skill:
1. Clones the solution's dedicated GitHub repo via sparse checkout
2. Reads `manifest.json` and presents an installation plan
3. Executes the solution's SQL scripts against the user's Snowflake account

The catalog repo stays lean — no SQL, no data, no notebooks live here.

**How catalog discovery works:** The `list` skill auto-discovers solutions by scanning `skills/*/SKILL.md` for files with `skill_type: solution` in their frontmatter. There is no separate catalog file to maintain — adding a skill makes it automatically appear in `$snowflake-solutions:list`.

---

## Repo Structure

```
sf-solutions/
├── .cortex-plugin/
│   ├── plugin.json               ← CoCo plugin manifest (skills[] array)
│   └── skills                    ← SYMLINK → ../skills
├── .cortex/
│   └── skills/
│       └── <name>                ← SYMLINK → ../../skills/<name> (per skill)
├── .claude-plugin/
│   ├── plugin.json               ← Claude marketplace manifest
│   └── marketplace.json
├── .claude/
│   └── commands/
│       ├── list.md               ← thin Claude adapters
│       ├── add-solution.md
│       └── <slug>.md             ← one per solution skill
├── skills/                       ← CANONICAL skill content (real files)
│   ├── list/
│   │   ├── SKILL.md              ← auto-discovers solutions via frontmatter scan
│   │   └── evals/evals.json
│   ├── add-solution/
│   │   ├── SKILL.md
│   │   ├── templates/
│   │   │   ├── skill-md.md       ← SKILL.md template for new solutions
│   │   │   └── next-actions.md   ← NEXT_ACTIONS.md template
│   │   └── evals/evals.json
│   └── <slug>/                   ← one dir per solution (added by add-solution)
│       ├── SKILL.md              ← frontmatter: skill_type, industry, features, tags
│       ├── NEXT_ACTIONS.md
│       └── evals/evals.json
├── hooks/
│   ├── hooks.json
│   └── allow-solution-commands.sh
├── CONTRIBUTING.md
└── README.md
```

**The symlink pattern:** `skills/` holds the real files. `.cortex-plugin/skills` (directory symlink) and `.cortex/skills/<name>` (per-skill symlinks) are how CoCo discovers them. `.claude/commands/<name>.md` are thin adapters for Claude Code.

---

## Adding a New Solution: Recommended Path

The fastest way is to use the built-in scaffolding skill in a CoCo session:

```
$snowflake-solutions:add-solution
```

The skill will ask for your solution details, generate all required files, patch `plugin.json`, and tell you the one manual shell command to run at the end.

If you prefer to add a solution manually, follow the steps below.

---

## Adding a New Solution: Manual Steps

### 1. Create the solution repo

Create a new public repo under `Snowflake-Labs` named `sf-solutions-<slug>`
(e.g., `sf-solutions-fraud-detection`).

**Required repo layout:**

```
sf-solutions-<slug>/
├── README.md                   # Overview, architecture, prerequisites
├── manifest.json               # Solution metadata (see schema below)
├── scripts/
│   ├── setup.sql               # Full installation SQL
│   └── teardown.sql            # DROP statements for clean removal
├── streamlit/                  # (optional)
│   ├── streamlit_app.py
│   └── environment.yml
├── notebooks/                  # (optional)
│   └── *.ipynb
└── prompts/                    # (optional)
    ├── demo_prompts.md
    └── demo_prompts_JA.md
```

**`manifest.json` schema:**

```json
{
  "slug": "fraud-detection",
  "name": "Real-Time Fraud Detection",
  "version": "1.0.0",
  "industry": "Financial Services",
  "description": "One sentence description.",
  "database": "SF_SOLUTIONS",
  "schemas": ["FRAUD_RAW", "FRAUD_ANALYTICS"],
  "role_required": "ACCOUNTADMIN",
  "warehouse": "COMPUTE_WH",
  "features": ["Snowflake ML", "Cortex AI Functions", "Streamlit"],
  "repo": "https://github.com/Snowflake-Labs/sf-solutions-fraud-detection"
}
```

### 2. Add the canonical skill

Create `skills/<slug>/SKILL.md` using `skills/add-solution/templates/skill-md.md` as the template.

**Required frontmatter fields:**

Solution skills carry extra metadata fields beyond the CoCo `name`/`description` minimum. CoCo ignores unknown frontmatter fields at runtime; the `list` skill reads them for catalog auto-discovery.

```yaml
---
name: <slug>
skill_type: solution          # required — marks this as discoverable by list skill
industry: <industry>
snowflake_features:
  - Snowflake ML Regression
  - Cortex AI Functions
tags: [ml, cortex, retail]   # searchable labels
repo: https://github.com/Snowflake-Labs/sf-solutions-<slug>
status: available            # available | coming-soon | deprecated
version: "1.0.0"
description: >               # pushy — enumerate exact trigger phrases
  Installs or tears down the <Solution Name> solution in Snowflake.
  Use when: "install <slug>", "set up <slug>", ...
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Bash
  - Read
  - Glob
  - Grep
  - WebFetch
---
```

**Required body sections:**
- `## Routing` table as the first body section
- `## Error Recovery` table
- `## Completion Criteria` with machine-verifiable conditions
- Post-install NEXT_ACTIONS presented automatically (as a hard step, not "if user asks")
- Declare `[[solutions-scaffold]] Tier 1` compliance

Also create:
- `skills/<slug>/NEXT_ACTIONS.md` — 4-phase guide (Explore / Customize / Tune / Production)
  Use `skills/add-solution/templates/next-actions.md` as the template
- `skills/<slug>/evals/evals.json` — at least one test case per invocation variant

### 3. Add the Claude Code adapter

Create `.claude/commands/<slug>.md`:

```markdown
---
description: "Install or teardown the <Solution Name> solution"
---

Load and follow `skills/<slug>/SKILL.md`.

To install: say "install <slug>"
To teardown: say "<slug> teardown"
To see what's next: say "<slug> next actions"
```

### 4. Create the CoCo auto-discovery symlink

From the repo root, run:

```bash
ln -s ../../skills/<slug> .cortex/skills/<slug>
```

This registers the skill for CoCo local auto-discovery. **This step cannot be done by the `add-solution` skill itself — you must run it manually.**

### 5. Update .cortex-plugin/plugin.json

Add a new entry to the `skills[]` array:

```json
{ "name": "<slug>", "path": "skills/<slug>/SKILL.md" }
```

### 6. Verify list skill auto-discovers the new solution

The `list` skill scans `skills/*/SKILL.md` for `skill_type: solution`. No manual catalog patching is needed — the new skill is automatically discoverable once its frontmatter is correct.

Verify by running `$snowflake-solutions:list` — the new solution should appear in the table.

### 7. Update root README.md

If the solution's `status` is `available`, mention it in the README.

### 8. Update hooks allowlist (if needed)

If your skill runs commands not already in the allowlist, add the prefix to
`hooks/allow-solution-commands.sh`.

---

## Bootstrap Pattern Reference

Every solution SKILL.md uses this sparse-checkout pattern to fetch the solution repo at invocation time:

```bash
git clone --filter=blob:none --no-checkout \
  https://github.com/Snowflake-Labs/sf-solutions-<slug>.git \
  /tmp/sf-solutions-<slug>
cd /tmp/sf-solutions-<slug>
git checkout main -- scripts/ manifest.json
```

Add paths as needed (`streamlit/`, `prompts/`, `notebooks/`).

---

## CoCo Skill Best Practices Summary

All skills in this catalog must comply with the CoCo skill-architect conventions:

| Practice | Requirement |
|---|---|
| Frontmatter | `name:` and `description:` are non-negotiable |
| `skill_type: solution` | Required in solution skill frontmatter for auto-discovery by list skill |
| Description | Must be "pushy" — enumerate exact trigger phrases, not just a summary |
| `tools:` array | Declare only the tools the skill actually uses |
| Routing table | Include as the first body section |
| User gates | Use `HARD GATE` / `STOP` markers before any SQL or file writes |
| Error recovery | Include an `## Error Recovery` table for each distinct failure mode |
| Completion criteria | Include `## Completion Criteria` with machine-verifiable conditions |
| NEXT_ACTIONS | Present automatically as a hard install step — not behind "if user asks" |
| Evals | At least one test case per invocation variant in `evals/evals.json` |
| Line cap | ~250 lines per SKILL.md (not a hard limit, but a quality signal) |

Anti-patterns to avoid:
- Vague description → skill won't trigger reliably
- Soft gates ("check if things look OK") → agents skip them under context pressure
- "If the user asks" for important post-install steps → use explicit routing
- Missing `skill_type: solution` → skill invisible to `$snowflake-solutions:list`

---

## Claude Marketplace Publishing

The Claude marketplace uses `.claude-plugin/` at the repo root.

**`.claude-plugin/plugin.json` required fields:**
```json
{
  "name": "snowflake-solutions",
  "version": "1.0.0",
  "description": "...",
  "author": { "name": "Snowflake Labs" },
  "homepage": "https://github.com/Snowflake-Labs/sf-solutions",
  "repository": "https://github.com/Snowflake-Labs/sf-solutions",
  "dependencies": ["snowflake-cortex-code"]
}
```

**`.claude-plugin/marketplace.json` required fields:**
```json
{
  "name": "snowflake-solutions",
  "description": "...",
  "owner": { "name": "Snowflake Labs" },
  "plugins": [{ "name": "snowflake-solutions", "source": "." }]
}
```

No changes to these files are needed when adding a new solution.

---

## PR Review Checklist

Before merging a new solution PR, verify:

- [ ] Solution repo (`sf-solutions-<slug>`) exists and is public
- [ ] `manifest.json` in solution repo is valid JSON with all required fields
- [ ] `scripts/setup.sql` and `scripts/teardown.sql` exist in solution repo
- [ ] `skills/<slug>/SKILL.md` has `skill_type: solution` in frontmatter
- [ ] `skills/<slug>/SKILL.md` has `industry`, `snowflake_features`, `tags`, `repo`, `status` in frontmatter
- [ ] `skills/<slug>/SKILL.md` has `name:` frontmatter, pushy `description:`, `tools:` array
- [ ] `skills/<slug>/SKILL.md` uses sparse-checkout bootstrap pattern
- [ ] `$snowflake-solutions:list` shows the new solution (auto-discovery check)
- [ ] `skills/<slug>/NEXT_ACTIONS.md` exists and covers all four phases
- [ ] `skills/<slug>/evals/evals.json` has at least one test case
- [ ] `.claude/commands/<slug>.md` thin adapter created
- [ ] `.cortex/skills/<slug>` symlink created (manual step)
- [ ] `.cortex-plugin/plugin.json` skills[] array updated
- [ ] Root `README.md` updated if status is `available`
- [ ] `hooks/allow-solution-commands.sh` updated if new command types introduced
