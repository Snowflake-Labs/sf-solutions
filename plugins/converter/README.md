# sfs

Cortex Code plugin for Snowflake solution authors. Converts a source project into the public `sf-*-solutions` format with security and conformance validation.

> **Note:** This plugin is for solution authors. It is not intended for customers.

---

## Install

```bash
cortex plugin install git Snowflake-Labs/sf-solutions --sub-path plugins/converter
```

---

## Skills

### `convert-solution`

Converts a source project into the standard `sf-*-solutions` format. Supports both solution types:

- **Script** — SQL-based solution with optional Python/Streamlit components
- **Plugin** — CoCo plugin with skills, agents, and references

**What it does:**

1. Asks for the solution type (script or plugin) and validates the target industry repo (or asks for one)
2. Analyzes the source and asks for Author, Edition, and Trial Account compatibility
3. Shows the conversion plan and waits for confirmation
4. Adapts all SQL to use the `SF_SOLUTIONS` database and `SF_SOLUTIONS_WH` warehouse
5. Generates required files: `manifest.json`, `README.md` (with disclaimer and metadata), `scripts/setup.sql`, `scripts/teardown.sql`, and `NEXT_ACTIONS.md` (script type)
6. Runs six security checks: credentials, Snow-prefixed names, confidential data, plugin-installs-plugin, disclaimer, conformance

**Usage:**

```
$sfs:convert-solution <source-path> <target-repo-path>
```

- `<source-path>` — source project to convert
- `<target-repo-path>` — local clone of the target industry repo. The solution is written to `<target-repo-path>/solutions/<solution-name>/`. If omitted, the skill asks which repo to use.

**Example:**

```
$sfs:convert-solution ~/project/my-solution ~/project/sf-rcg-solutions
```

**Target repos:**

| # | Repository | Industry |
|---|-----------|---------|
| 1 | `sf-hcls-solutions` | Healthcare & Life Sciences |
| 2 | `sf-fsi-solutions` | Financial Services |
| 3 | `sf-mleu-solutions` | Manufacturing, Logistics, Energy & Utilities |
| 4 | `sf-telco-solutions` | Telecommunications |
| 5 | `sf-media-entertainment-solutions` | Media & Entertainment |
| 6 | `sf-marketing-solutions` | Advertising, AdTech & MarTech |
| 7 | `sf-tnh-solutions` | Travel & Hospitality |
| 8 | `sf-pubsec-solutions` | Public Sector & Government |
| 9 | `sf-rcg-solutions` | Retail, CPG & General |

---

## Safety Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `check-no-credentials` | Before every file write | Blocks private keys, account locator URLs, internal hostnames, Bearer tokens |
| `check-solution-conformance` | Phase 5 (security validation) | Verifies required files exist, `database = SF_SOLUTIONS`, source DB names replaced |
