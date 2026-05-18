"""
🎯 Enterprise Clearing & Settlement Customer Data Products

Data distribution and customer portal for clearing participants and stakeholders
"""

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

# Page configuration
st.set_page_config(
    page_title="Customer Data Products",
    page_icon="🎯",
    layout="wide"
)

# --- Generic Placeholder Data ---
GENERIC_PARTICIPANTS = [
    'Participant A (Major Bank)', 'Participant B (Brokerage)', 'Participant C (Institutional)',
    'Participant D (Custodian)', 'Participant E (Regional Bank)', 'Participant F (Investment Firm)',
    'Participant G (Dealer)', 'Participant H (Clearing Member)', 'Participant I (Insurance)',
    'Participant J (Fund Manager)',
    "Regulator Alpha",
    "Industry Organization Beta",
    "Central Bank Gamma"
]
# --- End Generic Placeholder Data ---

@st.cache_data
def get_customer_data_products():
    """Get available customer data products"""
    return [
        {
            'name': 'Participant Settlement Reports',
            'description': 'Daily settlement summaries for clearing participants',
            'access_level': 'Participant-specific',
            'update_frequency': 'Daily',
            'format': ['CSV', 'JSON', 'API', 'Secure Share'],
            'price': 'Included',
            'records': '2,847 participants'
        },
        {
            'name': 'Market Data Feeds',
            'description': 'Real-time and historical Exchange market data',
            'access_level': 'Public/Subscription',
            'update_frequency': 'Real-time',
            'format': ['API', 'WebSocket', 'CSV', 'Secure Share'],
            'price': 'Subscription',
            'records': '15K+ daily records'
        },
        {
            'name': 'Risk Analytics Package',
            'description': 'Risk metrics and exposure analytics',
            'access_level': 'Risk managers',
            'update_frequency': 'Hourly',
            'format': ['Dashboard', 'API', 'PDF', 'Secure Share'],
            'price': 'Premium',
            'records': '5M+ transactions analyzed'
        },
        {
            'name': 'Regulatory Compliance Reports',
            'description': 'T+2 compliance and regulatory metrics',
            'access_level': 'Compliance teams',
            'update_frequency': 'Daily',
            'format': ['PDF', 'Excel', 'API', 'Secure Share'],
            'price': 'Enterprise',
            'records': 'Full compliance suite'
        },
        {
            'name': 'Settlement Performance Analytics',
            'description': 'Operational metrics and performance tracking',
            'access_level': 'Operations teams',
            'update_frequency': '5 minutes',
            'format': ['Dashboard', 'API', 'Excel', 'Secure Share'],
            'price': 'Standard',
            'records': 'Real-time KPIs'
        }
    ]

@st.cache_data(ttl=300)  # Cache for 5 minutes
def get_sample_participant_data(_session):
    """Get sample participant data for demo"""
    try:
        query = """
        SELECT 
            participant_name,
            total_transactions,
            settlement_value_billions,
            settlement_success_rate,
            t2_compliance_rate,
            enterprise_alert_status
        FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION.ENTERPRISE_PARTICIPANT_RISK_MONITOR
        ORDER BY total_transactions DESC
        LIMIT 10
        """
        
        result = _session.sql(query).collect()
        return pd.DataFrame(result) if result else pd.DataFrame()
    except Exception as e:
        st.warning(f"Using demo participant data: {str(e)}")
        # Return demo data for showcase - REAL NAMES REMOVED
        return pd.DataFrame({
            'PARTICIPANT_NAME': GENERIC_PARTICIPANTS[:10], # Use first 10 generic names
            'TOTAL_TRANSACTIONS': [25847, 23456, 21123, 19876, 18543, 16789, 14567, 13245, 12876, 11234],
            'SETTLEMENT_VALUE_BILLIONS': [4.2, 3.8, 3.4, 3.1, 2.9, 2.6, 2.3, 2.1, 1.9, 1.7],
            'SETTLEMENT_SUCCESS_RATE': [99.8, 99.7, 99.9, 99.6, 99.8, 99.5, 99.7, 99.6, 99.8, 99.7],
            'T2_COMPLIANCE_RATE': [98.9, 98.7, 99.1, 98.5, 98.8, 98.6, 98.9, 98.4, 98.7, 98.8],
            'ENTERPRISE_ALERT_STATUS': ['NORMAL', 'NORMAL', 'NORMAL', 'HIGH_EXPOSURE', 'NORMAL', 'NORMAL', 'NORMAL', 'NORMAL', 'NORMAL', 'NORMAL']
        })

