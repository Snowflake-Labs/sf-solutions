-- CUSTOMER LIFETIME VALUE PREDICTION SETUP
-- Version: 2.0
--
-- PREREQUISITES:
-- This script requires ACCOUNTADMIN role or a role with:
--   - CREATE DATABASE, SCHEMA, TABLE, VIEW, STAGE
--   - CREATE WAREHOUSE
--
-- WHAT THIS SCRIPT CREATES:
--   - Database: SF_SOLUTIONS (if not exists)
--   - Schemas: LTV_RAW, LTV_ANALYTICS, LTV_ML
--   - Raw transaction data loaded from S3 (~100K+ records)
--   - Monthly customer spend time series for ML FORECAST
--   - Snowflake ML Forecast model for LTV prediction
--   - Customer segments (Platinum/Gold/Silver/Bronze)
/*************************************************************************************************/

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS SF_SOLUTIONS;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.LTV_RAW;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.LTV_ANALYTICS;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.LTV_ML;

CREATE WAREHOUSE IF NOT EXISTS SF_SOLUTIONS_WH
    WAREHOUSE_SIZE = 'LARGE'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

USE DATABASE SF_SOLUTIONS;
USE WAREHOUSE SF_SOLUTIONS_WH;

/*************************************************************************************************/
-- STEP 1: Load raw transaction data from S3
/*************************************************************************************************/

USE SCHEMA LTV_RAW;

CREATE OR REPLACE FILE FORMAT ML_CSVFORMAT
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TYPE = 'CSV';

CREATE OR REPLACE STAGE ML_LTV_DATA_STAGE
    FILE_FORMAT = ML_CSVFORMAT
    URL = 's3://sfquickstarts/sfguide_getting_started_with_cortex_code_for_ds_ml/ltv_transactions/';

CREATE OR REPLACE TABLE ML_LTV_TRANSACTIONS (
    CUSTOMER_ID VARCHAR(50),
    TRANSACTION_TIME TIMESTAMP_NTZ(9),
    AMOUNT NUMBER(12, 2),
    PRODUCT_CATEGORY VARCHAR(15),
    CHANNEL VARCHAR(8)
);

COPY INTO ML_LTV_TRANSACTIONS
    FROM @ML_LTV_DATA_STAGE;

/*************************************************************************************************/
-- STEP 2: Create monthly customer spend time series
-- Aggregates transactions into (CUSTOMER_ID, MONTH, MONTHLY_SPEND) for FORECAST
/*************************************************************************************************/

USE SCHEMA LTV_ANALYTICS;

CREATE OR REPLACE TABLE CUSTOMER_MONTHLY_SPEND AS
SELECT
    CUSTOMER_ID,
    DATE_TRUNC('MONTH', TRANSACTION_TIME)::DATE AS MONTH,
    SUM(AMOUNT) AS MONTHLY_SPEND
FROM SF_SOLUTIONS.LTV_RAW.ML_LTV_TRANSACTIONS
GROUP BY CUSTOMER_ID, DATE_TRUNC('MONTH', TRANSACTION_TIME)
ORDER BY CUSTOMER_ID, MONTH;

-- Also create customer-level features for segmentation context
CREATE OR REPLACE TABLE CUSTOMER_FEATURES AS
SELECT
    CUSTOMER_ID,
    COUNT(*) AS TXN_COUNT,
    SUM(AMOUNT) AS TOTAL_SPEND,
    AVG(AMOUNT) AS AVG_TXN_AMOUNT,
    DATEDIFF(DAY, MIN(TRANSACTION_TIME), MAX(TRANSACTION_TIME)) AS CUSTOMER_TENURE_DAYS,
    COUNT(DISTINCT DATE_TRUNC('MONTH', TRANSACTION_TIME)) AS ACTIVE_MONTHS,
    COUNT(DISTINCT PRODUCT_CATEGORY) AS DISTINCT_CATEGORIES,
    ROUND(COUNT_IF(CHANNEL = 'online') * 1.0 / NULLIF(COUNT(*), 0), 4) AS ONLINE_RATIO,
    CASE
        WHEN DATEDIFF(DAY, MIN(TRANSACTION_TIME), MAX(TRANSACTION_TIME)) > 0
        THEN COUNT(*) * 30.0 / DATEDIFF(DAY, MIN(TRANSACTION_TIME), MAX(TRANSACTION_TIME))
        ELSE COUNT(*)
    END AS MONTHLY_FREQUENCY,
    DATEDIFF(DAY, MAX(TRANSACTION_TIME), (SELECT MAX(TRANSACTION_TIME) FROM SF_SOLUTIONS.LTV_RAW.ML_LTV_TRANSACTIONS)) AS RECENCY_DAYS
