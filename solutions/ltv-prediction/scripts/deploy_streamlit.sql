-- LTV PREDICTION: Deploy Streamlit Dashboard
-- Run this AFTER setup.sql has completed successfully.
-- This script uploads the Streamlit app and creates the STREAMLIT object.
/*************************************************************************************************/

USE ROLE ACCOUNTADMIN;
USE DATABASE SF_SOLUTIONS;
USE WAREHOUSE SF_SOLUTIONS_WH;
USE SCHEMA LTV_ML;

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
'    st.caption("Snowflake ML Forecast + Cortex AI Insights")' || CHAR(10) ||
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

-- Show Streamlit URL
SELECT
    'LTV Prediction Dashboard deployed!' AS STATUS,
    'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
        || '/#/streamlit-apps/SF_SOLUTIONS.LTV_ML.LTV_PREDICTION_DASHBOARD' AS STREAMLIT_URL;
