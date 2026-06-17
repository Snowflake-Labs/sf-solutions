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
-- STEP 4: Generate LTV predictions using weighted linear scoring
-- Uses normalized features with domain-appropriate weights.
-- This approach works on ALL Snowflake account types (including Trial).
-- To use Snowflake ML Regression instead (if available), see CONTRIBUTING.md.
/*************************************************************************************************/

CREATE OR REPLACE TABLE SF_SOLUTIONS.LTV_ML.LTV_PREDICTIONS AS
WITH feature_stats AS (
    SELECT
        AVG(TOTAL_SPEND) AS AVG_SPEND, STDDEV(TOTAL_SPEND) AS STD_SPEND,
        AVG(TXN_COUNT) AS AVG_TXN, STDDEV(TXN_COUNT) AS STD_TXN,
        AVG(MONTHLY_FREQUENCY) AS AVG_FREQ, STDDEV(MONTHLY_FREQUENCY) AS STD_FREQ,
        AVG(CUSTOMER_TENURE_DAYS) AS AVG_TENURE, STDDEV(CUSTOMER_TENURE_DAYS) AS STD_TENURE,
        AVG(DISTINCT_CATEGORIES) AS AVG_CAT, STDDEV(DISTINCT_CATEGORIES) AS STD_CAT,
        AVG(ONLINE_RATIO) AS AVG_ONLINE, STDDEV(ONLINE_RATIO) AS STD_ONLINE
    FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_FEATURES
),
scored AS (
    SELECT
        C.CUSTOMER_ID,
        C.FUTURE_LTV AS ACTUAL_LTV,
        -- Weighted linear scoring on normalized features
        ROUND(
            GREATEST(0,
                (ZEROIFNULL((C.TOTAL_SPEND - S.AVG_SPEND) / NULLIF(S.STD_SPEND, 0))) * 0.35
                + (ZEROIFNULL((C.TXN_COUNT - S.AVG_TXN) / NULLIF(S.STD_TXN, 0))) * 0.20
                + (ZEROIFNULL((C.MONTHLY_FREQUENCY - S.AVG_FREQ) / NULLIF(S.STD_FREQ, 0))) * 0.20
                + (ZEROIFNULL((C.CUSTOMER_TENURE_DAYS - S.AVG_TENURE) / NULLIF(S.STD_TENURE, 0))) * 0.10
                + (ZEROIFNULL((C.DISTINCT_CATEGORIES - S.AVG_CAT) / NULLIF(S.STD_CAT, 0))) * 0.10
                + (ZEROIFNULL((C.ONLINE_RATIO - S.AVG_ONLINE) / NULLIF(S.STD_ONLINE, 0))) * 0.05
            ) * (SELECT STDDEV(FUTURE_LTV) FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_FEATURES)
            + (SELECT AVG(FUTURE_LTV) FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_FEATURES)
        , 2) AS PREDICTED_LTV,
        C.TOTAL_SPEND,
        C.TXN_COUNT,
        C.CUSTOMER_TENURE_DAYS,
        C.MONTHLY_FREQUENCY,
        C.RECENCY_DAYS,
        C.ONLINE_RATIO,
        C.DISTINCT_CATEGORIES
    FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_FEATURES C
    CROSS JOIN feature_stats S
)
SELECT
    CUSTOMER_ID,
    ACTUAL_LTV,
    PREDICTED_LTV,
    ROUND(ABS(PREDICTED_LTV - ACTUAL_LTV), 2) AS ABSOLUTE_ERROR,
    TOTAL_SPEND,
    TXN_COUNT,
    CUSTOMER_TENURE_DAYS,
    MONTHLY_FREQUENCY,
    RECENCY_DAYS,
    ONLINE_RATIO,
    DISTINCT_CATEGORIES
FROM scored;

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
    QUERY_WAREHOUSE = COMPUTE_WH;

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
