"""
🏛️ Enterprise Clearing & Settlement
Enterprise Dynamic Tables Dashboard

Main Streamlit in Snowflake Application
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from snowflake.snowpark.context import get_active_session

# Page configuration
st.set_page_config(
    page_title="Enterprise Clearing & Settlement Dashboard",
    page_icon="🏛️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for styling
st.markdown("""
<style>
    .main-header {
        /* Neutral, professional slate gray gradient */
        background: linear-gradient(90deg, #4b6587 0%, #3f536e 100%);
        color: white;
        padding: 1.5rem;
        border-radius: 10px;
        margin-bottom: 2rem;
        text-align: center;
    }
    .metric-card {
        background: white;
        padding: 1rem;
        border-radius: 10px;
        /* Neutral border accent color */
        border-left: 5px solid #4b6587;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        margin: 0.5rem 0;
    }
    /* Standard semantic status colors */
    .status-success { border-left-color: #28a745; }
    .status-warning { border-left-color: #ffc107; }
    .status-danger { border-left-color: #dc3545; }
    
    .pipeline-stage {
        background: #f8f9fa;
        border: 2px solid #dee2e6;
        border-radius: 10px;
        padding: 1rem;
        margin: 0.5rem;
        text-align: center;
    }
</style>
""", unsafe_allow_html=True)

def check_database_connection(session):
    """Check if we can connect to SF_SOLUTIONS database and show status"""
    try:
        # Check if tables exist using fully qualified names
        tables_check = session.sql("""
            SELECT table_schema, table_name, row_count 
            FROM SF_SOLUTIONS.INFORMATION_SCHEMA.TABLES 
            WHERE table_schema IN ('CLEARING_SETTLEMENT_RAW', 'CLEARING_SETTLEMENT_DQ', 'CLEARING_SETTLEMENT_NORMALIZED', 'CLEARING_SETTLEMENT_CONSUMPTION')
            ORDER BY table_schema, table_name
        """).collect()
        
        if tables_check:
            st.success(f"✅ Connected to SF_SOLUTIONS database - Found {len(tables_check)} tables in pipeline")
            return True, pd.DataFrame(tables_check)
        else:
            st.warning("⚠️ SF_SOLUTIONS database exists but no pipeline tables found")
            return False, pd.DataFrame()
            
    except Exception as e:
        st.error(f"❌ Cannot connect to SF_SOLUTIONS database: {str(e)}")
        st.info("💡 Make sure you've run the Clearing Data Pipeline notebook and setup script to create the database and Dynamic Tables")
        return False, pd.DataFrame()

@st.cache_data(ttl=60)  # Cache for 1 minute
def get_pipeline_summary(_session):
    """Get overall pipeline summary metrics from live data"""
    try:
        # Get total transactions from RAW layer using fully qualified name
        total_result = _session.sql("SELECT COUNT(*) as total_transactions FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.SETTLEMENT_TRANSACTIONS").collect()
        total_transactions = total_result[0]['TOTAL_TRANSACTIONS'] if total_result else 0
        
        # Get quality metrics from DATA_QUALITY layer
        quality_result = _session.sql("""
            SELECT AVG(overall_quality_score) as avg_quality_score
            FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_DQ.SETTLEMENT_QUALITY_METRICS
            WHERE quality_date >= CURRENT_DATE() - 7
        """).collect()
        quality_score = quality_result[0]['AVG_QUALITY_SCORE'] if quality_result and quality_result[0]['AVG_QUALITY_SCORE'] else 99.2
        
        # Get settlement success rate from CONSUMPTION layer
        success_result = _session.sql("""
            SELECT AVG(settlement_success_rate) as avg_success_rate
            FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION.ENTERPRISE_DAILY_DASHBOARD
            WHERE settlement_date >= CURRENT_DATE() - 7
        """).collect()
        success_rate = success_result[0]['AVG_SUCCESS_RATE'] if success_result and success_result[0]['AVG_SUCCESS_RATE'] else 99.8
        
        # Get risk exposure from CONSUMPTION layer
        risk_result = _session.sql("""
            SELECT SUM(risk_exposure_billions) as total_risk_exposure
            FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION.ENTERPRISE_PARTICIPANT_RISK_MONITOR
        """).collect()
        risk_exposure = risk_result[0]['TOTAL_RISK_EXPOSURE'] if risk_result and risk_result[0]['TOTAL_RISK_EXPOSURE'] else 2.4
        
        return {
            'total_transactions': total_transactions,
            'quality_score': quality_score,
            'success_rate': success_rate,
            'risk_exposure': risk_exposure,
            'daily_increase': 125000,
            'is_live': True
        }
        
    except Exception as e:
        st.warning(f"Using demo data - unable to connect to live data: {str(e)}")
        return {
            'total_transactions': 5129375,
            'quality_score': 99.2,
            'success_rate': 99.8,
            'risk_exposure': 2.4,
            'daily_increase': 125000,
            'is_live': False
        }

def main():
    """Main application function"""
    
    # Get Snowflake session
    session = get_active_session()
    
    # Header
    st.markdown("""
    <div class="main-header">
        <h1>🏛️ Enterprise Clearing & Settlement Platform</h1>
        <h3>Enterprise Dynamic Tables Dashboard</h3>
        <p>Real-time Settlement & Clearing Data Platform | Processing 5.1M+ Transactions</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Check database connection first
    is_connected, tables_df = check_database_connection(session)
    
    if not is_connected:
        st.markdown("### 🚀 Getting Started")
        st.markdown("""
        To see live data from your Enterprise Clearing & Settlement pipeline:

        1. **Run the Enterprise Clearing & Settlement Notebook** first to create the database and Dynamic Tables
        2. **Deploy this Streamlit app** in the `SF_SOLUTIONS` database
        3. **Refresh this page** to see live data
        
        For now, you can explore the demo data and interface.
        """)
    
    # Sidebar navigation
    with st.sidebar:
        st.markdown("### 📊 Enterprise Clearing & Settlement Dashboard")
        st.markdown("Navigate through the enterprise data pipeline")
        
        # Connection status
        if is_connected:
            st.success("🟢 Live Data Connected")
        else:
            st.warning("🟡 Demo Mode")
        
        st.markdown("---")
        st.markdown("### 📈 Quick Stats")
        
        # Quick stats in sidebar
        try:
            summary = get_pipeline_summary(session)
            st.metric("Total Transactions", f"{summary.get('total_transactions', 0):,}")
            st.metric("Quality Score", f"{summary.get('quality_score', 0):.1f}%")
            st.metric("Success Rate", f"{summary.get('success_rate', 0):.1f}%")
            
            if summary.get('is_live'):
                st.success("📊 Live metrics")
            else:
                st.info("📊 Demo metrics")
                
        except Exception as e:
            st.warning("Demo mode - connect to see live data")
        
        st.markdown("---")
        st.markdown("### 🔗 Navigation")
        st.markdown("Use the pages in the sidebar to explore:")
        st.markdown("- **Data Pipeline**: Explore all layers")
        st.markdown("- **Data Quality**: Quality monitoring")
        st.markdown("- **Customer Products**: Data distribution")

    # Main content area
    col1, col2 = st.columns([2, 1])
    
    with col1:
        st.header("📊 Enterprise Pipeline Overview")
        
        # Show database tables if connected
        if is_connected and not tables_df.empty:
            st.markdown("### 🗃️ Database Tables Status")
            st.dataframe(tables_df, use_container_width=True)
        
        # Pipeline Architecture
        st.markdown("### 🏗️ Dynamic Tables Architecture")
        
        pipeline_cols = st.columns(4)
        
        with pipeline_cols[0]:
            st.markdown("""
            <div class="pipeline-stage">
                <h4>🥉 Raw Layer</h4>
                <p><strong>Static Tables</strong></p>
                <p>5.1M+ Transactions<br/>
                2,847 Participants<br/>
                1.9M Fee Records</p>
            </div>
            """, unsafe_allow_html=True)
        
        with pipeline_cols[1]:
            st.markdown("""
            <div class="pipeline-stage">
                <h4>🔍 Quality Layer</h4>
                <p><strong>Dynamic Tables</strong></p>
                <p>Real-time Validation<br/>
                Auto-remediation<br/>
                Quality Scoring</p>
            </div>
            """, unsafe_allow_html=True)
        
        with pipeline_cols[2]:
            st.markdown("""
            <div class="pipeline-stage">
                <h4>🥈 Normalized</h4>
                <p><strong>Multi-step Pipeline</strong></p>
                <p>Business Rules<br/>
                Risk Calculations<br/>
                Master Data Joins</p>
            </div>
            """, unsafe_allow_html=True)
        
        with pipeline_cols[3]:
            st.markdown("""
            <div class="pipeline-stage">
                <h4>🥇 Consumption</h4>
                <p><strong>Real-time Analytics</strong></p>
                <p>Risk Monitoring<br/>
                Performance KPIs<br/>
                Customer Products</p>
            </div>
            """, unsafe_allow_html=True)
        
        # Real-time metrics
        st.markdown("### 📈 Real-time Enterprise Metrics")
        
        metrics_col1, metrics_col2, metrics_col3, metrics_col4 = st.columns(4)
        
        try:
            summary = get_pipeline_summary(session)
            
            with metrics_col1:
                st.metric(
                    "Transactions Processed", 
                    f"{summary.get('total_transactions', 5129375):,}",
                    delta=f"+{summary.get('daily_increase', 125000):,} today"
                )
            
            with metrics_col2:
                quality_score = summary.get('quality_score', 99.2)
                st.metric(
                    "Data Quality Score", 
                    f"{quality_score:.1f}%",
                    delta=f"{quality_score - 99.0:+.1f}%"
                )
            
            with metrics_col3:
                success_rate = summary.get('success_rate', 99.8)
                st.metric(
                    "Settlement Success", 
                    f"{success_rate:.1f}%",
                    delta=f"{success_rate - 99.5:+.1f}%"
                )
            
            with metrics_col4:
                risk_exposure = summary.get('risk_exposure', 2.4)
                st.metric(
                    "Risk Exposure (B CAD)", 
                    f"${risk_exposure:.1f}B",
                    delta=f"{risk_exposure - 2.5:+.1f}B"
                )
        
        except Exception as e:
            # Fallback static metrics for demo
            with metrics_col1:
                st.metric("Transactions Processed", "5,129,375", "+125,000 today")
            with metrics_col2:
                st.metric("Data Quality Score", "99.2%", "+0.2%")
            with metrics_col3:
                st.metric("Settlement Success", "99.8%", "+0.3%")
            with metrics_col4:
                st.metric("Risk Exposure (B CAD)", "$2.4B", "-0.1B")

    with col2:
        st.header("🚨 System Status")
        
        # System health indicators
        st.markdown("### ⚡ Dynamic Table Health")
        
        health_data = [
            ("Settlement Quality Metrics", "🟢", "1 min refresh", "Healthy"),
            ("Cleansed Transactions", "🟢", "3 min refresh", "Healthy"),
            ("Settlement Validation", "🟢", "2 min refresh", "Healthy"),
            ("Reference Enrichment", "🟢", "3 min refresh", "Healthy"),
            ("Business Rules Engine", "🟢", "4 min refresh", "Healthy"),
            ("Risk Monitor", "🟢", "1 min refresh", "Healthy"),
            ("Daily Dashboard", "🟡", "5 min refresh", "Refreshing"),
        ]
        
        for name, status, refresh, state in health_data:
            st.markdown(f"""
            <div class="metric-card {'status-success' if status == '🟢' else 'status-warning'}">
                <strong>{status} {name}</strong><br/>
                <small>{refresh} • {state}</small>
            </div>
            """, unsafe_allow_html=True)
        
        # Recent alerts
        st.markdown("### 🔔 Recent Alerts")
        
        alerts = [
            ("🟡", "Quality Alert", "Symbol completeness at 99.7%", "2 min ago"),
            ("🟢", "Performance", "T+2 compliance: 98.5%", "5 min ago"),
            ("🔵", "Info", "New participant onboarded", "1 hour ago"),
        ]
        
        for icon, type_, message, time in alerts:
            st.markdown(f"""
            <div class="metric-card">
                {icon} <strong>{type_}</strong><br/>
                {message}<br/>
                <small>{time}</small>
            </div>
            """, unsafe_allow_html=True)

    # Footer
    st.markdown("---")
    st.markdown("""
    <div style="text-align: center; color: #666; padding: 1rem;">
        <p>Enterprise Clearing & Settlement Dashboard | Powered by Snowflake Dynamic Tables </p>
    </div>
    """, unsafe_allow_html=True)

if __name__ == "__main__":
    main() 