"""GNN Supply Chain Risk Analysis - Storytelling Dashboard.

Main entry point: "The Illusion of Diversity"
Opens with the compelling business problem - you think you're diversified but you're not.
"""

import math
import sys
from pathlib import Path

import plotly.graph_objects as go
import streamlit as st
from snowflake.snowpark.context import get_active_session

# Add current directory to path for utils import (needed for Streamlit in Snowflake)
sys.path.insert(0, str(Path(__file__).parent))
from utils.data_loader import DB_SCHEMA, run_queries_parallel
from utils.sidebar import render_sidebar, render_star_callout

# Page configuration
st.set_page_config(
    page_title="Supply Chain Risk Intelligence", page_icon=None, layout="wide", initial_sidebar_state="expanded"
)

# Custom CSS for storytelling design
st.markdown(
    """
<style>
    /* Dark theme foundation */
    .stApp {
        background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%);
    }

    /* Hero section */
    .hero-container {
        text-align: center;
        padding: 3rem 2rem;
        margin-bottom: 2rem;
    }
    .hero-title {
        font-size: 3rem;
        font-weight: 800;
        background: linear-gradient(135deg, #f8fafc 0%, #94a3b8 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        margin-bottom: 1rem;
        line-height: 1.2;
    }
    .hero-subtitle {
        font-size: 1.4rem;
        color: #f59e0b;
        font-weight: 600;
        margin-bottom: 1.5rem;
    }
    .hero-description {
        font-size: 1.1rem;
        color: #94a3b8;
        max-width: 800px;
        margin: 0 auto;
        line-height: 1.6;
    }

    /* Section headers */
    .section-header {
        font-size: 1.8rem;
        font-weight: 700;
        color: #f8fafc;
        margin: 2rem 0 1rem 0;
        padding-bottom: 0.5rem;
        border-bottom: 2px solid #334155;
    }
    .section-subheader {
        font-size: 1rem;
        color: #94a3b8;
        margin-bottom: 1.5rem;
    }

    /* Narrative cards */
    .narrative-card {
        background: rgba(30, 41, 59, 0.8);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1.5rem;
        margin: 1rem 0;
    }
    .narrative-card h3 {
        color: #f8fafc;
        font-size: 1.2rem;
        margin-bottom: 0.5rem;
    }
    .narrative-card p {
        color: #94a3b8;
        line-height: 1.6;
    }

    /* Metric cards */
    .metric-row {
        display: flex;
        gap: 1rem;
        margin: 1.5rem 0;
    }
    .metric-card {
        flex: 1;
        background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1.5rem;
        text-align: center;
    }
    .metric-value {
        font-size: 2.5rem;
        font-weight: 800;
        color: #f8fafc;
    }
    .metric-label {
        font-size: 0.9rem;
        color: #64748b;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        margin-top: 0.5rem;
    }
    .metric-critical { color: #dc2626; }
    .metric-warning { color: #f59e0b; }
    .metric-success { color: #10b981; }

    /* Problem statement */
    .problem-box {
        background: linear-gradient(135deg, rgba(220, 38, 38, 0.1) 0%, rgba(234, 88, 12, 0.1) 100%);
        border-left: 4px solid #dc2626;
        border-radius: 0 12px 12px 0;
        padding: 1.5rem 2rem;
        margin: 2rem 0;
    }
    .problem-box h3 {
        color: #dc2626;
        font-size: 1.3rem;
        margin-bottom: 0.5rem;
    }
    .problem-box p {
        color: #e2e8f0;
        line-height: 1.6;
    }

    /* Solution box */
    .solution-box {
        background: linear-gradient(135deg, rgba(16, 185, 129, 0.1) 0%, rgba(59, 130, 246, 0.1) 100%);
        border-left: 4px solid #10b981;
        border-radius: 0 12px 12px 0;
        padding: 1.5rem 2rem;
        margin: 2rem 0;
    }
    .solution-box h3 {
        color: #10b981;
        font-size: 1.3rem;
        margin-bottom: 0.5rem;
    }
    .solution-box p {
        color: #e2e8f0;
        line-height: 1.6;
    }

    /* Discovery callout */
    .discovery-callout {
        background: linear-gradient(135deg, rgba(245, 158, 11, 0.15) 0%, rgba(220, 38, 38, 0.15) 100%);
        border: 2px solid #f59e0b;
        border-radius: 12px;
        padding: 2rem;
        margin: 2rem 0;
        text-align: center;
    }
    .discovery-callout h2 {
        color: #f59e0b;
        font-size: 1.8rem;
        margin-bottom: 1rem;
    }
    .discovery-callout p {
        color: #e2e8f0;
        font-size: 1.1rem;
    }
    .discovery-callout .highlight {
        color: #dc2626;
        font-weight: 700;
    }

    /* CTA buttons */
    .cta-container {
        display: flex;
        gap: 1rem;
        justify-content: center;
        margin: 2rem 0;
    }

    /* Hide default streamlit elements */
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    .stDeployButton {display: none;}

    /* Hide default multipage navigation */
    [data-testid="stSidebarNav"] {display: none;}

    /* Streamlit metric overrides */
    [data-testid="stMetricValue"] {
        font-size: 2rem !important;
    }
</style>
""",
    unsafe_allow_html=True,
)


@st.cache_resource
def get_session():
    """Get Snowflake session."""
    return get_active_session()


@st.cache_data(ttl=300)
def load_key_metrics(_session):
    """Load key risk metrics for the hero section using parallel query execution."""
    # Define all queries for parallel execution (4 queries)
    queries = {
        "total_nodes": f"SELECT COUNT(*) as CNT FROM {DB_SCHEMA}.RISK_SCORES",
        "critical_count": f"SELECT COUNT(*) as CNT FROM {DB_SCHEMA}.RISK_SCORES WHERE RISK_CATEGORY = 'CRITICAL'",
        "bottleneck_count": f"SELECT COUNT(*) as CNT FROM {DB_SCHEMA}.BOTTLENECKS",
        "predicted_links": f"SELECT COUNT(*) as CNT FROM {DB_SCHEMA}.PREDICTED_LINKS",
    }

    # Execute all queries in parallel
    results = run_queries_parallel(_session, queries, max_workers=4)

    # Process results into metrics format
    metrics = {}
    for key in queries:
        df = results.get(key)
        if df is not None and not df.empty:
            metrics[key] = int(df["CNT"].iloc[0])
        else:
            metrics[key] = 0

    return metrics