FROM SF_SOLUTIONS.LTV_RAW.ML_LTV_TRANSACTIONS
GROUP BY CUSTOMER_ID;

/*************************************************************************************************/
-- STEP 3: Train Snowflake ML FORECAST model
-- Predicts future monthly spend per customer for 3 months ahead
/*************************************************************************************************/

USE SCHEMA LTV_ML;

CREATE OR REPLACE SNOWFLAKE.ML.FORECAST LTV_FORECAST_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('TABLE', 'SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_MONTHLY_SPEND'),
    SERIES_COLNAME => 'CUSTOMER_ID',
    TIMESTAMP_COLNAME => 'MONTH',
    TARGET_COLNAME => 'MONTHLY_SPEND'
);

/*************************************************************************************************/
-- STEP 4: Generate LTV predictions (sum of forecasted next 3 months)
/*************************************************************************************************/

-- Generate 3-month forecast for all customers
-- Use TABLE() wrapper to store results directly
CREATE OR REPLACE TABLE SF_SOLUTIONS.LTV_ML.LTV_FORECAST_RAW AS
SELECT * FROM TABLE(LTV_FORECAST_MODEL!FORECAST(FORECASTING_PERIODS => 3));

-- Aggregate forecast into predicted LTV per customer
CREATE OR REPLACE TABLE SF_SOLUTIONS.LTV_ML.LTV_PREDICTIONS AS
WITH forecast_results AS (
    SELECT
        SERIES AS CUSTOMER_ID,
        SUM(FORECAST) AS PREDICTED_LTV
    FROM SF_SOLUTIONS.LTV_ML.LTV_FORECAST_RAW
    GROUP BY SERIES
),
actual_ltv AS (
    -- Actual spend in the last 3 months of historical data as comparison
    SELECT
        CUSTOMER_ID,
        SUM(MONTHLY_SPEND) AS ACTUAL_LTV
    FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_MONTHLY_SPEND
    WHERE MONTH >= (SELECT DATEADD(MONTH, -3, MAX(MONTH)) FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_MONTHLY_SPEND)
    GROUP BY CUSTOMER_ID
)
SELECT
    F.CUSTOMER_ID,
    COALESCE(A.ACTUAL_LTV, 0) AS ACTUAL_LTV,
    ROUND(F.PREDICTED_LTV, 2) AS PREDICTED_LTV,
    ROUND(ABS(F.PREDICTED_LTV - COALESCE(A.ACTUAL_LTV, 0)), 2) AS ABSOLUTE_ERROR,
    C.TOTAL_SPEND,
    C.TXN_COUNT,
    C.CUSTOMER_TENURE_DAYS,
    C.MONTHLY_FREQUENCY,
    C.RECENCY_DAYS,
    C.ONLINE_RATIO,
    C.DISTINCT_CATEGORIES
FROM forecast_results F
LEFT JOIN actual_ltv A ON F.CUSTOMER_ID = A.CUSTOMER_ID
LEFT JOIN SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_FEATURES C ON F.CUSTOMER_ID = C.CUSTOMER_ID;

/*************************************************************************************************/
-- STEP 5: Customer segments by predicted LTV
/*************************************************************************************************/

