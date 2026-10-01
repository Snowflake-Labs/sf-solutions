# Install a Plugin-Type Solution

This reference is loaded by `install.md` when a solution's `manifest.json` has `"type": "plugin"`.
Prerequisites: `$REPO_ROOT`, `$SOLUTION_NAME`, `$INDUSTRY`, and the parsed manifest must be resolved.

The manifest must include a `plugin_path` field indicating the relative path from the solution directory to the plugin root (e.g., `"plugin_path": "plugins/cortex-code"`).

## 1. Display unofficial disclaimer

**MANDATORY.** Before anything else, display the following disclaimer to the user:

> **NOTICE:** This application is not part of the Snowflake Service and is governed by the terms in LICENSE, unless expressly agreed to in writing. You use this application at your own risk, and Snowflake has no obligation to support your use of this application.

Do NOT skip or abbreviate this disclaimer.

## 2. Scan plugin contents

Read the plugin directory at `$REPO_ROOT/solutions/$SOLUTION_NAME/<plugin_path>/` and collect:

- **plugin.json** — read `.cortex-plugin/plugin.json` for name, version, authors
- **Skills** — list each `skills/<name>/SKILL.md` (name + first-line description)
- **Hooks** — if `hooks/hooks.json` exists, list every hook event and command; otherwise "None"
- **MCP Servers** — if `.mcp.json` exists, list each server name and command; otherwise "None"
- **Agents** — list each `agents/<name>.md`; otherwise "None"

Do NOT display these results yet — they will be shown in the installation plan (Section 4).

## 3. Grandchild plugin check

**CRITICAL SECURITY CHECK.** The plugin must NOT install other plugins (grandchild prohibition).

Spawn a Task subagent to inspect the plugin contents:

```
task(
  subagent_type: "explore",
  readonly: true,
  description: "Check for grandchild plugin installs",
  prompt: """
  Inspect the plugin at <REPO_ROOT>/solutions/<SOLUTION_NAME>/<plugin_path>/ for any logic
  that would install additional plugins. This is a security check — grandchild plugin
  installation is prohibited.

  Check for:
  1. Any SKILL.md files that reference github-plugin-installer, local-plugin-installer,
     or plugin-creator skills
  2. Any SKILL.md files that write to ~/.snowflake/cortex/plugins/ or modify registry.json
  3. Any hooks in hooks/hooks.json that write to the plugins directory
  4. Any MCP server configs that could modify the plugin registry

  Report back:
  - PASS if no grandchild install logic was found
  - FAIL with specific file paths and snippets if any was found
  """
)
```

**If the check returns FAIL, show the findings to the user and STOP. Do NOT proceed with installation.**

## 4. Query current account info

```sql
SELECT CURRENT_ORGANIZATION_NAME() AS ORG,
       CURRENT_ACCOUNT_NAME() AS ACCOUNT,
       CURRENT_REGION() AS REGION,
       CURRENT_ROLE() AS ROLE;
```

## 5. Present installation plan and confirm

**CRITICAL: You MUST display the installation plan below using `ask_user_question` BEFORE proceeding. NEVER skip this step. NEVER ask "do you want to install?" without first showing this exact template filled in. If you skip this, the installation is invalid.**

Fill in EVERY field from the scanned data (Section 2) and account info (Section 4). Use `ask_user_question` with the plan as the question text:

