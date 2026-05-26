"""
Reusable sidebar navigation component for the Supply Chain Risk application.

Provides consistent navigation across all pages, plus guided demo mode functionality.
"""

import streamlit as st


# STAR method callout content for each page
STAR_CALLOUTS = {
    "home": {
        "phase": "SITUATION",
        "icon": "",
        "color": "#dc2626",
        "title": "The Hidden Risk",
        "content": """Your ERP shows a diversified supply base with multiple suppliers across different 
countries. But this view only shows Tier-1 relationships. What you can't see is that multiple 
"independent" suppliers may depend on the same hidden Tier-2 source — creating concentration 
risk that traditional analytics miss entirely."""
    },
    "exploratory": {
        "phase": "TASK",
        "icon": "",
        "color": "#f59e0b",
        "title": "Understanding the Data Gap",
        "content": """The task is to extend visibility beyond Tier-1. We fuse internal ERP data 
(vendors, materials, purchase orders, BOMs) with external trade intelligence (bills of lading, 
shipment records) to build a complete picture of the supply network. This data fusion is the 
foundation for graph-based risk analysis."""
    },
    "network": {
        "phase": "TASK",
        "icon": "",
        "color": "#f59e0b",
        "title": "Building the Knowledge Graph",
        "content": """By modeling the supply chain as a graph, we transform isolated data rows into 
connected intelligence. Suppliers, materials, and regions become nodes; transactions and trade 
flows become edges. This structure enables the GNN to learn patterns and infer hidden relationships 
that would be invisible in traditional tabular analysis."""
    },
    "tier2": {
        "phase": "ACTION",
        "icon": "",
        "color": "#29B5E8",  # Snowflake Blue
        "title": "AI-Powered Discovery",
        "content": """The Graph Neural Network analyzes trade patterns to predict likely Tier-2+ 
relationships with probability scores. It identifies concentration points where multiple Tier-1 
suppliers converge on shared upstream sources. Each bottleneck is scored by impact and supported 
by trade evidence — transforming guesswork into data-driven insight."""
    },
    "mitigation": {
        "phase": "ACTION",
        "icon": "",
        "color": "#29B5E8",  # Snowflake Blue
        "title": "Prioritized Response",
        "content": """With hidden risks surfaced, the system prioritizes actions by impact and probability. 
AI-generated guidance provides specific mitigation strategies for each concentration point. This 
transforms supply chain management from reactive firefighting to proactive resilience building."""
    },
    "executive": {
        "phase": "RESULT",
        "icon": "",
        "color": "#10b981",
        "title": "Measurable Value",
        "content": """The result: full visibility into your extended supply network, quantified risk 
reduction, and proactive supplier qualification. What previously took weeks of manual research 
now happens in minutes. Concentration risks are identified before they cause disruptions, not after."""
    },
    "simulator": {
        "phase": "ACTION",
        "icon": "",
        "color": "#29B5E8",  # Snowflake Blue
        "title": "What-If Analysis",
        "content": """Simulate disruption scenarios to understand cascading impacts before they happen. 
Select a region or supplier, inject a shock, and watch how risk propagates through the network. 
This predictive capability enables strategic planning and contingency preparation."""
    },
    "command": {
        "phase": "ACTION",
        "icon": "",
        "color": "#29B5E8",  # Snowflake Blue
        "title": "Operational Monitoring",
        "content": """Track active alerts, monitor watchlisted suppliers, and manage mitigation actions 
in real-time. This operational view keeps supply chain teams informed and enables rapid response 
when conditions change."""
    },
    "about": {
        "phase": "REFERENCE",
        "icon": "",
        "color": "#8b5cf6",
        "title": "Technical Foundation",
        "content": """This solution runs entirely within Snowflake's secure governance boundary. 
PyTorch Geometric models execute in GPU-enabled notebooks, results flow to governed tables, 
and Streamlit surfaces insights — no data movement, no pipeline complexity."""
    }
}


def get_demo_mode() -> bool:
    """Get current guided demo mode state."""
    if "guided_demo_mode" not in st.session_state:
        st.session_state.guided_demo_mode = False
    return st.session_state.guided_demo_mode


