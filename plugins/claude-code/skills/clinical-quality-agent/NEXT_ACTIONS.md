---
description: >
  Show next actions after installing the Clinical Quality Agent solution.
  Guides the user from exploration to production deployment.
  Triggers: what next, next steps, what can I do, how to use this, customize.
---

# Next Actions: Clinical Quality and Patient Safety Agent

After installation, guide the user through these progressive steps.

## Quick Exploration (5 min)

1. **Open the Cortex Agent**
   - URL was shown at the end of install
   - Or navigate: Snowsight > AI & ML > Agents > clinical_quality_safety_agent

2. **Try these questions:**
   ```
   How many patients died in the last year?
   Show me catheter infections that resulted in death
   What is our quarterly mortality trend?
   What percentage of deaths were preventable?
   Compare our sepsis mortality to national benchmarks
   ```

3. **Try PubMed search (if installed):**
   ```
   Find PubMed articles on preventing CAUTI infections
   What does recent research say about reducing hospital-acquired infections?
   ```

4. **Query the data directly:**
   ```sql
   -- Mortality summary
   SELECT COUNT(*) AS total_deaths,
          ROUND(AVG(CASE WHEN IS_PREVENTABLE THEN 1 ELSE 0 END) * 100, 1) AS pct_preventable
   FROM SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.OUTCOMES
   WHERE OUTCOME_TYPE = 'DEATH';

   -- Infection rates by type
   SELECT INFECTION_TYPE, COUNT(*) AS CASES,
          SUM(CASE WHEN RESULTED_IN_DEATH THEN 1 ELSE 0 END) AS DEATHS
   FROM SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.INFECTIONS
   GROUP BY INFECTION_TYPE
   ORDER BY CASES DESC;
   ```

## Customize with Your Data (30 min)

5. **Replace demo data with real clinical data**
   - Map your data to the 8-table schema (PATIENTS, ADMISSIONS, DIAGNOSES, PROCEDURES, INFECTIONS, QUALITY_EVENTS, OUTCOMES, RISK_FACTORS)
   - Load via COPY INTO or INSERT INTO

6. **Adjust data generation parameters** (if using synthetic data)
   ```sql
   -- Edit these in setup.sql before re-running
   SET num_patients = 75000;
   SET mortality_multiplier = 1.20;    -- 20% above national avg
   SET hai_multiplier = 1.25;          -- 25% above national avg
   SET trend_degradation = 0.06;       -- 6% quarterly worsening
   ```

7. **Update the semantic model**
   - Edit `scripts/semantic_model.yaml` to match your columns
   - Re-create the Cortex Analyst tool with updated model

## Extend the Agent (1 hour)

8. **Add more Agent tools**
   - Add a Cortex Search tool over your internal clinical guidelines
   - Add a webhook tool for Slack/Teams notifications
   - Add a tool for automated report generation

9. **Create custom Snowflake Intelligence dashboards**
   - Build quality scorecards combining Agent answers with visualizations
   - Set up scheduled queries for daily quality reports

10. **Connect additional data sources**
    - EHR data via External Functions or SPCS
    - Lab results, pharmacy data, nursing assessments
    - External benchmarks (CMS Hospital Compare, Leapfrog)

## Production Deployment

11. **Set up automated quality monitoring**
    ```sql
    CREATE OR REPLACE ALERT SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.MORTALITY_SPIKE_ALERT
        WAREHOUSE = SF_SOLUTIONS_WH
        SCHEDULE = 'USING CRON 0 7 * * * America/Los_Angeles'
        IF (EXISTS (
            SELECT 1 FROM SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.OUTCOMES
            WHERE OUTCOME_TYPE = 'DEATH'
              AND OUTCOME_DATE >= DATEADD(DAY, -1, CURRENT_DATE())
            HAVING COUNT(*) > 5
        ))
        THEN
            CALL SYSTEM$SEND_EMAIL(...);
    ```

12. **Grant access to quality team**
    ```sql
    CREATE ROLE IF NOT EXISTS CLINICAL_QUALITY_READER;
    GRANT USAGE ON DATABASE SF_SOLUTIONS TO ROLE CLINICAL_QUALITY_READER;
    GRANT USAGE ON SCHEMA SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY TO ROLE CLINICAL_QUALITY_READER;
    GRANT SELECT ON ALL TABLES IN SCHEMA SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY TO ROLE CLINICAL_QUALITY_READER;
    ```

13. **Schedule data refresh**
    ```sql
    CREATE OR REPLACE TASK SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.REFRESH_DATA
        WAREHOUSE = SF_SOLUTIONS_WH
        SCHEDULE = 'USING CRON 0 1 * * * America/Los_Angeles'
    AS
        -- Refresh from your EHR/data warehouse
        CALL SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.REFRESH_PROCEDURE();
    ```

## Summary

| Phase | Actions |
|-------|---------|
| Explore | Ask questions via Cortex Agent, query tables, search PubMed |
| Customize | Load your clinical data, adjust parameters, update semantic model |
| Extend | Add Agent tools, build dashboards, connect data sources |
| Production | Automated alerts, RBAC, scheduled refresh |
