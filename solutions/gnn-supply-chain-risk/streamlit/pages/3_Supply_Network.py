"""
Supply Network Page

Interactive visualization of the supply chain network graph.
"""

import streamlit as st
import json
import plotly.graph_objects as go
import pydeck as pdk
import networkx as nx
import sys
from pathlib import Path
from snowflake.snowpark.context import get_active_session

# Add parent directory to path for utils import (needed for Streamlit in Snowflake)
sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.data_loader import run_queries_parallel, DB_SCHEMA
from utils.sidebar import render_sidebar, render_star_callout

# Country coordinates (centroids) - ISO-3 to lat/lon mapping
COUNTRY_COORDS = {
    'CHN': {'lat': 35.8617, 'lon': 104.1954, 'name': 'China'},
    'KOR': {'lat': 35.9078, 'lon': 127.7669, 'name': 'South Korea'},
    'JPN': {'lat': 36.2048, 'lon': 138.2529, 'name': 'Japan'},
    'USA': {'lat': 37.0902, 'lon': -95.7129, 'name': 'United States'},
    'DEU': {'lat': 51.1657, 'lon': 10.4515, 'name': 'Germany'},
    'MEX': {'lat': 23.6345, 'lon': -102.5528, 'name': 'Mexico'},
    'CAN': {'lat': 56.1304, 'lon': -106.3468, 'name': 'Canada'},
    'AUS': {'lat': -25.2744, 'lon': 133.7751, 'name': 'Australia'},
    'BRA': {'lat': -14.2350, 'lon': -51.9253, 'name': 'Brazil'},
    'IND': {'lat': 20.5937, 'lon': 78.9629, 'name': 'India'},
    'GBR': {'lat': 55.3781, 'lon': -3.4360, 'name': 'United Kingdom'},
    'FRA': {'lat': 46.2276, 'lon': 2.2137, 'name': 'France'},
    'TWN': {'lat': 23.6978, 'lon': 120.9605, 'name': 'Taiwan'},
    'VNM': {'lat': 14.0583, 'lon': 108.2772, 'name': 'Vietnam'},
    'THA': {'lat': 15.8700, 'lon': 100.9925, 'name': 'Thailand'},
    'IDN': {'lat': -0.7893, 'lon': 113.9213, 'name': 'Indonesia'},
    'MYS': {'lat': 4.2105, 'lon': 101.9758, 'name': 'Malaysia'},
    'PHL': {'lat': 12.8797, 'lon': 121.7740, 'name': 'Philippines'},
    'SGP': {'lat': 1.3521, 'lon': 103.8198, 'name': 'Singapore'},
    'CHL': {'lat': -35.6751, 'lon': -71.5430, 'name': 'Chile'},
    'ARG': {'lat': -38.4161, 'lon': -63.6167, 'name': 'Argentina'},
    'ZAF': {'lat': -30.5595, 'lon': 22.9375, 'name': 'South Africa'},
    'COD': {'lat': -4.0383, 'lon': 21.7587, 'name': 'DR Congo'},
}



