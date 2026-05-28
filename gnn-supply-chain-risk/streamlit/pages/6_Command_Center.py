"""
Command Center Page

Operational monitoring dashboard for Plant Manager/Operations personas.
Real-time alerts, watchlist management, and action tracking.
"""

import streamlit as st
import pandas as pd
import plotly.graph_objects as go
from datetime import datetime, timedelta
import sys
from pathlib import Path
from snowflake.snowpark.context import get_active_session

# Add parent directory to path for utils import (needed for Streamlit in Snowflake)
sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.data_loader import run_queries_parallel, DB_SCHEMA
from utils.sidebar import render_sidebar, render_star_callout

st.set_page_config(
    page_title="Command Center",
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
    .alert-panel {
        background: rgba(30, 41, 59, 0.8);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1rem;
        max-height: 500px;
        overflow-y: auto;
    }
    .alert-item {
        background: rgba(15, 23, 42, 0.6);
        border-radius: 8px;
        padding: 1rem;
        margin: 0.5rem 0;
        border-left: 4px solid #dc2626;
    }
    .alert-item.high {
        border-left-color: #f59e0b;
    }
    .alert-item.medium {
        border-left-color: #3b82f6;
    }
    .alert-item.low {
        border-left-color: #10b981;
    }
    .alert-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 0.5rem;
    }
    .alert-title {
        color: #f8fafc;
        font-weight: 600;
        font-size: 0.95rem;
    }
    .alert-badge {
        padding: 2px 10px;
        border-radius: 12px;
        font-size: 0.7rem;
        font-weight: 600;
        text-transform: uppercase;
    }
    .badge-critical { background: #dc2626; color: white; }
    .badge-high { background: #f59e0b; color: black; }
    .badge-medium { background: #3b82f6; color: white; }
    .badge-low { background: #10b981; color: white; }
    .alert-content {
        color: #94a3b8;
        font-size: 0.85rem;
        line-height: 1.5;
    }
    .alert-meta {
        color: #64748b;
        font-size: 0.75rem;
        margin-top: 0.5rem;
    }
    .watchlist-card {
        background: rgba(30, 41, 59, 0.8);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1.5rem;
    }
    .watchlist-item {
        background: rgba(15, 23, 42, 0.6);
        border-radius: 8px;
        padding: 1rem;
        margin: 0.5rem 0;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }
    .watchlist-info {
        flex: 1;
    }
    .watchlist-name {
        color: #f8fafc;
        font-weight: 600;
        font-size: 0.95rem;
    }
    .watchlist-detail {
        color: #64748b;
        font-size: 0.8rem;
    }
    .watchlist-status {
        text-align: right;
    }
    .risk-indicator {
        width: 60px;
        height: 8px;
        background: #334155;
        border-radius: 4px;
        overflow: hidden;
    }
    .risk-fill {
        height: 100%;
        border-radius: 4px;
    }
    .action-tracker {
        background: rgba(30, 41, 59, 0.8);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1.5rem;
    }
    .action-item {
        background: rgba(15, 23, 42, 0.6);
        border-radius: 8px;
        padding: 1rem;
        margin: 0.5rem 0;
    }
    .action-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 0.5rem;
    }
    .action-title {
        color: #f8fafc;
        font-weight: 600;
        font-size: 0.95rem;
    }
    .status-badge {
        padding: 2px 10px;
        border-radius: 12px;
        font-size: 0.7rem;
        font-weight: 600;
    }
    .status-pending { background: #f59e0b; color: black; }
    .status-in-progress { background: #3b82f6; color: white; }
    .status-resolved { background: #10b981; color: white; }
    .action-detail {
        color: #94a3b8;
        font-size: 0.85rem;
    }
    .stat-row {
        display: flex;
        gap: 1rem;
        margin: 1rem 0;
    }
    .stat-box {
        flex: 1;
        background: rgba(15, 23, 42, 0.6);
        border-radius: 8px;
        padding: 1rem;
        text-align: center;
    }
    .stat-value {
        font-size: 1.8rem;
        font-weight: 800;
        color: #f8fafc;
    }
    .stat-value.critical { color: #dc2626; }
    .stat-value.warning { color: #f59e0b; }
    .stat-value.success { color: #10b981; }
    .stat-label {
        font-size: 0.75rem;
        color: #64748b;
        text-transform: uppercase;
    }
    .trend-indicator {
        font-size: 0.8rem;
        margin-top: 0.25rem;
    }
    .trend-up { color: #dc2626; }
    .trend-down { color: #10b981; }
    .trend-flat { color: #64748b; }
    
    /* Hide default multipage navigation */
    [data-testid="stSidebarNav"] {display: none;}
</style>
""", unsafe_allow_html=True)


@st.cache_resource
def get_session():
    return get_active_session()


@st.cache_data(ttl=60)  # Refresh every minute for operational view
def load_active_alerts(_session):
    """Load active alerts based on risk scores and bottlenecks."""
    alerts = []
    
    # Define all queries for parallel execution
    queries = {
        'critical_suppliers': f"""
            SELECT 
                v.VENDOR_ID,
                v.NAME,
                v.COUNTRY_CODE,
                rs.RISK_SCORE,
                rs.RISK_CATEGORY,
                rs.UPDATED_AT
            FROM {DB_SCHEMA}.RISK_SCORES rs
            JOIN {DB_SCHEMA}.VENDORS v ON rs.NODE_ID = v.VENDOR_ID
            WHERE rs.RISK_CATEGORY = 'CRITICAL'
            ORDER BY rs.RISK_SCORE DESC
            LIMIT 10
        """,
        'high_risk_suppliers': f"""
            SELECT 
                v.VENDOR_ID,
                v.NAME,
                v.COUNTRY_CODE,
                rs.RISK_SCORE,
                rs.RISK_CATEGORY,
                rs.UPDATED_AT
            FROM {DB_SCHEMA}.RISK_SCORES rs
            JOIN {DB_SCHEMA}.VENDORS v ON rs.NODE_ID = v.VENDOR_ID
            WHERE rs.RISK_CATEGORY = 'HIGH'
            ORDER BY rs.RISK_SCORE DESC
            LIMIT 5
        """,
        'bottlenecks': f"""
            SELECT 
                NODE_ID,
                DEPENDENT_COUNT,
                IMPACT_SCORE,
                DESCRIPTION,
                MITIGATION_STATUS,
                IDENTIFIED_AT
            FROM {DB_SCHEMA}.BOTTLENECKS
            WHERE IMPACT_SCORE >= 0.5
            ORDER BY IMPACT_SCORE DESC
            LIMIT 5
        """
    }
    
    results = run_queries_parallel(_session, queries, max_workers=3)
    
    # Process critical suppliers as alerts
    critical = results.get('critical_suppliers')
    if critical is not None and not critical.empty:
        for _, row in critical.iterrows():
            alerts.append({
                'severity': 'CRITICAL',
                'type': 'Supplier Risk',
                'title': f"{row['NAME']} at Critical Risk",
                'content': f"Risk score: {row['RISK_SCORE']:.0%}. Located in {row['COUNTRY_CODE']}. Immediate review recommended.",
                'entity_id': row['VENDOR_ID'],
                'entity_name': row['NAME'],
                'timestamp': row.get('UPDATED_AT'),
                'risk_score': float(row['RISK_SCORE'])
            })
    
    # Process high risk suppliers
    high_risk = results.get('high_risk_suppliers')
    if high_risk is not None and not high_risk.empty:
        for _, row in high_risk.iterrows():
            alerts.append({
                'severity': 'HIGH',
                'type': 'Supplier Risk',
                'title': f"{row['NAME']} Elevated Risk",
                'content': f"Risk score: {row['RISK_SCORE']:.0%}. Monitor closely for changes.",
                'entity_id': row['VENDOR_ID'],
                'entity_name': row['NAME'],
                'timestamp': row.get('UPDATED_AT'),
                'risk_score': float(row['RISK_SCORE'])
            })
    
    # Process bottlenecks as alerts
    bottlenecks = results.get('bottlenecks')
    if bottlenecks is not None and not bottlenecks.empty:
        for _, row in bottlenecks.iterrows():
            severity = 'CRITICAL' if row['IMPACT_SCORE'] >= 0.7 else 'HIGH'
            status = row.get('MITIGATION_STATUS', 'UNMITIGATED')
            
            alerts.append({
                'severity': severity,
                'type': 'Concentration Risk',
                'title': f"Bottleneck: {row['NODE_ID']}",
                'content': f"{row['DEPENDENT_COUNT']} vendors dependent. Impact: {row['IMPACT_SCORE']:.0%}. Status: {status}",
                'entity_id': row['NODE_ID'],
                'entity_name': row['NODE_ID'],
                'timestamp': row.get('IDENTIFIED_AT'),
                'risk_score': float(row['IMPACT_SCORE'])
            })
    
    # Sort by severity and risk score
    severity_order = {'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3}
    alerts.sort(key=lambda x: (severity_order.get(x['severity'], 99), -x.get('risk_score', 0)))
    
    return alerts


@st.cache_data(ttl=60)
def load_alert_summary(_session):
    """Load summary counts for alert categories."""
    queries = {
        'critical_count': f"SELECT COUNT(*) as CNT FROM {DB_SCHEMA}.RISK_SCORES WHERE RISK_CATEGORY = 'CRITICAL' AND NODE_TYPE = 'SUPPLIER'",
        'high_count': f"SELECT COUNT(*) as CNT FROM {DB_SCHEMA}.RISK_SCORES WHERE RISK_CATEGORY = 'HIGH' AND NODE_TYPE = 'SUPPLIER'",
        'medium_count': f"SELECT COUNT(*) as CNT FROM {DB_SCHEMA}.RISK_SCORES WHERE RISK_CATEGORY = 'MEDIUM' AND NODE_TYPE = 'SUPPLIER'",
        'bottleneck_count': f"SELECT COUNT(*) as CNT FROM {DB_SCHEMA}.BOTTLENECKS WHERE IMPACT_SCORE >= 0.5"
    }
    
    results = run_queries_parallel(_session, queries, max_workers=4)
    
    summary = {}
    for key in queries:
        df = results.get(key)
        if df is not None and not df.empty:
            summary[key] = int(df['CNT'].iloc[0])
        else:
            summary[key] = 0
    
    return summary


@st.cache_data(ttl=300)
def load_watchlist_suppliers(_session):
    """Load suppliers for watchlist - those with elevated risk."""
    try:
        result = _session.sql(f"""
            SELECT 
                v.VENDOR_ID,
                v.NAME,
                v.COUNTRY_CODE,
                v.FINANCIAL_HEALTH_SCORE,
                rs.RISK_SCORE,
                rs.RISK_CATEGORY,
                rs.calculated_at as UPDATED_AT
            FROM {DB_SCHEMA}.RISK_SCORES rs
            JOIN {DB_SCHEMA}.VENDORS v ON rs.NODE_ID = v.VENDOR_ID
            WHERE rs.RISK_CATEGORY IN ('CRITICAL', 'HIGH', 'MEDIUM')
            ORDER BY rs.RISK_SCORE DESC
            LIMIT 20
        """).to_pandas()
        return result
    except Exception:
        return pd.DataFrame()


@st.cache_data(ttl=300)
def load_action_items(_session):
    """Generate action items based on current risk state."""
    actions = []
    
    queries = {
        'unmitigated_bottlenecks': f"""
            SELECT NODE_ID, DEPENDENT_COUNT, IMPACT_SCORE
            FROM {DB_SCHEMA}.BOTTLENECKS
            WHERE MITIGATION_STATUS = 'UNMITIGATED' OR MITIGATION_STATUS IS NULL
            ORDER BY IMPACT_SCORE DESC
            LIMIT 5
        """,
        'critical_suppliers': f"""
            SELECT v.NAME, rs.RISK_SCORE
            FROM {DB_SCHEMA}.RISK_SCORES rs
            JOIN {DB_SCHEMA}.VENDORS v ON rs.NODE_ID = v.VENDOR_ID
            WHERE rs.RISK_CATEGORY = 'CRITICAL'
            LIMIT 3
        """
    }
    
    results = run_queries_parallel(_session, queries, max_workers=2)
    
    # Create action items from unmitigated bottlenecks
    bottlenecks = results.get('unmitigated_bottlenecks')
    if bottlenecks is not None and not bottlenecks.empty:
        for _, row in bottlenecks.iterrows():
            actions.append({
                'id': f"BTN-{row['NODE_ID'][:8]}",
                'title': f"Mitigate {row['NODE_ID']} dependency",
                'detail': f"{row['DEPENDENT_COUNT']} vendors at risk. Impact: {row['IMPACT_SCORE']:.0%}",
                'status': 'pending',
                'priority': 'critical' if row['IMPACT_SCORE'] >= 0.7 else 'high',
                'type': 'bottleneck'
            })
    
    # Create action items from critical suppliers
    critical = results.get('critical_suppliers')
    if critical is not None and not critical.empty:
        for _, row in critical.iterrows():
            actions.append({
                'id': f"SUP-{hash(row['NAME']) % 10000:04d}",
                'title': f"Review {row['NAME']}",
                'detail': f"Risk score: {row['RISK_SCORE']:.0%}. Schedule supplier audit.",
                'status': 'pending',
                'priority': 'critical',
                'type': 'supplier_review'
            })
    
    # Standard operational actions
    actions.extend([
        {
            'id': 'OP-001',
            'title': 'Refresh trade data',
            'detail': 'Update external trade intelligence feeds',
            'status': 'pending',
            'priority': 'medium',
            'type': 'operational'
        },
        {
            'id': 'OP-002',
            'title': 'Weekly risk review',
            'detail': 'Review risk score changes with procurement team',
            'status': 'in_progress',
            'priority': 'medium',
            'type': 'operational'
        }
    ])
    
    return actions


def render_risk_trend_chart(height=200):
    """Render a simple risk trend visualization."""
    # Simulated trend data (in production, this would come from historical risk scores)
    dates = pd.date_range(end=datetime.now(), periods=7, freq='D')
    
    # Simulated values with slight variation
    import random
    random.seed(42)
    values = [45 + random.randint(-5, 5) for _ in range(7)]
    
    fig = go.Figure()
    
    fig.add_trace(go.Scatter(
        x=dates,
        y=values,
        mode='lines+markers',
        line=dict(color='#3b82f6', width=2),
        marker=dict(size=6, color='#3b82f6'),
        fill='tozeroy',
        fillcolor='rgba(59, 130, 246, 0.1)',
        hovertemplate='%{x|%b %d}<br>Risk Index: %{y}<extra></extra>'
    ))
    
    fig.update_layout(
        paper_bgcolor='rgba(0,0,0,0)',
        plot_bgcolor='rgba(0,0,0,0)',
        height=height,
        margin=dict(l=40, r=20, t=10, b=30),
        xaxis=dict(
            showgrid=False,
            tickfont=dict(color='#64748b', size=10),
            tickformat='%b %d'
        ),
        yaxis=dict(
            showgrid=True,
            gridcolor='rgba(51, 65, 85, 0.3)',
            tickfont=dict(color='#64748b', size=10),
            title=None
        )
    )
    
    st.plotly_chart(fig, use_container_width=True, key="risk_trend")


def main():
    session = get_session()
    
    # Render sidebar
    render_sidebar()
    
    # Render STAR callout if demo mode is enabled
    render_star_callout("command")
    
    # Load data
    alerts = load_active_alerts(session)
    alert_summary = load_alert_summary(session)
    watchlist = load_watchlist_suppliers(session)
    action_items = load_action_items(session)
    
    # ============================================
    # HEADER
    # ============================================
    st.markdown("""
    <div class="page-header">Command Center</div>
    <div class="page-subheader">Operational monitoring and alert management</div>
    """, unsafe_allow_html=True)
    
    # ============================================
    # SUMMARY STATS
    # ============================================
    col1, col2, col3, col4, col5 = st.columns(5)
    
    with col1:
        critical = alert_summary.get('critical_count', 0)
        st.markdown(f"""
        <div class="stat-box">
            <div class="stat-value critical">{critical}</div>
            <div class="stat-label">Critical Alerts</div>
            <div class="trend-indicator trend-flat">━ No change</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        high = alert_summary.get('high_count', 0)
        st.markdown(f"""
        <div class="stat-box">
            <div class="stat-value warning">{high}</div>
            <div class="stat-label">High Priority</div>
            <div class="trend-indicator trend-flat">━ Stable</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        medium = alert_summary.get('medium_count', 0)
        st.markdown(f"""
        <div class="stat-box">
            <div class="stat-value">{medium}</div>
            <div class="stat-label">Monitoring</div>
            <div class="trend-indicator trend-down">↓ Improving</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        bottlenecks = alert_summary.get('bottleneck_count', 0)
        st.markdown(f"""
        <div class="stat-box">
            <div class="stat-value warning">{bottlenecks}</div>
            <div class="stat-label">Active Bottlenecks</div>
            <div class="trend-indicator trend-flat">━ Tracked</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col5:
        pending_actions = len([a for a in action_items if a['status'] == 'pending'])
        st.markdown(f"""
        <div class="stat-box">
            <div class="stat-value">{pending_actions}</div>
            <div class="stat-label">Pending Actions</div>
            <div class="trend-indicator trend-flat">→ In queue</div>
        </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # MAIN CONTENT
    # ============================================
    col1, col2 = st.columns([2, 1])
    
    with col1:
        # Active Alerts Panel
        st.markdown('<div class="section-header">Active Alerts</div>', unsafe_allow_html=True)
        
        # Filter controls
        filter_col1, filter_col2 = st.columns([1, 2])
        with filter_col1:
            severity_filter = st.selectbox(
                "Filter by severity:",
                ["All", "CRITICAL", "HIGH", "MEDIUM"],
                index=0
            )
        
        # Filter alerts
        filtered_alerts = alerts
        if severity_filter != "All":
            filtered_alerts = [a for a in alerts if a['severity'] == severity_filter]
        
        st.markdown(f"**{len(filtered_alerts)}** active alerts")
        
        if filtered_alerts:
            st.markdown('<div class="alert-panel">', unsafe_allow_html=True)
            
            for alert in filtered_alerts:
                severity = alert['severity']
                css_class = severity.lower()
                badge_class = f"badge-{css_class}"
                
                st.markdown(f"""
                <div class="alert-item {css_class}">
                    <div class="alert-header">
                        <span class="alert-title">{alert['title']}</span>
                        <span class="alert-badge {badge_class}">{severity}</span>
                    </div>
                    <div class="alert-content">{alert['content']}</div>
                    <div class="alert-meta">
                        Type: {alert['type']} · Entity: {alert['entity_id'][:20]}
                    </div>
                </div>
                """, unsafe_allow_html=True)
            
            st.markdown('</div>', unsafe_allow_html=True)
        else:
            st.info("No active alerts matching the filter criteria.")
        
        # Risk Trend
        st.markdown("#### 7-Day Risk Trend")
        render_risk_trend_chart(height=180)
    
    with col2:
        # Action Tracker
        st.markdown("#### Action Tracker")
        
        st.markdown('<div class="action-tracker">', unsafe_allow_html=True)
        
        if action_items:
            for action in action_items[:8]:
                status = action['status']
                status_class = status.replace('_', '-')
                status_label = status.replace('_', ' ').title()
                
                st.markdown(f"""
                <div class="action-item">
                    <div class="action-header">
                        <span class="action-title">{action['title'][:30]}</span>
                        <span class="status-badge status-{status_class}">{status_label}</span>
                    </div>
                    <div class="action-detail">{action['detail'][:60]}</div>
                </div>
                """, unsafe_allow_html=True)
        else:
            st.info("No pending actions.")
        
        st.markdown('</div>', unsafe_allow_html=True)
        
        # Quick Actions
        st.markdown("#### Quick Actions")
        
        if st.button("Export Alert Report", use_container_width=True):
            if alerts:
                df = pd.DataFrame(alerts)
                csv = df.to_csv(index=False)
                st.download_button(
                    "Download CSV",
                    csv,
                    "alert_report.csv",
                    "text/csv",
                    key="download_alerts"
                )
        
        if st.button("Refresh Alerts", use_container_width=True):
            st.cache_data.clear()
            st.rerun()
    
    st.divider()
    
    # ============================================
    # WATCHLIST
    # ============================================
    st.markdown('<div class="section-header">Supplier Watchlist</div>', unsafe_allow_html=True)
    st.markdown("Suppliers with elevated risk requiring monitoring")
    
    if not watchlist.empty:
        # Create columns for watchlist items
        cols = st.columns(3)
        
        for idx, (_, row) in enumerate(watchlist.head(12).iterrows()):
            col_idx = idx % 3
            
            name = row.get('NAME', row['VENDOR_ID'])
            country = row.get('COUNTRY_CODE', 'Unknown')
            risk = float(row.get('RISK_SCORE', 0) or 0)
            category = row.get('RISK_CATEGORY', 'UNKNOWN')
            health = float(row.get('FINANCIAL_HEALTH_SCORE', 0) or 0)
            
            # Risk color
            risk_color = '#dc2626' if risk >= 0.7 else '#f59e0b' if risk >= 0.4 else '#3b82f6'
            
            with cols[col_idx]:
                st.markdown(f"""
                <div class="watchlist-item">
                    <div class="watchlist-info">
                        <div class="watchlist-name">{name[:25]}</div>
                        <div class="watchlist-detail">{country} · Health: {health:.0%}</div>
                    </div>
                    <div class="watchlist-status">
                        <div style="color: {risk_color}; font-weight: 700; font-size: 1.1rem;">{risk:.0%}</div>
                        <div style="color: #64748b; font-size: 0.7rem;">{category}</div>
                    </div>
                </div>
                """, unsafe_allow_html=True)
        
        if len(watchlist) > 12:
            st.caption(f"+ {len(watchlist) - 12} more suppliers on watchlist")
    else:
        st.info("No suppliers currently on watchlist. Run the GNN notebook to generate risk scores.")
    
    st.divider()
    
    # ============================================
    # OPERATIONAL METRICS
    # ============================================
    st.markdown('<div class="section-header">Operational Metrics</div>', unsafe_allow_html=True)
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.markdown("#### Alert Response Time")
        st.markdown("""
        <div style="background: rgba(30, 41, 59, 0.8); border-radius: 12px; padding: 1.5rem; text-align: center;">
            <div style="font-size: 2.5rem; font-weight: 800; color: #10b981;">< 24h</div>
            <div style="color: #64748b; font-size: 0.85rem;">Avg Response Time</div>
            <div style="color: #10b981; font-size: 0.8rem; margin-top: 0.5rem;">Within SLA</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("#### Coverage")
        monitored = len(watchlist) if not watchlist.empty else 0
        st.markdown(f"""
        <div style="background: rgba(30, 41, 59, 0.8); border-radius: 12px; padding: 1.5rem; text-align: center;">
            <div style="font-size: 2.5rem; font-weight: 800; color: #3b82f6;">{monitored}</div>
            <div style="color: #64748b; font-size: 0.85rem;">Suppliers Monitored</div>
            <div style="color: #3b82f6; font-size: 0.8rem; margin-top: 0.5rem;">Active Tracking</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown("#### Data Freshness")
        st.markdown("""
        <div style="background: rgba(30, 41, 59, 0.8); border-radius: 12px; padding: 1.5rem; text-align: center;">
            <div style="font-size: 2.5rem; font-weight: 800; color: #10b981;">Live</div>
            <div style="color: #64748b; font-size: 0.85rem;">Risk Scores</div>
            <div style="color: #10b981; font-size: 0.8rem; margin-top: 0.5rem;">Real-time</div>
        </div>
        """, unsafe_allow_html=True)


if __name__ == "__main__":
    main()