CREATE OR REPLACE VIEW SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_SEGMENTS AS
SELECT
    *,
    CASE
        WHEN PREDICTED_LTV >= (
            SELECT PERCENTILE_CONT(0.9)
                WITHIN GROUP (ORDER BY PREDICTED_LTV)
            FROM SF_SOLUTIONS.LTV_ML.LTV_PREDICTIONS
        ) THEN 'Platinum'
        WHEN PREDICTED_LTV >= (
            SELECT PERCENTILE_CONT(0.7)
                WITHIN GROUP (ORDER BY PREDICTED_LTV)
            FROM SF_SOLUTIONS.LTV_ML.LTV_PREDICTIONS
        ) THEN 'Gold'
        WHEN PREDICTED_LTV >= (
            SELECT PERCENTILE_CONT(0.4)
                WITHIN GROUP (ORDER BY PREDICTED_LTV)
            FROM SF_SOLUTIONS.LTV_ML.LTV_PREDICTIONS
        ) THEN 'Silver'
        ELSE 'Bronze'
    END AS LTV_SEGMENT
FROM SF_SOLUTIONS.LTV_ML.LTV_PREDICTIONS;

/*************************************************************************************************/
-- STEP 6: AI-powered segment insights using Cortex AI Functions
/*************************************************************************************************/

CREATE OR REPLACE TABLE SF_SOLUTIONS.LTV_ML.SEGMENT_INSIGHTS AS
WITH segment_stats AS (
    SELECT
        LTV_SEGMENT,
        COUNT(*) AS CUSTOMER_COUNT,
        ROUND(AVG(PREDICTED_LTV), 2) AS AVG_PREDICTED_LTV,
        ROUND(AVG(TOTAL_SPEND), 2) AS AVG_SPEND,
        ROUND(AVG(TXN_COUNT), 1) AS AVG_TXNS,
        ROUND(AVG(MONTHLY_FREQUENCY), 2) AS AVG_FREQ,
        ROUND(AVG(RECENCY_DAYS), 0) AS AVG_RECENCY,
        ROUND(AVG(ONLINE_RATIO), 2) AS AVG_ONLINE_RATIO,
        ROUND(AVG(DISTINCT_CATEGORIES), 1) AS AVG_CATEGORIES
    FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_SEGMENTS
    GROUP BY LTV_SEGMENT
)
SELECT
    S.*,
    SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large2',
        CONCAT(
            'You are a retail analytics expert. ',
            'Based on these customer segment statistics, ',
            'write a 2-sentence business insight and ',
            '1 actionable recommendation. ',
            'Segment: ', S.LTV_SEGMENT,
            ', Customers: ', S.CUSTOMER_COUNT::VARCHAR,
            ', Avg Predicted LTV: $', S.AVG_PREDICTED_LTV::VARCHAR,
            ', Avg Historical Spend: $', S.AVG_SPEND::VARCHAR,
            ', Avg Transactions: ', S.AVG_TXNS::VARCHAR,
            ', Avg Monthly Frequency: ', S.AVG_FREQ::VARCHAR,
            ', Avg Recency (days): ', S.AVG_RECENCY::VARCHAR,
            ', Online Ratio: ', S.AVG_ONLINE_RATIO::VARCHAR,
            ', Avg Categories: ', S.AVG_CATEGORIES::VARCHAR
        )
    ) AS AI_INSIGHT
FROM segment_stats S;

/*************************************************************************************************/
-- VERIFICATION
/*************************************************************************************************/

SELECT 'ML_LTV_TRANSACTIONS' AS STEP, COUNT(*) AS ROWS
FROM SF_SOLUTIONS.LTV_RAW.ML_LTV_TRANSACTIONS
UNION ALL
SELECT 'CUSTOMER_FEATURES', COUNT(*)
FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_FEATURES
UNION ALL
SELECT 'LTV_PREDICTIONS', COUNT(*)
FROM SF_SOLUTIONS.LTV_ML.LTV_PREDICTIONS;

SELECT
    LTV_SEGMENT,
    COUNT(*) AS CUSTOMER_COUNT,
    ROUND(AVG(PREDICTED_LTV), 2) AS AVG_PREDICTED_LTV,
    ROUND(AVG(ACTUAL_LTV), 2) AS AVG_ACTUAL_LTV,
    ROUND(AVG(TOTAL_SPEND), 2) AS AVG_HISTORICAL_SPEND
FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_SEGMENTS
GROUP BY LTV_SEGMENT
ORDER BY AVG_PREDICTED_LTV DESC;

