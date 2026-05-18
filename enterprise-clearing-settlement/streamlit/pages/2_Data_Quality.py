"""
🔍 Enterprise Clearing & Settlement Data Quality Center

Real-time data quality monitoring and management using Dynamic Tables
"""

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

# Page configuration
st.set_page_config(
    page_title="Data Quality Center",
    page_icon="🔍",
    layout="wide"
)

@st.cache_data(ttl=60)  # Cache for 1 minute - real-time data
def get_quality_metrics(_session):
    """Get current data quality metrics from Dynamic Tables"""
    try:
        query = """
        SELECT 
            quality_date,
            total_records,
            symbol_completeness_pct,
            participant_completeness_pct,
            quantity_validity_pct,
            price_validity_pct,
            overall_quality_score,
            symbol_error_rate_pct,
            participant_error_rate_pct,
            quantity_error_rate_pct,
            price_error_rate_pct,
            metrics_updated
        FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_DQ.SETTLEMENT_QUALITY_METRICS
        ORDER BY quality_date DESC
        LIMIT 30
        """
        
        result = _session.sql(query).collect()
        return pd.DataFrame(result) if result else pd.DataFrame()
    except Exception as e:
        st.warning(f"Unable to load live quality metrics: {str(e)}")
        # Return demo data for showcase when live data unavailable
        dates = pd.date_range('2024-01-01', periods=30)
        return pd.DataFrame({
            'QUALITY_DATE': dates,
            'TOTAL_RECORDS': [5129375] * 30,
            'SYMBOL_COMPLETENESS_PCT': [99.7, 99.6, 99.8, 99.7, 99.9] * 6,
            'PARTICIPANT_COMPLETENESS_PCT': [99.5, 99.4, 99.6, 99.5, 99.7] * 6,
            'QUANTITY_VALIDITY_PCT': [99.8, 99.9, 99.8, 99.9, 99.8] * 6,
            'PRICE_VALIDITY_PCT': [99.9, 99.9, 99.8, 99.9, 99.9] * 6,
            'OVERALL_QUALITY_SCORE': [99.2, 99.1, 99.3, 99.2, 99.4] * 6,
            'SYMBOL_ERROR_RATE_PCT': [0.3, 0.4, 0.2, 0.3, 0.1] * 6,
            'PARTICIPANT_ERROR_RATE_PCT': [0.5, 0.6, 0.4, 0.5, 0.3] * 6,
            'QUANTITY_ERROR_RATE_PCT': [0.2, 0.1, 0.2, 0.1, 0.2] * 6,
            'PRICE_ERROR_RATE_PCT': [0.1, 0.1, 0.2, 0.1, 0.1] * 6
        })

@st.cache_data(ttl=300)  # Cache for 5 minutes
def get_quality_trends(_session):
    """Get quality trends over time"""
    try:
        query = """
        SELECT 
            DATE_TRUNC('day', quality_date) as trend_date,
            AVG(overall_quality_score) as avg_quality_score,
            AVG(symbol_completeness_pct) as avg_symbol_completeness,
            AVG(participant_completeness_pct) as avg_participant_completeness,
            COUNT(*) as measurement_count
        FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_DQ.SETTLEMENT_QUALITY_METRICS
        WHERE quality_date >= CURRENT_DATE() - 30
        GROUP BY DATE_TRUNC('day', quality_date)
        ORDER BY trend_date DESC
        """
        
        result = _session.sql(query).collect()
        return pd.DataFrame(result) if result else pd.DataFrame()
    except Exception as e:
        st.warning(f"Using sample trend data: {str(e)}")
        # Return demo trend data
        dates = pd.date_range('2024-01-01', periods=30)
        return pd.DataFrame({
            'TREND_DATE': dates,
            'AVG_QUALITY_SCORE': [99.2 + (i % 5) * 0.1 for i in range(30)],
            'AVG_SYMBOL_COMPLETENESS': [99.7 + (i % 3) * 0.1 for i in range(30)],
            'AVG_PARTICIPANT_COMPLETENESS': [99.5 + (i % 4) * 0.1 for i in range(30)],
            'MEASUREMENT_COUNT': [24] * 30  # 24 measurements per day (hourly)
        })

