/*************************************************************************************************/
-- SNOWCORE INDUSTRIES PREDICTIVE MAINTENANCE SETUP
-- Version: 1.0
--
-- PREREQUISITES:
-- This script requires ACCOUNTADMIN role or a role with the following privileges:
--   - CREATE DATABASE, SCHEMA, TABLE, VIEW
--   - CREATE WAREHOUSE
--   - CREATE COMPUTE POOL (for SPCS deployment)
--   - CREATE INTEGRATION (for external access and network rules)
--   - CREATE AGENT (for Snowflake Intelligence)
--   - BIND SERVICE ENDPOINT (account-level permission for SPCS)
--
-- WHAT THIS SCRIPT CREATES:
--   - Database: SF_SOLUTIONS with Bronze, Silver, Gold schemas
--   - Warehouses: SF_SOLUTIONS_WH, SF_SOLUTIONS_STREAMLIT_WH
--   - Compute Pool: SF_SOLUTIONS_STREAMLIT_POOL (for SPCS)
--   - External Access Integration: SF_SOLUTIONS_EAI (for PyPI & APIs)
--   - Sample data: ~160,000+ telemetry records, 12+ months of maintenance history
--   - Semantic View: For natural language queries via Cortex Analyst
--   - Intelligence Agent: PREDICTIVE_MAINTENANCE_ASSISTANT
/*************************************************************************************************/

USE ROLE ACCOUNTADMIN;

-- assign Query Tag to Session. This helps with performance monitoring and troubleshooting
ALTER SESSION SET query_tag = '{"origin":"sf_sit-is",'
    || '"name":"product analytics_snowcore_industries'
    || '_predictive_maintenance_dashboard",'
    || '"version":{"major":1,"minor":0},'
    || '"attributes":{"is_quickstart":1,"source":"sql"}}';

CREATE ROLE IF NOT EXISTS SF_SOLUTIONS_ROLE;

/*************************************************************************************************/
-- SF_SOLUTIONS PREDICTIVE MAINTENANCE DATABASE
-- Description: DDL and sample DML for the Bronze, Silver, and Gold layers.
/*************************************************************************************************/

-- Step 0: Setup Database and Schemas
CREATE OR REPLACE DATABASE SF_SOLUTIONS;


USE DATABASE SF_SOLUTIONS;
USE SCHEMA PUBLIC;

GRANT CREATE TABLE ON FUTURE SCHEMAS IN DATABASE SF_SOLUTIONS TO ROLE SF_SOLUTIONS_ROLE;
GRANT CREATE VIEW ON FUTURE SCHEMAS IN DATABASE SF_SOLUTIONS TO ROLE SF_SOLUTIONS_ROLE;
GRANT CREATE PROCEDURE ON FUTURE SCHEMAS IN DATABASE SF_SOLUTIONS TO ROLE SF_SOLUTIONS_ROLE;
GRANT CREATE FUNCTION ON FUTURE SCHEMAS IN DATABASE SF_SOLUTIONS TO ROLE SF_SOLUTIONS_ROLE;
GRANT CREATE SEQUENCE ON FUTURE SCHEMAS IN DATABASE SF_SOLUTIONS TO ROLE SF_SOLUTIONS_ROLE;
GRANT CREATE STREAMLIT ON FUTURE SCHEMAS IN DATABASE SF_SOLUTIONS TO ROLE SF_SOLUTIONS_ROLE;
GRANT CREATE SEMANTIC VIEW ON FUTURE SCHEMAS IN DATABASE SF_SOLUTIONS TO ROLE SF_SOLUTIONS_ROLE;
CREATE OR REPLACE SCHEMA BRONZE COMMENT = 'Schema for raw, unaltered source data';
CREATE OR REPLACE SCHEMA SILVER COMMENT = 'Schema for cleaned, conformed, and integrated data (Star Schema)';
CREATE OR REPLACE SCHEMA GOLD COMMENT = 'Schema for business-level aggregates and ML feature stores';

-- Create an event table if it doesn't already exist
CREATE or replace EVENT TABLE SF_SOLUTIONS.PUBLIC.SF_SOLUTIONS_EVENTS;
-- Associate the event table with the account
ALTER ACCOUNT SET EVENT_TABLE = SF_SOLUTIONS.PUBLIC.SF_SOLUTIONS_EVENTS;

-- Set the log level for the database containing your app
ALTER DATABASE SF_SOLUTIONS SET LOG_LEVEL = INFO;

-- Set the trace level for the database containing your app
ALTER DATABASE SF_SOLUTIONS SET TRACE_LEVEL = ON_EVENT;

GRANT CREATE STAGE ON ALL SCHEMAS IN DATABASE SF_SOLUTIONS TO ROLE SF_SOLUTIONS_ROLE;
GRANT CREATE STAGE ON FUTURE SCHEMAS IN DATABASE SF_SOLUTIONS TO ROLE SF_SOLUTIONS_ROLE;
GRANT CREATE STREAMLIT ON FUTURE SCHEMAS IN DATABASE SF_SOLUTIONS TO ROLE SF_SOLUTIONS_ROLE;
GRANT USAGE ON ALL STAGES IN DATABASE SF_SOLUTIONS TO ROLE SF_SOLUTIONS_ROLE;

-- Grants for the Snowflake Intelligence Roles
CREATE DATABASE IF NOT EXISTS snowflake_intelligence;
CREATE SCHEMA IF NOT EXISTS snowflake_intelligence.agents;
GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE SF_SOLUTIONS_ROLE;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE SF_SOLUTIONS_ROLE;
GRANT CREATE AGENT ON SCHEMA snowflake_intelligence.agents TO ROLE SF_SOLUTIONS_ROLE;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE SF_SOLUTIONS_ROLE;
GRANT CREATE AGENT ON ALL SCHEMAS IN DATABASE SF_SOLUTIONS TO ROLE SF_SOLUTIONS_ROLE;
GRANT CREATE AGENT ON FUTURE SCHEMAS IN DATABASE SF_SOLUTIONS TO ROLE SF_SOLUTIONS_ROLE;
GRANT CREATE AGENT ON SCHEMA SF_SOLUTIONS.GOLD TO ROLE SF_SOLUTIONS_ROLE;


GRANT SELECT ON ALL SEMANTIC VIEWS IN DATABASE SF_SOLUTIONS TO ROLE SF_SOLUTIONS_ROLE;
GRANT SELECT ON FUTURE SEMANTIC VIEWS IN DATABASE SF_SOLUTIONS TO ROLE SF_SOLUTIONS_ROLE;

GRANT ALL ON SCHEMA SF_SOLUTIONS.GOLD TO ROLE SF_SOLUTIONS_ROLE;

-- Create warehouses
CREATE WAREHOUSE IF NOT EXISTS SF_SOLUTIONS_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Default Warehouse';

GRANT USAGE ON WAREHOUSE sf_solutions_wh TO ROLE public;

-- Create warehouse for Streamlit apps
CREATE WAREHOUSE IF NOT EXISTS SF_SOLUTIONS_STREAMLIT_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse for Snowcore Streamlit applications';

-- Grant warehouse usage to roles
GRANT USAGE ON WAREHOUSE SF_SOLUTIONS_STREAMLIT_WH TO ROLE SF_SOLUTIONS_ROLE;

-- Grant the new role to user 
GRANT ROLE SF_SOLUTIONS_ROLE TO ROLE ACCOUNTADMIN;

/*************************************************************************************************/
-- SPCS INFRASTRUCTURE (Snowpark Container Services)
-- NOTE: The following resources require ACCOUNTADMIN role and appropriate privileges:
--   - CREATE COMPUTE POOL (requires ACCOUNTADMIN or role with CREATE COMPUTE POOL privilege)
--   - CREATE NETWORK RULE (requires ACCOUNTADMIN or role with CREATE INTEGRATION privilege)
--   - CREATE EXTERNAL ACCESS INTEGRATION (requires ACCOUNTADMIN or role with CREATE INTEGRATION privilege)
--   - GRANT BIND SERVICE ENDPOINT (requires ACCOUNTADMIN)
-- 
-- If you do not have these privileges in your Snowflake account, you will need to:
--   1. Request them from your Snowflake administrator, OR
--   2. Deploy the Streamlit app using warehouse-based runtime instead of SPCS
--      (omit RUNTIME_NAME and COMPUTE_POOL parameters when creating the Streamlit app)
/*************************************************************************************************/

-- Create a compute pool for running Streamlit apps on containers
CREATE COMPUTE POOL IF NOT EXISTS SF_SOLUTIONS_STREAMLIT_POOL
  MIN_NODES = 1
  MAX_NODES = 3
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = FALSE
  AUTO_SUSPEND_SECS = 3600
  COMMENT = 'Compute pool for Predictive Maintenance Streamlit app on SPCS';

-- Grant usage to the role
GRANT USAGE ON COMPUTE POOL SF_SOLUTIONS_STREAMLIT_POOL 
  TO ROLE SF_SOLUTIONS_ROLE;

-- Network rule for PyPI package installation
CREATE OR REPLACE NETWORK RULE SF_SOLUTIONS.GOLD.SF_SOLUTIONS_PYPI_NETWORK_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('pypi.org', 'pypi.python.org', 'pythonhosted.org', 'files.pythonhosted.org');

-- Network rule for Snowflake Cortex Analyst API
CREATE OR REPLACE NETWORK RULE SF_SOLUTIONS.GOLD.SF_SOLUTIONS_CORTEX_NETWORK_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('0.0.0.0:443', '0.0.0.0:80');

-- External access integration combining both rules
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION SF_SOLUTIONS_EAI
  ALLOWED_NETWORK_RULES = (
    SF_SOLUTIONS.GOLD.SF_SOLUTIONS_PYPI_NETWORK_RULE,
    SF_SOLUTIONS.GOLD.SF_SOLUTIONS_CORTEX_NETWORK_RULE
  )
  ENABLED = TRUE
  COMMENT = 'External access for PyPI packages and Cortex Analyst API with OAuth authentication';

-- Grant usage to the role
GRANT USAGE ON INTEGRATION SF_SOLUTIONS_EAI 
  TO ROLE SF_SOLUTIONS_ROLE;

-- Grant additional permissions needed for SPCS
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE SF_SOLUTIONS_ROLE;

/*************************************************************************************************/


USE ROLE SF_SOLUTIONS_ROLE;


---------------------------------------------------------------------------------------------------
-- ## BRONZE LAYER (Raw & Staging)
-- Tables in this layer use the VARIANT data type to land semi-structured JSON as-is.
---------------------------------------------------------------------------------------------------
USE SCHEMA SF_SOLUTIONS.BRONZE;

