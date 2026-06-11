---
description: >
  Show next actions after installing the LTV Prediction solution.
  Guides the user from demo exploration to production deployment.
  Triggers: what next, next steps, what can I do, how to use this, customize.
---

# Next Actions: Customer Lifetime Value Prediction

After installation, guide the user through these progressive steps from exploration to production.

## Quick Exploration (5 min)

1. **Open the Streamlit Dashboard**
   - URL was shown at the end of install
   - Or find it: Projects > Streamlit > LTV_PREDICTION_DASHBOARD
   - Explore segment distribution, predicted vs actual scatter, AI insights

2. **Query the data**
   ```sql
   -- See your top Platinum customers
   SELECT * FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_SEGMENTS
   WHERE LTV_SEGMENT = 'Platinum'
   ORDER BY PREDICTED_LTV DESC
   LIMIT 20;

   -- Check model accuracy
   SELECT
       ROUND(AVG(ABSOLUTE_ERROR), 2) AS MAE,
       ROUND(CORR(PREDICTED_LTV, ACTUAL_LTV), 4) AS CORRELATION
   FROM SF_SOLUTIONS.LTV_ML.LTV_PREDICTIONS;
   ```

3. **Read AI-generated segment insights**
   ```sql
   SELECT LTV_SEGMENT, AI_INSIGHT
   FROM SF_SOLUTIONS.LTV_ML.SEGMENT_INSIGHTS;
   ```

## Customize with Your Data (30 min)

4. **Replace demo data with your own transactions**
   - Your data needs these columns: `CUSTOMER_ID`, `TRANSACTION_TIME`, `AMOUNT`, `PRODUCT_CATEGORY`, `CHANNEL`
   - Load into `SF_SOLUTIONS.LTV_RAW.ML_LTV_TRANSACTIONS`:
   ```sql
   TRUNCATE TABLE SF_SOLUTIONS.LTV_RAW.ML_LTV_TRANSACTIONS;

   -- Option A: From S3/Azure/GCS stage
   COPY INTO SF_SOLUTIONS.LTV_RAW.ML_LTV_TRANSACTIONS
   FROM @your_stage/your_transactions.csv;

   -- Option B: From existing table
   INSERT INTO SF_SOLUTIONS.LTV_RAW.ML_LTV_TRANSACTIONS
   SELECT customer_id, txn_date, amount, category, channel
   FROM your_database.your_schema.your_transactions;
   ```

5. **Rebuild features and retrain the model**
   - Re-run Steps 2-7 from setup.sql (feature engineering through segment insights)
   - Or execute the full setup.sql again (it uses CREATE OR REPLACE)

## Tune the Model (1 hour)

6. **Adjust the train/test split**
   ```sql
   -- Change from 80/20 to 70/30
   CREATE OR REPLACE VIEW SF_SOLUTIONS.LTV_ANALYTICS.TRAIN_DATA AS
   SELECT * FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_FEATURES
   WHERE ABS(HASH(CUSTOMER_ID)) % 100 < 70;
   ```

7. **Add more features**
   - Edit the CUSTOMER_FEATURES CTE in setup.sql
   - Ideas: day-of-week patterns, seasonality, return rate, coupon usage

8. **Try different ML models**
   ```sql
   -- Use FORECAST for time-series LTV prediction
   CREATE OR REPLACE SNOWFLAKE.ML.FORECAST LTV_FORECAST_MODEL(...)

   -- Or use Cortex AI for classification
   -- Predict churn probability instead of LTV amount
   ```

## Production Deployment

9. **Schedule automated retraining**
   ```sql
   -- Create a task to retrain weekly
   CREATE OR REPLACE TASK SF_SOLUTIONS.LTV_ML.RETRAIN_LTV_MODEL
       WAREHOUSE = COMPUTE_WH
       SCHEDULE = 'USING CRON 0 2 * * 1 America/Los_Angeles'
   AS
       -- Re-run feature engineering + model training
       CALL SF_SOLUTIONS.LTV_ML.RETRAIN_PROCEDURE();
   ```

10. **Connect to your CRM/marketing tools**
    - Export segments to Salesforce via External Functions
    - Share segments with marketing team via Data Sharing
    - Use Cortex AI to generate personalized email content per segment

11. **Set up monitoring**
    ```sql
    -- Alert when model accuracy drops
    CREATE OR REPLACE ALERT SF_SOLUTIONS.LTV_ML.MODEL_DRIFT_ALERT
        WAREHOUSE = COMPUTE_WH
        SCHEDULE = 'USING CRON 0 8 * * * America/Los_Angeles'
        IF (EXISTS (
            SELECT 1 FROM SF_SOLUTIONS.LTV_ML.LTV_PREDICTIONS
            WHERE ABSOLUTE_ERROR > AVG(PREDICTED_LTV) * 0.5
            HAVING COUNT(*) > 100
        ))
        THEN
            CALL SYSTEM$SEND_EMAIL(...);
    ```

12. **Grant access to business users**
    ```sql
    -- Create a reader role for marketing team
    CREATE ROLE IF NOT EXISTS LTV_READER;
    GRANT USAGE ON DATABASE SF_SOLUTIONS TO ROLE LTV_READER;
    GRANT USAGE ON SCHEMA SF_SOLUTIONS.LTV_ANALYTICS TO ROLE LTV_READER;
    GRANT SELECT ON ALL VIEWS IN SCHEMA SF_SOLUTIONS.LTV_ANALYTICS TO ROLE LTV_READER;
    GRANT USAGE ON STREAMLIT SF_SOLUTIONS.LTV_ML.LTV_PREDICTION_DASHBOARD TO ROLE LTV_READER;
    ```

## Summary

| Phase | Time | Actions |
|-------|------|---------|
| Explore | 5 min | Dashboard, query segments, read AI insights |
| Customize | 30 min | Load your data, retrain model |
| Tune | 1 hour | Add features, adjust split, try other models |
| Production | 1 day | Schedule retraining, connect CRM, monitoring, RBAC |