def show_product_catalog(session):
    """Display the data product catalog"""
    
    st.header("📦 Enterprise Clearing & Settlement Data Product Catalog")
    st.markdown("Available datasets and services powered by Dynamic Tables")
    
    # Get product catalog
    products = get_customer_data_products()
    
    # Product filters
    col1, col2, col3 = st.columns(3)
    
    with col1:
        access_filter = st.selectbox(
            "Filter by Access Level",
            ["All", "Participant-specific", "Public/Subscription", "Risk managers", "Compliance teams", "Operations teams"]
        )
    
    with col2:
        format_filter = st.selectbox(
            "Filter by Format",
            ["All", "API", "Dashboard", "CSV", "Secure Share", "PDF", "Excel"]
        )
    
    with col3:
        price_filter = st.selectbox(
            "Filter by Pricing",
            ["All", "Included", "Subscription", "Standard", "Premium", "Enterprise"]
        )
    
    # Filter products
    filtered_products = products
    if access_filter != "All":
        filtered_products = [p for p in filtered_products if p['access_level'] == access_filter]
    if format_filter != "All":
        filtered_products = [p for p in filtered_products if format_filter in p['format']]
    if price_filter != "All":
        filtered_products = [p for p in filtered_products if p['price'] == price_filter]
    
    # Display products in a grid
    for i in range(0, len(filtered_products), 2):
        cols = st.columns(2)
        
        for j, col in enumerate(cols):
            if i + j < len(filtered_products):
                product = filtered_products[i + j]
                
                with col:
                    st.markdown(f"""
                    <div style="border: 2px solid #e0e0e0; border-radius: 10px; padding: 1.5rem; margin: 1rem 0; background: white; height: 300px;">
                        <h3 style="color: #1f4e79; margin-top: 0;">{product['name']}</h3>
                        <p style="color: #666; height: 60px; overflow: hidden;">{product['description']}</p>
                        <div style="margin: 1rem 0;">
                            <strong>Access Level:</strong> {product['access_level']}<br/>
                            <strong>Update:</strong> {product['update_frequency']}<br/>
                            <strong>Formats:</strong> {', '.join(product['format'][:2])}{'...' if len(product['format']) > 2 else ''}<br/>
                            <strong>Scale:</strong> {product['records']}<br/>
                            <strong>Pricing:</strong> {product['price']}
                        </div>
                    </div>
                    """, unsafe_allow_html=True)
                    
                    # Action buttons (simplified to avoid nesting)
                    if st.button(f"📊 View Sample", key=f"sample_{i+j}", use_container_width=True):
                        show_product_sample(session, product)
                    if st.button(f"🚀 Provision Data", key=f"provision_{i+j}", use_container_width=True):
                        show_data_provision(session, product)  
                    if st.button(f"📖 API Docs", key=f"docs_{i+j}", use_container_width=True):
                        show_api_documentation(product)

