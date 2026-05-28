"""
Scenario Simulator Page

What-if analysis tool for simulating supply chain disruptions and 
understanding cascading impacts through the network.
"""

import streamlit as st
import pandas as pd
import plotly.graph_objects as go
import networkx as nx
import math
import sys
from pathlib import Path
from snowflake.snowpark.context import get_active_session

# Add parent directory to path for utils import (needed for Streamlit in Snowflake)
sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.data_loader import run_queries_parallel, DB_SCHEMA
from utils.sidebar import render_sidebar, render_star_callout
from utils.risk_narratives import (
    render_risk_intelligence_card,
    has_critical_narrative,
    get_region_narrative,
)

st.set_page_config(
    page_title="Scenario Simulator",
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
    .scenario-panel {
        background: rgba(30, 41, 59, 0.8);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1.5rem;
    }
    .impact-card {
        background: linear-gradient(135deg, rgba(220, 38, 38, 0.15) 0%, rgba(245, 158, 11, 0.15) 100%);
        border: 1px solid #dc2626;
        border-radius: 12px;
        padding: 1.5rem;
        margin: 1rem 0;
    }
    .impact-card h3 {
        color: #dc2626;
        font-size: 1.2rem;
        margin-bottom: 0.5rem;
    }
    .impact-card p {
        color: #e2e8f0;
        line-height: 1.6;
    }
    .impact-metric {
        background: rgba(15, 23, 42, 0.8);
        border-radius: 8px;
        padding: 1rem;
        text-align: center;
        margin: 0.5rem 0;
    }
    .impact-metric .value {
        font-size: 2rem;
        font-weight: 800;
        color: #dc2626;
    }
    .impact-metric .label {
        font-size: 0.8rem;
        color: #64748b;
        text-transform: uppercase;
    }
    .affected-item {
        background: rgba(220, 38, 38, 0.1);
        border-left: 3px solid #dc2626;
        border-radius: 0 8px 8px 0;
        padding: 0.75rem 1rem;
        margin: 0.5rem 0;
    }
    .affected-item.indirect {
        background: rgba(245, 158, 11, 0.1);
        border-left-color: #f59e0b;
    }
    .affected-item h5 {
        color: #f8fafc;
        font-size: 0.95rem;
        margin-bottom: 0.25rem;
    }
    .affected-item p {
        color: #94a3b8;
        font-size: 0.85rem;
        margin: 0;
    }
    .scenario-result {
        background: linear-gradient(135deg, rgba(59, 130, 246, 0.1) 0%, rgba(139, 92, 246, 0.1) 100%);
        border: 1px solid #3b82f6;
        border-radius: 12px;
        padding: 1.5rem;
        margin: 1rem 0;
    }
    .alternative-card {
        background: rgba(16, 185, 129, 0.1);
        border: 1px solid #10b981;
        border-radius: 8px;
        padding: 1rem;
        margin: 0.5rem 0;
    }
    .alternative-card h5 {
        color: #10b981;
        font-size: 0.95rem;
        margin-bottom: 0.25rem;
    }
    .alternative-card p {
        color: #94a3b8;
        font-size: 0.85rem;
        margin: 0;
    }
    
    /* Hide default multipage navigation */
    [data-testid="stSidebarNav"] {display: none;}
</style>
""", unsafe_allow_html=True)


@st.cache_resource
def get_session():
    return get_active_session()


@st.cache_data(ttl=300)
def load_regions(_session):
    """Load available regions for simulation."""
    try:
        result = _session.sql(f"""
            SELECT DISTINCT 
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
            HAVING COUNT(v.VENDOR_ID) > 0
            ORDER BY VENDOR_COUNT DESC
        """).to_pandas()
        return result
    except Exception:
        return pd.DataFrame()


@st.cache_data(ttl=300)
def load_bottlenecks(_session):
    """Load bottlenecks for simulation."""
    try:
        result = _session.sql(f"""
            SELECT 
                NODE_ID,
                NODE_TYPE,
                DEPENDENT_COUNT,
                IMPACT_SCORE,
                DESCRIPTION
            FROM {DB_SCHEMA}.BOTTLENECKS
            ORDER BY DEPENDENT_COUNT DESC
        """).to_pandas()
        return result
    except Exception:
        return pd.DataFrame()


@st.cache_data(ttl=300)
def load_vendors_by_region(_session, region_code: str):
    """Load vendors in a specific region."""
    try:
        result = _session.sql(f"""
            SELECT 
                v.VENDOR_ID,
                v.NAME,
                v.COUNTRY_CODE,
                rs.RISK_SCORE,
                rs.RISK_CATEGORY
            FROM {DB_SCHEMA}.VENDORS v
            LEFT JOIN {DB_SCHEMA}.RISK_SCORES rs ON v.VENDOR_ID = rs.NODE_ID
            WHERE v.COUNTRY_CODE = '{region_code}'
            ORDER BY rs.RISK_SCORE DESC NULLS LAST
        """).to_pandas()
        return result
    except Exception:
        return pd.DataFrame()


@st.cache_data(ttl=300)
def load_materials_by_vendors(_session, vendor_ids: list):
    """Load materials supplied by specific vendors."""
    if not vendor_ids:
        return pd.DataFrame()
    
    vendor_list = "','".join(vendor_ids)
    try:
        result = _session.sql(f"""
            SELECT DISTINCT
                m.MATERIAL_ID,
                m.DESCRIPTION,
                m.MATERIAL_GROUP,
                m.CRITICALITY_SCORE,
                po.VENDOR_ID
            FROM {DB_SCHEMA}.PURCHASE_ORDERS po
            JOIN {DB_SCHEMA}.MATERIALS m ON po.MATERIAL_ID = m.MATERIAL_ID
            WHERE po.VENDOR_ID IN ('{vendor_list}')
            ORDER BY m.CRITICALITY_SCORE DESC NULLS LAST
        """).to_pandas()
        return result
    except Exception:
        return pd.DataFrame()


@st.cache_data(ttl=300)
def load_bottleneck_dependents(_session, bottleneck_id: str):
    """Load vendors dependent on a bottleneck."""
    try:
        result = _session.sql(f"""
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
        """).to_pandas()
        return result
    except Exception:
        return pd.DataFrame()


@st.cache_data(ttl=300)
def load_alternative_suppliers(_session, material_ids: list, excluded_vendors: list):
    """Find alternative suppliers for affected materials."""
    if not material_ids:
        return pd.DataFrame()
    
    material_list = "','".join(material_ids[:10])  # Limit to top 10
    if excluded_vendors:
        excluded_list = "','".join(excluded_vendors)
        vendor_exclusion = f"AND v.VENDOR_ID NOT IN ('{excluded_list}')"
    else:
        vendor_exclusion = ""
    
    try:
        result = _session.sql(f"""
            SELECT DISTINCT
                v.VENDOR_ID,
                v.NAME as VENDOR_NAME,
                v.COUNTRY_CODE,
                m.MATERIAL_ID,
                m.DESCRIPTION as MATERIAL_DESC,
                rs.RISK_SCORE
            FROM {DB_SCHEMA}.PURCHASE_ORDERS po
            JOIN {DB_SCHEMA}.VENDORS v ON po.VENDOR_ID = v.VENDOR_ID
            JOIN {DB_SCHEMA}.MATERIALS m ON po.MATERIAL_ID = m.MATERIAL_ID
            LEFT JOIN {DB_SCHEMA}.RISK_SCORES rs ON v.VENDOR_ID = rs.NODE_ID
            WHERE m.MATERIAL_ID IN ('{material_list}')
            {vendor_exclusion}
            ORDER BY rs.RISK_SCORE ASC NULLS LAST
            LIMIT 20
        """).to_pandas()
        return result
    except Exception:
        return pd.DataFrame()


@st.cache_data(ttl=300)
def load_downstream_products(_session, material_ids: list):
    """Find finished products affected by material disruption."""
    if not material_ids:
        return pd.DataFrame()
    
    material_list = "','".join(material_ids[:20])
    
    try:
        # Find products that use these materials (directly or indirectly)
        result = _session.sql(f"""
            WITH RECURSIVE product_tree AS (
                -- Direct parents
                SELECT 
                    PARENT_MATERIAL_ID,
                    CHILD_MATERIAL_ID,
                    1 as LEVEL
                FROM {DB_SCHEMA}.BILL_OF_MATERIALS
                WHERE CHILD_MATERIAL_ID IN ('{material_list}')
                
                UNION ALL
                
                -- Indirect parents
                SELECT 
                    b.PARENT_MATERIAL_ID,
                    pt.CHILD_MATERIAL_ID,
                    pt.LEVEL + 1
                FROM {DB_SCHEMA}.BILL_OF_MATERIALS b
                JOIN product_tree pt ON b.CHILD_MATERIAL_ID = pt.PARENT_MATERIAL_ID
                WHERE pt.LEVEL < 5
            )
            SELECT DISTINCT
                m.MATERIAL_ID,
                m.DESCRIPTION,
                m.MATERIAL_GROUP,
                m.CRITICALITY_SCORE,
                MIN(pt.LEVEL) as IMPACT_LEVEL
            FROM product_tree pt
            JOIN {DB_SCHEMA}.MATERIALS m ON pt.PARENT_MATERIAL_ID = m.MATERIAL_ID
            WHERE m.MATERIAL_GROUP = 'FIN'
            GROUP BY m.MATERIAL_ID, m.DESCRIPTION, m.MATERIAL_GROUP, m.CRITICALITY_SCORE
            ORDER BY IMPACT_LEVEL, m.CRITICALITY_SCORE DESC
            LIMIT 10
        """).to_pandas()
        return result
    except Exception:
        return pd.DataFrame()


def render_impact_network(affected_vendors, affected_materials, disruption_source, height=450):
    """Render network showing disruption propagation."""
    
    if affected_vendors.empty and affected_materials.empty:
        st.info("Select a disruption scenario to see impact visualization.")
        return
    
    # Build network
    G = nx.DiGraph()
    
    # Add disruption source (center)
    G.add_node(disruption_source, node_type='disruption', level=0)
    
    # Add affected vendors
    for _, row in affected_vendors.iterrows():
        vendor_id = row['VENDOR_ID']
        G.add_node(vendor_id, 
                   node_type='vendor',
                   label=row.get('NAME') or row.get('VENDOR_NAME') or vendor_id,
                   level=1)
        G.add_edge(disruption_source, vendor_id)
    
    # Add affected materials
    for _, row in affected_materials.iterrows():
        mat_id = row['MATERIAL_ID']
        if mat_id not in G.nodes():
            G.add_node(mat_id,
                       node_type='material',
                       label=row.get('DESCRIPTION', mat_id)[:25],
                       level=2)
        # Connect to vendor if we have that info
        if 'VENDOR_ID' in row and row['VENDOR_ID'] in G.nodes():
            G.add_edge(row['VENDOR_ID'], mat_id)
    
    # Layout
    pos = nx.spring_layout(G, k=2, iterations=50, seed=42)
    
    # Edge traces
    edge_x, edge_y = [], []
    for edge in G.edges():
        if edge[0] in pos and edge[1] in pos:
            x0, y0 = pos[edge[0]]
            x1, y1 = pos[edge[1]]
            edge_x.extend([x0, x1, None])
            edge_y.extend([y0, y1, None])
    
    edge_trace = go.Scatter(
        x=edge_x, y=edge_y,
        mode='lines',
        line=dict(width=2, color='#dc2626'),
        hoverinfo='none'
    )
    
    # Node traces by type
    node_traces = []
    
    type_config = {
        'disruption': {'color': '#dc2626', 'size': 40, 'symbol': 'diamond', 'name': 'Disruption Source'},
        'vendor': {'color': '#f59e0b', 'size': 25, 'symbol': 'circle', 'name': 'Affected Vendors'},
        'material': {'color': '#8b5cf6', 'size': 18, 'symbol': 'square', 'name': 'Affected Materials'}
    }
    
    for node_type, config in type_config.items():
        nodes = [n for n, d in G.nodes(data=True) if d.get('node_type') == node_type]
        if not nodes:
            continue
        
        node_x = [pos[n][0] for n in nodes if n in pos]
        node_y = [pos[n][1] for n in nodes if n in pos]
        node_text = []
        for n in nodes:
            if n in pos:
                data = G.nodes[n]
                label = data.get('label', n)
                node_text.append(f"<b>{label}</b>")
        
        trace = go.Scatter(
            x=node_x, y=node_y,
            mode='markers',
            marker=dict(
                size=config['size'],
                color=config['color'],
                symbol=config['symbol'],
                line=dict(width=2, color='#0f172a')
            ),
            text=node_text,
            hoverinfo='text',
            name=config['name']
        )
        node_traces.append(trace)
    
    fig = go.Figure(
        data=[edge_trace] + node_traces,
        layout=go.Layout(
            showlegend=True,
            hovermode='closest',
            paper_bgcolor='rgba(0,0,0,0)',
            plot_bgcolor='rgba(0,0,0,0)',
            height=height,
            margin=dict(l=20, r=20, t=20, b=20),
            legend=dict(
                x=0.01, y=0.99,
                bgcolor='rgba(30, 41, 59, 0.9)',
                bordercolor='#334155',
                borderwidth=1,
                font=dict(color='#e2e8f0')
            ),
            xaxis=dict(showgrid=False, zeroline=False, showticklabels=False),
            yaxis=dict(showgrid=False, zeroline=False, showticklabels=False)
        )
    )
    
    st.plotly_chart(fig, use_container_width=True, key="impact_network")


def main():
    session = get_session()
    
    # Render sidebar
    render_sidebar()
    
    # Render STAR callout if demo mode is enabled
    render_star_callout("simulator")
    
    # Load data for scenario selection
    regions = load_regions(session)
    bottlenecks = load_bottlenecks(session)
    
    # ============================================
    # HEADER
    # ============================================
    st.markdown("""
    <div class="page-header">Scenario Simulator</div>
    <div class="page-subheader">What-if analysis: simulate disruptions and understand cascading impacts</div>
    """, unsafe_allow_html=True)
    
    # ============================================
    # SCENARIO SELECTION
    # ============================================
    st.markdown('<div class="section-header">Configure Scenario</div>', unsafe_allow_html=True)
    
    col1, col2 = st.columns([1, 2])
    
    with col1:
        st.markdown("#### Disruption Type")
        
        scenario_type = st.radio(
            "Select disruption type:",
            ["Regional Disruption", "Tier-2 Supplier Failure"],
            help="Choose whether to simulate a regional event or a specific supplier failure"
        )
        
        if scenario_type == "Regional Disruption":
            if not regions.empty:
                region_options = {
                    f"{row['REGION_NAME']} ({row['REGION_CODE']}) - {row['VENDOR_COUNT']} vendors": row['REGION_CODE']
                    for _, row in regions.iterrows()
                }
                selected_region_label = st.selectbox(
                    "Select region:",
                    options=list(region_options.keys()),
                    help="Choose a region to simulate complete supply disruption"
                )
                selected_region = region_options[selected_region_label]
                
                # Show region risk info
                region_info = regions[regions['REGION_CODE'] == selected_region].iloc[0]
                
                # Check if this region has a detailed risk narrative (AUS, COD)
                if has_critical_narrative(selected_region):
                    # Show full Risk Intelligence card
                    st.markdown(
                        render_risk_intelligence_card(selected_region, show_bottleneck=True),
                        unsafe_allow_html=True
                    )
                else:
                    # Show basic region info for other regions
                    st.markdown(f"""
                    <div style="background: rgba(30, 41, 59, 0.6); border-radius: 8px; padding: 1rem; margin-top: 1rem;">
                        <div style="color: #94a3b8; font-size: 0.85rem;">
                            <div>Geopolitical Risk: <strong style="color: #f8fafc;">{region_info['GEOPOLITICAL_RISK']:.0%}</strong></div>
                            <div>Natural Disaster Risk: <strong style="color: #f8fafc;">{region_info['NATURAL_DISASTER_RISK']:.0%}</strong></div>
                            <div>Vendors in Region: <strong style="color: #f8fafc;">{region_info['VENDOR_COUNT']}</strong></div>
                        </div>
                    </div>
                    """, unsafe_allow_html=True)
            else:
                st.warning("No regions with suppliers available.")
                selected_region = None
            
            selected_bottleneck = None
        else:
            if not bottlenecks.empty:
                bottleneck_options = {
                    f"{row['NODE_ID']} ({row['DEPENDENT_COUNT']} dependents)": row['NODE_ID']
                    for _, row in bottlenecks.iterrows()
                }
                selected_bottleneck_label = st.selectbox(
                    "Select Tier-2 supplier:",
                    options=list(bottleneck_options.keys()),
                    help="Choose a hidden Tier-2 supplier to simulate failure"
                )
                selected_bottleneck = bottleneck_options[selected_bottleneck_label]
                
                # Show bottleneck info
                bottleneck_info = bottlenecks[bottlenecks['NODE_ID'] == selected_bottleneck].iloc[0]
                st.markdown(f"""
                <div style="background: rgba(30, 41, 59, 0.6); border-radius: 8px; padding: 1rem; margin-top: 1rem;">
                    <div style="color: #94a3b8; font-size: 0.85rem;">
                        <div>Impact Score: <strong style="color: #dc2626;">{bottleneck_info['IMPACT_SCORE']:.0%}</strong></div>
                        <div>Dependent Vendors: <strong style="color: #f8fafc;">{bottleneck_info['DEPENDENT_COUNT']}</strong></div>
                        <div style="margin-top: 0.5rem; color: #64748b; font-size: 0.8rem;">{bottleneck_info.get('DESCRIPTION', 'Hidden supply chain convergence point')}</div>
                    </div>
                </div>
                """, unsafe_allow_html=True)
            else:
                st.warning("No bottlenecks identified. Run the GNN notebook first.")
                selected_bottleneck = None
            
            selected_region = None
        
        # Simulation button
        st.markdown("")
        run_simulation = st.button("Run Simulation", type="primary", use_container_width=True)
    
    with col2:
        st.markdown("#### Impact Preview")
        
        # Run simulation and show results
        affected_vendors = pd.DataFrame()
        affected_materials = pd.DataFrame()
        disruption_source = ""
        
        if run_simulation or st.session_state.get('last_simulation'):
            # Store simulation state
            if run_simulation:
                st.session_state['last_simulation'] = {
                    'type': scenario_type,
                    'region': selected_region,
                    'bottleneck': selected_bottleneck
                }
            
            sim_state = st.session_state.get('last_simulation', {})
            
            if sim_state.get('type') == "Regional Disruption" and sim_state.get('region'):
                region = sim_state['region']
                disruption_source = f"Region: {region}"
                
                # Get affected vendors
                affected_vendors = load_vendors_by_region(session, region)
                
                if not affected_vendors.empty:
                    vendor_ids = affected_vendors['VENDOR_ID'].tolist()
                    affected_materials = load_materials_by_vendors(session, vendor_ids)
            
            elif sim_state.get('type') == "Tier-2 Supplier Failure" and sim_state.get('bottleneck'):
                bottleneck = sim_state['bottleneck']
                disruption_source = bottleneck
                
                # Get dependent vendors
                dependents = load_bottleneck_dependents(session, bottleneck)
                if not dependents.empty:
                    affected_vendors = dependents.copy()
                    affected_vendors['NAME'] = affected_vendors['VENDOR_NAME']
                    vendor_ids = affected_vendors['VENDOR_ID'].dropna().tolist()
                    affected_materials = load_materials_by_vendors(session, vendor_ids)
        
        # Render impact network
        render_impact_network(affected_vendors, affected_materials, disruption_source, height=380)
    
    # ============================================
    # IMPACT ANALYSIS
    # ============================================
    if not affected_vendors.empty or not affected_materials.empty:
        st.divider()
        st.markdown('<div class="section-header">Impact Analysis</div>', unsafe_allow_html=True)
        
        # Impact metrics
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            st.markdown(f"""
            <div class="impact-metric">
                <div class="value">{len(affected_vendors)}</div>
                <div class="label">Vendors Affected</div>
            </div>
            """, unsafe_allow_html=True)
        
        with col2:
            st.markdown(f"""
            <div class="impact-metric">
                <div class="value">{len(affected_materials)}</div>
                <div class="label">Materials at Risk</div>
            </div>
            """, unsafe_allow_html=True)
        
        with col3:
            # Count high criticality materials
            high_crit = len(affected_materials[affected_materials['CRITICALITY_SCORE'].fillna(0) >= 0.7]) if not affected_materials.empty else 0
            st.markdown(f"""
            <div class="impact-metric">
                <div class="value">{high_crit}</div>
                <div class="label">Critical Materials</div>
            </div>
            """, unsafe_allow_html=True)
        
        with col4:
            # Get downstream products
            if not affected_materials.empty:
                downstream = load_downstream_products(session, affected_materials['MATERIAL_ID'].tolist())
                downstream_count = len(downstream)
            else:
                downstream = pd.DataFrame()
                downstream_count = 0
            
            st.markdown(f"""
            <div class="impact-metric">
                <div class="value">{downstream_count}</div>
                <div class="label">Products Impacted</div>
            </div>
            """, unsafe_allow_html=True)
        
        # Detailed impact breakdown
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("#### Affected Vendors")
            if not affected_vendors.empty:
                for _, row in affected_vendors.head(10).iterrows():
                    name = row.get('NAME') or row.get('VENDOR_NAME') or row['VENDOR_ID']
                    country = row.get('COUNTRY_CODE', 'Unknown')
                    risk = row.get('RISK_SCORE', 0) or 0
                    
                    st.markdown(f"""
                    <div class="affected-item">
                        <h5>{name}</h5>
                        <p>Country: {country} · Risk Score: {risk:.0%}</p>
                    </div>
                    """, unsafe_allow_html=True)
                
                if len(affected_vendors) > 10:
                    st.caption(f"+ {len(affected_vendors) - 10} more vendors affected")
            else:
                st.info("No vendors directly affected.")
        
        with col2:
            st.markdown("#### Materials at Risk")
            if not affected_materials.empty:
                for _, row in affected_materials.head(10).iterrows():
                    desc = row.get('DESCRIPTION', row['MATERIAL_ID'])
                    group = row.get('MATERIAL_GROUP', 'Unknown')
                    crit = row.get('CRITICALITY_SCORE', 0) or 0
                    
                    css_class = "" if crit >= 0.7 else "indirect"
                    
                    st.markdown(f"""
                    <div class="affected-item {css_class}">
                        <h5>{desc[:40]}</h5>
                        <p>Type: {group} · Criticality: {crit:.0%}</p>
                    </div>
                    """, unsafe_allow_html=True)
                
                if len(affected_materials) > 10:
                    st.caption(f"+ {len(affected_materials) - 10} more materials at risk")
            else:
                st.info("No materials directly affected.")
        
        st.divider()
        
        # ============================================
        # MITIGATION OPTIONS
        # ============================================
        st.markdown('<div class="section-header">Mitigation Options</div>', unsafe_allow_html=True)
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("#### Alternative Suppliers")
            
            if not affected_materials.empty and not affected_vendors.empty:
                material_ids = affected_materials['MATERIAL_ID'].tolist()
                excluded = affected_vendors['VENDOR_ID'].tolist()
                alternatives = load_alternative_suppliers(session, material_ids, excluded)
                
                if not alternatives.empty:
                    for _, row in alternatives.head(8).iterrows():
                        name = row.get('VENDOR_NAME', row['VENDOR_ID'])
                        country = row.get('COUNTRY_CODE', 'Unknown')
                        risk = row.get('RISK_SCORE', 0) or 0
                        material = row.get('MATERIAL_DESC', '')[:30]
                        
                        st.markdown(f"""
                        <div class="alternative-card">
                            <h5>{name}</h5>
                            <p>Country: {country} · Risk: {risk:.0%}<br>Can supply: {material}</p>
                        </div>
                        """, unsafe_allow_html=True)
                else:
                    st.info("No alternative suppliers found for affected materials.")
            else:
                st.info("Run a simulation to see alternative supplier options.")
        
        with col2:
            st.markdown("#### Downstream Impact")
            
            if not downstream.empty:
                st.markdown("""
                <div class="impact-card">
                    <h3>Production at Risk</h3>
                    <p>The following finished products may be affected by this disruption:</p>
                </div>
                """, unsafe_allow_html=True)
                
                for _, row in downstream.iterrows():
                    desc = row.get('DESCRIPTION', row['MATERIAL_ID'])
                    level = row.get('IMPACT_LEVEL', 1)
                    crit = row.get('CRITICALITY_SCORE', 0) or 0
                    
                    impact_label = "Direct" if level == 1 else f"Level {level}"
                    
                    st.markdown(f"""
                    <div class="affected-item indirect">
                        <h5>{desc[:40]}</h5>
                        <p>Impact: {impact_label} · Criticality: {crit:.0%}</p>
                    </div>
                    """, unsafe_allow_html=True)
            else:
                st.info("No downstream products identified.")
        
        # Summary insight
        st.markdown(f"""
        <div class="scenario-result">
            <h3 style="color: #3b82f6; margin-bottom: 0.5rem;">Scenario Summary</h3>
            <p style="color: #e2e8f0; line-height: 1.6;">
                A disruption at <strong>{disruption_source}</strong> would directly affect 
                <strong>{len(affected_vendors)} vendor(s)</strong> and put 
                <strong>{len(affected_materials)} material(s)</strong> at risk.
                {f"This could cascade to impact <strong>{downstream_count} finished product(s)</strong>." if downstream_count > 0 else ""}
                {f"We identified <strong>{len(alternatives) if 'alternatives' in dir() and not alternatives.empty else 0} alternative supplier(s)</strong> that could help mitigate this risk." if not affected_materials.empty else ""}
            </p>
        </div>
        """, unsafe_allow_html=True)
    
    else:
        # No simulation run yet
        st.markdown("""
        <div class="scenario-result">
            <h3 style="color: #3b82f6; margin-bottom: 0.5rem;">How to Use</h3>
            <p style="color: #e2e8f0; line-height: 1.6;">
                1. Select a <strong>disruption type</strong> — regional event or specific Tier-2 supplier failure<br>
                2. Choose the <strong>affected region or supplier</strong> from the dropdown<br>
                3. Click <strong>Run Simulation</strong> to see cascading impacts<br>
                4. Review affected vendors, materials, and alternative suppliers
            </p>
        </div>
        """, unsafe_allow_html=True)


if __name__ == "__main__":
    main()

