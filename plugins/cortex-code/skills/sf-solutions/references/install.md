# Install a Solution

This reference is loaded by the sf-solutions skill when installing a solution.
Prerequisites: `$REPO_ROOT`, `$SOLUTION_NAME`, and `$INDUSTRY` must be resolved.

## 1. Validate the solution exists

Use the Read tool to check if the manifest exists:

```
$REPO_ROOT/solutions/$SOLUTION_NAME/manifest.json
```

If not found, show available solutions and stop.

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

## 4. Present the installation plan

Show the user a summary combining manifest data and account info:

```
Solution: <name> v<version>
Industry: <industry>
Database: <database>
Schemas:  <comma-separated schemas>
Role Required: <role>

Target Account:
  Organization: <ORG>
  Account:      <ACCOUNT>
  Region:       <REGION>
  Current Role: <ROLE>

What will be created:
  <bullet list from manifest.objects_created or inferred from setup.sql>

Proceed with installation?
```

## 5. Wait for user confirmation

**Do NOT proceed without explicit "yes" from the user.**

## 6. Execute setup.sql

Read the setup script with the Read tool:

```
$REPO_ROOT/solutions/$SOLUTION_NAME/scripts/setup.sql
```

Execute each statement via `snowflake_sql_execute`. Use `timeout_seconds: 600` for data loading statements. Log progress after each major section.

## 7. Execute data.sql (if exists)

Check if the file exists using the Read tool:

```
$REPO_ROOT/solutions/$SOLUTION_NAME/scripts/data.sql
```

If it exists, execute it statement by statement with `timeout_seconds: 600`.

## 8. Confirm success

```sql
SHOW SCHEMAS IN DATABASE <database>;
```

Report what was created.

## 9. Load next actions guide

Read the file with the Read tool (if it exists):

```
$REPO_ROOT/solutions/$SOLUTION_NAME/NEXT_ACTIONS.md
```

If the file exists, read it and present the recommended next steps to the user. This file contains solution-specific guidance (e.g., how to use the installed agent, sample queries to try, dashboards to open). If the user has follow-up questions about what to do next, refer back to this file for answers.
