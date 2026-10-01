# Teardown a Solution

This reference is loaded by the sf-solutions skill when tearing down a solution.
Prerequisites: `$REPO_ROOT`, `$SOLUTION_NAME`, and `$INDUSTRY` must be resolved.

## 1. Read the manifest to identify objects

Read the file with the Read tool:

```
$REPO_ROOT/solutions/$SOLUTION_NAME/manifest.json
```

## 2. Show what will be removed

```
This will permanently remove:
  - Database: <database> (and all schemas/objects within)
  - Warehouses: <list> (only if teardown.sql exists)

Source of teardown.sql:
  Repository: <REPO_URL>
  Branch:     <REPO_BRANCH>
  Commit:     <REPO_COMMIT>
  <If REPO_DIRTY is true: WARNING — solutions/<SOLUTION_NAME>/ has uncommitted local changes>

This action cannot be undone. Proceed?
```

## 3. Wait for explicit confirmation

**MANDATORY CHECKPOINT: Do NOT run teardown.sql or DROP DATABASE without explicit affirmative confirmation from the user. This action cannot be undone.**

## 4. Execute teardown.sql (if exists)

Read the file with the Read tool:

```
$REPO_ROOT/solutions/$SOLUTION_NAME/scripts/teardown.sql
```

If no teardown.sql exists, drop only the database:

```sql
DROP DATABASE IF EXISTS <database>;
```

**Note:** Warehouses are not dropped in this fallback path. If warehouses were created by the solution, they must be dropped manually or by the solution's teardown.sql.

## 5. Confirm teardown complete

Report what was removed.
