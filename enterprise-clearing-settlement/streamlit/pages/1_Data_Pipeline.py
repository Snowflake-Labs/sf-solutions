"""
📊 Enterprise Clearing & Settlement Data Pipeline Explorer

Explore data across all pipeline layers using Snowflake Dynamic Tables
"""

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

# Page configuration
st.set_page_config(
    page_title="Data Pipeline Explorer",
    page_icon="📊",
    layout="wide"
)

@st.cache_data(ttl=300)  # Cache for 5 minutes
def get_table_summary(_session, schema, table):
    """Get row count and sample data for a table"""
    try:
        # Get row count using fully qualified name
        count_result = _session.sql(f"SELECT COUNT(*) as row_count FROM SF_SOLUTIONS.{schema}.{table}").collect()
        row_count = count_result[0]['ROW_COUNT'] if count_result else 0
        
        return {
            'row_count': row_count,
            'status': 'Active' if row_count > 0 else 'Empty'
        }
    except Exception as e:
        return {
            'row_count': 0,
            'status': f'Error: {str(e)}'
        }

@st.cache_data(ttl=600)  # Cache for 10 minutes
def get_sample_data(_session, schema, table, limit=100):
    """Get sample data from a table"""
    try:
        query = f"SELECT * FROM SF_SOLUTIONS.{schema}.{table} ORDER BY RANDOM() LIMIT {limit}"
        result = _session.sql(query).collect()
        return pd.DataFrame(result) if result else pd.DataFrame()
    except Exception as e:
        st.error(f"Unable to load sample data from {schema}.{table}: {str(e)}")
        return pd.DataFrame()

def show_data_lineage(session):
    """Show data lineage and pipeline flow"""
    
    st.header("🏗️ Enterprise Data Pipeline Architecture")
    
    col1, col2 = st.columns([2, 1])
    
    with col1:
        st.markdown("### 📊 Data Flow Visualization")
        
        # Visual pipeline flow diagram
        st.markdown("""
        ```
        🥉 RAW LAYER (Bronze) - Static Tables
        ├── Settlement Transactions (5.1M+ records)
        ├── Securities Master Data (25 securities)
        ├── Participants (2,847 institutions)
        ├── Transaction Fees (1.9M+ records)
        └── Market Data (15K+ records)
                    ↓
        🔍 DATA QUALITY LAYER - Dynamic Tables
        ├── Quality Metrics (1-min refresh)
        └── Cleansed Transactions (3-min refresh)
                    ↓
        🥈 NORMALIZED LAYER (Silver) - Multi-Step Pipeline
        ├── Settlement Validation (2-min refresh)
        ├── Reference Enrichment (3-min refresh)
        └── Business Rules Engine (4-min refresh)
                    ↓
        🥇 CONSUMPTION LAYER (Gold) - Real-Time Analytics
        ├── Participant Risk Monitor (1-min refresh)
        └── Daily Dashboard (5-min refresh)
        ```
        """)
        
        # Pipeline layers with descriptions
        layers_info = [
            {
                'layer': 'Raw (Bronze)',
                'tables': ['SETTLEMENT_TRANSACTIONS', 'SECURITIES_MASTER', 'PARTICIPANTS', 'TRANSACTION_FEES', 'MARKET_DATA'],
                'type': 'Static Tables',
                'purpose': 'Source data ingestion with quality issues',
                'schema': 'CLEARING_SETTLEMENT_RAW'
            },
            {
                'layer': 'Data Quality',
                'tables': ['SETTLEMENT_QUALITY_METRICS', 'SETTLEMENT_TRANSACTIONS_CLEANSED'],
                'type': 'Dynamic Tables',
                'purpose': 'Real-time quality monitoring and cleansing',
                'schema': 'CLEARING_SETTLEMENT_DQ'
            },
            {
                'layer': 'Normalized (Silver)',
                'tables': ['SETTLEMENT_VALIDATION', 'REFERENCE_ENRICHMENT', 'BUSINESS_RULES_ENGINE'],
                'type': 'Dynamic Tables',
                'purpose': 'Business rules and enrichment pipeline',
                'schema': 'CLEARING_SETTLEMENT_NORMALIZED'
            },
            {
                'layer': 'Consumption (Gold)',
                'tables': ['ENTERPRISE_PARTICIPANT_RISK_MONITOR', 'ENTERPRISE_DAILY_DASHBOARD'],
                'type': 'Dynamic Tables',
                'purpose': 'Real-time analytics and reporting',
                'schema': 'CLEARING_SETTLEMENT_CONSUMPTION'
            }
        ]
        
        # Create simple data volume display
        st.markdown("### 📈 Data Volume by Pipeline Layer")
        
        layer_data = []
        for layer_info in layers_info:
            total_rows = 0
            for table in layer_info['tables']:
                try:
                    table_info = get_table_summary(session, layer_info['schema'], table)
                    total_rows += table_info['row_count']
                except:
                    pass
            layer_data.append({
                'Layer': layer_info['layer'],
                'Tables': len(layer_info['tables']),
                'Total Records': f"{total_rows:,}" if total_rows > 0 else "Loading..."
            })
        
        layer_df = pd.DataFrame(layer_data)
        st.dataframe(layer_df, use_container_width=True)
        
    with col2:
        st.markdown("### 📋 Layer Details")
        
        for layer_info in layers_info:
            with st.expander(f"{layer_info['layer']} ({len(layer_info['tables'])} tables)"):
                st.markdown(f"**Type**: {layer_info['type']}")
                st.markdown(f"**Purpose**: {layer_info['purpose']}")
                st.markdown(f"**Schema**: {layer_info['schema']}")
                
                st.markdown("**Tables**:")
                for table in layer_info['tables']:
                    try:
                        table_info = get_table_summary(session, layer_info['schema'], table)
                        st.markdown(f"- {table}: {table_info['row_count']:,} records")
                    except:
                        st.markdown(f"- {table}: N/A")

