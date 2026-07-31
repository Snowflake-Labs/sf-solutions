# sf-solutions Internal Plugin

Internal Cortex Code plugin for Snowflake solution authors. Provides tools to convert
internal industry plugins into public `sf-*-solutions` format.

> **Note:** This plugin is for internal use only. It is not intended for customers.

---

## Install

```bash
cortex plugin install git Snowflake-Labs/sf-solutions --sub-path plugins/internal
```

---

## Skills

### `publish-solution`

Converts an `industry-plugin-construct` plugin into the standard `sf-*-solutions` format.

**What it does:**

1. Analyzes the source plugin (SQL objects, skills, agents, references)
2. Asks which industry repo to publish to
3. Adapts all SQL to use `SF_SOLUTIONS` database and `SF_SOLUTIONS_WH` warehouse
4. Generates required files: `manifest.json`, `setup.sql`, `teardown.sql`, `README.md`, `NEXT_ACTIONS.md`
5. Validates output — no credentials, no internal URLs, required files present

**Usage:**

```
$sfs:publish-solution <source-plugin-path> <target-repo-dir>
```

**Example:**

```
$sfs:publish-solution ~/sfc-gh-projects/industry-plugin-construct/plugins/irops-intelligence-center ~/project/sf-mleu-solutions
```

**Target repos:**

| # | Repository | Industry |
|---|-----------|---------|
| 1 | `sf-hcls-solutions` | Healthcare & Life Sciences |
| 2 | `sf-fsi-solutions` | Financial Services & Insurance |
| 3 | `sf-mleu-solutions` | Manufacturing, Logistics, Energy & Utilities |
| 4 | `sf-telco-solutions` | Telecommunications |
| 5 | `sf-media-entertainment-solutions` | Media & Entertainment |
| 6 | `sf-marketing-solutions` | Marketing & Advertising |
| 7 | `sf-tnh-solutions` | Travel & Hospitality |
| 8 | `sf-pubsec-solutions` | Public Sector & Government |
| 9 | `sf-rcg-solutions` | Retail, CPG & General |

---

## Safety Hooks

The plugin includes two validation hooks:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `check-no-credentials` | Before every file write | Blocks private keys, account locator URLs, internal hostnames, Bearer tokens |
| `check-solution-conformance` | Phase 4 (post-generation) | Verifies required files exist, `database = SF_SOLUTIONS`, source DB names replaced |