def show_product_sample(session, product):
    """Show sample data for a product"""
    
    with st.expander(f"📊 Sample Data: {product['name']}", expanded=True):
        
        if "Settlement" in product['name']:
            # Show settlement data sample
            participant_data = get_sample_participant_data(session)
            if not participant_data.empty:
                st.markdown("**Sample Participant Settlement Data:**")
                st.dataframe(participant_data.head(), use_container_width=True)
            else:
                st.info("Sample data will be available once Dynamic Tables are running")
        
        elif "Risk" in product['name']:
            # Show risk data sample
            try:
                query = """
                SELECT 
                    participant_type,
                    COUNT(*) as participant_count,
                    AVG(avg_risk_score) as avg_risk_score,
                    SUM(risk_exposure_billions) as total_exposure
                FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION.ENTERPRISE_PARTICIPANT_RISK_MONITOR
                GROUP BY participant_type
                ORDER BY total_exposure DESC
                """
                
                result = session.sql(query).collect()
                risk_df = pd.DataFrame(result) if result else pd.DataFrame()
                
                if not risk_df.empty:
                    st.markdown("**Risk Analytics by Participant Type:**")
                    st.dataframe(risk_df, use_container_width=True)
                else:
                    st.info("Risk analytics will be available once Dynamic Tables are running")
            except Exception as e:
                st.warning(f"Error fetching risk sample data: {str(e)}")
                # Demo risk data
                demo_risk = pd.DataFrame({
                    'PARTICIPANT_TYPE': ['DEALER', 'BANK', 'INSTITUTIONAL', 'CUSTODIAN'],
                    'PARTICIPANT_COUNT': [847, 234, 156, 89],
                    'AVG_RISK_SCORE': [0.85, 0.62, 0.94, 0.71],
                    'TOTAL_EXPOSURE': [8.4, 12.7, 3.2, 5.8]
                })
                st.dataframe(demo_risk, use_container_width=True)
        
        elif "Market Data" in product['name']:
            # Show market data sample
            demo_market = pd.DataFrame({
                'Symbol': ['CORP.EX', 'TECH.EX', 'RAIL.EX', 'BANK.EX', 'MINE.EX'],
                'Last_Price': [132.45, 89.23, 156.78, 87.65, 23.89],
                'Volume': [1234567, 987654, 654321, 445566, 778899],
                'Change_Pct': [0.45, -1.23, 2.34, -0.56, 3.45],
                'Market_Cap_B': [185.2, 80.1, 95.4, 165.7, 35.2]
            })
            st.dataframe(demo_market, use_container_width=True)
        
        else:
            # Generic sample data
            demo_generic = pd.DataFrame({
                'Date': pd.date_range('2024-01-01', periods=5),
                'Metric_1': [100, 105, 98, 110, 107],
                'Metric_2': [85.5, 87.2, 84.1, 89.3, 88.7],
                'Status': ['Active'] * 5
            })
            st.dataframe(demo_generic, use_container_width=True)
        
        st.info("💡 This is a representative sample. Full datasets available through Snowflake Secure Data Sharing.")

def show_data_provision(_session, product):
    """Handle data provision to specific participants"""
    
    with st.expander(f"📊 Provision Data: {product['name']}", expanded=True):
        st.markdown("### Enterprise Clearing & Settlement Data Provision Portal")
        st.markdown("Select a participant to provision this data product via Snowflake Secure Data Sharing")
        
        # Get participant list (simplified for demo) - REAL NAMES REMOVED
        participants = GENERIC_PARTICIPANTS
        
        with st.form(f"provision_form_{product['name'].replace(' ', '_')}"):
            st.markdown("#### Data Sharing Configuration")
            
            # Simple form without nested columns
            selected_participant = st.selectbox(
                "Select Participant/Institution:",
                participants,
                help="Choose the institution to receive data access"
            )
            
            access_level = st.selectbox(
                "Access Level:",
                ["Read Only", "Full Dataset", "Real-time Stream", "Custom View"],
                help="Define the level of access to grant"
            )
            
            data_scope = st.selectbox(
                "Data Scope:",
                ["Current Data Only", "Historical (1 Year)", "Historical (3 Years)", "Full Historical"],
                help="Select the scope of historical data to include"
            )
            
            refresh_frequency = st.selectbox(
                "Refresh Frequency:",
                ["Real-time", "Hourly", "Daily", "Weekly"],
                help="How often should the shared data be updated"
            )
            
            sharing_method = st.radio(
                "Sharing Method:",
                ["Snowflake Secure Data Sharing", "API Access", "Scheduled Export"],
                help="Choose the method for data delivery"
            )
            
            # Additional notes
            notes = st.text_area(
                "Provision Notes:",
                placeholder="Optional: Add any specific requirements or notes..."
            )
            
            # Submit button
            submitted = st.form_submit_button("🚀 Provision Data Access")
            
            if submitted:
                # Generate a mock share name
                share_name = f"CSD_{product['name'].replace(' ', '_').upper()}_{selected_participant.split('(')[0].strip().replace(' ', '_').upper()}"
                
                st.success(f"✅ Data provision initiated successfully!")
                
                st.info(f"""
                **Provision Summary:**
                - **Product**: {product['name']}
                - **Recipient**: {selected_participant}
                - **Access Level**: {access_level}
                - **Data Scope**: {data_scope}
                - **Refresh**: {refresh_frequency}
                - **Method**: {sharing_method}
                - **Share Name**: `{share_name}`
                - **Status**: Provisioning in progress...
                
                The participant will receive access within 15 minutes via Snowflake Secure Data Sharing.
                """)
                
                # Show mock SQL for demonstration
                if sharing_method == "Snowflake Secure Data Sharing":
                    with st.expander("📄 Generated Snowflake Commands"):
                        # Use a sanitized version of the participant name for the mock account
                        sanitized_participant = selected_participant.split('(')[0].strip().lower().replace(' ', '_')
                        
                        st.code(f"""
-- Enterprise Clearing & Settlement Data Provision Commands
-- Generated for: {selected_participant}

-- Create secure data share
CREATE SHARE {share_name};

-- Grant database and schema access
GRANT USAGE ON DATABASE SF_SOLUTIONS TO SHARE {share_name};
GRANT USAGE ON SCHEMA SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION TO SHARE {share_name};

-- Grant table access based on product
GRANT SELECT ON SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION.ENTERPRISE_PARTICIPANT_RISK_MONITOR TO SHARE {share_name};
GRANT SELECT ON SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION.ENTERPRISE_DAILY_DASHBOARD TO SHARE {share_name};

-- Apply row-level security (participant-specific data)
ALTER TABLE SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION.ENTERPRISE_PARTICIPANT_RISK_MONITOR 
SET ROW ACCESS POLICY participant_access_policy;

-- Add consumer account (mock Snowflake account)
ALTER SHARE {share_name} ADD ACCOUNTS = ('{sanitized_participant}.snowflakecomputing.com');

-- Set share description
ALTER SHARE {share_name} SET COMMENT = 'Enterprise Clearing & Settlement {product["name"]} - {access_level} access for {selected_participant}';
                        """, language="sql")
                
                st.success("🎉 Data sharing configured! The participant can now access their data through Snowflake.")