st.set_page_config(
    page_title="Supply Network",
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
    .stat-card {
        background: rgba(30, 41, 59, 0.8);
        border: 1px solid #334155;
        border-radius: 8px;
        padding: 1rem;
        text-align: center;
    }
    .stat-value {
        font-size: 1.8rem;
        font-weight: 800;
        color: #f8fafc;
    }
    .stat-label {
        font-size: 0.8rem;
        color: #64748b;
        text-transform: uppercase;
    }
    .graph-container {
        background: rgba(15, 23, 42, 0.8);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1rem;
        margin: 1rem 0;
    }
    .legend-bar {
        display: flex;
        justify-content: center;
        gap: 2rem;
        padding: 0.5rem;
        color: #94a3b8;
        font-size: 0.85rem;
    }
    .legend-item {
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }
    .legend-dot {
        width: 12px;
        height: 12px;
        border-radius: 50%;
    }
    
    /* Hide default multipage navigation */
    [data-testid="stSidebarNav"] {display: none;}
</style>
""", unsafe_allow_html=True)


@st.cache_resource
def get_session():
    return get_active_session()


@st.cache_data(ttl=300)
def load_graph_data(_session, include_predicted=True):
    """Load full graph data for visualization."""
    nodes = []
    edges = []
    
    # Load vendors as nodes
    try:
        vendors = _session.sql(f"""
            SELECT 
                v.VENDOR_ID as ID,
                v.NAME as LABEL,
                v.COUNTRY_CODE,
                rs.RISK_SCORE,
                rs.RISK_CATEGORY
            FROM {DB_SCHEMA}.VENDORS v
            LEFT JOIN {DB_SCHEMA}.RISK_SCORES rs ON v.VENDOR_ID = rs.NODE_ID
        """).to_pandas()
        
        for _, row in vendors.iterrows():
            nodes.append({
                "id": row['ID'],
                "label": row['LABEL'] or row['ID'],
                "type": "SUPPLIER",
                "country": row['COUNTRY_CODE'],
                "risk_score": float(row['RISK_SCORE']) if row['RISK_SCORE'] else 0.3
            })
    except:
        pass
    
    # Load materials as nodes
    try:
        materials = _session.sql(f"""
            SELECT 
                m.MATERIAL_ID as ID,
                m.DESCRIPTION as LABEL,
                m.MATERIAL_GROUP,
                rs.RISK_SCORE
            FROM {DB_SCHEMA}.MATERIALS m
            LEFT JOIN {DB_SCHEMA}.RISK_SCORES rs ON m.MATERIAL_ID = rs.NODE_ID
        """).to_pandas()
        
        for _, row in materials.iterrows():
            nodes.append({
                "id": row['ID'],
                "label": row['LABEL'] or row['ID'],
                "type": "MATERIAL",
                "material_group": row['MATERIAL_GROUP'],
                "risk_score": float(row['RISK_SCORE']) if row['RISK_SCORE'] else 0.2
            })
    except:
        pass
    
    # Load purchase orders as edges (vendor -> material)
    try:
        pos = _session.sql(f"""
            SELECT DISTINCT VENDOR_ID as SOURCE, MATERIAL_ID as TARGET
            FROM {DB_SCHEMA}.PURCHASE_ORDERS
        """).to_pandas()
        
        for _, row in pos.iterrows():
            edges.append({
                "source": row['SOURCE'],
                "target": row['TARGET'],
                "type": "SUPPLIES",
                "predicted": False
            })
    except:
        pass
    
    # Load predicted links if requested
    if include_predicted:
        try:
            predicted = _session.sql(f"""
                SELECT 
                    SOURCE_NODE_ID as SOURCE,
                    TARGET_NODE_ID as TARGET,
                    PROBABILITY
                FROM {DB_SCHEMA}.PREDICTED_LINKS
                WHERE PROBABILITY >= 0.3
            """).to_pandas()
            
            # Add external supplier nodes
            ext_suppliers = predicted['SOURCE'].unique()
            for ext_id in ext_suppliers:
                if not any(n['id'] == ext_id for n in nodes):
                    nodes.append({
                        "id": ext_id,
                        "label": ext_id,
                        "type": "EXTERNAL_SUPPLIER",
                        "risk_score": 0.6
                    })
            
            for _, row in predicted.iterrows():
                edges.append({
                    "source": row['SOURCE'],
                    "target": row['TARGET'],
                    "type": "PREDICTED",
                    "predicted": True,
                    "weight": float(row['PROBABILITY'])
                })
        except:
            pass
    
    return nodes, edges


@st.cache_data(ttl=300)
def load_graph_stats(_session):
    """Load graph statistics using parallel query execution."""
    
    # Define all queries for parallel execution (8 queries)
    queries = {
        'vendors': "SELECT COUNT(*) as CNT FROM VENDORS",
        'materials': "SELECT COUNT(*) as CNT FROM MATERIALS",
        'regions': "SELECT COUNT(*) as CNT FROM REGIONS",
        'purchase_orders': "SELECT COUNT(*) as CNT FROM PURCHASE_ORDERS",
        'bom_edges': "SELECT COUNT(*) as CNT FROM BILL_OF_MATERIALS",
        'trade_records': "SELECT COUNT(*) as CNT FROM TRADE_DATA",
        'predicted_links': "SELECT COUNT(*) as CNT FROM PREDICTED_LINKS",
        'external_suppliers': "SELECT COUNT(DISTINCT SOURCE_NODE_ID) as CNT FROM PREDICTED_LINKS"
    }
    
    # Execute all queries in parallel
    results = run_queries_parallel(_session, queries, max_workers=4)
    
    # Process results into stats format
    stats = {}
    for key in queries:
        df = results.get(key)
        if df is not None and not df.empty:
            stats[key] = int(df['CNT'].iloc[0])
        else:
            stats[key] = 0
    
    return stats


@st.cache_data(ttl=300)
def load_bom_hierarchy(_session):
    """Load BOM data as hierarchical structure."""
    try:
        # First check if we have BOM data
        count_result = _session.sql(f"SELECT COUNT(*) as CNT FROM {DB_SCHEMA}.BILL_OF_MATERIALS").to_pandas()
        if count_result['CNT'].iloc[0] == 0:
            return None
        
        bom = _session.sql(f"""
            SELECT DISTINCT
                bom.PARENT_MATERIAL_ID,
                pm.DESCRIPTION as PARENT_DESC,
                pm.MATERIAL_GROUP as PARENT_GROUP,
                bom.CHILD_MATERIAL_ID,
                cm.DESCRIPTION as CHILD_DESC,
                cm.MATERIAL_GROUP as CHILD_GROUP,
                bom.QUANTITY_PER_UNIT
            FROM {DB_SCHEMA}.BILL_OF_MATERIALS bom
            LEFT JOIN {DB_SCHEMA}.MATERIALS pm ON bom.PARENT_MATERIAL_ID = pm.MATERIAL_ID
            LEFT JOIN {DB_SCHEMA}.MATERIALS cm ON bom.CHILD_MATERIAL_ID = cm.MATERIAL_ID
        """).to_pandas()
        
        if bom.empty:
            return None
        
        # Build hierarchical structure
        # Find root nodes (parents that are not children of anything)
        all_parents = set(bom['PARENT_MATERIAL_ID'].unique())
        all_children = set(bom['CHILD_MATERIAL_ID'].unique())
        roots = all_parents - all_children
        
        if not roots:
            # If no roots found, use top-level parents
            roots = all_parents
        
        def build_tree(parent_id, parent_desc, parent_group, depth=0):
            if depth > 10:  # Prevent infinite recursion
                return {"id": parent_id, "name": parent_desc or parent_id, "type": parent_group, "children": None}
            
            children_df = bom[bom['PARENT_MATERIAL_ID'] == parent_id]
            children = []
            for _, row in children_df.iterrows():
                child_tree = build_tree(
                    row['CHILD_MATERIAL_ID'],
                    row['CHILD_DESC'] or row['CHILD_MATERIAL_ID'],
                    row['CHILD_GROUP'] or 'RAW',
                    depth + 1
                )
                child_tree['quantity'] = float(row['QUANTITY_PER_UNIT']) if row['QUANTITY_PER_UNIT'] else 1.0
                children.append(child_tree)
            
            return {
                "id": parent_id,
                "name": parent_desc or parent_id,
                "type": parent_group or 'FIN',
                "children": children if children else None
            }
        
        # Build trees for each root (limit to first 3 roots to avoid performance issues)
        trees = []
        for root_id in list(roots)[:3]:
            root_rows = bom[bom['PARENT_MATERIAL_ID'] == root_id]
            if not root_rows.empty:
                root_info = root_rows.iloc[0]
                trees.append(build_tree(
                    root_id, 
                    root_info['PARENT_DESC'] or root_id, 
                    root_info['PARENT_GROUP'] or 'FIN'
                ))
        
        return trees if trees else None
        
    except Exception as e:
        st.warning(f"Error loading BOM hierarchy: {e}")
        return None


def render_full_graph(nodes, edges, height=600):
    """Render the full supply chain network graph using Plotly."""
    
    if not nodes:
        st.info("No graph data available.")
        return
    
    # Build NetworkX graph for layout computation
    G = nx.Graph()
    
    # Add nodes
    for node in nodes:
        G.add_node(node['id'], **node)
    
    # Add edges
    for edge in edges:
        G.add_edge(edge['source'], edge['target'], **edge)
    
    # Compute layout using spring algorithm
    try:
        pos = nx.spring_layout(G, k=2, iterations=50, seed=42)
    except Exception:
        pos = nx.random_layout(G, seed=42)
    
    # Color maps
    type_colors = {
                'SUPPLIER': '#3b82f6',
                'MATERIAL': '#8b5cf6',
                'EXTERNAL_SUPPLIER': '#f59e0b'
    }
    
    def get_node_color(node):
        risk = node.get('risk_score', 0)
        if risk >= 0.75:
            return '#dc2626'  # critical
        elif risk >= 0.5:
            return '#ea580c'  # high
        elif risk >= 0.25:
            return '#ca8a04'  # medium
        return type_colors.get(node.get('type'), '#6b7280')
    
    def get_node_size(node):
        if node.get('type') == 'EXTERNAL_SUPPLIER':
            return 20
        elif node.get('type') == 'SUPPLIER':
            return 16
        return 12
    
    # Separate known and predicted edges
    known_edges = [e for e in edges if not e.get('predicted', False)]
    predicted_edges = [e for e in edges if e.get('predicted', False)]
    
    # Create edge traces for known edges
    known_edge_x, known_edge_y = [], []
    for edge in known_edges:
        if edge['source'] in pos and edge['target'] in pos:
            x0, y0 = pos[edge['source']]
            x1, y1 = pos[edge['target']]
            known_edge_x.extend([x0, x1, None])
            known_edge_y.extend([y0, y1, None])
    
    known_edge_trace = go.Scatter(
        x=known_edge_x, y=known_edge_y,
        mode='lines',
        line=dict(width=1, color='#475569'),
        hoverinfo='none',
        name='Known (ERP)'
    )
    
    # Create edge traces for predicted edges
    predicted_edge_x, predicted_edge_y = [], []
    for edge in predicted_edges:
        if edge['source'] in pos and edge['target'] in pos:
            x0, y0 = pos[edge['source']]
            x1, y1 = pos[edge['target']]
            predicted_edge_x.extend([x0, x1, None])
            predicted_edge_y.extend([y0, y1, None])
    
    predicted_edge_trace = go.Scatter(
        x=predicted_edge_x, y=predicted_edge_y,
        mode='lines',
        line=dict(width=2, color='#f59e0b', dash='dash'),
        hoverinfo='none',
        name='Predicted (GNN)'
    )
    
    # Create node traces by type
    node_traces = []
    for node_type, color in type_colors.items():
        type_nodes = [n for n in nodes if n.get('type') == node_type]
        if not type_nodes:
            continue
        
        node_x = [pos[n['id']][0] for n in type_nodes if n['id'] in pos]
        node_y = [pos[n['id']][1] for n in type_nodes if n['id'] in pos]
        node_colors = [get_node_color(n) for n in type_nodes if n['id'] in pos]
        node_sizes = [get_node_size(n) for n in type_nodes if n['id'] in pos]
        node_text = []
        for n in type_nodes:
            if n['id'] in pos:
                risk_pct = int(n.get('risk_score', 0) * 100)
                text = f"<b>{n.get('label', n['id'])}</b><br>"
                text += f"Type: {n.get('type', 'Unknown').replace('_', ' ')}<br>"
                if n.get('country'):
                    text += f"Country: {n['country']}<br>"
                text += f"Risk: {risk_pct}%"
                node_text.append(text)
        
        type_name = node_type.replace('_', ' ').title()
        node_trace = go.Scatter(
            x=node_x, y=node_y,
            mode='markers',
            marker=dict(
                size=node_sizes,
                color=node_colors,
                line=dict(width=1, color='#0f172a')
            ),
            text=node_text,
            hoverinfo='text',
            name=type_name
        )
        node_traces.append(node_trace)
    
    # Create figure
    fig = go.Figure(
        data=[known_edge_trace, predicted_edge_trace] + node_traces,
        layout=go.Layout(
            showlegend=True,
            hovermode='closest',
            paper_bgcolor='#0f172a',
            plot_bgcolor='#0f172a',
            height=height,
            margin=dict(b=20, l=5, r=5, t=40),
            legend=dict(
                x=0.01,
                y=0.99,
                bgcolor='rgba(30, 41, 59, 0.9)',
                bordercolor='#334155',
                borderwidth=1,
                font=dict(color='#e2e8f0')
            ),
            xaxis=dict(
                showgrid=False,
                zeroline=False,
                showticklabels=False
            ),
            yaxis=dict(
                showgrid=False,
                zeroline=False,
                showticklabels=False
            )
        )
    )
    
    st.plotly_chart(fig, use_container_width=True, key="network_graph")


def render_bom_tree(tree_data, height=500):
    """Render BOM hierarchy using Plotly Treemap with rich tooltips."""
    
    if not tree_data:
        st.info("No Bill of Materials data available.")
        return
    
    # Color scheme and type labels
    type_colors = {
        'FIN': '#10b981',
        'SEMI': '#8b5cf6',
        'RAW': '#f59e0b'
    }
    
    type_labels = {
        'FIN': 'Finished Good',
        'SEMI': 'Semi-finished',
        'RAW': 'Raw Material'
    }
    
    # Flatten all trees for Plotly Treemap
    ids = []
    labels = []
    parents = []
    values = []
    colors = []
    custom_data = []
    
    def count_leaves(node):
        """Count leaf nodes for sizing - ensures parent >= sum of children."""
        if not node:
            return 0
        children = node.get('children')
        if not children:
            return 1
        return sum(count_leaves(c) for c in children if c)
    
    def count_children(node):
        """Count direct children."""
        children = node.get('children')
        return len(children) if children else 0
    
    def flatten_tree(node, parent_id=""):
        if not node:
            return
        
        node_id = node.get('id', node.get('name', 'Unknown'))
        node_name = node.get('name', node_id)
        node_type = node.get('type', 'RAW')
        qty = node.get('quantity', 1) or 1
        
        # Make unique ID
        unique_id = f"{parent_id}/{node_id}" if parent_id else node_id
        
        ids.append(unique_id)
        labels.append(node_name[:30])  # Truncate long names
        parents.append(parent_id)
        
        # Use leaf count for value to ensure proper hierarchy display
        leaf_count = count_leaves(node)
        values.append(max(leaf_count, 1))
        
        colors.append(type_colors.get(node_type, '#6b7280'))
        
        # Build custom data for rich tooltips
        type_label = type_labels.get(node_type, node_type)
        num_children = count_children(node)
        children_text = f"{num_children} direct" if num_children > 0 else "None (leaf)"
        
        custom_data.append([
            node_id,              # 0: Material ID
            type_label,           # 1: Type label  
            qty,                  # 2: Quantity per unit
            children_text         # 3: Number of components
        ])
        
        children = node.get('children')
        if children:
            for child in children:
                if child:  # Skip None children
                    flatten_tree(child, unique_id)
    
    # Process all root trees
    trees = tree_data if isinstance(tree_data, list) else [tree_data]
    for tree in trees:
        if tree:
            flatten_tree(tree)
    
    if not labels:
        st.info("No Bill of Materials data available.")
        return
    
    # Create Treemap with rich tooltips
    fig = go.Figure(go.Treemap(
        ids=ids,
        labels=labels,
        parents=parents,
        values=values,
        marker=dict(
            colors=colors,
            line=dict(width=2, color='#0f172a'),
            cornerradius=5
        ),
        branchvalues="total",
        customdata=custom_data,
        hovertemplate=(
            "<b>%{label}</b><br><br>"
            "<b>Material ID:</b> %{customdata[0]}<br>"
            "<b>Type:</b> %{customdata[1]}<br>"
            "<b>Qty per Unit:</b> %{customdata[2]:.2f}<br>"
            "<b>Components:</b> %{customdata[3]}"
            "<extra></extra>"
        ),
        texttemplate="<b>%{label}</b><br>%{customdata[1]}",
        textfont=dict(size=11, color='white'),
        maxdepth=3,
        pathbar=dict(
            visible=True,
            thickness=28,
            textfont=dict(size=12, color='#e2e8f0'),
            edgeshape='>'
        )
    ))
    
    fig.update_layout(
        paper_bgcolor='#0f172a',
        plot_bgcolor='#0f172a',
        height=height,
        margin=dict(t=35, l=10, r=10, b=10),
        font=dict(color='#e2e8f0'),
        hoverlabel=dict(
            bgcolor='#1e293b',
            bordercolor='#334155',
            font=dict(size=12, color='#e2e8f0', family='system-ui')
        )
    )
    
    st.plotly_chart(fig, use_container_width=True, key="bom_tree")


def main():
    session = get_session()
    
    # Render STAR callout if demo mode is enabled
    render_star_callout("network")
    
    # Load data
    stats = load_graph_stats(session)
    
    # ============================================
    # HEADER
    # ============================================
    st.markdown("""
    <div class="page-header">Supply Network</div>
    <div class="page-subheader">Multi-tier supplier relationship graph</div>
    """, unsafe_allow_html=True)
    
    # ============================================
    # GRAPH STATISTICS
    # ============================================
    col1, col2, col3, col4, col5, col6 = st.columns(6)
    
    with col1:
        st.markdown(f"""
        <div class="stat-card">
            <div class="stat-value">{stats.get('vendors', 0)}</div>
            <div class="stat-label">Tier-1 Suppliers</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown(f"""
        <div class="stat-card">
            <div class="stat-value">{stats.get('materials', 0)}</div>
            <div class="stat-label">Materials</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown(f"""
        <div class="stat-card">
            <div class="stat-value">{stats.get('external_suppliers', 0)}</div>
            <div class="stat-label">External (Tier-2+)</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        st.markdown(f"""
        <div class="stat-card">
            <div class="stat-value">{stats.get('purchase_orders', 0)}</div>
            <div class="stat-label">Known Edges</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col5:
        st.markdown(f"""
        <div class="stat-card">
            <div class="stat-value">{stats.get('predicted_links', 0)}</div>
            <div class="stat-label">Predicted Edges</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col6:
        st.markdown(f"""
        <div class="stat-card">
            <div class="stat-value">{stats.get('trade_records', 0)}</div>
            <div class="stat-label">Trade Records</div>
        </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # FULL NETWORK GRAPH
    # ============================================
    st.markdown('<div class="section-header">Network Graph</div>', unsafe_allow_html=True)
    st.markdown("""
    <p style="color: #94a3b8; margin-bottom: 1rem;">
        Drag nodes to explore relationships. Zoom and pan to navigate. 
        <strong style="color: #f59e0b;">Dashed lines</strong> indicate inferred Tier-2+ relationships.
    </p>
    """, unsafe_allow_html=True)
    
    # Load graph data
    with st.spinner("Loading graph data..."):
        nodes, edges = load_graph_data(session, include_predicted=True)
    
    if nodes:
        render_full_graph(nodes, edges, height=550)
    else:
        st.info("No graph data available. Run the GNN notebook to build the knowledge graph.")
    
    st.divider()
    
    # ============================================
    # BOM HIERARCHY
    # ============================================
    st.markdown('<div class="section-header">Bill of Materials Treemap</div>', unsafe_allow_html=True)
    st.markdown("""
    <p style="color: #94a3b8; margin-bottom: 1rem;">
        Product structure showing how materials combine into finished goods. Click to drill down, hover for details.
        <span style="color: #10b981;">■</span> Finished &nbsp;
        <span style="color: #8b5cf6;">■</span> Semi-finished &nbsp;
        <span style="color: #f59e0b;">■</span> Raw Materials
    </p>
    """, unsafe_allow_html=True)
    
    bom_trees = load_bom_hierarchy(session)
    
    if bom_trees:
        render_bom_tree(bom_trees, height=400)
    else:
        st.info("No Bill of Materials data available.")
    
    st.divider()
    
    # ============================================
    # REGIONAL DISTRIBUTION
    # ============================================
    st.markdown('<div class="section-header">Geographic Distribution</div>', unsafe_allow_html=True)
    st.markdown("""
    <p style="color: #94a3b8; margin-bottom: 1rem;">
        Supplier distribution by country with risk analysis. Column height shows vendor count, color shows risk level.
    </p>
    """, unsafe_allow_html=True)
    
    try:
        region_data = session.sql("""
            SELECT 
                v.COUNTRY_CODE,
                r.REGION_NAME,
                COUNT(*) as VENDOR_COUNT,
                ROUND(AVG(rs.RISK_SCORE), 3) as AVG_RISK,
                ROUND(AVG(v.FINANCIAL_HEALTH_SCORE), 3) as AVG_HEALTH,
                r.GEOPOLITICAL_RISK,
                r.NATURAL_DISASTER_RISK,
                r.INFRASTRUCTURE_SCORE
            FROM VENDORS v
            LEFT JOIN REGIONS r ON v.COUNTRY_CODE = r.REGION_CODE
            LEFT JOIN RISK_SCORES rs ON v.VENDOR_ID = rs.NODE_ID
            GROUP BY v.COUNTRY_CODE, r.REGION_NAME, r.GEOPOLITICAL_RISK, r.NATURAL_DISASTER_RISK, r.INFRASTRUCTURE_SCORE
            ORDER BY VENDOR_COUNT DESC
        """).to_pandas()
        
        if not region_data.empty:
            # Compute combined risk and display fields
            region_data['COMBINED_RISK'] = (
                region_data['AVG_RISK'].fillna(0.3) * 0.4 +
                region_data['GEOPOLITICAL_RISK'].fillna(0.3) * 0.3 +
                region_data['NATURAL_DISASTER_RISK'].fillna(0.3) * 0.3
            )
            region_data['DISPLAY_NAME'] = region_data.apply(
                lambda r: f"{r['REGION_NAME']} ({r['COUNTRY_CODE']})" if r['REGION_NAME'] else r['COUNTRY_CODE'], 
                axis=1
            )
            
            # Add coordinates for map visualization
            region_data['lat'] = region_data['COUNTRY_CODE'].map(lambda x: COUNTRY_COORDS.get(x, {}).get('lat'))
            region_data['lon'] = region_data['COUNTRY_CODE'].map(lambda x: COUNTRY_COORDS.get(x, {}).get('lon'))
            region_data['COUNTRY_NAME'] = region_data['COUNTRY_CODE'].map(
                lambda x: COUNTRY_COORDS.get(x, {}).get('name', x)
            )
            
            # Data for map (only countries with coordinates)
            map_data = region_data.dropna(subset=['lat', 'lon']).copy()
            
            # ============================================
            # 3D WORLD MAP
            # ============================================
            if not map_data.empty:
                # Risk to RGB color
                def risk_to_color(risk):
                    if risk < 0.3:
                        return [16, 185, 129, 200]  # Green
                    elif risk < 0.5:
                        return [245, 158, 11, 200]  # Amber
                    else:
                        return [239, 68, 68, 200]   # Red
                
                map_data['color'] = map_data['COMBINED_RISK'].apply(risk_to_color)
                map_data['elevation'] = map_data['VENDOR_COUNT'] * 100000
                # Pre-format risk as percentage string for tooltip (pydeck doesn't support format specifiers)
                map_data['RISK_DISPLAY'] = map_data['COMBINED_RISK'].apply(lambda x: f"{x:.0%}")
                
                layer = pdk.Layer(
                    'ColumnLayer',
                    data=map_data,
                    get_position='[lon, lat]',
                    get_elevation='elevation',
                    elevation_scale=1,
                    radius=300000,
                    get_fill_color='color',
                    pickable=True,
                    auto_highlight=True,
                )
                
                view_state = pdk.ViewState(
                    latitude=20,
                    longitude=0,
                    zoom=0.9,
                    pitch=45,
                    bearing=0,
                    min_zoom=0.5,
                    max_zoom=6
                )
                
                deck = pdk.Deck(
                    layers=[layer],
                    initial_view_state=view_state,
                    tooltip={
                        'html': '<b>{COUNTRY_NAME}</b><br>'
                                'Vendors: {VENDOR_COUNT}<br>'
                                'Risk: {RISK_DISPLAY}',
                        'style': {
                            'backgroundColor': '#1e293b',
                            'color': '#e2e8f0',
                            'borderRadius': '8px',
                            'padding': '8px'
                        }
                    },
                    # Use None to let Streamlit/Snowflake pick appropriate Carto/Mapbox style
                    # This aligns with CSP allowlist and auto-injected tokens in SiS
                    map_style=None
                )
                
                st.pydeck_chart(deck, use_container_width=True)
                
                # Legend
                st.markdown("""
                <div style="display: flex; gap: 1.5rem; justify-content: center; margin-top: 0.5rem; margin-bottom: 1rem;">
                    <span style="color: #94a3b8;"><span style="color: #10b981;">●</span> Low Risk (&lt;30%)</span>
                    <span style="color: #94a3b8;"><span style="color: #f59e0b;">●</span> Medium Risk (30-50%)</span>
                    <span style="color: #94a3b8;"><span style="color: #ef4444;">●</span> High Risk (&gt;50%)</span>
                </div>
                """, unsafe_allow_html=True)
            else:
                st.warning("No geographic coordinates available for map visualization.")
            
            # ============================================
            # BAR CHART + REGIONAL DETAILS
            # ============================================
            col1, col2 = st.columns([3, 2])
            
            with col1:
                # Horizontal bar chart with rich tooltips
                bar_fig = go.Figure(go.Bar(
                    x=region_data['VENDOR_COUNT'],
                    y=region_data['DISPLAY_NAME'],
                    orientation='h',
                    marker=dict(
                        color=region_data['COMBINED_RISK'],
                        colorscale=[
                            [0, '#10b981'],
                            [0.5, '#f59e0b'],
                            [1, '#ef4444']
                        ],
                        cmin=0,
                        cmax=1,
                        showscale=True,
                        colorbar=dict(
                            title=dict(text="Risk", font=dict(color='#e2e8f0', size=11)),
                            tickfont=dict(color='#e2e8f0', size=10),
                            tickformat='.0%',
                            len=0.8
                        )
                    ),
                    text=region_data['VENDOR_COUNT'],
                    textposition='outside',
                    textfont=dict(color='#e2e8f0', size=12),
                    customdata=list(zip(
                        region_data['COMBINED_RISK'],
                        region_data['AVG_HEALTH'].fillna(0),
                        region_data['GEOPOLITICAL_RISK'].fillna(0),
                        region_data['NATURAL_DISASTER_RISK'].fillna(0),
                        region_data['INFRASTRUCTURE_SCORE'].fillna(0)
                    )),
                    hovertemplate=(
                        "<b>%{y}</b><br><br>"
                        "<b>Vendors:</b> %{x}<br>"
                        "<b>Combined Risk:</b> %{customdata[0]:.0%}<br>"
                        "<b>Avg Financial Health:</b> %{customdata[1]:.0%}<br>"
                        "<b>Geopolitical Risk:</b> %{customdata[2]:.0%}<br>"
                        "<b>Natural Disaster Risk:</b> %{customdata[3]:.0%}<br>"
                        "<b>Infrastructure Score:</b> %{customdata[4]:.0%}<br>"
                        "<extra></extra>"
                    )
                ))
                
                bar_fig.update_layout(
                    paper_bgcolor='#0f172a',
                    plot_bgcolor='#0f172a',
                    height=350,
                    margin=dict(l=10, r=60, t=10, b=10),
                    xaxis=dict(
                        showgrid=True,
                        gridcolor='#1e293b',
                        tickfont=dict(color='#94a3b8'),
                        title=dict(text="Number of Vendors", font=dict(color='#94a3b8', size=11))
                    ),
                    yaxis=dict(
                        showgrid=False,
                        tickfont=dict(color='#e2e8f0', size=11),
                        autorange='reversed'
                    ),
                    bargap=0.25,
                    hoverlabel=dict(
                        bgcolor='#1e293b',
                        bordercolor='#334155',
                        font=dict(size=12, color='#e2e8f0', family='system-ui')
                    )
                )
                
                st.plotly_chart(bar_fig, use_container_width=True, key="geo_bar")
            
            with col2:
                st.markdown("**Regional Risk Summary**")
                
                # Show risk details for each region in styled cards
                for _, row in region_data.iterrows():
                    risk = row['COMBINED_RISK']
                    geo_risk = row.get('GEOPOLITICAL_RISK', 0) or 0
                    nat_risk = row.get('NATURAL_DISASTER_RISK', 0) or 0
                    infra = row.get('INFRASTRUCTURE_SCORE', 0) or 0
                    health = row.get('AVG_HEALTH', 0) or 0
                    
                    risk_color = '#ef4444' if risk >= 0.5 else '#f59e0b' if risk >= 0.3 else '#10b981'
                    
                    st.markdown(f"""
                    <div style="background: #1e293b; border-radius: 8px; padding: 0.75rem; margin-bottom: 0.5rem; border-left: 3px solid {risk_color};">
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <div style="color: #f8fafc; font-weight: 600;">
                                {row['REGION_NAME'] or row['COUNTRY_CODE']}
                            </div>
                            <div style="background: {risk_color}; color: white; padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; font-weight: 600;">
                                {risk:.0%}
                            </div>
                        </div>
                        <div style="color: #94a3b8; font-size: 0.85rem; margin-top: 0.25rem;">
                            {row['VENDOR_COUNT']} vendors · Health: {health:.0%}
                        </div>
                        <div style="color: #64748b; font-size: 0.75rem; margin-top: 0.25rem;">
                            Geo: {geo_risk:.0%} · Natural: {nat_risk:.0%} · Infra: {infra:.0%}
                        </div>
                    </div>
                    """, unsafe_allow_html=True)
        else:
            st.info("No regional data available. Ensure VENDORS and REGIONS tables have data.")
    except Exception as e:
        st.warning(f"Could not load regional data: {str(e)[:100]}")
    
    # Sidebar
    render_sidebar()


if __name__ == "__main__":
    main()

