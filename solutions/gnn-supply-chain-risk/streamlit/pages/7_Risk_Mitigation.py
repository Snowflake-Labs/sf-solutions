"""
Risk Mitigation Page

Risk prioritization, recommended actions, and AI-assisted analysis.
"""

import streamlit as st
import pandas as pd
import altair as alt
import sys
from pathlib import Path
from snowflake.snowpark.context import get_active_session

# Add parent directory to path for utils import (needed for Streamlit in Snowflake)
sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.data_loader import run_queries_parallel, DB_SCHEMA
from utils.sidebar import render_sidebar, render_star_callout

st.set_page_config(
    page_title="Risk Mitigation",
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
    .action-card {
        background: rgba(30, 41, 59, 0.8);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1.5rem;
        margin: 1rem 0;
    }
    .action-card.urgent {
        border-left: 4px solid #dc2626;
    }
    .action-card.important {
        border-left: 4px solid #f59e0b;
    }
    .action-card.routine {
        border-left: 4px solid #10b981;
    }
    .action-title {
        font-size: 1.1rem;
        font-weight: 700;
        color: #f8fafc;
        margin-bottom: 0.5rem;
    }
    .action-description {
        color: #94a3b8;
        font-size: 0.95rem;
        line-height: 1.5;
    }
    .priority-badge {
        display: inline-block;
        padding: 4px 12px;
        border-radius: 20px;
        font-size: 0.75rem;
        font-weight: 600;
        text-transform: uppercase;
    }
    .priority-urgent {
        background: #dc2626;
        color: #fff;
    }
    .priority-important {
        background: #f59e0b;
        color: #000;
    }
    .priority-routine {
        background: #10b981;
        color: #fff;
    }
    .risk-row {
        background: rgba(15, 23, 42, 0.5);
        border-radius: 8px;
        padding: 0.75rem 1rem;
        margin: 0.5rem 0;
        display: flex;
        align-items: center;
        justify-content: space-between;
    }
    .risk-name {
        color: #f8fafc;
        font-weight: 500;
    }
    .risk-score {
        font-weight: 700;
        padding: 4px 12px;
        border-radius: 4px;
    }
    .risk-critical { background: #dc2626; color: #fff; }
    .risk-high { background: #ea580c; color: #fff; }
    .risk-medium { background: #ca8a04; color: #000; }
    .risk-low { background: #16a34a; color: #fff; }
    .chat-container {
        background: rgba(15, 23, 42, 0.8);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1rem;
        height: 400px;
        overflow-y: auto;
    }
    .sample-question {
        background: rgba(59, 130, 246, 0.2);
        border: 1px solid #3b82f6;
        border-radius: 8px;
        padding: 0.5rem 1rem;
        margin: 0.25rem 0;
        cursor: pointer;
        transition: all 0.2s;
        color: #93c5fd;
        font-size: 0.9rem;
    }
    .sample-question:hover {
        background: rgba(59, 130, 246, 0.4);
    }
    
    /* Hide default multipage navigation */
    [data-testid="stSidebarNav"] {display: none;}
</style>
""", unsafe_allow_html=True)


@st.cache_resource
def get_session():
    return get_active_session()


@st.cache_data(ttl=300)
def load_high_risk_suppliers(_session, limit=15):
    """Load highest risk suppliers."""
    try:
        result = _session.sql(f"""
            SELECT 
                rs.NODE_ID,
                v.NAME as VENDOR_NAME,
                v.COUNTRY_CODE,
                rs.RISK_SCORE,
                rs.RISK_CATEGORY,
                rs.CONFIDENCE,
                v.FINANCIAL_HEALTH_SCORE
            FROM {DB_SCHEMA}.RISK_SCORES rs
            LEFT JOIN {DB_SCHEMA}.VENDORS v ON rs.NODE_ID = v.VENDOR_ID
            WHERE rs.NODE_TYPE = 'SUPPLIER'
            ORDER BY rs.RISK_SCORE DESC
            LIMIT {limit}
        """).to_pandas()
        return result
    except:
        return None


@st.cache_data(ttl=300)
def load_risk_matrix_data(_session):
    """Load data for risk matrix visualization."""
    try:
        # Suppliers with risk scores
        df = _session.sql(f"""
            SELECT 
                rs.NODE_ID as ID,
                COALESCE(v.NAME, rs.NODE_ID) as NAME,
                rs.RISK_SCORE as PROBABILITY,
                COALESCE(b.IMPACT_SCORE, rs.RISK_SCORE * 0.5) as IMPACT,
                'SUPPLIER' as CATEGORY
            FROM {DB_SCHEMA}.RISK_SCORES rs
            LEFT JOIN {DB_SCHEMA}.VENDORS v ON rs.NODE_ID = v.VENDOR_ID
            LEFT JOIN (
                SELECT TARGET_NODE_ID, MAX(PROBABILITY) as IMPACT_SCORE
                FROM {DB_SCHEMA}.PREDICTED_LINKS
                GROUP BY TARGET_NODE_ID
            ) b ON rs.NODE_ID = b.TARGET_NODE_ID
            WHERE rs.NODE_TYPE = 'SUPPLIER'
        """).to_pandas()
        
        # Fill nulls and ensure numeric types
        df['PROBABILITY'] = pd.to_numeric(df['PROBABILITY'], errors='coerce').fillna(0.3)
        df['IMPACT'] = pd.to_numeric(df['IMPACT'], errors='coerce').fillna(0.3)
        
        # Add quadrant classification for coloring
        def get_quadrant(row):
            if row['IMPACT'] >= 0.5 and row['PROBABILITY'] >= 0.5:
                return 'Critical'
            elif row['IMPACT'] >= 0.5:
                return 'Manage'
            elif row['PROBABILITY'] >= 0.5:
                return 'Monitor'
            else:
                return 'Accept'
        
        df['QUADRANT'] = df.apply(get_quadrant, axis=1)
        
        return df
    except:
        return pd.DataFrame()


@st.cache_data(ttl=300)
def load_recommended_actions(_session):
    """Generate recommended actions based on risk analysis using parallel query execution."""
    actions = []
    
    # Define queries for parallel execution
    queries = {
        'bottlenecks': f"""
            SELECT NODE_ID, DEPENDENT_COUNT, IMPACT_SCORE, DESCRIPTION
            FROM {DB_SCHEMA}.BOTTLENECKS
            WHERE IMPACT_SCORE >= 0.5
            ORDER BY IMPACT_SCORE DESC
            LIMIT 5
        """,
        'high_risk': f"""
            SELECT v.NAME, rs.RISK_SCORE, v.COUNTRY_CODE
            FROM {DB_SCHEMA}.RISK_SCORES rs
            JOIN {DB_SCHEMA}.VENDORS v ON rs.NODE_ID = v.VENDOR_ID
            WHERE rs.NODE_TYPE = 'SUPPLIER' AND rs.RISK_CATEGORY IN ('CRITICAL', 'HIGH')
            ORDER BY rs.RISK_SCORE DESC
            LIMIT 3
        """
    }
    
    # Execute both queries in parallel
    results = run_queries_parallel(_session, queries, max_workers=2)
    
    # Process bottlenecks results
    bottlenecks = results.get('bottlenecks')
    if bottlenecks is not None and not bottlenecks.empty:
        for _, row in bottlenecks.iterrows():
            actions.append({
                "priority": "urgent",
                "title": f"Mitigate {row['NODE_ID']} dependency",
                "description": f"This hidden Tier-2 supplier affects {row['DEPENDENT_COUNT']} of your vendors. "
                              f"Identify alternative sources or establish direct relationship.",
                "impact_score": float(row['IMPACT_SCORE']),
                "action_type": "bottleneck",
                "node_id": row['NODE_ID'],
                "dependent_count": row['DEPENDENT_COUNT']
            })
    
    # Process high-risk suppliers results
    high_risk = results.get('high_risk')
    if high_risk is not None and not high_risk.empty:
        for _, row in high_risk.iterrows():
            actions.append({
                "priority": "important",
                "title": f"Review {row['NAME']} risk exposure",
                "description": f"Risk score: {row['RISK_SCORE']:.0%}. Located in {row['COUNTRY_CODE']}. "
                              f"Consider diversification or contingency planning.",
                "impact_score": float(row['RISK_SCORE']),
                "action_type": "high_risk_supplier",
                "supplier_name": row['NAME'],
                "country": row['COUNTRY_CODE'],
                "risk_score": float(row['RISK_SCORE'])
            })
    
    # General recommendations (always added)
    actions.append({
        "priority": "routine",
        "title": "Update trade data feeds",
        "description": "Refresh external trade intelligence data to ensure predictions reflect current market conditions.",
        "impact_score": 0.3,
        "action_type": "routine"
    })
    
    actions.append({
        "priority": "routine",
        "title": "Quarterly risk review",
        "description": "Schedule regular review of risk scores and predicted links with procurement team.",
        "impact_score": 0.25,
        "action_type": "routine"
    })
    
    # If no data-driven actions were added, add a fallback
    if len(actions) == 2:  # Only the two routine actions
        actions.insert(0, {
            "priority": "important",
            "title": "Run GNN analysis",
            "description": "Execute the GNN notebook to generate risk scores and predictions.",
            "impact_score": 0.5,
            "action_type": "routine"
        })
    
    return actions


def _build_action_prompt(action: dict) -> str:
    """Build the prompt for a given action type."""
    action_type = action.get('action_type', 'routine')
    
    if action_type == "bottleneck":
        return f"""You are a supply chain risk advisor. Provide a detailed explanation and specific mitigation strategies for this recommended action.

Action: {action['title']}
Context: 
- This is a hidden Tier-2 supplier that {action.get('dependent_count', 0)} of our Tier-1 vendors depend on
- Impact score: {action.get('impact_score', 0):.0%}

Provide 3-4 specific, actionable mitigation strategies. Be concise but practical. Include:
1. Immediate actions (within 30 days)
2. Medium-term actions (1-3 months)  
3. Long-term strategic changes

Format as a brief paragraph for each strategy.

Output only the strategies. No preamble, headers, or follow-up questions."""

    elif action_type == "high_risk_supplier":
        return f"""You are a supply chain risk advisor. Provide detailed guidance for managing this high-risk supplier situation.

Action: {action['title']}
Context:
- Supplier: {action.get('supplier_name', 'Unknown')}
- Location: {action.get('country', 'Unknown')}
- Risk Score: {action.get('risk_score', 0):.0%}

Provide 3-4 specific recommendations for risk mitigation. Consider:
1. Due diligence steps to understand the risk better
2. Contingency planning measures
3. Diversification strategies
4. Relationship management approaches

Be practical and actionable.

Output only the recommendations. No preamble, headers, or follow-up questions."""

    else:
        return f"""You are a supply chain operations advisor. Provide practical implementation guidance for this recommended action.

Action: {action['title']}
Description: {action.get('description', '')}

Provide 2-3 specific implementation steps with timelines and key considerations. Be concise and actionable.

Output only the steps. No preamble, headers, or follow-up questions."""


@st.cache_data(ttl=600)
def prefetch_all_action_explanations(_session, actions: list):
    """
    Prefetch AI explanations for all actions in parallel.
    Returns dict mapping action index -> AI explanation text.
    """
    from concurrent.futures import ThreadPoolExecutor, as_completed
    
    if not actions:
        return {}
    
    def generate_single_explanation(idx: int, action: dict) -> tuple:
        """Generate AI explanation for a single action."""
        try:
            prompt = _build_action_prompt(action)
            escaped_prompt = prompt.replace("'", "''")
            
            result = _session.sql(f"""
                SELECT SNOWFLAKE.CORTEX.COMPLETE(
                    'llama3.1-70b',
                    '{escaped_prompt}'
                ) as RESPONSE
            """).to_pandas()
            
            if not result.empty and result['RESPONSE'].iloc[0]:
                return idx, result['RESPONSE'].iloc[0].strip()
            return idx, None
        except Exception:
            return idx, None
    
    # Execute all AI calls in parallel
    results = {}
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = {executor.submit(generate_single_explanation, idx, action): idx 
                   for idx, action in enumerate(actions)}
        
        for future in as_completed(futures):
            try:
                idx, explanation = future.result()
                results[idx] = explanation
            except Exception:
                pass
    
    return results


@st.cache_data(ttl=600)
def generate_action_ai_explanation(_session, action: dict):
    """Generate detailed AI explanation for a recommended action (single action fallback)."""
    try:
        prompt = _build_action_prompt(action)
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


def render_risk_matrix(df, height=400):
    """Render risk priority matrix using Altair."""
    
    if df.empty:
        st.info("No risk data available for matrix visualization.")
        return
    
    # Define color scale for quadrants
    color_scale = alt.Scale(
        domain=['Critical', 'Manage', 'Monitor', 'Accept'],
        range=['#dc2626', '#ea580c', '#ca8a04', '#16a34a']
    )
    
    # Create quadrant background data
    quadrants = pd.DataFrame([
        {'x': 0.5, 'x2': 1.0, 'y': 0.5, 'y2': 1.0, 'label': 'CRITICAL', 'color': '#dc262620'},
        {'x': 0.0, 'x2': 0.5, 'y': 0.5, 'y2': 1.0, 'label': 'MONITOR', 'color': '#ca8a0420'},
        {'x': 0.5, 'x2': 1.0, 'y': 0.0, 'y2': 0.5, 'label': 'MANAGE', 'color': '#ea580c20'},
        {'x': 0.0, 'x2': 0.5, 'y': 0.0, 'y2': 0.5, 'label': 'ACCEPT', 'color': '#16a34a20'},
    ])
    
    # Quadrant backgrounds
    quadrant_bg = alt.Chart(quadrants).mark_rect().encode(
        x=alt.X('x:Q', scale=alt.Scale(domain=[0, 1])),
        x2='x2:Q',
        y=alt.Y('y:Q', scale=alt.Scale(domain=[0, 1])),
        y2='y2:Q',
        color=alt.Color('color:N', scale=None, legend=None)
    )
    
    # Quadrant labels
    quadrant_labels = alt.Chart(quadrants).mark_text(
        fontSize=11,
        fontWeight='bold',
        opacity=0.5
    ).encode(
        x=alt.X('label_x:Q'),
        y=alt.Y('label_y:Q'),
        text='label:N'
    ).transform_calculate(
        label_x='(datum.x + datum.x2) / 2',
        label_y='(datum.y + datum.y2) / 2'
    )
    
    # Threshold lines
    vline = alt.Chart(pd.DataFrame({'x': [0.5]})).mark_rule(
        strokeDash=[4, 4],
        stroke='#475569'
    ).encode(x='x:Q')
    
    hline = alt.Chart(pd.DataFrame({'y': [0.5]})).mark_rule(
        strokeDash=[4, 4],
        stroke='#475569'
    ).encode(y='y:Q')
    
    # Main scatter plot
    points = alt.Chart(df).mark_circle(size=120, stroke='#0f172a', strokeWidth=1.5).encode(
        x=alt.X('IMPACT:Q', 
                scale=alt.Scale(domain=[0, 1]),
                axis=alt.Axis(title='Impact Score', format='%', tickCount=5)),
        y=alt.Y('PROBABILITY:Q', 
                scale=alt.Scale(domain=[0, 1]),
                axis=alt.Axis(title='Risk Probability', format='%', tickCount=5)),
        color=alt.Color('QUADRANT:N', 
                       scale=color_scale,
                       legend=alt.Legend(title='Risk Level')),
        tooltip=[
            alt.Tooltip('NAME:N', title='Supplier'),
            alt.Tooltip('IMPACT:Q', title='Impact', format='.0%'),
            alt.Tooltip('PROBABILITY:Q', title='Probability', format='.0%'),
            alt.Tooltip('QUADRANT:N', title='Classification')
        ]
    )
    
    # Combine all layers
    chart = (quadrant_bg + vline + hline + quadrant_labels + points).properties(
        height=height
    ).configure_axis(
        labelColor='#94a3b8',
        titleColor='#e2e8f0',
        gridColor='#334155',
        domainColor='#475569'
    ).configure_legend(
        labelColor='#e2e8f0',
        titleColor='#e2e8f0'
    ).configure_view(
        strokeWidth=0
    ).interactive()
    
    st.altair_chart(chart, use_container_width=True)


def execute_query(session, question):
    """Execute a query based on natural language question."""
    question_lower = question.lower()
    
    query_map = {
        "highest risk": """
            SELECT v.NAME, v.COUNTRY_CODE, rs.RISK_SCORE, rs.RISK_CATEGORY
            FROM RISK_SCORES rs
            JOIN VENDORS v ON rs.NODE_ID = v.VENDOR_ID
            WHERE rs.NODE_TYPE = 'SUPPLIER'
            ORDER BY rs.RISK_SCORE DESC
            LIMIT 10
        """,
        "bottleneck": """
            SELECT NODE_ID, DEPENDENT_COUNT, IMPACT_SCORE, DESCRIPTION
            FROM BOTTLENECKS
            ORDER BY IMPACT_SCORE DESC
        """,
        "average risk": """
            SELECT v.COUNTRY_CODE, r.REGION_NAME, 
                   COUNT(*) as SUPPLIER_COUNT,
                   ROUND(AVG(rs.RISK_SCORE), 3) as AVG_RISK
            FROM VENDORS v
            JOIN REGIONS r ON v.COUNTRY_CODE = r.REGION_CODE
            LEFT JOIN RISK_SCORES rs ON v.VENDOR_ID = rs.NODE_ID
            GROUP BY v.COUNTRY_CODE, r.REGION_NAME
            ORDER BY AVG_RISK DESC
        """,
        "material": """
            SELECT m.MATERIAL_ID, m.DESCRIPTION, m.MATERIAL_GROUP, 
                   m.CRITICALITY_SCORE, rs.RISK_SCORE
            FROM MATERIALS m
            LEFT JOIN RISK_SCORES rs ON m.MATERIAL_ID = rs.NODE_ID
            ORDER BY m.CRITICALITY_SCORE DESC
            LIMIT 10
        """,
        "external": """
            SELECT SOURCE_NODE_ID as EXTERNAL_SUPPLIER, 
                   COUNT(DISTINCT TARGET_NODE_ID) as DEPENDENT_COUNT,
                   AVG(PROBABILITY) as AVG_PROBABILITY
            FROM PREDICTED_LINKS
            WHERE SOURCE_NODE_TYPE = 'EXTERNAL_SUPPLIER'
            GROUP BY SOURCE_NODE_ID
            ORDER BY DEPENDENT_COUNT DESC
            LIMIT 10
        """,
        "prediction": """
            SELECT SOURCE_NODE_ID, TARGET_NODE_ID, PROBABILITY, EVIDENCE_STRENGTH
            FROM PREDICTED_LINKS
            WHERE PROBABILITY >= 0.5
            ORDER BY PROBABILITY DESC
            LIMIT 20
        """
    }
    
    for keyword, query in query_map.items():
        if keyword in question_lower:
            try:
                result = session.sql(query).to_pandas()
                return result, query
            except Exception as e:
                return None, str(e)
    
    return None, "Could not understand the question. Try asking about risk, bottlenecks, materials, or predictions."


SAMPLE_QUESTIONS = [
    "Which suppliers have the highest risk scores?",
    "What bottlenecks have been identified?",
    "What is the average risk by region?",
    "Show me the top materials by criticality",
    "Which external suppliers have the most dependents?",
    "What are the highest confidence predictions?"
]


def main():
    session = get_session()
    
    # Render sidebar immediately (before heavy data loading)
    render_sidebar()
    
    # Render STAR callout if demo mode is enabled
    render_star_callout("mitigation")
    
    # Load data
    high_risk = load_high_risk_suppliers(session)
    matrix_data = load_risk_matrix_data(session)
    actions = load_recommended_actions(session)
    
    # ============================================
    # HEADER
    # ============================================
    st.markdown("""
    <div class="page-header">Risk Mitigation</div>
    <div class="page-subheader">Prioritization matrix, action items, and analysis tools</div>
    """, unsafe_allow_html=True)
    
    # ============================================
    # RISK PRIORITY MATRIX
    # ============================================
    st.markdown('<div class="section-header">Priority Matrix</div>', unsafe_allow_html=True)
    st.markdown("""
    <p style="color: #94a3b8; margin-bottom: 1rem;">
        Suppliers plotted by impact score and risk probability.
    </p>
    """, unsafe_allow_html=True)
    
    render_risk_matrix(matrix_data, height=400)
    
    st.divider()
    
    # ============================================
    # RECOMMENDED ACTIONS
    # ============================================
    st.markdown('<div class="section-header">Recommended Actions</div>', unsafe_allow_html=True)
    
    # PARALLEL PREFETCH: Load all AI explanations upfront
    with st.spinner("Loading action guidance..."):
        all_explanations = prefetch_all_action_explanations(session, actions)
    
    col1, col2 = st.columns([2, 1])
    
    with col1:
        for idx, action in enumerate(actions):
            priority_class = action['priority']
            priority_label = action['priority'].upper()
            
            st.markdown(f"""
            <div class="action-card {priority_class}">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem;">
                    <span class="action-title">{action['title']}</span>
                    <span class="priority-badge priority-{priority_class}">{priority_label}</span>
                </div>
                <div class="action-description">{action['description']}</div>
            </div>
            """, unsafe_allow_html=True)
            
            # Use prefetched AI explanation
            ai_explanation = all_explanations.get(idx)
            
            if ai_explanation:
                st.markdown(f"""
                <div style="background: rgba(59, 130, 246, 0.08); border-left: 3px solid #3b82f6; padding: 0.75rem 1rem; margin-top: 0.5rem; border-radius: 0 8px 8px 0;">
                    <div style="color: #60a5fa; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.25rem;">AI Guidance</div>
                    <p style="color: #e2e8f0; line-height: 1.6; white-space: pre-wrap; margin: 0; font-size: 0.9rem;">{ai_explanation}</p>
                </div>
                """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("#### High Risk Suppliers")
        if high_risk is not None and not high_risk.empty:
            for _, row in high_risk.head(8).iterrows():
                risk = row['RISK_SCORE']
                risk_class = 'critical' if risk >= 0.75 else 'high' if risk >= 0.5 else 'medium' if risk >= 0.25 else 'low'
                
                st.markdown(f"""
                <div class="risk-row">
                    <span class="risk-name">{row['VENDOR_NAME'] or row['NODE_ID']}</span>
                    <span class="risk-score risk-{risk_class}">{risk:.0%}</span>
                </div>
                """, unsafe_allow_html=True)
        else:
            st.info("No risk data available.")
    
    st.divider()
    
    # ============================================
    # AI ASSISTANT
    # ============================================
    st.markdown('<div class="section-header">AI Supply Chain Assistant</div>', unsafe_allow_html=True)
    st.markdown("""
    <p style="color: #94a3b8; margin-bottom: 1rem;">
        Ask questions about your supply chain risk data using natural language.
    </p>
    """, unsafe_allow_html=True)
    
    col1, col2 = st.columns([2, 1])
    
    with col1:
        # Chat interface
        if "messages" not in st.session_state:
            st.session_state.messages = []
        
        # Display chat history
        for message in st.session_state.messages:
            with st.chat_message(message["role"]):
                st.markdown(message["content"])
                if "data" in message and message["data"] is not None:
                    st.dataframe(message["data"], use_container_width=True, height=200)
        
        # Chat input
        if prompt := st.chat_input("Ask about your supply chain..."):
            st.session_state.messages.append({"role": "user", "content": prompt})
            
            with st.chat_message("user"):
                st.markdown(prompt)
            
            with st.chat_message("assistant"):
                with st.spinner("Analyzing..."):
                    result, info = execute_query(session, prompt)
                    
                    if result is not None and not result.empty:
                        st.markdown("Here's what I found:")
                        st.dataframe(result, use_container_width=True, height=200)
                        st.session_state.messages.append({
                            "role": "assistant",
                            "content": "Here's what I found:",
                            "data": result
                        })
                    elif result is not None:
                        st.markdown("The query returned no results.")
                        st.session_state.messages.append({
                            "role": "assistant",
                            "content": "The query returned no results."
                        })
                    else:
                        st.markdown(f"I couldn't process that. {info}")
                        st.session_state.messages.append({
                            "role": "assistant",
                            "content": f"I couldn't process that. {info}"
                        })
    
    with col2:
        st.markdown("**Sample Questions:**")
        
        for q in SAMPLE_QUESTIONS:
            if st.button(q, key=f"q_{q[:20]}", use_container_width=True):
                st.session_state.messages.append({"role": "user", "content": q})
                result, info = execute_query(session, q)
                if result is not None:
                    st.session_state.messages.append({
                        "role": "assistant",
                        "content": "Here's what I found:",
                        "data": result
                    })
                else:
                    st.session_state.messages.append({
                        "role": "assistant",
                        "content": f"Error: {info}"
                    })
                st.rerun()
        
        st.markdown("---")
        if st.button("Clear Chat"):
            st.session_state.messages = []
            st.rerun()
    
    st.divider()
    
    # ============================================
    # EXPORT OPTIONS
    # ============================================
    st.markdown('<div class="section-header">Export & Report</div>', unsafe_allow_html=True)
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        if high_risk is not None:
            csv = high_risk.to_csv(index=False)
            st.download_button(
                "Download Risk Report (CSV)",
                csv,
                "risk_report.csv",
                "text/csv",
                use_container_width=True
            )
    
    with col2:
        try:
            bottlenecks = session.sql("SELECT * FROM BOTTLENECKS ORDER BY IMPACT_SCORE DESC").to_pandas()
            if not bottlenecks.empty:
                csv = bottlenecks.to_csv(index=False)
                st.download_button(
                    "Download Bottleneck Report",
                    csv,
                    "bottleneck_report.csv",
                    "text/csv",
                    use_container_width=True
                )
        except:
            st.button("Download Bottleneck Report", disabled=True, use_container_width=True)
    
    with col3:
        try:
            links = session.sql("SELECT * FROM PREDICTED_LINKS WHERE PROBABILITY >= 0.5 ORDER BY PROBABILITY DESC").to_pandas()
            if not links.empty:
                csv = links.to_csv(index=False)
                st.download_button(
                    "Download Predictions",
                    csv,
                    "predicted_links.csv",
                    "text/csv",
                    use_container_width=True
                )
        except:
            st.button("Download Predictions", disabled=True, use_container_width=True)


if __name__ == "__main__":
    main()

