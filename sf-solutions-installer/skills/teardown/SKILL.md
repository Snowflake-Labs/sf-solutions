---
description: >
  Tear down (uninstall) a previously installed Snowflake industry solution.
  Reads manifest.json to find teardown scripts and executes them to remove all created objects.
  Use when: removing a solution, cleaning up a demo environment.
---

# Teardown Snowflake Industry Solution

Removes a previously installed solution by executing its teardown scripts.

## Instructions

### Step 1: Parse and Locate

1. Extract the solution slug from: `/snowflake-solutions:teardown <slug>`
2. Locate the sf-solutions repository (same logic as install skill)
3. Read `<slug>/manifest.json`

### Step 2: Confirm Teardown

**STOP HERE** — Present what will be removed:

```
Teardown: <display_name> (v<version>)

Will DROP:
  Schema(s): <database>.<schema> (CASCADE) for each schema in manifest
  Agent(s): if any exist in the schema

The database <database> will NOT be dropped (shared across solutions).

Proceed with teardown?
```

Wait for user confirmation.

### Step 3: Execute Teardown Scripts

For each script in `teardown_scripts`:
1. Read the SQL file
2. Execute against Snowflake
3. Log each DROP statement

### Step 4: Verify Removal

```sql
SHOW SCHEMAS IN DATABASE <database>;
```

Confirm the schemas no longer exist.

### Step 5: Summary

```
Solution removed: <display_name>
Dropped schemas: <list>
Database <database> preserved.
```
