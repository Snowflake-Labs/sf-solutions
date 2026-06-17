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
-- STEP 7: Deploy Streamlit Dashboard
/*************************************************************************************************/

CREATE STAGE IF NOT EXISTS SF_SOLUTIONS.LTV_ML.STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE);

-- Upload Streamlit app using CHAR(10) for proper newlines
COPY INTO @SF_SOLUTIONS.LTV_ML.STREAMLIT_STAGE/streamlit_app.py
FROM (
SELECT 'import streamlit as st' || CHAR(10) ||
'import pandas as pd' || CHAR(10) ||
'import plotly.express as px' || CHAR(10) ||
'import plotly.graph_objects as go' || CHAR(10) ||
'from snowflake.snowpark.context import get_active_session' || CHAR(10) ||
CHAR(10) ||
'st.set_page_config(page_title="LTV Prediction Dashboard", layout="wide")' || CHAR(10) ||
CHAR(10) ||
'DB = "SF_SOLUTIONS"' || CHAR(10) ||
'SCHEMA_ML = "LTV_ML"' || CHAR(10) ||
'SCHEMA_ANALYTICS = "LTV_ANALYTICS"' || CHAR(10) ||
CHAR(10) ||
'@st.cache_resource' || CHAR(10) ||
'def get_session():' || CHAR(10) ||
'    return get_active_session()' || CHAR(10) ||
CHAR(10) ||
'@st.cache_data(ttl=300)' || CHAR(10) ||
'def load_segments(_session):' || CHAR(10) ||
'    return _session.sql("SELECT LTV_SEGMENT, COUNT(*) AS CUSTOMER_COUNT, ROUND(AVG(PREDICTED_LTV), 2) AS AVG_PREDICTED_LTV, ROUND(AVG(ACTUAL_LTV), 2) AS AVG_ACTUAL_LTV, ROUND(AVG(TOTAL_SPEND), 2) AS AVG_SPEND, ROUND(AVG(TXN_COUNT), 1) AS AVG_TXNS, ROUND(AVG(MONTHLY_FREQUENCY), 2) AS AVG_FREQUENCY, ROUND(AVG(RECENCY_DAYS), 0) AS AVG_RECENCY, ROUND(AVG(ONLINE_RATIO), 2) AS AVG_ONLINE_RATIO FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_SEGMENTS GROUP BY LTV_SEGMENT ORDER BY AVG_PREDICTED_LTV DESC").to_pandas()' || CHAR(10) ||
CHAR(10) ||
'@st.cache_data(ttl=300)' || CHAR(10) ||
'def load_predictions(_session):' || CHAR(10) ||
'    return _session.sql("SELECT PREDICTED_LTV, ACTUAL_LTV, ABSOLUTE_ERROR, TOTAL_SPEND, TXN_COUNT FROM SF_SOLUTIONS.LTV_ML.LTV_PREDICTIONS LIMIT 5000").to_pandas()' || CHAR(10) ||
CHAR(10) ||
'@st.cache_data(ttl=300)' || CHAR(10) ||
'def load_insights(_session):' || CHAR(10) ||
'    return _session.sql("SELECT LTV_SEGMENT, CUSTOMER_COUNT, AVG_PREDICTED_LTV, AVG_SPEND, AI_INSIGHT FROM SF_SOLUTIONS.LTV_ML.SEGMENT_INSIGHTS ORDER BY AVG_PREDICTED_LTV DESC").to_pandas()' || CHAR(10) ||
CHAR(10) ||
'def main():' || CHAR(10) ||
'    session = get_session()' || CHAR(10) ||
'    st.title("Customer Lifetime Value Prediction")' || CHAR(10) ||
'    st.caption("Snowflake ML Regression + Cortex AI Insights")' || CHAR(10) ||
'    segments = load_segments(session)' || CHAR(10) ||
'    predictions = load_predictions(session)' || CHAR(10) ||
'    if segments.empty:' || CHAR(10) ||
'        st.warning("No data found. Run setup.sql first.")' || CHAR(10) ||
'        return' || CHAR(10) ||
'    total_customers = int(segments["CUSTOMER_COUNT"].sum())' || CHAR(10) ||
'    avg_ltv = float(segments["AVG_PREDICTED_LTV"].mean())' || CHAR(10) ||
'    platinum_count = int(segments.loc[segments["LTV_SEGMENT"] == "Platinum", "CUSTOMER_COUNT"].sum())' || CHAR(10) ||
'    col1, col2, col3, col4 = st.columns(4)' || CHAR(10) ||
'    col1.metric("Total Customers", f"{total_customers:,}")' || CHAR(10) ||
'    col2.metric("Avg Predicted LTV", f"${avg_ltv:,.0f}")' || CHAR(10) ||
'    col3.metric("Platinum Customers", f"{platinum_count:,}")' || CHAR(10) ||
'    col4.metric("Segments", "4")' || CHAR(10) ||
'    st.divider()' || CHAR(10) ||
'    left, right = st.columns(2)' || CHAR(10) ||
'    with left:' || CHAR(10) ||
'        st.subheader("Segment Distribution")' || CHAR(10) ||
'        fig = px.bar(segments, x="LTV_SEGMENT", y="CUSTOMER_COUNT", color="LTV_SEGMENT", color_discrete_map={"Platinum": "#8B5CF6", "Gold": "#F59E0B", "Silver": "#6B7280", "Bronze": "#92400E"})' || CHAR(10) ||
'        fig.update_layout(showlegend=False, height=350)' || CHAR(10) ||
'        st.plotly_chart(fig, use_container_width=True)' || CHAR(10) ||
'    with right:' || CHAR(10) ||
'        st.subheader("Avg Predicted LTV by Segment")' || CHAR(10) ||
'        fig = px.bar(segments, x="LTV_SEGMENT", y="AVG_PREDICTED_LTV", color="LTV_SEGMENT", color_discrete_map={"Platinum": "#8B5CF6", "Gold": "#F59E0B", "Silver": "#6B7280", "Bronze": "#92400E"})' || CHAR(10) ||
'        fig.update_layout(showlegend=False, height=350, yaxis_tickprefix="$")' || CHAR(10) ||
'        st.plotly_chart(fig, use_container_width=True)' || CHAR(10) ||
'    st.divider()' || CHAR(10) ||
'    st.subheader("Predicted vs Actual LTV")' || CHAR(10) ||
'    if not predictions.empty:' || CHAR(10) ||
'        fig = px.scatter(predictions, x="ACTUAL_LTV", y="PREDICTED_LTV", opacity=0.4, color_discrete_sequence=["#29B5E8"])' || CHAR(10) ||
'        max_val = max(predictions["ACTUAL_LTV"].max(), predictions["PREDICTED_LTV"].max())' || CHAR(10) ||
'        fig.add_trace(go.Scatter(x=[0, max_val], y=[0, max_val], mode="lines", line=dict(dash="dash", color="gray"), name="Perfect"))' || CHAR(10) ||
'        fig.update_layout(height=400, xaxis_title="Actual LTV ($)", yaxis_title="Predicted LTV ($)")' || CHAR(10) ||
'        st.plotly_chart(fig, use_container_width=True)' || CHAR(10) ||
'    st.divider()' || CHAR(10) ||
'    st.subheader("Segment Metrics")' || CHAR(10) ||
'    st.dataframe(segments.rename(columns={"LTV_SEGMENT": "Segment", "CUSTOMER_COUNT": "Customers", "AVG_PREDICTED_LTV": "Avg Predicted LTV", "AVG_ACTUAL_LTV": "Avg Actual LTV", "AVG_SPEND": "Avg Spend", "AVG_TXNS": "Avg Txns", "AVG_FREQUENCY": "Monthly Freq", "AVG_RECENCY": "Recency (days)", "AVG_ONLINE_RATIO": "Online %"}), use_container_width=True)' || CHAR(10) ||
'    st.divider()' || CHAR(10) ||
'    st.subheader("AI-Generated Segment Insights")' || CHAR(10) ||
'    insights = load_insights(session)' || CHAR(10) ||
'    if not insights.empty:' || CHAR(10) ||
'        for _, row in insights.iterrows():' || CHAR(10) ||
'            with st.expander(str(row["LTV_SEGMENT"]) + " - " + str(row["CUSTOMER_COUNT"]) + " customers"):' || CHAR(10) ||
'                st.write(row["AI_INSIGHT"])' || CHAR(10) ||
'    else:' || CHAR(10) ||
'        st.info("AI insights not available.")' || CHAR(10) ||
CHAR(10) ||
'if __name__ == "__main__":' || CHAR(10) ||
'    main()' || CHAR(10)
)
FILE_FORMAT = (TYPE = 'CSV' FIELD_DELIMITER = NONE RECORD_DELIMITER = NONE COMPRESSION = NONE FIELD_OPTIONALLY_ENCLOSED_BY = NONE)
OVERWRITE = TRUE
SINGLE = TRUE;