@st.cache_data(ttl=300)
def load_illusion_data(_session):
    """Load data to demonstrate the 'illusion of diversity'.

    Multiple Tier-1 suppliers that all depend on the same Tier-2 source.
    """
    # Get top bottleneck (the hidden Tier-2 supplier)
    try:
        bottleneck = _session.sql(f"""
            SELECT NODE_ID, DEPENDENT_COUNT, IMPACT_SCORE, DESCRIPTION
            FROM {DB_SCHEMA}.BOTTLENECKS
            ORDER BY DEPENDENT_COUNT DESC
            LIMIT 1
        """).to_pandas()

        if bottleneck.empty:
            return None, [], []

        bottleneck_id = bottleneck["NODE_ID"].iloc[0]

        # Get the vendors that depend on this bottleneck
        dependent_vendors = _session.sql(f"""
            SELECT
                pl.TARGET_NODE_ID as VENDOR_ID,
                v.NAME as VENDOR_NAME,
                v.COUNTRY_CODE,
                pl.PROBABILITY,
                rs.RISK_SCORE
            FROM {DB_SCHEMA}.PREDICTED_LINKS pl
            LEFT JOIN {DB_SCHEMA}.VENDORS v ON pl.TARGET_NODE_ID = v.VENDOR_ID
            LEFT JOIN {DB_SCHEMA}.RISK_SCORES rs ON v.VENDOR_ID = rs.NODE_ID
            WHERE pl.SOURCE_NODE_ID = '{bottleneck_id}'
            ORDER BY pl.PROBABILITY DESC
            LIMIT 10
        """).to_pandas()

        # Build graph data for visualization
        nodes = [
            {
                "id": bottleneck_id,
                "label": bottleneck_id,
                "type": "EXTERNAL_SUPPLIER",
                "risk_score": float(bottleneck["IMPACT_SCORE"].iloc[0]),
                "dependent_count": int(bottleneck["DEPENDENT_COUNT"].iloc[0]),
            }
        ]

        edges = []

        for _, row in dependent_vendors.iterrows():
            nodes.append(
                {
                    "id": row["VENDOR_ID"],
                    "label": row["VENDOR_NAME"] or row["VENDOR_ID"],
                    "type": "SUPPLIER",
                    "country": row["COUNTRY_CODE"],
                    "risk_score": float(row["RISK_SCORE"]) if row["RISK_SCORE"] else 0.5,
                }
            )
            edges.append(
                {
                    "source": bottleneck_id,
                    "target": row["VENDOR_ID"],
                    "predicted": True,
                    "weight": float(row["PROBABILITY"]),
                }
            )

        return bottleneck.iloc[0].to_dict(), nodes, edges

    except Exception:
        return None, [], []


# =============================================================================
# TRADITIONAL BI DATA LOADERS - "Before" Picture
# =============================================================================


@st.cache_data(ttl=300)
def load_vendor_distribution(_session):
    """Load vendor distribution by country and financial health."""
    queries = {
        "geo_dist": f"""
            SELECT
                v.COUNTRY_CODE,
                COALESCE(r.REGION_NAME, v.COUNTRY_CODE) as COUNTRY_NAME,
                COUNT(*) as VENDOR_COUNT,
                AVG(v.FINANCIAL_HEALTH_SCORE) as AVG_HEALTH
            FROM {DB_SCHEMA}.VENDORS v
            LEFT JOIN {DB_SCHEMA}.REGIONS r ON v.COUNTRY_CODE = r.REGION_CODE
            GROUP BY v.COUNTRY_CODE, r.REGION_NAME
            ORDER BY VENDOR_COUNT DESC
        """,
        "health_dist": f"""
            SELECT
                CASE
                    WHEN FINANCIAL_HEALTH_SCORE >= 0.8 THEN 'Excellent (0.8-1.0)'
                    WHEN FINANCIAL_HEALTH_SCORE >= 0.6 THEN 'Good (0.6-0.8)'
                    WHEN FINANCIAL_HEALTH_SCORE >= 0.4 THEN 'Fair (0.4-0.6)'
                    WHEN FINANCIAL_HEALTH_SCORE >= 0.2 THEN 'Poor (0.2-0.4)'
                    ELSE 'Critical (0-0.2)'
                END as HEALTH_BUCKET,
                COUNT(*) as VENDOR_COUNT
            FROM {DB_SCHEMA}.VENDORS
            GROUP BY HEALTH_BUCKET
            ORDER BY MIN(FINANCIAL_HEALTH_SCORE) DESC
        """,
        "summary": f"""
            SELECT
                COUNT(*) as TOTAL_VENDORS,
                COUNT(DISTINCT COUNTRY_CODE) as COUNTRY_COUNT,
                AVG(FINANCIAL_HEALTH_SCORE) as AVG_HEALTH
            FROM {DB_SCHEMA}.VENDORS
        """,
    }
    return run_queries_parallel(_session, queries, max_workers=3)


@st.cache_data(ttl=300)
def load_spend_analysis(_session):
    """Load purchase order spend analysis by vendor."""
    queries = {
        "top_vendors": f"""
            SELECT
                v.VENDOR_ID,
                v.NAME as VENDOR_NAME,
                v.COUNTRY_CODE,
                COUNT(po.PO_ID) as ORDER_COUNT,
                SUM(po.QUANTITY * po.UNIT_PRICE) as TOTAL_SPEND
            FROM {DB_SCHEMA}.PURCHASE_ORDERS po
            JOIN {DB_SCHEMA}.VENDORS v ON po.VENDOR_ID = v.VENDOR_ID
            GROUP BY v.VENDOR_ID, v.NAME, v.COUNTRY_CODE
            ORDER BY TOTAL_SPEND DESC
            LIMIT 15
        """,
        "spend_summary": f"""
            SELECT
                COUNT(DISTINCT VENDOR_ID) as ACTIVE_VENDORS,
                COUNT(*) as TOTAL_ORDERS,
                SUM(QUANTITY * UNIT_PRICE) as TOTAL_SPEND
            FROM {DB_SCHEMA}.PURCHASE_ORDERS
        """,
    }
    return run_queries_parallel(_session, queries, max_workers=2)


@st.cache_data(ttl=300)
def load_material_sourcing(_session):
    """Load material portfolio and sourcing strategy analysis."""
    queries = {
        "material_groups": f"""
            SELECT
                MATERIAL_GROUP,
                COUNT(*) as MATERIAL_COUNT,
                AVG(CRITICALITY_SCORE) as AVG_CRITICALITY
            FROM {DB_SCHEMA}.MATERIALS
            GROUP BY MATERIAL_GROUP
            ORDER BY MATERIAL_COUNT DESC
        """,
        "sourcing_strategy": f"""
            SELECT
                m.MATERIAL_ID,
                m.DESCRIPTION,
                m.CRITICALITY_SCORE,
                COUNT(DISTINCT po.VENDOR_ID) as SUPPLIER_COUNT
            FROM {DB_SCHEMA}.MATERIALS m
            LEFT JOIN {DB_SCHEMA}.PURCHASE_ORDERS po ON m.MATERIAL_ID = po.MATERIAL_ID
            GROUP BY m.MATERIAL_ID, m.DESCRIPTION, m.CRITICALITY_SCORE
        """,
        "sourcing_summary": f"""
            SELECT
                CASE
                    WHEN supplier_count = 0 THEN 'No Suppliers'
                    WHEN supplier_count = 1 THEN 'Single Source'
                    WHEN supplier_count = 2 THEN 'Dual Source'
                    ELSE 'Multi Source (3+)'
                END as SOURCING_TYPE,
                COUNT(*) as MATERIAL_COUNT
            FROM (
                SELECT m.MATERIAL_ID, COUNT(DISTINCT po.VENDOR_ID) as supplier_count
                FROM {DB_SCHEMA}.MATERIALS m
                LEFT JOIN {DB_SCHEMA}.PURCHASE_ORDERS po ON m.MATERIAL_ID = po.MATERIAL_ID
                GROUP BY m.MATERIAL_ID
            )
            GROUP BY SOURCING_TYPE
        """,
    }
    return run_queries_parallel(_session, queries, max_workers=3)


