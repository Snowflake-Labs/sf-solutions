"""
About Page

Provides comprehensive information about the Supply Chain Risk Intelligence demo,
including data sources, the GNN notebook, and technical architecture.
"""

import streamlit as st
import sys
from pathlib import Path
from snowflake.snowpark.context import get_active_session

# Add parent directory to path for utils import (needed for Streamlit in Snowflake)
sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.sidebar import render_sidebar, render_star_callout

st.set_page_config(
    page_title="About",
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
    .info-card {
        background: rgba(30, 41, 59, 0.8);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1.5rem;
        margin: 0.5rem 0;
        height: 100%;
    }
    .info-card h3 {
        color: #f8fafc;
        font-size: 1.1rem;
        margin-bottom: 0.5rem;
    }
    .info-card p {
        color: #94a3b8;
        font-size: 0.95rem;
        line-height: 1.6;
    }
    .table-card {
        background: rgba(30, 41, 59, 0.6);
        border: 1px solid #334155;
        border-radius: 8px;
        padding: 1rem;
        margin: 0.5rem 0;
    }
    .table-name {
        color: #3b82f6;
        font-weight: 700;
        font-size: 1rem;
        font-family: monospace;
    }
    .table-desc {
        color: #94a3b8;
        font-size: 0.9rem;
        margin-top: 0.25rem;
    }
    .badge-internal {
        background: #1e40af;
        color: #fff;
        padding: 2px 8px;
        border-radius: 4px;
        font-size: 0.7rem;
        text-transform: uppercase;
        margin-left: 8px;
    }
    .badge-external {
        background: #b45309;
        color: #fff;
        padding: 2px 8px;
        border-radius: 4px;
        font-size: 0.7rem;
        text-transform: uppercase;
        margin-left: 8px;
    }
    .badge-output {
        background: #166534;
        color: #fff;
        padding: 2px 8px;
        border-radius: 4px;
        font-size: 0.7rem;
        text-transform: uppercase;
        margin-left: 8px;
    }
    .tech-stack {
        display: flex;
        flex-wrap: wrap;
        gap: 0.5rem;
        margin-top: 1rem;
    }
    .tech-badge {
        background: rgba(59, 130, 246, 0.2);
        border: 1px solid #3b82f6;
        color: #93c5fd;
        padding: 4px 12px;
        border-radius: 20px;
        font-size: 0.85rem;
    }
    .workflow-step {
        background: rgba(30, 41, 59, 0.6);
        border-left: 3px solid #3b82f6;
        padding: 1rem 1.5rem;
        margin: 0.5rem 0;
        border-radius: 0 8px 8px 0;
    }
    .workflow-step h4 {
        color: #f8fafc;
        margin-bottom: 0.25rem;
    }
    .workflow-step p {
        color: #94a3b8;
        margin: 0;
    }
    
    /* Hide default multipage navigation */
    [data-testid="stSidebarNav"] {display: none;}
</style>
""", unsafe_allow_html=True)


def main():
    """Main application."""
    
    # Render STAR callout if demo mode is enabled
    render_star_callout("about")
    
    # Header
    st.markdown("""
    <div class="page-header">About This Demo</div>
    <div class="page-subheader">
        AI-Driven N-Tier Supply Chain Resilience using Graph Neural Networks
    </div>
    """, unsafe_allow_html=True)
    
    # ============================================
    # OVERVIEW
    # ============================================
    st.markdown('<div class="section-header">Overview</div>', unsafe_allow_html=True)
    
    col1, col2 = st.columns([2, 1])
    
    with col1:
        st.markdown("""
        <div class="info-card">
            <h3>The Problem: Tier-N Blindness</h3>
            <p>
                Modern supply chains are brittle because visibility typically ends at "Tier 1"—the direct suppliers. 
                A company might believe its supply chain is resilient because it sources a critical component from 
                three different vendors across three different countries. However, they lack the visibility to see 
                that all three vendors unknowingly source their raw materials from the same single refinery.
            </p>
            <p style="margin-top: 1rem;">
                This "Tier-N Blindness" means that risks—whether geopolitical, environmental, or financial—fester 
                unseen in the deeper layers of the network. When a disruption occurs at Tier 3, the manufacturer 
                is blindsided weeks later by sudden shortages.
            </p>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("""
        <div class="info-card">
            <h3>The Solution</h3>
            <p>
                We model the supply chain as a <strong>Knowledge Graph</strong> and use 
                <strong>Graph Neural Networks (GNNs)</strong> to:
            </p>
            <ul style="color: #94a3b8; margin-top: 0.5rem;">
                <li>Infer hidden Tier-2+ relationships</li>
                <li>Predict link probabilities</li>
                <li>Propagate risk scores</li>
                <li>Identify concentration points</li>
            </ul>
        </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # DATA ARCHITECTURE
    # ============================================
    st.markdown('<div class="section-header">Data Architecture</div>', unsafe_allow_html=True)
    
    st.markdown("""
    <p style="color: #94a3b8; margin-bottom: 1.5rem;">
        The solution fuses internal ERP data with external trade intelligence to build a multi-tier supply network graph.
    </p>
    """, unsafe_allow_html=True)
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.markdown("#### Internal ERP Data")
        st.markdown("""
        <div class="table-card">
            <span class="table-name">VENDORS</span>
            <span class="badge-internal">ERP</span>
            <p class="table-desc">Tier-1 supplier master data including company info, country, and contact details</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown("""
        <div class="table-card">
            <span class="table-name">MATERIALS</span>
            <span class="badge-internal">ERP</span>
            <p class="table-desc">Parts and products catalog with material groups (RAW, SEMI, FIN) and units</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown("""
        <div class="table-card">
            <span class="table-name">PURCHASE_ORDERS</span>
            <span class="badge-internal">ERP</span>
            <p class="table-desc">Transaction history linking vendors to materials with quantities and prices</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown("""
        <div class="table-card">
            <span class="table-name">BOM</span>
            <span class="badge-internal">ERP</span>
            <p class="table-desc">Bill of Materials defining component-of relationships between parts</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("#### External Trade Intelligence")
        st.markdown("""
        <div class="table-card">
            <span class="table-name">BILLS_OF_LADING</span>
            <span class="badge-external">TRADE</span>
            <p class="table-desc">Global shipping records showing shipper-to-consignee relationships with HS codes</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown("""
        <div class="table-card">
            <span class="table-name">REGIONS</span>
            <span class="badge-external">TRADE</span>
            <p class="table-desc">Geographic risk factors including geopolitical, environmental, and economic scores</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown("""
        <div class="table-card">
            <span class="table-name">EXTERNAL_SUPPLIERS</span>
            <span class="badge-external">TRADE</span>
            <p class="table-desc">Tier-2+ suppliers discovered from trade data (not in internal ERP)</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown("#### Model Outputs")
        st.markdown("""
        <div class="table-card">
            <span class="table-name">RISK_SCORES</span>
            <span class="badge-output">GNN</span>
            <p class="table-desc">Propagated risk scores for all nodes with categories (CRITICAL, HIGH, MEDIUM, LOW)</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown("""
        <div class="table-card">
            <span class="table-name">PREDICTED_LINKS</span>
            <span class="badge-output">GNN</span>
            <p class="table-desc">Inferred Tier-2+ relationships with probability scores and confidence levels</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown("""
        <div class="table-card">
            <span class="table-name">BOTTLENECKS</span>
            <span class="badge-output">GNN</span>
            <p class="table-desc">Identified concentration points where multiple Tier-1 suppliers converge</p>
        </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # GNN NOTEBOOK
    # ============================================
    st.markdown('<div class="section-header">GNN Analysis Notebook</div>', unsafe_allow_html=True)
    
    col1, col2 = st.columns([1, 1])
    
    with col1:
        st.markdown("""
        <div class="info-card">
            <h3>Notebook Overview</h3>
            <p>
                The Snowflake Notebook implements a complete Graph Neural Network pipeline using 
                <strong>PyTorch Geometric (PyG)</strong> running natively in Snowflake.
            </p>
            <p style="margin-top: 1rem;">
                <strong>Key Capabilities:</strong>
            </p>
            <ul style="color: #94a3b8;">
                <li><strong>Graph Construction:</strong> Builds a HeteroData object with Supplier, Part, and Region nodes</li>
                <li><strong>Link Prediction:</strong> GraphSAGE encoder predicts hidden Tier-2+ relationships</li>
                <li><strong>Risk Propagation:</strong> Calculates propagated risk scores across the network</li>
                <li><strong>Bottleneck Detection:</strong> Identifies single points of failure</li>
            </ul>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("""
        <div class="info-card">
            <h3>Technical Details</h3>
            <p><strong>Model Architecture:</strong></p>
            <ul style="color: #94a3b8;">
                <li><strong>Encoder:</strong> GraphSAGE with HeteroConv layers</li>
                <li><strong>Task:</strong> Link Prediction + Node Classification</li>
                <li><strong>Training:</strong> Negative sampling with edge-level supervision</li>
            </ul>
            <p style="margin-top: 1rem;"><strong>Graph Structure:</strong></p>
            <ul style="color: #94a3b8;">
                <li><strong>Node Types:</strong> Supplier, Part, Region, External Supplier</li>
                <li><strong>Edge Types:</strong> SUPPLIES, COMPONENT_OF, LOCATED_IN, SHIPS_TO</li>
            </ul>
        </div>
        """, unsafe_allow_html=True)
    
    # Workflow steps
    st.markdown("#### Analysis Workflow", unsafe_allow_html=True)
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.markdown("""
        <div class="workflow-step">
            <h4>1. Ingest</h4>
            <p>Load ERP and Trade data into Snowflake tables</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("""
        <div class="workflow-step">
            <h4>2. Build</h4>
            <p>Construct the heterogeneous graph structure</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown("""
        <div class="workflow-step">
            <h4>3. Infer</h4>
            <p>Run GNN to predict links and propagate risk</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        st.markdown("""
        <div class="workflow-step">
            <h4>4. Act</h4>
            <p>Write results to tables for dashboard visualization</p>
        </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # HOW THE TECHNOLOGY WORKS - EXECUTIVE SUMMARY
    # ============================================
    st.markdown('<div class="section-header">How the Technology Works</div>', unsafe_allow_html=True)
    
    st.markdown("""
    <p style="color: #94a3b8; margin-bottom: 1.5rem; font-size: 1rem;">
        This section explains the technology at two levels: a business-focused overview for Supply Chain leaders, 
        and a technical deep-dive for Data Science teams.
    </p>
    """, unsafe_allow_html=True)
    
    # ============================================
    # EXECUTIVE OVERVIEW
    # ============================================
    st.markdown('<div class="section-header" style="font-size: 1.3rem; margin-top: 1rem;">Executive Overview</div>', unsafe_allow_html=True)
    
    st.markdown("### Why Traditional Approaches Fall Short")
    
    col1, col2 = st.columns([1, 1])
    
    with col1:
        st.markdown("""
        <div class="info-card">
            <h3>The Iceberg Problem</h3>
            <p>
                Think of your supply chain as an iceberg. Your ERP system shows you the <strong>10% above the waterline</strong>—your 
                direct Tier-1 suppliers. But <strong>90% of your risk</strong> lurks below: the Tier-2, Tier-3, and deeper 
                suppliers that your vendors depend on.
            </p>
            <p style="margin-top: 1rem;">
                <strong>Real Example:</strong> During the 2021 chip shortage, many automotive manufacturers discovered too late 
                that their "diversified" supplier base actually shared common dependencies on a handful of semiconductor fabs 
                and rare earth mineral refiners.
            </p>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("""
        <div class="info-card">
            <h3>The False Diversification Trap</h3>
            <p>
                Traditional risk assessments score suppliers independently—like grading students without knowing they all 
                copied from the same source. You might have 5 battery suppliers from 5 different countries, each with 
                a "low risk" score. But if they all source lithium from the same Australian refinery, you don't have 
                diversification—you have <strong>concentrated risk with extra steps</strong>.
            </p>
            <p style="margin-top: 1rem;">
                <strong>The Hidden Pattern:</strong> This demo reveals "Queensland Minerals"—a fictional Tier-2 supplier 
                that provides materials to 70% of our Tier-1 battery manufacturers. Traditional analysis misses this entirely.
            </p>
        </div>
        """, unsafe_allow_html=True)
    
    st.markdown("### How Graph Neural Networks Solve This")
    
    st.markdown("""
    <div class="info-card" style="margin-bottom: 1.5rem;">
        <h3>From Spreadsheets to Network Intelligence</h3>
        <p>
            Instead of treating each supplier as an isolated row in a spreadsheet, we model your supply chain as a 
            <strong>connected network</strong>—a graph where suppliers, materials, and regions are nodes, and their 
            relationships are edges. This mirrors how your supply chain actually works.
        </p>
        <p style="margin-top: 1rem;">
            The Graph Neural Network (GNN) then "walks" through this network, learning patterns like:
        </p>
        <ul style="color: #94a3b8; margin-top: 0.5rem;">
            <li><strong>Who supplies whom?</strong> Following the chain from raw materials to finished goods</li>
            <li><strong>Where do paths converge?</strong> Finding hidden chokepoints where multiple supply chains intersect</li>
            <li><strong>How does risk propagate?</strong> Understanding that a problem at Tier-3 will cascade to Tier-1</li>
            <li><strong>What relationships are we missing?</strong> Inferring hidden supplier connections from shipping patterns</li>
        </ul>
    </div>
    """, unsafe_allow_html=True)
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.markdown("""
        <div class="info-card" style="border-left: 4px solid #ef4444;">
            <h3 style="color: #ef4444;">Traditional Approach</h3>
            <p><strong>Method:</strong> Score each supplier independently based on financial health, location risk, and delivery history.</p>
            <p style="margin-top: 0.5rem;"><strong>Limitation:</strong> Completely misses network effects. A supplier with excellent scores can still be a single point of failure if they're the hidden source for multiple "independent" supply paths.</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("""
        <div class="info-card" style="border-left: 4px solid #f59e0b;">
            <h3 style="color: #f59e0b;">Manual Mapping</h3>
            <p><strong>Method:</strong> Survey Tier-1 suppliers about their sources, then survey those suppliers, and so on.</p>
            <p style="margin-top: 0.5rem;"><strong>Limitation:</strong> Expensive, slow, incomplete. Suppliers may not know or share their full network. Data is outdated by the time you collect it.</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown("""
        <div class="info-card" style="border-left: 4px solid #10b981;">
            <h3 style="color: #10b981;">GNN Approach</h3>
            <p><strong>Method:</strong> Combine internal ERP data with external trade intelligence. Let the AI discover hidden patterns and infer missing connections.</p>
            <p style="margin-top: 0.5rem;"><strong>Advantage:</strong> Automated, scalable, continuously updated. Discovers relationships that no human analyst would find manually.</p>
        </div>
        """, unsafe_allow_html=True)
    
    st.markdown("### Business Value")
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.markdown("""
        <div style="background: rgba(16, 185, 129, 0.1); border: 1px solid #10b981; border-radius: 12px; padding: 1.5rem; text-align: center;">
            <div style="font-size: 2rem; font-weight: 800; color: #10b981;">Early</div>
            <div style="color: #94a3b8; font-size: 0.9rem;">Warning System</div>
            <p style="color: #94a3b8; font-size: 0.8rem; margin-top: 0.5rem;">Identify risks before they cascade to production</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("""
        <div style="background: rgba(59, 130, 246, 0.1); border: 1px solid #3b82f6; border-radius: 12px; padding: 1.5rem; text-align: center;">
            <div style="font-size: 2rem; font-weight: 800; color: #3b82f6;">N-Tier</div>
            <div style="color: #94a3b8; font-size: 0.9rem;">Visibility</div>
            <p style="color: #94a3b8; font-size: 0.8rem; margin-top: 0.5rem;">See beyond Tier-1 to discover hidden dependencies</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown("""
        <div style="background: rgba(245, 158, 11, 0.1); border: 1px solid #f59e0b; border-radius: 12px; padding: 1.5rem; text-align: center;">
            <div style="font-size: 2rem; font-weight: 800; color: #f59e0b;">Quantified</div>
            <div style="color: #94a3b8; font-size: 0.9rem;">Risk Scores</div>
            <p style="color: #94a3b8; font-size: 0.8rem; margin-top: 0.5rem;">Data-driven prioritization for mitigation efforts</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        st.markdown("""
        <div style="background: rgba(139, 92, 246, 0.1); border: 1px solid #8b5cf6; border-radius: 12px; padding: 1.5rem; text-align: center;">
            <div style="font-size: 2rem; font-weight: 800; color: #8b5cf6;">Automated</div>
            <div style="color: #94a3b8; font-size: 0.9rem;">Discovery</div>
            <p style="color: #94a3b8; font-size: 0.8rem; margin-top: 0.5rem;">AI finds patterns humans would miss</p>
        </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # TECHNICAL DEEP-DIVE
    # ============================================
    st.markdown('<div class="section-header" style="font-size: 1.3rem;">Technical Deep-Dive</div>', unsafe_allow_html=True)
    
    st.markdown("### Graph Neural Networks: A Technical Overview")
    
    st.markdown("""
    <div class="info-card">
        <h3>Why Graphs? Why Neural Networks?</h3>
        <p>
            Supply chains are inherently <strong>relational</strong>—a vendor supplies a material, which is a component 
            of another material, which is sourced from a region with specific risk factors. Traditional ML treats each 
            entity as an independent feature vector, losing this rich structural information.
        </p>
        <p style="margin-top: 1rem;">
            <strong>Graph Neural Networks (GNNs)</strong> operate directly on graph-structured data. They learn node 
            representations by aggregating information from neighboring nodes through a process called <strong>message passing</strong>. 
            This means a supplier's risk embedding naturally incorporates information about what materials it supplies, 
            what region it's in, and who its upstream suppliers are.
        </p>
    </div>
    """, unsafe_allow_html=True)
    
    st.markdown("### Message Passing: The Core Mechanism")
    
    col1, col2 = st.columns([1, 1])
    
    with col1:
        st.markdown("""
        <div class="info-card">
            <h3>How Message Passing Works</h3>
            <p>At each layer of the GNN, every node:</p>
            <ol style="color: #94a3b8; margin-top: 0.5rem;">
                <li><strong>Gathers</strong> embeddings from all its neighbors</li>
                <li><strong>Aggregates</strong> them (mean, sum, or attention-weighted)</li>
                <li><strong>Combines</strong> with its own embedding</li>
                <li><strong>Transforms</strong> through a learned neural network layer</li>
            </ol>
            <p style="margin-top: 1rem;">
                With <strong>2 layers</strong>, each node's final embedding contains information from nodes up to 
                <strong>2 hops away</strong>. This is exactly what we need: a Tier-1 supplier's embedding will 
                incorporate information about Tier-2 suppliers (via the materials they both connect to).
            </p>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("""
        <div class="info-card">
            <h3>Mathematical Formulation</h3>
            <p>For a node <em>v</em> at layer <em>l</em>:</p>
            <div style="background: rgba(15, 23, 42, 0.8); border-radius: 8px; padding: 1rem; margin: 0.5rem 0; font-family: monospace; color: #93c5fd;">
                h<sub>v</sub><sup>(l+1)</sup> = σ( W · AGG({h<sub>u</sub><sup>(l)</sup> : u ∈ N(v)}) + B · h<sub>v</sub><sup>(l)</sup> )
            </div>
            <p style="margin-top: 0.5rem;"><strong>Where:</strong></p>
            <ul style="color: #94a3b8; font-size: 0.9rem;">
                <li><strong>h<sub>v</sub></strong> = embedding of node v</li>
                <li><strong>N(v)</strong> = neighbors of node v</li>
                <li><strong>AGG</strong> = aggregation function (mean in GraphSAGE)</li>
                <li><strong>W, B</strong> = learnable weight matrices</li>
                <li><strong>σ</strong> = activation function (ReLU)</li>
            </ul>
        </div>
        """, unsafe_allow_html=True)
    
    st.markdown("### Heterogeneous Graph Structure")
    
    st.markdown("""
    <div class="info-card">
        <h3>Multi-Typed Nodes and Edges</h3>
        <p>
            Our supply chain graph is <strong>heterogeneous</strong>—it has multiple types of nodes and edges, each with 
            different semantics and feature spaces:
        </p>
    </div>
    """, unsafe_allow_html=True)
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("""
        <div class="table-card">
            <h4 style="color: #3b82f6;">Node Types</h4>
            <table style="width: 100%; color: #94a3b8; font-size: 0.9rem;">
                <tr style="border-bottom: 1px solid #334155;">
                    <td style="padding: 0.5rem 0;"><strong>Vendor</strong></td>
                    <td>Tier-1 suppliers from ERP</td>
                </tr>
                <tr style="border-bottom: 1px solid #334155;">
                    <td style="padding: 0.5rem 0;"><strong>Material</strong></td>
                    <td>Parts (RAW, SEMI, FIN)</td>
                </tr>
                <tr style="border-bottom: 1px solid #334155;">
                    <td style="padding: 0.5rem 0;"><strong>Region</strong></td>
                    <td>Countries with risk factors</td>
                </tr>
                <tr>
                    <td style="padding: 0.5rem 0;"><strong>External</strong></td>
                    <td>Tier-2+ from trade data</td>
                </tr>
            </table>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("""
        <div class="table-card">
            <h4 style="color: #10b981;">Edge Types</h4>
            <table style="width: 100%; color: #94a3b8; font-size: 0.9rem;">
                <tr style="border-bottom: 1px solid #334155;">
                    <td style="padding: 0.5rem 0;"><strong>SUPPLIES</strong></td>
                    <td>Vendor → Material</td>
                </tr>
                <tr style="border-bottom: 1px solid #334155;">
                    <td style="padding: 0.5rem 0;"><strong>COMPONENT_OF</strong></td>
                    <td>Material → Material (BOM)</td>
                </tr>
                <tr style="border-bottom: 1px solid #334155;">
                    <td style="padding: 0.5rem 0;"><strong>LOCATED_IN</strong></td>
                    <td>Vendor → Region</td>
                </tr>
                <tr>
                    <td style="padding: 0.5rem 0;"><strong>SHIPS_TO</strong></td>
                    <td>External → Vendor</td>
                </tr>
            </table>
        </div>
        """, unsafe_allow_html=True)
    
    st.markdown("### Model Architecture: GraphSAGE with HeteroConv")
    
    st.markdown("""
    <div class="info-card">
        <h3>Architecture Details</h3>
        <p>We use <strong>GraphSAGE</strong> (Graph SAmple and aggreGatE) wrapped in <strong>HeteroConv</strong> for heterogeneous message passing:</p>
    </div>
    """, unsafe_allow_html=True)
    
    st.code("""Input Features (varying dimensions per node type)
    ↓
Linear Projection → hidden_dim (64)
    ↓
ReLU Activation
    ↓
HeteroConv Layer 1 (SAGEConv per edge type) → hidden_dim
    ↓
ReLU + Dropout (0.3)
    ↓
HeteroConv Layer 2 (SAGEConv per edge type) → out_dim (32)
    ↓
Node Embeddings (used for link prediction + risk scoring)""", language=None)
    
    st.markdown("""
    <div class="info-card" style="margin-top: 1rem;">
        <p><strong>Key Design Choices:</strong></p>
        <ul style="color: #94a3b8;">
            <li><strong>HeteroConv:</strong> Applies separate SAGEConv layers for each edge type, then aggregates. This lets the model learn that "SUPPLIES" relationships matter differently than "LOCATED_IN" relationships.</li>
            <li><strong>2 Layers:</strong> Captures 2-hop neighborhoods—exactly what's needed for Tier-1 to Tier-2 inference.</li>
            <li><strong>Bidirectional Edges:</strong> We use <code>ToUndirected()</code> to add reverse edges, enabling information flow in both directions.</li>
        </ul>
    </div>
    """, unsafe_allow_html=True)
    
    st.markdown("### Self-Supervised Training: Link Prediction")
    
    col1, col2 = st.columns([1, 1])
    
    with col1:
        st.markdown("""
        <div class="info-card">
            <h3>Why Link Prediction?</h3>
            <p>
                We don't have labeled "risk scores" for every supplier. Instead, we train the model using 
                <strong>link prediction</strong> as a self-supervised proxy task:
            </p>
            <ul style="color: #94a3b8; margin-top: 0.5rem;">
                <li><strong>Positive samples:</strong> Real edges from trade data (External → Vendor shipments)</li>
                <li><strong>Negative samples:</strong> Random pairs that don't have edges</li>
            </ul>
            <p style="margin-top: 1rem;">
                The model learns: "Given two node embeddings, predict if an edge should exist." To do this well, 
                it must learn meaningful representations that capture the underlying supply chain structure.
            </p>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("""
        <div class="info-card">
            <h3>Training Details</h3>
            <p><strong>Loss Function:</strong> Binary Cross-Entropy</p>
            <div style="background: rgba(15, 23, 42, 0.8); border-radius: 8px; padding: 0.75rem; margin: 0.5rem 0; font-family: monospace; color: #93c5fd; font-size: 0.9rem;">
                L = -[y·log(p) + (1-y)·log(1-p)]
            </div>
            <p style="margin-top: 0.5rem;"><strong>Link Probability:</strong> Dot-product decoder</p>
            <div style="background: rgba(15, 23, 42, 0.8); border-radius: 8px; padding: 0.75rem; margin: 0.5rem 0; font-family: monospace; color: #93c5fd; font-size: 0.9rem;">
                P(edge) = σ(z<sub>src</sub> · z<sub>dst</sub>)
            </div>
            <p style="margin-top: 0.5rem;"><strong>Hyperparameters:</strong></p>
            <ul style="color: #94a3b8; font-size: 0.9rem;">
                <li>Epochs: 200</li>
                <li>Learning rate: 0.01 with plateau scheduler</li>
                <li>L2 regularization: 0.001</li>
            </ul>
        </div>
        """, unsafe_allow_html=True)
    
    st.markdown("### Risk Propagation & Bottleneck Detection")
    
    st.markdown("""
    <div class="info-card">
        <h3>From Embeddings to Risk Scores</h3>
        <p>
            After training, each node has a learned embedding that captures its position and role in the supply network. 
            We compute risk scores by:
        </p>
        <ol style="color: #94a3b8; margin-top: 0.5rem;">
            <li><strong>Base Risk:</strong> Combine node features (financial health, regional risk factors)</li>
            <li><strong>Propagated Risk:</strong> Aggregate risk from connected nodes weighted by edge importance</li>
            <li><strong>Network Risk:</strong> Factor in centrality—nodes with many dependents are riskier bottlenecks</li>
        </ol>
        <p style="margin-top: 1rem;">
            <strong>Bottleneck Detection:</strong> We identify nodes where the SHIPS_TO edges from External suppliers 
            converge on multiple Tier-1 Vendors. If an External supplier has high in-degree to Vendors that themselves 
            supply critical materials, that External supplier is a concentration risk.
        </p>
    </div>
    """, unsafe_allow_html=True)
    
    st.markdown("### Key Innovation: Discovering the Unknown")
    
    st.markdown("""
    <div class="info-card" style="border-left: 4px solid #10b981;">
        <h3>What Makes This Novel</h3>
        <p>
            Traditional supplier risk systems answer: <em>"How risky is this supplier I know about?"</em>
        </p>
        <p style="margin-top: 0.5rem;">
            This GNN-based approach answers: <em>"What suppliers exist that I don't know about, and how do they 
            create hidden concentration risks across my supposedly diversified supply base?"</em>
        </p>
        <p style="margin-top: 1rem;">
            The combination of <strong>internal ERP data</strong> (what we transact) with <strong>external trade intelligence</strong> 
            (what ships globally) enables inference of relationships that neither dataset reveals alone. The GNN learns 
            to connect the dots, surfacing the "Queensland Minerals" hidden bottlenecks that would otherwise remain 
            invisible until a disruption occurs.
        </p>
    </div>
    """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # APP PAGES
    # ============================================
    st.markdown('<div class="section-header">Application Pages</div>', unsafe_allow_html=True)
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("""
        <div class="info-card">
            <h3>Home</h3>
            <p>Executive dashboard with key metrics, top concentration risk visualization, and navigation to analysis modules.</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown("""
        <div class="info-card">
            <h3>Exploratory Analysis</h3>
            <p>Data source overview showing connected tables, record counts, and the visibility gap between known Tier-1 and inferred Tier-2+ relationships.</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown("""
        <div class="info-card">
            <h3>Supply Network</h3>
            <p>Interactive force-directed graph visualization of the multi-tier supply network with node filtering and relationship exploration.</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("""
        <div class="info-card">
            <h3>Tier-2 Analysis</h3>
            <p>Deep dive into concentration risk with bottleneck identification, predicted link analysis, and confidence scoring.</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown("""
        <div class="info-card">
            <h3>Risk Mitigation</h3>
            <p>Prioritized action items with impact/probability matrix, AI-assisted analysis, and mitigation recommendations.</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown("""
        <div class="info-card">
            <h3>About</h3>
            <p>This page! Documentation of the demo architecture, data sources, and technical implementation.</p>
        </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # TECH STACK
    # ============================================
    st.markdown('<div class="section-header">Technology Stack</div>', unsafe_allow_html=True)
    
    st.markdown("""
    <div class="tech-stack">
        <span class="tech-badge">Snowflake</span>
        <span class="tech-badge">Snowpark</span>
        <span class="tech-badge">Snowflake Notebooks</span>
        <span class="tech-badge">Streamlit in Snowflake</span>
        <span class="tech-badge">PyTorch Geometric</span>
        <span class="tech-badge">GraphSAGE</span>
        <span class="tech-badge">Plotly</span>
        <span class="tech-badge">Python 3.11</span>
    </div>
    """, unsafe_allow_html=True)
    
    st.markdown("")
    st.markdown("")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.markdown("""
        <div class="info-card">
            <h3>Snowflake Platform</h3>
            <p>
                All data, compute, and AI run within Snowflake's secure governance boundary. 
                No data movement required.
            </p>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("""
        <div class="info-card">
            <h3>Graph Neural Networks</h3>
            <p>
                PyTorch Geometric enables sophisticated graph-based machine learning for 
                link prediction and risk propagation.
            </p>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown("""
        <div class="info-card">
            <h3>Interactive Visualization</h3>
            <p>
                Streamlit provides a modern, responsive interface with Plotly charts 
                and custom D3.js components.
            </p>
        </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # ============================================
    # GETTING STARTED
    # ============================================
    st.markdown('<div class="section-header">Getting Started</div>', unsafe_allow_html=True)
    
    st.markdown("""
    <div class="info-card">
        <h3>Quick Start Guide</h3>
        <ol style="color: #94a3b8; line-height: 2;">
            <li><strong>Run the Setup:</strong> Execute the SQL scripts to create the database, schema, and load sample data</li>
            <li><strong>Execute the Notebook:</strong> Open the GNN notebook in Snowflake and run all cells to generate risk scores, predicted links, and bottlenecks</li>
            <li><strong>Explore the Dashboard:</strong> Navigate through the Streamlit app pages to visualize the results</li>
            <li><strong>Analyze Risks:</strong> Use the Tier-2 Analysis page to identify concentration points and the Risk Mitigation page to prioritize actions</li>
        </ol>
    </div>
    """, unsafe_allow_html=True)
    
    # Footer
    st.markdown("")
    st.markdown("""
    <p style="text-align: center; color: #64748b; font-size: 0.85rem; margin-top: 2rem;">
        Built with Snowflake | PyTorch Geometric | Streamlit
    </p>
    """, unsafe_allow_html=True)
    
    # Sidebar
    render_sidebar()


if __name__ == "__main__":
    main()