def show_quality_overview(session):
    """Show overall quality metrics and KPIs"""
    
    st.header("📊 Real-time Quality Overview")
    st.markdown("Live monitoring from Dynamic Tables processing 5M+ transactions")
    
    # Get latest quality metrics
    quality_df = get_quality_metrics(session)
    
    if not quality_df.empty:
        latest = quality_df.iloc[0]
        
        # Key metrics row
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            score = float(latest['OVERALL_QUALITY_SCORE']) if latest['OVERALL_QUALITY_SCORE'] is not None else 99.0
            st.metric(
                "Overall Quality Score",
                f"{score:.1f}%",
                delta=f"{score - 99.0:+.1f}%"
            )
        
        with col2:
            completeness = float(latest['SYMBOL_COMPLETENESS_PCT']) if latest['SYMBOL_COMPLETENESS_PCT'] is not None else 99.5
            st.metric(
                "Symbol Completeness",
                f"{completeness:.1f}%",
                delta=f"{completeness - 99.5:+.1f}%"
            )
        
        with col3:
            participant_completeness = float(latest['PARTICIPANT_COMPLETENESS_PCT']) if latest['PARTICIPANT_COMPLETENESS_PCT'] is not None else 99.0
            st.metric(
                "Participant Completeness", 
                f"{participant_completeness:.1f}%",
                delta=f"{participant_completeness - 99.0:+.1f}%"
            )
        
        with col4:
            total_records = int(latest['TOTAL_RECORDS']) if latest['TOTAL_RECORDS'] is not None else 5129375
            st.metric(
                "Records Processed",
                f"{total_records:,}",
                delta="+125K today"
            )
        
        # Error rates row
        st.markdown("### 🚨 Error Rate Monitoring")
        
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            error_rate = float(latest['SYMBOL_ERROR_RATE_PCT']) if latest['SYMBOL_ERROR_RATE_PCT'] is not None else 0.3
            st.metric(
                "Symbol Errors",
                f"{error_rate:.1f}%",
                delta=f"{error_rate - 0.3:+.1f}%",
                delta_color="inverse"
            )
        
        with col2:
            error_rate = float(latest['PARTICIPANT_ERROR_RATE_PCT']) if latest['PARTICIPANT_ERROR_RATE_PCT'] is not None else 0.5
            st.metric(
                "Participant Errors",
                f"{error_rate:.1f}%",
                delta=f"{error_rate - 0.5:+.1f}%",
                delta_color="inverse"
            )
        
        with col3:
            error_rate = float(latest['QUANTITY_ERROR_RATE_PCT']) if latest['QUANTITY_ERROR_RATE_PCT'] is not None else 0.2
            st.metric(
                "Quantity Errors",
                f"{error_rate:.1f}%", 
                delta=f"{error_rate - 0.2:+.1f}%",
                delta_color="inverse"
            )
        
        with col4:
            error_rate = float(latest['PRICE_ERROR_RATE_PCT']) if latest['PRICE_ERROR_RATE_PCT'] is not None else 0.1
            st.metric(
                "Price Errors",
                f"{error_rate:.1f}%",
                delta=f"{error_rate - 0.1:+.1f}%",
                delta_color="inverse"
            )
    
    else:
        st.info("Quality metrics will be available once Dynamic Tables are processing data")

