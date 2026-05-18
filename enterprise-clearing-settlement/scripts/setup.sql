/*************************************************************************************************/
-- ENTERPRISE CLEARING & SETTLEMENT DATA PLATFORM SETUP
-- Version: 1.0
--
-- PREREQUISITES:
-- This script requires ACCOUNTADMIN role or a role with:
--   - CREATE DATABASE, SCHEMA, TABLE, VIEW, DYNAMIC TABLE
--   - CREATE WAREHOUSE
--   - CREATE STAGE
--
-- WHAT THIS SCRIPT CREATES:
--   - Database: SF_SOLUTIONS (if not exists)
--   - Schemas: CLEARING_SETTLEMENT_RAW, CLEARING_SETTLEMENT_DQ,
--              CLEARING_SETTLEMENT_NORMALIZED, CLEARING_SETTLEMENT_CONSUMPTION
--   - Warehouses: SF_SOLUTIONS_WH (XS), SF_SOLUTIONS_ETL_WH (M), SF_SOLUTIONS_ANALYTICS_WH (L)
--   - 5 static tables with 5M+ records of realistic settlement data
--   - 7 Dynamic Tables across quality, normalized, and consumption layers
--   - Stage for Streamlit application
--
-- ESTIMATED RUNTIME: ~5-10 minutes (bulk of time in 5M+ record generation)
/*************************************************************************************************/

USE ROLE ACCOUNTADMIN;

ALTER SESSION SET query_tag = '{"origin":"sf_sit-is",'
    || '"name":"enterprise_clearing_and_settlement_data_platform",'
    || '"version":{"major":1,"minor":0},'
    || '"attributes":{"is_quickstart":1,"source":"sql"}}'

/*************************************************************************************************/
-- SECTION 1: Database, Schemas, Warehouses, and Stage
/*************************************************************************************************/

CREATE DATABASE IF NOT EXISTS SF_SOLUTIONS;

CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.CLEARING_SETTLEMENT_DQ;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.CLEARING_SETTLEMENT_NORMALIZED;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION;

CREATE WAREHOUSE IF NOT EXISTS SF_SOLUTIONS_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'General purpose warehouse for SF Solutions';

CREATE WAREHOUSE IF NOT EXISTS SF_SOLUTIONS_ETL_WH
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    COMMENT = 'ETL warehouse for clearing pipeline data processing';

CREATE WAREHOUSE IF NOT EXISTS SF_SOLUTIONS_ANALYTICS_WH
    WAREHOUSE_SIZE = 'LARGE'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    COMMENT = 'Analytics warehouse for clearing pipeline reporting';

USE WAREHOUSE SF_SOLUTIONS_WH;

USE DATABASE SF_SOLUTIONS;
USE SCHEMA CLEARING_SETTLEMENT_RAW;

CREATE STAGE IF NOT EXISTS SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.STREAMLIT_STAGE
    COMMENT = 'Stage for Enterprise Clearing & Settlement Streamlit application files';

/*************************************************************************************************/
-- SECTION 2: RAW Layer - Static Tables (DDL)
/*************************************************************************************************/

CREATE OR REPLACE TABLE SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.SETTLEMENT_TRANSACTIONS (
    transaction_id STRING,
    trade_date DATE,
    settlement_date DATE,
    security_symbol STRING,
    participant_id STRING,
    counterparty_id STRING,
    quantity NUMBER(15,2),
    price NUMBER(10,4),
    settlement_amount NUMBER(15,2),
    settlement_status STRING,
    currency STRING,
    created_timestamp TIMESTAMP_NTZ(6),
    source_system STRING,
    batch_id STRING,
    row_hash STRING
)
COMMENT = 'Raw settlement transaction data from various trading systems';

CREATE OR REPLACE TABLE SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.SECURITIES_MASTER (
    security_id STRING,
    symbol STRING,
    security_name STRING,
    security_type STRING,
    exchange STRING,
    currency STRING,
    sector STRING,
    market_cap NUMBER(15,2),
    effective_date DATE,
    status STRING,
    last_updated TIMESTAMP_NTZ(6)
)
COMMENT = 'Master data for securities traded on recognized exchanges';

CREATE OR REPLACE TABLE SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.PARTICIPANTS (
    participant_id STRING,
    participant_name STRING,
    participant_type STRING,
    registration_number STRING,
    address STRING,
    city STRING,
    province STRING,
    postal_code STRING,
    status STRING,
    registration_date DATE,
    last_verified TIMESTAMP_NTZ(6)
)
COMMENT = 'Central Depository participant member information';

CREATE OR REPLACE TABLE SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.TRANSACTION_FEES (
    fee_id STRING,
    transaction_id STRING,
    fee_type STRING,
    fee_amount NUMBER(10,4),
    currency STRING,
    fee_date DATE,
    created_timestamp TIMESTAMP_NTZ(6)
)
COMMENT = 'Transaction fees and charges for settlement processing';

CREATE OR REPLACE TABLE SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.MARKET_DATA (
    symbol STRING,
    trade_date DATE,
    open_price NUMBER(10,4),
    close_price NUMBER(10,4),
    high_price NUMBER(10,4),
    low_price NUMBER(10,4),
    volume NUMBER(15,0),
    created_timestamp TIMESTAMP_NTZ(6)
)
COMMENT = 'Daily market data for listed securities';

/*************************************************************************************************/
-- SECTION 3: Demo Data Generation (5M+ records)
/*************************************************************************************************/

USE WAREHOUSE SF_SOLUTIONS_ETL_WH;

