/*************************************************************************************************/
-- CUSTOMER LIFETIME VALUE PREDICTION SETUP
-- Version: 1.0
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
--   - Customer feature table for ML training
--   - Snowflake ML Regression model for LTV prediction
--   - Customer segments (Platinum/Gold/Silver/Bronze)
/*************************************************************************************************/

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS SF_SOLUTIONS;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.LTV_RAW;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.LTV_ANALYTICS;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.LTV_ML;

CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

USE DATABASE SF_SOLUTIONS;
USE WAREHOUSE COMPUTE_WH;

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
-- STEP 2: Feature engineering — customer-level features
-- Split: first 80% of history for features, last 20% as LTV target
/*************************************************************************************************/

USE SCHEMA LTV_ANALYTICS;

CREATE OR REPLACE TABLE CUSTOMER_FEATURES AS
WITH date_bounds AS (
    SELECT
        MIN(TRANSACTION_TIME) AS FIRST_TXN,
        MAX(TRANSACTION_TIME) AS LAST_TXN,
        DATEADD(
            DAY,
            DATEDIFF(DAY, MIN(TRANSACTION_TIME), MAX(TRANSACTION_TIME)) * 0.8,
            MIN(TRANSACTION_TIME)
        ) AS CUTOFF_DATE
    FROM SF_SOLUTIONS.LTV_RAW.ML_LTV_TRANSACTIONS
),

feature_period AS (
    SELECT T.*
    FROM SF_SOLUTIONS.LTV_RAW.ML_LTV_TRANSACTIONS T
    CROSS JOIN date_bounds D
    WHERE T.TRANSACTION_TIME <= D.CUTOFF_DATE
),

target_period AS (
    SELECT T.*
    FROM SF_SOLUTIONS.LTV_RAW.ML_LTV_TRANSACTIONS T
    CROSS JOIN date_bounds D
    WHERE T.TRANSACTION_TIME > D.CUTOFF_DATE
),

features AS (
    SELECT
        CUSTOMER_ID,
        COUNT(*) AS TXN_COUNT,
        SUM(AMOUNT) AS TOTAL_SPEND,
        AVG(AMOUNT) AS AVG_TXN_AMOUNT,
        STDDEV(AMOUNT) AS STD_TXN_AMOUNT,
        MIN(AMOUNT) AS MIN_TXN_AMOUNT,
        MAX(AMOUNT) AS MAX_TXN_AMOUNT,
        DATEDIFF(
            DAY,
            MIN(TRANSACTION_TIME),
            MAX(TRANSACTION_TIME)
        ) AS CUSTOMER_TENURE_DAYS,
        COUNT(
            DISTINCT DATE_TRUNC('MONTH', TRANSACTION_TIME)
        ) AS ACTIVE_MONTHS,
        COUNT(DISTINCT PRODUCT_CATEGORY) AS DISTINCT_CATEGORIES,
        COUNT_IF(CHANNEL = 'online') AS ONLINE_TXN_COUNT,
        COUNT_IF(CHANNEL = 'store') AS STORE_TXN_COUNT,
        ROUND(
            COUNT_IF(CHANNEL = 'online') * 1.0
            / NULLIF(COUNT(*), 0), 4
        ) AS ONLINE_RATIO,
        DATEDIFF(
            DAY,
            MAX(TRANSACTION_TIME),
            (SELECT CUTOFF_DATE FROM date_bounds)
        ) AS RECENCY_DAYS,
        CASE
            WHEN DATEDIFF(
                DAY,
                MIN(TRANSACTION_TIME),
                MAX(TRANSACTION_TIME)
            ) > 0
            THEN COUNT(*) * 30.0 / DATEDIFF(
                DAY,
                MIN(TRANSACTION_TIME),
                MAX(TRANSACTION_TIME)
            )
            ELSE COUNT(*)
        END AS MONTHLY_FREQUENCY
    FROM feature_period
    GROUP BY CUSTOMER_ID
),

target AS (
    SELECT CUSTOMER_ID, SUM(AMOUNT) AS FUTURE_LTV
    FROM target_period
    GROUP BY CUSTOMER_ID
)

SELECT
    F.*,
    COALESCE(T.FUTURE_LTV, 0) AS FUTURE_LTV
FROM features F
LEFT JOIN target T ON F.CUSTOMER_ID = T.CUSTOMER_ID;

/*************************************************************************************************/
-- STEP 3: Train/test split
/*************************************************************************************************/

CREATE OR REPLACE VIEW TRAIN_DATA AS
SELECT *
FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_FEATURES
WHERE ABS(HASH(CUSTOMER_ID)) % 100 < 80;

CREATE OR REPLACE VIEW TEST_DATA AS
SELECT *
FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_FEATURES
WHERE ABS(HASH(CUSTOMER_ID)) % 100 >= 80;

/*************************************************************************************************/
-- STEP 4: Train Snowflake ML Regression model
/*************************************************************************************************/

CREATE OR REPLACE SNOWFLAKE.ML.REGRESSION LTV_REGRESSION_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'TRAIN_DATA'),
    TARGET_COLNAME => 'FUTURE_LTV',
    CONFIG_OBJECT => {
        'ON_ERROR': 'SKIP'
    }
);

/*************************************************************************************************/
-- STEP 5: Generate predictions on full dataset
/*************************************************************************************************/

CALL LTV_REGRESSION_MODEL!PREDICT(
    INPUT_DATA => SYSTEM$REFERENCE(
        'TABLE', 'SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_FEATURES'
    )
);

CREATE OR REPLACE TABLE SF_SOLUTIONS.LTV_ML.LTV_PREDICTIONS AS
SELECT
    CUSTOMER_ID,
    FUTURE_LTV AS ACTUAL_LTV,
    ROUND(PREDICTED_FUTURE_LTV, 2) AS PREDICTED_LTV,
    ROUND(
        ABS(PREDICTED_FUTURE_LTV - FUTURE_LTV), 2
    ) AS ABSOLUTE_ERROR,
    TOTAL_SPEND,
    TXN_COUNT,
    CUSTOMER_TENURE_DAYS,
    MONTHLY_FREQUENCY,
    RECENCY_DAYS,
    ONLINE_RATIO,
    DISTINCT_CATEGORIES
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

/*************************************************************************************************/
-- STEP 6: Customer segments by predicted LTV
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
-- STEP 7: AI-powered segment insights using Cortex AI Functions
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