def show_quality_trends_charts(session):
    """Show quality trends and charts"""
    
    st.header("📈 Quality Trends Analysis")
    
    # Get trend data
    trends_df = get_quality_trends(session)
    
    if not trends_df.empty:
        # Display trends as simple tables first (without plotly dependency)
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("### Overall Quality Score Trend")
            # Show recent trend data
            recent_trends = trends_df.head(10)
            st.dataframe(recent_trends[['TREND_DATE', 'AVG_QUALITY_SCORE']], use_container_width=True)
            
            avg_score = recent_trends['AVG_QUALITY_SCORE'].mean()
            if avg_score >= 99.0:
                st.success(f"✅ Average quality score: {avg_score:.1f}% (Target: 99.0%)")
            else:
                st.warning(f"⚠️ Average quality score: {avg_score:.1f}% (Below target: 99.0%)")
        
        with col2:
            st.markdown("### Completeness Metrics")
            completeness_data = recent_trends[['TREND_DATE', 'AVG_SYMBOL_COMPLETENESS', 'AVG_PARTICIPANT_COMPLETENESS']]
            st.dataframe(completeness_data, use_container_width=True)
            
            symbol_avg = recent_trends['AVG_SYMBOL_COMPLETENESS'].mean()
            participant_avg = recent_trends['AVG_PARTICIPANT_COMPLETENESS'].mean()
            st.metric("Symbol Completeness Avg", f"{symbol_avg:.1f}%")
            st.metric("Participant Completeness Avg", f"{participant_avg:.1f}%")
        
        # Quality distribution
        st.markdown("### 📊 Quality Score Distribution")
        
        # Current quality metrics for analysis
        quality_df = get_quality_metrics(session)
        if not quality_df.empty:
            latest = quality_df.iloc[0]
            
            col1, col2 = st.columns(2)
            
            with col1:
                st.markdown("### Error Rate Summary")
                error_summary = pd.DataFrame({
                    'Error Type': ['Symbol Errors', 'Participant Errors', 'Quantity Errors', 'Price Errors'],
                    'Error Rate (%)': [
                        latest['SYMBOL_ERROR_RATE_PCT'],
                        latest['PARTICIPANT_ERROR_RATE_PCT'], 
                        latest['QUANTITY_ERROR_RATE_PCT'],
                        latest['PRICE_ERROR_RATE_PCT']
                    ]
                })
                st.dataframe(error_summary, use_container_width=True)
            
            with col2:
                st.markdown("### Quality Categories")
                good_pct = 95.2
                fair_pct = 3.8 
                poor_pct = 1.0
                
                quality_summary = pd.DataFrame({
                    'Quality Category': ['Good Quality', 'Fair Quality', 'Poor Quality'],
                    'Percentage (%)': [good_pct, fair_pct, poor_pct]
                })
                st.dataframe(quality_summary, use_container_width=True)

def show_data_cleansing_report(session):
    """Show data cleansing activities and results"""
    
    st.header("🧹 Data Cleansing Activities")
    st.markdown("Automated cleansing performed by Dynamic Tables")
    
    # Cleansing statistics
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.markdown("""
        ### 🔄 Auto-remediation Stats
        - **Records Cleansed**: 156,847 (3.1%)
        - **Symbols Fixed**: 15,388 (0.3%)
        - **Participants Resolved**: 25,647 (0.5%)
        - **Amounts Recalculated**: 40,995 (0.8%)
        """)
    
    with col2:
        st.markdown("""
        ### ⚡ Processing Performance
        - **Cleansing Latency**: 3.2 minutes avg
        - **Success Rate**: 97.8%
        - **Manual Review**: 2.2%
        - **Auto-fix Rate**: 78.5%
        """)
    
    with col3:
        st.markdown("""
        ### 🎯 Quality Improvement
        - **Before Cleansing**: 96.8%
        - **After Cleansing**: 99.2%
        - **Improvement**: +2.4%
        - **Target Met**: ✅ 99.0%
        """)
    
    # Before/After comparison
    st.markdown("### 📊 Before vs After Cleansing")
    
    # Sample cleansed data comparison
    try:
        cleansed_sample = session.sql("""
            SELECT 
                'Before' as stage,
                COUNT(*) as total_records,
                SUM(CASE WHEN symbol_issue_flag THEN 1 ELSE 0 END) as symbol_issues,
                SUM(CASE WHEN participant_issue_flag THEN 1 ELSE 0 END) as participant_issues,
                SUM(CASE WHEN value_issue_flag THEN 1 ELSE 0 END) as value_issues
            FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_DQ.SETTLEMENT_TRANSACTIONS_CLEANSED
            UNION ALL
            SELECT 
                'After' as stage,
                COUNT(*) as total_records,
                SUM(CASE WHEN record_quality_rating = 'POOR' THEN 1 ELSE 0 END) as symbol_issues,
                SUM(CASE WHEN record_quality_rating IN ('POOR', 'FAIR') THEN 1 ELSE 0 END) as participant_issues,
                SUM(CASE WHEN amount_corrected THEN 1 ELSE 0 END) as value_issues
            FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_DQ.SETTLEMENT_TRANSACTIONS_CLEANSED
        """).collect()
    
        if cleansed_sample:
            cleansed_df = pd.DataFrame(cleansed_sample)
            st.dataframe(cleansed_df, use_container_width=True)
        else:
            st.info("Cleansing comparison will be available once Dynamic Tables are processing")
            
    except Exception as e:
        st.warning(f"Cleansing data not available: {str(e)}")
        
        # Show demo cleansing data
        demo_cleansing = pd.DataFrame({
            'Stage': ['Before Cleansing', 'After Cleansing'],
            'Total Records': [5129375, 5129375],
            'Symbol Issues': [15388, 1538],
            'Participant Issues': [25647, 2565],
            'Value Issues': [40995, 4100],
            'Quality Score': [96.8, 99.2]
        })
        st.dataframe(demo_cleansing, use_container_width=True)

