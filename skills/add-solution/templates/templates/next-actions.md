# {{name}} — What's Next

After installing the {{name}} solution, here are four phases of engagement.

---

## Phase 1: Quick Exploration (5 min)

Get oriented with the data and models that were just created.

**Queries to try:**

```sql
-- Overview of created tables
SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
FROM SF_SOLUTIONS.INFORMATION_SCHEMA.TABLES
ORDER BY TABLE_SCHEMA, TABLE_NAME;
```

**What to look for:** Row counts, schema structure, table names.

---

## Phase 2: Customize with Your Data (30 min)

Replace the sample data with your own.

1. Identify the raw ingestion table and replace the S3 COPY INTO with your data source
2. Adjust column names in the feature engineering SQL if your schema differs
3. Re-run the setup steps from the point of data loading forward

**Tip:** The `manifest.json` in the solution repo describes each schema's purpose.

---

## Phase 3: Tune and Optimize (1 hr)

Improve model accuracy or query performance.

1. Adjust hyperparameters in the ML training step
2. Add or remove features in the feature engineering queries
3. Review EXPLAIN plans on slow analytical queries and add clustering keys

---

## Phase 4: Production Deployment (1 day)

Harden for production use.

1. Replace `ACCOUNTADMIN` with a least-privilege role
2. Schedule the data pipeline with a Snowflake Task
3. Set up alerts on data freshness and model drift
4. Review the Streamlit app and customize branding and filters

---

## Related Resources

- [Snowflake ML](https://docs.snowflake.com/en/developer-guide/snowflake-ml/overview)
- [Cortex AI Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)
- [Snowflake Tasks](https://docs.snowflake.com/en/user-guide/tasks-intro)