@st.cache_data(ttl=300)
def load_bom_structure(_session):
    """Load bill of materials structure analysis."""
    queries = {
        "bom_stats": f"""
            SELECT
                COUNT(*) as TOTAL_RELATIONSHIPS,
                COUNT(DISTINCT PARENT_MATERIAL_ID) as PARENT_COUNT,
                COUNT(DISTINCT CHILD_MATERIAL_ID) as COMPONENT_COUNT
            FROM {DB_SCHEMA}.BILL_OF_MATERIALS
        """,
        "component_reuse": f"""
            SELECT
                b.CHILD_MATERIAL_ID,
                m.DESCRIPTION,
                COUNT(DISTINCT b.PARENT_MATERIAL_ID) as USED_IN_COUNT
            FROM {DB_SCHEMA}.BILL_OF_MATERIALS b
            JOIN {DB_SCHEMA}.MATERIALS m ON b.CHILD_MATERIAL_ID = m.MATERIAL_ID
            GROUP BY b.CHILD_MATERIAL_ID, m.DESCRIPTION
            HAVING COUNT(DISTINCT b.PARENT_MATERIAL_ID) > 1
            ORDER BY USED_IN_COUNT DESC
            LIMIT 10
        """,
        "depth_analysis": f"""
            WITH RECURSIVE bom_depth AS (
                SELECT PARENT_MATERIAL_ID, CHILD_MATERIAL_ID, 1 as DEPTH
                FROM {DB_SCHEMA}.BILL_OF_MATERIALS
                WHERE PARENT_MATERIAL_ID NOT IN (SELECT CHILD_MATERIAL_ID FROM {DB_SCHEMA}.BILL_OF_MATERIALS)
                UNION ALL
                SELECT b.PARENT_MATERIAL_ID, b.CHILD_MATERIAL_ID, bd.DEPTH + 1
                FROM {DB_SCHEMA}.BILL_OF_MATERIALS b
                JOIN bom_depth bd ON b.PARENT_MATERIAL_ID = bd.CHILD_MATERIAL_ID
                WHERE bd.DEPTH < 10
            )
            SELECT DEPTH, COUNT(*) as RELATIONSHIP_COUNT
            FROM bom_depth
            GROUP BY DEPTH
            ORDER BY DEPTH
        """,
    }
    return run_queries_parallel(_session, queries, max_workers=3)


@st.cache_data(ttl=300)
def load_trade_preview(_session):
    """Load trade data preview for external intelligence."""
    queries = {
        "origin_distribution": f"""
            SELECT
                SHIPPER_COUNTRY,
                COUNT(*) as SHIPMENT_COUNT,
                COUNT(DISTINCT SHIPPER_NAME) as SHIPPER_COUNT,
                SUM(WEIGHT_KG) as TOTAL_WEIGHT_KG
            FROM {DB_SCHEMA}.TRADE_DATA
            WHERE SHIPPER_COUNTRY IS NOT NULL
            GROUP BY SHIPPER_COUNTRY
            ORDER BY SHIPMENT_COUNT DESC
            LIMIT 10
        """,
        "top_shippers": f"""
            SELECT
                SHIPPER_NAME,
                SHIPPER_COUNTRY,
                COUNT(*) as SHIPMENT_COUNT,
                COUNT(DISTINCT CONSIGNEE_NAME) as CUSTOMER_COUNT
            FROM {DB_SCHEMA}.TRADE_DATA
            GROUP BY SHIPPER_NAME, SHIPPER_COUNTRY
            ORDER BY SHIPMENT_COUNT DESC
            LIMIT 10
        """,
        "trade_summary": f"""
            SELECT
                COUNT(*) as TOTAL_SHIPMENTS,
                COUNT(DISTINCT SHIPPER_NAME) as UNIQUE_SHIPPERS,
                COUNT(DISTINCT CONSIGNEE_NAME) as UNIQUE_CONSIGNEES,
                COUNT(DISTINCT SHIPPER_COUNTRY) as ORIGIN_COUNTRIES
            FROM {DB_SCHEMA}.TRADE_DATA
        """,
    }
    return run_queries_parallel(_session, queries, max_workers=3)


@st.cache_data(ttl=300)
def load_region_exposure(_session):
    """Load region risk exposure analysis."""
    queries = {
        "risk_exposure": f"""
            SELECT
                r.REGION_CODE,
                r.REGION_NAME,
                r.BASE_RISK_SCORE,
                r.GEOPOLITICAL_RISK,
                r.NATURAL_DISASTER_RISK,
                COUNT(v.VENDOR_ID) as VENDOR_COUNT
            FROM {DB_SCHEMA}.REGIONS r
            LEFT JOIN {DB_SCHEMA}.VENDORS v ON r.REGION_CODE = v.COUNTRY_CODE
            GROUP BY r.REGION_CODE, r.REGION_NAME, r.BASE_RISK_SCORE,
                     r.GEOPOLITICAL_RISK, r.NATURAL_DISASTER_RISK
            ORDER BY VENDOR_COUNT DESC
        """,
        "risk_buckets": f"""
            SELECT
                CASE
                    WHEN r.BASE_RISK_SCORE >= 0.7 THEN 'High Risk'
                    WHEN r.BASE_RISK_SCORE >= 0.4 THEN 'Medium Risk'
                    ELSE 'Low Risk'
                END as RISK_LEVEL,
                COUNT(DISTINCT v.VENDOR_ID) as VENDOR_COUNT
            FROM {DB_SCHEMA}.VENDORS v
            LEFT JOIN {DB_SCHEMA}.REGIONS r ON v.COUNTRY_CODE = r.REGION_CODE
            GROUP BY RISK_LEVEL
        """,
    }
    return run_queries_parallel(_session, queries, max_workers=2)


# =============================================================================
# TRADITIONAL BI VISUALIZATIONS - "Before" Picture
# =============================================================================

# Color palette - Snowflake brand colors + colorblind-safe accents
# Per SNOWFLAKE_COLOR_SCHEME.md: Use Snowflake Blue as signature brand color
BI_COLORS = {
    "primary": "#29B5E8",  # Snowflake Blue (signature brand color)
    "secondary": "#10b981",  # Green
    "tertiary": "#8b5cf6",  # Purple
    "quaternary": "#f59e0b",  # Amber/Valencia Orange
    "neutral": "#64748b",  # Slate
    "chart_bg": "rgba(30, 41, 59, 0.8)",
}


def render_geo_distribution_chart(geo_data, height=300):
    """Render supplier geographic distribution bar chart."""
    if geo_data is None or geo_data.empty:
        st.info("No vendor geographic data available.")
        return

    fig = go.Figure(
        data=[
            go.Bar(
                x=geo_data["COUNTRY_NAME"],
                y=geo_data["VENDOR_COUNT"],
                marker_color=BI_COLORS["primary"],
                hovertemplate="<b>%{x}</b><br>Vendors: %{y}<extra></extra>",
            )
        ]
    )

    fig.update_layout(
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        height=height,
        margin=dict(l=40, r=20, t=30, b=60),
        xaxis=dict(
            title=None, tickangle=-45, tickfont=dict(color="#94a3b8", size=10), gridcolor="rgba(51, 65, 85, 0.3)"
        ),
        yaxis=dict(
            title="Vendor Count",
            title_font=dict(color="#94a3b8", size=11),
            tickfont=dict(color="#94a3b8"),
            gridcolor="rgba(51, 65, 85, 0.3)",
        ),
    )

    st.plotly_chart(fig, use_container_width=True, key="geo_dist_chart")