def show_api_documentation(product):
    """Show API documentation for a product"""
    
    # Generic placeholders used previously
    generic_api_url = "https://api.clearingcorp.com"
    generic_clearing_path = "/clearing"
    
    with st.expander(f"📖 API Documentation: {product['name']}", expanded=True):
        
        st.markdown("### Authentication")
        st.markdown("All API calls require authentication using OAuth 2.0 tokens or Snowflake session tokens.")
        
        st.code(f"""
# Using OAuth 2.0
curl -H "Authorization: Bearer YOUR_TOKEN" \\
     {generic_api_url}{generic_clearing_path}/v1/data

# Using Snowflake Session
curl -H "X-Snowflake-Authorization-Token: YOUR_SESSION_TOKEN" \\
     {generic_api_url}{generic_clearing_path}/v1/data
        """, language="bash")
        
        st.markdown("### Endpoints")
        
        if "Settlement" in product['name']:
            st.code(f"""
# Get daily settlement data
GET {generic_clearing_path}/api/v1/settlement/daily?date=2024-01-15

# Get participant settlement summary  
GET {generic_clearing_path}/api/v1/settlement/participant/{{participant_id}}

# Get settlement performance metrics
GET {generic_clearing_path}/api/v1/settlement/performance?start_date=2024-01-01&end_date=2024-01-31

# Real-time settlement stream
WebSocket: wss://stream.clearingcorp.com{generic_clearing_path}/v1/stream/settlement
            """, language="bash")
        
        elif "Risk" in product['name']:
            st.code(f"""
# Get participant risk profile
GET {generic_clearing_path}/api/v1/risk/participant/{{participant_id}}

# Get system-wide risk metrics
GET {generic_clearing_path}/api/v1/risk/system/current

# Get risk alerts
GET {generic_clearing_path}/api/v1/risk/alerts?severity=high

# Risk exposure by sector
GET {generic_clearing_path}/api/v1/risk/exposure/sector
            """, language="bash")
        
        elif "Market Data" in product['name']:
            st.code(f"""
# Get real-time market data
GET /api/v1/market/realtime?symbols=CORP.EX,TECH.EX

# Historical data
GET /api/v1/market/historical?symbol=CORP.EX&start=2024-01-01

# Market statistics
GET /api/v1/market/stats/daily

# Real-time market feed
WebSocket: wss://stream.clearingcorp.com/market/v1/stream
            """, language="bash")
        
        else:
            st.code(f"""
# Generic data endpoint
GET {generic_clearing_path}/api/v1/data/{{dataset}}?filters={{parameters}}

# Bulk data export
POST {generic_clearing_path}/api/v1/export/{{dataset}}

# Real-time data stream
WebSocket: wss://stream.clearingcorp.com{generic_clearing_path}/v1/stream/{{dataset}}
            """, language="bash")
        
        # Rate limits and pricing  
        st.markdown("### Rate Limits")
        st.markdown("- **Standard**: 1,000 requests/hour")
        st.markdown("- **Premium**: 10,000 requests/hour") 
        st.markdown("- **Enterprise**: Unlimited")
        st.markdown("- **Real-time**: 100 connections")
        
        st.markdown("### Response Format")
        st.code("""
{
  "status": "success",
  "data": [...],
  "metadata": {
    "count": 1000,
    "timestamp": "2024-01-15T10:30:00Z",
    "next_page": "token_abc123"
  }
}
        """, language="json")

