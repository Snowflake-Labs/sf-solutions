# Install a Solution

This reference is loaded by the sf-solutions skill when installing a solution.
Prerequisites: `$REPO_ROOT`, `$SOLUTION_NAME`, and `$INDUSTRY` must be resolved.

## 1. Validate the solution exists

Use the Read tool to check if the manifest exists:

```
$REPO_ROOT/solutions/$SOLUTION_NAME/manifest.json
```

If the file is not found, show available solutions and stop.

## 2. Read the manifest

Read the file with the Read tool:

```
$REPO_ROOT/solutions/$SOLUTION_NAME/manifest.json
```

## 3. Query current account info

```sql
SELECT CURRENT_ORGANIZATION_NAME() AS ORG,
       CURRENT_ACCOUNT_NAME() AS ACCOUNT,
       CURRENT_REGION() AS REGION,
       CURRENT_ROLE() AS ROLE;
```

## 4. Present the installation plan and confirm

Show the user a summary combining manifest data and account info using `ask_user_question`:

```
Solution: <name> v<version>
Industry: <industry>
Database: <database>
Schemas:  <comma-separated schemas>
Role Required: <role>
Features: <features>

Target Account:
  Organization: <ORG>
  Account:      <ACCOUNT>
  Region:       <REGION>
  Current Role: <ROLE>

Scripts: <install_scripts list>

Proceed with installation?
```

**Do NOT proceed without explicit "yes" from the user.**

## 5. Execute installation via Task subagent

**CRITICAL: Do NOT read .sql files into the main conversation context.**

Spawn a single Task subagent to handle the full installation:

```
task(
  subagent_type: "generalPurpose",
  description: "Execute <SOLUTION_NAME> installation",
  prompt: """
  Install the <SOLUTION_NAME> solution from <REPO_ROOT>/solutions/<SOLUTION_NAME>/.

  ## STEP 1 — Check for solution-specific SKILL.md

  FIRST, read this file with the Read tool:
    <REPO_ROOT>/solutions/<SOLUTION_NAME>/SKILL.md

  If this file EXISTS, follow its "Install" section EXACTLY. It contains
  solution-specific steps (PUT to stage, semantic view creation, agent.sql, etc.)
  that MUST be followed. Do NOT fall back to the generic steps below.

  If this file does NOT exist, proceed with Step 2 (generic flow).

  ## STEP 2 — Generic flow (only if no SKILL.md)

  Files to execute IN ORDER:
  1. <REPO_ROOT>/solutions/<SOLUTION_NAME>/scripts/setup.sql
  2. <REPO_ROOT>/solutions/<SOLUTION_NAME>/scripts/data.sql (if it exists)

  Execution instructions:
  - Read each SQL file with the Read tool
  - Split into individual statements on semicolons BUT respect $$...$$ dollar-quoting:
    * Track $$ occurrences per line (odd count toggles in/out of dollar-quote mode)
    * Do NOT split on ; when inside a $$...$$ block
  - Skip comment-only statements (all lines start with -- or are blank)
  - Execute each statement via snowflake_sql_execute with timeout_seconds: 600
  - If a statement fails with "already exists" or similar non-critical error, log and continue
  - If a statement fails with "insufficient privileges", log the error and stop

  ## Reporting

  Report back:
  - Which flow was used (SKILL.md or generic)
  - Number of statements executed successfully
  - Any INSERT row counts
  - Whether semantic view and/or agent were created
  - Any errors encountered (with the failing SQL snippet)
  """
)
```

## 6. Verify installation

After the subagent completes, run verification:

```sql
SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
FROM <database>.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN (<schemas from manifest>)
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;
```

## 7. Load next actions guide

Read the file with the Read tool (if it exists):

```
$REPO_ROOT/solutions/$SOLUTION_NAME/NEXT_ACTIONS.md
```

If the file exists, present the recommended next steps to the user.

## 8. Post-install summary

Present:
- Solution name and version
- Objects created (table count, total rows)
- Agent URL (if features include "Snowflake Intelligence" or "Cortex Agent")
- Teardown command: `$sf-solutions:<SOLUTION_NAME> teardown`
