import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="LTV Prediction Dashboard", layout="wide")

DB = "SF_SOLUTIONS"
SCHEMA_ML = "LTV_ML"
SCHEMA_ANALYTICS = "LTV_ANALYTICS"


@st.cache_resource
def get_session():
    return get_active_session()


@st.cache_data(ttl=300)
def load_segments(_session):
    return _session.sql(f"""
        SELECT LTV_SEGMENT, COUNT(*) AS CUSTOMER_COUNT,
               ROUND(AVG(PREDICTED_LTV), 2) AS AVG_PREDICTED_LTV,
               ROUND(AVG(ACTUAL_LTV), 2) AS AVG_ACTUAL_LTV,
               ROUND(AVG(TOTAL_SPEND), 2) AS AVG_SPEND,
               ROUND(AVG(TXN_COUNT), 1) AS AVG_TXNS,
               ROUND(AVG(MONTHLY_FREQUENCY), 2) AS AVG_FREQUENCY,
               ROUND(AVG(RECENCY_DAYS), 0) AS AVG_RECENCY,
               ROUND(AVG(ONLINE_RATIO), 2) AS AVG_ONLINE_RATIO
        FROM {DB}.{SCHEMA_ANALYTICS}.CUSTOMER_SEGMENTS
        GROUP BY LTV_SEGMENT
        ORDER BY AVG_PREDICTED_LTV DESC
    """).to_pandas()


@st.cache_data(ttl=300)
def load_predictions(_session):
    return _session.sql(f"""
        SELECT PREDICTED_LTV, ACTUAL_LTV, ABSOLUTE_ERROR,
               TOTAL_SPEND, TXN_COUNT, CUSTOMER_TENURE_DAYS,
               MONTHLY_FREQUENCY, RECENCY_DAYS, ONLINE_RATIO
        FROM {DB}.{SCHEMA_ML}.LTV_PREDICTIONS
        LIMIT 5000
    """).to_pandas()


@st.cache_data(ttl=300)
def load_insights(_session):
    return _session.sql(f"""
        SELECT LTV_SEGMENT, CUSTOMER_COUNT, AVG_PREDICTED_LTV, AVG_SPEND, AI_INSIGHT
        FROM {DB}.{SCHEMA_ML}.SEGMENT_INSIGHTS
        ORDER BY AVG_PREDICTED_LTV DESC
    """).to_pandas()


def main():
    session = get_session()

    st.title("Customer Lifetime Value Prediction")
    st.caption("Snowflake ML Forecast + Cortex AI Insights")

    segments = load_segments(session)
    predictions = load_predictions(session)

    if segments.empty:
        st.warning("No data found. Run setup.sql first.")
        return

    # Convert Decimal types to float for Plotly compatibility
    numeric_cols = segments.select_dtypes(include=["object", "number"]).columns
    for col in segments.columns:
        if col != "LTV_SEGMENT":
            segments[col] = pd.to_numeric(segments[col], errors="coerce")
    for col in predictions.columns:
        predictions[col] = pd.to_numeric(predictions[col], errors="coerce")

    # KPI row
    total_customers = int(segments["CUSTOMER_COUNT"].sum())
    avg_ltv = float(segments["AVG_PREDICTED_LTV"].mean())
    platinum_count = int(
        segments.loc[segments["LTV_SEGMENT"] == "Platinum", "CUSTOMER_COUNT"].sum()
    )

    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Total Customers", f"{total_customers:,}")
    col2.metric("Avg Predicted LTV", f"${avg_ltv:,.0f}")
    col3.metric("Platinum Customers", f"{platinum_count:,}")
    col4.metric("Segments", "4")

    st.divider()

    # Segment distribution
    left, right = st.columns(2)

    with left:
        st.subheader("Segment Distribution")
        fig = px.bar(
            segments,
            x="LTV_SEGMENT",
            y="CUSTOMER_COUNT",
            color="LTV_SEGMENT",
            color_discrete_map={
                "Platinum": "#8B5CF6",
                "Gold": "#F59E0B",
                "Silver": "#6B7280",
                "Bronze": "#92400E",
            },
        )
        fig.update_layout(showlegend=False, height=350)
        st.plotly_chart(fig, use_container_width=True)

    with right:
        st.subheader("Avg Predicted LTV by Segment")
        fig = px.bar(
            segments,
            x="LTV_SEGMENT",
            y="AVG_PREDICTED_LTV",
            color="LTV_SEGMENT",
            color_discrete_map={
                "Platinum": "#8B5CF6",
                "Gold": "#F59E0B",
                "Silver": "#6B7280",
                "Bronze": "#92400E",
            },
        )
        fig.update_layout(showlegend=False, height=350, yaxis_tickprefix="$")
        st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # Predicted vs Actual scatter
    st.subheader("Predicted vs Actual LTV")
    if not predictions.empty:
        fig = px.scatter(
            predictions,
            x="ACTUAL_LTV",
            y="PREDICTED_LTV",
            opacity=0.4,
            color_discrete_sequence=["#29B5E8"],
        )
        max_val = max(predictions["ACTUAL_LTV"].max(), predictions["PREDICTED_LTV"].max())
        fig.add_trace(
            go.Scatter(
                x=[0, max_val], y=[0, max_val],
                mode="lines", line=dict(dash="dash", color="gray"),
                name="Perfect",
            )
        )
        fig.update_layout(
            height=400,
            xaxis_title="Actual LTV ($)",
            yaxis_title="Predicted LTV ($)",
        )
        st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # Segment metrics table
    st.subheader("Segment Metrics")
    st.dataframe(
        segments.rename(columns={
            "LTV_SEGMENT": "Segment",
            "CUSTOMER_COUNT": "Customers",
            "AVG_PREDICTED_LTV": "Avg Predicted LTV",
            "AVG_ACTUAL_LTV": "Avg Actual LTV",
            "AVG_SPEND": "Avg Spend",
            "AVG_TXNS": "Avg Txns",
            "AVG_FREQUENCY": "Monthly Freq",
            "AVG_RECENCY": "Recency (days)",
            "AVG_ONLINE_RATIO": "Online %",
        }),
        use_container_width=True,
    )

    st.divider()

    # AI Insights
    st.subheader("AI-Generated Segment Insights")
    insights = load_insights(session)
    if not insights.empty:
        for _, row in insights.iterrows():
            with st.expander(f"{row['LTV_SEGMENT']} — {row['CUSTOMER_COUNT']:,} customers (Avg LTV: ${row['AVG_PREDICTED_LTV']:,.0f})"):
                st.write(row["AI_INSIGHT"])
    else:
        st.info("AI insights not available. Ensure SEGMENT_INSIGHTS table exists.")


if __name__ == "__main__":
    main()
