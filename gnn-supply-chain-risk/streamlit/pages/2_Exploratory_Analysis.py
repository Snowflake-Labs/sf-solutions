"""
Exploratory Analysis Page

View connected data sources, pipeline status, and data quality metrics.
"""

import streamlit as st
import json
import plotly.graph_objects as go
import sys
from pathlib import Path
from snowflake.snowpark.context import get_active_session

# Add parent directory to path for utils import (needed for Streamlit in Snowflake)
sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.data_loader import run_queries_parallel, DB_SCHEMA
from utils.sidebar import render_sidebar, render_star_callout

st.set_page_config(
    page_title="Exploratory Analysis",
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
    .data-card {
        background: rgba(30, 41, 59, 0.8);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1.5rem;
        margin: 0.5rem 0;
        height: 100%;
    }
    .data-card h3 {
        color: #f8fafc;
        font-size: 1.1rem;
        margin-bottom: 0.5rem;
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }
    .data-card p {
        color: #94a3b8;
        font-size: 0.9rem;
        line-height: 1.5;
    }
    .data-count {
        font-size: 2rem;
        font-weight: 800;
        color: #3b82f6;
    }
    .internal-badge {
        background: #1e40af;
        color: #fff;
        padding: 2px 8px;
        border-radius: 4px;
        font-size: 0.7rem;
        text-transform: uppercase;
    }
    .external-badge {
        background: #b45309;
        color: #fff;
        padding: 2px 8px;
        border-radius: 4px;
        font-size: 0.7rem;
        text-transform: uppercase;
    }
    .visibility-gap {
        background: linear-gradient(135deg, rgba(220, 38, 38, 0.1) 0%, rgba(245, 158, 11, 0.1) 100%);
        border: 1px solid #f59e0b;
        border-radius: 12px;
        padding: 1.5rem;
        margin: 1.5rem 0;
    }
    .visibility-gap h3 {
        color: #f59e0b;
        margin-bottom: 0.5rem;
    }
    .tier-visual {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 1rem;
        padding: 2rem;
    }
    .tier-box {
        padding: 1rem 1.5rem;
        border-radius: 8px;
        text-align: center;
        min-width: 120px;
    }
    .tier-known {
        background: #166534;
        border: 2px solid #22c55e;
    }
    .tier-unknown {
        background: #7f1d1d;
        border: 2px solid #dc2626;
    }
    .arrow {
        color: #64748b;
        font-size: 2rem;
    }
    
    /* Hide default multipage navigation */
    [data-testid="stSidebarNav"] {display: none;}
</style>
""", unsafe_allow_html=True)


@st.cache_resource
def get_session():
    return get_active_session()


@st.cache_data(ttl=300)
def load_data_statistics(_session):
    """Load statistics about the data sources using parallel query execution."""
    
    # Define all table descriptions
    table_descriptions = {
        'VENDORS': 'Tier-1 supplier records from ERP',
        'MATERIALS': 'Parts and products in the catalog',
        'PURCHASE_ORDERS': 'Transaction history (Supplier→Part edges)',
        'BILL_OF_MATERIALS': 'Component hierarchy (Part→Part edges)',
        'REGIONS': 'Geographic risk data',
        'TRADE_DATA': 'Bills of lading / shipment records',
        'PREDICTED_LINKS': 'Hidden relationships discovered by GNN',
        'RISK_SCORES': 'Nodes with propagated risk scores'
    }
    
    # Build queries for parallel execution (8 queries in parallel instead of sequential)
    queries = {table: f"SELECT COUNT(*) as CNT FROM {DB_SCHEMA}.{table}" for table in table_descriptions}
    
    # Execute all COUNT queries in parallel
    results = run_queries_parallel(_session, queries, max_workers=4)
    
    # Process results into stats format
    stats = {}
    for table, desc in table_descriptions.items():
        df = results.get(table)
        if df is not None and not df.empty:
            stats[table] = {'count': int(df['CNT'].iloc[0]), 'description': desc}
        else:
            stats[table] = {'count': 0, 'description': desc}
    
    return stats


@st.cache_data(ttl=300)
def load_geographic_distribution(_session):
    """Load vendor distribution by country."""
    try:
        result = _session.sql(f"""
            SELECT 
                v.COUNTRY_CODE,
                r.REGION_NAME,
                COUNT(*) as VENDOR_COUNT,
                AVG(v.FINANCIAL_HEALTH_SCORE) as AVG_HEALTH,
                r.BASE_RISK_SCORE as REGION_RISK
            FROM {DB_SCHEMA}.VENDORS v
            LEFT JOIN {DB_SCHEMA}.REGIONS r ON v.COUNTRY_CODE = r.REGION_CODE
            GROUP BY v.COUNTRY_CODE, r.REGION_NAME, r.BASE_RISK_SCORE
            ORDER BY VENDOR_COUNT DESC
        """).to_pandas()
        return result
    except:
        return None


@st.cache_data(ttl=300)
def load_trade_flow_summary(_session):
    """Load summary of trade flows from external data."""
    try:
        result = _session.sql(f"""
            SELECT 
                SHIPPER_COUNTRY,
                COUNT(DISTINCT SHIPPER_NAME) as SHIPPER_COUNT,
                COUNT(*) as SHIPMENT_COUNT,
                SUM(WEIGHT_KG) as TOTAL_WEIGHT,
                COUNT(DISTINCT CONSIGNEE_NAME) as CONSIGNEE_COUNT
            FROM {DB_SCHEMA}.TRADE_DATA
            GROUP BY SHIPPER_COUNTRY
            ORDER BY SHIPMENT_COUNT DESC
        """).to_pandas()
        return result
    except:
        return None


def render_data_flow_sankey(stats, height=350):
    """Render a Sankey diagram showing data flow from sources to graph using Plotly."""
    
    # Node labels
    labels = [
        "ERP System",
        f"Vendors ({stats.get('VENDORS', {}).get('count', 0)})",
        f"Materials ({stats.get('MATERIALS', {}).get('count', 0)})",
        f"Purchase Orders ({stats.get('PURCHASE_ORDERS', {}).get('count', 0)})",
        f"BOM ({stats.get('BILL_OF_MATERIALS', {}).get('count', 0)})",
        "Trade Intelligence",
        f"Trade Records ({stats.get('TRADE_DATA', {}).get('count', 0)})",
        "Knowledge Graph",
        "GNN Model",
        f"Predictions ({stats.get('PREDICTED_LINKS', {}).get('count', 0)})",
        f"Risk Scores ({stats.get('RISK_SCORES', {}).get('count', 0)})"
    ]
    
    # Node indices: 0=ERP, 1=Vendors, 2=Materials, 3=POs, 4=BOM, 5=Trade Src, 6=Trade, 7=Graph, 8=GNN, 9=Predictions, 10=Risks
    
    # Category colors
    colors = {
        'ERP': '#3b82f6',
        'TRADE': '#f59e0b',
        'GRAPH': '#8b5cf6',
        'INFERENCE': '#10b981'
    }
    
    node_colors = [
        colors['ERP'], colors['ERP'], colors['ERP'], colors['ERP'], colors['ERP'],  # ERP nodes
        colors['TRADE'], colors['TRADE'],  # Trade nodes
        colors['GRAPH'],  # Graph node
        colors['INFERENCE'], colors['INFERENCE'], colors['INFERENCE']  # Inference nodes
    ]
    
    # Links: source, target, value
    sources = [0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 8]
    targets = [1, 2, 3, 4, 7, 7, 7, 7, 6, 7, 8, 9, 10]
    
    values = [
        stats.get('VENDORS', {}).get('count', 1) or 1,
        stats.get('MATERIALS', {}).get('count', 1) or 1,
        max(stats.get('PURCHASE_ORDERS', {}).get('count', 1), 1) // 10 or 1,
        max(stats.get('BILL_OF_MATERIALS', {}).get('count', 1), 1) // 5 or 1,
        stats.get('VENDORS', {}).get('count', 1) or 1,
        stats.get('MATERIALS', {}).get('count', 1) or 1,
        max(stats.get('PURCHASE_ORDERS', {}).get('count', 1), 1) // 10 or 1,
        max(stats.get('BILL_OF_MATERIALS', {}).get('count', 1), 1) // 5 or 1,
        max(stats.get('TRADE_DATA', {}).get('count', 1), 1) // 5 or 1,
        max(stats.get('TRADE_DATA', {}).get('count', 1), 1) // 5 or 1,
        50,
        max(stats.get('PREDICTED_LINKS', {}).get('count', 1), 1) // 3 or 1,
        max(stats.get('RISK_SCORES', {}).get('count', 1), 1) // 3 or 1
    ]
    
    # Link colors (based on source category)
    link_colors = [
        'rgba(59, 130, 246, 0.4)', 'rgba(59, 130, 246, 0.4)', 'rgba(59, 130, 246, 0.4)', 'rgba(59, 130, 246, 0.4)',  # ERP to children
        'rgba(59, 130, 246, 0.4)', 'rgba(59, 130, 246, 0.4)', 'rgba(59, 130, 246, 0.4)', 'rgba(59, 130, 246, 0.4)',  # Children to graph
        'rgba(245, 158, 11, 0.4)', 'rgba(245, 158, 11, 0.4)',  # Trade flow
        'rgba(139, 92, 246, 0.4)',  # Graph to GNN
        'rgba(16, 185, 129, 0.4)', 'rgba(16, 185, 129, 0.4)'  # GNN outputs
    ]
    
    fig = go.Figure(data=[go.Sankey(
        node=dict(
            pad=20,
            thickness=20,
            line=dict(color="#0f172a", width=1),
            label=labels,
            color=node_colors,
            hovertemplate='%{label}<extra></extra>'
        ),
        link=dict(
            source=sources,
            target=targets,
            value=values,
            color=link_colors,
            hovertemplate='%{source.label} → %{target.label}<br>%{value}<extra></extra>'
        )
    )])
    
    fig.update_layout(
        paper_bgcolor='rgba(0,0,0,0)',
        plot_bgcolor='rgba(0,0,0,0)',
        height=height,
        margin=dict(l=0, r=0, t=20, b=20),
        font=dict(color='#e2e8f0', size=11)
    )
    
    st.plotly_chart(fig, use_container_width=True, key="data_flow_sankey")


def main():
    session = get_session()
    
    # Render STAR callout if demo mode is enabled
    render_star_callout("exploratory")
    
    # Load data
    stats = load_data_statistics(session)
    geo_dist = load_geographic_distribution(session)
    trade_flows = load_trade_flow_summary(session)
    
    # ============================================
    # HEADER
    # ============================================
    st.markdown("""
    <div class="page-header">Exploratory Analysis</div>
    <div class="page-subheader">Data sources, coverage analysis, and pipeline status</div>
    """, unsafe_allow_html=True)
    
    # ============================================
    # DATA FLOW VISUALIZATION
    # ============================================
    st.markdown('<div class="section-header">Data Pipeline</div>', unsafe_allow_html=True)
    
    render_data_flow_sankey(stats, height=350)
    
    st.markdown("""
    <p style="text-align: center; color: #64748b; font-size: 0.85rem; margin-top: 0.5rem;">
        <span style="color: #3b82f6;">■</span> Internal ERP Data &nbsp;|&nbsp;
        <span style="color: #f59e0b;">■</span> External Trade Intelligence &nbsp;|&nbsp;
        <span style="color: #8b5cf6;">■</span> Knowledge Graph &nbsp;|&nbsp;
        <span style="color: #10b981;">■</span> GNN Outputs
    </p>
    """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # INTERNAL DATA SOURCES
    # ============================================
    st.markdown("""
    <div class="section-header">ERP Data</div>
    <p style="color: #94a3b8; margin-bottom: 1rem;">
        Internal supply chain data from connected ERP systems.
    </p>
    """, unsafe_allow_html=True)
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        v = stats.get('VENDORS', {})
        st.markdown(f"""
        <div class="data-card">
            <h3>Vendors <span class="internal-badge">ERP</span></h3>
            <div class="data-count">{v.get('count', 0):,}</div>
            <p>{v.get('description', '')}</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        m = stats.get('MATERIALS', {})
        st.markdown(f"""
        <div class="data-card">
            <h3>Materials <span class="internal-badge">ERP</span></h3>
            <div class="data-count">{m.get('count', 0):,}</div>
            <p>{m.get('description', '')}</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        p = stats.get('PURCHASE_ORDERS', {})
        st.markdown(f"""
        <div class="data-card">
            <h3>Purchase Orders <span class="internal-badge">ERP</span></h3>
            <div class="data-count">{p.get('count', 0):,}</div>
            <p>{p.get('description', '')}</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        b = stats.get('BILL_OF_MATERIALS', {})
        st.markdown(f"""
        <div class="data-card">
            <h3>Bill of Materials <span class="internal-badge">ERP</span></h3>
            <div class="data-count">{b.get('count', 0):,}</div>
            <p>{b.get('description', '')}</p>
        </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # THE VISIBILITY GAP
    # ============================================
    st.markdown("""
    <div class="visibility-gap">
        <h3>Coverage Analysis</h3>
        <p style="color: #e2e8f0;">
            ERP data provides Tier-1 visibility. Trade intelligence extends coverage to Tier-2+ suppliers 
            through shipment pattern analysis.
        </p>
    </div>
    """, unsafe_allow_html=True)
    
    # Visual showing the tier gap
    col1, col2, col3, col4, col5 = st.columns([1, 0.3, 1, 0.3, 1])
    
    with col1:
        st.markdown("""
        <div style="text-align: center; padding: 1rem;">
            <div style="background: #166534; border: 2px solid #22c55e; border-radius: 8px; padding: 1rem;">
                <div style="color: #22c55e; font-weight: 700; font-size: 1.2rem;">YOUR COMPANY</div>
                <div style="color: #86efac; font-size: 0.9rem;">Full Visibility ✓</div>
            </div>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown('<div style="text-align: center; padding-top: 1.5rem; color: #64748b; font-size: 2rem;">→</div>', unsafe_allow_html=True)
    
    with col3:
        st.markdown(f"""
        <div style="text-align: center; padding: 1rem;">
            <div style="background: #166534; border: 2px solid #22c55e; border-radius: 8px; padding: 1rem;">
                <div style="color: #22c55e; font-weight: 700; font-size: 1.2rem;">TIER 1</div>
                <div style="color: #86efac; font-size: 0.9rem;">{stats.get('VENDORS', {}).get('count', 0)} Direct Suppliers</div>
                <div style="color: #86efac; font-size: 0.8rem;">Visible in ERP ✓</div>
            </div>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        st.markdown('<div style="text-align: center; padding-top: 1.5rem; color: #64748b; font-size: 2rem;">→</div>', unsafe_allow_html=True)
    
    with col5:
        st.markdown(f"""
        <div style="text-align: center; padding: 1rem;">
            <div style="background: #7f1d1d; border: 2px solid #dc2626; border-radius: 8px; padding: 1rem;">
                <div style="color: #dc2626; font-weight: 700; font-size: 1.2rem;">TIER 2+</div>
                <div style="color: #fca5a5; font-size: 0.9rem;">Hidden Suppliers</div>
                <div style="color: #fca5a5; font-size: 0.8rem;">Unknown until now</div>
            </div>
        </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # EXTERNAL DATA SOURCES
    # ============================================
    st.markdown("""
    <div class="section-header">Trade Intelligence</div>
    <p style="color: #94a3b8; margin-bottom: 1rem;">
        External trade data enrichment for Tier-2+ supplier identification.
    </p>
    """, unsafe_allow_html=True)
    
    col1, col2 = st.columns([1, 1])
    
    with col1:
        t = stats.get('TRADE_DATA', {})
        st.markdown(f"""
        <div class="data-card">
            <h3>Trade Records <span class="external-badge">Trade Intel</span></h3>
            <div class="data-count">{t.get('count', 0):,}</div>
            <p>{t.get('description', '')} — Bills of lading showing who ships to whom</p>
        </div>
        """, unsafe_allow_html=True)
        
        # Show trade flow summary if available
        if trade_flows is not None and not trade_flows.empty:
            st.markdown("**Top Shipping Origins:**")
            for _, row in trade_flows.head(5).iterrows():
                st.markdown(f"- **{row['SHIPPER_COUNTRY']}**: {row['SHIPMENT_COUNT']} shipments, {row['SHIPPER_COUNT']} unique shippers")
    
    with col2:
        r = stats.get('REGIONS', {})
        st.markdown(f"""
        <div class="data-card">
            <h3>Regional Risk Data <span class="external-badge">Enrichment</span></h3>
            <div class="data-count">{r.get('count', 0):,}</div>
            <p>Geographic and geopolitical risk factors by region</p>
        </div>
        """, unsafe_allow_html=True)
        
        # Show geographic distribution if available
        if geo_dist is not None and not geo_dist.empty:
            st.markdown("**Vendor Distribution by Region:**")
            for _, row in geo_dist.head(5).iterrows():
                risk_label = "High" if row.get('REGION_RISK', 0) > 0.5 else "Medium" if row.get('REGION_RISK', 0) > 0.25 else "Low"
                st.markdown(f"- **{row['COUNTRY_CODE']}** ({row.get('REGION_NAME', 'Unknown')}): {row['VENDOR_COUNT']} vendors [{risk_label} risk]")
    
    st.divider()
    
    # ============================================
    # GNN OUTPUTS
    # ============================================
    st.markdown("""
    <div class="section-header">Model Outputs</div>
    <p style="color: #94a3b8; margin-bottom: 1rem;">
        Inferred relationships and calculated risk scores from the graph neural network.
    </p>
    """, unsafe_allow_html=True)
    
    col1, col2 = st.columns(2)
    
    with col1:
        pl = stats.get('PREDICTED_LINKS', {})
        st.markdown(f"""
        <div class="data-card" style="border-color: #10b981;">
            <h3>Predicted Links <span style="background: #166534; color: #fff; padding: 2px 8px; border-radius: 4px; font-size: 0.7rem;">GNN OUTPUT</span></h3>
            <div class="data-count" style="color: #10b981;">{pl.get('count', 0):,}</div>
            <p>{pl.get('description', '')} — Hidden Tier-2+ relationships that the GNN discovered by analyzing trade patterns</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        rs = stats.get('RISK_SCORES', {})
        st.markdown(f"""
        <div class="data-card" style="border-color: #10b981;">
            <h3>Risk Scores <span style="background: #166534; color: #fff; padding: 2px 8px; border-radius: 4px; font-size: 0.7rem;">GNN OUTPUT</span></h3>
            <div class="data-count" style="color: #10b981;">{rs.get('count', 0):,}</div>
            <p>{rs.get('description', '')} — Every node in the graph now has a propagated risk score based on its position in the network</p>
        </div>
        """, unsafe_allow_html=True)
    
    # Sidebar
    render_sidebar()


if __name__ == "__main__":
    main()

