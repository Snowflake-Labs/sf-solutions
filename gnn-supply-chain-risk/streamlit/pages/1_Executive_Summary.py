"""
Executive Summary Page

Strategic dashboard for VP/Executive personas showing portfolio-level health,
regional risk aggregation, and key performance indicators.
"""

import streamlit as st
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
import sys
from pathlib import Path
from snowflake.snowpark.context import get_active_session

# Add parent directory to path for utils import (needed for Streamlit in Snowflake)
sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.data_loader import run_queries_parallel, DB_SCHEMA
from utils.sidebar import render_sidebar, render_star_callout

st.set_page_config(
    page_title="Executive Summary",
    page_icon=None,
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
<style>
    .stApp {
        background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%);
    }
    .page-header {
        font-size: 2.5rem;
        font-weight: 800;
        color: #f8fafc;
        margin-bottom: 0.5rem;
    }
    .page-subheader {
        font-size: 1.2rem;
        color: #94a3b8;
        margin-bottom: 2rem;
    }
    .section-header {
        font-size: 1.5rem;
        font-weight: 700;
        color: #f8fafc;
        margin: 2rem 0 1rem 0;
        padding-bottom: 0.5rem;
        border-bottom: 2px solid #334155;
    }
    .kpi-card {
        background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
        border: 1px solid #334155;
        border-radius: 16px;
        padding: 1.5rem;
        text-align: center;
        height: 100%;
    }
    .kpi-value {
        font-size: 2.8rem;
        font-weight: 800;
        color: #f8fafc;
        line-height: 1;
    }
    .kpi-value.critical { color: #dc2626; }
    .kpi-value.warning { color: #f59e0b; }
    .kpi-value.success { color: #10b981; }
    .kpi-label {
        font-size: 0.85rem;
        color: #64748b;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        margin-top: 0.5rem;
    }
    .kpi-trend {
        font-size: 0.8rem;
        margin-top: 0.5rem;
        padding: 4px 8px;
        border-radius: 12px;
        display: inline-block;
    }
    .trend-up { background: rgba(220, 38, 38, 0.2); color: #fca5a5; }
    .trend-down { background: rgba(16, 185, 129, 0.2); color: #86efac; }
    .trend-neutral { background: rgba(148, 163, 184, 0.2); color: #94a3b8; }
    .health-gauge {
        background: rgba(30, 41, 59, 0.8);
        border: 1px solid #334155;
        border-radius: 16px;
        padding: 1.5rem;
        text-align: center;
    }
    .health-score {
        font-size: 4rem;
        font-weight: 800;
        line-height: 1;
    }
    .health-label {
        font-size: 1rem;
        color: #94a3b8;
        margin-top: 0.5rem;
    }
    .insight-card {
        background: rgba(30, 41, 59, 0.8);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1.25rem;
        margin: 0.5rem 0;
    }
    .insight-card h4 {
        color: #f8fafc;
        font-size: 1rem;
        margin-bottom: 0.5rem;
    }
    .insight-card p {
        color: #94a3b8;
        font-size: 0.9rem;
        line-height: 1.5;
        margin: 0;
    }
    .concentration-item {
        background: rgba(220, 38, 38, 0.1);
        border-left: 3px solid #dc2626;
        border-radius: 0 8px 8px 0;
        padding: 1rem;
        margin: 0.5rem 0;
    }
    .concentration-item.high {
        background: rgba(245, 158, 11, 0.1);
        border-left-color: #f59e0b;
    }
    .concentration-item h5 {
        color: #f8fafc;
        font-size: 0.95rem;
        margin-bottom: 0.25rem;
    }
    .concentration-item p {
        color: #94a3b8;
        font-size: 0.85rem;
        margin: 0;
    }
    .value-highlight {
        background: linear-gradient(135deg, rgba(16, 185, 129, 0.1) 0%, rgba(59, 130, 246, 0.1) 100%);
        border: 1px solid #10b981;
        border-radius: 12px;
        padding: 1.5rem;
        margin: 1rem 0;
    }
    .value-highlight h3 {
        color: #10b981;
        font-size: 1.2rem;
        margin-bottom: 0.5rem;
    }
    .value-highlight p {
        color: #e2e8f0;
        line-height: 1.6;
    }
    
    /* Hide default multipage navigation */
    [data-testid="stSidebarNav"] {display: none;}
</style>
""", unsafe_allow_html=True)


@st.cache_resource
def get_session():
    return get_active_session()


@st.cache_data(ttl=300)
def load_executive_metrics(_session):
    """Load executive-level KPIs using parallel query execution."""
    
    queries = {
        'risk_summary': f"""
            SELECT 
                COUNT(*) as TOTAL_NODES,
                SUM(CASE WHEN RISK_CATEGORY = 'CRITICAL' THEN 1 ELSE 0 END) as CRITICAL_COUNT,
                SUM(CASE WHEN RISK_CATEGORY = 'HIGH' THEN 1 ELSE 0 END) as HIGH_COUNT,
                SUM(CASE WHEN RISK_CATEGORY = 'MEDIUM' THEN 1 ELSE 0 END) as MEDIUM_COUNT,
                SUM(CASE WHEN RISK_CATEGORY = 'LOW' THEN 1 ELSE 0 END) as LOW_COUNT,
                ROUND(AVG(RISK_SCORE), 3) as AVG_RISK_SCORE
            FROM {DB_SCHEMA}.RISK_SCORES
        """,
        'vendor_summary': f"""
            SELECT 
                COUNT(*) as TOTAL_VENDORS,
                COUNT(DISTINCT COUNTRY_CODE) as COUNTRY_COUNT,
                ROUND(AVG(FINANCIAL_HEALTH_SCORE), 3) as AVG_HEALTH
            FROM {DB_SCHEMA}.VENDORS
        """,
        'bottleneck_summary': f"""
            SELECT 
                COUNT(*) as TOTAL_BOTTLENECKS,
                SUM(DEPENDENT_COUNT) as TOTAL_AT_RISK_VENDORS,
                ROUND(MAX(IMPACT_SCORE), 3) as MAX_IMPACT
            FROM {DB_SCHEMA}.BOTTLENECKS
        """,
        'prediction_summary': f"""
            SELECT 
                COUNT(*) as TOTAL_PREDICTIONS,
                SUM(CASE WHEN PROBABILITY >= 0.7 THEN 1 ELSE 0 END) as HIGH_CONFIDENCE,
                ROUND(AVG(PROBABILITY), 3) as AVG_CONFIDENCE
            FROM {DB_SCHEMA}.PREDICTED_LINKS
        """,
        'material_summary': f"""
            SELECT 
                COUNT(*) as TOTAL_MATERIALS,
                ROUND(AVG(CRITICALITY_SCORE), 3) as AVG_CRITICALITY
            FROM {DB_SCHEMA}.MATERIALS
        """
    }
    
    return run_queries_parallel(_session, queries, max_workers=4)


@st.cache_data(ttl=300)
def load_regional_risk(_session):
    """Load risk aggregated by region."""
    try:
        result = _session.sql(f"""
            SELECT 
                v.COUNTRY_CODE,
                COALESCE(r.REGION_NAME, v.COUNTRY_CODE) as REGION_NAME,
                COUNT(DISTINCT v.VENDOR_ID) as VENDOR_COUNT,
                ROUND(AVG(rs.RISK_SCORE), 3) as AVG_RISK,
                ROUND(AVG(v.FINANCIAL_HEALTH_SCORE), 3) as AVG_HEALTH,
                r.GEOPOLITICAL_RISK,
                r.NATURAL_DISASTER_RISK,
                SUM(CASE WHEN rs.RISK_CATEGORY IN ('CRITICAL', 'HIGH') THEN 1 ELSE 0 END) as HIGH_RISK_COUNT
            FROM {DB_SCHEMA}.VENDORS v
            LEFT JOIN {DB_SCHEMA}.REGIONS r ON v.COUNTRY_CODE = r.REGION_CODE
            LEFT JOIN {DB_SCHEMA}.RISK_SCORES rs ON v.VENDOR_ID = rs.NODE_ID
            GROUP BY v.COUNTRY_CODE, r.REGION_NAME, r.GEOPOLITICAL_RISK, r.NATURAL_DISASTER_RISK
            ORDER BY AVG_RISK DESC NULLS LAST
        """).to_pandas()
        return result
    except Exception:
        return pd.DataFrame()


@st.cache_data(ttl=300)
def load_top_concentration_risks(_session, limit=5):
    """Load top concentration risks for executive view."""
    try:
        result = _session.sql(f"""
            SELECT 
                NODE_ID,
                NODE_TYPE,
                DEPENDENT_COUNT,
                IMPACT_SCORE,
                DESCRIPTION,
                MITIGATION_STATUS
            FROM {DB_SCHEMA}.BOTTLENECKS
            ORDER BY IMPACT_SCORE DESC
            LIMIT {limit}
        """).to_pandas()
        return result
    except Exception:
        return pd.DataFrame()


@st.cache_data(ttl=300)
def load_spend_at_risk(_session):
    """Calculate estimated spend at risk based on supplier risk scores."""
    try:
        result = _session.sql(f"""
            SELECT 
                SUM(po.QUANTITY * po.UNIT_PRICE) as TOTAL_SPEND,
                SUM(CASE WHEN rs.RISK_CATEGORY IN ('CRITICAL', 'HIGH') 
                    THEN po.QUANTITY * po.UNIT_PRICE ELSE 0 END) as HIGH_RISK_SPEND,
                SUM(CASE WHEN rs.RISK_CATEGORY = 'CRITICAL' 
                    THEN po.QUANTITY * po.UNIT_PRICE ELSE 0 END) as CRITICAL_RISK_SPEND
            FROM {DB_SCHEMA}.PURCHASE_ORDERS po
            LEFT JOIN {DB_SCHEMA}.RISK_SCORES rs ON po.VENDOR_ID = rs.NODE_ID
        """).to_pandas()
        return result
    except Exception:
        return pd.DataFrame()


def calculate_portfolio_health(metrics):
    """Calculate overall portfolio health score (0-100)."""
    risk_summary = metrics.get('risk_summary')
    bottleneck_summary = metrics.get('bottleneck_summary')
    
    if risk_summary is None or risk_summary.empty:
        return 50, "Unknown"
    
    # Base score from average risk (inverted - lower risk = higher health)
    avg_risk = float(risk_summary['AVG_RISK_SCORE'].iloc[0] or 0.5)
    base_score = (1 - avg_risk) * 100
    
    # Penalty for critical issues
    critical_count = int(risk_summary['CRITICAL_COUNT'].iloc[0] or 0)
    critical_penalty = min(critical_count * 5, 30)  # Max 30 point penalty
    
    # Penalty for bottlenecks
    if bottleneck_summary is not None and not bottleneck_summary.empty:
        bottleneck_count = int(bottleneck_summary['TOTAL_BOTTLENECKS'].iloc[0] or 0)
        bottleneck_penalty = min(bottleneck_count * 3, 20)  # Max 20 point penalty
    else:
        bottleneck_penalty = 0
    
    final_score = max(0, min(100, base_score - critical_penalty - bottleneck_penalty))
    
    # Determine status
    if final_score >= 80:
        status = "Healthy"
    elif final_score >= 60:
        status = "Moderate"
    elif final_score >= 40:
        status = "At Risk"
    else:
        status = "Critical"
    
    return final_score, status


def render_health_gauge(score, status, height=250):
    """Render portfolio health gauge using Plotly."""
    
    # Color based on score
    if score >= 80:
        color = "#10b981"
    elif score >= 60:
        color = "#f59e0b"
    elif score >= 40:
        color = "#ea580c"
    else:
        color = "#dc2626"
    
    fig = go.Figure(go.Indicator(
        mode="gauge+number",
        value=score,
        number={'suffix': "", 'font': {'size': 48, 'color': '#f8fafc'}},
        gauge={
            'axis': {'range': [0, 100], 'tickwidth': 1, 'tickcolor': "#334155", 'tickfont': {'color': '#94a3b8'}},
            'bar': {'color': color},
            'bgcolor': "#1e293b",
            'borderwidth': 2,
            'bordercolor': "#334155",
            'steps': [
                {'range': [0, 40], 'color': 'rgba(220, 38, 38, 0.2)'},
                {'range': [40, 60], 'color': 'rgba(234, 88, 12, 0.2)'},
                {'range': [60, 80], 'color': 'rgba(245, 158, 11, 0.2)'},
                {'range': [80, 100], 'color': 'rgba(16, 185, 129, 0.2)'}
            ],
            'threshold': {
                'line': {'color': "#f8fafc", 'width': 2},
                'thickness': 0.8,
                'value': score
            }
        }
    ))
    
    fig.update_layout(
        paper_bgcolor='rgba(0,0,0,0)',
        plot_bgcolor='rgba(0,0,0,0)',
        height=height,
        margin=dict(l=30, r=30, t=30, b=10),
        font={'color': '#f8fafc'}
    )
    
    st.plotly_chart(fig, use_container_width=True, key="health_gauge")


def render_regional_heatmap(regional_data, height=350):
    """Render regional risk heatmap."""
    
    if regional_data.empty:
        st.info("No regional data available.")
        return
    
    # Prepare data
    df = regional_data.copy()
    df['AVG_RISK'] = df['AVG_RISK'].fillna(0.3)
    df['VENDOR_COUNT'] = df['VENDOR_COUNT'].fillna(0)
    
    # Create heatmap-style bar chart
    fig = go.Figure()
    
    # Sort by risk
    df = df.sort_values('AVG_RISK', ascending=True)
    
    # Color scale based on risk
    colors = df['AVG_RISK'].apply(
        lambda x: '#dc2626' if x >= 0.6 else '#f59e0b' if x >= 0.4 else '#10b981'
    ).tolist()
    
    fig.add_trace(go.Bar(
        y=df['REGION_NAME'],
        x=df['AVG_RISK'],
        orientation='h',
        marker_color=colors,
        text=[f"{v:.0%}" for v in df['AVG_RISK']],
        textposition='auto',
        textfont=dict(color='white', size=11),
        customdata=list(zip(df['VENDOR_COUNT'], df['HIGH_RISK_COUNT'].fillna(0))),
        hovertemplate=(
            "<b>%{y}</b><br>"
            "Avg Risk: %{x:.0%}<br>"
            "Vendors: %{customdata[0]}<br>"
            "High Risk: %{customdata[1]:.0f}<br>"
            "<extra></extra>"
        )
    ))
    
    fig.update_layout(
        paper_bgcolor='rgba(0,0,0,0)',
        plot_bgcolor='rgba(0,0,0,0)',
        height=height,
        margin=dict(l=10, r=40, t=20, b=20),
        xaxis=dict(
            title="Average Risk Score",
            title_font=dict(color='#94a3b8', size=11),
            tickfont=dict(color='#94a3b8'),
            tickformat='.0%',
            gridcolor='rgba(51, 65, 85, 0.3)',
            range=[0, 1]
        ),
        yaxis=dict(
            title=None,
            tickfont=dict(color='#e2e8f0', size=11)
        ),
        bargap=0.3
    )
    
    st.plotly_chart(fig, use_container_width=True, key="regional_heatmap")


def render_risk_distribution_bar(metrics, height=280):
    """Render risk category distribution as horizontal bar chart."""
    
    risk_summary = metrics.get('risk_summary')
    if risk_summary is None or risk_summary.empty:
        st.info("No risk data available.")
        return
    
    # Order from most severe to least severe (top to bottom)
    labels = ['Low', 'Medium', 'High', 'Critical']
    values = [
        int(risk_summary['LOW_COUNT'].iloc[0] or 0),
        int(risk_summary['MEDIUM_COUNT'].iloc[0] or 0),
        int(risk_summary['HIGH_COUNT'].iloc[0] or 0),
        int(risk_summary['CRITICAL_COUNT'].iloc[0] or 0)
    ]
    colors = ['#10b981', '#f59e0b', '#ea580c', '#dc2626']
    
    total = sum(values)
    
    fig = go.Figure()
    
    for i, (label, value, color) in enumerate(zip(labels, values, colors)):
        pct = (value / total * 100) if total > 0 else 0
        fig.add_trace(go.Bar(
            y=[label],
            x=[value],
            orientation='h',
            marker=dict(color=color, line=dict(color='#0f172a', width=1)),
            text=f"{value} ({pct:.0f}%)",
            textposition='auto',
            textfont=dict(color='white', size=11),
            hovertemplate=f"<b>{label}</b><br>Count: {value}<br>{pct:.1f}%<extra></extra>",
            showlegend=False
        ))
    
    fig.update_layout(
        paper_bgcolor='rgba(0,0,0,0)',
        plot_bgcolor='rgba(0,0,0,0)',
        height=height,
        margin=dict(l=10, r=10, t=10, b=30),
        xaxis=dict(
            showgrid=True,
            gridcolor='rgba(148, 163, 184, 0.1)',
            zeroline=False,
            title=dict(text=f"Supplier Count (n={total})", font=dict(color='#94a3b8', size=10)),
            tickfont=dict(color='#94a3b8', size=10)
        ),
        yaxis=dict(
            showgrid=False,
            tickfont=dict(color='#e2e8f0', size=11)
        ),
        barmode='group',
        bargap=0.3
    )
    
    st.plotly_chart(fig, use_container_width=True, key="risk_bar")


def main():
    session = get_session()
    
    # Render sidebar immediately
    render_sidebar()
    
    # Render STAR callout if demo mode is enabled
    render_star_callout("executive")
    
    # Load all data
    metrics = load_executive_metrics(session)
    regional_data = load_regional_risk(session)
    top_risks = load_top_concentration_risks(session)
    spend_data = load_spend_at_risk(session)
    
    # Calculate portfolio health
    health_score, health_status = calculate_portfolio_health(metrics)
    
    # ============================================
    # HEADER
    # ============================================
    st.markdown("""
    <div class="page-header">Executive Summary</div>
    <div class="page-subheader">Portfolio-level supply chain risk intelligence</div>
    """, unsafe_allow_html=True)
    
    # ============================================
    # PORTFOLIO HEALTH + KEY METRICS
    # ============================================
    col1, col2 = st.columns([1, 2])
    
    with col1:
        st.markdown("### Portfolio Health")
        render_health_gauge(health_score, health_status, height=220)
        
        # Status badge
        status_color = "#10b981" if health_status == "Healthy" else "#f59e0b" if health_status == "Moderate" else "#dc2626"
        st.markdown(f"""
        <div style="text-align: center; margin-top: -1rem;">
            <span style="background: {status_color}; color: white; padding: 6px 16px; border-radius: 20px; font-weight: 600;">
                {health_status}
            </span>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("### Key Performance Indicators")
        
        # Extract metrics
        risk_summary = metrics.get('risk_summary')
        vendor_summary = metrics.get('vendor_summary')
        bottleneck_summary = metrics.get('bottleneck_summary')
        prediction_summary = metrics.get('prediction_summary')
        
        kpi_col1, kpi_col2, kpi_col3, kpi_col4 = st.columns(4)
        
        with kpi_col1:
            critical_count = int(risk_summary['CRITICAL_COUNT'].iloc[0] or 0) if risk_summary is not None and not risk_summary.empty else 0
            st.markdown(f"""
            <div class="kpi-card">
                <div class="kpi-value critical">{critical_count}</div>
                <div class="kpi-label">Critical Risks</div>
                <div class="kpi-trend trend-up">Requires Action</div>
            </div>
            """, unsafe_allow_html=True)
        
        with kpi_col2:
            bottleneck_count = int(bottleneck_summary['TOTAL_BOTTLENECKS'].iloc[0] or 0) if bottleneck_summary is not None and not bottleneck_summary.empty else 0
            st.markdown(f"""
            <div class="kpi-card">
                <div class="kpi-value warning">{bottleneck_count}</div>
                <div class="kpi-label">Concentration Points</div>
                <div class="kpi-trend trend-neutral">Hidden SPOFs</div>
            </div>
            """, unsafe_allow_html=True)
        
        with kpi_col3:
            total_vendors = int(vendor_summary['TOTAL_VENDORS'].iloc[0] or 0) if vendor_summary is not None and not vendor_summary.empty else 0
            st.markdown(f"""
            <div class="kpi-card">
                <div class="kpi-value">{total_vendors}</div>
                <div class="kpi-label">Suppliers Monitored</div>
                <div class="kpi-trend trend-neutral">Tier-1 Coverage</div>
            </div>
            """, unsafe_allow_html=True)
        
        with kpi_col4:
            predicted_links = int(prediction_summary['TOTAL_PREDICTIONS'].iloc[0] or 0) if prediction_summary is not None and not prediction_summary.empty else 0
            st.markdown(f"""
            <div class="kpi-card">
                <div class="kpi-value success">{predicted_links}</div>
                <div class="kpi-label">Hidden Links Found</div>
                <div class="kpi-trend trend-down">Tier-2+ Visibility</div>
            </div>
            """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # SPEND AT RISK + RISK DISTRIBUTION
    # ============================================
    col1, col2, col3 = st.columns([1, 1, 1])
    
    with col1:
        st.markdown("### Spend at Risk")
        
        if spend_data is not None and not spend_data.empty:
            total_spend = float(spend_data['TOTAL_SPEND'].iloc[0] or 0)
            high_risk_spend = float(spend_data['HIGH_RISK_SPEND'].iloc[0] or 0)
            critical_spend = float(spend_data['CRITICAL_RISK_SPEND'].iloc[0] or 0)
            
            pct_at_risk = (high_risk_spend / total_spend * 100) if total_spend > 0 else 0
            
            st.markdown(f"""
            <div class="kpi-card">
                <div class="kpi-value warning">${high_risk_spend/1e6:.1f}M</div>
                <div class="kpi-label">High-Risk Supplier Spend</div>
                <div class="kpi-trend trend-up">{pct_at_risk:.1f}% of Total</div>
            </div>
            """, unsafe_allow_html=True)
            
            st.markdown(f"""
            <div style="margin-top: 1rem; color: #94a3b8; font-size: 0.9rem;">
                <div>Total PO Spend: <strong>${total_spend/1e6:.1f}M</strong></div>
                <div>Critical Risk Exposure: <strong style="color: #dc2626;">${critical_spend/1e6:.2f}M</strong></div>
            </div>
            """, unsafe_allow_html=True)
        else:
            st.info("No spend data available.")
    
    with col2:
        st.markdown("### Risk Distribution")
        render_risk_distribution_bar(metrics, height=250)
    
    with col3:
        st.markdown("### Quick Insights")
        
        # Generate insights based on data
        if risk_summary is not None and not risk_summary.empty:
            avg_risk = float(risk_summary['AVG_RISK_SCORE'].iloc[0] or 0)
            critical = int(risk_summary['CRITICAL_COUNT'].iloc[0] or 0)
            
            st.markdown(f"""
            <div class="insight-card">
                <h4>Average Portfolio Risk</h4>
                <p>Your supply chain has an average risk score of <strong>{avg_risk:.0%}</strong>. 
                {"This is elevated and requires attention." if avg_risk > 0.5 else "This is within acceptable range."}</p>
            </div>
            """, unsafe_allow_html=True)
            
            if critical > 0:
                st.markdown(f"""
                <div class="insight-card">
                    <h4>Critical Attention Needed</h4>
                    <p><strong>{critical} supplier(s)</strong> are in critical risk status. 
                    Immediate review and mitigation planning recommended.</p>
                </div>
                """, unsafe_allow_html=True)
        
        if bottleneck_summary is not None and not bottleneck_summary.empty:
            at_risk = int(bottleneck_summary['TOTAL_AT_RISK_VENDORS'].iloc[0] or 0)
            if at_risk > 0:
                st.markdown(f"""
                <div class="insight-card">
                    <h4>Concentration Alert</h4>
                    <p><strong>{at_risk} vendors</strong> depend on hidden Tier-2 suppliers 
                    that could create supply disruptions.</p>
                </div>
                """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # REGIONAL RISK + TOP CONCENTRATION RISKS
    # ============================================
    col1, col2 = st.columns([3, 2])
    
    with col1:
        st.markdown("### Regional Risk Profile")
        render_regional_heatmap(regional_data, height=320)
        
        # Regional summary
        if not regional_data.empty:
            high_risk_regions = regional_data[regional_data['AVG_RISK'].fillna(0) >= 0.5]
            if not high_risk_regions.empty:
                st.caption(f"{len(high_risk_regions)} region(s) above 50% risk threshold")
    
    with col2:
        st.markdown("### Top Concentration Risks")
        
        if not top_risks.empty:
            for _, row in top_risks.iterrows():
                impact = float(row['IMPACT_SCORE'] or 0)
                css_class = "" if impact >= 0.7 else "high"
                
                st.markdown(f"""
                <div class="concentration-item {css_class}">
                    <h5>{row['NODE_ID']}</h5>
                    <p>
                        <strong>{row['DEPENDENT_COUNT']}</strong> dependent vendors · 
                        Impact: <strong>{impact:.0%}</strong>
                    </p>
                </div>
                """, unsafe_allow_html=True)
        else:
            st.info("Run the GNN notebook to identify concentration risks.")
    
    st.divider()
    
    # ============================================
    # VALUE STATEMENT
    # ============================================
    st.markdown("""
    <div class="value-highlight">
        <h3>Value Delivered by Supply Chain Risk Intelligence</h3>
        <p>
            <strong>Before:</strong> Weeks of manual research to trace supplier dependencies. 
            Reactive response to disruptions. Hidden concentration risks causing unexpected shortages.
        </p>
        <p style="margin-top: 0.75rem;">
            <strong>After:</strong> Minutes to identify hidden Tier-2+ relationships. 
            Proactive risk scoring before disruptions occur. 
            Concentration points surfaced and prioritized for mitigation.
        </p>
    </div>
    """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # VALUE CALCULATOR
    # ============================================
    st.markdown('<div class="section-header">ROI Calculator</div>', unsafe_allow_html=True)
    st.markdown("Estimate the value of proactive supply chain risk management")
    
    calc_col1, calc_col2 = st.columns(2)
    
    with calc_col1:
        st.markdown("#### Input Your Parameters")
        
        avg_disruption_cost = st.number_input(
            "Average cost per supply disruption ($)",
            min_value=10000,
            max_value=50000000,
            value=500000,
            step=50000,
            help="Include production delays, expedited shipping, lost sales, etc."
        )
        
        disruptions_per_year = st.slider(
            "Estimated disruptions per year (without visibility)",
            min_value=1,
            max_value=20,
            value=4,
            help="How many supply disruptions typically occur annually"
        )
        
        reduction_rate = st.slider(
            "Expected disruption reduction with proactive monitoring (%)",
            min_value=10,
            max_value=80,
            value=40,
            help="Industry benchmarks suggest 30-50% reduction with early warning systems"
        )
        
        time_saved_hours = st.number_input(
            "Hours saved per risk assessment",
            min_value=1,
            max_value=200,
            value=40,
            help="Manual supplier due diligence vs. automated analysis"
        )
        
        hourly_rate = st.number_input(
            "Average analyst hourly rate ($)",
            min_value=25,
            max_value=500,
            value=150,
            step=25
        )
    
    with calc_col2:
        st.markdown("#### Estimated Annual Value")
        
        # Calculate values
        disruptions_prevented = disruptions_per_year * (reduction_rate / 100)
        disruption_savings = disruptions_prevented * avg_disruption_cost
        
        # Assume 12 major risk assessments per year
        assessments_per_year = 12
        time_savings_value = time_saved_hours * hourly_rate * assessments_per_year
        
        total_value = disruption_savings + time_savings_value
        
        st.markdown(f"""
        <div style="background: rgba(16, 185, 129, 0.1); border: 1px solid #10b981; border-radius: 12px; padding: 1.5rem; margin-bottom: 1rem;">
            <div style="color: #10b981; font-size: 0.85rem; text-transform: uppercase; margin-bottom: 0.5rem;">Total Estimated Annual Value</div>
            <div style="color: #f8fafc; font-size: 2.5rem; font-weight: 800;">${total_value:,.0f}</div>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown(f"""
        <div style="background: rgba(30, 41, 59, 0.8); border-radius: 8px; padding: 1rem; margin-bottom: 0.5rem;">
            <div style="display: flex; justify-content: space-between;">
                <span style="color: #94a3b8;">Disruption Cost Avoidance</span>
                <span style="color: #f8fafc; font-weight: 600;">${disruption_savings:,.0f}</span>
            </div>
            <div style="color: #64748b; font-size: 0.8rem; margin-top: 0.25rem;">
                {disruptions_prevented:.1f} disruptions prevented × ${avg_disruption_cost:,.0f}
            </div>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown(f"""
        <div style="background: rgba(30, 41, 59, 0.8); border-radius: 8px; padding: 1rem; margin-bottom: 0.5rem;">
            <div style="display: flex; justify-content: space-between;">
                <span style="color: #94a3b8;">Time Savings Value</span>
                <span style="color: #f8fafc; font-weight: 600;">${time_savings_value:,.0f}</span>
            </div>
            <div style="color: #64748b; font-size: 0.8rem; margin-top: 0.25rem;">
                {time_saved_hours}h × ${hourly_rate}/h × {assessments_per_year} assessments/year
            </div>
        </div>
        """, unsafe_allow_html=True)
        
        # Additional benefits
        st.markdown("#### Additional Strategic Benefits")
        st.markdown("""
        - **Compliance Risk Reduction** — Avoid regulatory penalties from supply chain traceability requirements
        - **Negotiating Leverage** — Use visibility data to negotiate better terms with suppliers
        - **Insurance Premium Reduction** — Demonstrate proactive risk management to reduce premiums
        - **Competitive Advantage** — Faster response to market disruptions than competitors
        """)
    
    st.divider()
    
    # ============================================
    # NAVIGATION
    # ============================================
    st.markdown("### Explore Further")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.page_link("pages/4_Tier2_Analysis.py", label="Deep Dive: Tier-2 Analysis")
        st.caption("Examine concentration points and predicted links")
    
    with col2:
        st.page_link("pages/5_Scenario_Simulator.py", label="What-If: Scenario Simulator")
        st.caption("Simulate disruptions and see cascading impact")
    
    with col3:
        st.page_link("pages/7_Risk_Mitigation.py", label="Take Action: Risk Mitigation")
        st.caption("Prioritized actions and AI guidance")


if __name__ == "__main__":
    main()

