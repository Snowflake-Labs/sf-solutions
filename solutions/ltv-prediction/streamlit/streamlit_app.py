import streamlit as st
import pandas as pd
import plotly.graph_objects as go
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="LTV Prediction Dashboard", layout="wide")


@st.cache_resource
def get_session():
    return get_active_session()


@st.cache_data(ttl=300)
def load_segments(_session):
    return _session.sql("""
        SELECT LTV_SEGMENT,
               COUNT(*)::FLOAT AS CUSTOMER_COUNT,
               AVG(PREDICTED_LTV)::FLOAT AS AVG_PREDICTED_LTV,
               AVG(ACTUAL_LTV)::FLOAT AS AVG_ACTUAL_LTV,
               AVG(TOTAL_SPEND)::FLOAT AS AVG_SPEND,
               AVG(TXN_COUNT)::FLOAT AS AVG_TXNS,
               AVG(MONTHLY_FREQUENCY)::FLOAT AS AVG_FREQUENCY,
               AVG(RECENCY_DAYS)::FLOAT AS AVG_RECENCY,
               AVG(ONLINE_RATIO)::FLOAT AS AVG_ONLINE_RATIO
        FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_SEGMENTS
        GROUP BY LTV_SEGMENT
        ORDER BY AVG_PREDICTED_LTV DESC
    """).to_pandas()


@st.cache_data(ttl=300)
def load_predictions(_session):
    return _session.sql("""
        SELECT PREDICTED_LTV::FLOAT AS PREDICTED_LTV,
               ACTUAL_LTV::FLOAT AS ACTUAL_LTV,
               ABSOLUTE_ERROR::FLOAT AS ABSOLUTE_ERROR,
               TOTAL_SPEND::FLOAT AS TOTAL_SPEND,
               TXN_COUNT::FLOAT AS TXN_COUNT
        FROM SF_SOLUTIONS.LTV_ML.LTV_PREDICTIONS
        LIMIT 5000
    """).to_pandas()


@st.cache_data(ttl=300)
def load_insights(_session):
    return _session.sql("""
        SELECT LTV_SEGMENT,
               CUSTOMER_COUNT::FLOAT AS CUSTOMER_COUNT,
               AVG_PREDICTED_LTV::FLOAT AS AVG_PREDICTED_LTV,
               AVG_SPEND::FLOAT AS AVG_SPEND,
               AI_INSIGHT
        FROM SF_SOLUTIONS.LTV_ML.SEGMENT_INSIGHTS
        ORDER BY AVG_PREDICTED_LTV DESC
    """).to_pandas()


@st.cache_data(ttl=300)
def load_timeseries_all(_session):
    actual = _session.sql("""
        WITH top_customers AS (
            SELECT CUSTOMER_ID::VARCHAR AS CUSTOMER_ID, LTV_SEGMENT,
                   ROW_NUMBER() OVER (PARTITION BY LTV_SEGMENT ORDER BY PREDICTED_LTV DESC) AS RN
            FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_SEGMENTS
        )
        SELECT A.CUSTOMER_ID::VARCHAR AS CUSTOMER_ID,
               A.MONTH::DATE AS MONTH,
               A.MONTHLY_SPEND::FLOAT AS MONTHLY_SPEND,
               S.LTV_SEGMENT
        FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_MONTHLY_SPEND A
        JOIN top_customers S ON A.CUSTOMER_ID::VARCHAR = S.CUSTOMER_ID
        WHERE S.RN <= 5
        ORDER BY A.CUSTOMER_ID, A.MONTH
    """).to_pandas()
    forecast = _session.sql("""
        WITH top_customers AS (
            SELECT CUSTOMER_ID::VARCHAR AS CUSTOMER_ID, LTV_SEGMENT,
                   ROW_NUMBER() OVER (PARTITION BY LTV_SEGMENT ORDER BY PREDICTED_LTV DESC) AS RN
            FROM SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_SEGMENTS
        )
        SELECT F.SERIES::VARCHAR AS CUSTOMER_ID,
               F.TS::DATE AS MONTH,
               F.FORECAST::FLOAT AS MONTHLY_SPEND,
               S.LTV_SEGMENT
        FROM SF_SOLUTIONS.LTV_ML.LTV_FORECAST_RAW F
        JOIN top_customers S ON F.SERIES::VARCHAR = S.CUSTOMER_ID
        WHERE S.RN <= 5
        ORDER BY F.SERIES, F.TS
    """).to_pandas()
    return actual, forecast