def show_raw_data_layer(session):
    """Display raw data layer details"""
    
    st.header("🥉 Raw Data Layer (Bronze)")
    st.markdown("Source data with enterprise-scale volumes and realistic quality challenges")
    
    # Raw tables with descriptions
    raw_tables = {
        'SETTLEMENT_TRANSACTIONS': 'Settlement transactions with quality indicators (5M+ records)',
        'SECURITIES_MASTER': 'Exchange securities master data',
        'PARTICIPANTS': 'Clearing participant information (2,847 institutions)',
        'TRANSACTION_FEES': 'Transaction fees and charges (1.9M+ records)',
        'MARKET_DATA': 'Daily market data for securities'
    }
    
    # Display table summaries
    cols = st.columns(2)
    
    for i, (table_name, description) in enumerate(raw_tables.items()):
        with cols[i % 2]:
            try:
                table_info = get_table_summary(session, 'CLEARING_SETTLEMENT_RAW', table_name)
                st.markdown(f"""
                <div style="border: 1px solid #ddd; padding: 1rem; border-radius: 5px; margin: 0.5rem 0;">
                    <h4>{table_name}</h4>
                    <p>{description}</p>
                    <p><strong>Records:</strong> {table_info['row_count']:,}</p>
                    <p><strong>Status:</strong> {table_info['status']}</p>
                </div>
                """, unsafe_allow_html=True)
            except Exception as e:
                st.error(f"Error loading {table_name}: {str(e)}")
    
    # Table selector for sample data
    st.markdown("### 🔍 Explore Sample Data")
    
    selected_table = st.selectbox(
        "Select table to explore:",
        list(raw_tables.keys())
    )
    
    if selected_table:
        show_sample_data_viewer(session, 'CLEARING_SETTLEMENT_RAW', selected_table)