SET EXCHANGE_NAME = 'EXCH';
SET TICKER_1  = 'CORP.EXCH'; SET COMPANY_1  = 'Global Financial Corp';
SET TICKER_2  = 'TECH.EXCH'; SET COMPANY_2  = 'Innovatech Systems Inc.';
SET TICKER_3  = 'RAIL.EXCH'; SET COMPANY_3  = 'Continental Transport Co.';
SET TICKER_4  = 'BANK.EXCH'; SET COMPANY_4  = 'National Trust Bank';
SET TICKER_5  = 'MINE.EXCH'; SET COMPANY_5  = 'Precious Metals Mining';
SET TICKER_6  = 'SOFT.EXCH'; SET COMPANY_6  = 'Enterprise Software Solutions';
SET TICKER_7  = 'FOOD.EXCH'; SET COMPANY_7  = 'Retail Food Holdings';
SET TICKER_8  = 'UTIL.EXCH'; SET COMPANY_8  = 'Regional Utility Group';
SET TICKER_9  = 'LOAN.EXCH'; SET COMPANY_9  = 'Midwest Lending Corp.';
SET TICKER_10 = 'TELE.EXCH'; SET COMPANY_10 = 'Broadband Telecom Services';
SET TICKER_11 = 'PIPE.EXCH'; SET COMPANY_11 = 'Energy Transmission Systems';
SET TICKER_12 = 'FREI.EXCH'; SET COMPANY_12 = 'Pan-Continental Freight';
SET TICKER_13 = 'INSURE.EXCH'; SET COMPANY_13 = 'Apex Life & Health';
SET TICKER_14 = 'SUN.EXCH'; SET COMPANY_14 = 'Horizon Insurance Group';
SET TICKER_15 = 'FIN.EXCH'; SET COMPANY_15 = 'Central Investment Banking';
SET TICKER_16 = 'MANAGE.EXCH'; SET COMPANY_16 = 'Global Asset Management';
SET TICKER_17 = 'CAPI.EXCH'; SET COMPANY_17 = 'Capital Markets Group';
SET TICKER_18 = 'FAST.EXCH'; SET COMPANY_18 = 'Quick Service Restaurants';
SET TICKER_19 = 'MINRL.EXCH'; SET COMPANY_19 = 'Diversified Royalty Corp.';
SET TICKER_20 = 'SERV.EXCH'; SET COMPANY_20 = 'IT Consulting Services';
SET TICKER_21 = 'BIO.EXCH'; SET COMPANY_21 = 'Research Biotech Holdings';
SET TICKER_22 = 'FLIGHT.EXCH'; SET COMPANY_22 = 'Northwind Airlines';
SET TICKER_23 = 'CYBER.EXCH'; SET COMPANY_23 = 'Secure Cyber Systems';
SET TICKER_24 = 'POWER.EXCH'; SET COMPANY_24 = 'Nuclear Energy Producer';
SET TICKER_25 = 'REIT.EXCH'; SET COMPANY_25 = 'Commercial Property Trust';

INSERT INTO SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.SETTLEMENT_TRANSACTIONS
SELECT 
    UUID_STRING() AS transaction_id,
    DATEADD(DAY, -UNIFORM(0, 180, RANDOM()), CURRENT_DATE()) AS trade_date,
    DATEADD(DAY, UNIFORM(1, 3, RANDOM()), trade_date) AS settlement_date,
    CASE UNIFORM(1, 1000, RANDOM())
        WHEN 1 THEN $TICKER_1 WHEN 2 THEN $TICKER_2 WHEN 3 THEN $TICKER_3 WHEN 4 THEN $TICKER_4
        WHEN 5 THEN $TICKER_5 WHEN 6 THEN $TICKER_6 WHEN 7 THEN $TICKER_7 WHEN 8 THEN $TICKER_8
        WHEN 9 THEN $TICKER_9 WHEN 10 THEN $TICKER_10 WHEN 11 THEN $TICKER_11 WHEN 12 THEN $TICKER_12
        WHEN 13 THEN $TICKER_13 WHEN 14 THEN $TICKER_14 WHEN 15 THEN $TICKER_15 WHEN 16 THEN $TICKER_16
        WHEN 17 THEN $TICKER_17 WHEN 18 THEN $TICKER_18 WHEN 19 THEN $TICKER_19 WHEN 20 THEN $TICKER_20
        WHEN 21 THEN $TICKER_21 WHEN 22 THEN $TICKER_22 WHEN 23 THEN $TICKER_23 WHEN 24 THEN $TICKER_24
        WHEN 25 THEN $TICKER_25 WHEN 26 THEN 'SYM_26.EXCH' WHEN 27 THEN 'SYM_27.EXCH' WHEN 28 THEN 'SYM_28.EXCH'
        WHEN 29 THEN 'SYM_29.EXCH' WHEN 30 THEN 'SYM_30.EXCH' WHEN 31 THEN 'SYM_31.EXCH' WHEN 32 THEN 'SYM_32.EXCH'
        WHEN 33 THEN 'SYM_33.EXCH' WHEN 34 THEN 'SYM_34.EXCH' WHEN 35 THEN 'SYM_35.EXCH' WHEN 36 THEN 'SYM_36.EXCH'
        WHEN 37 THEN 'SYM_37.EXCH' WHEN 38 THEN 'SYM_38.EXCH' WHEN 39 THEN 'SYM_39.EXCH' WHEN 40 THEN 'SYM_40.EXCH'
        WHEN 997 THEN 'INVALID_SYM' WHEN 998 THEN NULL WHEN 999 THEN 'XYZ.UNKNOWN' 
        WHEN 1000 THEN '' ELSE 
        CASE UNIFORM(1, 100, RANDOM()) 
            WHEN 1 THEN $TICKER_1 WHEN 2 THEN $TICKER_2 WHEN 3 THEN $TICKER_3 WHEN 4 THEN $TICKER_4
            WHEN 5 THEN $TICKER_5 WHEN 6 THEN $TICKER_6 WHEN 7 THEN $TICKER_7 WHEN 8 THEN $TICKER_8
            WHEN 9 THEN $TICKER_9 WHEN 10 THEN $TICKER_10 WHEN 11 THEN $TICKER_11 WHEN 12 THEN $TICKER_12
            WHEN 13 THEN $TICKER_13 WHEN 14 THEN $TICKER_14 WHEN 15 THEN $TICKER_15 WHEN 16 THEN $TICKER_16
            WHEN 17 THEN $TICKER_17 WHEN 18 THEN $TICKER_18 WHEN 19 THEN $TICKER_19 WHEN 20 THEN $TICKER_20
            WHEN 21 THEN $TICKER_21 WHEN 22 THEN $TICKER_22 WHEN 23 THEN $TICKER_23 WHEN 24 THEN $TICKER_24
            WHEN 25 THEN $TICKER_25 WHEN 26 THEN 'SYM_26.EXCH' WHEN 27 THEN 'SYM_27.EXCH' WHEN 28 THEN 'SYM_28.EXCH'
            WHEN 29 THEN 'SYM_29.EXCH' WHEN 30 THEN 'SYM_30.EXCH' WHEN 31 THEN 'SYM_31.EXCH' WHEN 32 THEN 'SYM_32.EXCH'
            WHEN 33 THEN 'SYM_33.EXCH' WHEN 34 THEN 'SYM_34.EXCH' WHEN 35 THEN 'SYM_35.EXCH' WHEN 36 THEN 'SYM_36.EXCH'
            WHEN 37 THEN 'SYM_37.EXCH' WHEN 38 THEN 'SYM_38.EXCH' WHEN 39 THEN 'SYM_39.EXCH' ELSE 'SYM_40.EXCH'
        END
    END AS security_symbol,
    CASE UNIFORM(1, 200, RANDOM())
        WHEN 200 THEN NULL
        ELSE 'PART_' || LPAD(UNIFORM(1000, 9999, RANDOM()), 4, '0')
    END AS participant_id,
    'PART_' || LPAD(UNIFORM(1000, 9999, RANDOM()), 4, '0') AS counterparty_id,
    CASE UNIFORM(1, 500, RANDOM())
        WHEN 499 THEN -UNIFORM(100, 1000, RANDOM())
        WHEN 500 THEN 0
        ELSE UNIFORM(100, 500000, RANDOM())
    END AS quantity,
    CASE UNIFORM(1, 1000, RANDOM())
        WHEN 999 THEN 0
        WHEN 1000 THEN -UNIFORM(10, 100, RANDOM())
        ELSE UNIFORM(5, 2000, RANDOM()) + (UNIFORM(0, 99, RANDOM()) / 100.0)
    END AS price,
    CASE UNIFORM(1, 125, RANDOM())
        WHEN 124 THEN quantity * price * 1.02
        WHEN 125 THEN quantity * price * 0.98
        ELSE quantity * price
    END AS settlement_amount,
    CASE UNIFORM(1, 10, RANDOM())
        WHEN 1 THEN 'SETTLED' WHEN 2 THEN 'SETTLED' WHEN 3 THEN 'SETTLED' WHEN 4 THEN 'SETTLED'
        WHEN 5 THEN 'SETTLED' WHEN 6 THEN 'SETTLED' WHEN 7 THEN 'SETTLED' WHEN 8 THEN 'SETTLED'
        WHEN 9 THEN 'PENDING' ELSE 'FAILED'
    END AS settlement_status,
    'CAD' AS currency,
    CURRENT_TIMESTAMP() AS created_timestamp,
    'TRADING_SYS' AS source_system,
    'BATCH_' || TO_CHAR(CURRENT_DATE(), 'YYYYMMDD') AS batch_id,
    HASH(transaction_id, trade_date, security_symbol, participant_id) AS row_hash