def render_star_callout(page_key: str):
    """
    Render STAR method callout for a specific page if demo mode is enabled.
    
    Args:
        page_key: Key identifying the page (e.g., 'home', 'tier2', 'executive')
    """
    if not get_demo_mode():
        return
    
    callout = STAR_CALLOUTS.get(page_key)
    if not callout:
        return
    
    phase = callout["phase"]
    icon = callout["icon"]
    color = callout["color"]
    title = callout["title"]
    content = callout["content"]
    
    # Phase badge styling (using Snowflake Blue for ACTION per brand guidelines)
    phase_colors = {
        "SITUATION": "#dc2626",
        "TASK": "#f59e0b",
        "ACTION": "#29B5E8",  # Snowflake Blue
        "RESULT": "#10b981",
        "REFERENCE": "#8b5cf6"
    }
    badge_color = phase_colors.get(phase, color)
    
    st.markdown(f"""
    <div style="
        background: linear-gradient(135deg, rgba({_hex_to_rgb(badge_color)}, 0.15) 0%, rgba({_hex_to_rgb(badge_color)}, 0.05) 100%);
        border: 1px solid {badge_color};
        border-radius: 12px;
        padding: 1.25rem 1.5rem;
        margin-bottom: 1.5rem;
    ">
        <div style="display: flex; align-items: center; gap: 0.75rem; margin-bottom: 0.75rem;">
            <span style="
                background: {badge_color};
                color: white;
                padding: 4px 12px;
                border-radius: 20px;
                font-size: 0.75rem;
                font-weight: 700;
                letter-spacing: 0.05em;
            ">{phase}</span>
            <span style="color: #f8fafc; font-weight: 700; font-size: 1.1rem;">{title}</span>
        </div>
        <p style="color: #cbd5e1; line-height: 1.6; margin: 0; font-size: 0.95rem;">
            {content}
        </p>
    </div>
    """, unsafe_allow_html=True)


def render_star_progress():
    """Render STAR method progress indicator in sidebar when demo mode is enabled."""
    if not get_demo_mode():
        return
    
    st.markdown("#### Demo Progress")
    st.markdown("""
    <div style="font-size: 0.85rem; line-height: 1.8; color: #94a3b8;">
        <div><span style="color: #dc2626;">S</span> <strong>SITUATION</strong> — The Problem</div>
        <div><span style="color: #f59e0b;">T</span> <strong>TASK</strong> — What We Solve</div>
        <div><span style="color: #29B5E8;">A</span> <strong>ACTION</strong> — How We Do It</div>
        <div><span style="color: #10b981;">R</span> <strong>RESULT</strong> — Value Delivered</div>
    </div>
    """, unsafe_allow_html=True)
    st.markdown("---")


def _hex_to_rgb(hex_color: str) -> str:
    """Convert hex color to RGB string for CSS rgba()."""
    hex_color = hex_color.lstrip('#')
    r, g, b = tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))
    return f"{r}, {g}, {b}"


def render_sidebar():
    """
    Render the standard sidebar navigation for the application.
    
    Includes:
    - Application title/branding
    - Guided demo mode toggle
    - Navigation links to all pages
    - STAR progress indicator (when demo mode enabled)
    - Refresh data button
    
    Should be called at the end of each page's main() function.
    """
    with st.sidebar:
        st.markdown("### Supply Chain Risk")
        st.markdown("---")
        
        # STAR progress indicator (when demo mode enabled) - show at top if active
        render_star_progress()
        
        # Navigation
        st.page_link("streamlit_app.py", label="Home")
        st.page_link("pages/1_Executive_Summary.py", label="Executive Summary")
        st.page_link("pages/2_Exploratory_Analysis.py", label="Exploratory Analysis")
        st.page_link("pages/3_Supply_Network.py", label="Supply Network")
        st.page_link("pages/4_Tier2_Analysis.py", label="Tier-2 Analysis")
        st.page_link("pages/5_Scenario_Simulator.py", label="Scenario Simulator")
        st.page_link("pages/6_Command_Center.py", label="Command Center")
        st.page_link("pages/7_Risk_Mitigation.py", label="Risk Mitigation")
        st.page_link("pages/8_About.py", label="About")
        st.markdown("---")
        
        if st.button("Refresh Data"):
            st.cache_data.clear()
            st.rerun()
        
        st.markdown("")
        
        # Guided Demo Mode toggle - at bottom of sidebar
        demo_mode = st.toggle(
            "Guided Demo Mode",
            value=get_demo_mode(),
            help="Enable contextual STAR method annotations throughout the demo"
        )
        st.session_state.guided_demo_mode = demo_mode
        
        if demo_mode:
            st.caption("STAR annotations enabled")