def render_health_distribution_chart(health_data, height=280):
    """Render supplier financial health distribution."""
    if health_data is None or health_data.empty:
        st.info("No financial health data available.")
        return

    # Color scale from green (excellent) to blue (critical)
    colors = ["#10b981", "#22c55e", "#eab308", "#f97316", "#3b82f6"]

    fig = go.Figure(
        data=[
            go.Bar(
                x=health_data["HEALTH_BUCKET"],
                y=health_data["VENDOR_COUNT"],
                marker_color=colors[: len(health_data)],
                hovertemplate="<b>%{x}</b><br>Vendors: %{y}<extra></extra>",
            )
        ]
    )

    fig.update_layout(
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        height=height,
        margin=dict(l=40, r=20, t=20, b=80),
        xaxis=dict(
            title=None, tickangle=-30, tickfont=dict(color="#94a3b8", size=9), gridcolor="rgba(51, 65, 85, 0.3)"
        ),
        yaxis=dict(
            title="Count",
            title_font=dict(color="#94a3b8", size=11),
            tickfont=dict(color="#94a3b8"),
            gridcolor="rgba(51, 65, 85, 0.3)",
        ),
    )

    st.plotly_chart(fig, use_container_width=True, key="health_dist_chart")


def render_spend_concentration_chart(spend_data, total_spend, height=320):
    """Render top vendors by spend horizontal bar chart."""
    if spend_data is None or spend_data.empty:
        st.info("No purchase order data available.")
        return

    # Calculate percentage of total
    spend_data = spend_data.copy()
    spend_data["PCT_OF_TOTAL"] = (spend_data["TOTAL_SPEND"] / total_spend * 100) if total_spend > 0 else 0

    # Top 10 only
    top_10 = spend_data.head(10).iloc[::-1]  # Reverse for horizontal bar

    fig = go.Figure(
        data=[
            go.Bar(
                y=top_10["VENDOR_NAME"],
                x=top_10["TOTAL_SPEND"],
                orientation="h",
                marker_color=BI_COLORS["primary"],
                hovertemplate="<b>%{y}</b><br>Spend: $%{x:,.0f}<br>%{customdata:.1f}% of total<extra></extra>",
                customdata=top_10["PCT_OF_TOTAL"],
            )
        ]
    )

    fig.update_layout(
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        height=height,
        margin=dict(l=120, r=20, t=20, b=40),
        xaxis=dict(
            title="Total Spend ($)",
            title_font=dict(color="#94a3b8", size=11),
            tickfont=dict(color="#94a3b8"),
            gridcolor="rgba(51, 65, 85, 0.3)",
            tickformat="$,.0f",
        ),
        yaxis=dict(
            title=None,
            tickfont=dict(color="#e2e8f0", size=10),
        ),
    )

    st.plotly_chart(fig, use_container_width=True, key="spend_chart")


def render_material_portfolio_chart(material_data, height=280):
    """Render material portfolio by group."""
    if material_data is None or material_data.empty:
        st.info("No material data available.")
        return

    # Color mapping for material groups
    group_colors = {
        "RAW": "#3b82f6",  # Blue - raw materials
        "SEMI": "#8b5cf6",  # Purple - semi-finished
        "FIN": "#10b981",  # Green - finished goods
    }

    colors = [group_colors.get(g, BI_COLORS["neutral"]) for g in material_data["MATERIAL_GROUP"]]

    fig = go.Figure(
        data=[
            go.Bar(
                x=material_data["MATERIAL_GROUP"],
                y=material_data["MATERIAL_COUNT"],
                marker_color=colors,
                hovertemplate="<b>%{x}</b><br>Materials: %{y}<br>Avg Criticality: %{customdata:.2f}<extra></extra>",
                customdata=material_data["AVG_CRITICALITY"],
            )
        ]
    )

    fig.update_layout(
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        height=height,
        margin=dict(l=40, r=20, t=20, b=40),
        xaxis=dict(title=None, tickfont=dict(color="#94a3b8", size=11), gridcolor="rgba(51, 65, 85, 0.3)"),
        yaxis=dict(
            title="Material Count",
            title_font=dict(color="#94a3b8", size=11),
            tickfont=dict(color="#94a3b8"),
            gridcolor="rgba(51, 65, 85, 0.3)",
        ),
    )

    st.plotly_chart(fig, use_container_width=True, key="material_portfolio_chart")


def render_sourcing_strategy_chart(sourcing_data, height=280):
    """Render sourcing strategy distribution (single vs multi-source)."""
    if sourcing_data is None or sourcing_data.empty:
        st.info("No sourcing data available.")
        return

    # Order for display
    order = ["Multi Source (3+)", "Dual Source", "Single Source", "No Suppliers"]
    sourcing_data = sourcing_data.copy()
    sourcing_data["ORDER"] = sourcing_data["SOURCING_TYPE"].apply(lambda x: order.index(x) if x in order else 99)
    sourcing_data = sourcing_data.sort_values("ORDER")

    # Colors: green for multi, amber for single, blue for none
    color_map = {
        "Multi Source (3+)": "#10b981",
        "Dual Source": "#22c55e",
        "Single Source": "#f59e0b",
        "No Suppliers": "#64748b",
    }
    colors = [color_map.get(t, BI_COLORS["neutral"]) for t in sourcing_data["SOURCING_TYPE"]]

    fig = go.Figure(
        data=[
            go.Bar(
                x=sourcing_data["SOURCING_TYPE"],
                y=sourcing_data["MATERIAL_COUNT"],
                marker_color=colors,
                hovertemplate="<b>%{x}</b><br>Materials: %{y}<extra></extra>",
            )
        ]
    )

    fig.update_layout(
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        height=height,
        margin=dict(l=40, r=20, t=20, b=60),
        xaxis=dict(
            title=None, tickangle=-20, tickfont=dict(color="#94a3b8", size=10), gridcolor="rgba(51, 65, 85, 0.3)"
        ),
        yaxis=dict(
            title="Materials",
            title_font=dict(color="#94a3b8", size=11),
            tickfont=dict(color="#94a3b8"),
            gridcolor="rgba(51, 65, 85, 0.3)",
        ),
    )

    st.plotly_chart(fig, use_container_width=True, key="sourcing_strategy_chart")