FROM TABLE(GENERATOR(ROWCOUNT => 5129375));

INSERT INTO SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.SECURITIES_MASTER VALUES
    (
        'SEC_001',
        $TICKER_1,
        $COMPANY_1,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'FINANCIALS',
        185000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_002',
        $TICKER_2,
        $COMPANY_2,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'TECHNOLOGY',
        80000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_003',
        $TICKER_3,
        $COMPANY_3,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'TRANSPORTATION',
        95000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_004',
        $TICKER_4,
        $COMPANY_4,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'FINANCIALS',
        165000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_005',
        $TICKER_5,
        $COMPANY_5,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'MATERIALS',
        35000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_006',
        $TICKER_6,
        $COMPANY_6,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'TECHNOLOGY',
        72000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_007',
        $TICKER_7,
        $COMPANY_7,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'CONSUMER_STAPLES',
        52000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_008',
        $TICKER_8,
        $COMPANY_8,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'UTILITIES',
        38000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_009',
        $TICKER_9,
        $COMPANY_9,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'FINANCIALS',
        82000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_010',
        $TICKER_10,
        $COMPANY_10,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'TELECOMMUNICATIONS',
        44000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_011',
        $TICKER_11,
        $COMPANY_11,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'ENERGY',
        108000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_012',
        $TICKER_12,
        $COMPANY_12,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'TRANSPORTATION',
        78000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_013',
        $TICKER_13,
        $COMPANY_13,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'FINANCIALS',
        48000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_014',
        $TICKER_14,
        $COMPANY_14,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'FINANCIALS',
        42000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_015',
        $TICKER_15,
        $COMPANY_15,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'FINANCIALS',
        58000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_016',
        $TICKER_16,
        $COMPANY_16,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'FINANCIALS',
        68000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_017',
        $TICKER_17,
        $COMPANY_17,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'FINANCIALS',
        78000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_018',
        $TICKER_18,
        $COMPANY_18,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'CONSUMER_DISCRETIONARY',
        28000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_019',
        $TICKER_19,
        $COMPANY_19,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'MATERIALS',
        32000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_020',
        $TICKER_20,
        $COMPANY_20,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'TECHNOLOGY',
        28000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_021',
        $TICKER_21,
        $COMPANY_21,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'HEALTHCARE',
        2000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_022',
        $TICKER_22,
        $COMPANY_22,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'TRANSPORTATION',
        8000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_023',
        $TICKER_23,
        $COMPANY_23,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'TECHNOLOGY',
        3000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_024',
        $TICKER_24,
        $COMPANY_24,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'ENERGY',
        22000000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    ),
    (
        'SEC_025',
        $TICKER_25,
        $COMPANY_25,
        'COMMON_STOCK',
        $EXCHANGE_NAME,
        'CAD',
        'REAL_ESTATE',
        3500000000,
        CURRENT_DATE(),
        'ACTIVE',
        CURRENT_TIMESTAMP()
    );