def main():
    session = get_session()

    st.title("Customer Lifetime Value Prediction")
    st.caption("Snowflake ML Forecast + Cortex AI Insights")

    segments = load_segments(session)
    predictions = load_predictions(session)

    if segments.empty:
        st.warning("No data found. Run setup.sql first.")
        return

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

    # Segment distribution (using go.Figure to avoid SiS Plotly bug)
    left, right = st.columns(2)

    with left:
        st.subheader("Segment Distribution")
        fig = go.Figure(data=[go.Bar(
            x=segments["LTV_SEGMENT"].tolist(),
            y=segments["CUSTOMER_COUNT"].tolist()
        )])
        fig.update_layout(showlegend=False, height=350, xaxis_title="Segment", yaxis_title="Customer Count")
        st.plotly_chart(fig, use_container_width=True)

    with right:
        st.subheader("Avg Predicted LTV by Segment")
        fig = go.Figure(data=[go.Bar(
            x=segments["LTV_SEGMENT"].tolist(),
            y=segments["AVG_PREDICTED_LTV"].tolist()
        )])
        fig.update_layout(showlegend=False, height=350, xaxis_title="Segment", yaxis_title="Avg Predicted LTV", yaxis_tickprefix="$")
        st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # Predicted vs Actual scatter (using go.Scatter with explicit lists)
    st.subheader("Predicted vs Actual LTV")
    if not predictions.empty:
        fig = go.Figure(data=[go.Scatter(
            x=predictions["ACTUAL_LTV"].tolist(),
            y=predictions["PREDICTED_LTV"].tolist(),
            mode="markers",
            marker=dict(opacity=0.5, size=5)
        )])
        fig.update_layout(height=400, xaxis_title="Actual LTV ($)", yaxis_title="Predicted LTV ($)")
        st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # Time series: actual (solid) vs forecast (dashed) for all customers
    st.subheader("Monthly Spend: Actual vs Forecast")
    actual_ts, forecast_ts = load_timeseries_all(session)

    if not actual_ts.empty:
        fig = go.Figure()
        seg_colors = {"Platinum": "#1f77b4", "Gold": "#ff7f0e", "Silver": "#2ca02c", "Bronze": "#d62728"}
        legend_added = set()

        customer_ids = actual_ts["CUSTOMER_ID"].unique()
        for cid in customer_ids:
            cust_actual = actual_ts[actual_ts["CUSTOMER_ID"] == cid]
            cust_forecast = forecast_ts[forecast_ts["CUSTOMER_ID"] == cid]
            seg = cust_actual["LTV_SEGMENT"].iloc[0] if not cust_actual.empty else "Bronze"
            color = seg_colors.get(seg, "#999999")
            show_legend = seg not in legend_added

            # Actual (solid line)
            fig.add_trace(go.Scatter(
                x=cust_actual["MONTH"].tolist(),
                y=cust_actual["MONTHLY_SPEND"].tolist(),
                mode="lines",
                line=dict(color=color, width=1.5),
                showlegend=show_legend,
                name=f"{seg}",
                legendgroup=seg,
                opacity=0.6
            ))

            # Forecast (dashed line)
            if not cust_forecast.empty:
                if not cust_actual.empty:
                    last_month = cust_actual["MONTH"].iloc[-1]
                    last_spend = cust_actual["MONTHLY_SPEND"].iloc[-1]
                    fx = [last_month] + cust_forecast["MONTH"].tolist()
                    fy = [last_spend] + cust_forecast["MONTHLY_SPEND"].tolist()
                else:
                    fx = cust_forecast["MONTH"].tolist()
                    fy = cust_forecast["MONTHLY_SPEND"].tolist()

                fig.add_trace(go.Scatter(
                    x=fx,
                    y=fy,
                    mode="lines",
                    line=dict(color=color, width=1.5, dash="dash"),
                    showlegend=False,
                    legendgroup=seg,
                    opacity=0.6
                ))

            if show_legend:
                legend_added.add(seg)

        fig.update_layout(
            height=500,
            xaxis_title="Month",
            yaxis_title="Monthly Spend ($)",
            yaxis_tickprefix="$"
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
            with st.expander(f"{row['LTV_SEGMENT']} - {int(row['CUSTOMER_COUNT'])} customers"):
                st.write(row["AI_INSIGHT"])
    else:
        st.info("AI insights not available.")


if __name__ == "__main__":
    main()