def show_secure_sharing_demo(session):
    """Demonstrate Snowflake Secure Data Sharing"""
    
    st.header("🔐 Snowflake Secure Data Sharing")
    st.markdown("Enterprise-grade data sharing with built-in security and governance")
    
    col1, col2 = st.columns([2, 1])
    
    with col1:
        st.markdown("### 📋 Active Data Shares")
        
        # Mock active shares - REAL NAMES REMOVED
        shares_data = pd.DataFrame({
            'Share Name': [
                'CLEARING_Settlement_PartA',
                'CLEARING_Settlement_PartB', 
                'CLEARING_Risk_PartC',
                'CLEARING_Market_PartD',
                'CLEARING_Compliance_RegAlpha'
            ],
            'Customer': [
                'Participant A (Major Bank)',
                'Participant B (Brokerage)',
                'Participant C (Institutional)',
                'Participant D (Custodian)', 
                'Regulator Alpha'
            ],
            'Data Product': [
                'Settlement Reports',
                'Settlement Reports',
                'Risk Analytics',
                'Market Data',
                'Compliance Reports'
            ],
            'Status': ['Active'] * 5,
            'Last Accessed': [
                '2024-01-15 09:30',
                '2024-01-15 08:45',
                '2024-01-15 10:15',
                '2024-01-15 07:20',
                '2024-01-14 16:30'
            ]
        })
        
        st.dataframe(shares_data, use_container_width=True)
        
        # Create new share demo
        st.markdown("### ➕ Create New Secure Share")
        
        with st.form("demo_share"):
            share_name = st.text_input("Share Name", value="SF_SOLUTIONS_Share")
            customer_account = st.text_input("Customer Account", placeholder="customer.snowflakecomputing.com")
            data_product = st.selectbox("Data Product", [p['name'] for p in get_customer_data_products()])
            access_level = st.selectbox("Access Level", ["Read Only", "Limited", "Full Access"])
            
            # Advanced options
            with st.expander("🔧 Advanced Sharing Options"):
                row_access_policy = st.checkbox("Apply Row Access Policy (participant-specific data)")
                column_masking = st.checkbox("Apply Dynamic Data Masking (sensitive fields)")
                time_based_access = st.checkbox("Time-based Access Control")
                
                if time_based_access:
                    start_date = st.date_input("Access Start Date")
                    end_date = st.date_input("Access End Date")
            
            submitted = st.form_submit_button("🚀 Create Secure Share (Demo)")
            
            if submitted and share_name and customer_account:
                st.success(f"✅ Secure share '{share_name}' created successfully!")
                
                # Show generated SQL for demo
                with st.expander("📄 Generated Snowflake SQL"):
                    schema_map = {
                        'Participant Settlement Reports': 'SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION.ENTERPRISE_PARTICIPANT_RISK_MONITOR',
                        'Market Data Feeds': 'SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.MARKET_DATA',
                        'Risk Analytics Package': 'SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION.ENTERPRISE_PARTICIPANT_RISK_MONITOR',
                        'Regulatory Compliance Reports': 'SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION.ENTERPRISE_DAILY_DASHBOARD',
                        'Settlement Performance Analytics': 'SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION.ENTERPRISE_DAILY_DASHBOARD'
                    }
                    
                    table_ref = schema_map.get(data_product, 'SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION.ENTERPRISE_DAILY_DASHBOARD')
                    
                    st.code(f("""
-- Create secure data share
CREATE SHARE {share_name};

-- Grant database and schema usage
GRANT USAGE ON DATABASE SF_SOLUTIONS TO SHARE {share_name};
GRANT USAGE ON SCHEMA SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION TO SHARE {share_name};

-- Grant table access with security policies
GRANT SELECT ON {table_ref} TO SHARE {share_name};

{f"-- Apply row access policy for participant data" if row_access_policy else ""}
{f"ALTER TABLE {table_ref} SET ROW ACCESS POLICY participant_access_policy;" if row_access_policy else ""}

{f"-- Apply column masking for sensitive data" if column_masking else ""}
{f"ALTER TABLE {table_ref} MODIFY COLUMN participant_id SET MASKING POLICY mask_participant_id;" if column_masking else ""}

-- Add consumer account
ALTER SHARE {share_name} ADD ACCOUNTS = ('{customer_account}');

-- Set share description
ALTER SHARE {share_name} SET COMMENT = 'Enterprise Clearing & Settlement {data_product} - {access_level} access';
                    """), language="sql")
    
    with col2:
        st.markdown("### 📊 Sharing Statistics")
        
        # Usage metrics
        metrics = [
            ("Active Shares", 47),
            ("Customer Accounts", 23), 
            ("Data Volume Shared", "156.8 GB"),
            ("Queries Today", 2847)
        ]
        
        for metric, value in metrics:
            st.metric(metric, value)
        
        st.markdown("### 🔒 Security Features")
        
        st.markdown("""
        ✅ **Row-level Security** ✅ **Dynamic Data Masking** ✅ **Time-based Access** ✅ **Audit Logging** ✅ **Encryption in Transit** ✅ **No Data Copy Required** """)
        
        st.markdown("### 🚨 Recent Activity")
        
        # REAL NAMES REMOVED
        activities = [
            "🟢 New share created for Participant A",
            "🔵 Participant C accessed risk data", 
            "🟡 Regulator Alpha compliance export completed",
            "🟢 Participant B share permissions updated"
        ]
        
        for activity in activities:
            st.markdown(f"- {activity}")