CREATE OR REPLACE TABLE RAW_IOT_TELEMETRY (
    RAW_PAYLOAD         VARIANT,
    SOURCE_TIMESTAMP    TIMESTAMP_NTZ,
    INGESTION_TIMESTAMP TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE RAW_MAINTENANCE_LOGS (
    LOG_DATA            VARIANT,
    SOURCE_FILENAME     VARCHAR,
    INGESTION_TIMESTAMP TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE RAW_EQUIPMENT_MASTER (
    EQUIPMENT_DATA      VARIANT,
    INGESTION_TIMESTAMP TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);


---------------------------------------------------------------------------------------------------
-- ## SILVER LAYER (Conformed & Integrated Star Schema)
-- This is the single source of truth, structured for analytics.
-- Rationalized to align with plant hierarchy and business impact modeling
---------------------------------------------------------------------------------------------------
USE SCHEMA SF_SOLUTIONS.SILVER;

-- Dimension Tables (The "Who, What, Where")

-- Date Dimension (Standard)
CREATE OR REPLACE TABLE DIM_DATE (
    DATE_SK         NUMBER(8) PRIMARY KEY, -- YYYYMMDD
    FULL_DATE       DATE NOT NULL,
    DAY_OF_WEEK     VARCHAR(10),
    MONTH_NAME      VARCHAR(10),
    QUARTER         NUMBER(1),
    YEAR            NUMBER(4)
);

-- Plant Dimension (Location Hierarchy Level 1)
CREATE OR REPLACE TABLE DIM_PLANT (
    PLANT_ID        NUMBER(10,0) PRIMARY KEY,
    PLANT_NAME      VARCHAR(100),
    LOCATION        VARCHAR(100),
    PLANT_UNS_NK    VARCHAR(100) -- UNS Natural Key (enterprise/site)
);

-- Production Line Dimension (Location Hierarchy Level 2)
CREATE OR REPLACE TABLE DIM_LINE (
    LINE_ID         NUMBER(10,0) PRIMARY KEY,
    PLANT_ID        NUMBER(10,0),
    LINE_NAME       VARCHAR(100),
    HOURLY_REVENUE  NUMBER(10,2), -- Used for calculating revenue loss
    LINE_UNS_NK     VARCHAR(150), -- UNS Natural Key (enterprise/site/line)
    FOREIGN KEY (PLANT_ID) REFERENCES DIM_PLANT(PLANT_ID)
);

-- Process Dimension (Manufacturing Process Level)
CREATE OR REPLACE TABLE DIM_PROCESS (
    PROCESS_ID       INTEGER AUTOINCREMENT START 1 INCREMENT 1 PRIMARY KEY,
    PROCESS_NK       VARCHAR(50) NOT NULL, -- Natural Key (Process Code)
    PROCESS_NAME     VARCHAR(100),
    PROCESS_TYPE     VARCHAR(50), -- e.g., 'Manufacturing', 'Assembly', 'Testing'
    LINE_ID          NUMBER(10,0),
    PROCESS_UNS_NK   VARCHAR(200), -- UNS Natural Key (enterprise/site/line/process)
    DESCRIPTION      VARCHAR(255),
    IS_ACTIVE        BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (LINE_ID) REFERENCES DIM_LINE(LINE_ID)
);

-- Asset Class Dimension (Asset Categorization)
CREATE OR REPLACE TABLE DIM_ASSET_CLASS (
    ASSET_CLASS_ID  NUMBER(10,0) PRIMARY KEY,
    CLASS_NAME      VARCHAR(100)
);

-- Asset Dimension (Central Dimension - replaces DIM_EQUIPMENT)
CREATE OR REPLACE TABLE DIM_ASSET (
    ASSET_ID                INTEGER AUTOINCREMENT START 1 INCREMENT 1 PRIMARY KEY,
    ASSET_NK                VARCHAR(50) NOT NULL, -- Natural Key (Serial Number)
    ASSET_NAME              VARCHAR(100),
    MODEL                   VARCHAR(50),
    OEM_NAME                VARCHAR(50),
    PROCESS_ID              INTEGER, -- Foreign Key to DIM_PROCESS
    PROCESS_SEQUENCE        INTEGER, -- Sequence within the process (1, 2, 3, etc.)
    ASSET_CLASS_ID          NUMBER(10,0),
    INSTALLATION_DATE       DATE,
    DOWNTIME_IMPACT_PER_HOUR NUMBER(12,2), -- Used for "Production at Risk" KPI
    ASSET_UNS_NK            VARCHAR(250), -- UNS Natural Key (enterprise/site/line/process/asset)
    -- For Slowly Changing Dimensions (Type 2)
    SCD_START_DATE          TIMESTAMP_NTZ NOT NULL,
    SCD_END_DATE            TIMESTAMP_NTZ,
    IS_CURRENT              BOOLEAN,
    FOREIGN KEY (PROCESS_ID) REFERENCES DIM_PROCESS(PROCESS_ID),
    FOREIGN KEY (ASSET_CLASS_ID) REFERENCES DIM_ASSET_CLASS(ASSET_CLASS_ID)
);

-- Work Order Type Dimension (Enhanced maintenance categorization)
CREATE OR REPLACE TABLE DIM_WORK_ORDER_TYPE (
    WO_TYPE_ID      NUMBER(10,0) PRIMARY KEY,
    WO_TYPE_NAME    VARCHAR(50), -- e.g., 'Unplanned Emergency', 'Planned Predictive', 'Planned Preventive'
    WO_TYPE_CODE    VARCHAR(10)
);

-- Sensor Dimension (Retained for detailed sensor tracking)
CREATE OR REPLACE TABLE DIM_SENSOR (
    SENSOR_SK       INTEGER AUTOINCREMENT START 1 INCREMENT 1 PRIMARY KEY,
    SENSOR_NK       VARCHAR(50) NOT NULL, -- Natural Key (Sensor UUID)
    ASSET_ID        INTEGER, -- Foreign Key to DIM_ASSET
    SENSOR_TYPE     VARCHAR(50),
    UNITS_OF_MEASURE VARCHAR(20),
    SENSOR_UNS_NK   VARCHAR(300), -- UNS Natural Key (enterprise/site/line/process/asset/sensor_type)
    FOREIGN KEY (ASSET_ID) REFERENCES DIM_ASSET(ASSET_ID)
);

-- Fact Tables (The "Measurements and Events")

-- Time-series sensor data and ML predictions (Consolidated telemetry)
CREATE OR REPLACE TABLE FCT_ASSET_TELEMETRY (
    TELEMETRY_ID        NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    ASSET_ID            INTEGER NOT NULL,
    PROCESS_ID          INTEGER, -- Foreign Key to DIM_PROCESS
    DATE_SK             NUMBER(8) NOT NULL,
    RECORDED_AT         TIMESTAMP_NTZ,
    TEMPERATURE_C       NUMBER(5,2),
    VIBRATION_MM_S      NUMBER(5,2),
    PRESSURE_PSI        NUMBER(6,2),
    HEALTH_SCORE        NUMBER(5,2), -- e.g., 0-100
    FAILURE_PROBABILITY NUMBER(3,2), -- e.g., 0-1.0
    RUL_DAYS            NUMBER(5,0), -- Remaining Useful Life in days
    IS_ANOMALOUS        BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (ASSET_ID) REFERENCES DIM_ASSET(ASSET_ID),
    FOREIGN KEY (PROCESS_ID) REFERENCES DIM_PROCESS(PROCESS_ID)
) COMMENT = 'Consolidated telemetry with ML predictions and health scores'
CLUSTER BY (ASSET_ID, RECORDED_AT); -- Optimized for time-series queries on specific assets



CREATE OR REPLACE TABLE DIM_TECHNICIAN (
    TECHNICIAN_ID   NUMBER(38,0) AUTOINCREMENT  PRIMARY KEY,
    EMPLOYEE_NK     VARCHAR(20) NOT NULL, -- Natural Key from HR system
    TECHNICIAN_NAME VARCHAR(100),
    CRAFT           VARCHAR(50), -- e.g., 'Mechanic', 'Electrician', 'Instrumentation'
    SHIFT           VARCHAR(10),
    HIRE_DATE       DATE,
    IS_ACTIVE       BOOLEAN
);


CREATE OR REPLACE TABLE DIM_FAILURE_CODE (
    FAILURE_CODE_ID     NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    FAILURE_HIERARCHY_1 VARCHAR(50), -- e.g., 'Mechanical', 'Electrical', 'Operational'
    FAILURE_HIERARCHY_2 VARCHAR(50), -- e.g., 'Bearing', 'Motor', 'Seal'
    FAILURE_HIERARCHY_3 VARCHAR(50), -- e.g., 'Over-lubrication', 'Misalignment', 'Contamination'
    FAILURE_DESCRIPTION VARCHAR(255)
);


CREATE OR REPLACE TABLE DIM_MATERIAL (
    MATERIAL_ID         INTEGER PRIMARY KEY,
    MATERIAL_NK         VARCHAR(50) NOT NULL, -- Part Number / SKU
    MATERIAL_DESC       VARCHAR(255),
    SUPPLIER_NAME       VARCHAR(100),
    UNIT_COST           NUMBER(10,2)
);


-- Log of all maintenance activities (Enhanced)
CREATE OR REPLACE TABLE FCT_MAINTENANCE_LOG (
    LOG_ID              NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    ASSET_ID            INTEGER NOT NULL,
    PROCESS_ID          INTEGER, -- Foreign Key to DIM_PROCESS
    WO_TYPE_ID          NUMBER(10,0) NOT NULL,
    ACTION_DATE_SK      NUMBER(8) NOT NULL,
    COMPLETED_DATE      DATE,
    DOWNTIME_HOURS      NUMBER(5,1),
    PARTS_COST          NUMBER(10,2),
    LABOR_COST          NUMBER(10,2),
    FAILURE_FLAG        BOOLEAN COMMENT 'TRUE if this action was in response to a failure',
    TECHNICIAN_ID       NUMBER(38,0) COMMENT 'Foreign key to DIM_TECHNICIAN',
    FAILURE_CODE_ID     NUMBER(38,0) COMMENT 'Foreign key to DIM_FAILURE_CODE, populated when FAILURE_FLAG is TRUE',
    TECHNICIAN_NOTES    VARCHAR(1000),
    FOREIGN KEY (ASSET_ID) REFERENCES DIM_ASSET(ASSET_ID),
    FOREIGN KEY (PROCESS_ID) REFERENCES DIM_PROCESS(PROCESS_ID),
    FOREIGN KEY (WO_TYPE_ID) REFERENCES DIM_WORK_ORDER_TYPE(WO_TYPE_ID),
    FOREIGN KEY (TECHNICIAN_ID) REFERENCES DIM_TECHNICIAN(TECHNICIAN_ID),
    FOREIGN KEY (FAILURE_CODE_ID) REFERENCES DIM_FAILURE_CODE(FAILURE_CODE_ID)
) CLUSTER BY (ASSET_ID, ACTION_DATE_SK);

-- Daily production summary for OEE calculations (New)
CREATE OR REPLACE TABLE FCT_PRODUCTION_LOG (
    PROD_LOG_ID         NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    ASSET_ID            INTEGER NOT NULL,
    PROCESS_ID          INTEGER, -- Foreign Key to DIM_PROCESS
    DATE_SK             NUMBER(8) NOT NULL,
    PRODUCTION_DATE     DATE,
    PLANNED_RUNTIME_HOURS   NUMBER(4,1),
    ACTUAL_RUNTIME_HOURS    NUMBER(4,1), -- Drives OEE "Availability"
    UNITS_PRODUCED      NUMBER(10,0), -- Drives OEE "Performance"
    UNITS_SCRAPPED      NUMBER(10,0), -- Drives OEE "Quality"
    FOREIGN KEY (ASSET_ID) REFERENCES DIM_ASSET(ASSET_ID),
    FOREIGN KEY (PROCESS_ID) REFERENCES DIM_PROCESS(PROCESS_ID)
) CLUSTER BY (ASSET_ID, PRODUCTION_DATE);


CREATE OR REPLACE TABLE FCT_MAINTENANCE_PARTS_USED (
    LOG_ID              NUMBER(38,0) NOT NULL, -- Foreign Key to FCT_MAINTENANCE_LOG
    MATERIAL_ID         INTEGER NOT NULL,      -- Foreign Key to DIM_MATERIAL
    QUANTITY_USED       NUMBER(8,2),
    TOTAL_COST          NUMBER(10,2),
    PRIMARY KEY (LOG_ID, MATERIAL_ID)
);

CREATE OR REPLACE TABLE FCT_BUDGET (
    BUDGET_ID           INTEGER PRIMARY KEY,
    PLANT_ID            NUMBER(10,0),
    YEAR                NUMBER(4),
    QUARTER             NUMBER(1),
    BUDGET_TYPE         VARCHAR(50), -- e.g., 'OpEx Maintenance', 'CapEx Project'
    BUDGET_AMOUNT       NUMBER(15,2),
    FOREIGN KEY (PLANT_ID) REFERENCES DIM_PLANT(PLANT_ID)
);


---------------------------------------------------------------------------------------------------
-- ## GOLD LAYER (Application & Feature Store)
-- Purpose-built tables for high-speed dashboards and ML model training.
---------------------------------------------------------------------------------------------------
USE SCHEMA SF_SOLUTIONS.GOLD;

CREATE OR REPLACE TABLE AGG_ASSET_HOURLY_HEALTH (
    HOUR_TIMESTAMP          TIMESTAMP_NTZ,
    ASSET_ID                INTEGER,
    AVG_TEMPERATURE_C       FLOAT,
    MAX_VIBRATION_MM_S      FLOAT,
    STDDEV_PRESSURE_PSI     FLOAT,
    LATEST_HEALTH_SCORE     NUMBER(5, 2),
    AVG_FAILURE_PROBABILITY NUMBER(3, 2),
    MIN_RUL_DAYS            NUMBER(5, 0)
);

CREATE OR REPLACE TABLE ML_FEATURE_STORE (
    OBSERVATION_DATE_SK     NUMBER(8),
    ASSET_ID                INTEGER,
    -- Example Features
    AVG_TEMP_LAST_24H       FLOAT,
    VIBRATION_STDDEV_7D     FLOAT,
    PRESSURE_TREND_7D       FLOAT,
    CYCLES_SINCE_LAST_PM    INTEGER,
    DAYS_SINCE_LAST_FAILURE INTEGER,
    OEM_FAILURE_RATE_EST    FLOAT,
    DOWNTIME_IMPACT_RISK    NUMBER(12, 2), -- Calculated risk based on asset downtime impact
    -- Target Variable
    FAILED_IN_NEXT_7_DAYS   BOOLEAN
);

-- Daily OEE Metrics (for detailed analysis and trending)
CREATE OR REPLACE TABLE AGG_DAILY_OEE (
    PRODUCTION_DATE         DATE,
    DATE_SK                 NUMBER(8),
    ASSET_ID                INTEGER,
    PROCESS_ID              INTEGER,
    -- OEE Components
    AVAILABILITY_PERCENT    NUMBER(5, 2), -- (Actual Runtime / Planned Runtime) * 100
    PERFORMANCE_PERCENT     NUMBER(5, 2), -- (Actual Output / Theoretical Max Output) * 100
    QUALITY_PERCENT         NUMBER(5, 2), -- (Good Units / Total Units) * 100
    -- Overall OEE
    OEE_PERCENT             NUMBER(5, 2), -- Availability × Performance × Quality
    -- Supporting Metrics
    PLANNED_RUNTIME_HOURS   NUMBER(4, 1),
    ACTUAL_RUNTIME_HOURS    NUMBER(4, 1),
    UNITS_PRODUCED          NUMBER(10, 0),
    UNITS_SCRAPPED          NUMBER(10, 0),
    GOOD_UNITS              NUMBER(10, 0),
    FOREIGN KEY (ASSET_ID) REFERENCES SF_SOLUTIONS.SILVER.DIM_ASSET(ASSET_ID)
);

-- Monthly Trend Aggregations (optimized for Intelligence Agent queries)
CREATE OR REPLACE TABLE AGG_MONTHLY_TRENDS (
    YEAR_MONTH              VARCHAR(7), -- YYYY-MM format for easy sorting and display
    YEAR                    NUMBER(4),
    MONTH                   NUMBER(2),
    PLANT_ID                NUMBER(10, 0),
    LINE_ID                 NUMBER(10, 0),
    PROCESS_ID              INTEGER,
    -- OEE Metrics
    AVG_OEE_PERCENT         NUMBER(5, 2),
    MIN_OEE_PERCENT         NUMBER(5, 2),
    MAX_OEE_PERCENT         NUMBER(5, 2),
    AVG_AVAILABILITY_PERCENT NUMBER(5, 2),
    AVG_PERFORMANCE_PERCENT  NUMBER(5, 2),
    AVG_QUALITY_PERCENT      NUMBER(5, 2),
    -- Maintenance Costs
    TOTAL_MAINTENANCE_COST   NUMBER(12, 2), -- Parts + Labor
    TOTAL_PARTS_COST         NUMBER(12, 2),
    TOTAL_LABOR_COST         NUMBER(12, 2),
    -- Maintenance Activities
    TOTAL_DOWNTIME_HOURS     NUMBER(10, 1),
    PREVENTIVE_WO_COUNT      NUMBER(10, 0),
    PREDICTIVE_WO_COUNT      NUMBER(10, 0),
    EMERGENCY_WO_COUNT       NUMBER(10, 0),
    FAILURE_COUNT            NUMBER(10, 0),
    -- Production Metrics
    TOTAL_UNITS_PRODUCED     NUMBER(15, 0),
    TOTAL_UNITS_SCRAPPED     NUMBER(15, 0),
    -- Asset Count
    ASSET_COUNT              NUMBER(10, 0)
);

/*************************************************************************************************/
-- Step 2: Insert Sample Data (DML)
/*************************************************************************************************/

-- Insert into BRONZE Layer
USE SCHEMA SF_SOLUTIONS.BRONZE;
INSERT INTO RAW_EQUIPMENT_MASTER (EQUIPMENT_DATA)
SELECT PARSE_JSON(column1) FROM VALUES
('{ "serialNumber": "eq_pump_001", "model": "HydroFlow 5000",'
    || ' "oem": "FlowServe", "installDate": "2022-01-15",'
    || ' "assetType": "Centrifugal Pump",'
    || ' "plant": "Davidson NC"}'),
('{ "serialNumber": "eq_motor_007", "model": "IronHorse 75HP",'
    || ' "oem": "Siemens", "installDate": "2021-11-20",'
    || ' "assetType": "Induction Motor",'
    || ' "plant": "Davidson NC"}');

INSERT INTO RAW_IOT_TELEMETRY (RAW_PAYLOAD, SOURCE_TIMESTAMP)
SELECT PARSE_JSON(column1), column2::TIMESTAMP_NTZ FROM VALUES
-- Normal readings for Pump 001
('{ "deviceId": "eq_pump_001_vib", "metric": "vibration", "value": 0.51, "unit": "mm/s" }', '2025-09-22 10:00:00'),
('{ "deviceId": "eq_pump_001_tmp", "metric": "temperature", "value": 65.2, "unit": "C" }', '2025-09-22 10:00:00'),
('{ "deviceId": "eq_pump_001_vib", "metric": "vibration", "value": 0.55, "unit": "mm/s" }', '2025-09-22 11:00:00'),
-- Anomalous reading
('{ "deviceId": "eq_pump_001_vib", "metric": "vibration", "value": 2.15, "unit": "mm/s" }', '2025-09-23 08:00:00'),
('{ "deviceId": "eq_pump_001_tmp", "metric": "temperature", "value": 75.8, "unit": "C" }', '2025-09-23 08:00:00');

INSERT INTO RAW_MAINTENANCE_LOGS (LOG_DATA)
SELECT PARSE_JSON(column1) FROM VALUES
('{ "workOrderId": "WO-9987", "assetId": "eq_pump_001",'
    || ' "type": "CM",'
    || ' "notes": "High vibration detected.'
    || ' Found bearing misalignment.",'
    || ' "downtimeHours": 4, "laborCost": 600,'
    || ' "partsCost": 250, "failure": true,'
    || ' "date": "2025-09-23"}');


-- Insert into SILVER Layer
USE SCHEMA SF_SOLUTIONS.SILVER;
-- Populate Dimensions first
SET (START_DATE, END_DATE) = ('1995-01-01', '2030-12-31');
SET GENERATOR_RECORD_COUNT = (select DATEDIFF(DAY, $START_DATE, $END_DATE) + 1);
INSERT OVERWRITE INTO DIM_DATE (DATE_SK, FULL_DATE, DAY_OF_WEEK, MONTH_NAME, QUARTER, YEAR)
SELECT 
    TO_NUMBER(TO_CHAR(d.DATE, 'YYYYMMDD')) AS DATE_SK,
    d.DATE AS FULL_DATE,
    DAYNAME(d.DATE) AS DAY_OF_WEEK,
    TO_CHAR(TO_DATE(d.DATE), 'MMMM') AS MONTH_NAME,
    QUARTER(d.DATE) AS QUARTER,
    YEAR(d.DATE) AS YEAR
FROM (
    SELECT DATEADD(DAY, SEQ4(), $START_DATE) AS DATE
    FROM TABLE(GENERATOR(ROWCOUNT => $GENERATOR_RECORD_COUNT))
) d;

-- Plant and Line Hierarchy
INSERT INTO DIM_PLANT (PLANT_ID, PLANT_NAME, LOCATION, PLANT_UNS_NK) VALUES
(1, 'Davidson Manufacturing', 'Davidson NC', 'snowcore_industries/davidson_nc'),
(2, 'Charlotte Assembly', 'Charlotte NC', 'snowcore_industries/charlotte_nc');

INSERT INTO DIM_LINE (LINE_ID, PLANT_ID, LINE_NAME, HOURLY_REVENUE, LINE_UNS_NK) VALUES
(101, 1, 'Production Line A', 15000.00, 'snowcore_industries/davidson_nc/production_line_a'),
(102, 1, 'Production Line B', 12000.00, 'snowcore_industries/davidson_nc/production_line_b'),
(103, 1, 'Production Line C', 14000.00, 'snowcore_industries/davidson_nc/production_line_c'),
(201, 2, 'Assembly Line 1', 18000.00, 'snowcore_industries/charlotte_nc/assembly_line_1'),
(202, 2, 'Assembly Line 2', 16000.00, 'snowcore_industries/charlotte_nc/assembly_line_2'),
(203, 2, 'Assembly Line 3', 17500.00, 'snowcore_industries/charlotte_nc/assembly_line_3');

-- Manufacturing Processes (3 per line = 18 total processes)
INSERT INTO DIM_PROCESS (PROCESS_NK, PROCESS_NAME, PROCESS_TYPE, LINE_ID, PROCESS_UNS_NK, DESCRIPTION) VALUES
-- Production Line A Processes (Davidson Manufacturing)
('machining_process_a',
'Machining Operations',
'Manufacturing',
101,
'snowcore_industries/davidson_nc/production_line_a/machining_process',
'Primary machining operations including cutting, drilling, and shaping'),
('assembly_process_a',
'Assembly Operations',
'Assembly',
101,
'snowcore_industries/davidson_nc/production_line_a/assembly_process',
'Component assembly and integration operations'),
('testing_process_a',
'Quality Testing',
'Testing',
101,
'snowcore_industries/davidson_nc/production_line_a/testing_process',
'Quality control and testing operations'),

-- Production Line B Processes (Davidson Manufacturing)
('forming_process_b',
'Metal Forming',
'Manufacturing',
102,
'snowcore_industries/davidson_nc/production_line_b/forming_process',
'Metal forming and shaping operations'),
('welding_process_b',
'Welding Operations',
'Manufacturing',
102,
'snowcore_industries/davidson_nc/production_line_b/welding_process',
'Welding and joining operations'),
('finishing_process_b',
'Surface Finishing',
'Manufacturing',
102,
'snowcore_industries/davidson_nc/production_line_b/finishing_process',
'Surface treatment and finishing operations'),

-- Production Line C Processes (Davidson Manufacturing)
('molding_process_c',
'Plastic Molding',
'Manufacturing',
103,
'snowcore_industries/davidson_nc/production_line_c/molding_process',
'Plastic injection molding operations'),
('inspection_process_c',
'Quality Inspection',
'Testing',
103,
'snowcore_industries/davidson_nc/production_line_c/inspection_process',
'Quality inspection and verification'),
('packaging_process_c',
'Final Packaging',
'Assembly',
103,
'snowcore_industries/davidson_nc/production_line_c/packaging_process',
'Final packaging and preparation'),

-- Assembly Line 1 Processes (Charlotte Assembly)
('robot_assembly_1',
'Robotic Assembly',
'Assembly',
201,
'snowcore_industries/charlotte_nc/assembly_line_1/robot_assembly',
'Automated robotic assembly operations'),
('manual_assembly_1',
'Manual Assembly',
'Assembly',
201,
'snowcore_industries/charlotte_nc/assembly_line_1/manual_assembly',
'Manual assembly and hand operations'),
('quality_check_1',
'Quality Verification',
'Testing',
201,
'snowcore_industries/charlotte_nc/assembly_line_1/quality_check',
'Quality verification and testing'),

-- Assembly Line 2 Processes (Charlotte Assembly)
('welding_station_2',
'Welding Station',
'Manufacturing',
202,
'snowcore_industries/charlotte_nc/assembly_line_2/welding_station',
'Dedicated welding station operations'),
('heat_treatment_2',
'Heat Treatment',
'Manufacturing',
202,
'snowcore_industries/charlotte_nc/assembly_line_2/heat_treatment',
'Heat treatment and thermal processing'),
('final_inspection_2',
'Final Inspection',
'Testing',
202,
'snowcore_industries/charlotte_nc/assembly_line_2/final_inspection',
'Final quality inspection and approval'),

-- Assembly Line 3 Processes (Charlotte Assembly)
('sorting_process_3',
'Product Sorting',
'Assembly',
203,
'snowcore_industries/charlotte_nc/assembly_line_3/sorting_process',
'Product sorting and classification'),
('packaging_robot_3',
'Automated Packaging',
'Assembly',
203,
'snowcore_industries/charlotte_nc/assembly_line_3/packaging_robot',
'Automated packaging operations'),
('quality_scan_3',
'Quality Scanning',
'Testing',
203,
'snowcore_industries/charlotte_nc/assembly_line_3/quality_scan',
'Automated quality scanning and verification');

-- Asset Classifications
INSERT INTO DIM_ASSET_CLASS (ASSET_CLASS_ID, CLASS_NAME) VALUES
(1, 'Rotating Equipment'),
(2, 'Static Equipment'),
(3, 'Electrical Systems'),
(4, 'Control Systems');

-- Work Order Types (Enhanced)
INSERT INTO DIM_WORK_ORDER_TYPE (WO_TYPE_ID, WO_TYPE_NAME, WO_TYPE_CODE) VALUES
(1, 'Unplanned Emergency', 'UE'),
(2, 'Planned Predictive', 'PP'),
(3, 'Planned Preventive', 'PM'),
(4, 'Inspection', 'INSP');

-- Assets (formerly Equipment) - 3 per line across 6 lines = 18 total
INSERT INTO DIM_ASSET (ASSET_NK,
ASSET_NAME,
MODEL,
OEM_NAME,
PROCESS_ID,
PROCESS_SEQUENCE,
ASSET_CLASS_ID,
INSTALLATION_DATE,
DOWNTIME_IMPACT_PER_HOUR,
ASSET_UNS_NK,
SCD_START_DATE,
IS_CURRENT) VALUES
-- Line 101 Assets (Production Line A) - Machining Process
('eq_pump_001',
'Primary Coolant Pump',
'HydroFlow 5000',
'FlowServe',
1,
1,
1,
'2022-01-15',
7500.00,
'snowcore_industries/davidson_nc/production_line_a/machining_process/eq_pump_001',
'2022-01-15',
TRUE),
('eq_motor_007',
'Conveyor Drive Motor',
'IronHorse 75HP',
'Siemens',
1,
2,
1,
'2021-11-20',
5000.00,
'snowcore_industries/davidson_nc/production_line_a/machining_process/eq_motor_007',
'2021-11-20',
TRUE),
('eq_comp_101',
'Air Compressor Unit',
'CompMax 200',
'Atlas Copco',
1,
3,
1,
'2022-03-10',
6000.00,
'snowcore_industries/davidson_nc/production_line_a/machining_process/eq_comp_101',
'2022-03-10',
TRUE),

-- Line 102 Assets (Production Line B) - Forming Process
('eq_pump_102',
'Hydraulic Pump System',
'PowerFlow 3000',
'Bosch Rexroth',
4,
1,
1,
'2021-08-15',
4500.00,
'snowcore_industries/davidson_nc/production_line_b/forming_process/eq_pump_102',
'2021-08-15',
TRUE),
('eq_motor_102',
'Main Drive Motor',
'PowerMax 50HP',
'ABB',
4,
2,
1,
'2021-09-20',
4000.00,
'snowcore_industries/davidson_nc/production_line_b/forming_process/eq_motor_102',
'2021-09-20',
TRUE),
('eq_fan_102',
'Cooling Fan Assembly',
'AeroMax 1200',
'Ziehl-Abegg',
4,
3,
3,
'2022-01-05',
2500.00,
'snowcore_industries/davidson_nc/production_line_b/forming_process/eq_fan_102',
'2022-01-05',
TRUE),

-- Line 103 Assets (Production Line C) - Molding Process
('eq_pump_103',
'Process Circulation Pump',
'FlowTech 4000',
'Grundfos',
7,
1,
1,
'2021-12-12',
5500.00,
'snowcore_industries/davidson_nc/production_line_c/molding_process/eq_pump_103',
'2021-12-12',
TRUE),
('eq_motor_103',
'Conveyor Motor Assembly',
'DriveForce 60HP',
'Siemens',
7,
2,
1,
'2022-02-18',
4800.00,
'snowcore_industries/davidson_nc/production_line_c/molding_process/eq_motor_103',
'2022-02-18',
TRUE),
('eq_valve_103',
'Control Valve System',
'PrecisionFlow 500',
'Emerson',
7,
3,
2,
'2022-04-22',
3200.00,
'snowcore_industries/davidson_nc/production_line_c/molding_process/eq_valve_103',
'2022-04-22',
TRUE),

-- Line 201 Assets (Assembly Line 1) - Robot Assembly Process
('eq_robot_201',
'Assembly Robot Arm',
'FlexArm 6000',
'KUKA',
10,
1,
4,
'2021-06-30',
9000.00,
'snowcore_industries/charlotte_nc/assembly_line_1/robot_assembly/eq_robot_201',
'2021-06-30',
TRUE),
('eq_motor_201',
'Conveyor Drive System',
'MegaDrive 100HP',
'Schneider Electric',
10,
2,
1,
'2021-07-15',
6500.00,
'snowcore_industries/charlotte_nc/assembly_line_1/robot_assembly/eq_motor_201',
'2021-07-15',
TRUE),
('eq_press_201',
'Pneumatic Press Unit',
'PowerPress 5000',
'SMC',
10,
3,
2,
'2021-08-01',
7200.00,
'snowcore_industries/charlotte_nc/assembly_line_1/robot_assembly/eq_press_201',
'2021-08-01',
TRUE),

-- Line 202 Assets (Assembly Line 2) - Welding Station Process
('eq_robot_202',
'Welding Robot System',
'WeldMaster Pro',
'Fanuc',
13,
1,
4,
'2021-09-10',
8500.00,
'snowcore_industries/charlotte_nc/assembly_line_2/welding_station/eq_robot_202',
'2021-09-10',
TRUE),
('eq_motor_202',
'Material Handling Motor',
'FlexDrive 80HP',
'Rockwell',
13,
2,
1,
'2021-10-05',
5800.00,
'snowcore_industries/charlotte_nc/assembly_line_2/welding_station/eq_motor_202',
'2021-10-05',
TRUE),
('eq_heat_202',
'Heat Treatment Furnace',
'ThermoPro 3000',
'Despatch',
14,
1,
2,
'2021-11-12',
8000.00,
'snowcore_industries/charlotte_nc/assembly_line_2/heat_treatment/eq_heat_202',
'2021-11-12',
TRUE),

-- Line 203 Assets (Assembly Line 3) - Sorting and Packaging Processes
('eq_robot_203',
'Packaging Robot',
'PackBot 2000',
'ABB Robotics',
16,
1,
4,
'2022-01-20',
7800.00,
'snowcore_industries/charlotte_nc/assembly_line_3/packaging_robot/eq_robot_203',
'2022-01-20',
TRUE),
('eq_motor_203',
'Sorting System Motor',
'SortDrive 45HP',
'Baldor',
15,
1,
1,
'2022-02-14',
4200.00,
'snowcore_industries/charlotte_nc/assembly_line_3/sorting_process/eq_motor_203',
'2022-02-14',
TRUE),
('eq_scan_203',
'Quality Control Scanner',
'VisionScan Pro',
'Cognex',
18,
1,
4,
'2022-03-18',
6200.00,
'snowcore_industries/charlotte_nc/assembly_line_3/quality_scan/eq_scan_203',
'2022-03-18',
TRUE);

-- Populate Technicians
INSERT INTO DIM_TECHNICIAN (EMPLOYEE_NK, TECHNICIAN_NAME, CRAFT, SHIFT, HIRE_DATE, IS_ACTIVE) VALUES
('EMP001', 'John Martinez', 'Mechanic', 'Day', '2020-03-15', TRUE),
('EMP002', 'Sarah Chen', 'Electrician', 'Day', '2019-08-22', TRUE),
('EMP003', 'Mike Johnson', 'Instrumentation', 'Day', '2021-01-10', TRUE),
('EMP004', 'Lisa Rodriguez', 'Mechanic', 'Evening', '2020-11-05', TRUE),
('EMP005', 'David Kim', 'Electrician', 'Evening', '2018-09-18', TRUE),
('EMP006', 'Angela Thompson', 'Instrumentation', 'Evening', '2022-04-12', TRUE),
('EMP007', 'Robert Wilson', 'Mechanic', 'Night', '2019-12-03', TRUE),
('EMP008', 'Maria Garcia', 'Electrician', 'Night', '2021-06-28', TRUE),
('EMP009', 'James Lee', 'Instrumentation', 'Night', '2020-07-14', TRUE),
('EMP010', 'Emily Davis', 'Mechanic', 'Day', '2022-01-25', TRUE);

-- Populate Failure Codes
INSERT INTO DIM_FAILURE_CODE (FAILURE_HIERARCHY_1, FAILURE_HIERARCHY_2, FAILURE_HIERARCHY_3, FAILURE_DESCRIPTION) VALUES
('Mechanical', 'Bearing', 'Misalignment', 'Bearing misalignment causing excessive vibration and wear'),
('Mechanical', 'Bearing', 'Lubrication', 'Inadequate or contaminated lubrication leading to bearing failure'),
('Mechanical', 'Seal', 'Wear', 'Seal deterioration causing fluid leakage'),
('Mechanical', 'Coupling', 'Failure', 'Coupling failure due to fatigue or misalignment'),
('Mechanical', 'Impeller', 'Erosion', 'Impeller damage due to cavitation or erosion'),
('Electrical', 'Motor', 'Winding', 'Motor winding failure due to overheating or insulation breakdown'),
('Electrical', 'Motor', 'Connection', 'Loose or corroded electrical connections'),
('Electrical', 'Sensor', 'Calibration', 'Sensor drift or calibration issues affecting readings'),
('Electrical', 'Power Supply', 'Voltage', 'Power supply voltage fluctuations or failures'),
('Operational', 'Overload', 'Capacity', 'Equipment operated beyond design capacity'),
('Operational', 'Temperature', 'Overheating', 'Equipment overheating due to operational conditions'),
('Operational', 'Contamination', 'Foreign Object', 'Foreign object contamination causing operational issues');

-- Populate Materials (Parts and components used in maintenance)
INSERT INTO DIM_MATERIAL (MATERIAL_ID, MATERIAL_NK, MATERIAL_DESC, SUPPLIER_NAME, UNIT_COST) VALUES
(1, 'BRG-001', 'Standard Ball Bearing 6202', 'SKF Industries', 25.50),
(2, 'BRG-002', 'Heavy Duty Roller Bearing', 'Timken Company', 85.00),
(3, 'SEAL-001', 'Oil Seal 35x52x7', 'Parker Hannifin', 12.75),
(4, 'SEAL-002', 'Mechanical Seal Assembly', 'John Crane', 145.00),
(5, 'BELT-001', 'V-Belt A47', 'Gates Corporation', 18.50),
(6, 'FILTER-001', 'Hydraulic Filter Element', 'Pall Corporation', 42.00),
(7, 'FILTER-002', 'Air Filter Cartridge', 'Donaldson Company', 38.50),
(8, 'OIL-001', 'Synthetic Gear Oil 5L', 'Mobil', 55.00),
(9, 'OIL-002', 'Hydraulic Oil ISO 46 20L', 'Shell', 95.00),
(10, 'MOTOR-001', 'Servo Motor 2kW', 'Siemens', 850.00),
(11, 'SENSOR-001', 'Temperature Sensor PT100', 'Omega Engineering', 75.00),
(12, 'SENSOR-002', 'Vibration Sensor Accelerometer', 'PCB Piezotronics', 425.00),
(13, 'VALVE-001', 'Solenoid Valve 24V', 'Emerson', 165.00),
(14, 'COUPLING-001', 'Flexible Coupling', 'Lovejoy', 95.00),
(15, 'GASKET-001', 'Flange Gasket Set', 'Garlock', 22.00),
(16, 'IMPELLER-001', 'Pump Impeller Bronze', 'Goulds Pumps', 320.00),
(17, 'WIRE-001', 'Electrical Wire 10AWG 100ft', '3M', 85.00),
(18, 'RELAY-001', 'Control Relay 24VDC', 'Allen-Bradley', 45.00),
(19, 'FUSE-001', 'Fast-Acting Fuse 30A', 'Bussmann', 8.50),
(20, 'GREASE-001', 'High-Temp Bearing Grease 1lb', 'Mobil', 15.75);

-- Populate Budget Data
INSERT INTO FCT_BUDGET (BUDGET_ID, PLANT_ID, YEAR, QUARTER, BUDGET_TYPE, BUDGET_AMOUNT) VALUES
-- Davidson Manufacturing (Plant 1) - 2025 Budget
(1, 1, 2025, 1, 'OpEx Maintenance', 450000.00),
(2, 1, 2025, 2, 'OpEx Maintenance', 475000.00),
(3, 1, 2025, 3, 'OpEx Maintenance', 500000.00),
(4, 1, 2025, 4, 'OpEx Maintenance', 525000.00),
(5, 1, 2025, 1, 'CapEx Project', 125000.00),
(6, 1, 2025, 2, 'CapEx Project', 150000.00),
(7, 1, 2025, 3, 'CapEx Project', 200000.00),
(8, 1, 2025, 4, 'CapEx Project', 175000.00),

-- Charlotte Assembly (Plant 2) - 2025 Budget
(9, 2, 2025, 1, 'OpEx Maintenance', 550000.00),
(10, 2, 2025, 2, 'OpEx Maintenance', 580000.00),
(11, 2, 2025, 3, 'OpEx Maintenance', 600000.00),
(12, 2, 2025, 4, 'OpEx Maintenance', 625000.00),
(13, 2, 2025, 1, 'CapEx Project', 175000.00),
(14, 2, 2025, 2, 'CapEx Project', 200000.00),
(15, 2, 2025, 3, 'CapEx Project', 250000.00),
(16, 2, 2025, 4, 'CapEx Project', 225000.00),

-- Davidson Manufacturing (Plant 1) - 2024 Actuals for comparison
(17, 1, 2024, 1, 'OpEx Maintenance', 425000.00),
(18, 1, 2024, 2, 'OpEx Maintenance', 445000.00),
(19, 1, 2024, 3, 'OpEx Maintenance', 485000.00),
(20, 1, 2024, 4, 'OpEx Maintenance', 510000.00),
(21, 1, 2024, 1, 'CapEx Project', 100000.00),
(22, 1, 2024, 2, 'CapEx Project', 120000.00),
(23, 1, 2024, 3, 'CapEx Project', 180000.00),
(24, 1, 2024, 4, 'CapEx Project', 160000.00),

-- Charlotte Assembly (Plant 2) - 2024 Actuals for comparison
(25, 2, 2024, 1, 'OpEx Maintenance', 520000.00),
(26, 2, 2024, 2, 'OpEx Maintenance', 555000.00),
(27, 2, 2024, 3, 'OpEx Maintenance', 575000.00),
(28, 2, 2024, 4, 'OpEx Maintenance', 595000.00),
(29, 2, 2024, 1, 'CapEx Project', 150000.00),
(30, 2, 2024, 2, 'CapEx Project', 175000.00),
(31, 2, 2024, 3, 'CapEx Project', 220000.00),
(32, 2, 2024, 4, 'CapEx Project', 200000.00);

-- Sensors (3 per asset = 54 total sensors)
INSERT INTO DIM_SENSOR (SENSOR_NK, ASSET_ID, SENSOR_TYPE, UNITS_OF_MEASURE, SENSOR_UNS_NK) VALUES
-- Asset 1 (Primary Coolant Pump) Sensors
('eq_pump_001_vib', 1, 'Vibration', 'mm/s', 'snowcore_industries/davidson_nc/production_line_a/machining_process/eq_pump_001/vibration'),
('eq_pump_001_tmp',
1,
'Temperature',
'Celsius',
'snowcore_industries/davidson_nc/production_line_a/machining_process/eq_pump_001/temperature'),
('eq_pump_001_psi', 1, 'Pressure', 'PSI', 'snowcore_industries/davidson_nc/production_line_a/machining_process/eq_pump_001/pressure'),

-- Asset 2 (Conveyor Drive Motor) Sensors
('eq_motor_007_vib', 2, 'Vibration', 'mm/s', 'snowcore_industries/davidson_nc/production_line_a/machining_process/eq_motor_007/vibration'),
('eq_motor_007_tmp',
2,
'Temperature',
'Celsius',
'snowcore_industries/davidson_nc/production_line_a/machining_process/eq_motor_007/temperature'),
('eq_motor_007_rpm',
2,
'Rotational Speed',
'RPM',
'snowcore_industries/davidson_nc/production_line_a/machining_process/eq_motor_007/rotational_speed'),

-- Asset 3 (Air Compressor Unit) Sensors
('eq_comp_101_vib', 3, 'Vibration', 'mm/s', 'snowcore_industries/davidson_nc/production_line_a/machining_process/eq_comp_101/vibration'),
('eq_comp_101_tmp',
3,
'Temperature',
'Celsius',
'snowcore_industries/davidson_nc/production_line_a/machining_process/eq_comp_101/temperature'),
('eq_comp_101_psi', 3, 'Pressure', 'PSI', 'snowcore_industries/davidson_nc/production_line_a/machining_process/eq_comp_101/pressure'),

-- Asset 4 (Hydraulic Pump System) Sensors
('eq_pump_102_vib', 4, 'Vibration', 'mm/s', 'snowcore_industries/davidson_nc/production_line_b/forming_process/eq_pump_102/vibration'),
('eq_pump_102_tmp',
4,
'Temperature',
'Celsius',
'snowcore_industries/davidson_nc/production_line_b/forming_process/eq_pump_102/temperature'),
('eq_pump_102_psi', 4, 'Pressure', 'PSI', 'snowcore_industries/davidson_nc/production_line_b/forming_process/eq_pump_102/pressure'),

-- Asset 5 (Main Drive Motor) Sensors
('eq_motor_102_vib', 5, 'Vibration', 'mm/s', 'snowcore_industries/davidson_nc/production_line_b/forming_process/eq_motor_102/vibration'),
('eq_motor_102_tmp',
5,
'Temperature',
'Celsius',
'snowcore_industries/davidson_nc/production_line_b/forming_process/eq_motor_102/temperature'),
('eq_motor_102_cur', 5, 'Current', 'Amps', 'snowcore_industries/davidson_nc/production_line_b/forming_process/eq_motor_102/current'),

-- Asset 6 (Cooling Fan Assembly) Sensors
('eq_fan_102_vib', 6, 'Vibration', 'mm/s', 'snowcore_industries/davidson_nc/production_line_b/forming_process/eq_fan_102/vibration'),
('eq_fan_102_tmp', 6, 'Temperature', 'Celsius', 'snowcore_industries/davidson_nc/production_line_b/forming_process/eq_fan_102/temperature'),
('eq_fan_102_rpm',
6,
'Rotational Speed',
'RPM',
'snowcore_industries/davidson_nc/production_line_b/forming_process/eq_fan_102/rotational_speed'),

-- Asset 7 (Process Circulation Pump) Sensors
('eq_pump_103_vib', 7, 'Vibration', 'mm/s', 'snowcore_industries/davidson_nc/production_line_c/molding_process/eq_pump_103/vibration'),
('eq_pump_103_tmp',
7,
'Temperature',
'Celsius',
'snowcore_industries/davidson_nc/production_line_c/molding_process/eq_pump_103/temperature'),
('eq_pump_103_flw', 7, 'Flow Rate', 'GPM', 'snowcore_industries/davidson_nc/production_line_c/molding_process/eq_pump_103/flow_rate'),

-- Asset 8 (Conveyor Motor Assembly) Sensors
('eq_motor_103_vib', 8, 'Vibration', 'mm/s', 'snowcore_industries/davidson_nc/production_line_c/molding_process/eq_motor_103/vibration'),
('eq_motor_103_tmp',
8,
'Temperature',
'Celsius',
'snowcore_industries/davidson_nc/production_line_c/molding_process/eq_motor_103/temperature'),
('eq_motor_103_trq', 8, 'Torque', 'Nm', 'snowcore_industries/davidson_nc/production_line_c/molding_process/eq_motor_103/torque'),

-- Asset 9 (Control Valve System) Sensors
('eq_valve_103_psi', 9, 'Pressure', 'PSI', 'snowcore_industries/davidson_nc/production_line_c/molding_process/eq_valve_103/pressure'),
('eq_valve_103_tmp',
9,
'Temperature',
'Celsius',
'snowcore_industries/davidson_nc/production_line_c/molding_process/eq_valve_103/temperature'),
('eq_valve_103_pos', 9, 'Position', 'Percent', 'snowcore_industries/davidson_nc/production_line_c/molding_process/eq_valve_103/position'),

-- Asset 10 (Assembly Robot Arm) Sensors
('eq_robot_201_tmp',
10,
'Temperature',
'Celsius',
'snowcore_industries/charlotte_nc/assembly_line_1/robot_assembly/eq_robot_201/temperature'),
('eq_robot_201_cur', 10, 'Current', 'Amps', 'snowcore_industries/charlotte_nc/assembly_line_1/robot_assembly/eq_robot_201/current'),
('eq_robot_201_pos', 10, 'Position', 'Degrees', 'snowcore_industries/charlotte_nc/assembly_line_1/robot_assembly/eq_robot_201/position'),

-- Asset 11 (Conveyor Drive System) Sensors
('eq_motor_201_vib', 11, 'Vibration', 'mm/s', 'snowcore_industries/charlotte_nc/assembly_line_1/robot_assembly/eq_motor_201/vibration'),
('eq_motor_201_tmp',
11,
'Temperature',
'Celsius',
'snowcore_industries/charlotte_nc/assembly_line_1/robot_assembly/eq_motor_201/temperature'),
('eq_motor_201_cur', 11, 'Current', 'Amps', 'snowcore_industries/charlotte_nc/assembly_line_1/robot_assembly/eq_motor_201/current'),

-- Asset 12 (Pneumatic Press Unit) Sensors
('eq_press_201_psi', 12, 'Pressure', 'PSI', 'snowcore_industries/charlotte_nc/assembly_line_1/robot_assembly/eq_press_201/pressure'),
('eq_press_201_tmp',
12,
'Temperature',
'Celsius',
'snowcore_industries/charlotte_nc/assembly_line_1/robot_assembly/eq_press_201/temperature'),
('eq_press_201_for', 12, 'Force', 'kN', 'snowcore_industries/charlotte_nc/assembly_line_1/robot_assembly/eq_press_201/force'),

-- Asset 13 (Welding Robot System) Sensors
('eq_robot_202_tmp',
13,
'Temperature',
'Celsius',
'snowcore_industries/charlotte_nc/assembly_line_2/welding_station/eq_robot_202/temperature'),
('eq_robot_202_cur', 13, 'Current', 'Amps', 'snowcore_industries/charlotte_nc/assembly_line_2/welding_station/eq_robot_202/current'),
('eq_robot_202_vol', 13, 'Voltage', 'Volts', 'snowcore_industries/charlotte_nc/assembly_line_2/welding_station/eq_robot_202/voltage'),

-- Asset 14 (Material Handling Motor) Sensors
('eq_motor_202_vib', 14, 'Vibration', 'mm/s', 'snowcore_industries/charlotte_nc/assembly_line_2/welding_station/eq_motor_202/vibration'),
('eq_motor_202_tmp',
14,
'Temperature',
'Celsius',
'snowcore_industries/charlotte_nc/assembly_line_2/welding_station/eq_motor_202/temperature'),
('eq_motor_202_spd', 14, 'Speed', 'RPM', 'snowcore_industries/charlotte_nc/assembly_line_2/welding_station/eq_motor_202/speed'),

-- Asset 15 (Heat Treatment Furnace) Sensors
('eq_heat_202_tmp',
15,
'Temperature',
'Celsius',
'snowcore_industries/charlotte_nc/assembly_line_2/heat_treatment/eq_heat_202/temperature'),
('eq_heat_202_gas', 15, 'Gas Flow', 'SCFM', 'snowcore_industries/charlotte_nc/assembly_line_2/heat_treatment/eq_heat_202/gas_flow'),
('eq_heat_202_oxy',
15,
'Oxygen Level',
'Percent',
'snowcore_industries/charlotte_nc/assembly_line_2/heat_treatment/eq_heat_202/oxygen_level'),

-- Asset 16 (Packaging Robot) Sensors
('eq_robot_203_tmp',
16,
'Temperature',
'Celsius',
'snowcore_industries/charlotte_nc/assembly_line_3/packaging_robot/eq_robot_203/temperature'),
('eq_robot_203_spd', 16, 'Speed', 'Units/Min', 'snowcore_industries/charlotte_nc/assembly_line_3/packaging_robot/eq_robot_203/speed'),
('eq_robot_203_pos', 16, 'Position', 'mm', 'snowcore_industries/charlotte_nc/assembly_line_3/packaging_robot/eq_robot_203/position'),

-- Asset 17 (Sorting System Motor) Sensors
('eq_motor_203_vib', 17, 'Vibration', 'mm/s', 'snowcore_industries/charlotte_nc/assembly_line_3/sorting_process/eq_motor_203/vibration'),
('eq_motor_203_tmp',
17,
'Temperature',
'Celsius',
'snowcore_industries/charlotte_nc/assembly_line_3/sorting_process/eq_motor_203/temperature'),
('eq_motor_203_cur', 17, 'Current', 'Amps', 'snowcore_industries/charlotte_nc/assembly_line_3/sorting_process/eq_motor_203/current'),

-- Asset 18 (Quality Control Scanner) Sensors
('eq_scan_203_tmp', 18, 'Temperature', 'Celsius', 'snowcore_industries/charlotte_nc/assembly_line_3/quality_scan/eq_scan_203/temperature'),
('eq_scan_203_lux',
18,
'Light Intensity',
'Lux',
'snowcore_industries/charlotte_nc/assembly_line_3/quality_scan/eq_scan_203/light_intensity'),
('eq_scan_203_fps', 18, 'Scan Rate', 'FPS', 'snowcore_industries/charlotte_nc/assembly_line_3/quality_scan/eq_scan_203/scan_rate');

-- Populate Facts using IDs from Dimensions
-- Asset Telemetry (Hourly readings for all 18 assets from Nov 1, 2024 to current date)
-- Using a CTE to generate hourly data dynamically
INSERT INTO FCT_ASSET_TELEMETRY (ASSET_ID,
PROCESS_ID,
DATE_SK,
RECORDED_AT,
TEMPERATURE_C,
VIBRATION_MM_S,
PRESSURE_PSI,
HEALTH_SCORE,
FAILURE_PROBABILITY,
RUL_DAYS,
IS_ANOMALOUS)
WITH date_params AS (
    SELECT 
        '2024-11-01 00:00:00'::TIMESTAMP_NTZ AS start_timestamp,
        DATE_TRUNC('HOUR', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ AS end_timestamp,
        -- Decay start date: 90 days ago from current time (assets are healthy before this)
        DATE_TRUNC('HOUR', DATEADD(DAY, -90, CURRENT_TIMESTAMP()))::TIMESTAMP_NTZ AS decay_start_timestamp
),
hourly_base AS (
    SELECT 
        a.asset_id,
        a.process_id,
        DATEADD(HOUR, h.hour_seq, dp.start_timestamp) as recorded_at,
        TO_NUMBER(TO_CHAR(DATEADD(HOUR, h.hour_seq, dp.start_timestamp), 'YYYYMMDD')) as date_sk,
        h.hour_seq,
        HOUR(DATEADD(HOUR, h.hour_seq, dp.start_timestamp)) as hour_of_day,
        DATEDIFF(DAY, dp.start_timestamp, DATEADD(HOUR, h.hour_seq, dp.start_timestamp)) as days_elapsed,
        -- Calculate days since decay started (0 or negative if before decay start)
        GREATEST(0, DATEDIFF(DAY, dp.decay_start_timestamp, DATEADD(HOUR, h.hour_seq, dp.start_timestamp))) as days_since_decay_start
    FROM date_params dp
    CROSS JOIN (
        SELECT 
            da.ASSET_ID,
            da.PROCESS_ID
        FROM SF_SOLUTIONS.SILVER.DIM_ASSET da
        WHERE da.IS_CURRENT = TRUE
    ) a
    CROSS JOIN (
        SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS hour_seq
        FROM TABLE(GENERATOR(ROWCOUNT => 10000))  -- Enough for ~13 months
    ) h
    WHERE DATEADD(HOUR, h.hour_seq, dp.start_timestamp) <= dp.end_timestamp
),
sensor_data AS (
    SELECT 
        asset_id,
        process_id,
        date_sk,
        recorded_at,
        hour_of_day,
        days_elapsed,
        days_since_decay_start,
        -- Generate realistic sensor data based on asset type and time (controlled ranges)
        -- Temperature increases only after decay start date
        CASE 
            -- Pumps run warmer, gradual degradation
            WHEN asset_id IN (1,4,7) THEN ROUND(60 + (hour_of_day * 0.5) + (days_since_decay_start * 0.1) + UNIFORM(-3, 7, RANDOM()), 2)
            -- Motors
            WHEN asset_id IN (2,
            5,
            8,
            11,
            14,
            17) THEN ROUND(55 + (hour_of_day * 0.3) + (days_since_decay_start * 0.08) + UNIFORM(-2,
            6,
            RANDOM()),
            2)
            -- Robots
            WHEN asset_id IN (10,13,16) THEN ROUND(50 + (hour_of_day * 0.2) + (days_since_decay_start * 0.05) + UNIFORM(-2, 4, RANDOM()), 2)
            -- Furnace much hotter
            WHEN asset_id = 15 THEN ROUND(200 + (hour_of_day * 2) + (days_since_decay_start * 0.5) + UNIFORM(-10, 10, RANDOM()), 2)
            ELSE ROUND(45 + (hour_of_day * 0.4) + (days_since_decay_start * 0.06) + UNIFORM(-2, 3, RANDOM()), 2)  -- Other equipment
        END as temperature_c,
        
        -- Vibration data (rotating equipment has higher vibration) - controlled precision with degradation
        -- Vibration increases only after decay start date
        CASE 
            -- Rotating equipment
            WHEN asset_id IN (1,2,4,5,7,8,11,14,17) THEN ROUND(0.3 + (days_since_decay_start * 0.002) + UNIFORM(0, 0.4, RANDOM()), 2)
            -- Robots (less vibration)
            WHEN asset_id IN (10,13,16) THEN ROUND(0.1 + (days_since_decay_start * 0.001) + UNIFORM(0, 0.2, RANDOM()), 2)
            ELSE ROUND(0.05 + UNIFORM(0, 0.1, RANDOM()), 2)  -- Static equipment
        END as vibration_mm_s,
        
        -- Pressure data (only for pumps, compressors, and pneumatic systems) - controlled range
        CASE 
            WHEN asset_id IN (1,3,4,7,9,12) THEN ROUND(140 + UNIFORM(-5, 15, RANDOM()), 2)  -- Equipment with pressure sensors
            ELSE NULL
        END as pressure_psi,
        
        -- Health score (degrades over time with realistic variation) - range 10-100 for interesting insights
        -- Base health degrades with time ONLY after decay_start_date (90 days ago)
        -- Before decay start: assets are healthy (95-100)
        -- After decay start: gradual degradation over 90 days
        -- Decay rate: 0.3 per day over 90 days = ~27 points base decay + wide asset-specific variation
        -- This creates interesting ranges: critical (<50), warning (50-70), good (70-85), excellent (85+)
        ROUND(GREATEST(10, LEAST(100, 
            100 - (days_since_decay_start * 0.3) - (hour_of_day * 0.06) - 
            CASE 
                -- Critical pumps (heavily degraded)
                WHEN asset_id IN (1,7) THEN UNIFORM(25, 45, RANDOM())  -- Pumps worst condition (CRITICAL: 28-48 range)
                -- Warning pump (moderate issues)
                WHEN asset_id = 4 THEN UNIFORM(15, 30, RANDOM())  -- Pump with some issues (WARNING: 43-58 range)
                -- Critical/Warning motors (mixed conditions)
                WHEN asset_id IN (2,8,14) THEN UNIFORM(18, 38, RANDOM())  -- Motors with issues (WARNING-CRITICAL: 35-55 range)
                -- Good motors (well maintained)
                WHEN asset_id IN (5,11,17) THEN UNIFORM(0, 15, RANDOM())  -- Motors in good shape (GOOD: 58-73 range)
                -- Excellent robots (newest/best maintained)
                WHEN asset_id IN (10,16) THEN UNIFORM(-5, 5, RANDOM())  -- Robots excellent (EXCELLENT: 68-78 range)
                -- Good robot (reliable)
                WHEN asset_id = 13 THEN UNIFORM(0, 10, RANDOM())  -- Robot good condition (GOOD: 63-73 range)
                -- Critical/Warning other equipment
                WHEN asset_id IN (3,6,9,12,18) THEN UNIFORM(20, 40, RANDOM())  -- Conveyors/scanners mixed (WARNING-CRITICAL: 33-53 range)
                -- Good other equipment
                ELSE UNIFORM(5, 20, RANDOM())  -- Other equipment decent (GOOD: 53-68 range)
            END
        )), 2) as health_score
    FROM hourly_base
)
SELECT 
    asset_id,
    process_id,
    date_sk,
    recorded_at,
    temperature_c,
    vibration_mm_s,
    pressure_psi,
    health_score,
    
    -- Failure probability (inversely correlated with health score) - range 0.01 to 0.95
    -- Formula: low health (10) = high failure prob (0.95), high health (100) = low failure prob (0.01)
    -- Linear relationship: failure_prob = 0.01 + (100 - health_score) / 90 * 0.94
    -- This ensures health=10 gives 0.95 and health=100 gives 0.01
    ROUND(LEAST(0.95, GREATEST(0.01, 0.01 + (100 - health_score) / 90.0 * 0.94)), 2) as failure_probability,
    
    -- Remaining useful life (correlated with health score) - range 10 to 500 days
    -- Lower health = lower RUL, higher health = higher RUL
    -- Formula ensures RUL scales with health: health=10 gives ~55 days, health=100 gives ~500 days
    -- RUL decreases based on days since decay started
    GREATEST(10, ROUND((health_score / 100.0 * 500) - (days_since_decay_start * 0.5) - UNIFORM(0, 20, RANDOM()), 0))::INTEGER as rul_days,
    
    -- Mark as anomalous based on realistic thresholds
    CASE 
        WHEN health_score < 50 THEN TRUE  -- Health below 50 is concerning (failure prob > 0.48)
        WHEN asset_id IN (1,2,4,5,7,8,11,14,17) AND vibration_mm_s > 1.5 THEN TRUE  -- High vibration
        WHEN asset_id IN (1,4,7) AND temperature_c > 85 THEN TRUE  -- Overheating pumps
        ELSE FALSE
    END as is_anomalous
FROM sensor_data;

-- Maintenance Log (Dynamic generation from Nov 1, 2024 to current date)
-- Each asset gets maintenance events based on realistic frequencies:
-- - Preventive Maintenance (PM): Every 30 days
-- - Inspections: Every 15 days
-- - Predictive Maintenance: Every 20 days
-- - Emergency repairs: Randomly, 5% chance
INSERT INTO FCT_MAINTENANCE_LOG (ASSET_ID,
PROCESS_ID,
WO_TYPE_ID,
ACTION_DATE_SK,
COMPLETED_DATE,
DOWNTIME_HOURS,
PARTS_COST,
LABOR_COST,
FAILURE_FLAG,
TECHNICIAN_ID,
FAILURE_CODE_ID,
TECHNICIAN_NOTES)
WITH date_params AS (
    SELECT 
        '2024-11-01'::DATE AS start_date,
        CURRENT_DATE() AS end_date
),
daily_asset_base AS (
    SELECT 
        a.asset_id,
        a.process_id,
        DATEADD(DAY, d.day_seq, dp.start_date) as maint_date,
        d.day_seq,
        TO_NUMBER(TO_CHAR(DATEADD(DAY, d.day_seq, dp.start_date), 'YYYYMMDD')) as date_sk
    FROM date_params dp
    CROSS JOIN (
        SELECT 
            da.ASSET_ID,
            da.PROCESS_ID
        FROM SF_SOLUTIONS.SILVER.DIM_ASSET da
        WHERE da.IS_CURRENT = TRUE
    ) a
    CROSS JOIN (
        SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS day_seq
        FROM TABLE(GENERATOR(ROWCOUNT => 500))
    ) d
    WHERE DATEADD(DAY, d.day_seq, dp.start_date) <= dp.end_date
),
maintenance_events AS (
    SELECT 
        asset_id,
        process_id,
        maint_date,
        date_sk,
        day_seq,
        -- Determine work order type based on patterns
        CASE 
            WHEN MOD(day_seq, 30) = MOD(asset_id, 30) THEN 3  -- Preventive Maintenance every 30 days
            WHEN MOD(day_seq, 15) = MOD(asset_id, 15) THEN 4  -- Inspection every 15 days
            WHEN MOD(day_seq, 20) = MOD((asset_id * 2), 20) THEN 2  -- Predictive Maintenance every 20 days
            WHEN UNIFORM(0, 100, RANDOM()) < 2 THEN 1  -- 2% chance of emergency repair
            ELSE NULL
        END as wo_type_id,
        -- Assign technician (rotate through available technicians)
        MOD((asset_id + day_seq), 10) + 1 as technician_id
    FROM daily_asset_base
),
maint_with_details AS (
    SELECT 
        me.*,
        -- Downtime hours based on work order type
        CASE 
            WHEN wo_type_id = 1 THEN ROUND(4 + UNIFORM(0, 4, RANDOM()), 1)  -- Emergency: 4-8 hours
            WHEN wo_type_id = 2 THEN ROUND(1 + UNIFORM(0, 2, RANDOM()), 1)  -- Predictive: 1-3 hours
            WHEN wo_type_id = 3 THEN ROUND(2 + UNIFORM(0, 3, RANDOM()), 1)  -- Preventive: 2-5 hours
            WHEN wo_type_id = 4 THEN ROUND(0.5 + UNIFORM(0, 1, RANDOM()), 1)  -- Inspection: 0.5-1.5 hours
            ELSE 0
        END as downtime_hours,
        -- Parts cost
        CASE 
            WHEN wo_type_id = 1 THEN ROUND(300 + UNIFORM(0, 500, RANDOM()), 2)  -- Emergency: $300-800
            WHEN wo_type_id = 2 THEN ROUND(50 + UNIFORM(0, 150, RANDOM()), 2)   -- Predictive: $50-200
            WHEN wo_type_id = 3 THEN ROUND(100 + UNIFORM(0, 200, RANDOM()), 2)  -- Preventive: $100-300
            WHEN wo_type_id = 4 THEN ROUND(0 + UNIFORM(0, 50, RANDOM()), 2)     -- Inspection: $0-50
            ELSE 0
        END as parts_cost,
        -- Labor cost (based on downtime * hourly rate $150-200/hr)
        CASE 
            WHEN wo_type_id = 1 THEN ROUND((4 + UNIFORM(0, 4, RANDOM())) * 180, 2)
            WHEN wo_type_id = 2 THEN ROUND((1 + UNIFORM(0, 2, RANDOM())) * 160, 2)
            WHEN wo_type_id = 3 THEN ROUND((2 + UNIFORM(0, 3, RANDOM())) * 150, 2)
            WHEN wo_type_id = 4 THEN ROUND((0.5 + UNIFORM(0, 1, RANDOM())) * 140, 2)
            ELSE 0
        END as labor_cost,
        -- Failure flag and failure code (only for emergency repairs)
        CASE WHEN wo_type_id = 1 THEN TRUE ELSE FALSE END as failure_flag,
        CASE 
            WHEN wo_type_id = 1 THEN MOD((asset_id + day_seq), 12) + 1  -- Rotate through 12 failure codes
            ELSE NULL 
        END as failure_code_id,
        -- Notes based on work order type and asset
        CASE 
            WHEN wo_type_id = 1 THEN 'Emergency repair - ' || 
                CASE MOD(asset_id, 6)
                    WHEN 0 THEN 'bearing failure requiring immediate replacement'
                    WHEN 1 THEN 'unexpected shutdown due to overheating'
                    WHEN 2 THEN 'seal failure causing fluid leak'
                    WHEN 3 THEN 'electrical fault requiring repair'
                    WHEN 4 THEN 'mechanical failure requiring parts replacement'
                    ELSE 'critical component failure addressed'
                END
            WHEN wo_type_id = 2 THEN 'Predictive maintenance - ' || 
                CASE MOD(asset_id, 4)
                    WHEN 0 THEN 'proactive component replacement based on sensor data'
                    WHEN 1 THEN 'condition-based maintenance preventing failure'
                    WHEN 2 THEN 'vibration analysis indicated need for adjustment'
                    ELSE 'temperature trends suggested preventive action'
                END
            WHEN wo_type_id = 3 THEN 'Preventive maintenance - ' || 
                CASE MOD(asset_id, 4)
                    WHEN 0 THEN 'scheduled lubrication and inspection completed'
                    WHEN 1 THEN 'routine service and parts replacement per schedule'
                    WHEN 2 THEN 'planned maintenance activities completed'
                    ELSE 'standard PM tasks performed successfully'
                END
            WHEN wo_type_id = 4 THEN 'Routine inspection - ' || 
                CASE MOD(asset_id, 3)
                    WHEN 0 THEN 'visual inspection and sensor verification'
                    WHEN 1 THEN 'performance monitoring and calibration check'
                    ELSE 'standard inspection completed, no issues found'
                END
            ELSE 'Maintenance activity completed'
        END as technician_notes
    FROM maintenance_events me
    WHERE wo_type_id IS NOT NULL
)
SELECT 
    asset_id,
    process_id,
    wo_type_id,
    date_sk,
    maint_date as completed_date,
    downtime_hours,
    parts_cost,
    labor_cost,
    failure_flag,
    technician_id,
    failure_code_id,
    technician_notes
FROM maint_with_details;

-- Production Log (Daily production data for all assets from Nov 1, 2024 to current date)
-- Generates daily production metrics with realistic variations and maintenance impacts
INSERT INTO FCT_PRODUCTION_LOG (ASSET_ID,
PROCESS_ID,
DATE_SK,
PRODUCTION_DATE,
PLANNED_RUNTIME_HOURS,
ACTUAL_RUNTIME_HOURS,
UNITS_PRODUCED,
UNITS_SCRAPPED)
WITH date_params AS (
    SELECT 
        '2024-11-01'::DATE AS start_date,
        CURRENT_DATE() AS end_date
),
daily_production_base AS (
    SELECT 
        a.asset_id,
        a.process_id,
        DATEADD(DAY, d.day_seq, dp.start_date) as production_date,
        TO_NUMBER(TO_CHAR(DATEADD(DAY, d.day_seq, dp.start_date), 'YYYYMMDD')) as date_sk,
        d.day_seq,
        DAYOFWEEK(DATEADD(DAY, d.day_seq, dp.start_date)) as day_of_week
    FROM date_params dp
    CROSS JOIN (
        SELECT 
            da.ASSET_ID,
            da.PROCESS_ID
        FROM SF_SOLUTIONS.SILVER.DIM_ASSET da
        WHERE da.IS_CURRENT = TRUE
    ) a
    CROSS JOIN (
        SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS day_seq
        FROM TABLE(GENERATOR(ROWCOUNT => 500))
    ) d
    WHERE DATEADD(DAY, d.day_seq, dp.start_date) <= dp.end_date
),
production_with_maint AS (
    SELECT 
        pb.asset_id,
        pb.process_id,
        pb.production_date,
        pb.date_sk,
        pb.day_seq,
        pb.day_of_week,
        -- Check if there was maintenance on this day
        COALESCE(ml.downtime_hours, 0) as maint_downtime,
        COALESCE(ml.failure_flag, FALSE) as had_failure
    FROM daily_production_base pb
    LEFT JOIN SF_SOLUTIONS.SILVER.FCT_MAINTENANCE_LOG ml 
        ON pb.asset_id = ml.asset_id 
        AND pb.date_sk = ml.action_date_sk
)
SELECT 
    asset_id,
    process_id,
    date_sk,
    production_date,
    -- Planned runtime varies by asset class
    CASE 
        WHEN asset_id IN (1,2,3,4,5,6,7,8,9) THEN 24.0  -- Davidson plant runs 24/7
        WHEN asset_id IN (10,11,12,13,14,15) THEN 20.0  -- Charlotte Assembly line 1&2
        ELSE 18.0  -- Charlotte Assembly line 3
    END as planned_runtime_hours,
    -- Actual runtime (reduced by maintenance and random variations)
    CASE 
        WHEN asset_id IN (1,2,3,4,5,6,7,8,9) THEN 
            GREATEST(0, ROUND(24.0 - maint_downtime - UNIFORM(0, 1.5, RANDOM()), 1))
        WHEN asset_id IN (10,11,12,13,14,15) THEN 
            GREATEST(0, ROUND(20.0 - maint_downtime - UNIFORM(0, 1.2, RANDOM()), 1))
        ELSE 
            GREATEST(0, ROUND(18.0 - maint_downtime - UNIFORM(0, 1.0, RANDOM()), 1))
    END as actual_runtime_hours,
    -- Units produced (based on asset capacity and actual runtime)
    CASE 
        WHEN asset_id IN (1,2,3,4,5,6,7,8,9) THEN 
            ROUND((24.0 - maint_downtime - UNIFORM(0, 1.5, RANDOM())) * 
                CASE asset_id
                    WHEN 1 THEN 50  -- Primary Coolant Pump: 50 units/hr
                    WHEN 2 THEN 100  -- Conveyor Drive Motor: 100 units/hr
                    WHEN 3 THEN 48  -- Air Compressor: 48 units/hr
                    WHEN 4 THEN 49  -- Hydraulic Pump: 49 units/hr
                    WHEN 5 THEN 50  -- Main Drive Motor: 50 units/hr
                    WHEN 6 THEN 50  -- Cooling Fan: 50 units/hr
                    WHEN 7 THEN 48  -- Process Circulation Pump: 48 units/hr
                    WHEN 8 THEN 49  -- Conveyor Motor Assembly: 49 units/hr
                    ELSE 49  -- Control Valve System: 49 units/hr
                END, 0)::INTEGER
        WHEN asset_id IN (10,11,12,13,14,15) THEN 
            ROUND((20.0 - maint_downtime - UNIFORM(0, 1.2, RANDOM())) * 
                CASE asset_id
                    WHEN 10 THEN 50  -- Assembly Robot: 50 units/hr
                    WHEN 11 THEN 49  -- Conveyor Drive System: 49 units/hr
                    WHEN 12 THEN 48  -- Pneumatic Press: 48 units/hr
                    WHEN 13 THEN 50  -- Welding Robot: 50 units/hr
                    WHEN 14 THEN 49  -- Material Handling Motor: 49 units/hr
                    ELSE 46  -- Heat Treatment Furnace: 46 units/hr (slower process)
                END, 0)::INTEGER
        ELSE 
            ROUND((18.0 - maint_downtime - UNIFORM(0, 1.0, RANDOM())) * 
                CASE asset_id
                    WHEN 16 THEN 50  -- Packaging Robot: 50 units/hr
                    WHEN 17 THEN 49  -- Sorting System Motor: 49 units/hr
                    ELSE 50  -- Quality Control Scanner: 50 units/hr
                END, 0)::INTEGER
    END as units_produced,
    -- Units scrapped (higher if there was a failure, normal quality issues otherwise)
    CASE 
        WHEN had_failure THEN ROUND(UNIFORM(20, 50, RANDOM()), 0)::INTEGER
        ELSE ROUND(UNIFORM(3, 15, RANDOM()), 0)::INTEGER
    END as units_scrapped
FROM production_with_maint;

-- Maintenance Parts Used (Links maintenance events to materials consumed)
-- Generates realistic parts usage for each maintenance event based on work order type
INSERT INTO FCT_MAINTENANCE_PARTS_USED (LOG_ID, MATERIAL_ID, QUANTITY_USED, TOTAL_COST)
WITH maintenance_logs_with_seq AS (
    SELECT 
        ml.LOG_ID,
        ml.WO_TYPE_ID,
        ml.ASSET_ID,
        ml.PARTS_COST,
        ROW_NUMBER() OVER (ORDER BY ml.LOG_ID) as log_seq
    FROM SF_SOLUTIONS.SILVER.FCT_MAINTENANCE_LOG ml
),
parts_per_maint AS (
    SELECT 
        ml.LOG_ID,
        ml.WO_TYPE_ID,
        ml.ASSET_ID,
        ml.PARTS_COST,
        -- Determine number of parts used based on work order type
        CASE 
            WHEN ml.WO_TYPE_ID = 1 THEN UNIFORM(2, 5, RANDOM())  -- Emergency: 2-5 parts
            WHEN ml.WO_TYPE_ID = 2 THEN UNIFORM(1, 3, RANDOM())  -- Predictive: 1-3 parts
            WHEN ml.WO_TYPE_ID = 3 THEN UNIFORM(2, 4, RANDOM())  -- Preventive: 2-4 parts
            WHEN ml.WO_TYPE_ID = 4 THEN UNIFORM(0, 2, RANDOM())  -- Inspection: 0-2 parts
            ELSE 1
        END as num_parts
    FROM maintenance_logs_with_seq ml
),
parts_expanded AS (
    SELECT 
        pm.LOG_ID,
        pm.WO_TYPE_ID,
        pm.ASSET_ID,
        pm.PARTS_COST,
        p.part_seq
    FROM parts_per_maint pm
    CROSS JOIN (
        SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) as part_seq
        FROM TABLE(GENERATOR(ROWCOUNT => 10))
    ) p
    WHERE p.part_seq <= pm.num_parts
)
SELECT 
    pe.LOG_ID,
    -- Select material based on work order type and asset
    CASE 
        WHEN pe.WO_TYPE_ID = 1 THEN  -- Emergency repairs use critical parts
            CASE MOD((pe.ASSET_ID + pe.part_seq), 8)
                WHEN 0 THEN 2   -- Heavy duty bearing
                WHEN 1 THEN 4   -- Mechanical seal
                WHEN 2 THEN 10  -- Servo motor
                WHEN 3 THEN 16  -- Pump impeller
                WHEN 4 THEN 14  -- Coupling
                WHEN 5 THEN 13  -- Solenoid valve
                WHEN 6 THEN 12  -- Vibration sensor
                ELSE 11         -- Temperature sensor
            END
        WHEN pe.WO_TYPE_ID = 2 THEN  -- Predictive maintenance
            CASE MOD((pe.ASSET_ID + pe.part_seq), 6)
                WHEN 0 THEN 1   -- Standard bearing
                WHEN 1 THEN 3   -- Oil seal
                WHEN 2 THEN 5   -- Belt
                WHEN 3 THEN 14  -- Coupling
                WHEN 4 THEN 11  -- Temperature sensor
                ELSE 8          -- Synthetic oil
            END
        WHEN pe.WO_TYPE_ID = 3 THEN  -- Preventive maintenance
            CASE MOD((pe.ASSET_ID + pe.part_seq), 7)
                WHEN 0 THEN 6   -- Hydraulic filter
                WHEN 1 THEN 7   -- Air filter
                WHEN 2 THEN 8   -- Gear oil
                WHEN 3 THEN 9   -- Hydraulic oil
                WHEN 4 THEN 20  -- Grease
                WHEN 5 THEN 15  -- Gasket
                ELSE 3          -- Oil seal
            END
        ELSE  -- Inspections use minimal parts
            CASE MOD((pe.ASSET_ID + pe.part_seq), 4)
                WHEN 0 THEN 19  -- Fuse
                WHEN 1 THEN 20  -- Grease
                WHEN 2 THEN 15  -- Gasket
                ELSE 8          -- Oil
            END
    END as material_id,
    -- Quantity varies by part type
    CASE 
        WHEN pe.WO_TYPE_ID = 1 THEN ROUND(UNIFORM(1, 3, RANDOM()), 1)  -- Emergency: 1-3 units
        WHEN pe.WO_TYPE_ID = 2 THEN ROUND(UNIFORM(1, 2, RANDOM()), 1)  -- Predictive: 1-2 units
        WHEN pe.WO_TYPE_ID = 3 THEN ROUND(UNIFORM(1, 2, RANDOM()), 1)  -- Preventive: 1-2 units
        ELSE 1  -- Inspection: 1 unit
    END as quantity_used,
    -- Calculate cost based on material and quantity
    ROUND(
        CASE 
            WHEN pe.WO_TYPE_ID = 1 THEN UNIFORM(1, 3, RANDOM())
            WHEN pe.WO_TYPE_ID = 2 THEN UNIFORM(1, 2, RANDOM())
            WHEN pe.WO_TYPE_ID = 3 THEN UNIFORM(1, 2, RANDOM())
            ELSE 1
        END * 
        -- Approximate cost per material (simplified for dynamic generation)
        CASE MOD((pe.ASSET_ID + pe.part_seq), 20) + 1
            WHEN 1 THEN 25.50
            WHEN 2 THEN 85.00
            WHEN 3 THEN 12.75
            WHEN 4 THEN 145.00
            WHEN 5 THEN 18.50
            WHEN 6 THEN 42.00
            WHEN 7 THEN 38.50
            WHEN 8 THEN 55.00
            WHEN 9 THEN 95.00
            WHEN 10 THEN 850.00
            WHEN 11 THEN 75.00
            WHEN 12 THEN 425.00
            WHEN 13 THEN 165.00
            WHEN 14 THEN 95.00
            WHEN 15 THEN 22.00
            WHEN 16 THEN 320.00
            WHEN 17 THEN 85.00
            WHEN 18 THEN 45.00
            WHEN 19 THEN 8.50
            ELSE 15.75
        END
    , 2) as total_cost
FROM parts_expanded pe;

-- Insert into GOLD Layer
USE SCHEMA SF_SOLUTIONS.GOLD;

-- AGG_ASSET_HOURLY_HEALTH: Aggregated hourly health metrics from telemetry data
INSERT INTO AGG_ASSET_HOURLY_HEALTH (HOUR_TIMESTAMP,
ASSET_ID,
AVG_TEMPERATURE_C,
MAX_VIBRATION_MM_S,
STDDEV_PRESSURE_PSI,
LATEST_HEALTH_SCORE,
AVG_FAILURE_PROBABILITY,
MIN_RUL_DAYS)
SELECT 
    DATE_TRUNC('HOUR', t.RECORDED_AT) as hour_timestamp,
    t.ASSET_ID,
    ROUND(AVG(t.TEMPERATURE_C), 2) as avg_temperature_c,
    ROUND(MAX(t.VIBRATION_MM_S), 2) as max_vibration_mm_s,
    ROUND(STDDEV(t.PRESSURE_PSI), 2) as stddev_pressure_psi,
    -- Get the latest health score within the hour
    MAX(t.HEALTH_SCORE) as latest_health_score,
    ROUND(AVG(t.FAILURE_PROBABILITY), 2) as avg_failure_probability,
    MIN(t.RUL_DAYS) as min_rul_days
FROM SF_SOLUTIONS.SILVER.FCT_ASSET_TELEMETRY t
WHERE t.RECORDED_AT >= '2024-11-01 00:00:00'::TIMESTAMP_NTZ
GROUP BY 
    DATE_TRUNC('HOUR', t.RECORDED_AT),
    t.ASSET_ID
ORDER BY hour_timestamp, asset_id;

-- ML_FEATURE_STORE: Daily feature store for machine learning models
INSERT INTO ML_FEATURE_STORE (OBSERVATION_DATE_SK,
ASSET_ID,
AVG_TEMP_LAST_24H,
VIBRATION_STDDEV_7D,
PRESSURE_TREND_7D,
CYCLES_SINCE_LAST_PM,
DAYS_SINCE_LAST_FAILURE,
OEM_FAILURE_RATE_EST,
DOWNTIME_IMPACT_RISK,
FAILED_IN_NEXT_7_DAYS)
WITH daily_observations AS (
    SELECT DISTINCT
        t.DATE_SK as observation_date_sk,
        t.ASSET_ID,
        t.RECORDED_AT::DATE as observation_date
    FROM SF_SOLUTIONS.SILVER.FCT_ASSET_TELEMETRY t
    WHERE t.RECORDED_AT >= '2024-11-01'::DATE
),
temp_features AS (
    SELECT 
        do.observation_date_sk,
        do.ASSET_ID,
        ROUND(AVG(t.TEMPERATURE_C), 2) as avg_temp_last_24h
    FROM daily_observations do
    JOIN SF_SOLUTIONS.SILVER.FCT_ASSET_TELEMETRY t 
        ON do.ASSET_ID = t.ASSET_ID
        AND t.RECORDED_AT >= DATEADD(HOUR, -24, do.observation_date::TIMESTAMP_NTZ)
        AND t.RECORDED_AT < DATEADD(DAY, 1, do.observation_date::TIMESTAMP_NTZ)
    GROUP BY do.observation_date_sk, do.ASSET_ID
),
vibration_features AS (
    SELECT 
        do.observation_date_sk,
        do.ASSET_ID,
        ROUND(STDDEV(t.VIBRATION_MM_S), 2) as vibration_stddev_7d
    FROM daily_observations do
    JOIN SF_SOLUTIONS.SILVER.FCT_ASSET_TELEMETRY t 
        ON do.ASSET_ID = t.ASSET_ID
        AND t.RECORDED_AT >= DATEADD(DAY, -7, do.observation_date::TIMESTAMP_NTZ)
        AND t.RECORDED_AT < DATEADD(DAY, 1, do.observation_date::TIMESTAMP_NTZ)
    GROUP BY do.observation_date_sk, do.ASSET_ID
),
pressure_features AS (
    SELECT 
        do.observation_date_sk,
        do.ASSET_ID,
        ROUND(
            (MAX(t.PRESSURE_PSI) - MIN(t.PRESSURE_PSI)) / NULLIF(COUNT(*), 0), 
        2) as pressure_trend_7d
    FROM daily_observations do
    JOIN SF_SOLUTIONS.SILVER.FCT_ASSET_TELEMETRY t 
        ON do.ASSET_ID = t.ASSET_ID
        AND t.RECORDED_AT >= DATEADD(DAY, -7, do.observation_date::TIMESTAMP_NTZ)
        AND t.RECORDED_AT < DATEADD(DAY, 1, do.observation_date::TIMESTAMP_NTZ)
        AND t.PRESSURE_PSI IS NOT NULL
    GROUP BY do.observation_date_sk, do.ASSET_ID
),
maintenance_features AS (
    SELECT 
        do.observation_date_sk,
        do.ASSET_ID,
        do.observation_date,
        -- Days since last preventive maintenance
        COALESCE(DATEDIFF(DAY, 
            MAX(CASE WHEN ml.WO_TYPE_ID = 3 THEN ml.COMPLETED_DATE END), 
            do.observation_date), 
        999) as days_since_last_pm,
        -- Days since last failure
        COALESCE(DATEDIFF(DAY, 
            MAX(CASE WHEN ml.FAILURE_FLAG = TRUE THEN ml.COMPLETED_DATE END), 
            do.observation_date), 
        999) as days_since_last_failure
    FROM daily_observations do
    LEFT JOIN SF_SOLUTIONS.SILVER.FCT_MAINTENANCE_LOG ml 
        ON do.ASSET_ID = ml.ASSET_ID
        AND ml.COMPLETED_DATE < do.observation_date
    GROUP BY do.observation_date_sk, do.ASSET_ID, do.observation_date
),
future_failures AS (
    SELECT 
        do.observation_date_sk,
        do.ASSET_ID,
        -- Check if there was a failure in the next 7 days
        MAX(CASE 
            WHEN ml.FAILURE_FLAG = TRUE 
                AND ml.COMPLETED_DATE > do.observation_date 
                AND ml.COMPLETED_DATE <= DATEADD(DAY, 7, do.observation_date)
            THEN TRUE 
            ELSE FALSE 
        END) as failed_in_next_7_days
    FROM daily_observations do
    LEFT JOIN SF_SOLUTIONS.SILVER.FCT_MAINTENANCE_LOG ml 
        ON do.ASSET_ID = ml.ASSET_ID
    GROUP BY do.observation_date_sk, do.ASSET_ID
)
SELECT 
    do.observation_date_sk,
    do.ASSET_ID,
    tf.avg_temp_last_24h,
    vf.vibration_stddev_7d,
    pf.pressure_trend_7d,
    -- Cycles approximation (hours * 60 for cycles per hour estimate)
    GREATEST(0, mf.days_since_last_pm * 24 * 50) as cycles_since_last_pm,
    mf.days_since_last_failure,
    -- OEM failure rate estimate (based on asset age and type)
    ROUND(0.08 + UNIFORM(0, 0.12, RANDOM()), 2) as oem_failure_rate_est,
    -- Downtime impact risk (health score * downtime impact per hour)
    ROUND(
        (100 - COALESCE(h.latest_health_score, 95)) * a.DOWNTIME_IMPACT_PER_HOUR,
    2) as downtime_impact_risk,
    ff.failed_in_next_7_days
FROM daily_observations do
LEFT JOIN temp_features tf ON do.observation_date_sk = tf.observation_date_sk AND do.ASSET_ID = tf.ASSET_ID
LEFT JOIN vibration_features vf ON do.observation_date_sk = vf.observation_date_sk AND do.ASSET_ID = vf.ASSET_ID
LEFT JOIN pressure_features pf ON do.observation_date_sk = pf.observation_date_sk AND do.ASSET_ID = pf.ASSET_ID
LEFT JOIN maintenance_features mf ON do.observation_date_sk = mf.observation_date_sk AND do.ASSET_ID = mf.ASSET_ID
LEFT JOIN future_failures ff ON do.observation_date_sk = ff.observation_date_sk AND do.ASSET_ID = ff.ASSET_ID
LEFT JOIN SF_SOLUTIONS.SILVER.DIM_ASSET a ON do.ASSET_ID = a.ASSET_ID
LEFT JOIN (
    SELECT 
        ASSET_ID,
        DATE_SK,
        MAX(HEALTH_SCORE) as latest_health_score
    FROM SF_SOLUTIONS.SILVER.FCT_ASSET_TELEMETRY
    GROUP BY ASSET_ID, DATE_SK
) h ON do.ASSET_ID = h.ASSET_ID AND do.observation_date_sk = h.DATE_SK
WHERE do.observation_date >= '2024-11-01'::DATE
ORDER BY do.observation_date_sk, do.ASSET_ID;

-- AGG_DAILY_OEE: Daily OEE calculations for each asset
INSERT INTO AGG_DAILY_OEE (
    PRODUCTION_DATE, DATE_SK, ASSET_ID, PROCESS_ID,
    AVAILABILITY_PERCENT, PERFORMANCE_PERCENT, QUALITY_PERCENT, OEE_PERCENT,
    PLANNED_RUNTIME_HOURS, ACTUAL_RUNTIME_HOURS, UNITS_PRODUCED, UNITS_SCRAPPED, GOOD_UNITS
)
SELECT 
    pl.PRODUCTION_DATE,
    pl.DATE_SK,
    pl.ASSET_ID,
    pl.PROCESS_ID,
    -- Availability: (Actual Runtime / Planned Runtime) × 100
    ROUND(CASE 
        WHEN pl.PLANNED_RUNTIME_HOURS > 0 
        THEN (pl.ACTUAL_RUNTIME_HOURS / pl.PLANNED_RUNTIME_HOURS) * 100 
        ELSE 0 
    END, 2) AS availability_percent,
    -- Performance: Assume 80-98% of theoretical max (adding realistic variation)
    ROUND(UNIFORM(80, 98, RANDOM()), 2) AS performance_percent,
    -- Quality: (Good Units / Total Units) × 100
    ROUND(CASE 
        WHEN pl.UNITS_PRODUCED > 0 
        THEN ((pl.UNITS_PRODUCED - pl.UNITS_SCRAPPED) / pl.UNITS_PRODUCED) * 100 
        ELSE 0 
    END, 2) AS quality_percent,
    -- OEE: Availability × Performance × Quality (as decimal multiplication, then × 100)
    ROUND(
        CASE 
            WHEN pl.PLANNED_RUNTIME_HOURS > 0 AND pl.UNITS_PRODUCED > 0
            THEN (pl.ACTUAL_RUNTIME_HOURS / pl.PLANNED_RUNTIME_HOURS) * 
                 (UNIFORM(80, 98, RANDOM()) / 100) * 
                 ((pl.UNITS_PRODUCED - pl.UNITS_SCRAPPED) / pl.UNITS_PRODUCED) * 100
            ELSE 0 
        END, 2
    ) AS oee_percent,
    pl.PLANNED_RUNTIME_HOURS,
    pl.ACTUAL_RUNTIME_HOURS,
    pl.UNITS_PRODUCED,
    pl.UNITS_SCRAPPED,
    pl.UNITS_PRODUCED - pl.UNITS_SCRAPPED AS good_units
FROM SF_SOLUTIONS.SILVER.FCT_PRODUCTION_LOG pl
WHERE pl.PRODUCTION_DATE >= '2024-11-01'::DATE
ORDER BY pl.PRODUCTION_DATE, pl.ASSET_ID;

-- AGG_MONTHLY_TRENDS: Monthly aggregations for OEE vs Maintenance Cost trending
INSERT INTO AGG_MONTHLY_TRENDS (
    YEAR_MONTH, YEAR, MONTH, PLANT_ID, LINE_ID, PROCESS_ID,
    AVG_OEE_PERCENT, MIN_OEE_PERCENT, MAX_OEE_PERCENT,
    AVG_AVAILABILITY_PERCENT, AVG_PERFORMANCE_PERCENT, AVG_QUALITY_PERCENT,
    TOTAL_MAINTENANCE_COST, TOTAL_PARTS_COST, TOTAL_LABOR_COST,
    TOTAL_DOWNTIME_HOURS, PREVENTIVE_WO_COUNT, PREDICTIVE_WO_COUNT, EMERGENCY_WO_COUNT, FAILURE_COUNT,
    TOTAL_UNITS_PRODUCED, TOTAL_UNITS_SCRAPPED, ASSET_COUNT
)
WITH monthly_oee AS (
    SELECT 
        TO_CHAR(oee.PRODUCTION_DATE, 'YYYY-MM') as year_month,
        YEAR(oee.PRODUCTION_DATE) as year,
        MONTH(oee.PRODUCTION_DATE) as month,
        l.PLANT_ID,
        p.LINE_ID,
        oee.PROCESS_ID,
        AVG(oee.OEE_PERCENT) as avg_oee_percent,
        MIN(oee.OEE_PERCENT) as min_oee_percent,
        MAX(oee.OEE_PERCENT) as max_oee_percent,
        AVG(oee.AVAILABILITY_PERCENT) as avg_availability_percent,
        AVG(oee.PERFORMANCE_PERCENT) as avg_performance_percent,
        AVG(oee.QUALITY_PERCENT) as avg_quality_percent,
        SUM(oee.UNITS_PRODUCED) as total_units_produced,
        SUM(oee.UNITS_SCRAPPED) as total_units_scrapped,
        COUNT(DISTINCT oee.ASSET_ID) as asset_count
    FROM SF_SOLUTIONS.GOLD.AGG_DAILY_OEE oee
    JOIN SF_SOLUTIONS.SILVER.DIM_ASSET a ON oee.ASSET_ID = a.ASSET_ID AND a.IS_CURRENT = TRUE
    JOIN SF_SOLUTIONS.SILVER.DIM_PROCESS p ON oee.PROCESS_ID = p.PROCESS_ID
    JOIN SF_SOLUTIONS.SILVER.DIM_LINE l ON p.LINE_ID = l.LINE_ID
    WHERE oee.PRODUCTION_DATE >= '2024-11-01'::DATE
    GROUP BY 
        TO_CHAR(oee.PRODUCTION_DATE, 'YYYY-MM'),
        YEAR(oee.PRODUCTION_DATE),
        MONTH(oee.PRODUCTION_DATE),
        l.PLANT_ID,
        p.LINE_ID,
        oee.PROCESS_ID
),
monthly_maintenance AS (
    SELECT 
        TO_CHAR(ml.COMPLETED_DATE, 'YYYY-MM') as year_month,
        l.PLANT_ID,
        p.LINE_ID,
        ml.PROCESS_ID,
        SUM(ml.PARTS_COST + ml.LABOR_COST) as total_maintenance_cost,
        SUM(ml.PARTS_COST) as total_parts_cost,
        SUM(ml.LABOR_COST) as total_labor_cost,
        SUM(ml.DOWNTIME_HOURS) as total_downtime_hours,
        SUM(CASE WHEN ml.WO_TYPE_ID = 3 THEN 1 ELSE 0 END) as preventive_wo_count,
        SUM(CASE WHEN ml.WO_TYPE_ID = 2 THEN 1 ELSE 0 END) as predictive_wo_count,
        SUM(CASE WHEN ml.WO_TYPE_ID = 1 THEN 1 ELSE 0 END) as emergency_wo_count,
        SUM(CASE WHEN ml.FAILURE_FLAG = TRUE THEN 1 ELSE 0 END) as failure_count
    FROM SF_SOLUTIONS.SILVER.FCT_MAINTENANCE_LOG ml
    JOIN SF_SOLUTIONS.SILVER.DIM_ASSET a ON ml.ASSET_ID = a.ASSET_ID AND a.IS_CURRENT = TRUE
    JOIN SF_SOLUTIONS.SILVER.DIM_PROCESS p ON ml.PROCESS_ID = p.PROCESS_ID
    JOIN SF_SOLUTIONS.SILVER.DIM_LINE l ON p.LINE_ID = l.LINE_ID
    WHERE ml.COMPLETED_DATE >= '2024-11-01'::DATE
    GROUP BY 
        TO_CHAR(ml.COMPLETED_DATE, 'YYYY-MM'),
        l.PLANT_ID,
        p.LINE_ID,
        ml.PROCESS_ID
)
SELECT 
    oee.year_month,
    oee.year,
    oee.month,
    oee.plant_id,
    oee.line_id,
    oee.process_id,
    ROUND(oee.avg_oee_percent, 2) as avg_oee_percent,
    ROUND(oee.min_oee_percent, 2) as min_oee_percent,
    ROUND(oee.max_oee_percent, 2) as max_oee_percent,
    ROUND(oee.avg_availability_percent, 2) as avg_availability_percent,
    ROUND(oee.avg_performance_percent, 2) as avg_performance_percent,
    ROUND(oee.avg_quality_percent, 2) as avg_quality_percent,
    COALESCE(maint.total_maintenance_cost, 0) as total_maintenance_cost,
    COALESCE(maint.total_parts_cost, 0) as total_parts_cost,
    COALESCE(maint.total_labor_cost, 0) as total_labor_cost,
    COALESCE(maint.total_downtime_hours, 0) as total_downtime_hours,
    COALESCE(maint.preventive_wo_count, 0) as preventive_wo_count,
    COALESCE(maint.predictive_wo_count, 0) as predictive_wo_count,
    COALESCE(maint.emergency_wo_count, 0) as emergency_wo_count,
    COALESCE(maint.failure_count, 0) as failure_count,
    oee.total_units_produced,
    oee.total_units_scrapped,
    oee.asset_count
FROM monthly_oee oee
LEFT JOIN monthly_maintenance maint 
    ON oee.year_month = maint.year_month 
    AND oee.plant_id = maint.plant_id 
    AND oee.line_id = maint.line_id 
    AND oee.process_id = maint.process_id
ORDER BY oee.year_month, oee.plant_id, oee.line_id;

/*************************************************************************************************/
-- Step 3: Create Stage and Semantic View for Cortex Analyst
/*************************************************************************************************/

USE SCHEMA SF_SOLUTIONS.GOLD;

-- Create a stage for uploading the semantic view definition
CREATE STAGE IF NOT EXISTS SEMANTIC_VIEW_STAGE
  DIRECTORY = ( ENABLE = TRUE )
  COMMENT = 'Stage for semantic view YAML definitions';

CREATE STAGE IF NOT EXISTS STREAMLIT_STAGE
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Stage for Streamlit application files';

-- Note: The YAML file upload and semantic view creation are handled by the deploy.sh script
-- This ensures proper file staging and semantic view creation in the correct sequence

SELECT 'SF_SOLUTIONS database, data, and Cortex Analyst semantic view created successfully.' AS status;

CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML('SF_SOLUTIONS.GOLD',
$$
name: SF_SOLUTIONS_SV
verified_queries:
  - name: oee_vs_maintenance_cost_12_month_trend
    question: "Show me the trend of our OEE versus our total maintenance cost over the last 12 months"
    sql: |
      SELECT 
        year_month,
        year,
        month,
        AVG(avg_oee_percent) as avg_oee_percent,
        SUM(total_maintenance_cost) as total_maintenance_cost,
        SUM(total_parts_cost) as total_parts_cost,
        SUM(total_labor_cost) as total_labor_cost,
        SUM(total_downtime_hours) as total_downtime_hours,
        SUM(failure_count) as total_failures,
        SUM(preventive_wo_count) as total_preventive_work_orders,
        SUM(predictive_wo_count) as total_predictive_work_orders,
        SUM(emergency_wo_count) as total_emergency_work_orders,
        SUM(total_units_produced) as total_units_produced,
        SUM(total_units_scrapped) as total_units_scrapped,
        SUM(asset_count) as total_assets
      FROM SF_SOLUTIONS.GOLD.AGG_MONTHLY_TRENDS
      WHERE year_month >= TO_CHAR(DATEADD(month, -12, DATE_TRUNC('month', CURRENT_DATE)), 'YYYY-MM')
        AND year_month <= TO_CHAR(DATE_TRUNC('month', CURRENT_DATE), 'YYYY-MM')
      GROUP BY year_month, year, month
      ORDER BY year_month ASC
tables:
  - name: AGG_ASSET_HOURLY_HEALTH
    base_table:
      database: SF_SOLUTIONS
      schema: GOLD
      table: AGG_ASSET_HOURLY_HEALTH
    dimensions:
      - name: ASSET_ID
        description: Unique identifier for an asset, used to track and monitor its health and performance over time.
        expr: ASSET_ID
        data_type: NUMBER(38,0)
        sample_values:
          - '1'
          - '2'
    time_dimensions:
      - name: HOUR_TIMESTAMP
        description: The timestamp representing the hour for which the asset health data is aggregated.
        expr: HOUR_TIMESTAMP
        data_type: TIMESTAMP_NTZ(9)
        sample_values:
          - 2025-09-22T10:00:00.000+0000
          - 2025-09-22T11:00:00.000+0000
          - 2025-09-23T08:00:00.000+0000
    facts:
      - name: AVG_FAILURE_PROBABILITY
        description: >-
          The average probability of an asset failing within a given hour, expressed as a decimal value between 0 and 1, where 0
          represents no probability of failure and 1 represents a 100% probability of failure.
        expr: AVG_FAILURE_PROBABILITY
        data_type: NUMBER(3,2)
        sample_values:
          - '0.03'
          - '0.85'
          - '0.02'
      - name: AVG_TEMPERATURE_C
        description: The average temperature in degrees Celsius of the asset over a one-hour period.
        expr: AVG_TEMPERATURE_C
        data_type: FLOAT
        sample_values:
          - '66.1'
          - '75.8'
          - '65.2'
      - name: LATEST_HEALTH_SCORE
        description: >-
          The LATEST_HEALTH_SCORE column represents the most recent health score of an asset, measured as a percentage,
          indicating the asset's current performance and operational status, with higher scores indicating better health.
        expr: LATEST_HEALTH_SCORE
        data_type: NUMBER(5,2)
        sample_values:
          - '98.50'
          - '98.20'
          - '35.10'
      - name: MAX_VIBRATION_MM_S
        description: Maximum vibration measured in millimeters per second.
        expr: MAX_VIBRATION_MM_S
        data_type: FLOAT
        sample_values:
          - '0.51'
          - '0.55'
          - '2.15'
      - name: MIN_RUL_DAYS
        description: >-
          Minimum Remaining Useful Life in Days, representing the estimated number of days until the asset is expected to reach
          the end of its useful life.
        expr: MIN_RUL_DAYS
        data_type: NUMBER(5,0)
        sample_values:
          - '365'
          - '364'
          - '400'
      - name: STDDEV_PRESSURE_PSI
        description: >-
          Standard Deviation of Pressure in Pounds per Square Inch, representing the variability of pressure readings for an
          asset over a one-hour period.
        expr: STDDEV_PRESSURE_PSI
        data_type: FLOAT
        sample_values:
          - '1.2'
          - '1.1'
          - '5.8'
  - name: ML_FEATURE_STORE
    base_table:
      database: SF_SOLUTIONS
      schema: GOLD
      table: ML_FEATURE_STORE
    dimensions:
      - name: FAILED_IN_NEXT_7_DAYS
        description: Indicates whether the customer failed to make a payment within the next 7 days from the current date.
        expr: FAILED_IN_NEXT_7_DAYS
        data_type: BOOLEAN
        sample_values:
          - 'FALSE'
          - 'TRUE'
    facts:
      - name: ASSET_ID
        description: >-
          Unique identifier for a financial asset, such as a stock, bond, or commodity, used to track and analyze its performance
          and characteristics within the machine learning feature store.
        expr: ASSET_ID
        data_type: NUMBER(38,0)
        sample_values:
          - '1'
          - '2'
      - name: AVG_TEMP_LAST_24H
        description: The average temperature over the last 24 hours.
        expr: AVG_TEMP_LAST_24H
        data_type: FLOAT
        sample_values:
          - '71.5'
          - '68.8'
      - name: CYCLES_SINCE_LAST_PM
        description: The number of production cycles that have occurred since the last planned maintenance (PM) event.
        expr: CYCLES_SINCE_LAST_PM
        data_type: NUMBER(38,0)
        sample_values:
          - '12000'
          - '8500'
      - name: DAYS_SINCE_LAST_FAILURE
        description: The number of days since the last time a failure occurred.
        expr: DAYS_SINCE_LAST_FAILURE
        data_type: NUMBER(38,0)
        sample_values:
          - '365'
          - '180'
      - name: DOWNTIME_IMPACT_RISK
        description: >-
          The estimated financial impact of downtime on the organization, representing the potential loss in dollars per hour of
          system unavailability.
        expr: DOWNTIME_IMPACT_RISK
        data_type: NUMBER(12,2)
        sample_values:
          - '20000.00'
          - '63750.00'
      - name: OBSERVATION_DATE_SK
        description: Unique identifier for the date of observation, in the format YYYYMMDD, used to track and analyze data over time.
        expr: OBSERVATION_DATE_SK
        data_type: NUMBER(8,0)
        sample_values:
          - '20250923'
      - name: OEM_FAILURE_RATE_EST
        description: >-
          Estimated rate of failures for original equipment manufacturer (OEM) parts, expressed as a decimal value between 0 and
          1, where 0 represents no failures and 1 represents 100% failures.
        expr: OEM_FAILURE_RATE_EST
        data_type: FLOAT
        sample_values:
          - '0.15'
          - '0.08'
      - name: PRESSURE_TREND_7D
        description: The average rate of change in pressure over the last 7 days.
        expr: PRESSURE_TREND_7D
        data_type: FLOAT
        sample_values:
          - '2.3'
      - name: VIBRATION_STDDEV_7D
        description: >-
          The standard deviation of vibration measurements over a 7-day period, indicating the variability or consistency of
          vibration levels over time.
        expr: VIBRATION_STDDEV_7D
        data_type: FLOAT
        sample_values:
          - '0.87'
          - '0.12'
  - name: AGG_DAILY_OEE
    base_table:
      database: SF_SOLUTIONS
      schema: GOLD
      table: AGG_DAILY_OEE
    dimensions:
      - name: PRODUCTION_DATE
        description: The date on which production occurred.
        expr: PRODUCTION_DATE
        data_type: DATE
        sample_values:
          - '2024-11-01'
          - '2024-12-15'
      - name: DATE_SK
        description: Date surrogate key in YYYYMMDD format.
        expr: DATE_SK
        data_type: NUMBER(8,0)
        sample_values:
          - '20241101'
          - '20241215'
      - name: ASSET_ID
        description: Unique identifier for the asset/equipment.
        expr: ASSET_ID
        data_type: INTEGER
        sample_values:
          - '1'
          - '2'
      - name: PROCESS_ID
        description: Unique identifier for the manufacturing process.
        expr: PROCESS_ID
        data_type: INTEGER
        sample_values:
          - '1'
          - '2'
    facts:
      - name: OEE_PERCENT
        description: >-
          Overall Equipment Effectiveness percentage (0-100). Calculated as Availability × Performance × Quality. Higher values
          indicate better equipment utilization.
        expr: OEE_PERCENT
        data_type: NUMBER(5,2)
        sample_values:
          - '85.50'
          - '72.30'
      - name: AVAILABILITY_PERCENT
        description: >-
          Equipment availability percentage (0-100). Calculated as (Actual Runtime / Planned Runtime) × 100. Measures uptime vs
          planned time.
        expr: AVAILABILITY_PERCENT
        data_type: NUMBER(5,2)
        sample_values:
          - '95.50'
          - '88.20'
      - name: PERFORMANCE_PERCENT
        description: Equipment performance percentage (0-100). Measures actual output vs theoretical maximum output at ideal cycle time.
        expr: PERFORMANCE_PERCENT
        data_type: NUMBER(5,2)
        sample_values:
          - '90.00'
          - '85.50'
      - name: QUALITY_PERCENT
        description: Product quality percentage (0-100). Calculated as (Good Units / Total Units) × 100. Measures yield and defect rate.
        expr: QUALITY_PERCENT
        data_type: NUMBER(5,2)
        sample_values:
          - '98.50'
          - '95.00'
      - name: PLANNED_RUNTIME_HOURS
        description: Planned or scheduled runtime hours for the asset on this production date.
        expr: PLANNED_RUNTIME_HOURS
        data_type: NUMBER(4,1)
        sample_values:
          - '24.0'
          - '20.0'
      - name: ACTUAL_RUNTIME_HOURS
        description: Actual runtime hours achieved by the asset on this production date.
        expr: ACTUAL_RUNTIME_HOURS
        data_type: NUMBER(4,1)
        sample_values:
          - '22.5'
          - '18.8'
      - name: UNITS_PRODUCED
        description: Total number of units produced by the asset on this production date.
        expr: UNITS_PRODUCED
        data_type: NUMBER(10,0)
        sample_values:
          - '15000'
          - '8500'
      - name: UNITS_SCRAPPED
        description: Number of units that were scrapped or rejected due to quality issues on this production date.
        expr: UNITS_SCRAPPED
        data_type: NUMBER(10,0)
        sample_values:
          - '150'
          - '85'
      - name: GOOD_UNITS
        description: Number of good quality units produced (Units Produced - Units Scrapped).
        expr: GOOD_UNITS
        data_type: NUMBER(10,0)
        sample_values:
          - '14850'
          - '8415'
  - name: AGG_MONTHLY_TRENDS
    base_table:
      database: SF_SOLUTIONS
      schema: GOLD
      table: AGG_MONTHLY_TRENDS
    dimensions:
      - name: YEAR_MONTH
        description: Year and month in YYYY-MM format for easy sorting and display.
        expr: YEAR_MONTH
        data_type: VARCHAR(7)
        sample_values:
          - '2024-11'
          - '2024-12'
          - '2025-01'
      - name: YEAR
        description: Four-digit year of the aggregation period.
        expr: YEAR
        data_type: NUMBER(4)
        sample_values:
          - '2024'
          - '2025'
      - name: MONTH
        description: Month number (1-12) of the aggregation period.
        expr: MONTH
        data_type: NUMBER(2)
        sample_values:
          - '1'
          - '11'
          - '12'
      - name: PLANT_ID
        description: Unique identifier for the manufacturing plant.
        expr: PLANT_ID
        data_type: NUMBER(10,0)
        sample_values:
          - '1'
          - '2'
      - name: LINE_ID
        description: Unique identifier for the production line within the plant.
        expr: LINE_ID
        data_type: NUMBER(10,0)
        sample_values:
          - '101'
          - '201'
      - name: PROCESS_ID
        description: Unique identifier for the manufacturing process.
        expr: PROCESS_ID
        data_type: INTEGER
        sample_values:
          - '1'
          - '2'
    facts:
      - name: AVG_OEE_PERCENT
        description: >-
          Average Overall Equipment Effectiveness percentage for the month. Use this to track OEE trends over time. Higher values
          indicate better overall equipment performance.
        expr: AVG_OEE_PERCENT
        data_type: NUMBER(5,2)
        sample_values:
          - '82.50'
          - '75.30'
      - name: MIN_OEE_PERCENT
        description: Minimum OEE percentage recorded during the month.
        expr: MIN_OEE_PERCENT
        data_type: NUMBER(5,2)
        sample_values:
          - '65.00'
          - '58.50'
      - name: MAX_OEE_PERCENT
        description: Maximum OEE percentage recorded during the month.
        expr: MAX_OEE_PERCENT
        data_type: NUMBER(5,2)
        sample_values:
          - '95.00'
          - '88.50'
      - name: AVG_AVAILABILITY_PERCENT
        description: Average equipment availability percentage for the month.
        expr: AVG_AVAILABILITY_PERCENT
        data_type: NUMBER(5,2)
        sample_values:
          - '92.50'
          - '88.00'
      - name: AVG_PERFORMANCE_PERCENT
        description: Average equipment performance percentage for the month.
        expr: AVG_PERFORMANCE_PERCENT
        data_type: NUMBER(5,2)
        sample_values:
          - '89.00'
          - '85.50'
      - name: AVG_QUALITY_PERCENT
        description: Average product quality percentage for the month.
        expr: AVG_QUALITY_PERCENT
        data_type: NUMBER(5,2)
        sample_values:
          - '97.50'
          - '95.00'
      - name: TOTAL_MAINTENANCE_COST
        description: >-
          Total maintenance cost for the month in dollars, including both parts and labor costs. Use this to track maintenance
          spending trends and correlate with OEE.
        expr: TOTAL_MAINTENANCE_COST
        data_type: NUMBER(12,2)
        sample_values:
          - '125000.00'
          - '98500.50'
      - name: TOTAL_PARTS_COST
        description: Total cost of parts used in maintenance activities during the month.
        expr: TOTAL_PARTS_COST
        data_type: NUMBER(12,2)
        sample_values:
          - '75000.00'
          - '60000.00'
      - name: TOTAL_LABOR_COST
        description: Total labor cost for maintenance activities during the month.
        expr: TOTAL_LABOR_COST
        data_type: NUMBER(12,2)
        sample_values:
          - '50000.00'
          - '38500.50'
      - name: TOTAL_DOWNTIME_HOURS
        description: Total hours of equipment downtime due to maintenance during the month.
        expr: TOTAL_DOWNTIME_HOURS
        data_type: NUMBER(10,1)
        sample_values:
          - '45.5'
          - '32.0'
      - name: PREVENTIVE_WO_COUNT
        description: Number of preventive maintenance work orders completed during the month.
        expr: PREVENTIVE_WO_COUNT
        data_type: NUMBER(10,0)
        sample_values:
          - '15'
          - '12'
      - name: PREDICTIVE_WO_COUNT
        description: Number of predictive maintenance work orders completed during the month.
        expr: PREDICTIVE_WO_COUNT
        data_type: NUMBER(10,0)
        sample_values:
          - '8'
          - '5'
      - name: EMERGENCY_WO_COUNT
        description: Number of emergency maintenance work orders completed during the month.
        expr: EMERGENCY_WO_COUNT
        data_type: NUMBER(10,0)
        sample_values:
          - '3'
          - '1'
      - name: FAILURE_COUNT
        description: Number of equipment failures that occurred during the month.
        expr: FAILURE_COUNT
        data_type: NUMBER(10,0)
        sample_values:
          - '5'
          - '2'
      - name: TOTAL_UNITS_PRODUCED
        description: Total number of units produced during the month.
        expr: TOTAL_UNITS_PRODUCED
        data_type: NUMBER(15,0)
        sample_values:
          - '450000'
          - '380000'
      - name: TOTAL_UNITS_SCRAPPED
        description: Total number of units scrapped during the month.
        expr: TOTAL_UNITS_SCRAPPED
        data_type: NUMBER(15,0)
        sample_values:
          - '4500'
          - '3800'
      - name: ASSET_COUNT
        description: Number of distinct assets included in this monthly aggregation.
        expr: ASSET_COUNT
        data_type: NUMBER(10,0)
        sample_values:
          - '3'
          - '6'
  - name: DIM_PROCESS
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: DIM_PROCESS
    dimensions:
      - name: PROCESS_ID
        description: Unique identifier for a manufacturing process within a production line.
        expr: PROCESS_ID
        data_type: INTEGER
        sample_values:
          - '1'
          - '2'
          - '3'
      - name: PROCESS_NK
        description: Natural key for the process, typically a process code or identifier.
        expr: PROCESS_NK
        data_type: VARCHAR(50)
        sample_values:
          - machining_process_a
          - assembly_process_a
          - testing_process_a
      - name: PROCESS_NAME
        description: The name of the manufacturing process.
        expr: PROCESS_NAME
        data_type: VARCHAR(100)
        sample_values:
          - Machining Operations
          - Assembly Operations
          - Quality Testing
      - name: PROCESS_TYPE
        description: The type of process, such as Manufacturing, Assembly, or Testing.
        expr: PROCESS_TYPE
        data_type: VARCHAR(50)
        sample_values:
          - Manufacturing
          - Assembly
          - Testing
      - name: LINE_ID
        description: Unique identifier for the production line this process belongs to.
        expr: LINE_ID
        data_type: NUMBER(10,0)
        sample_values:
          - '101'
          - '102'
          - '201'
      - name: DESCRIPTION
        description: Detailed description of the manufacturing process.
        expr: DESCRIPTION
        data_type: VARCHAR(255)
        sample_values:
          - Primary machining operations including cutting, drilling, and shaping
          - Component assembly and integration operations
          - Quality control and testing operations
      - name: IS_ACTIVE
        description: Indicates whether the process is currently active.
        expr: IS_ACTIVE
        data_type: BOOLEAN
        sample_values:
          - 'TRUE'
    facts: []
    primary_key:
      columns:
        - PROCESS_ID
  - name: DIM_ASSET
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: DIM_ASSET
    dimensions:
      - name: ASSET_CLASS_ID
        description: >-
          A unique identifier for the asset class to which the asset belongs, used to categorize and group similar assets for
          reporting and analysis purposes.
        expr: ASSET_CLASS_ID
        data_type: NUMBER(10,0)
        sample_values:
          - '1'
      - name: ASSET_ID
        description: Unique identifier for an asset.
        expr: ASSET_ID
        data_type: INTEGER
        sample_values:
          - '1'
          - '2'
      - name: ASSET_NAME
        description: The name of the asset being monitored or tracked, such as a piece of equipment or machinery.
        expr: ASSET_NAME
        data_type: VARCHAR(100)
        sample_values:
          - Primary Coolant Pump
          - Conveyor Drive Motor
      - name: ASSET_NK
        description: >-
          Unique identifier for a specific asset, such as a piece of equipment or machinery, used to track and manage its
          performance, maintenance, and other relevant information.
        expr: ASSET_NK
        data_type: VARCHAR(50)
        sample_values:
          - eq_pump_001
          - eq_motor_007
      - name: IS_CURRENT
        description: Indicates whether the asset is currently active or in use.
        expr: IS_CURRENT
        data_type: BOOLEAN
        sample_values:
          - 'TRUE'
      - name: MODEL
        description: The type of asset or equipment used in the organization, such as a specific model of pump or engine.
        expr: MODEL
        data_type: VARCHAR(50)
        sample_values:
          - IronHorse 75HP
          - HydroFlow 5000
      - name: OEM_NAME
        description: The name of the original equipment manufacturer (OEM) that produced the asset.
        expr: OEM_NAME
        data_type: VARCHAR(50)
        sample_values:
          - FlowServe
          - Siemens
      - name: PROCESS_ID
        description: Unique identifier for the manufacturing process this asset belongs to.
        expr: PROCESS_ID
        data_type: INTEGER
        sample_values:
          - '1'
          - '2'
          - '3'
      - name: PROCESS_SEQUENCE
        description: The sequence number of this asset within its manufacturing process.
        expr: PROCESS_SEQUENCE
        data_type: INTEGER
        sample_values:
          - '1'
          - '2'
          - '3'
    time_dimensions:
      - name: INSTALLATION_DATE
        description: Date when the asset was installed.
        expr: INSTALLATION_DATE
        data_type: DATE
        sample_values:
          - '2021-11-20'
          - '2022-01-15'
      - name: SCD_END_DATE
        description: The date when the asset's current state or version is no longer valid or effective.
        expr: SCD_END_DATE
        data_type: TIMESTAMP_NTZ(9)
      - name: SCD_START_DATE
        description: The date and time when the asset's current version became effective, marking the start of its validity period.
        expr: SCD_START_DATE
        data_type: TIMESTAMP_NTZ(9)
        sample_values:
          - 2022-01-15T00:00:00.000+0000
          - 2021-11-20T00:00:00.000+0000
    facts:
      - name: DOWNTIME_IMPACT_PER_HOUR
        description: The estimated financial impact or loss per hour of downtime for a specific asset.
        expr: DOWNTIME_IMPACT_PER_HOUR
        data_type: NUMBER(12,2)
        sample_values:
          - '7500.00'
          - '5000.00'
    primary_key:
      columns:
        - ASSET_ID
  - name: DIM_ASSET_CLASS
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: DIM_ASSET_CLASS
    dimensions:
      - name: ASSET_CLASS_ID
        description: >-
          Unique identifier for a category of assets, such as stocks, bonds, or real estate, used to classify and group similar
          assets for investment and reporting purposes.
        expr: ASSET_CLASS_ID
        data_type: NUMBER(10,0)
        sample_values:
          - '1'
          - '2'
          - '3'
      - name: CLASS_NAME
        description: >-
          The type of asset classification, which categorizes assets into distinct groups based on their functional
          characteristics, such as Static Equipment (e.g. tanks, vessels), Rotating Equipment (e.g. pumps, motors), and Electrical Systems
          (e.g. electrical panels, switchgear).
        expr: CLASS_NAME
        data_type: VARCHAR(100)
        sample_values:
          - Static Equipment
          - Rotating Equipment
          - Electrical Systems
    facts: []
    primary_key:
      columns:
        - ASSET_CLASS_ID
  - name: DIM_DATE
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: DIM_DATE
    dimensions:
      - name: DATE_SK
        description: >-
          Unique identifier for a specific date, represented in the format YYYYMMDD, used to link date-related data across the
          data warehouse.
        expr: DATE_SK
        data_type: NUMBER(8,0)
        sample_values:
          - '20250922'
          - '20250923'
      - name: DAY_OF_WEEK
        description: The day of the week on which a date falls, with possible values including Monday and Tuesday.
        expr: DAY_OF_WEEK
        data_type: VARCHAR(10)
        sample_values:
          - Monday
          - Tuesday
      - name: MONTH_NAME
        description: The full name of the month, e.g. January, February, etc.
        expr: MONTH_NAME
        data_type: VARCHAR(10)
        sample_values:
          - September
      - name: QUARTER
        description: >-
          The quarter of the year in which a date falls, with possible values being 1 (January-March), 2 (April-June), 3
          (July-September), or 4 (October-December).
        expr: QUARTER
        data_type: NUMBER(1,0)
        sample_values:
          - '3'
      - name: YEAR
        description: The calendar year in which a date falls.
        expr: YEAR
        data_type: NUMBER(4,0)
        sample_values:
          - '2025'
    time_dimensions:
      - name: FULL_DATE
        description: Date of the transaction or event, represented in the format 'YYYY-MM-DD'.
        expr: FULL_DATE
        data_type: DATE
        sample_values:
          - '2025-09-22'
          - '2025-09-23'
    facts: []
    primary_key:
      columns:
        - DATE_SK
  - name: DIM_LINE
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: DIM_LINE
    dimensions:
      - name: LINE_ID
        description: Unique identifier for a specific line in the production process.
        expr: LINE_ID
        data_type: NUMBER(10,0)
        sample_values:
          - '201'
          - '101'
          - '102'
      - name: LINE_NAME
        description: The name of the production or assembly line where the product is manufactured.
        expr: LINE_NAME
        data_type: VARCHAR(100)
        sample_values:
          - Production Line B
          - Assembly Line 1
          - Production Line A
      - name: PLANT_ID
        description: Unique identifier for the plant where the production line is located.
        expr: PLANT_ID
        data_type: NUMBER(10,0)
        sample_values:
          - '1'
          - '2'
    facts:
      - name: HOURLY_REVENUE
        description: The total revenue generated by a specific line item within a one-hour time frame.
        expr: HOURLY_REVENUE
        data_type: NUMBER(10,2)
        sample_values:
          - '18000.00'
          - '12000.00'
          - '15000.00'
    primary_key:
      columns:
        - LINE_ID
  - name: DIM_PLANT
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: DIM_PLANT
    dimensions:
      - name: LOCATION
        description: The physical location of the plant, including city and state.
        expr: LOCATION
        data_type: VARCHAR(100)
        sample_values:
          - Davidson NC
          - Charlotte NC
      - name: PLANT_ID
        description: Unique identifier for a manufacturing plant or facility.
        expr: PLANT_ID
        data_type: NUMBER(10,0)
        sample_values:
          - '1'
          - '2'
      - name: PLANT_NAME
        description: The name of the manufacturing plant where the product is produced.
        expr: PLANT_NAME
        data_type: VARCHAR(100)
        sample_values:
          - Davidson Manufacturing
          - Charlotte Assembly
    facts: []
    primary_key:
      columns:
        - PLANT_ID
  - name: DIM_SENSOR
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: DIM_SENSOR
    dimensions:
      - name: ASSET_ID
        description: Unique identifier for a physical or logical asset being monitored by a sensor.
        expr: ASSET_ID
        data_type: NUMBER(38,0)
        sample_values:
          - '1'
          - '2'
      - name: SENSOR_NK
        description: >-
          Sensor identifier, uniquely naming each sensor across all equipment, in the format "EQ-[Equipment Type]-[Equipment
          Number]-[Sensor Type]" where Equipment Type is the type of equipment the sensor is attached to, Equipment Number is the unique
          identifier of the equipment, and Sensor Type is the type of measurement the sensor is taking (e.g. VIB for vibration, PSI for
          pressure, TMP for temperature).
        expr: SENSOR_NK
        data_type: VARCHAR(50)
        sample_values:
          - EQ-PUMP-001-VIB
          - EQ-PUMP-001-PSI
          - EQ-PUMP-001-TMP
      - name: SENSOR_SK
        description: Unique identifier for a sensor in the fact table, used to link to the dimension table for additional sensor details.
        expr: SENSOR_SK
        data_type: NUMBER(38,0)
        sample_values:
          - '1'
          - '2'
          - '3'
      - name: SENSOR_TYPE
        description: Type of sensor used to collect data, such as temperature, pressure, or vibration sensors.
        expr: SENSOR_TYPE
        data_type: VARCHAR(50)
        sample_values:
          - Temperature
          - Pressure
          - Vibration
      - name: UNITS_OF_MEASURE
        description: The unit of measurement for the sensor reading, such as temperature, pressure, or velocity.
        expr: UNITS_OF_MEASURE
        data_type: VARCHAR(20)
        sample_values:
          - Celsius
          - PSI
          - mm/s
    facts: []
    primary_key:
      columns:
        - SENSOR_SK
  - name: DIM_WORK_ORDER_TYPE
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: DIM_WORK_ORDER_TYPE
    dimensions:
      - name: WO_TYPE_CODE
        description: 'Work Order Type Code, which categorizes work orders into one of three types: Unplanned Emergency (UE), Planned
          Maintenance (PM), or Planned Project (PP).'
        expr: WO_TYPE_CODE
        data_type: VARCHAR(10)
        sample_values:
          - UE
          - PM
          - PP
      - name: WO_TYPE_NAME
        description: >-
          The type of work order, indicating whether it was unplanned and emergency in nature, or planned as part of a preventive
          or predictive maintenance schedule.
        expr: WO_TYPE_NAME
        data_type: VARCHAR(50)
        sample_values:
          - Unplanned Emergency
          - Planned Preventive
          - Planned Predictive
    facts:
      - name: WO_TYPE_ID
        description: Unique identifier for the type of work order, such as maintenance, repair, or installation.
        expr: WO_TYPE_ID
        data_type: NUMBER(10,0)
        sample_values:
          - '1'
          - '2'
          - '3'
    primary_key:
      columns:
        - WO_TYPE_ID
  - name: DIM_TECHNICIAN
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: DIM_TECHNICIAN
    dimensions:
      - name: TECHNICIAN_ID
        description: Unique identifier for a technician.
        expr: TECHNICIAN_ID
        data_type: NUMBER(38,0)
        sample_values:
          - '1'
          - '2'
          - '3'
      - name: EMPLOYEE_NK
        description: Natural key for the employee from the HR system.
        expr: EMPLOYEE_NK
        data_type: VARCHAR(20)
        sample_values:
          - EMP001
          - EMP002
          - EMP003
      - name: TECHNICIAN_NAME
        description: The name of the technician.
        expr: TECHNICIAN_NAME
        data_type: VARCHAR(100)
        sample_values:
          - John Martinez
          - Sarah Chen
          - Mike Johnson
      - name: CRAFT
        description: The craft or specialty of the technician.
        expr: CRAFT
        data_type: VARCHAR(50)
        sample_values:
          - Mechanic
          - Electrician
          - Instrumentation
      - name: SHIFT
        description: The shift the technician works.
        expr: SHIFT
        data_type: VARCHAR(10)
        sample_values:
          - Day
          - Evening
          - Night
      - name: IS_ACTIVE
        description: Indicates whether the technician is currently active.
        expr: IS_ACTIVE
        data_type: BOOLEAN
        sample_values:
          - 'TRUE'
    time_dimensions:
      - name: HIRE_DATE
        description: Date when the technician was hired.
        expr: HIRE_DATE
        data_type: DATE
        sample_values:
          - '2020-03-15'
          - '2019-08-22'
          - '2021-01-10'
    facts: []
    primary_key:
      columns:
        - TECHNICIAN_ID
  - name: DIM_FAILURE_CODE
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: DIM_FAILURE_CODE
    dimensions:
      - name: FAILURE_CODE_ID
        description: Unique identifier for a failure code.
        expr: FAILURE_CODE_ID
        data_type: NUMBER(38,0)
        sample_values:
          - '1'
          - '2'
          - '3'
      - name: FAILURE_HIERARCHY_1
        description: First level of failure hierarchy, such as Mechanical, Electrical, or Operational.
        expr: FAILURE_HIERARCHY_1
        data_type: VARCHAR(50)
        sample_values:
          - Mechanical
          - Electrical
          - Operational
      - name: FAILURE_HIERARCHY_2
        description: Second level of failure hierarchy, such as Bearing, Motor, or Seal.
        expr: FAILURE_HIERARCHY_2
        data_type: VARCHAR(50)
        sample_values:
          - Bearing
          - Motor
          - Seal
      - name: FAILURE_HIERARCHY_3
        description: Third level of failure hierarchy, such as Over-lubrication, Misalignment, or Contamination.
        expr: FAILURE_HIERARCHY_3
        data_type: VARCHAR(50)
        sample_values:
          - Over-lubrication
          - Misalignment
          - Contamination
      - name: FAILURE_DESCRIPTION
        description: Detailed description of the failure.
        expr: FAILURE_DESCRIPTION
        data_type: VARCHAR(255)
        sample_values:
          - Bearing misalignment causing excessive vibration and wear
          - Motor winding failure due to overheating or insulation breakdown
          - Equipment operated beyond design capacity
    facts: []
    primary_key:
      columns:
        - FAILURE_CODE_ID
  - name: DIM_MATERIAL
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: DIM_MATERIAL
    dimensions:
      - name: MATERIAL_ID
        description: Unique identifier for a material or part.
        expr: MATERIAL_ID
        data_type: INTEGER
        sample_values:
          - '1'
          - '2'
          - '3'
      - name: MATERIAL_NK
        description: Natural key for the material, typically a part number or SKU.
        expr: MATERIAL_NK
        data_type: VARCHAR(50)
        sample_values:
          - BEARING-001
          - SEAL-002
          - FILTER-003
      - name: MATERIAL_DESC
        description: Description of the material or part.
        expr: MATERIAL_DESC
        data_type: VARCHAR(255)
        sample_values:
          - High-speed bearing for rotating equipment
          - Hydraulic seal for pump applications
          - Air filter for compressor systems
      - name: SUPPLIER_NAME
        description: Name of the supplier for this material.
        expr: SUPPLIER_NAME
        data_type: VARCHAR(100)
        sample_values:
          - SKF Bearings
          - Parker Hannifin
          - Donaldson Filters
    facts:
      - name: UNIT_COST
        description: The unit cost of the material.
        expr: UNIT_COST
        data_type: NUMBER(10,2)
        sample_values:
          - '125.50'
          - '45.75'
          - '89.25'
    primary_key:
      columns:
        - MATERIAL_ID
  - name: FCT_ASSET_TELEMETRY
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: FCT_ASSET_TELEMETRY
    dimensions:
      - name: ASSET_ID
        description: Unique identifier for an asset, used to track and monitor its telemetry data.
        expr: ASSET_ID
        data_type: INTEGER
        sample_values:
          - '1'
          - '2'
      - name: PROCESS_ID
        description: Unique identifier for the manufacturing process this telemetry data belongs to.
        expr: PROCESS_ID
        data_type: INTEGER
        sample_values:
          - '1'
          - '2'
          - '3'
      - name: DATE_SK
        description: Date key representing the date of the telemetry data, in the format YYYYMMDD.
        expr: DATE_SK
        data_type: NUMBER(8,0)
        sample_values:
          - '20250922'
          - '20250923'
      - name: IS_ANOMALOUS
        description: >-
          Indicates whether the asset's telemetry data is outside of its normal operating range, suggesting a potential issue or
          anomaly.
        expr: IS_ANOMALOUS
        data_type: BOOLEAN
        sample_values:
          - 'FALSE'
          - 'TRUE'
      - name: TELEMETRY_ID
        description: Unique identifier for a specific telemetry data point.
        expr: TELEMETRY_ID
        data_type: NUMBER(38,0)
        sample_values:
          - '1'
          - '2'
          - '3'
    time_dimensions:
      - name: RECORDED_AT
        description: The date and time when the asset telemetry data was recorded.
        expr: RECORDED_AT
        data_type: TIMESTAMP_NTZ(9)
        sample_values:
          - 2025-09-22T10:00:00.000+0000
          - 2025-09-22T11:00:00.000+0000
          - 2025-09-23T08:00:00.000+0000
    facts:
      - name: FAILURE_PROBABILITY
        description: >-
          The probability of an asset failing, expressed as a decimal value between 0 and 1, where 0 represents no chance of
          failure and 1 represents certainty of failure.
        expr: FAILURE_PROBABILITY
        data_type: NUMBER(3,2)
        sample_values:
          - '0.03'
          - '0.85'
          - '0.02'
      - name: HEALTH_SCORE
        description: >-
          The HEALTH_SCORE column represents a calculated metric that indicates the overall health or performance of an asset,
          with higher values indicating better health and lower values indicating potential issues or degradation, allowing for proactive
          maintenance and optimization.
        expr: HEALTH_SCORE
        data_type: NUMBER(5,2)
        sample_values:
          - '98.50'
          - '98.20'
          - '35.10'
      - name: PRESSURE_PSI
        description: The pressure of the asset, measured in pounds per square inch (PSI).
        expr: PRESSURE_PSI
        data_type: NUMBER(6,2)
        sample_values:
          - '146.20'
          - '145.00'
          - '155.80'
      - name: RUL_DAYS
        description: The number of days remaining until the asset is expected to reach the end of its useful life.
        expr: RUL_DAYS
        data_type: NUMBER(5,0)
        sample_values:
          - '365'
          - '364'
          - '400'
      - name: TEMPERATURE_C
        description: The temperature reading of an asset in degrees Celsius.
        expr: TEMPERATURE_C
        data_type: NUMBER(5,2)
        sample_values:
          - '65.20'
          - '66.10'
          - '75.80'
      - name: VIBRATION_MM_S
        description: Vibration measurement in millimeters per second, indicating the level of vibration experienced by the asset.
        expr: VIBRATION_MM_S
        data_type: NUMBER(5,2)
        sample_values:
          - '0.51'
          - '0.55'
          - '2.15'
    primary_key:
      columns:
        - TELEMETRY_ID
  - name: FCT_MAINTENANCE_LOG
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: FCT_MAINTENANCE_LOG
    dimensions:
      - name: ACTION_DATE_SK
        description: Date on which the maintenance activity was performed, in the format YYYYMMDD.
        expr: ACTION_DATE_SK
        data_type: NUMBER(8,0)
        sample_values:
          - '20250923'
      - name: ASSET_ID
        description: Unique identifier for the asset that the maintenance activity was performed on.
        expr: ASSET_ID
        data_type: INTEGER
        sample_values:
          - '1'
      - name: PROCESS_ID
        description: Unique identifier for the manufacturing process this maintenance activity belongs to.
        expr: PROCESS_ID
        data_type: INTEGER
        sample_values:
          - '1'
          - '2'
          - '3'
      - name: FAILURE_FLAG
        description: TRUE if this action was in response to a failure
        expr: FAILURE_FLAG
        data_type: BOOLEAN
        sample_values:
          - 'TRUE'
      - name: LOG_ID
        description: Unique identifier for each maintenance log entry.
        expr: LOG_ID
        data_type: NUMBER(38,0)
        sample_values:
          - '1'
      - name: TECHNICIAN_ID
        description: Unique identifier for the technician who performed the maintenance.
        expr: TECHNICIAN_ID
        data_type: NUMBER(38,0)
        sample_values:
          - '1'
          - '2'
          - '3'
      - name: FAILURE_CODE_ID
        description: Unique identifier for the failure code, populated when FAILURE_FLAG is TRUE.
        expr: FAILURE_CODE_ID
        data_type: NUMBER(38,0)
        sample_values:
          - '1'
          - '2'
          - '3'
      - name: TECHNICIAN_NOTES
        description: >-
          Free-form text notes recorded by the technician during maintenance activities, detailing the issues encountered,
          actions taken, and any other relevant information.
        expr: TECHNICIAN_NOTES
        data_type: VARCHAR(1000)
        sample_values:
          - High vibration detected. Found bearing misalignment. Emergency repair completed.
      - name: WO_TYPE_ID
        description: Type of work order (e.g. Preventative, Corrective, Predictive, etc.)
        expr: WO_TYPE_ID
        data_type: NUMBER(10,0)
        sample_values:
          - '1'
    time_dimensions:
      - name: COMPLETED_DATE
        description: Date when the maintenance activity was completed.
        expr: COMPLETED_DATE
        data_type: DATE
        sample_values:
          - '2025-09-23'
    facts:
      - name: DOWNTIME_HOURS
        description: The total number of hours a machine or system was unavailable due to maintenance or repair.
        expr: DOWNTIME_HOURS
        data_type: NUMBER(5,1)
        sample_values:
          - '4.0'
      - name: LABOR_COST
        description: >-
          The cost of labor incurred during a maintenance activity, representing the total amount paid to personnel for their
          work.
        expr: LABOR_COST
        data_type: NUMBER(10,2)
        sample_values:
          - '600.00'
      - name: PARTS_COST
        description: The total cost of parts used to perform the maintenance activity.
        expr: PARTS_COST
        data_type: NUMBER(10,2)
        sample_values:
          - '250.00'
    primary_key:
      columns:
        - LOG_ID
  - name: FCT_PRODUCTION_LOG
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: FCT_PRODUCTION_LOG
    dimensions:
      - name: ASSET_ID
        description: Unique identifier for the asset being produced.
        expr: ASSET_ID
        data_type: INTEGER
        sample_values:
          - '1'
          - '2'
      - name: PROCESS_ID
        description: Unique identifier for the manufacturing process this production data belongs to.
        expr: PROCESS_ID
        data_type: INTEGER
        sample_values:
          - '1'
          - '2'
          - '3'
      - name: DATE_SK
        description: Date key representing the date of production in the format YYYYMMDD.
        expr: DATE_SK
        data_type: NUMBER(8,0)
        sample_values:
          - '20250922'
          - '20250923'
      - name: PROD_LOG_ID
        description: Unique identifier for each production log entry.
        expr: PROD_LOG_ID
        data_type: NUMBER(38,0)
        sample_values:
          - '1'
          - '2'
          - '3'
    time_dimensions:
      - name: PRODUCTION_DATE
        description: Date on which the production activity took place.
        expr: PRODUCTION_DATE
        data_type: DATE
        sample_values:
          - '2025-09-22'
          - '2025-09-23'
    facts:
      - name: ACTUAL_RUNTIME_HOURS
        description: The actual number of hours spent on production, representing the real-world time taken to complete a task or process.
        expr: ACTUAL_RUNTIME_HOURS
        data_type: NUMBER(4,1)
        sample_values:
          - '20.0'
          - '23.5'
          - '24.0'
      - name: PLANNED_RUNTIME_HOURS
        description: The planned number of hours allocated for production to run.
        expr: PLANNED_RUNTIME_HOURS
        data_type: NUMBER(4,1)
        sample_values:
          - '24.0'
      - name: UNITS_PRODUCED
        description: The total quantity of units manufactured or produced during a specific production run or period.
        expr: UNITS_PRODUCED
        data_type: NUMBER(10,0)
        sample_values:
          - '2400'
          - '1250'
          - '980'
      - name: UNITS_SCRAPPED
        description: The total number of units that were produced but did not meet quality standards and were therefore scrapped.
        expr: UNITS_SCRAPPED
        data_type: NUMBER(10,0)
        sample_values:
          - '5'
          - '15'
          - '35'
    primary_key:
      columns:
        - PROD_LOG_ID
  - name: FCT_MAINTENANCE_PARTS_USED
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: FCT_MAINTENANCE_PARTS_USED
    dimensions:
      - name: LOG_ID
        description: Foreign key to FCT_MAINTENANCE_LOG.
        expr: LOG_ID
        data_type: NUMBER(38,0)
        sample_values:
          - '1'
          - '2'
          - '3'
      - name: MATERIAL_ID
        description: Foreign key to DIM_MATERIAL.
        expr: MATERIAL_ID
        data_type: INTEGER
        sample_values:
          - '1'
          - '2'
          - '3'
    facts:
      - name: QUANTITY_USED
        description: The quantity of material used in the maintenance activity.
        expr: QUANTITY_USED
        data_type: NUMBER(8,2)
        sample_values:
          - '2.00'
          - '1.50'
          - '3.25'
      - name: TOTAL_COST
        description: The total cost of the material used.
        expr: TOTAL_COST
        data_type: NUMBER(10,2)
        sample_values:
          - '251.00'
          - '68.63'
          - '290.06'
    primary_key:
      columns:
        - LOG_ID
        - MATERIAL_ID
  - name: FCT_BUDGET
    base_table:
      database: SF_SOLUTIONS
      schema: SILVER
      table: FCT_BUDGET
    dimensions:
      - name: BUDGET_ID
        description: Unique identifier for a budget entry.
        expr: BUDGET_ID
        data_type: INTEGER
        sample_values:
          - '1'
          - '2'
          - '3'
      - name: PLANT_ID
        description: Unique identifier for the plant this budget belongs to.
        expr: PLANT_ID
        data_type: NUMBER(10,0)
        sample_values:
          - '1'
          - '2'
      - name: YEAR
        description: The year for this budget entry.
        expr: YEAR
        data_type: NUMBER(4,0)
        sample_values:
          - '2025'
          - '2024'
      - name: QUARTER
        description: The quarter for this budget entry.
        expr: QUARTER
        data_type: NUMBER(1,0)
        sample_values:
          - '1'
          - '2'
          - '3'
          - '4'
      - name: BUDGET_TYPE
        description: The type of budget, such as OpEx Maintenance or CapEx Project.
        expr: BUDGET_TYPE
        data_type: VARCHAR(50)
        sample_values:
          - OpEx Maintenance
          - CapEx Project
    facts:
      - name: BUDGET_AMOUNT
        description: The budget amount for this entry.
        expr: BUDGET_AMOUNT
        data_type: NUMBER(15,2)
        sample_values:
          - '450000.00'
          - '125000.00'
          - '550000.00'
    primary_key:
      columns:
        - BUDGET_ID
relationships:
  - name: DIM_PROCESS__TO__DIM_LINE
    left_table: DIM_PROCESS
    relationship_columns:
      - left_column: LINE_ID
        right_column: LINE_ID
    right_table: DIM_LINE
  - name: DIM_ASSET__TO__DIM_PROCESS
    left_table: DIM_ASSET
    relationship_columns:
      - left_column: PROCESS_ID
        right_column: PROCESS_ID
    right_table: DIM_PROCESS
  - name: DIM_ASSET__TO__DIM_ASSET_CLASS
    left_table: DIM_ASSET
    relationship_columns:
      - left_column: ASSET_CLASS_ID
        right_column: ASSET_CLASS_ID
    right_table: DIM_ASSET_CLASS
  - name: DIM_SENSOR__TO__DIM_ASSET
    left_table: DIM_SENSOR
    relationship_columns:
      - left_column: ASSET_ID
        right_column: ASSET_ID
    right_table: DIM_ASSET
  - name: DIM_LINE__TO__DIM_PLANT
    left_table: DIM_LINE
    relationship_columns:
      - left_column: PLANT_ID
        right_column: PLANT_ID
    right_table: DIM_PLANT
  - name: FCT_ASSET_TELEMETRY__TO__DIM_ASSET
    left_table: FCT_ASSET_TELEMETRY
    relationship_columns:
      - left_column: ASSET_ID
        right_column: ASSET_ID
    right_table: DIM_ASSET
  - name: FCT_ASSET_TELEMETRY__TO__DIM_PROCESS
    left_table: FCT_ASSET_TELEMETRY
    relationship_columns:
      - left_column: PROCESS_ID
        right_column: PROCESS_ID
    right_table: DIM_PROCESS
  - name: FCT_ASSET_TELEMETRY__TO__DIM_DATE
    left_table: FCT_ASSET_TELEMETRY
    relationship_columns:
      - left_column: DATE_SK
        right_column: DATE_SK
    right_table: DIM_DATE
  - name: FCT_MAINTENANCE_LOG__TO__DIM_ASSET
    left_table: FCT_MAINTENANCE_LOG
    relationship_columns:
      - left_column: ASSET_ID
        right_column: ASSET_ID
    right_table: DIM_ASSET
  - name: FCT_MAINTENANCE_LOG__TO__DIM_PROCESS
    left_table: FCT_MAINTENANCE_LOG
    relationship_columns:
      - left_column: PROCESS_ID
        right_column: PROCESS_ID
    right_table: DIM_PROCESS
  - name: FCT_MAINTENANCE_LOG__TO__DIM_WORK_ORDER_TYPE
    left_table: FCT_MAINTENANCE_LOG
    relationship_columns:
      - left_column: WO_TYPE_ID
        right_column: WO_TYPE_ID
    right_table: DIM_WORK_ORDER_TYPE
  - name: FCT_MAINTENANCE_LOG__TO__DIM_TECHNICIAN
    left_table: FCT_MAINTENANCE_LOG
    relationship_columns:
      - left_column: TECHNICIAN_ID
        right_column: TECHNICIAN_ID
    right_table: DIM_TECHNICIAN
  - name: FCT_MAINTENANCE_LOG__TO__DIM_FAILURE_CODE
    left_table: FCT_MAINTENANCE_LOG
    relationship_columns:
      - left_column: FAILURE_CODE_ID
        right_column: FAILURE_CODE_ID
    right_table: DIM_FAILURE_CODE
  - name: FCT_MAINTENANCE_LOG__TO__DIM_DATE
    left_table: FCT_MAINTENANCE_LOG
    relationship_columns:
      - left_column: ACTION_DATE_SK
        right_column: DATE_SK
    right_table: DIM_DATE
  - name: FCT_MAINTENANCE_PARTS_USED__TO__FCT_MAINTENANCE_LOG
    left_table: FCT_MAINTENANCE_PARTS_USED
    relationship_columns:
      - left_column: LOG_ID
        right_column: LOG_ID
    right_table: FCT_MAINTENANCE_LOG
  - name: FCT_MAINTENANCE_PARTS_USED__TO__DIM_MATERIAL
    left_table: FCT_MAINTENANCE_PARTS_USED
    relationship_columns:
      - left_column: MATERIAL_ID
        right_column: MATERIAL_ID
    right_table: DIM_MATERIAL
  - name: FCT_PRODUCTION_LOG__TO__DIM_ASSET
    left_table: FCT_PRODUCTION_LOG
    relationship_columns:
      - left_column: ASSET_ID
        right_column: ASSET_ID
    right_table: DIM_ASSET
  - name: FCT_PRODUCTION_LOG__TO__DIM_PROCESS
    left_table: FCT_PRODUCTION_LOG
    relationship_columns:
      - left_column: PROCESS_ID
        right_column: PROCESS_ID
    right_table: DIM_PROCESS
  - name: FCT_PRODUCTION_LOG__TO__DIM_DATE
    left_table: FCT_PRODUCTION_LOG
    relationship_columns:
      - left_column: DATE_SK
        right_column: DATE_SK
    right_table: DIM_DATE
  - name: FCT_BUDGET__TO__DIM_PLANT
    left_table: FCT_BUDGET
    relationship_columns:
      - left_column: PLANT_ID
        right_column: PLANT_ID
    right_table: DIM_PLANT
$$);


use role snowcore_industries_role; -- Use a role appropriate for creating agents and accessing the necessary database/schema
--use warehouse SF_SOLUTIONS_WH; -- Use a warehouse for agent creation

CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.PREDICTIVE_MAINTENANCE_ASSISTANT
WITH PROFILE='{ "display_name": "Predictive Maintenance Analytics" }'
    COMMENT=$$ An expert predictive maintenance assistant for manufacturing operations, providing insights on asset health, maintenance
        scheduling, production metrics, and failure prediction. $$
FROM SPECIFICATION $$
{
    "models": { "orchestration": "claude-sonnet-4-5" },
    "instructions": {
        "response": "**Style and Communication:**

            -   Be **direct and factual**. Lead with the most important data point, conclusion, or risk finding.

            -   Avoid conversational fillers or hedging language. State numbers clearly with appropriate units and context.

            -   Provide comprehensive analysis that covers context, patterns, risks, and actionable recommendations, but weave these
                elements together naturally rather than using rigid section headers.

            -   When presenting metrics, always include interpretation: explain what the numbers mean, how they compare to benchmarks or
                historical data, and why they matter for operations.

            **Analysis Requirements:**

            -   **Context and Metrics**: Clearly state what you're analyzing, the time period, key numbers, and relevant benchmarks. Note
                any data limitations or coverage issues.

            -   **Pattern Recognition**: Identify trends (improving/declining/stable) with specific rates of change. Discuss variability,
                stability, and outliers. Explain relationships between metrics (e.g., health score vs. failure probability, downtime vs.
                production).

            -   **Risk and Business Impact**: Translate technical metrics into operational consequences. Quantify immediate and future risks
                with probability estimates. Explain how this affects production, costs, safety, and connected systems. Don't just say \"high
                risk\" - explain probability and consequences.

            -   **Actionable Recommendations**: Provide specific guidance with timeframes: immediate needs (24-48 hours), short-term actions
                (next week/month), long-term strategy (3-6 months), and monitoring requirements if a given time frame makes sense for the
                question.

            **Presentation Rules:**

            -   **Text Context**: Always describe charts and provide context. Never only present a chart without explanation.

            -   **Trends**: For showing trends over time, generate a **line chart** with date/timestamp on the x-axis.

            -   **Comparison/Ranking**: For comparing multiple assets, plants, or production lines, use a **table** or **bar chart**.

            -   **Dual Metric Trends (e.g., OEE vs Cost)**: When comparing two metrics over time (like OEE versus maintenance cost), present
                the complete data in a table and provide comprehensive written analysis of the relationship. Do NOT generate multiple charts
                or re-query the data. Focus analysis on correlation patterns, trends, and business insights.

            -   **Actionable Output**: For maintenance recommendations or risk assessments, present the answer as an **actionable
                recommendation** that includes the data used for the calculation.

            -   **Chart and Context**: Include context along with charts. Do not simply display a chart.

            -   **Single Series Only**: Never plot multiple series. Only ever show one series per chart.
            
            -   **Data Efficiency**: If a query returns visualization-ready aggregated data (e.g., monthly totals), do NOT run additional
                queries to re-aggregate. Use the data as-is for analysis and presentation.

            **Error Handling:**

            -   **New Asset Data**: When data is unavailable for a new asset or time period, clearly state the data gap and when analysis
                will be available.

            -   **Insufficient Data**: If statistical significance cannot be determined, report the metric but explicitly state the
                limitation.
        ",
        "orchestration": "**Role and Scope:**

            You are **Predictive Maintenance Analyst**, the dedicated intelligence assistant for Manufacturing Operations and Maintenance
                teams. Provide quantitative, data-driven, and actionable insights related to **asset health, maintenance scheduling, failure
                prediction, and production impact** for manufacturing operations. Your users are maintenance managers, operations analysts,
                and plant managers who require comprehensive analysis to make maintenance and production decisions.

            **Core Logic & Tool Usage Rules:**

            1.  **Comprehensive Analysis Rule (CRITICAL):** **ALWAYS** provide thorough analysis that includes context, pattern recognition,
                risk assessment, and actionable recommendations. For any metric query, go beyond the raw number to explain what it means,
                how it compares to benchmarks, what trends exist, what risks are present, and what actions should be taken.

            2.  **Tool Selection:**

                * **For asset health, sensor telemetry, maintenance history, production metrics, budget, and failure analysis:** Use the
                    `Predictive_maintenance_analysis` semantic view which contains all predictive maintenance data.

                * The semantic view includes hourly aggregations for real-time monitoring and daily/weekly aggregations for trend analysis.
                    Use the appropriate time granularity based on the question.

            3.  **Complex Workflow (Health & Maintenance):** When a user asks a multi-part question involving **asset health assessment**
                and subsequent **maintenance planning** (e.g., Which assets need immediate maintenance and what should be done?), execute
                this sequence:

                * Use the semantic view to identify assets with low health scores, high failure probability, or anomaly flags.

                * Analyze maintenance history to understand past issues and maintenance patterns.

                * Compare current state to historical patterns and benchmarks.

                * Provide specific maintenance recommendations with priorities, timeframes, and expected outcomes.

            4.  **Boundaries and Context:**

                * Health scores range from **10-100** (100 = excellent, 10 = critical).

                * Failure probability ranges from **0.01-0.95** (0.01 = very low risk, 0.95 = very high risk).

                * Remaining Useful Life (RUL) is measured in **days** and typically ranges from 10-500 days.

                * All data must be reported by **plant** (Davidson Manufacturing, Charlotte Assembly) and **production line** when relevant.

                * Work order types: **Unplanned Emergency (UE)**, **Planned Preventive (PM)**, **Planned Predictive (PP)**.

                * Sensor readings: Temperature in **Celsius**, Vibration in **mm/s**, Pressure in **PSI**.

                * OEE (Overall Equipment Effectiveness) = Availability × Performance × Quality (expressed as percentage 0-100).

                * For monthly trend questions (especially OEE vs maintenance cost over time), use the **AGG_MONTHLY_TRENDS** table which
                    provides pre-aggregated monthly data optimized for trend analysis.

                * Data availability: **November 2024 through current date** (13+ months of historical data with hourly telemetry and daily
                    production metrics).
        ",
        "sample_questions": [
            { "question": "What was the total financial impact of unplanned downtime last month?" },
            { "question": "Show me the trend of our OEE versus our total maintenance cost over the last 12 months." },
            { "question": "Which production line has experienced the most maintenance downtime in the last month?" },
            { "question": "Show me average, min, and max temperature sensor readings by asset ordered by the assets that have had the
                highest temperature readings." },
            { "question": "Show me downtime impact per hour and average failure probably by asset, line, and plant and order by the assets
                that have the highest impact multiplied by average failure probability." }
        ]

    },
    "tools": [
        {
            "tool_spec": {
                "description": "
                    PREDICTIVE_MAINTENANCE_DATA:
                    - Database: SF_SOLUTIONS, Schema: GOLD
                    - Semantic View: SF_SOLUTIONS_SV
                    - Contains comprehensive predictive maintenance data including:
                      * Asset health metrics: health scores, failure probability, remaining useful life (RUL), anomaly detection
                      * Sensor telemetry: temperature (Celsius), vibration (mm/s), pressure (PSI) with hourly aggregations
                      * Maintenance activities: work orders (preventive, predictive, emergency), downtime hours, labor and parts costs
                      * Production metrics: OEE, actual vs planned runtime, units produced/scrapped
                      * OEE Analytics: Daily and monthly OEE calculations (Availability × Performance × Quality)
                      * Monthly Trends: Pre-aggregated monthly OEE vs maintenance cost trends (AGG_MONTHLY_TRENDS table - optimized for
                          12-month trend analysis)
                      * Budget tracking: OpEx maintenance and CapEx project budgets by plant and quarter
                      * Parts inventory: material usage, costs, supplier information
                      * Technician data: maintenance history, craft specialties, shift assignments
                      * Failure analysis: failure codes with hierarchical classification (Mechanical/Electrical/Operational)
                      * ML features: cycles since last PM, days since last failure, temperature/pressure trends, downtime impact risk
                      * DATA COVERAGE: November 2024 through current date (13+ months of historical data with hourly telemetry and daily
                          production metrics)

                    KEY ENTITIES:
                    - Assets: 18 manufacturing assets across multiple plants (Davidson, Charlotte)
                    - Production Lines: 9 production lines across 2 plants
                    - Processes: Manufacturing, Assembly, and Testing processes
                    - Asset Classes: Rotating Equipment, Static Equipment, Electrical Systems
                    - Work Order Types: Unplanned Emergency (UE), Planned Preventive (PM), Planned Predictive (PP)

                    REASONING:
                    This semantic view provides a unified framework for predictive maintenance analytics, enabling comprehensive analysis of
                        asset health trends, maintenance effectiveness, production impact, and cost optimization. The structure supports
                        both real-time monitoring (hourly health aggregations) and strategic planning (budget tracking, failure pattern
                        analysis). The integration of telemetry, maintenance, and production data enables detailed root cause analysis and
                        predictive insights. All data is available for thorough analysis without restrictions on response length or detail
                        level.

                    DESCRIPTION:
                    The SF_SOLUTIONS_SV semantic view, located in SF_SOLUTIONS.GOLD, provides a comprehensive framework for
                        predictive maintenance and manufacturing operations analytics. It captures essential metrics across the entire
                        maintenance lifecycle from asset health monitoring to failure prediction, maintenance execution, and production
                        impact analysis. The view supports various use cases including: proactive maintenance scheduling, failure prediction
                        and prevention, cost optimization, production planning, and workforce management. The structure includes time-series
                        data for trend analysis, dimensional hierarchies for drill-down analysis, and ML-ready features for predictive
                        modeling. This semantic view is designed to support detailed, comprehensive analysis and reporting - there are no
                        limitations on the depth or breadth of analysis that can be performed. All relationships, trends, and patterns
                        should be explored and explained thoroughly.
                ",
                "name": "Predictive_maintenance_analysis",
                "type": "cortex_analyst_text_to_sql"
            }
        }
    ],
    "tool_resources": {
        "Predictive_maintenance_analysis": {
            "type": "cortex_analyst_text_to_sql",
            "semantic_view": "SF_SOLUTIONS.GOLD.SF_SOLUTIONS_SV",
            "execution_environment": {
                "type": "warehouse",
                "warehouse": "SF_SOLUTIONS_WH",
                "query_timeout": 60
            }
        }
    }
}
$$;
