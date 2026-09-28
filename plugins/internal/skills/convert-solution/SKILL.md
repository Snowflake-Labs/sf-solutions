---
name: convert-solution
description: >
  Convert a source project into the sf-*-solutions format. Handles both script type (SQL/Python repos)
  and plugin type (CoCo plugin with skills/agents). Validates security, conformance, and compliance.
  Usage: $sfs:convert-solution <source-path>
  Triggers: convert solution, publish solution, add solution, export solution, import plugin.
tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Write
  - snowflake_sql_execute
---

# Convert Solution

Convert a source project into the standard `sf-*-solutions` format with all required files,
security checks, and compliance validation.

## Input

`$ARGUMENTS` takes one positional argument:

1. **source path** — path to the source directory (required)

Examples:

```
$sfs:convert-solution ~/project/my-solution
$sfs:convert-solution /path/to/my-plugin
```

If source path is not provided, ask the user.

## Security Rules (MANDATORY — enforced by hooks)

Before creating ANY file, these rules are enforced by the `check-no-credentials` hook:

1. **NO CREDENTIALS** — Never include RSA/SSH keys, API tokens, or passwords.
2. **NO INTERNAL URLS** — No Snowflake internal hostnames.
3. **NO ACCOUNT LOCATORS** — No account-specific URLs.
4. **PLACEHOLDER ONLY** — Use generic placeholders for any sensitive values.

---

## Phase 0: Determine Solution Type

Ask the user which type of solution this is using `ask_user_question`:

- **Script** — SQL-based solution with optional Python/Streamlit components. Source contains `.sql` files, Python scripts, or both.
- **Plugin** — CoCo plugin with skills, agents, references. Source contains `.cortex-plugin/plugin.json` or `plugin.json`.

Store as `$SOLUTION_TYPE` ("script" or "plugin").

## Phase 1: Select Target Industry Repo

Ask the user which industry repo to create the solution in using `ask_user_question`:

| # | Repo | Industry |
|---|------|----------|
| 1 | sf-hcls-solutions | Healthcare & Life Sciences |
| 2 | sf-fsi-solutions | Financial Services |
| 3 | sf-mleu-solutions | Manufacturing, Logistics, Energy & Utilities |
| 4 | sf-telco-solutions | Telecommunications |
| 5 | sf-media-entertainment-solutions | Media & Entertainment |
| 6 | sf-marketing-solutions | Advertising, AdTech & MarTech |
| 7 | sf-tnh-solutions | Travel & Hospitality |
| 8 | sf-pubsec-solutions | Public Sector & Government |
| 9 | sf-rcg-solutions | Retail, CPG & General |

Store `$TARGET_REPO_PATH`. If the user provides the repo path directly as a second argument, skip this menu.

## Phase 2: Source Analysis

### Common (both types)

1. Verify source path exists
2. Scan for source database names (anything that looks like a `CREATE DATABASE` or `USE DATABASE` that is NOT `SF_SOLUTIONS`)
3. Scan for source warehouse names (anything that looks like `USE WAREHOUSE` or `WAREHOUSE =` that is NOT `SF_SOLUTIONS_WH`)
4. Write `.convert-meta.json` with:
   - `solution_type`: "script" or "plugin"
   - `source_databases`: list of detected source DB names
   - `source_warehouses`: list of detected source WH names
   - `source_path`: absolute path

### Script type — additional analysis

Read and follow `references/script-type.md` Phase 2 section.

### Plugin type — additional analysis

Read and follow `references/plugin-type.md` Phase 2 section.

## Phase 3: Confirm Conversion Plan

Present the conversion plan to the user using `ask_user_question`:

```
Solution Type: <script|plugin>
Source:        <source_path>
Target:        <target_repo>/<solution-name>/

Database Renames:
  <source_db> → SF_SOLUTIONS

Warehouse Renames:
  <source_wh> → SF_SOLUTIONS_WH

Files to generate:
  - manifest.json (type: <script|plugin>)
  - README.md (with disclaimer)
  - NEXT_ACTIONS.md (script type only)
  - scripts/setup.sql
  - scripts/teardown.sql
  - [plugin type: plugins/cortex-code/ directory]

Proceed with conversion?
```

**Do NOT proceed without explicit "yes" from the user.**

## Phase 4: Generate Files

### Common (both types)

1. **manifest.json** — MUST include `"type": "<script|plugin>"`. For plugin type, also include `"plugin_path": "plugins/cortex-code"`. Database must be `SF_SOLUTIONS`.