-- Upload environment.yml
COPY INTO @SF_SOLUTIONS.LTV_ML.STREAMLIT_STAGE/environment.yml
FROM (
    SELECT 'name: sf_env' || CHAR(10)
        || 'channels:' || CHAR(10)
        || '  - snowflake' || CHAR(10)
        || 'dependencies:' || CHAR(10)
        || '  - plotly' || CHAR(10)
        || '  - pandas' || CHAR(10)
)
FILE_FORMAT = (TYPE = 'CSV' FIELD_DELIMITER = NONE RECORD_DELIMITER = NONE COMPRESSION = NONE FIELD_OPTIONALLY_ENCLOSED_BY = NONE)
OVERWRITE = TRUE
SINGLE = TRUE;

-- Create Streamlit app
CREATE OR REPLACE STREAMLIT SF_SOLUTIONS.LTV_ML.LTV_PREDICTION_DASHBOARD
    FROM '@SF_SOLUTIONS.LTV_ML.STREAMLIT_STAGE'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = SF_SOLUTIONS_WH;

ALTER STREAMLIT SF_SOLUTIONS.LTV_ML.LTV_PREDICTION_DASHBOARD ADD LIVE VERSION FROM LAST;

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

/*************************************************************************************************/
-- FINAL: Show Streamlit URL
/*************************************************************************************************/

SELECT
    'LTV Prediction Dashboard deployed!' AS STATUS,
    'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
        || '/#/streamlit-apps/SF_SOLUTIONS.LTV_ML.LTV_PREDICTION_DASHBOARD' AS STREAMLIT_URL;
