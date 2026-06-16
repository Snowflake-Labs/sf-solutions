---
description: >
  Show next actions after installing the Manufacturing Predictive Maintenance solution.
  Guides the user from exploration to production deployment.
  Triggers: what next, next steps, what can I do, how to use this, customize.
---

# Next Actions: Manufacturing Predictive Maintenance

After installation, guide the user through these progressive steps.

## Quick Exploration (5 min)

1. **Open the Snowflake Intelligence Agent**
   - URL was shown at the end of install
   - Or navigate: Snowsight > AI & ML > Agents > PREDICTIVE_MAINTENANCE_ASSISTANT

2. **Try these questions:**
   ```
   Show me assets with health scores below 70
   What are the total maintenance costs this month?
   Which assets are predicted to fail in the next 30 days?
   What is the average OEE across all facilities?
   Show maintenance history for Asset A-101
   ```

3. **Query the data directly:**
   ```sql
   -- Asset health overview
   SELECT ASSET_ID, ASSET_NAME, HEALTH_SCORE, PREDICTED_FAILURE_DATE
   FROM SF_SOLUTIONS.GOLD.ASSET_HEALTH_METRICS
   WHERE HEALTH_SCORE < 70
   ORDER BY HEALTH_SCORE ASC;

   -- Maintenance costs by facility
   SELECT FACILITY_NAME, SUM(MAINTENANCE_COST) AS TOTAL_COST
   FROM SF_SOLUTIONS.GOLD.MAINTENANCE_SUMMARY
   GROUP BY FACILITY_NAME
   ORDER BY TOTAL_COST DESC;

   -- OEE metrics
   SELECT ASSET_ID, AVG(OEE) AS AVG_OEE
   FROM SF_SOLUTIONS.GOLD.OEE_METRICS
   GROUP BY ASSET_ID
   ORDER BY AVG_OEE ASC
   LIMIT 10;
   ```

## Customize with Your Data (30 min)

4. **Replace demo data with real IoT telemetry**
   - Map your data to BRONZE schema tables (telemetry, maintenance logs, equipment specs)
   - Load via COPY INTO from your data lake or streaming ingestion

5. **Connect real-time IoT data**
   ```sql
   -- Set up Snowpipe for streaming sensor data
   CREATE PIPE SF_SOLUTIONS.BRONZE.SENSOR_PIPE
       AUTO_INGEST = TRUE
   AS
       COPY INTO SF_SOLUTIONS.BRONZE.RAW_TELEMETRY
       FROM @your_iot_stage;
   ```

6. **Update the semantic view**
   - Modify the semantic view in GOLD schema to match your column names
   - Re-create the Cortex Analyst tool with the updated model

## Extend the Solution (1 hour)

7. **Deploy the Streamlit dashboard**
   - Clone the source repo: `git clone https://github.com/Snowflake-Labs/sfguide-getting-started-with-predictive-maintenance.git`
   - Upload Streamlit files to `@SF_SOLUTIONS.GOLD.STREAMLIT_STAGE`
   - Create the STREAMLIT object pointing to the stage

8. **Add ML prediction models**
   ```sql
   -- Train a failure prediction model
   CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION FAILURE_PREDICTOR(
       INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'GOLD.ML_FEATURES'),
       TARGET_COLNAME => 'WILL_FAIL_30D'
   );
   ```

9. **Add more Agent tools**
   - Add Cortex Search over maintenance manuals
   - Add email notification tool for critical alerts
   - Add a tool for work order generation

## Production Deployment

10. **Set up automated health monitoring**
    ```sql
    CREATE OR REPLACE ALERT SF_SOLUTIONS.GOLD.CRITICAL_HEALTH_ALERT
        WAREHOUSE = SF_SOLUTIONS_WH
        SCHEDULE = 'USING CRON 0 */4 * * * America/Los_Angeles'
        IF (EXISTS (
            SELECT 1 FROM SF_SOLUTIONS.GOLD.ASSET_HEALTH_METRICS
            WHERE HEALTH_SCORE < 50
            HAVING COUNT(*) > 0
        ))
        THEN
            CALL SYSTEM$SEND_EMAIL(...);
    ```

11. **Schedule data pipeline refresh**
    ```sql
    CREATE OR REPLACE TASK SF_SOLUTIONS.GOLD.REFRESH_METRICS
        WAREHOUSE = SF_SOLUTIONS_WH
        SCHEDULE = 'USING CRON 0 */6 * * * America/Los_Angeles'
    AS
        -- Rebuild Silver and Gold layers from Bronze
        CALL SF_SOLUTIONS.GOLD.REFRESH_PIPELINE();
    ```

12. **Grant access to operations team**
    ```sql
    CREATE ROLE IF NOT EXISTS MAINTENANCE_VIEWER;
    GRANT USAGE ON DATABASE SF_SOLUTIONS TO ROLE MAINTENANCE_VIEWER;
    GRANT USAGE ON SCHEMA SF_SOLUTIONS.GOLD TO ROLE MAINTENANCE_VIEWER;
    GRANT SELECT ON ALL VIEWS IN SCHEMA SF_SOLUTIONS.GOLD TO ROLE MAINTENANCE_VIEWER;
    ```

## Summary

| Phase | Actions |
|-------|---------|
| Explore | Ask questions via Intelligence Agent, query Gold tables |
| Customize | Load real IoT data, connect streaming, update semantic view |
| Extend | Deploy Streamlit, add ML models, add Agent tools |
| Production | Automated alerts, scheduled pipelines, RBAC |