INSERT INTO SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.PARTICIPANTS
SELECT 
    'PART_' || LPAD(SEQ4(), 4, '0') AS participant_id,
    CASE UNIFORM(1, 50, RANDOM())
        WHEN 1 THEN 'Alpha Securities Corp.' WHEN 2 THEN 'Beta Dominion Capital'
        WHEN 3 THEN 'Gamma Institutional Bank' WHEN 4 THEN 'Delta Global Markets'
        WHEN 5 THEN 'Epsilon Clearing House' WHEN 6 THEN 'Zeta Financial Advisors'
        WHEN 7 THEN 'Theta Brokerage' WHEN 8 THEN 'Iota Custodial Services'
        WHEN 9 THEN 'Kappa Fund Management' WHEN 10 THEN 'Lambda Asset Group'
        WHEN 11 THEN 'Mu Investment Solutions' WHEN 12 THEN 'Nu Life Insurance Group'
        WHEN 13 THEN 'Xi ETF Issuer' WHEN 14 THEN 'Omicron Portfolio Management'
        WHEN 15 THEN 'Pi Asset Management Ltd.' WHEN 16 THEN 'Rho Wealth Services'
        WHEN 17 THEN 'Sigma Trust Company' WHEN 18 THEN 'Tau Fund Advisors'
        WHEN 19 THEN 'Upsilon Capital Inc.' WHEN 20 THEN 'Phi Global Funds'
        ELSE 'Financial Institution ' || UNIFORM(1, 10000, RANDOM())
    END AS participant_name,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'DEALER' WHEN 2 THEN 'CUSTODIAN' WHEN 3 THEN 'BANK' ELSE 'INSTITUTIONAL'
    END AS participant_type,
    'REG_' || LPAD(UNIFORM(100000, 999999, RANDOM()), 6, '0') AS registration_number,
    CASE UNIFORM(1, 8, RANDOM())
        WHEN 1 THEN '100 Main Street' WHEN 2 THEN '200 Central Avenue'
        WHEN 3 THEN '1 Commerce Tower' WHEN 4 THEN '181 Financial Blvd'
        ELSE '199 Exchange Road'
    END AS address,
    CASE UNIFORM(1, 6, RANDOM())
        WHEN 1 THEN 'Metropolis' WHEN 2 THEN 'Coastal City' WHEN 3 THEN 'Mountain Town' 
        WHEN 4 THEN 'Prairie Hub' WHEN 5 THEN 'Capital Heights' ELSE 'River City'
    END AS city,
    CASE 
        WHEN city = 'Metropolis' THEN 'ST' WHEN city = 'Coastal City' THEN 'WS'
        WHEN city = 'Mountain Town' THEN 'MT' WHEN city = 'Prairie Hub' THEN 'PR'
        WHEN city = 'Capital Heights' THEN 'CH' ELSE 'RV'
    END AS province,
    CASE 
        WHEN city = 'Metropolis' THEN '10001' WHEN city = 'Coastal City' THEN '20002'
        WHEN city = 'Mountain Town' THEN '30003' WHEN city = 'Prairie Hub' THEN '40004'
        WHEN city = 'Capital Heights' THEN '50005' ELSE '60006'
    END AS postal_code,
    CASE UNIFORM(1, 20, RANDOM())
        WHEN 20 THEN 'INACTIVE'
        ELSE 'ACTIVE'
    END AS status,
    DATEADD(YEAR, -UNIFORM(1, 30, RANDOM()), CURRENT_DATE()) AS registration_date,
    CURRENT_TIMESTAMP() AS last_verified
FROM TABLE(GENERATOR(ROWCOUNT => 2847));

INSERT INTO SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.TRANSACTION_FEES
SELECT 
    UUID_STRING() AS fee_id,
    (SELECT transaction_id FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.SETTLEMENT_TRANSACTIONS SAMPLE(0.37) LIMIT 1) AS transaction_id,
    CASE UNIFORM(1, 8, RANDOM())
        WHEN 1 THEN 'SETTLEMENT_FEE' WHEN 2 THEN 'CLEARING_FEE' WHEN 3 THEN 'CUSTODY_FEE'
        WHEN 4 THEN 'TRANSFER_FEE' WHEN 5 THEN 'REGULATORY_FEE' WHEN 6 THEN 'EXCHANGE_FEE'
        WHEN 7 THEN 'PROCESSING_FEE' ELSE 'SERVICE_FEE'
    END AS fee_type,
    UNIFORM(0.25, 75.00, RANDOM()) AS fee_amount,
    'CAD' AS currency,
    DATEADD(DAY, -UNIFORM(0, 180, RANDOM()), CURRENT_DATE()) AS fee_date,
    CURRENT_TIMESTAMP() AS created_timestamp
FROM TABLE(GENERATOR(ROWCOUNT => 1891256));

INSERT INTO SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.MARKET_DATA
SELECT 
    CASE UNIFORM(1, 25, RANDOM())
        WHEN 1 THEN $TICKER_1 WHEN 2 THEN $TICKER_2 WHEN 3 THEN $TICKER_3 WHEN 4 THEN $TICKER_4
        WHEN 5 THEN $TICKER_5 WHEN 6 THEN $TICKER_6 WHEN 7 THEN $TICKER_7 WHEN 8 THEN $TICKER_8
        WHEN 9 THEN $TICKER_9 WHEN 10 THEN $TICKER_10 WHEN 11 THEN $TICKER_11 WHEN 12 THEN $TICKER_12
        WHEN 13 THEN $TICKER_13 WHEN 14 THEN $TICKER_14 WHEN 15 THEN $TICKER_15 WHEN 16 THEN $TICKER_16
        WHEN 17 THEN $TICKER_17 WHEN 18 THEN $TICKER_18 WHEN 19 THEN $TICKER_19 WHEN 20 THEN $TICKER_20
        WHEN 21 THEN $TICKER_21 WHEN 22 THEN $TICKER_22 WHEN 23 THEN $TICKER_23 WHEN 24 THEN $TICKER_24
        ELSE $TICKER_25
    END AS symbol,
    DATEADD(DAY, -UNIFORM(0, 180, RANDOM()), CURRENT_DATE()) AS trade_date,
    UNIFORM(10, 500, RANDOM()) + (UNIFORM(0, 99, RANDOM()) / 100.0) AS open_price,
    open_price + UNIFORM(-10, 10, RANDOM()) + (UNIFORM(0, 99, RANDOM()) / 100.0) AS close_price,
    GREATEST(open_price, close_price) + UNIFORM(0, 5, RANDOM()) AS high_price,
    LEAST(open_price, close_price) - UNIFORM(0, 5, RANDOM()) AS low_price,
    UNIFORM(10000, 5000000, RANDOM()) AS volume,
    CURRENT_TIMESTAMP() AS created_timestamp
FROM TABLE(GENERATOR(ROWCOUNT => 15738));

/*************************************************************************************************/
-- SECTION 4: Data Quality Layer - Dynamic Tables
/*************************************************************************************************/