def show_quality_layer(session):
    """Display data quality layer details"""
    
    st.header("🔍 Data Quality Layer")
    st.markdown("Real-time quality monitoring and automated data cleansing with Dynamic Tables")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("### 📊 Quality Metrics Table")
        st.markdown("""
        **SETTLEMENT_QUALITY_METRICS** (Dynamic Table)
        - **Target Lag**: 1 minute
        - **Purpose**: Real-time quality monitoring across 5M+ records
        - **Metrics**: Completeness, validity, overall quality score
        - **Refresh**: Automatic based on source data changes
        """)
        
        # Show sample quality data
        try:
            quality_data = get_sample_data(session, 'CLEARING_SETTLEMENT_DQ', 'SETTLEMENT_QUALITY_METRICS', 5)
            if not quality_data.empty:
                st.dataframe(quality_data, use_container_width=True)
            else:
                st.info("Quality metrics will be available once the Dynamic Tables are refreshing")
        except Exception as e:
            st.warning(f"Unable to load quality metrics: {str(e)}")
    
    with col2:
        st.markdown("### 🧹 Cleansed Transactions Table")
        st.markdown("""
        **SETTLEMENT_TRANSACTIONS_CLEANSED** (Dynamic Table)
        - **Target Lag**: 3 minutes
        - **Purpose**: Automated data cleansing and standardization
        - **Features**: Error correction, quality scoring, data flags
        - **Scale**: Processing 5M+ transactions with real-time validation
        """)
        
        # Show sample cleansed data
        try:
            cleansed_data = get_sample_data(session, 'CLEARING_SETTLEMENT_DQ', 'SETTLEMENT_TRANSACTIONS_CLEANSED', 5)
            if not cleansed_data.empty:
                # Show key columns for readability
                key_columns = ['TRANSACTION_ID', 'SECURITY_SYMBOL_CLEANSED', 'PARTICIPANT_ID_CLEANSED', 
                              'RECORD_QUALITY_RATING', 'QUALITY_SCORE']
                available_cols = [col for col in key_columns if col in cleansed_data.columns]
                if available_cols:
                    st.dataframe(cleansed_data[available_cols], use_container_width=True)
                else:
                    st.dataframe(cleansed_data.head(), use_container_width=True)
            else:
                st.info("Cleansed data will be available once the Dynamic Tables are processing")
        except Exception as e:
            st.warning(f"Unable to load cleansed data: {str(e)}")

def show_normalized_layer(session):
    """Display normalized layer details"""
    
    st.header("🥈 Normalized Layer (Silver)")
    st.markdown("Multi-step dynamic pipeline with business rules and enrichment across enterprise data")
    
    # Pipeline steps
    steps = [
        {
            'name': 'SETTLEMENT_VALIDATION',
            'purpose': 'Institutional business rules validation',
            'lag': '2 minutes',
            'description': 'Validates T+2 settlement cycles, amounts, and institutional business logic'
        },
        {
            'name': 'REFERENCE_ENRICHMENT', 
            'purpose': 'Master data enrichment',
            'lag': '3 minutes',
            'description': 'Complex joins with securities and participant master data'
        },
        {
            'name': 'BUSINESS_RULES_ENGINE',
            'purpose': 'Advanced risk calculations',
            'lag': '4 minutes', 
            'description': 'Multi-factor risk scoring and regulatory classification'
        }
    ]
    
    for i, step in enumerate(steps):
        with st.expander(f"Step {i+1}: {step['name']} (Dynamic - {step['lag']} refresh)"):
            st.markdown(f"**Purpose**: {step['purpose']}")
            st.markdown(f"**Description**: {step['description']}")
            st.markdown(f"**Type**: Dynamic Table with automatic refresh")
            
            # Show sample data
            try:
                sample_data = get_sample_data(session, 'CLEARING_SETTLEMENT_NORMALIZED', step['name'], 3)
                if not sample_data.empty:
                    st.dataframe(sample_data, use_container_width=True)
                else:
                    st.info(f"Data will be available once {step['name']} Dynamic Table is processing")
            except Exception as e:
                st.warning(f"Unable to load {step['name']}: {str(e)}")

def show_consumption_layer(session):
    """Display consumption layer details"""
    
    st.header("🥇 Consumption Layer (Gold)")
    st.markdown("Real-time analytics and business intelligence with sub-minute refresh rates")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("### 📊 Enterprise Participant Risk Monitor")
        st.markdown("""
        **Real-time risk monitoring** (1-minute refresh)
        - Live participant exposure tracking across all transactions
        - Risk tier analysis and alert generation
        - Enterprise-scale processing for 2,847+ participants
        - Automated threshold-based alerting
        """)
        
        try:
            risk_data = get_sample_data(session, 'CLEARING_SETTLEMENT_CONSUMPTION', 'ENTERPRISE_PARTICIPANT_RISK_MONITOR', 5)
            if not risk_data.empty:
                # Show key columns for business users
                key_columns = ['PARTICIPANT_NAME', 'TOTAL_TRANSACTIONS', 'SETTLEMENT_VALUE_BILLIONS', 
                              'AVG_RISK_SCORE', 'ENTERPRISE_ALERT_STATUS']
                available_cols = [col for col in key_columns if col in risk_data.columns]
                if available_cols:
                    st.dataframe(risk_data[available_cols], use_container_width=True)
                else:
                    st.dataframe(risk_data.head(), use_container_width=True)
            else:
                st.info("Risk monitor data will be available once Dynamic Tables are running")
        except Exception as e:
            st.warning(f"Unable to load risk data: {str(e)}")
    
    with col2:
        st.markdown("### 📈 Enterprise Daily Dashboard")
        st.markdown("""
        **Daily performance metrics** (5-minute refresh)
        - Settlement success rates and T+2 compliance tracking
        - Operational efficiency metrics and performance ratings
        - Volume trends and market analytics
        - Regulatory compliance monitoring
        """)
        
        try:
            dashboard_data = get_sample_data(session, 'CLEARING_SETTLEMENT_CONSUMPTION', 'ENTERPRISE_DAILY_DASHBOARD', 5)
            if not dashboard_data.empty:
                # Show key performance columns
                key_columns = ['SETTLEMENT_DATE', 'TOTAL_TRANSACTIONS', 'SETTLEMENT_SUCCESS_RATE', 
                              'T2_COMPLIANCE_RATE', 'ENTERPRISE_PERFORMANCE_RATING']
                available_cols = [col for col in key_columns if col in dashboard_data.columns]
                if available_cols:
                    st.dataframe(dashboard_data[available_cols], use_container_width=True)
                else:
                    st.dataframe(dashboard_data.head(), use_container_width=True)
            else:
                st.info("Dashboard data will be available once Dynamic Tables are running")
        except Exception as e:
            st.warning(f"Unable to load dashboard data: {str(e)}")

