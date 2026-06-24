"""
Tier-2 Analysis Page

Analysis of inferred Tier-2+ supplier dependencies and concentration risks.
"""

import streamlit as st
import json
import plotly.graph_objects as go
import plotly.express as px
import sys
from pathlib import Path
from snowflake.snowpark.context import get_active_session

# Add parent directory to path for utils import (needed for Streamlit in Snowflake)
sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.data_loader import run_queries_parallel, DB_SCHEMA
from utils.sidebar import render_sidebar, render_star_callout
from utils.risk_narratives import (
    render_risk_intelligence_card,
    render_compact_risk_card,
    get_region_for_bottleneck,
    get_region_narrative,
)

st.set_page_config(
    page_title="Tier-2 Analysis",
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
    .concentration-alert {
        background: rgba(220, 38, 38, 0.1);
        border: 1px solid #dc2626;
        border-radius: 12px;
        padding: 1.5rem;
        margin: 1rem 0;
    }
    .concentration-alert h3 {
        color: #dc2626;
        font-size: 1.2rem;
        margin-bottom: 0.5rem;
    }
    .concentration-alert .value {
        color: #f8fafc;
        font-weight: 700;
    }
    .bottleneck-card {
        background: rgba(30, 41, 59, 0.8);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1.5rem;
        margin: 1rem 0;
        border-left: 4px solid #dc2626;
    }
    .bottleneck-card.high {
        border-left-color: #ea580c;
    }
    .bottleneck-card.medium {
        border-left-color: #ca8a04;
    }
    .bottleneck-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 0.75rem;
    }
    .bottleneck-name {
        font-size: 1.1rem;
        font-weight: 700;
        color: #f8fafc;
    }
    .impact-badge {
        padding: 4px 12px;
        border-radius: 20px;
        font-size: 0.8rem;
        font-weight: 600;
    }
    .impact-critical {
        background: #dc2626;
        color: #fff;
    }
    .impact-high {
        background: #ea580c;
        color: #fff;
    }
    .impact-medium {
        background: #ca8a04;
        color: #fff;
    }
    .bottleneck-stats {
        display: flex;
        gap: 2rem;
        margin: 1rem 0;
        color: #94a3b8;
        font-size: 0.9rem;
    }
    .bottleneck-description {
        color: #cbd5e1;
        font-size: 0.95rem;
        line-height: 1.5;
    }
    .evidence-section {
        background: rgba(15, 23, 42, 0.5);
        border-radius: 8px;
        padding: 1rem;
        margin-top: 1rem;
    }
    .evidence-title {
        color: #64748b;
        font-size: 0.8rem;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        margin-bottom: 0.5rem;
    }
    .vendor-chip {
        display: inline-block;
        background: #1e3a5f;
        color: #93c5fd;
        padding: 4px 10px;
        border-radius: 4px;
        margin: 2px;
        font-size: 0.8rem;
    }
    .stat-card {
        background: rgba(30, 41, 59, 0.8);
        border: 1px solid #334155;
        border-radius: 8px;
        padding: 1rem;
        text-align: center;
    }
    .stat-value {
        font-size: 2rem;
        font-weight: 800;
        color: #f8fafc;
    }
    .stat-value.warning { color: #f59e0b; }
    .stat-value.danger { color: #dc2626; }
    .stat-label {
        font-size: 0.8rem;
        color: #64748b;
        text-transform: uppercase;
    }
    
    /* Hide default multipage navigation */
    [data-testid="stSidebarNav"] {display: none;}
</style>
""", unsafe_allow_html=True)


@st.cache_resource
def get_session():
    return get_active_session()


@st.cache_data(ttl=300)
def load_discovery_summary(_session):
    """Load summary statistics about discoveries using parallel query execution."""
    
    # Define all queries for parallel execution (5 queries)
    queries = {
        'total_bottlenecks': f"SELECT COUNT(*) as CNT FROM {DB_SCHEMA}.BOTTLENECKS",
        'critical_bottlenecks': f"SELECT COUNT(*) as CNT FROM {DB_SCHEMA}.BOTTLENECKS WHERE IMPACT_SCORE >= 0.7",
        'predicted_links': f"SELECT COUNT(*) as CNT FROM {DB_SCHEMA}.PREDICTED_LINKS",
        'high_confidence_links': f"SELECT COUNT(*) as CNT FROM {DB_SCHEMA}.PREDICTED_LINKS WHERE PROBABILITY >= 0.7",
        'total_dependencies': f"SELECT COALESCE(SUM(DEPENDENT_COUNT), 0) as CNT FROM {DB_SCHEMA}.BOTTLENECKS"
    }
    
    # Execute all queries in parallel
    results = run_queries_parallel(_session, queries, max_workers=4)
    
    # Process results into summary format
    summary = {}
    for key in queries:
        df = results.get(key)
        if df is not None and not df.empty:
            summary[key] = int(df['CNT'].iloc[0])
        else:
            summary[key] = 0
    
    return summary


@st.cache_data(ttl=300)
def load_all_bottlenecks(_session):
    """Load all identified bottlenecks with details."""
    try:
        result = _session.sql(f"""
            SELECT 
                NODE_ID,
                NODE_TYPE,
                DEPENDENT_COUNT,
                IMPACT_SCORE,
                DESCRIPTION,
                MITIGATION_STATUS,
                IDENTIFIED_AT
            FROM {DB_SCHEMA}.BOTTLENECKS
            ORDER BY IMPACT_SCORE DESC
        """).to_pandas()
        return result
    except:
        return None


@st.cache_data(ttl=300)
def load_bottleneck_dependents(_session, bottleneck_id):
    """Load vendors dependent on a specific bottleneck."""
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
    except:
        return None


@st.cache_data(ttl=300)
def load_trade_evidence(_session, bottleneck_id):
    """Load trade data evidence for a bottleneck."""
    try:
        result = _session.sql(f"""
            SELECT 
                CONSIGNEE_NAME,
                HS_CODE,
                HS_DESCRIPTION,
                SUM(WEIGHT_KG) as TOTAL_WEIGHT,
                COUNT(*) as SHIPMENT_COUNT,
                SUM(VALUE_USD) as TOTAL_VALUE
            FROM {DB_SCHEMA}.TRADE_DATA
            WHERE SHIPPER_NAME = '{bottleneck_id}'
            GROUP BY CONSIGNEE_NAME, HS_CODE, HS_DESCRIPTION
            ORDER BY TOTAL_WEIGHT DESC
        """).to_pandas()
        return result
    except:
        return None


@st.cache_data(ttl=300)
def load_all_predicted_links(_session, min_probability=0.3):
    """Load all predicted links."""
    try:
        result = _session.sql(f"""
            SELECT 
                SOURCE_NODE_ID,
                SOURCE_NODE_TYPE,
                TARGET_NODE_ID,
                TARGET_NODE_TYPE,
                PROBABILITY,
                EVIDENCE_STRENGTH,
                PREDICTED_AT
            FROM {DB_SCHEMA}.PREDICTED_LINKS
            WHERE PROBABILITY >= {min_probability}
            ORDER BY PROBABILITY DESC
        """).to_pandas()
        return result
    except:
        return None


@st.cache_data(ttl=300)
def prefetch_all_bottleneck_dependents(_session, bottleneck_ids: list):
    """
    Prefetch dependents for all bottlenecks in parallel.
    Returns dict mapping bottleneck_id -> DataFrame of dependents.
    """
    if not bottleneck_ids:
        return {}
    
    # Build queries for each bottleneck
    queries = {}
    for bid in bottleneck_ids:
        queries[bid] = f"""
            SELECT 
                pl.TARGET_NODE_ID as VENDOR_ID,
                v.NAME as VENDOR_NAME,
                v.COUNTRY_CODE,
                pl.PROBABILITY,
                rs.RISK_SCORE
            FROM {DB_SCHEMA}.PREDICTED_LINKS pl
            LEFT JOIN {DB_SCHEMA}.VENDORS v ON pl.TARGET_NODE_ID = v.VENDOR_ID
            LEFT JOIN {DB_SCHEMA}.RISK_SCORES rs ON v.VENDOR_ID = rs.NODE_ID
            WHERE pl.SOURCE_NODE_ID = '{bid}'
            ORDER BY pl.PROBABILITY DESC
        """
    
    # Execute all queries in parallel
    return run_queries_parallel(_session, queries, max_workers=4)


@st.cache_data(ttl=600)
def prefetch_all_ai_analyses(_session, bottleneck_data: list):
    """
    Prefetch AI analyses for all bottlenecks in parallel.
    bottleneck_data: list of dicts with node_id, dependent_count, impact_score, mitigation_status
    Returns dict mapping node_id -> AI analysis text.
    """
    from concurrent.futures import ThreadPoolExecutor, as_completed
    
    if not bottleneck_data:
        return {}
    
    def generate_single_analysis(data: dict) -> tuple:
        """Generate AI analysis for a single bottleneck."""
        node_id = data.get('node_id', 'Unknown')
        try:
            prompt = f"""You are a supply chain risk analyst. Provide a brief risk assessment for this concentration point in 2-3 sentences.

Bottleneck: {node_id}
- Dependent Vendors: {data.get('dependent_count', 0)}
- Impact Score: {data.get('impact_score', 0):.0%}
- Mitigation Status: {data.get('mitigation_status', 'UNMITIGATED')}

Explain the specific risk this creates and one key mitigation action.

Output only the analysis. No preamble, headers, or follow-up questions."""

            escaped_prompt = prompt.replace("'", "''")
            
            result = _session.sql(f"""
                SELECT SNOWFLAKE.CORTEX.COMPLETE(
                    'llama3.1-70b',
                    '{escaped_prompt}'
                ) as RESPONSE
            """).to_pandas()
            
            if not result.empty and result['RESPONSE'].iloc[0]:
                return node_id, result['RESPONSE'].iloc[0].strip()
            return node_id, None
        except Exception:
            return node_id, None
    
    # Execute all AI calls in parallel
    results = {}
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = {executor.submit(generate_single_analysis, data): data['node_id'] 
                   for data in bottleneck_data}
        
        for future in as_completed(futures):
            try:
                node_id, analysis = future.result()
                results[node_id] = analysis
            except Exception:
                pass
    
    return results


@st.cache_data(ttl=600)
def generate_ai_analysis(_session, context_type: str, context_data: dict):
    """Generate AI analysis using Snowflake Cortex COMPLETE."""
    try:
        if context_type == "concentration_risk":
            prompt = f"""You are a supply chain risk analyst. Analyze this concentration risk finding and explain its business implications in 2-3 concise sentences.

Context:
- Hidden Tier-2 Supplier: {context_data.get('node_id', 'Unknown')}
- Number of your Tier-1 vendors dependent on this supplier: {context_data.get('dependent_count', 0)}
- Impact Score: {context_data.get('impact_score', 0):.0%}
- Description: {context_data.get('description', 'Supply chain convergence point')}

Explain why this is a risk and what could happen if this supplier experiences disruption. Be specific and actionable.

Output only the analysis. No preamble, headers, or follow-up questions."""

        elif context_type == "bottleneck_detail":
            prompt = f"""You are a supply chain risk analyst. Provide a brief risk assessment for this concentration point in 2-3 sentences.

Bottleneck: {context_data.get('node_id', 'Unknown')}
- Dependent Vendors: {context_data.get('dependent_count', 0)}
- Impact Score: {context_data.get('impact_score', 0):.0%}
- Mitigation Status: {context_data.get('mitigation_status', 'UNMITIGATED')}

Explain the specific risk this creates and one key mitigation action.

Output only the analysis. No preamble, headers, or follow-up questions."""

        elif context_type == "links_summary":
            prompt = f"""You are a supply chain analyst. Summarize these link prediction findings in 2-3 sentences.

Analysis Results:
- Total predicted hidden relationships: {context_data.get('total_links', 0)}
- High confidence predictions (>70%): {context_data.get('high_confidence', 0)}
- Average confidence level: {context_data.get('avg_confidence', 0):.0%}

Explain what these hidden links mean for supply chain visibility and risk management.

Output only the analysis. No preamble, headers, or follow-up questions."""

        else:
            return None

        # Escape single quotes in prompt
        escaped_prompt = prompt.replace("'", "''")
        
        result = _session.sql(f"""
            SELECT SNOWFLAKE.CORTEX.COMPLETE(
                'llama3.1-70b',
                '{escaped_prompt}'
            ) as RESPONSE
        """).to_pandas()
        
        if not result.empty and result['RESPONSE'].iloc[0]:
            return result['RESPONSE'].iloc[0].strip()
        return None
    except Exception as e:
        return None


def render_ego_graph(center_id, center_label, dependents, height=400):
    """Render ego-centric graph for a bottleneck using Plotly."""
    
    if dependents is None or dependents.empty:
        st.info("No dependency data available.")
        return
    
    import math
    
    # Prepare node data
    num_dependents = len(dependents)
    
    # Calculate positions in a circle
    center_x, center_y = 0, 0
    radius = 2
    
    dep_x = []
    dep_y = []
    dep_text = []
    dep_colors = []
    
    for i, (_, row) in enumerate(dependents.iterrows()):
        angle = (2 * math.pi * i / num_dependents) - (math.pi / 2)
        x = center_x + radius * math.cos(angle)
        y = center_y + radius * math.sin(angle)
        dep_x.append(x)
        dep_y.append(y)
        
        name = row['VENDOR_NAME'] or row['VENDOR_ID']
        risk = float(row['RISK_SCORE']) if row['RISK_SCORE'] else 0.5
        prob = float(row['PROBABILITY']) if row['PROBABILITY'] else 0
        
        dep_text.append(f"<b>{name}</b><br>Country: {row['COUNTRY_CODE']}<br>Confidence: {prob:.0%}<br>Risk: {risk:.0%}")
        dep_colors.append('#ea580c' if risk >= 0.5 else '#3b82f6')
    
    # Create edge traces
    edge_x = []
    edge_y = []
    for x, y in zip(dep_x, dep_y):
        edge_x.extend([center_x, x, None])
        edge_y.extend([center_y, y, None])
    
    edge_trace = go.Scatter(
        x=edge_x, y=edge_y,
        mode='lines',
        line=dict(width=2, color='#f59e0b', dash='dash'),
        hoverinfo='none'
    )
    
    # Center node
    center_trace = go.Scatter(
        x=[center_x], y=[center_y],
        mode='markers+text',
        marker=dict(size=50, color='#dc2626', line=dict(width=3, color='#0f172a')),
        text=[str(num_dependents)],
        textposition='middle center',
        textfont=dict(size=16, color='white', family='Arial Black'),
        hovertext=f"<b>{center_label}</b><br>Dependents: {num_dependents}",
        hoverinfo='text',
        name='Bottleneck'
    )
    
    # Dependent nodes
    dep_trace = go.Scatter(
        x=dep_x, y=dep_y,
        mode='markers',
        marker=dict(size=28, color=dep_colors, line=dict(width=2, color='#0f172a')),
        hovertext=dep_text,
        hoverinfo='text',
        name='Affected Vendors'
    )
    
    # Labels for dependents
    label_y = [y - 0.4 for y in dep_y]
    labels = [str(row['VENDOR_NAME'] or row['VENDOR_ID'])[:12] for _, row in dependents.iterrows()]
    
    label_trace = go.Scatter(
        x=dep_x, y=label_y,
        mode='text',
        text=labels,
        textfont=dict(size=9, color='#cbd5e1'),
        hoverinfo='none'
    )
    
    # Center label
    center_label_trace = go.Scatter(
        x=[center_x], y=[center_y - 0.6],
        mode='text',
        text=[center_label[:25]],
        textfont=dict(size=11, color='#f8fafc', family='Arial'),
        hoverinfo='none'
    )
    
    fig = go.Figure(
        data=[edge_trace, dep_trace, center_trace, label_trace, center_label_trace],
        layout=go.Layout(
            showlegend=False,
            hovermode='closest',
            paper_bgcolor='rgba(0,0,0,0)',
            plot_bgcolor='rgba(0,0,0,0)',
            height=height,
            margin=dict(b=20, l=20, r=20, t=20),
            xaxis=dict(showgrid=False, zeroline=False, showticklabels=False, range=[-3.5, 3.5]),
            yaxis=dict(showgrid=False, zeroline=False, showticklabels=False, range=[-3.5, 3.5])
        )
    )
    
    st.plotly_chart(fig, use_container_width=True, key="ego_graph")


def main():
    session = get_session()
    
    # Render sidebar immediately (before heavy data loading)
    render_sidebar()
    
    # Render STAR callout if demo mode is enabled
    render_star_callout("tier2")
    
    # Load data
    summary = load_discovery_summary(session)
    bottlenecks = load_all_bottlenecks(session)
    
    # ============================================
    # HEADER
    # ============================================
    st.markdown("""
    <div class="page-header">Tier-2 Analysis</div>
    <div class="page-subheader">Inferred supplier dependencies and concentration risks</div>
    """, unsafe_allow_html=True)
    
    # ============================================
    # DISCOVERY SUMMARY
    # ============================================
    col1, col2, col3, col4, col5 = st.columns(5)
    
    with col1:
        st.markdown(f"""
        <div class="stat-card">
            <div class="stat-value danger">{summary.get('total_bottlenecks', 0)}</div>
            <div class="stat-label">Bottlenecks Found</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown(f"""
        <div class="stat-card">
            <div class="stat-value danger">{summary.get('critical_bottlenecks', 0)}</div>
            <div class="stat-label">Critical (≥70%)</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown(f"""
        <div class="stat-card">
            <div class="stat-value warning">{summary.get('predicted_links', 0)}</div>
            <div class="stat-label">Hidden Links</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        st.markdown(f"""
        <div class="stat-card">
            <div class="stat-value">{summary.get('high_confidence_links', 0)}</div>
            <div class="stat-label">High Confidence</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col5:
        st.markdown(f"""
        <div class="stat-card">
            <div class="stat-value warning">{summary.get('total_dependencies', 0)}</div>
            <div class="stat-label">At-Risk Vendors</div>
        </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # TOP CONCENTRATION RISK
    # ============================================
    if bottlenecks is not None and not bottlenecks.empty:
        top_bottleneck = bottlenecks.iloc[0]
        
        st.markdown(f"""
        <div class="concentration-alert">
            <h3>Highest Concentration Risk</h3>
            <p style="color: #e2e8f0;">
                <span class="value">{top_bottleneck['NODE_ID']}</span> — Tier-2 supplier with 
                <span class="value">{top_bottleneck['DEPENDENT_COUNT']}</span> dependent Tier-1 vendors
            </p>
            <p style="color: #94a3b8; font-size: 0.9rem; margin-top: 0.5rem;">
                Impact Score: {top_bottleneck['IMPACT_SCORE']:.0%} · 
                {top_bottleneck.get('DESCRIPTION', 'Supply chain convergence point')}
            </p>
        </div>
        """, unsafe_allow_html=True)
        
        # AI-generated detailed analysis
        with st.spinner("Generating AI analysis..."):
            ai_analysis = generate_ai_analysis(session, "concentration_risk", {
                'node_id': top_bottleneck['NODE_ID'],
                'dependent_count': top_bottleneck['DEPENDENT_COUNT'],
                'impact_score': top_bottleneck['IMPACT_SCORE'],
                'description': top_bottleneck.get('DESCRIPTION', 'Supply chain convergence point')
            })
        
        if ai_analysis:
            st.markdown(f"""
            <div style="background: rgba(59, 130, 246, 0.1); border: 1px solid #3b82f6; border-radius: 8px; padding: 1rem; margin: 1rem 0;">
                <div style="color: #3b82f6; font-size: 0.8rem; text-transform: uppercase; margin-bottom: 0.5rem;">
                    AI Risk Analysis
                </div>
                <p style="color: #e2e8f0; line-height: 1.6; margin: 0;">
                    {ai_analysis}
                </p>
            </div>
            """, unsafe_allow_html=True)
        
        # Show Regional Risk Context if this bottleneck has a critical region association
        region_code = get_region_for_bottleneck(top_bottleneck['NODE_ID'])
        if region_code:
            st.markdown("#### Regional Risk Context")
            st.markdown(
                render_risk_intelligence_card(region_code, show_bottleneck=False),
                unsafe_allow_html=True
            )
        
        # Load details for the top bottleneck
        dependents = load_bottleneck_dependents(session, top_bottleneck['NODE_ID'])
        trade_evidence = load_trade_evidence(session, top_bottleneck['NODE_ID'])
        
        col1, col2 = st.columns([1, 1])
        
        with col1:
            st.markdown("#### Dependency Network")
            if dependents is not None and not dependents.empty:
                render_ego_graph(
                    top_bottleneck['NODE_ID'],
                    top_bottleneck['NODE_ID'],
                    dependents,
                    height=380
                )
            else:
                st.info("No dependency data available.")
        
        with col2:
            st.markdown("#### Trade Evidence")
            if trade_evidence is not None and not trade_evidence.empty:
                st.markdown(f"""
                <div class="evidence-section">
                    <div class="evidence-title">Shipments from {top_bottleneck['NODE_ID']}</div>
                </div>
                """, unsafe_allow_html=True)
                
                # Summary stats
                total_shipments = trade_evidence['SHIPMENT_COUNT'].sum()
                total_weight = trade_evidence['TOTAL_WEIGHT'].sum()
                total_value = trade_evidence['TOTAL_VALUE'].sum()
                
                st.markdown(f"""
                - **{total_shipments:,}** total shipments
                - **{total_weight:,.0f} kg** total weight
                - **${total_value:,.0f}** total value
                """)
                
                # Consignee display in scrollable container
                unique_consignees = trade_evidence['CONSIGNEE_NAME'].unique()
                st.markdown(f"**Consignees (Your Tier-1 Suppliers):** {len(unique_consignees)} companies")
                
                # Show all consignees in a scrollable chip container
                all_chips = ''.join([f'<span class="vendor-chip">{name}</span> ' for name in unique_consignees])
                st.markdown(f"""
                <div style="max-height: 120px; overflow-y: auto; padding: 8px; background: rgba(15, 23, 42, 0.5); border-radius: 8px;">
                    {all_chips}
                </div>
                """, unsafe_allow_html=True)
                
                st.markdown("")
                st.markdown(f"**Primary Commodity:** {trade_evidence.iloc[0]['HS_DESCRIPTION']}")
            else:
                st.info("No trade evidence available for this supplier.")
            
            # Affected vendors list - show as compact bar chart
            if dependents is not None and not dependents.empty:
                st.markdown("#### Affected Tier-1 Vendors")
                
                # Create a horizontal bar chart of confidence levels
                dep_df = dependents.copy()
                dep_df['NAME'] = dep_df['VENDOR_NAME'].fillna(dep_df['VENDOR_ID'])
                dep_df['PROB'] = dep_df['PROBABILITY'].fillna(0) * 100
                dep_df['RISK'] = dep_df['RISK_SCORE'].fillna(0)
                dep_df['COLOR'] = dep_df['RISK'].apply(lambda x: '#dc2626' if x >= 0.5 else '#f59e0b' if x >= 0.25 else '#16a34a')
                
                # Sort by probability descending
                dep_df = dep_df.sort_values('PROB', ascending=True).tail(10)
                
                fig = go.Figure(go.Bar(
                    y=[f"{r['NAME'][:20]} ({r['COUNTRY_CODE']})" for _, r in dep_df.iterrows()],
                    x=dep_df['PROB'],
                    orientation='h',
                    marker_color=dep_df['COLOR'].tolist(),
                    text=[f"{p:.0f}%" for p in dep_df['PROB']],
                    textposition='auto',
                    hovertemplate='<b>%{y}</b><br>Confidence: %{x:.0f}%<extra></extra>'
                ))
                
                fig.update_layout(
                    paper_bgcolor='rgba(0,0,0,0)',
                    plot_bgcolor='rgba(0,0,0,0)',
                    height=min(300, len(dep_df) * 30 + 50),
                    margin=dict(l=0, r=0, t=10, b=0),
                    xaxis=dict(title=dict(text='Confidence %', font=dict(color='#94a3b8')), tickfont=dict(color='#94a3b8'), showgrid=False, range=[0, 100]),
                    yaxis=dict(tickfont=dict(color='#e2e8f0', size=10), showgrid=False),
                    font=dict(color='#e2e8f0')
                )
                
                st.plotly_chart(fig, use_container_width=True, key="affected_vendors")
    
    st.divider()
    
    # ============================================
    # ALL BOTTLENECKS (Scrollable Cards)
    # ============================================
    st.markdown('<div class="section-header">Concentration Points</div>', unsafe_allow_html=True)
    st.markdown("""
    <p style="color: #94a3b8; margin-bottom: 1rem;">
        Tier-2+ suppliers with multiple Tier-1 vendor dependencies. Higher impact scores indicate 
        greater concentration risk.
    </p>
    """, unsafe_allow_html=True)
    
    if bottlenecks is not None and not bottlenecks.empty:
        # PARALLEL PREFETCH: Load all dependents and AI analyses upfront
        with st.spinner("Loading concentration analysis..."):
            # Get all bottleneck IDs
            bottleneck_ids = bottlenecks['NODE_ID'].tolist()
            
            # Prefetch all dependents in parallel
            all_dependents = prefetch_all_bottleneck_dependents(session, bottleneck_ids)
            
            # Prepare data for AI analysis prefetch
            ai_data = [
                {
                    'node_id': row['NODE_ID'],
                    'dependent_count': row['DEPENDENT_COUNT'],
                    'impact_score': row['IMPACT_SCORE'],
                    'mitigation_status': row.get('MITIGATION_STATUS', 'UNMITIGATED')
                }
                for _, row in bottlenecks.iterrows()
            ]
            
            # Prefetch all AI analyses in parallel
            all_ai_analyses = prefetch_all_ai_analyses(session, ai_data)
        
        # Render all bottleneck cards using prefetched data
        for idx, row in bottlenecks.iterrows():
            impact = row['IMPACT_SCORE']
            impact_class = 'critical' if impact >= 0.7 else 'high' if impact >= 0.4 else 'medium'
            impact_label = 'CRITICAL' if impact >= 0.7 else 'HIGH' if impact >= 0.4 else 'MEDIUM'
            
            # Use prefetched dependents
            deps = all_dependents.get(row['NODE_ID'])
            dep_names = []
            if deps is not None and not deps.empty:
                dep_names = deps['VENDOR_NAME'].fillna(deps['VENDOR_ID']).tolist()[:5]
            
            st.markdown(f"""
            <div class="bottleneck-card {impact_class}">
                <div class="bottleneck-header">
                    <span class="bottleneck-name">{row['NODE_ID']}</span>
                    <span class="impact-badge impact-{impact_class}">{impact_label} IMPACT</span>
                </div>
                <div class="bottleneck-stats">
                    <span>Impact: <strong>{impact:.0%}</strong></span>
                    <span>Dependents: <strong>{row['DEPENDENT_COUNT']}</strong></span>
                    <span>Status: <strong>{row.get('MITIGATION_STATUS', 'UNMITIGATED')}</strong></span>
                </div>
                <div class="bottleneck-description">
                    {row.get('DESCRIPTION', 'Hidden supply chain convergence point requiring attention.')}
                </div>
                <div class="evidence-section">
                    <div class="evidence-title">Affected Tier-1 Vendors</div>
                    {''.join([f'<span class="vendor-chip">{name}</span>' for name in dep_names])}
                    {f'<span style="color: #64748b; font-size: 0.8rem;"> +{len(deps) - 5} more</span>' if deps is not None and len(deps) > 5 else ''}
                </div>
            </div>
            """, unsafe_allow_html=True)
            
            # Use prefetched AI analysis
            bottleneck_analysis = all_ai_analyses.get(row['NODE_ID'])
            if bottleneck_analysis:
                st.markdown(f"""
                <div style="background: rgba(59, 130, 246, 0.08); border-left: 3px solid #3b82f6; padding: 0.75rem 1rem; margin-top: 0.5rem; border-radius: 0 8px 8px 0;">
                    <div style="color: #60a5fa; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.25rem;">AI Analysis</div>
                    <p style="color: #e2e8f0; line-height: 1.5; margin: 0; font-size: 0.9rem;">{bottleneck_analysis}</p>
                </div>
                """, unsafe_allow_html=True)
            
            # Show compact regional context for bottlenecks with critical region associations
            bottleneck_region = get_region_for_bottleneck(row['NODE_ID'])
            if bottleneck_region:
                st.markdown(
                    render_compact_risk_card(bottleneck_region),
                    unsafe_allow_html=True
                )
    else:
        st.info("No bottlenecks identified. Run the GNN notebook to analyze your supply chain.")
    
    st.divider()
    
    # ============================================
    # ALL PREDICTED LINKS
    # ============================================
    st.markdown('<div class="section-header">Inferred Relationships</div>', unsafe_allow_html=True)
    
    # Filter controls
    col1, col2 = st.columns([1, 3])
    with col1:
        min_prob = st.slider("Min Probability", 0.0, 1.0, 0.3, 0.1)
    
    predicted_links = load_all_predicted_links(session, min_prob)
    
    if predicted_links is not None and not predicted_links.empty:
        st.markdown(f"**{len(predicted_links):,}** predicted links above {min_prob:.0%} confidence")
        
        # AI-generated summary of link predictions
        high_conf_count = len(predicted_links[predicted_links['PROBABILITY'] >= 0.7])
        avg_conf = predicted_links['PROBABILITY'].mean()
        
        with st.spinner("Generating AI summary..."):
            links_summary = generate_ai_analysis(session, "links_summary", {
                'total_links': len(predicted_links),
                'high_confidence': high_conf_count,
                'avg_confidence': avg_conf
            })
        
        if links_summary:
            st.markdown(f"""
            <div style="background: rgba(16, 185, 129, 0.1); border: 1px solid #10b981; border-radius: 8px; padding: 1rem; margin: 1rem 0;">
                <div style="color: #10b981; font-size: 0.8rem; text-transform: uppercase; margin-bottom: 0.5rem;">
                    AI Summary
                </div>
                <p style="color: #e2e8f0; line-height: 1.6; margin: 0;">
                    {links_summary}
                </p>
            </div>
            """, unsafe_allow_html=True)
        
        # Add evidence strength column styling
        def style_probability(val):
            if val >= 0.7:
                return 'background-color: rgba(22, 163, 74, 0.3)'
            elif val >= 0.5:
                return 'background-color: rgba(202, 138, 4, 0.3)'
            else:
                return 'background-color: rgba(220, 38, 38, 0.2)'
        
        display_cols = ['SOURCE_NODE_ID', 'TARGET_NODE_ID', 'PROBABILITY', 'EVIDENCE_STRENGTH']
        styled_df = predicted_links[display_cols].style.applymap(
            style_probability, subset=['PROBABILITY']
        ).format({'PROBABILITY': '{:.1%}'})
        
        st.dataframe(styled_df, use_container_width=True, height=400)
        
        # Download option
        csv = predicted_links.to_csv(index=False)
        st.download_button(
            "Download Predicted Links CSV",
            csv,
            "predicted_links.csv",
            "text/csv"
        )
    else:
        st.info("No predicted links found above the threshold.")


if __name__ == "__main__":
    main()