2. **README.md** — MUST include the disclaimer at the top:
   ```
   Disclaimer: This application is not part of the Snowflake Service and is governed by the terms
   in LICENSE, unless expressly agreed to in writing. You use this application at your own risk,
   and Snowflake has no obligation to support your use of this application. [Learn more](../../LEGAL.md)
   ```

### Type-specific generation

- **Script type** → Read and follow `references/script-type.md` Phase 4 section.
- **Plugin type** → Read and follow `references/plugin-type.md` Phase 4 section.

## Phase 5: Security Validation

Run ALL of the following checks on the generated output. Report each as PASS or FAIL.

### Check 1: Credentials and Secrets

Run `check-no-credentials.sh` equivalent scan on all generated files:

```bash
# Already enforced by PreToolUse hooks, but do a final sweep
grep -rn "-----BEGIN" <target_dir>/
grep -rnE '[a-z]{2}[0-9]{5,6}\.(us|eu|ap)-' <target_dir>/
grep -rnE 'Bearer[[:space:]]+[A-Za-z0-9_./-]{20,}' <target_dir>/
```

### Check 2: Snow-Prefixed Data Names

Scan all `.sql` files and `manifest.json` for names starting with "Snow" (case-insensitive):

```bash
grep -rniE '\bSnow[A-Z][a-z]+\b' <target_dir>/scripts/ <target_dir>/manifest.json
```

Flag names like SnowStore, SnowLeague, SnowMart, SnowBank, etc. These require PMM approval.

### Check 3: Confidential or Customer Data

Scan for patterns suggesting real customer data:

```bash
# Email addresses (not example.com)
grep -rnE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' <target_dir>/scripts/ | grep -v example | grep -v placeholder

# Phone numbers
grep -rnE '\b[0-9]{3}[-.]?[0-9]{3}[-.]?[0-9]{4}\b' <target_dir>/scripts/

# SSN patterns
grep -rnE '\b[0-9]{3}-[0-9]{2}-[0-9]{4}\b' <target_dir>/scripts/

# IP addresses (not 0.0.0.0, 127.0.0.1, or 10.x)
grep -rnE '\b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b' <target_dir>/scripts/ | grep -vE '(0\.0\.0\.0|127\.0\.0\.1|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)'
```

### Check 4: Plugin-Installs-Plugin

Scan for any logic that would install other plugins (grandchild prohibition):

```bash
# References to plugin installer skills
grep -rniE '(github-plugin-installer|local-plugin-installer|plugin-creator)' <target_dir>/

# Writes to plugin directory
grep -rniE '~/.snowflake/cortex/plugins|registry\.json' <target_dir>/

# Plugin installation commands in hooks
grep -rniE '(install.*plugin|plugin.*install)' <target_dir>/hooks/ 2>/dev/null
```

If any matches found: **FAIL — grandchild plugin installation is prohibited.**

### Check 5: Disclaimer Present

Verify README.md contains the LEGAL.md disclaimer link:

```bash
grep -q "LEGAL.md" <target_dir>/README.md
```

If not found: **FAIL — disclaimer is mandatory.**

### Check 6: Conformance Check

Run the conformance script:

```bash
bash plugins/internal/skills/convert-solution/hooks/check-solution-conformance.sh <target_dir> <target_dir>/.convert-meta.json
```

## Phase 6: Report

Present a summary table:

```
Security Validation Report
─────────────────────────────────────────
Check 1 — Credentials/Secrets:       PASS/FAIL
Check 2 — Snow-Prefixed Names:       PASS/FAIL (list any matches)
Check 3 — Confidential Data:         PASS/FAIL (list any matches)
Check 4 — Plugin-Installs-Plugin:    PASS/FAIL
Check 5 — Disclaimer Present:        PASS/FAIL
Check 6 — Conformance:               PASS/FAIL
─────────────────────────────────────────
```

If all PASS: clean up `.convert-meta.json` and report success.

If any FAIL: list specific files and line numbers that need fixing. Do NOT clean up `.convert-meta.json` until issues are resolved.

## Post-Conversion

After all checks pass:

1. Delete `.convert-meta.json`
2. Show the user the generated file tree
3. Suggest next steps:
   - Review generated files
   - Run `pre-commit run --all-files` to lint
   - Create a branch, commit, and open a PR
   - Register the solution in `sf-solutions/registry.json`
