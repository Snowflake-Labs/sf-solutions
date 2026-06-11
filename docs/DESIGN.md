# sf-solutions: Design Rationale

This document explains the architectural decisions behind the sf-solutions plugin catalog.
It is intended for contributors who want to understand *why* the repo is structured the way it is,
not just *how* to use it.

---

## 1. Why zero runtime code lives in this repo

sf-solutions is a **thin plugin catalog** — it contains skill orchestration files, not solution code.
Every piece of solution runtime (SQL, notebooks, Streamlit apps, prompts) lives in a dedicated repo:
`Snowflake-Labs/sf-solutions-<slug>`.

**Reasons:**

- **Independent iteration** — a solution team can push a fix to their repo without touching the catalog.
  Users who reinstall get the latest version automatically; no plugin update required.
- **Installable size** — `cortex plugin install` clones this repo. Keeping it lean means fast installs.
- **Clean review surface** — PRs to the catalog are about skill orchestration (frontmatter, routing tables,
  evals), not about domain-specific SQL logic. Reviewers can focus on skill quality.
- **Separation of concerns** — the catalog enforces conventions; solution repos own their data model.

---

## 2. Why sparse checkout at skill invocation time

Each solution SKILL.md bootstraps by running:

```bash
git clone --filter=blob:none --no-checkout \
  https://github.com/Snowflake-Labs/sf-solutions-<slug>.git \
  /tmp/sf-solutions-<slug>
cd /tmp/sf-solutions-<slug>
git checkout main -- scripts/ manifest.json
```

**Reasons:**

- **Always fresh** — users get the latest `setup.sql` without reinstalling the plugin.
- **Minimal transfer** — `--filter=blob:none` avoids downloading blobs until checkout; only the
  paths named in `git checkout` are fetched.
- **No bundling** — SQL scripts don't belong in a markdown-only catalog repo.

An alternative (bundling solution code in `skills/<slug>/scripts/`) was rejected because it couples
the catalog release cycle to every solution's SQL changes.

---

## 3. Why frontmatter scanning for catalog auto-discovery

The `list` skill discovers solutions by scanning `skills/*/SKILL.md` for files with
`skill_type: solution` in their frontmatter. There is no separate `catalog.yaml` to maintain.

**Reasons:**

- **Single source of truth** — the SKILL.md frontmatter is already the authoritative metadata
  (name, industry, features, tags, status). Duplicating it in a catalog file creates sync drift.
- **Zero maintenance** — adding a skill via `$snowflake-solutions:add-solution` automatically makes
  it discoverable. No catalog file to patch.
- **PR simplicity** — a new solution PR touches only `skills/<slug>/` and `plugin.json`.
  No catalog file conflict to resolve.

---

## 4. Why the dual-symlink pattern

Two separate symlink mechanisms exist for two different CoCo discovery paths:

| Path | Purpose | Created by |
|------|---------|------------|
| `.cortex-plugin/skills` | Directory symlink → `../skills` | Repo setup (once) |
| `.cortex/skills/<name>` | Per-skill symlink → `../../skills/<name>` | `add-solution` skill + manual step |

**`.cortex-plugin/skills`** is read when the plugin is installed remotely via
`cortex plugin install`. CoCo resolves skill paths relative to this directory.

**`.cortex/skills/<name>`** is read during **local development** — when CoCo starts in the
repo directory, it auto-loads any skill found under `.cortex/skills/`. This lets contributors
test a skill in a CoCo session without installing the plugin.

The reason they coexist rather than using one mechanism: remote plugin install and local
development have different resolution roots.

---

## 5. Why separate `.cortex-plugin/` and `.claude-plugin/` manifests

Two plugin ecosystems with incompatible manifest schemas:

| Field | CoCo `.cortex-plugin/plugin.json` | Claude Code `.claude-plugin/plugin.json` |
|-------|-----------------------------------|------------------------------------------|
| Skills | `skills[]` array with `name` + `path` | Commands in `.claude/commands/` |
| Author | `author.name` string | `author` object `{ "name": "..." }` |
| Dependencies | not supported | `dependencies[]` array |

Maintaining separate manifests lets each ecosystem evolve independently without requiring a
compatibility shim. The skills themselves (`skills/*/SKILL.md`) are shared — only the
manifest envelope differs.

---

## 6. How CoCo plugin manifest and sparse checkout interact

> **Question (from contributors):** When the catalog has multiple skills where some solutions use
> sparse checkout and some don't, how does the CoCo plugin manifest handle this? Can the `repo`
> URL be moved into respective skill blocks?

**Answer:**

The CoCo plugin manifest (`plugin.json`) controls **plugin installation only** — it registers
which SKILL.md files exist. It knows nothing about what a skill does at invocation time.

The `sparseCheckout` field in `plugin.json` (if present) scopes which paths are fetched from
*this catalog repo* when the plugin is installed. It is unrelated to per-solution repo checkout.

Per-solution sparse checkout is orchestrated entirely inside each SKILL.md's instructions via
`git clone --filter=blob:none`. Each skill decides independently whether to clone an external
repo, use inline SQL, or do something else entirely.

The `repo:` URL in SKILL.md frontmatter is the correct location for a solution's source repo URL.
It is read by the `list` skill for display purposes — the plugin loader ignores it. Moving it
into the plugin manifest would couple catalog installation to solution repo structure for no benefit.

**Conclusion:** no manifest changes are needed to support a mix of bootstrap and self-contained skills.
Each skill handles its own runtime fetch pattern inside its SKILL.md.

---

## 7. Why pre-commit hooks enforce the PR checklist

The original `CONTRIBUTING.md` included a manual PR checklist. That checklist is now mechanically
enforced by pre-commit hooks:

| Manual checklist item | Hook that replaces it |
|-----------------------|-----------------------|
| Valid JSON (plugin.json, evals.json) | `check-json` |
| Markdown style (SKILL.md, README) | `markdownlint` |
| No code files in `skills/` | `no-code-in-skills` |
| Commit message format | `conventional-pre-commit` |

This removes the cognitive overhead of remembering to check a list and makes violations
visible at commit time rather than PR review time.