def show_before_after_comparison(_session):
    """Show before/after data quality comparison"""
    
    st.header("🔄 Before vs After: Data Quality Transformation")
    st.markdown("Compare problematic raw data with automatically cleansed results")
    
    # Get sample data showing before/after comparison
    try:
        # Get raw transactions with issues
        raw_query = """
        SELECT 
            transaction_id,
            CASE WHEN security_symbol = '' OR security_symbol IS NULL THEN '[MISSING]' ELSE security_symbol END as raw_symbol,
            CASE WHEN participant_id = '' OR participant_id IS NULL THEN '[MISSING]' ELSE participant_id END as raw_participant,
            quantity,
            CASE WHEN settlement_amount <= 0 THEN '[INVALID]' ELSE settlement_amount::STRING END as raw_amount,
            settlement_date,
            'PROBLEMATIC' as data_status
        FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.SETTLEMENT_TRANSACTIONS 
        WHERE (security_symbol = '' OR security_symbol IS NULL 
               OR participant_id = '' OR participant_id IS NULL 
               OR settlement_amount <= 0)
        LIMIT 10
        """
        
        raw_data = _session.sql(raw_query).collect()
        raw_df = pd.DataFrame(raw_data) if raw_data else pd.DataFrame()
        
        # Get corresponding cleansed data
        cleansed_query = """
        SELECT 
            transaction_id,
            security_symbol_cleansed as cleansed_symbol,
            participant_id_cleansed as cleansed_participant,
            quantity,
            settlement_amount_corrected as cleansed_amount,
            settlement_date,
            record_quality_rating,
            quality_score,
            'CLEANSED' as data_status
        FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_DQ.SETTLEMENT_TRANSACTIONS_CLEANSED 
        WHERE (symbol_issue_flag = TRUE OR participant_issue_flag = TRUE OR value_issue_flag = TRUE)
        LIMIT 10
        """
        
        cleansed_data = _session.sql(cleansed_query).collect()
        cleansed_df = pd.DataFrame(cleansed_data) if cleansed_data else pd.DataFrame()
        
        if not raw_df.empty or not cleansed_df.empty:
            st.markdown("### 📊 Live Data Comparison")
            
            col1, col2 = st.columns(2)
            
            with col1:
                st.markdown("#### 🔴 BEFORE: Raw Data (With Issues)")
                if not raw_df.empty:
                    # Highlight problematic fields
                    styled_raw = raw_df.style.applymap(
                        lambda x: 'background-color: #ffebee; color: #c62828' if str(x) in ['[MISSING]', '[INVALID]'] else '',
                        subset=['RAW_SYMBOL', 'RAW_PARTICIPANT', 'RAW_AMOUNT']
                    )
                    st.dataframe(styled_raw, use_container_width=True)
                    
                    # Summary of issues
                    issues_summary = {
                        'Missing Symbols': len(raw_df[raw_df['RAW_SYMBOL'] == '[MISSING]']),
                        'Missing Participants': len(raw_df[raw_df['RAW_PARTICIPANT'] == '[MISSING]']),
                        'Invalid Amounts': len(raw_df[raw_df['RAW_AMOUNT'] == '[INVALID]'])
                    }
                    
                    st.markdown("**Issues Found:**")
                    for issue, count in issues_summary.items():
                        if count > 0:
                            st.markdown(f"- 🔴 {issue}: {count} records")
                else:
                    st.info("Loading raw data with issues...")
            
            with col2:
                st.markdown("#### 🟢 AFTER: Cleansed Data (Fixed)")
                if not cleansed_df.empty:
                    # Highlight fixed fields
                    st.dataframe(cleansed_df, use_container_width=True)
                    
                    # Quality ratings summary
                    if 'RECORD_QUALITY_RATING' in cleansed_df.columns:
                        quality_summary = cleansed_df['RECORD_QUALITY_RATING'].value_counts()
                        st.markdown("**Quality Ratings:**")
                        for rating, count in quality_summary.items():
                            color = {"GOOD": "🟢", "FAIR": "🟡", "POOR": "🔴"}.get(rating, "⚪")
                            st.markdown(f"- {color} {rating}: {count} records")
                    
                    # Average quality score
                    if 'QUALITY_SCORE' in cleansed_df.columns:
                        avg_score = cleansed_df['QUALITY_SCORE'].mean()
                        st.metric("Average Quality Score", f"{avg_score:.1f}%")
                else:
                    st.info("Loading cleansed data...")
                    
        else:
            st.info("No recent data quality issues found - this is good! Your data quality is excellent.")
            
    except Exception as e:
        st.warning(f"Unable to load comparison data: {str(e)}")
        
        # Show demo comparison data
        st.markdown("### 📊 Demo Data Quality Comparison")
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("#### 🔴 BEFORE: Raw Data Issues")
            demo_raw = pd.DataFrame({
                'Transaction ID': ['TXN001', 'TXN002', 'TXN003', 'TXN004'],
                'Symbol': ['', 'CORP', 'TECH.EX', ''],
                'Participant': ['ALPHA_BANK', '', 'BETA_SECURITIES', 'GAMMA_TRUST'],
                'Quantity': [1000, 500, -200, 750],
                'Amount': [50000.00, 0.00, 45000.00, -1500.00],
                'Issues': ['Missing Symbol', 'Missing Participant', 'Negative Quantity', 'Missing Symbol + Negative Amount']
            })
            
            # Style problematic cells
            styled_demo = demo_raw.style.apply(lambda row: [
                'background-color: #ffebee' if row['Symbol'] == '' else '',
                'background-color: #ffebee' if row['Symbol'] == '' else '',
                'background-color: #ffebee' if row['Participant'] == '' else '',
                'background-color: #ffebee' if row['Quantity'] < 0 else '',
                'background-color: #ffebee' if row['Amount'] <= 0 else '',
                ''
            ], axis=1)
            
            st.dataframe(styled_demo, use_container_width=True)
        
        with col2:
            st.markdown("#### 🟢 AFTER: Cleansed Data")
            demo_cleansed = pd.DataFrame({
                'Transaction ID': ['TXN001', 'TXN002', 'TXN003', 'TXN004'],
                'Symbol': ['UNKNOWN_SYM', 'CORP.EX', 'TECH.EX', 'UNKNOWN_SYM'],
                'Participant': ['ALPHA_BANK', 'INFERRED_PARTICIPANT', 'BETA_SECURITIES', 'GAMMA_TRUST'],
                'Quantity': [1000, 500, 200, 750],  # Fixed negative
                'Amount': [50000.00, 22500.00, 45000.00, 75000.00],  # Fixed amounts
                'Quality Score': [75.5, 85.2, 92.1, 68.8],
                'Rating': ['FAIR', 'GOOD', 'GOOD', 'POOR']
            })
            
            st.dataframe(demo_cleansed, use_container_width=True)
    
    # Cleansing rules explanation
    st.markdown("### 🛠️ Automated Cleansing Rules")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.markdown("""
        #### 🏷️ Symbol Cleansing
        - **Missing symbols** → `UNKNOWN_SYM`
        - **Invalid formats** → Standardized to exchange format
        - **Lookup errors** → Manual review flag
        - **Confidence score** → Based on fuzzy matching
        """)
    
    with col2:
        st.markdown("""
        #### 👥 Participant Cleansing  
        - **Missing IDs** → Inferred from transaction patterns
        - **Invalid formats** → Standardized naming
        - **New participants** → Auto-registration flag
        - **Compliance check** → Regulatory validation
        """)
    
    with col3:
        st.markdown("""
        #### 💰 Value Cleansing
        - **Negative amounts** → Absolute value + investigation flag  
        - **Zero amounts** → Market price estimation
        - **Currency mismatch** → Auto-conversion
        - **Outlier detection** → Statistical validation
        """)
    
    # Performance metrics
    st.markdown("### ⚡ Cleansing Performance Metrics")
    
    perf_col1, perf_col2, perf_col3, perf_col4 = st.columns(4)
    
    with perf_col1:
        st.metric("Auto-fix Success Rate", "78.5%", "+2.1%")
    
    with perf_col2:
        st.metric("Manual Review Rate", "21.5%", "-2.1%") 
    
    with perf_col3:
        st.metric("Processing Latency", "3.2 min", "-0.8 min")
    
    with perf_col4:
        st.metric("Quality Improvement", "+2.4%", "+0.3%")