def show_sample_data_viewer(session, schema, table_name, limit=100):
    """Display sample data from a table with controls"""
    
    st.markdown(f"### Sample Data: {schema}.{table_name}")
    
    # Controls
    col1, col2, col3 = st.columns([2, 1, 1])
    
    with col1:
        limit = st.number_input("Number of records", min_value=10, max_value=1000, value=100)
    
    with col2:
        if st.button("Refresh Data"):
            st.cache_data.clear()
            st.rerun()
    
    with col3:
        export_format = st.selectbox("Export Format", ["CSV", "JSON"])
    
    # Get and display data
    try:
        sample_data = get_sample_data(session, schema, table_name, limit)
        
        if not sample_data.empty:
            st.dataframe(sample_data, use_container_width=True)
            
            # Export functionality
            if export_format == "CSV":
                csv = sample_data.to_csv(index=False)
                st.download_button(
                    label="Download CSV",
                    data=csv,
                    file_name=f"{table_name}_sample.csv",
                    mime="text/csv"
                )
            elif export_format == "JSON":
                json_str = sample_data.to_json(orient="records", indent=2)
                st.download_button(
                    label="Download JSON",
                    data=json_str,
                    file_name=f"{table_name}_sample.json",
                    mime="application/json"
                )
            
            # Data info
            st.markdown(f"**Showing {len(sample_data)} records** | **Columns**: {len(sample_data.columns)}")
            
        else:
            st.info(f"No data available in {schema}.{table_name} or table is still loading")
            
    except Exception as e:
        st.error(f"Unable to load sample data: {str(e)}")

def main():
    """Main function for Data Pipeline Explorer"""

    st.title("📊 Enterprise Clearing & Settlement Data Pipeline Explorer")
    st.markdown("Navigate through the enterprise data pipeline from raw data to analytics-ready consumption layers")
    
    # Get Snowflake session
    session = get_active_session()
    
    # Sidebar - Layer Selection
    with st.sidebar:
        st.header("🔍 Pipeline Navigation")
        
        selected_layer = st.selectbox(
            "Select Pipeline Layer",
            ["Overview", "Raw Data (Bronze)", "Data Quality", "Normalized (Silver)", "Consumption (Gold)"],
            index=0
        )
        
        st.markdown("---")
        st.markdown("### 📈 Pipeline Stats")
        
        # Quick pipeline stats
        st.metric("Pipeline Layers", "4")
        st.metric("Dynamic Tables", "7")
        st.metric("Static Tables", "5")
        
        # Connection status
        st.success("🟢 Connected to SF_SOLUTIONS")

    # Main content based on selected layer
    if selected_layer == "Overview":
        show_data_lineage(session)
    elif selected_layer == "Raw Data (Bronze)":
        show_raw_data_layer(session)
    elif selected_layer == "Data Quality":
        show_quality_layer(session)
    elif selected_layer == "Normalized (Silver)":
        show_normalized_layer(session)
    elif selected_layer == "Consumption (Gold)":
        show_consumption_layer(session)

if __name__ == "__main__":
    main() 