def main():
    """Main function for Customer Data Products"""

    st.title("🎯 Enterprise Clearing & Settlement Customer Data Products")
    st.markdown("Enterprise data distribution powered by Snowflake Dynamic Tables and Secure Data Sharing")
    
    # Get Snowflake session
    session = get_active_session()
    
    # Sidebar
    with st.sidebar:
        st.header("🎯 Customer Portal")
        
        selected_view = st.selectbox(
            "Select View",
            ["Product Catalog", "Secure Data Sharing", "Usage Analytics"],
            index=0
        )
        
        st.markdown("---")
        st.markdown("### 📊 Customer Stats")
        st.metric("Active Customers", "847")
        st.metric("Data Products", "5")
        st.metric("Secure Shares", "47")
        st.metric("API Calls (Today)", "45.2K")
        
        st.markdown("---")
        st.markdown("### 🔗 Quick Actions")
        
        if st.button("💼 Create Demo Share"):
            st.info("Demo share creation workflow")
        
        if st.button("📊 View Usage Report"):
            st.info("Usage analytics dashboard")
        
        if st.button("🔐 Manage Permissions"):
            st.info("Permission management interface")

    # Main content based on selected view
    if selected_view == "Product Catalog":
        show_product_catalog(session)
    elif selected_view == "Secure Data Sharing":
        show_secure_sharing_demo(session)
    elif selected_view == "Usage Analytics":
        # Usage analytics
        st.header("📊 Customer Usage Analytics")
        st.markdown("Monitor customer engagement and data product performance")
        
        # Sample usage data as simple tables (no plotly dependency)
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("### API Calls Trend (Last 7 Days)")
            api_trend = pd.DataFrame({
                'Date': pd.date_range('2024-01-01', periods=7),
                'API Calls': [1200, 1350, 1180, 1420, 1380, 1650, 1580],
                'Unique Users': [45, 52, 41, 58, 55, 67, 63]
            })
            st.dataframe(api_trend, use_container_width=True)
        
        with col2:
            st.markdown("### Product Usage Distribution")
            product_usage = pd.DataFrame({
                'Product': ['Settlement Reports', 'Risk Analytics', 'Market Data', 'Compliance Reports'],
                'Usage (%)': [45, 28, 18, 9],
                'Active Users': [125, 78, 52, 23]
            })
            st.dataframe(product_usage, use_container_width=True)

if __name__ == "__main__":
    main()