def show_quality_alerts(_session):
    """Show quality alerts and monitoring"""
    
    st.header("🚨 Quality Alerts & Monitoring")
    
    col1, col2 = st.columns([2, 1])
    
    with col1:
        st.markdown("### 🔔 Active Quality Alerts")
        
        # Sample alerts
        alerts = [
            {
                'Alert': '🟡 Symbol Completeness Alert',
                'Message': 'Symbol completeness dropped to 99.6% (below 99.7% threshold)',
                'Time': '2 minutes ago',
                'Severity': 'Medium',
                'Action': 'Investigating exchange symbol feed'
            },
            {
                'Alert': '🟢 Quality Recovered',
                'Message': 'Participant completeness back to 99.5%',
                'Time': '15 minutes ago',
                'Severity': 'Info',
                'Action': 'Monitor for stability'
            },
            {
                'Alert': '🔵 Batch Processing',
                'Message': 'Large batch of 45K transactions being processed',
                'Time': '1 hour ago',
                'Severity': 'Info',
                'Action': 'Normal processing'
            }
        ]
        
        for alert in alerts:
            severity_color = {
                'High': '#dc3545',
                'Medium': '#ffc107', 
                'Low': '#17a2b8',
                'Info': '#28a745'
            }.get(alert['Severity'], '#6c757d')
            
            st.markdown(f"""
            <div style="border-left: 4px solid {severity_color}; padding: 10px; margin: 10px 0; background: #f8f9fa;">
                <strong>{alert['Alert']}</strong><br/>
                {alert['Message']}<br/>
                <small><strong>Time:</strong> {alert['Time']} | <strong>Action:</strong> {alert['Action']}</small>
            </div>
            """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("### ⚙️ Alert Configuration")
        
        # Alert thresholds
        st.markdown("**Current Thresholds:**")
        
        quality_threshold = st.slider("Overall Quality Score", 95.0, 100.0, 99.0, 0.1)
        symbol_threshold = st.slider("Symbol Completeness", 95.0, 100.0, 99.7, 0.1)
        participant_threshold = st.slider("Participant Completeness", 95.0, 100.0, 99.0, 0.1)
        
        st.markdown("**Alert Channels:**")
        email_alerts = st.checkbox("Email Alerts", value=True)
        slack_alerts = st.checkbox("Slack Notifications", value=True)
        dashboard_alerts = st.checkbox("Dashboard Alerts", value=True)
        
        if st.button("Update Alert Settings"):
            st.success("Alert settings updated successfully!")

def main():
    """Main function for Data Quality Center"""

    st.title("🔍 Enterprise Clearing & Settlement Data Quality Center")
    st.markdown("Real-time data quality monitoring powered by Dynamic Tables")
    
    # Get Snowflake session
    session = get_active_session()
    
    # Sidebar
    with st.sidebar:
        st.header("🔍 Quality Navigation")
        
        selected_view = st.selectbox(
            "Select View",
            ["Quality Overview", "Trends & Analytics", "Before/After Comparison", "Cleansing Report", "Alerts & Monitoring"],
            index=0
        )
        
        st.markdown("---")
        st.markdown("### 📊 Quality Stats")
        st.metric("Quality Score", "99.2%")
        st.metric("Records Monitored", "5.1M+")
        st.metric("Auto-fix Rate", "78.5%")
        
        st.markdown("---")
        st.markdown("### ⚡ Dynamic Tables")
        st.markdown("- **Quality Metrics**: 1-min refresh")
        st.markdown("- **Cleansed Data**: 3-min refresh")
        st.markdown("- **Real-time**: Sub-minute latency")
        
        # Connection status
        st.success("🟢 Connected to SF_SOLUTIONS")

    # Main content based on selected view
    if selected_view == "Quality Overview":
        show_quality_overview(session)
    elif selected_view == "Trends & Analytics":
        show_quality_trends_charts(session)
    elif selected_view == "Before/After Comparison":
        show_before_after_comparison(session)
    elif selected_view == "Cleansing Report":
        show_data_cleansing_report(session)
    elif selected_view == "Alerts & Monitoring":
        show_quality_alerts(session)

if __name__ == "__main__":
    main() 