def render_criticality_scatter(sourcing_detail, height=300):
    """Render criticality vs supplier count scatter plot."""
    if sourcing_detail is None or sourcing_detail.empty:
        st.info("No sourcing detail data available.")
        return

    # Color by supplier count (single source = amber warning)
    colors = ["#f59e0b" if c <= 1 else "#10b981" for c in sourcing_detail["SUPPLIER_COUNT"]]

    fig = go.Figure(
        data=[
            go.Scatter(
                x=sourcing_detail["SUPPLIER_COUNT"],
                y=sourcing_detail["CRITICALITY_SCORE"],
                mode="markers",
                marker=dict(size=8, color=colors, opacity=0.7, line=dict(width=1, color="#0f172a")),
                hovertemplate="<b>%{customdata}</b><br>Suppliers: %{x}<br>Criticality: %{y:.2f}<extra></extra>",
                customdata=sourcing_detail["DESCRIPTION"],
            )
        ]
    )

    # Add danger zone annotation
    fig.add_annotation(
        x=0.5,
        y=0.85,
        text="High Risk Zone",
        showarrow=False,
        font=dict(color="#f59e0b", size=10),
        xref="paper",
        yref="paper",
    )

    fig.update_layout(
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        height=height,
        margin=dict(l=50, r=20, t=30, b=50),
        xaxis=dict(
            title="Number of Suppliers",
            title_font=dict(color="#94a3b8", size=11),
            tickfont=dict(color="#94a3b8"),
            gridcolor="rgba(51, 65, 85, 0.3)",
            dtick=1,
        ),
        yaxis=dict(
            title="Criticality Score",
            title_font=dict(color="#94a3b8", size=11),
            tickfont=dict(color="#94a3b8"),
            gridcolor="rgba(51, 65, 85, 0.3)",
            range=[0, 1.05],
        ),
    )

    st.plotly_chart(fig, use_container_width=True, key="criticality_scatter")


def render_bom_depth_chart(depth_data, height=250):
    """Render BOM depth distribution chart."""
    if depth_data is None or depth_data.empty:
        st.info("No BOM depth data available.")
        return

    fig = go.Figure(
        data=[
            go.Bar(
                x=[f"Level {d}" for d in depth_data["DEPTH"]],
                y=depth_data["RELATIONSHIP_COUNT"],
                marker_color=BI_COLORS["tertiary"],
                hovertemplate="<b>%{x}</b><br>Relationships: %{y}<extra></extra>",
            )
        ]
    )

    fig.update_layout(
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        height=height,
        margin=dict(l=40, r=20, t=20, b=40),
        xaxis=dict(title=None, tickfont=dict(color="#94a3b8", size=10), gridcolor="rgba(51, 65, 85, 0.3)"),
        yaxis=dict(
            title="Relationships",
            title_font=dict(color="#94a3b8", size=11),
            tickfont=dict(color="#94a3b8"),
            gridcolor="rgba(51, 65, 85, 0.3)",
        ),
    )

    st.plotly_chart(fig, use_container_width=True, key="bom_depth_chart")


def render_component_reuse_chart(reuse_data, height=280):
    """Render top reused components chart."""
    if reuse_data is None or reuse_data.empty:
        st.info("No component reuse data available.")
        return

    # Top 8 most reused
    top_reuse = reuse_data.head(8).iloc[::-1]

    fig = go.Figure(
        data=[
            go.Bar(
                y=top_reuse["DESCRIPTION"].str[:30],  # Truncate long names
                x=top_reuse["USED_IN_COUNT"],
                orientation="h",
                marker_color=BI_COLORS["tertiary"],
                hovertemplate="<b>%{customdata}</b><br>Used in %{x} assemblies<extra></extra>",
                customdata=top_reuse["DESCRIPTION"],
            )
        ]
    )

    fig.update_layout(
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        height=height,
        margin=dict(l=150, r=20, t=20, b=40),
        xaxis=dict(
            title="Used In # Assemblies",
            title_font=dict(color="#94a3b8", size=11),
            tickfont=dict(color="#94a3b8"),
            gridcolor="rgba(51, 65, 85, 0.3)",
        ),
        yaxis=dict(
            title=None,
            tickfont=dict(color="#e2e8f0", size=9),
        ),
    )

    st.plotly_chart(fig, use_container_width=True, key="component_reuse_chart")


def render_trade_origin_chart(origin_data, height=280):
    """Render trade data origin country distribution."""
    if origin_data is None or origin_data.empty:
        st.info("No trade origin data available.")
        return

    fig = go.Figure(
        data=[
            go.Bar(
                x=origin_data["SHIPPER_COUNTRY"],
                y=origin_data["SHIPMENT_COUNT"],
                marker_color=BI_COLORS["quaternary"],
                hovertemplate="<b>%{x}</b><br>Shipments: %{y}<br>Shippers: %{customdata}<extra></extra>",
                customdata=origin_data["SHIPPER_COUNT"],
            )
        ]
    )

    fig.update_layout(
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        height=height,
        margin=dict(l=40, r=20, t=20, b=50),
        xaxis=dict(
            title=None, tickangle=-30, tickfont=dict(color="#94a3b8", size=10), gridcolor="rgba(51, 65, 85, 0.3)"
        ),
        yaxis=dict(
            title="Shipments",
            title_font=dict(color="#94a3b8", size=11),
            tickfont=dict(color="#94a3b8"),
            gridcolor="rgba(51, 65, 85, 0.3)",
        ),
    )

    st.plotly_chart(fig, use_container_width=True, key="trade_origin_chart")


def render_top_shippers_chart(shipper_data, height=280):
    """Render top external shippers chart."""
    if shipper_data is None or shipper_data.empty:
        st.info("No shipper data available.")
        return

    top_shippers = shipper_data.head(8).iloc[::-1]

    fig = go.Figure(
        data=[
            go.Bar(
                y=top_shippers["SHIPPER_NAME"].str[:25],
                x=top_shippers["SHIPMENT_COUNT"],
                orientation="h",
                marker_color=BI_COLORS["quaternary"],
                hovertemplate="<b>%{customdata[0]}</b><br>Country: %{customdata[1]}<br>Shipments: %{x}<extra></extra>",
                customdata=list(zip(top_shippers["SHIPPER_NAME"], top_shippers["SHIPPER_COUNTRY"])),
            )
        ]
    )

    fig.update_layout(
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        height=height,
        margin=dict(l=140, r=20, t=20, b=40),
        xaxis=dict(
            title="Shipments",
            title_font=dict(color="#94a3b8", size=11),
            tickfont=dict(color="#94a3b8"),
            gridcolor="rgba(51, 65, 85, 0.3)",
        ),
        yaxis=dict(
            title=None,
            tickfont=dict(color="#e2e8f0", size=9),
        ),
    )

    st.plotly_chart(fig, use_container_width=True, key="top_shippers_chart")


def render_region_risk_chart(risk_data, height=280):
    """Render supplier exposure by region risk level."""
    if risk_data is None or risk_data.empty:
        st.info("No region risk data available.")
        return

    # Order by risk level
    order = {"High Risk": 0, "Medium Risk": 1, "Low Risk": 2}
    risk_data = risk_data.copy()
    risk_data["ORDER"] = risk_data["RISK_LEVEL"].apply(lambda x: order.get(x, 99))
    risk_data = risk_data.sort_values("ORDER")

    color_map = {"High Risk": "#f59e0b", "Medium Risk": "#3b82f6", "Low Risk": "#10b981"}
    colors = [color_map.get(r, BI_COLORS["neutral"]) for r in risk_data["RISK_LEVEL"]]

    fig = go.Figure(
        data=[
            go.Bar(
                x=risk_data["RISK_LEVEL"],
                y=risk_data["VENDOR_COUNT"],
                marker_color=colors,
                hovertemplate="<b>%{x}</b><br>Vendors: %{y}<extra></extra>",
            )
        ]
    )

    fig.update_layout(
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        height=height,
        margin=dict(l=40, r=20, t=20, b=40),
        xaxis=dict(title=None, tickfont=dict(color="#94a3b8", size=11), gridcolor="rgba(51, 65, 85, 0.3)"),
        yaxis=dict(
            title="Vendor Count",
            title_font=dict(color="#94a3b8", size=11),
            tickfont=dict(color="#94a3b8"),
            gridcolor="rgba(51, 65, 85, 0.3)",
        ),
    )

    st.plotly_chart(fig, use_container_width=True, key="region_risk_chart")