```
============================================================
  UNOFFICIAL PLUGIN — NOT A SUPPORTED SNOWFLAKE PRODUCT
============================================================

This application is not part of the Snowflake Service and is
governed by the terms in LICENSE, unless expressly agreed to
in writing. You use this application at your own risk, and
Snowflake has no obligation to support your use of this
application.

Solution:     <name> v<version>
Type:         Plugin
Industry:     <industry>

Plugin to install:
  Name:        <plugin name from plugin.json>
  Version:     <plugin version>
  Authors:     <plugin authors>
  Source:      <plugin_path>
  Install to:  ~/.snowflake/cortex/plugins/<plugin-name>/

Components:
  Skills:      <list every skill name, one per line>
  Hooks:       <list every hook event and command, or "None">
  MCP Servers: <list every server name and command, or "None">
  Agents:      <list every agent name, or "None">

Target Account:
  Organization: <ORG>
  Account:      <ACCOUNT>
  Region:       <REGION>
  Current Role: <ROLE>

Snowflake objects to create (if any):
  Database: <database from manifest, or "None">
  Schemas:  <schemas from manifest, or "None">
  Scripts:  <install_scripts list, or "None">

Do you want to install this plugin? (yes/no)
```

**Do NOT proceed without explicit "yes" from the user.**
**If the user says "no" or anything other than "yes", STOP immediately.**

## 6. Install the plugin via Task subagent

**CRITICAL: Do NOT perform file writes in the main conversation context.**

Spawn a single Task subagent to handle the plugin installation:

```
task(
  subagent_type: "generalPurpose",
  description: "Install <SOLUTION_NAME> plugin",
  prompt: """
  Install the CoCo plugin from:
    <REPO_ROOT>/solutions/<SOLUTION_NAME>/<plugin_path>/

  Target directory:
    ~/.snowflake/cortex/plugins/<plugin-name>/

  ## STEP 1 — Copy plugin files

  1. Check if ~/.snowflake/cortex/plugins/<plugin-name>/ already exists.
     If yes, report this and STOP — do not overwrite without explicit instruction.
  2. Copy the entire plugin directory:
     cp -r <REPO_ROOT>/solutions/<SOLUTION_NAME>/<plugin_path>/ ~/.snowflake/cortex/plugins/<plugin-name>/
  3. Verify the copy succeeded by listing the target directory.

  ## STEP 2 — Update registry.json

  Read ~/.snowflake/cortex/plugins/registry.json (create if missing).
  Add or update the entry for this plugin:

  {
    "name": "<plugin-name>",
    "path": "~/.snowflake/cortex/plugins/<plugin-name>",
    "enabled": true,
    "installKind": "sf-solutions",
    "sfSolutions": {
      "solutionName": "<SOLUTION_NAME>",
      "industry": "<INDUSTRY>",
      "repoUrl": "<REPO_URL>",
      "installedAt": "<ISO 8601 timestamp>"
    }
  }

  ## STEP 3 — Execute SQL scripts (if any)

  If the manifest includes install_scripts, execute them IN ORDER:
  - Read each SQL file with the Read tool
  - Split on semicolons respecting $$...$$ dollar-quoting
  - Execute via snowflake_sql_execute with timeout_seconds: 600
  - Log errors but continue for non-critical failures

  ## Reporting

  Report back:
  - Plugin install path
  - Whether registry.json was updated
  - Number of SQL statements executed (if any)
  - Any errors encountered
  """
)
```

## 7. Verify installation

After the subagent completes:

1. Verify the plugin directory exists:

```
~/.snowflake/cortex/plugins/<plugin-name>/.cortex-plugin/plugin.json
```

2. If SQL scripts were executed, run table verification:

```sql
SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
FROM <database>.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN (<schemas from manifest>)
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;
```

## 8. Load next actions guide

Read the file with the Read tool (if it exists):

```
$REPO_ROOT/solutions/$SOLUTION_NAME/NEXT_ACTIONS.md
```

If the file exists, present the recommended next steps to the user.

## 9. Post-install summary

Present:
- Solution name and version
- Plugin name and install location
- Skills installed (list names)
- Objects created in Snowflake (if SQL scripts were run)
- Agent URL (if features include "Snowflake Intelligence" or "Cortex Agent")
- Usage: `$<plugin-name>` or `$<plugin-name>:<skill-name>`
- Teardown command: `$sf-solutions:teardown <SOLUTION_NAME>`