CREATE OR REPLACE DYNAMIC TABLE SF_SOLUTIONS.CLEARING_SETTLEMENT_DQ.SETTLEMENT_QUALITY_METRICS
TARGET_LAG = '1 minute'
WAREHOUSE = SF_SOLUTIONS_ETL_WH
AS
SELECT 
    CURRENT_DATE() as quality_date,
    COUNT(*) as total_records,
    COUNT(*) - SUM(CASE WHEN security_symbol IS NULL OR security_symbol = '' THEN 1 ELSE 0 END) as valid_symbols,
    COUNT(*) - SUM(CASE WHEN participant_id IS NULL THEN 1 ELSE 0 END) as valid_participants,
    ROUND((COUNT(*) - SUM(CASE WHEN security_symbol IS NULL OR security_symbol = '' THEN 1 ELSE 0 END)) / COUNT(*) * 100,
    4) as symbol_completeness_pct,
    ROUND((COUNT(*) - SUM(CASE WHEN participant_id IS NULL THEN 1 ELSE 0 END)) / COUNT(*) * 100, 4) as participant_completeness_pct,
    SUM(CASE WHEN quantity > 0 THEN 1 ELSE 0 END) as valid_quantities,
    SUM(CASE WHEN price > 0 THEN 1 ELSE 0 END) as valid_prices,
    ROUND(SUM(CASE WHEN quantity > 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) as quantity_validity_pct,
    ROUND(SUM(CASE WHEN price > 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) as price_validity_pct,
    SUM(CASE WHEN DATEDIFF(day, trade_date, settlement_date) BETWEEN 1 AND 5 THEN 1 ELSE 0 END) as valid_settlement_cycles,
    SUM(CASE WHEN settlement_amount BETWEEN 100 AND 100000000 THEN 1 ELSE 0 END) as reasonable_amounts,
    ROUND((
        (SUM(CASE WHEN security_symbol IS NOT NULL AND security_symbol != '' THEN 1 ELSE 0 END) * 0.2) +
        (SUM(CASE WHEN participant_id IS NOT NULL THEN 1 ELSE 0 END) * 0.2) +
        (SUM(CASE WHEN quantity > 0 THEN 1 ELSE 0 END) * 0.2) +
        (SUM(CASE WHEN price > 0 THEN 1 ELSE 0 END) * 0.2) +
        (SUM(CASE WHEN ABS(settlement_amount - (quantity * price)) <= (quantity * price * 0.02) THEN 1 ELSE 0 END) * 0.2)
    ) / COUNT(*) * 100, 4) as overall_quality_score,
    ROUND(SUM(CASE WHEN security_symbol IS NULL OR security_symbol LIKE '%INVALID%' THEN 1 ELSE 0 END) / COUNT(*) * 100,
    4) as symbol_error_rate_pct,
    ROUND(SUM(CASE WHEN participant_id IS NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) as participant_error_rate_pct,
    ROUND(SUM(CASE WHEN quantity <= 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) as quantity_error_rate_pct,
    ROUND(SUM(CASE WHEN price <= 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) as price_error_rate_pct,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_LTZ(6)) as metrics_updated
FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.SETTLEMENT_TRANSACTIONS
WHERE created_timestamp >= DATEADD(hour, -24, CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_LTZ(6)));

CREATE OR REPLACE DYNAMIC TABLE SF_SOLUTIONS.CLEARING_SETTLEMENT_DQ.SETTLEMENT_TRANSACTIONS_CLEANSED
TARGET_LAG = '3 minutes'
WAREHOUSE = SF_SOLUTIONS_ETL_WH
AS
SELECT 
    transaction_id,
    trade_date,
    settlement_date,
    CASE 
        WHEN security_symbol IS NULL OR security_symbol = '' THEN 'UNKNOWN_SECURITY'
        WHEN security_symbol LIKE '%INVALID%'
            OR security_symbol LIKE '%CORRUPT%'
            OR security_symbol LIKE '%UNKNOWN%' THEN 'INVALID_SECURITY'
        ELSE security_symbol
    END as security_symbol_cleansed,
    COALESCE(participant_id, 'UNKNOWN_PARTICIPANT') as participant_id_cleansed,
    counterparty_id,
    CASE WHEN quantity <= 0 THEN NULL ELSE quantity END as quantity_cleansed,
    CASE WHEN price <= 0 THEN NULL ELSE price END as price_cleansed,
    CASE 
        WHEN quantity > 0 AND price > 0 THEN quantity * price
        ELSE settlement_amount
    END as settlement_amount_corrected,
    CASE 
        WHEN quantity > 0 AND price > 0 AND ABS(settlement_amount - (quantity * price)) > (quantity * price * 0.02) THEN TRUE
        ELSE FALSE
    END as amount_corrected,
    settlement_status,
    currency,
    CASE 
        WHEN security_symbol IS NULL
            OR security_symbol = ''
            OR security_symbol LIKE '%INVALID%'
            OR security_symbol LIKE '%CORRUPT%'
            OR security_symbol LIKE '%UNKNOWN%' THEN TRUE
        ELSE FALSE
    END as symbol_issue_flag,
    CASE WHEN participant_id IS NULL THEN TRUE ELSE FALSE END as participant_issue_flag,
    CASE WHEN quantity <= 0 OR price <= 0 THEN TRUE ELSE FALSE END as value_issue_flag,
    CASE 
        WHEN (
            security_symbol IS NULL
            OR security_symbol = ''
            OR security_symbol LIKE '%INVALID%'
            OR security_symbol LIKE '%CORRUPT%'
            OR security_symbol LIKE '%UNKNOWN%'
        )
            OR participant_id IS NULL
            OR quantity <= 0
            OR price <= 0 THEN 'POOR'
        WHEN quantity > 0 AND price > 0 AND ABS(settlement_amount - (quantity * price)) > (quantity * price * 0.02) THEN 'FAIR'
        ELSE 'GOOD'
    END as record_quality_rating,
    CASE 
        WHEN (
            security_symbol IS NULL
            OR security_symbol = ''
            OR security_symbol LIKE '%INVALID%'
            OR security_symbol LIKE '%CORRUPT%'
            OR security_symbol LIKE '%UNKNOWN%'
        )
            OR participant_id IS NULL
            OR quantity <= 0
            OR price <= 0 THEN 25
        WHEN quantity > 0 AND price > 0 AND ABS(settlement_amount - (quantity * price)) > (quantity * price * 0.02) THEN 75
        ELSE 100
    END as quality_score,
    created_timestamp,
    batch_id,
    row_hash,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_LTZ(6)) as cleansed_timestamp
FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.SETTLEMENT_TRANSACTIONS;

/*************************************************************************************************/
-- SECTION 5: Normalized Layer - Dynamic Tables
/*************************************************************************************************/

CREATE OR REPLACE DYNAMIC TABLE SF_SOLUTIONS.CLEARING_SETTLEMENT_NORMALIZED.SETTLEMENT_VALIDATION
TARGET_LAG = '3 minutes'
WAREHOUSE = SF_SOLUTIONS_ETL_WH
AS
SELECT 
    st.transaction_id,
    st.trade_date,
    st.settlement_date,
    st.security_symbol_cleansed as security_symbol,
    st.participant_id_cleansed as participant_id,
    st.counterparty_id,
    st.quantity_cleansed as quantity,
    st.price_cleansed as price,
    st.settlement_amount_corrected as settlement_amount,
    st.settlement_status,
    st.currency,
    DATEDIFF(day, st.trade_date, st.settlement_date) as settlement_cycle_days,
    CASE WHEN DATEDIFF(day, st.trade_date, st.settlement_date) = 2 THEN TRUE ELSE FALSE END as is_standard_t2_settlement,
    CASE WHEN st.record_quality_rating = 'GOOD' THEN TRUE ELSE FALSE END as passes_quality_check,
    CASE WHEN st.settlement_amount_corrected BETWEEN 100 AND 100000000 THEN TRUE ELSE FALSE END as reasonable_amount,
    CASE WHEN DATEDIFF(day, st.trade_date, st.settlement_date) BETWEEN 1 AND 5 THEN TRUE ELSE FALSE END as valid_settlement_cycle,
    (
        CASE WHEN st.record_quality_rating = 'GOOD' THEN 30 ELSE 0 END +
        CASE WHEN DATEDIFF(day, st.trade_date, st.settlement_date) BETWEEN 1 AND 5 THEN 25 ELSE 0 END +
        CASE WHEN st.settlement_amount_corrected BETWEEN 100 AND 100000000 THEN 25 ELSE 0 END +
        CASE WHEN st.security_symbol_cleansed NOT LIKE '%UNKNOWN%' AND st.security_symbol_cleansed NOT LIKE '%INVALID%' THEN 20 ELSE 0 END
    ) as validation_score,
    CASE WHEN st.settlement_amount_corrected > 10000000 THEN TRUE ELSE FALSE END as high_value_transaction,
    CASE WHEN st.settlement_status IN ('FAILED', 'PARTIAL') THEN TRUE ELSE FALSE END as settlement_risk_flag,
    st.quality_score,
    st.created_timestamp,
    st.batch_id,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_LTZ(6)) as validation_processed_timestamp
FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_DQ.SETTLEMENT_TRANSACTIONS_CLEANSED st
WHERE st.record_quality_rating IN ('GOOD', 'FAIR');

CREATE OR REPLACE DYNAMIC TABLE SF_SOLUTIONS.CLEARING_SETTLEMENT_NORMALIZED.REFERENCE_ENRICHMENT
TARGET_LAG = '3 minutes'
WAREHOUSE = SF_SOLUTIONS_ETL_WH
AS
SELECT 
    sv.*,
    COALESCE(sm.security_name, 'Unknown Security') as security_name,
    COALESCE(sm.security_type, 'UNKNOWN') as security_type,
    COALESCE(sm.sector, 'UNKNOWN') as sector,
    COALESCE(sm.market_cap, 0) as market_cap,
    COALESCE(sm.exchange, 'UNKNOWN') as exchange,
    COALESCE(sm.status, 'UNKNOWN') as security_status,
    COALESCE(p.participant_name, 'Unknown Participant') as participant_name,
    COALESCE(p.participant_type, 'UNKNOWN') as participant_type,
    COALESCE(p.city, 'Unknown') as participant_city,
    COALESCE(p.province, 'Unknown') as participant_province,
    COALESCE(p.status, 'UNKNOWN') as participant_status,
    COALESCE(cp.participant_name, 'Unknown Counterparty') as counterparty_name,
    COALESCE(cp.participant_type, 'UNKNOWN') as counterparty_type,
    COALESCE(cp.city, 'Unknown') as counterparty_city,
    CASE 
        WHEN sm.market_cap > 50000000000 THEN 'MEGA_CAP'
        WHEN sm.market_cap > 10000000000 THEN 'LARGE_CAP'
        WHEN sm.market_cap > 2000000000 THEN 'MID_CAP'
        WHEN sm.market_cap > 300000000 THEN 'SMALL_CAP'
        WHEN sm.market_cap > 0 THEN 'MICRO_CAP'
        ELSE 'UNKNOWN_CAP'
    END as market_cap_category,
    CASE 
        WHEN sm.sector IN ('FINANCIALS', 'ENERGY', 'MATERIALS') THEN 'HIGH_VOLATILITY'
        WHEN sm.sector IN ('UTILITIES', 'CONSUMER_STAPLES', 'TELECOMMUNICATIONS') THEN 'LOW_VOLATILITY'
        WHEN sm.sector IN ('TECHNOLOGY', 'HEALTHCARE', 'CONSUMER_DISCRETIONARY') THEN 'MEDIUM_VOLATILITY'
        ELSE 'UNKNOWN_VOLATILITY'
    END as sector_volatility_class,
    CASE 
        WHEN sm.security_name IS NOT NULL AND p.participant_name IS NOT NULL AND cp.participant_name IS NOT NULL THEN 100
        WHEN sm.security_name IS NOT NULL AND p.participant_name IS NOT NULL THEN 85
        WHEN sm.security_name IS NOT NULL OR p.participant_name IS NOT NULL THEN 65
        ELSE 25
    END as enrichment_completeness_score,
    CASE WHEN sm.security_name IS NOT NULL THEN TRUE ELSE FALSE END as security_data_available,
    CASE WHEN p.participant_name IS NOT NULL THEN TRUE ELSE FALSE END as participant_data_available,
    CASE WHEN cp.participant_name IS NOT NULL THEN TRUE ELSE FALSE END as counterparty_data_available,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_LTZ(6)) as enrichment_processed_timestamp
FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_NORMALIZED.SETTLEMENT_VALIDATION sv
LEFT JOIN SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.SECURITIES_MASTER sm ON sv.security_symbol = sm.symbol
LEFT JOIN SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.PARTICIPANTS p ON sv.participant_id = p.participant_id
LEFT JOIN SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.PARTICIPANTS cp ON sv.counterparty_id = cp.participant_id
WHERE sv.validation_score >= 50;

CREATE OR REPLACE DYNAMIC TABLE SF_SOLUTIONS.CLEARING_SETTLEMENT_NORMALIZED.BUSINESS_RULES_ENGINE
TARGET_LAG = '4 minutes'
WAREHOUSE = SF_SOLUTIONS_ETL_WH
AS
SELECT 
    re.*,
    CASE 
        WHEN re.security_type = 'COMMON_STOCK' AND re.participant_type = 'BANK' THEN 0.3
        WHEN re.security_type = 'COMMON_STOCK' AND re.participant_type = 'DEALER' THEN 0.5
        WHEN re.security_type = 'COMMON_STOCK' AND re.participant_type = 'INSTITUTIONAL' THEN 0.7
        WHEN re.security_type = 'COMMON_STOCK' AND re.participant_type = 'CUSTODIAN' THEN 0.4
        WHEN re.security_type = 'COMMON_STOCK' THEN 1.0
        ELSE 1.5
    END as base_risk_weight,
    CASE 
        WHEN re.market_cap_category = 'MEGA_CAP' THEN 0.7
        WHEN re.market_cap_category = 'LARGE_CAP' THEN 0.8
        WHEN re.market_cap_category = 'MID_CAP' THEN 1.0
        WHEN re.market_cap_category = 'SMALL_CAP' THEN 1.3
        WHEN re.market_cap_category = 'MICRO_CAP' THEN 1.6
        ELSE 2.0
    END as market_cap_risk_multiplier,
    CASE 
        WHEN re.settlement_status = 'SETTLED' THEN 1.0
        WHEN re.settlement_status = 'PENDING' THEN 1.2
        WHEN re.settlement_status = 'PARTIAL' THEN 1.5
        WHEN re.settlement_status = 'FAILED' THEN 2.5
        ELSE 2.0
    END as status_risk_multiplier,
    CASE 
        WHEN re.sector_volatility_class = 'LOW_VOLATILITY' THEN 0.8
        WHEN re.sector_volatility_class = 'MEDIUM_VOLATILITY' THEN 1.0
        WHEN re.sector_volatility_class = 'HIGH_VOLATILITY' THEN 1.4
        ELSE 1.2
    END as sector_volatility_multiplier,
    CASE 
        WHEN re.is_standard_t2_settlement THEN 1.0
        WHEN re.settlement_cycle_days = 1 THEN 1.1
        WHEN re.settlement_cycle_days >= 3 THEN 1.3
        ELSE 1.5
    END as settlement_cycle_risk_multiplier,
    (
        CASE 
            WHEN re.security_type = 'COMMON_STOCK' AND re.participant_type = 'BANK' THEN 0.3
            WHEN re.security_type = 'COMMON_STOCK' AND re.participant_type = 'DEALER' THEN 0.5
            WHEN re.security_type = 'COMMON_STOCK' AND re.participant_type = 'INSTITUTIONAL' THEN 0.7
            WHEN re.security_type = 'COMMON_STOCK' AND re.participant_type = 'CUSTODIAN' THEN 0.4
            ELSE 1.0
        END *
        CASE 
            WHEN re.market_cap_category = 'MEGA_CAP' THEN 0.7
            WHEN re.market_cap_category = 'LARGE_CAP' THEN 0.8
            WHEN re.market_cap_category = 'MID_CAP' THEN 1.0
            WHEN re.market_cap_category = 'SMALL_CAP' THEN 1.3
            ELSE 1.6
        END *
        CASE 
            WHEN re.settlement_status = 'SETTLED' THEN 1.0
            WHEN re.settlement_status = 'PENDING' THEN 1.2
            WHEN re.settlement_status = 'PARTIAL' THEN 1.5
            ELSE 2.0
        END *
        CASE 
            WHEN re.sector_volatility_class = 'LOW_VOLATILITY' THEN 0.8
            WHEN re.sector_volatility_class = 'MEDIUM_VOLATILITY' THEN 1.0
            ELSE 1.3
        END *
        CASE 
            WHEN re.is_standard_t2_settlement THEN 1.0
            WHEN re.settlement_cycle_days = 1 THEN 1.1
            ELSE 1.3
        END
    ) as final_risk_score,
    re.settlement_amount * (
        CASE 
            WHEN re.security_type = 'COMMON_STOCK' AND re.participant_type = 'BANK' THEN 0.3
            ELSE 1.0
        END *
        CASE 
            WHEN re.market_cap_category = 'MEGA_CAP' THEN 0.7
            ELSE 1.3
        END *
        CASE 
            WHEN re.settlement_status = 'SETTLED' THEN 1.0
            ELSE 1.5
        END
    ) as risk_weighted_exposure,
    CASE 
        WHEN (
            CASE WHEN re.security_type = 'COMMON_STOCK' AND re.participant_type = 'BANK' THEN 0.3 ELSE 1.0 END *
            CASE WHEN re.market_cap_category = 'MEGA_CAP' THEN 0.7 ELSE 1.3 END *
            CASE WHEN re.settlement_status = 'SETTLED' THEN 1.0 ELSE 1.5 END
        ) >= 2.0 THEN 'HIGH_RISK'
        WHEN (
            CASE WHEN re.security_type = 'COMMON_STOCK' AND re.participant_type = 'BANK' THEN 0.3 ELSE 1.0 END *
            CASE WHEN re.market_cap_category = 'MEGA_CAP' THEN 0.7 ELSE 1.3 END *
            CASE WHEN re.settlement_status = 'SETTLED' THEN 1.0 ELSE 1.5 END
        ) >= 1.0 THEN 'MEDIUM_RISK'
        ELSE 'LOW_RISK'
    END as risk_tier,
    ROUND((re.validation_score * 0.4 + re.enrichment_completeness_score * 0.3 + 
           (100 - LEAST(100, (
        CASE WHEN re.security_type = 'COMMON_STOCK' AND re.participant_type = 'BANK' THEN 0.3 ELSE 1.0 END *
        CASE WHEN re.market_cap_category = 'MEGA_CAP' THEN 0.7 ELSE 1.3 END *
        CASE WHEN re.settlement_status = 'SETTLED' THEN 1.0 ELSE 1.5 END
    ) * 20)) * 0.3), 2) as overall_processing_score,
    CASE 
        WHEN re.settlement_amount > 50000000 THEN 'REGULATORY_REPORTING_REQUIRED'
        WHEN re.settlement_amount > 10000000 THEN 'ENHANCED_MONITORING'
        ELSE 'STANDARD_PROCESSING'
    END as regulatory_classification,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_LTZ(6)) as business_rules_processed_timestamp
FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_NORMALIZED.REFERENCE_ENRICHMENT re
WHERE re.enrichment_completeness_score >= 50;

/*************************************************************************************************/
-- SECTION 6: Consumption Layer - Dynamic Tables
/*************************************************************************************************/

USE WAREHOUSE SF_SOLUTIONS_ANALYTICS_WH;

CREATE OR REPLACE DYNAMIC TABLE SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION.ENTERPRISE_PARTICIPANT_RISK_MONITOR
TARGET_LAG = 'DOWNSTREAM'
WAREHOUSE = SF_SOLUTIONS_ANALYTICS_WH
AS
SELECT 
    bre.participant_id,
    MAX(bre.participant_name) as participant_name,
    MAX(bre.participant_type) as participant_type,
    MAX(bre.participant_city) as participant_city,
    COUNT(*) as total_transactions,
    SUM(bre.settlement_amount) as total_settlement_value,
    ROUND(SUM(bre.settlement_amount) / 1000000000, 4) as settlement_value_billions,
    AVG(bre.settlement_amount) as avg_transaction_size,
    AVG(bre.final_risk_score) as avg_risk_score,
    MAX(bre.final_risk_score) as max_risk_score,
    SUM(bre.risk_weighted_exposure) as total_risk_exposure,
    ROUND(SUM(bre.risk_weighted_exposure) / 1000000000, 4) as risk_exposure_billions,
    SUM(CASE WHEN bre.risk_tier = 'HIGH_RISK' THEN 1 ELSE 0 END) as high_risk_transactions,
    SUM(CASE WHEN bre.risk_tier = 'MEDIUM_RISK' THEN 1 ELSE 0 END) as medium_risk_transactions,
    SUM(CASE WHEN bre.risk_tier = 'LOW_RISK' THEN 1 ELSE 0 END) as low_risk_transactions,
    ROUND(SUM(CASE WHEN bre.risk_tier = 'HIGH_RISK' THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) as high_risk_pct,
    ROUND(SUM(CASE WHEN bre.settlement_status = 'SETTLED' THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) as settlement_success_rate,
    ROUND(SUM(CASE WHEN bre.is_standard_t2_settlement THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) as t2_compliance_rate,
    SUM(CASE WHEN bre.settlement_status IN ('PENDING', 'PARTIAL') THEN bre.settlement_amount ELSE 0 END) as current_exposure,
    SUM(CASE WHEN bre.settlement_status IN ('PENDING', 'PARTIAL') THEN bre.risk_weighted_exposure ELSE 0 END) as current_risk_exposure,
    SUM(CASE WHEN bre.regulatory_classification = 'REGULATORY_REPORTING_REQUIRED' THEN 1 ELSE 0 END) as regulatory_transactions,
    SUM(CASE WHEN bre.high_value_transaction THEN 1 ELSE 0 END) as high_value_count,
    AVG(bre.overall_processing_score) as avg_processing_score,
    AVG(bre.validation_score) as avg_validation_score,
    AVG(bre.enrichment_completeness_score) as avg_enrichment_score,
    CASE 
        WHEN SUM(CASE WHEN bre.settlement_status IN ('PENDING',
        'PARTIAL') THEN bre.risk_weighted_exposure ELSE 0 END) > 100000000 THEN 'CRITICAL_EXPOSURE'
        WHEN SUM(CASE WHEN bre.settlement_status = 'FAILED' THEN 1 ELSE 0 END) > 50 THEN 'HIGH_FAILURE_RATE'
        WHEN ROUND(SUM(CASE WHEN bre.settlement_status = 'SETTLED' THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) < 95 THEN 'LOW_SUCCESS_RATE'
        WHEN AVG(bre.final_risk_score) > 2.0 THEN 'HIGH_AVG_RISK'
        ELSE 'NORMAL'
    END as enterprise_alert_status,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_LTZ(6)) as monitor_updated
FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_NORMALIZED.BUSINESS_RULES_ENGINE bre
WHERE bre.business_rules_processed_timestamp >= DATEADD(hour, -24, CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_LTZ(6)))
GROUP BY bre.participant_id;

CREATE OR REPLACE DYNAMIC TABLE SF_SOLUTIONS.CLEARING_SETTLEMENT_CONSUMPTION.ENTERPRISE_DAILY_DASHBOARD
TARGET_LAG = '5 minutes'
WAREHOUSE = SF_SOLUTIONS_ANALYTICS_WH
AS
SELECT 
    bre.settlement_date,
    COUNT(*) as total_transactions,
    SUM(bre.settlement_amount) as total_settlement_value,
    ROUND(SUM(bre.settlement_amount) / 1000000000, 4) as settlement_value_billions,
    AVG(bre.settlement_amount) as avg_transaction_size,
    ROUND(SUM(CASE WHEN bre.settlement_status = 'SETTLED' THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) as settlement_success_rate,
    ROUND(SUM(CASE WHEN bre.is_standard_t2_settlement THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) as t2_compliance_rate,
    ROUND(AVG(bre.settlement_cycle_days), 2) as avg_settlement_cycle_days,
    SUM(bre.risk_weighted_exposure) as total_risk_exposure,
    ROUND(SUM(bre.risk_weighted_exposure) / 1000000000, 4) as risk_exposure_billions,
    AVG(bre.final_risk_score) as avg_risk_score,
    SUM(CASE WHEN bre.risk_tier = 'HIGH_RISK' THEN 1 ELSE 0 END) as high_risk_count,
    SUM(CASE WHEN bre.risk_tier = 'MEDIUM_RISK' THEN 1 ELSE 0 END) as medium_risk_count,
    SUM(CASE WHEN bre.risk_tier = 'LOW_RISK' THEN 1 ELSE 0 END) as low_risk_count,
    COUNT(DISTINCT bre.participant_id) as unique_participants,
    COUNT(DISTINCT bre.security_symbol) as unique_securities,
    COUNT(DISTINCT bre.sector) as unique_sectors,
    SUM(CASE WHEN bre.regulatory_classification = 'REGULATORY_REPORTING_REQUIRED' THEN 1 ELSE 0 END) as regulatory_transactions,
    ROUND(SUM(CASE WHEN bre.regulatory_classification = 'REGULATORY_REPORTING_REQUIRED' THEN 1 ELSE 0 END) / COUNT(*) * 100,
    4) as regulatory_transaction_pct,
    AVG(bre.validation_score) as avg_validation_score,
    AVG(bre.enrichment_completeness_score) as avg_enrichment_score,
    AVG(bre.overall_processing_score) as avg_processing_score,
    CASE 
        WHEN ROUND(SUM(CASE WHEN bre.settlement_status = 'SETTLED' THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) >= 99.5 
             AND ROUND(SUM(CASE WHEN bre.is_standard_t2_settlement THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) >= 95 THEN 'EXCELLENT'
        WHEN ROUND(SUM(CASE WHEN bre.settlement_status = 'SETTLED' THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) >= 98 
             AND ROUND(SUM(CASE WHEN bre.is_standard_t2_settlement THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) >= 90 THEN 'GOOD'
        WHEN ROUND(SUM(CASE WHEN bre.settlement_status = 'SETTLED' THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) >= 95 THEN 'FAIR'
        ELSE 'NEEDS_ATTENTION'
    END as enterprise_performance_rating,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_LTZ(6)) as dashboard_updated
FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_NORMALIZED.BUSINESS_RULES_ENGINE bre
WHERE bre.settlement_date >= DATEADD(day, -90, CURRENT_DATE())
GROUP BY bre.settlement_date
ORDER BY bre.settlement_date DESC;

/*************************************************************************************************/
-- SECTION 7: Verification
/*************************************************************************************************/

SELECT 
    'Enterprise Clearing & Settlement Data Platform deployed successfully!' as STATUS,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.SETTLEMENT_TRANSACTIONS) as settlement_transactions,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.SECURITIES_MASTER) as securities_count,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.PARTICIPANTS) as participants_count,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.TRANSACTION_FEES) as transaction_fees,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.CLEARING_SETTLEMENT_RAW.MARKET_DATA) as market_data_records;