def render_illusion_graph(nodes, edges, height=500):
    """Render the 'illusion of diversity' graph showing hidden convergence using Plotly."""
    if not nodes or len(nodes) < 2:
        st.info("No concentration data available for visualization.")
        return

    # Find center node (the bottleneck) and outer nodes
    center_node = next((n for n in nodes if n.get("type") == "EXTERNAL_SUPPLIER"), None)
    outer_nodes = [n for n in nodes if n.get("type") != "EXTERNAL_SUPPLIER"]

    if not center_node or not outer_nodes:
        st.info("Insufficient data for visualization.")
        return

    # Calculate positions in radial layout
    center_x, center_y = 0, 0
    radius = 2.5
    num_outer = len(outer_nodes)

    outer_x = []
    outer_y = []
    outer_text = []

    for i, node in enumerate(outer_nodes):
        angle = (2 * math.pi * i / num_outer) - (math.pi / 2)
        x = center_x + radius * math.cos(angle)
        y = center_y + radius * math.sin(angle)
        outer_x.append(x)
        outer_y.append(y)

        label = node.get("label", node.get("id", "Unknown"))
        country = node.get("country", "")
        outer_text.append(f"<b>{label}</b><br>Country: {country}")

    # Create edge traces
    edge_x = []
    edge_y = []
    for i in range(len(outer_nodes)):
        edge_x.extend([center_x, outer_x[i], None])
        edge_y.extend([center_y, outer_y[i], None])

    edge_trace = go.Scatter(
        x=edge_x,
        y=edge_y,
        mode="lines",
        line=dict(width=2, color="#f59e0b", dash="dash"),
        hoverinfo="none",
        showlegend=False,
    )

    # Center node (bottleneck)
    dependent_count = center_node.get("dependent_count", len(outer_nodes))
    center_label = center_node.get("label", center_node.get("id", "Unknown"))

    center_trace = go.Scatter(
        x=[center_x],
        y=[center_y],
        mode="markers+text",
        marker=dict(size=55, color="#dc2626", line=dict(width=3, color="#0f172a")),
        text=[str(dependent_count)],
        textposition="middle center",
        textfont=dict(size=16, color="white", family="Arial Black"),
        hovertext=f"<b>{center_label}</b><br>Tier-2 Supplier<br>Dependents: {dependent_count}",
        hoverinfo="text",
        name="Hidden Tier-2 Supplier",
        showlegend=True,
    )

    # Center node label below
    center_label_trace = go.Scatter(
        x=[center_x],
        y=[center_y - 0.7],
        mode="text",
        text=[center_label[:25] if len(center_label) > 25 else center_label],
        textfont=dict(size=12, color="#f8fafc", family="Arial"),
        hoverinfo="none",
        showlegend=False,
    )

    # Outer nodes (Tier-1 suppliers)
    outer_trace = go.Scatter(
        x=outer_x,
        y=outer_y,
        mode="markers",
        marker=dict(size=30, color="#3b82f6", line=dict(width=2, color="#0f172a")),
        hovertext=outer_text,
        hoverinfo="text",
        name="Your Tier-1 Suppliers",
        showlegend=True,
    )

    # Labels for outer nodes
    label_y = [y - 0.5 for y in outer_y]
    outer_labels = [str(n.get("label", n.get("id", "")))[:15] for n in outer_nodes]

    label_trace = go.Scatter(
        x=outer_x,
        y=label_y,
        mode="text",
        text=outer_labels,
        textfont=dict(size=10, color="#e2e8f0"),
        hoverinfo="none",
        showlegend=False,
    )

    fig = go.Figure(
        data=[edge_trace, outer_trace, center_trace, center_label_trace, label_trace],
        layout=go.Layout(
            showlegend=True,
            hovermode="closest",
            paper_bgcolor="rgba(0,0,0,0)",
            plot_bgcolor="rgba(0,0,0,0)",
            height=height,
            margin=dict(b=20, l=20, r=20, t=20),
            legend=dict(
                x=0.01,
                y=0.99,
                bgcolor="rgba(30, 41, 59, 0.9)",
                bordercolor="#334155",
                borderwidth=1,
                font=dict(color="#e2e8f0", size=11),
            ),
            xaxis=dict(showgrid=False, zeroline=False, showticklabels=False, range=[-4, 4]),
            yaxis=dict(showgrid=False, zeroline=False, showticklabels=False, range=[-4, 4]),
        ),
    )

    st.plotly_chart(fig, use_container_width=True, key="illusion_graph")


