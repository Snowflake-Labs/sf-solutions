----------------------------------------------------------------------
-- Retail Demand Forecasting & Inventory Optimization
-- Step 2: Build demand forecast model using Snowflake ML (Forecasting)
----------------------------------------------------------------------

USE SCHEMA SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_ANALYTICS;

----------------------------------------------------------------------
-- Prepare training data: aggregate to weekly level per store/product
----------------------------------------------------------------------
CREATE OR REPLACE VIEW WEEKLY_DEMAND AS
SELECT
    DATE_TRUNC('WEEK', SALE_DATE)::DATE AS WEEK_START,
    STORE_ID,
    PRODUCT_ID,
    SUM(UNITS_SOLD) AS TOTAL_UNITS,
    SUM(REVENUE) AS TOTAL_REVENUE,
    COUNT(DISTINCT SALE_DATE) AS SELLING_DAYS
FROM SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_RAW.DAILY_SALES
GROUP BY 1, 2, 3;

----------------------------------------------------------------------
-- Build forecasting model (multi-series)
-- Predicts weekly demand for each store-product combination
----------------------------------------------------------------------
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST demand_forecast_model(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'WEEKLY_DEMAND'),
    SERIES_COLNAME => 'STORE_ID || \'-\' || PRODUCT_ID',
    TIMESTAMP_COLNAME => 'WEEK_START',
    TARGET_COLNAME => 'TOTAL_UNITS',
    CONFIG_OBJECT => {
        'ON_ERROR': 'SKIP'
    }
);

----------------------------------------------------------------------
-- Alternative: Build with explicit series column for cleaner usage
----------------------------------------------------------------------
CREATE OR REPLACE VIEW WEEKLY_DEMAND_WITH_SERIES AS
SELECT
    DATE_TRUNC('WEEK', SALE_DATE)::DATE AS WEEK_START,
    STORE_ID || '-' || PRODUCT_ID AS SERIES_ID,
    STORE_ID,
    PRODUCT_ID,
    SUM(UNITS_SOLD) AS TOTAL_UNITS,
    SUM(REVENUE) AS TOTAL_REVENUE
FROM SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_RAW.DAILY_SALES
GROUP BY 1, 2, 3, 4;

CREATE OR REPLACE SNOWFLAKE.ML.FORECAST demand_forecast_model(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'WEEKLY_DEMAND_WITH_SERIES'),
    SERIES_COLNAME => 'SERIES_ID',
    TIMESTAMP_COLNAME => 'WEEK_START',
    TARGET_COLNAME => 'TOTAL_UNITS',
    CONFIG_OBJECT => {
        'ON_ERROR': 'SKIP'
    }
);

----------------------------------------------------------------------
-- Generate 8-week forecast
----------------------------------------------------------------------
CALL demand_forecast_model!FORECAST(
    FORECASTING_PERIODS => 8,
    CONFIG_OBJECT => {
        'prediction_interval': 0.95
    }
);

----------------------------------------------------------------------
-- Store forecast results
----------------------------------------------------------------------
CREATE OR REPLACE TABLE SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_ML.DEMAND_FORECAST AS
SELECT
    SERIES AS SERIES_ID,
    SPLIT_PART(SERIES, '-', 1) AS STORE_ID,
    SPLIT_PART(SERIES, '-', 2) AS PRODUCT_ID,
    TS AS FORECAST_WEEK,
    ROUND(FORECAST, 0) AS FORECASTED_UNITS,
    ROUND(LOWER, 0) AS FORECAST_LOWER_95,
    ROUND(UPPER, 0) AS FORECAST_UPPER_95
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

----------------------------------------------------------------------
-- View model evaluation metrics
----------------------------------------------------------------------
CALL demand_forecast_model!SHOW_EVALUATION_METRICS();

----------------------------------------------------------------------
-- Inspect feature importances
----------------------------------------------------------------------
CALL demand_forecast_model!EXPLAIN_FEATURE_IMPORTANCE();
