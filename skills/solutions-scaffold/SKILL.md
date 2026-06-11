---
name: solutions-scaffold
description: >
  Shared engineering conventions for all sf-solutions skills (demos, workshops,
  solution accelerators). Consult when: building a new sf-solutions skill,
  reviewing conventions for an existing skill, asking "how should I structure a
  new skill", "what are the SKILL.md requirements", "skill conventions",
  "demo skill standards", "how do I add a step", "plan mode gate pattern",
  "three presentation points", "manifest.toml schema for demos",
  "snow sql flags", "gate pattern", "solutions-scaffold".
---

# Solutions Scaffold

Reference conventions shared by all sf-solutions skills.
Individual skills state which tiers they follow; they override only what is
scenario-specific. Everything else defers to this document.

---

## Tier 1 — Universal (all skills)

Every skill in sf-solutions must follow these conventions unconditionally.

### 1. SKILL.md structure

Required sections in order:

```text
---                          ← frontmatter: name + description only
name: <slug>
description: >               ← intent phrases go here, not in extra fields
  ...
---

# <Name> Skill              ← H1 title

## Global Rules             ← numbered list, Tier 1 first, then Tier 2 if used

## Routing                  ← table: command → step file

## Steps                    ← reference to steps/<slug>.md files
```

Frontmatter fields: `name` and `description` only.
Encode all intent trigger phrases inside `description`.
Do not add custom fields (`invocations`, `intent_triggers`, etc.).
Keep SKILL.md under 500 lines; move reference material to `references/` files.

### 2. Three mandatory presentation points

Every step MUST present these three sections verbatim, as formatted markdown.
Never skip, summarize, or paraphrase any of the three:

1. **"Why this matters"** — the teaching moment (concept + IDD connection)
2. **"What we'll do"** — preview of actions for this step
3. **"What we did"** — summary of completed work

These are natural pause points. Present each one, let the user read it, then continue.

### 3. Plan mode gate protocol

Call `enter_plan_mode` **immediately** after marking a step IN_PROGRESS,
before presenting any content.

Run inside plan mode:

- "Why this matters"
- "What we'll do"
- Dry-run output or SQL preview (if applicable)

Call `exit_plan_mode` with a plan summary after the dry-run (or after
"What we'll do" for steps without a dry-run).

`exit_plan_mode` is the **single confirmation gate** per step.
There are no intermediate `Proceed?` asks or `STOP` blocks within the step flow.

### 4. Step routing convention

Organize skill content as:

```text
skills/<slug>/
├── SKILL.md          ← orchestration entrypoint
├── NEXT_ACTIONS.md   ← optional: post-install exploration guide
├── steps/            ← one file per step: step-1.md, step-2.md, ...
├── references/       ← supporting reference docs (keep SKILL.md < 500 lines)
├── cleanup/          ← SKILL.md for teardown flow
└── evals/
    └── evals.json
```

Routing table format (required in every SKILL.md):

| Command | Route |
|---------|-------|
| `$<slug>` (no args) | → Introduction (plan mode overview) |
| `$<slug> step N` | → `steps/step-N.md` |
| `$<slug> cleanup` | → `cleanup/SKILL.md` |

### 5. Accuracy and confirmation rules

- **Never hallucinate** — if uncertain about any value, path, or state, use
  `ask_user_question` to confirm before proceeding.
- **Always use markdown** for all user-facing output (tables, code blocks, admonitions).
- **Stop on billable actions** — always warn and confirm before creating cloud
  infrastructure (PG instances, external volumes, compute pools, etc.).

---

## Tier 2 — Infra-heavy demos (manifest + Snowflake object provisioning)

Apply Tier 2 when the skill provisions real Snowflake infrastructure.
Streetlights and GlobalPay use both tiers; executor-role workshop uses Tier 1 only.

### 1. manifest.toml as single source of truth

All configuration flows from a single `manifest.toml` (or `.sfutils/manifest.toml`).
Read it via `load_manifest()` or `tomllib.load()`. Never read `.env` instead.

Manifest schema for demo steps:

```toml
[demo]
demo_resource_prefix = "lowercase_prefix"   # used as Snowflake object prefix

[demo.steps.step-N]
desc         = "Human-readable description"
status       = "COMPLETE"            # IN_PROGRESS | COMPLETE | BLOCKED
started_at   = "2026-05-07T14:00:00Z"
completed_at = "2026-05-07T14:02:30Z"
```

`demo_resource_prefix` is lowercase in manifest; convert to UPPERCASE when
passing as `-D "PREFIX=..."` to `snow sql`.

### 2. snow sql universal flags

Every `snow sql` invocation must use all three flags:

```bash
snow sql -f snowflake/NNN_file.sql \
  -D "PREFIX=UPPERCASE_PREFIX" \
  -c {connection} \
  --format json \
  --enable-templating STANDARD
```

Template syntax is `<% PREFIX %>` (STANDARD mode). Never `${PREFIX}`.

Always show `> **Source**: \`snowflake/NNN_file.sql\`` immediately before the
command so users can cross-reference the exact SQL being run.

Before running any `snow` subcommand beyond `snow sql`, run
`snow <subcommand> --help` first to confirm the subcommand and its flags exist.
Never assume a subcommand or flag exists.

### 3. Gate pattern (self-healing step lifecycle)

All steps use `scripts/gate.py` (check / start / complete) and
`scripts/sanity_gate.py` (unified reconciliation).

Gate behavior:

1. Check `[demo.steps.step-N].status` in manifest (O(1) dict lookup)
2. If `COMPLETE` and fresh (< 3600s since `completed_at`) → **PASS**
3. If `COMPLETE` but stale → re-verify against Snowflake → re-stamp or **BLOCK**
4. If MISSING or not `COMPLETE` → verify against Snowflake:
   - Provably done → stamp COMPLETE (backfill) and continue
   - Not done → **BLOCK** with actionable message

The agent MUST NOT:

- Skip gates by querying Snowflake directly and declaring "passed"
- Declare a step "passed" without the gate script writing to the manifest
- Treat sanity checks as read-only — gates WRITE `[demo.steps.*]` records

See `references/gate-pattern.md` in individual skills for full gate usage.

### 4. Snowflake object naming

All Snowflake objects (tables, views, agents, semantic views, Streamlit apps)
are created in `{PREFIX}_<SCHEMA>.PUBLIC`.

CLD (Catalog-Linked Database) tables have lowercase column names from PostgreSQL.
Always double-quote CLD column references: `"light_id"`, `"date"`, `"status"`.
CLD is read-only — SELECT only, no DDL or DML.

---

## Usage

Individual skills reference this scaffold with a one-liner in Global Rules:

```text
This skill follows [[solutions-scaffold]] Tier 1 conventions.
```

or

```text
This skill follows [[solutions-scaffold]] Tier 1 + Tier 2 conventions.
```

Scenario-specific overrides (forbidden CLI patterns, manifest section ownership,
routing tables, SQL templates) are documented locally in the individual skill.