def main():
    """Main application - The Storytelling Home Page."""
    session = get_session()

    # Render STAR callout if demo mode is enabled
    render_star_callout("home")

    # Load data
    metrics = load_key_metrics(session)
    bottleneck, nodes, edges = load_illusion_data(session)

    # Load Traditional BI data (the "before" picture)
    vendor_data = load_vendor_distribution(session)
    spend_data = load_spend_analysis(session)
    material_data = load_material_sourcing(session)
    bom_data = load_bom_structure(session)
    trade_data = load_trade_preview(session)
    region_data = load_region_exposure(session)

    # ============================================
    # HERO SECTION
    # ============================================
    st.markdown(
        """
    <div class="hero-container">
        <div class="hero-title">Supply Chain Risk Intelligence</div>
        <div class="hero-subtitle">N-Tier Visibility & Concentration Risk Analysis</div>
        <div class="hero-description">
            AI-powered analysis of multi-tier supplier dependencies using graph neural networks.
            Identify concentration risks and Tier-2+ supplier relationships that traditional
            analytics cannot detect.
        </div>
    </div>
    """,
        unsafe_allow_html=True,
    )

    # ============================================
    # KEY METRICS
    # ============================================
    col1, col2, col3, col4 = st.columns(4)

    with col1:
        st.metric(
            label="Nodes Analyzed",
            value=f"{metrics['total_nodes']:,}",
            help="Suppliers, Parts, and External entities in the risk model",
        )

    with col2:
        st.metric(
            label="Critical Risks", value=f"{metrics['critical_count']}", delta="Requires action", delta_color="inverse"
        )

    with col3:
        st.metric(
            label="Bottlenecks Found", value=f"{metrics['bottleneck_count']}", help="Hidden single points of failure"
        )

    with col4:
        st.metric(
            label="Hidden Links Discovered",
            value=f"{metrics['predicted_links']:,}",
            help="Tier-2+ relationships predicted by GNN",
        )

    # Show notebook link if no risk scores yet
    if metrics["total_nodes"] == 0:
        st.markdown(
            """
        <div style="background: linear-gradient(135deg, #1e3a5f 0%, #0f172a 100%);
                    border: 1px solid #3b82f6; border-radius: 12px; padding: 1.5rem;
                    margin: 1rem 0; text-align: center;">
            <div style="font-size: 1.2rem; color: #f8fafc; margin-bottom: 0.5rem;">
                <strong>Run the GNN Analysis</strong>
            </div>
            <div style="color: #94a3b8; margin-bottom: 1rem;">
                Execute the notebook to generate risk scores, discover hidden dependencies, and identify bottlenecks.
            </div>
            <a href="../notebooks/SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.GNN_SUPPLY_CHAIN_RISK_NOTEBOOK"
               target="_blank"
               style="display: inline-block; background: #3b82f6; color: white;
                      padding: 0.75rem 2rem; border-radius: 8px; text-decoration: none;
                      font-weight: 600; transition: background 0.2s;">
                Open GNN Notebook →
            </a>
        </div>
        """,
            unsafe_allow_html=True,
        )

    st.divider()

    # ============================================
    # TRADITIONAL BI VIEW - "What Your ERP Tells You"
    # ============================================
    st.markdown(
        """
    <div class="section-header">What Your ERP Tells You</div>
    <div class="section-subheader">
        Traditional BI reports show a diversified supply base — but this view is incomplete
    </div>
    """,
        unsafe_allow_html=True,
    )

    # Extract summary statistics for narrative
    vendor_summary = vendor_data.get("summary")
    spend_summary = spend_data.get("spend_summary")
    trade_summary = trade_data.get("trade_summary")

    total_vendors = (
        int(vendor_summary["TOTAL_VENDORS"].iloc[0]) if vendor_summary is not None and not vendor_summary.empty else 0
    )
    country_count = (
        int(vendor_summary["COUNTRY_COUNT"].iloc[0]) if vendor_summary is not None and not vendor_summary.empty else 0
    )
    avg_health = (
        float(vendor_summary["AVG_HEALTH"].iloc[0]) if vendor_summary is not None and not vendor_summary.empty else 0
    )
    total_spend = (
        float(spend_summary["TOTAL_SPEND"].iloc[0]) if spend_summary is not None and not spend_summary.empty else 0
    )

    # Summary metrics row
    bi_col1, bi_col2, bi_col3, bi_col4 = st.columns(4)
    with bi_col1:
        st.metric("Tier-1 Suppliers", f"{total_vendors:,}", help="Direct suppliers in your ERP")
    with bi_col2:
        st.metric("Countries", f"{country_count}", help="Geographic footprint")
    with bi_col3:
        st.metric("Avg Health Score", f"{avg_health:.0%}", help="Average financial health")
    with bi_col4:
        st.metric(
            "Total PO Spend",
            f"${total_spend / 1e6:.1f}M" if total_spend > 1e6 else f"${total_spend:,.0f}",
            help="Purchase order value",
        )

    # Subsection 1: Supplier Portfolio
    with st.expander("Supplier Portfolio Analysis", expanded=True):
        st.markdown(
            """
        <p style="color: #94a3b8; margin-bottom: 1rem;">
            Your ERP shows supplier distribution by geography, financial health, and spend concentration.
        </p>
        """,
            unsafe_allow_html=True,
        )

        sp_col1, sp_col2 = st.columns(2)
        with sp_col1:
            st.markdown("**Geographic Distribution**")
            geo_data = vendor_data.get("geo_dist")
            render_geo_distribution_chart(geo_data, height=280)

        with sp_col2:
            st.markdown("**Financial Health Distribution**")
            health_data = vendor_data.get("health_dist")
            render_health_distribution_chart(health_data, height=280)

        st.markdown("**Top Suppliers by Spend**")
        top_vendors = spend_data.get("top_vendors")
        render_spend_concentration_chart(top_vendors, total_spend, height=320)

        # Calculate concentration metric
        if top_vendors is not None and not top_vendors.empty and total_spend > 0:
            top_10_spend = top_vendors.head(10)["TOTAL_SPEND"].sum()
            concentration_pct = (top_10_spend / total_spend) * 100
            st.caption(f"Top 10 suppliers account for {concentration_pct:.1f}% of total spend")

    # Subsection 2: Materials & Sourcing
    with st.expander("Materials & Sourcing Strategy", expanded=True):
        st.markdown(
            """
        <p style="color: #94a3b8; margin-bottom: 1rem;">
            Material portfolio breakdown and sourcing strategy metrics from purchase order data.
        </p>
        """,
            unsafe_allow_html=True,
        )

        mat_col1, mat_col2 = st.columns(2)
        with mat_col1:
            st.markdown("**Material Portfolio by Type**")
            mat_groups = material_data.get("material_groups")
            render_material_portfolio_chart(mat_groups, height=280)

        with mat_col2:
            st.markdown("**Sourcing Strategy**")
            sourcing_summary = material_data.get("sourcing_summary")
            render_sourcing_strategy_chart(sourcing_summary, height=280)

        st.markdown("**Material Criticality vs Supplier Count**")
        sourcing_detail = material_data.get("sourcing_strategy")
        render_criticality_scatter(sourcing_detail, height=300)
        st.caption("Amber dots = single-sourced materials (higher risk). Green dots = multi-sourced.")

    # Subsection 3: BOM Structure
    with st.expander("Bill of Materials Structure", expanded=False):
        st.markdown(
            """
        <p style="color: #94a3b8; margin-bottom: 1rem;">
            Product structure hierarchy and component reuse patterns.
        </p>
        """,
            unsafe_allow_html=True,
        )

        bom_stats = bom_data.get("bom_stats")
        if bom_stats is not None and not bom_stats.empty:
            bom_col1, bom_col2, bom_col3 = st.columns(3)
            with bom_col1:
                st.metric("BOM Relationships", f"{int(bom_stats['TOTAL_RELATIONSHIPS'].iloc[0]):,}")
            with bom_col2:
                st.metric("Parent Assemblies", f"{int(bom_stats['PARENT_COUNT'].iloc[0]):,}")
            with bom_col3:
                st.metric("Component Parts", f"{int(bom_stats['COMPONENT_COUNT'].iloc[0]):,}")

        bom_col1, bom_col2 = st.columns(2)
        with bom_col1:
            st.markdown("**BOM Depth Distribution**")
            depth_data = bom_data.get("depth_analysis")
            render_bom_depth_chart(depth_data, height=250)

        with bom_col2:
            st.markdown("**Most Reused Components**")
            reuse_data = bom_data.get("component_reuse")
            render_component_reuse_chart(reuse_data, height=250)

    # Subsection 4: Trade Intelligence Preview
    with st.expander("External Trade Intelligence", expanded=False):
        st.markdown(
            """
        <p style="color: #94a3b8; margin-bottom: 1rem;">
            Shipping and trade data reveals external entities supplying
            your vendors — potential hidden Tier-2 suppliers.
        </p>
        """,
            unsafe_allow_html=True,
        )

        if trade_summary is not None and not trade_summary.empty:
            trade_col1, trade_col2, trade_col3 = st.columns(3)
            with trade_col1:
                st.metric("Trade Records", f"{int(trade_summary['TOTAL_SHIPMENTS'].iloc[0]):,}")
            with trade_col2:
                st.metric("Unique Shippers", f"{int(trade_summary['UNIQUE_SHIPPERS'].iloc[0]):,}")
            with trade_col3:
                st.metric("Origin Countries", f"{int(trade_summary['ORIGIN_COUNTRIES'].iloc[0]):,}")

        tr_col1, tr_col2 = st.columns(2)
        with tr_col1:
            st.markdown("**Shipments by Origin Country**")
            origin_data = trade_data.get("origin_distribution")
            render_trade_origin_chart(origin_data, height=280)

        with tr_col2:
            st.markdown("**Top External Shippers**")
            shipper_data = trade_data.get("top_shippers")
            render_top_shippers_chart(shipper_data, height=280)

        st.markdown("**Supplier Exposure by Region Risk**")
        risk_buckets = region_data.get("risk_buckets")
        render_region_risk_chart(risk_buckets, height=250)

    # Transition callout - "What BI Cannot See"
    st.markdown(
        """
    <div style="background: linear-gradient(135deg, rgba(59, 130, 246, 0.1) 0%, rgba(139, 92, 246, 0.1) 100%);
                border: 1px solid #3b82f6;
                border-radius: 12px;
                padding: 1.5rem 2rem;
                margin: 2rem 0;
                text-align: center;">
        <h3 style="color: #3b82f6; margin-bottom: 0.5rem;">What Traditional BI Cannot See</h3>
        <p style="color: #e2e8f0;">
            These reports show <strong>Tier-1 relationships only</strong>. Your ERP doesn't track who supplies
            your suppliers. Multiple Tier-1 vendors may depend on the same hidden Tier-2 source —
            creating concentration risk that standard analytics miss.
        </p>
        <p style="color: #94a3b8; margin-top: 0.5rem; font-size: 0.9rem;">
            The GNN analysis below reveals these hidden dependencies.
        </p>
    </div>
    """,
        unsafe_allow_html=True,
    )

    st.divider()

    # ============================================
    # OVERVIEW
    # ============================================
    st.markdown(
        """
    <div class="section-header">Risk Overview</div>
    """,
        unsafe_allow_html=True,
    )

    col1, col2 = st.columns([1, 1])

    with col1:
        st.markdown(
            """
        <div class="problem-box">
            <h3>Concentration Risk</h3>
            <p>
                ERP systems show direct Tier-1 supplier relationships, but lack visibility into
                upstream dependencies. Multiple Tier-1 suppliers may share common Tier-2+ sources,
                creating hidden concentration risks.
            </p>
            <p style="margin-top: 1rem; color: #94a3b8;">
                This analysis identifies convergence points in your extended supply network.
            </p>
        </div>
        """,
            unsafe_allow_html=True,
        )

    with col2:
        st.markdown(
            """
        <div class="solution-box">
            <h3>Analysis Approach</h3>
            <p>
                The system combines internal ERP data with external trade intelligence to build
                a multi-tier supply network graph. Machine learning models infer likely Tier-2+
                relationships and calculate propagated risk scores.
            </p>
            <p style="margin-top: 1rem; color: #94a3b8;">
                Risk scores reflect both direct and indirect supplier dependencies.
            </p>
        </div>
        """,
            unsafe_allow_html=True,
        )

    st.divider()

    # ============================================
    # TOP CONCENTRATION RISK
    # ============================================
    st.markdown(
        """
    <div class="section-header">Top Concentration Risk</div>
    <div class="section-subheader">Highest-impact Tier-2 dependency identified</div>
    """,
        unsafe_allow_html=True,
    )

    if bottleneck and len(nodes) > 1:
        # Show the concentration risk callout
        st.markdown(
            f"""
        <div class="discovery-callout">
            <h2>Concentration Alert</h2>
            <p>
                <span class="highlight">{bottleneck["NODE_ID"]}</span> — Tier-2 supplier with
                <span class="highlight">{bottleneck["DEPENDENT_COUNT"]}</span> dependent Tier-1 vendors
            </p>
            <p style="margin-top: 0.5rem; color: #94a3b8;">
                Impact Score: {bottleneck["IMPACT_SCORE"]:.0%} ·
                {bottleneck.get("DESCRIPTION", "Supply chain convergence point")}
            </p>
        </div>
        """,
            unsafe_allow_html=True,
        )

        # Render the visualization
        render_illusion_graph(nodes, edges, height=450)

        st.markdown(
            """
        <p style="text-align: center; color: #64748b; font-size: 0.9rem; margin-top: 1rem;">
            <strong>Blue nodes:</strong> Your Tier-1 suppliers (visible in your ERP) &nbsp;|&nbsp;
            <strong>Red node:</strong> Hidden Tier-2 supplier (discovered by GNN) &nbsp;|&nbsp;
            <strong>Dashed lines:</strong> Predicted dependencies
        </p>
        """,
            unsafe_allow_html=True,
        )
    else:
        st.info("Run the GNN notebook to discover hidden dependencies in your supply chain data.")

    st.divider()

    # ============================================
    # KEY CAPABILITIES
    # ============================================
    st.markdown(
        """
    <div class="section-header">Key Capabilities</div>
    """,
        unsafe_allow_html=True,
    )

    col1, col2, col3 = st.columns(3)

    with col1:
        st.markdown(
            """
        <div class="narrative-card">
            <h3>Risk Scoring</h3>
            <p>
                Propagated risk scores that account for both direct supplier risk and
                indirect exposure through Tier-2+ dependencies.
            </p>
        </div>
        """,
            unsafe_allow_html=True,
        )

    with col2:
        st.markdown(
            """
        <div class="narrative-card">
            <h3>Concentration Analysis</h3>
            <p>
                Identify suppliers where multiple Tier-1 vendors converge on shared
                Tier-2+ sources, creating hidden concentration risk.
            </p>
        </div>
        """,
            unsafe_allow_html=True,
        )

    with col3:
        st.markdown(
            """
        <div class="narrative-card">
            <h3>Mitigation Planning</h3>
            <p>
                Prioritized action items based on risk impact and probability, with
                AI-assisted analysis for deeper investigation.
            </p>
        </div>
        """,
            unsafe_allow_html=True,
        )

    st.divider()

    # ============================================
    # NAVIGATION
    # ============================================
    st.markdown(
        """
    <div class="section-header">Analysis Modules</div>
    """,
        unsafe_allow_html=True,
    )

    col1, col2, col3, col4 = st.columns(4)

    with col1:
        st.page_link("pages/1_Executive_Summary.py", label="Executive Summary")
        st.caption("Portfolio health and KPIs")

    with col2:
        st.page_link("pages/3_Supply_Network.py", label="Supply Network")
        st.caption("Multi-tier relationship graph")

    with col3:
        st.page_link("pages/4_Tier2_Analysis.py", label="Tier-2 Analysis")
        st.caption("Concentration points and inferred links")

    with col4:
        st.page_link("pages/7_Risk_Mitigation.py", label="Risk Mitigation")
        st.caption("Prioritization and action planning")

    # Sidebar with navigation
    render_sidebar()


if __name__ == "__main__":
    main()
