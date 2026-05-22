/*************************************************************************************************/
-- SUPPLY CHAIN INTELLIGENCE PLATFORM SETUP
-- Version: 1.0
--
-- PREREQUISITES:
-- This script requires ACCOUNTADMIN role with:
--   - CREATE DATABASE, SCHEMA, TABLE, STAGE
--   - CREATE WAREHOUSE
--   - CREATE CORTEX SEARCH SERVICE
--   - CREATE AGENT
--
-- WHAT THIS SCRIPT CREATES:
--   - Database: SF_SOLUTIONS (if not exists)
--   - Schema: SUPPLY_CHAIN_ENTITIES
--   - 11 tables with demo data (~1,100 rows)
--   - Semantic Model (staged YAML for Cortex Analyst)
--   - Cortex Search Service (supply chain documentation)
--   - Snowflake Intelligence Agent
--   - Streamlit stage for app deployment
--
-- ESTIMATED RUNTIME: ~2 minutes
/*************************************************************************************************/

USE ROLE ACCOUNTADMIN;

ALTER SESSION SET query_tag = '{"origin":"sf_sit-is",'
    || '"name":"supply_chain_intelligence_platform",'
    || '"version":{"major":1,"minor":0},'
    || '"attributes":{"is_quickstart":1,"source":"sql"}}';

/*************************************************************************************************/
-- SECTION 1: Database, Schema, Warehouse, Stages
/*************************************************************************************************/

CREATE DATABASE IF NOT EXISTS SF_SOLUTIONS;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES;

CREATE WAREHOUSE IF NOT EXISTS SF_SOLUTIONS_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

USE WAREHOUSE SF_SOLUTIONS_WH;
USE DATABASE SF_SOLUTIONS;
USE SCHEMA SUPPLY_CHAIN_ENTITIES;

CREATE STAGE IF NOT EXISTS SEMANTIC_STAGE
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    DIRECTORY = (ENABLE = TRUE);

CREATE STAGE IF NOT EXISTS SCN_PDF
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    DIRECTORY = (ENABLE = TRUE);

CREATE STAGE IF NOT EXISTS STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for Supply Chain Streamlit app';

CREATE FILE FORMAT IF NOT EXISTS CSVFORMAT
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TYPE = 'CSV';

/*************************************************************************************************/
-- SECTION 2: Table DDL
/*************************************************************************************************/

/* set up roles */


/* create role and add permissions required by role for installation of framework */

/* perform grants */


/* add cortex_user database role to use Cortex */

/* set up objects */


/* create database */



-- Suppliers
CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLIERS (
	SUPPLIER_ID INTEGER NOT NULL COMMENT 'Unique identifier for the supplier',
	SUPPLIER_NAME VARCHAR(255) NOT NULL COMMENT 'Name of the supplier company',
	ADDRESS VARCHAR(255) COMMENT 'Street address of the supplier',
	CITY VARCHAR(100) COMMENT 'City of the supplier',
	STATE VARCHAR(50) COMMENT 'State/Province of the supplier',
	COUNTRY VARCHAR(50) COMMENT 'Country of the supplier',
	ZIP_CODE VARCHAR(20) COMMENT 'Postal code of the supplier',
	CONTACT_PERSON_NAME VARCHAR(255) COMMENT 'Primary contact person at the supplier',
	CONTACT_EMAIL VARCHAR(255) COMMENT 'Contact email address',
	CONTACT_PHONE VARCHAR(50) COMMENT 'Contact phone number',
	SUPPLIER_TYPE VARCHAR(100) COMMENT 'Type of supplier (Raw Materials, Components, Services, etc.)',
	BUSINESS_LINE VARCHAR(15) COMMENT 'business line (AEROSPACE, INDUSTRIAL, BUILDINGS, ENERGY)',
	IS_PREFERRED BOOLEAN DEFAULT FALSE COMMENT 'Indicates if this is a preferred supplier',
	PAYMENT_TERMS VARCHAR(50) COMMENT 'Standard payment terms (Net 30, Net 60, etc.)',
	primary key (SUPPLIER_ID)
)COMMENT='Information about suppliers who provide raw materials and components'
;

-- Bill of Materials
CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.BILL_OF_MATERIALS (
	BOM_ID INTEGER NOT NULL COMMENT 'Unique identifier for the bill of materials entry',
	PARENT_PRODUCT_ID INTEGER COMMENT 'Product that uses these materials/components',
	PARENT_COMPONENT_ID INTEGER COMMENT 'Component that uses these materials (for sub-assemblies)',
	CHILD_MATERIAL_ID INTEGER COMMENT 'Raw material used in this BOM',
	CHILD_COMPONENT_ID INTEGER COMMENT 'Component used in this BOM',
	QUANTITY_REQUIRED NUMBER(10,4) NOT NULL COMMENT 'Quantity of the child item required per parent item',
	UNIT_OF_MEASURE VARCHAR(50) COMMENT 'Unit of measure (pieces, kg, meters, etc.)',
	SCRAP_FACTOR NUMBER(5,4) DEFAULT 0.0 COMMENT 'Expected scrap/waste factor (0.05 = 5% scrap)',
	EFFECTIVE_DATE DATE COMMENT 'Date when this BOM version becomes effective',
	EXPIRATION_DATE DATE COMMENT 'Date when this BOM version expires',
	primary key (BOM_ID)
)COMMENT='Bill of materials defining what raw materials and components are needed to produce products and components'
;

-- Component
CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.COMPONENT (
	COMPONENT_ID INTEGER NOT NULL COMMENT 'Unique identifier for the component',
	COMPONENT_NAME VARCHAR(255) NOT NULL COMMENT 'Name of the component',
	COMPONENT_DESCRIPTION VARCHAR(1024) COMMENT 'Description of the component',
	BILL_OF_MATERIALS_ID INTEGER COMMENT 'Foreign key referencing a bill_of_materials table (if applicable)',
	BUSINESS_LINE VARCHAR(15) COMMENT 'business line (AEROSPACE, INDUSTRIAL, BUILDINGS, ENERGY)',
	primary key (COMPONENT_ID)
)COMMENT='Information about individual components'
;

-- Product
CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.PRODUCT (
	PRODUCT_ID INTEGER NOT NULL COMMENT 'Unique identifier for the product',
	PRODUCT_NAME VARCHAR(255) NOT NULL COMMENT 'Name of the product',
	PRODUCT_DESCRIPTION VARCHAR(1024) COMMENT 'Description of the product',
	PRODUCT_CATEGORY VARCHAR(100) COMMENT 'Category of the product',
	UNIT_PRICE NUMBER(10,2) COMMENT 'Price per unit of the product',
	BUSINESS_LINE VARCHAR(15) COMMENT 'business line (AEROSPACE, INDUSTRIAL, BUILDINGS, ENERGY)',
	primary key (PRODUCT_ID)
)COMMENT='Information about finished goods products'
;

-- Manufacturing Plant
CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.MFG_PLANT (
	MFG_PLANT_ID INTEGER COMMENT 'Unique identifier for each manufacturing plant.',
	MFG_PLANT_NAME VARCHAR(255) COMMENT 'The name of the manufacturing plant.',
	ADDRESS VARCHAR(255) COMMENT 'Manufacturing plant addresses.',
	CITY VARCHAR(100) COMMENT 'Names of cities where manufacturing plants are located.',
	STATE VARCHAR(50) COMMENT 'The abbreviated name of the U.S. state where the manufacturing plant is located.',
	COUNTRY VARCHAR(50) COMMENT 'The country where the manufacturing plant is located.',
	ZIP_CODE VARCHAR(20) COMMENT 'Five-digit codes representing specific geographic locations in the United States.',
	LATITUDE NUMBER(10,6) COMMENT 'The geographical latitude coordinate.',
	LONGITUDE NUMBER(11,6) COMMENT 'Longitudes of manufacturing plant locations.',
	PLANT_MANAGER_CONTACT_ID INTEGER COMMENT 'Unique identifier for the contact person managing each manufacturing plant.',
	SQUARE_FOOTAGE NUMBER(10,2) COMMENT 'The size of the manufacturing plant measured in square footage.',
	NUMBER_OF_EMPLOYEES NUMBER(38,0) COMMENT 'The number of employees at the manufacturing plant.',
	IS_ACTIVE BOOLEAN COMMENT 'Indicates whether the manufacturing plant is currently in operation.',
	BUSINESS_LINE VARCHAR(15) COMMENT 'The business line to which the manufacturing plant belongs (AEROSPACE, INDUSTRIAL, BUILDINGS, ENERGY).'
)COMMENT='Manufacturing plants that produce components and assemble finished products for direct sale to customers'
;

-- Manufacturing Plant Inventory (handles both raw materials, components, and finished products)
CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.MFG_INVENTORY (
	MFG_PLANT_ID INTEGER NOT NULL COMMENT 'Foreign key referencing MFG_PLANT',
	MATERIAL_ID INTEGER COMMENT 'Foreign key referencing raw_material table (if applicable)',
	COMPONENT_ID INTEGER COMMENT 'Foreign key referencing component table (if applicable)',
	PRODUCT_ID INTEGER COMMENT 'Foreign key referencing product table (if applicable)',
	QUANTITY_ON_HAND NUMBER(38,0) COMMENT 'Current quantity on hand',
	QUANTITY_ON_ORDER NUMBER(38,0) COMMENT 'Quantity currently on order',
	SAFETY_STOCK_LEVEL NUMBER(38,0) COMMENT 'Minimum inventory level to maintain',
	REPLENISHMENT_POINT NUMBER(38,0) COMMENT 'Target inventory level for replenishment calculations',
	LAST_UPDATED_TIMESTAMP TIMESTAMP_NTZ(9) COMMENT 'Timestamp of the last inventory update',
	MATERIAL_LEAD_TIME NUMBER(38,0) COMMENT 'Lead time in days to acquire/produce this item',
	DAYS_FORWARD_COVERAGE NUMBER(38,0) COMMENT 'Number of days current inventory can sustain demand',
	LEAD_TIME_VARIABILITY NUMBER(38,0) COMMENT 'Variability in lead time, measured in days'
)COMMENT='Inventory levels of raw materials, components, and finished products at manufacturing plants'
;

-- Customer
CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.CUSTOMER (
	CUSTOMER_ID INTEGER NOT NULL COMMENT 'Unique identifier for the customer',
	CUSTOMER_NAME VARCHAR(255) NOT NULL COMMENT 'Name of the customer',
	ADDRESS VARCHAR(255) COMMENT 'Street address of the customer',
	CITY VARCHAR(100) COMMENT 'City of the customer',
	STATE VARCHAR(50) COMMENT 'State/Province of the customer',
	COUNTRY VARCHAR(50) COMMENT 'Country of the customer',
	ZIP_CODE VARCHAR(20) COMMENT 'Postal code of the customer',
	CONTACT_PERSON_ID INTEGER COMMENT 'Foreign key referencing a contacts table (if applicable)',
	INDUSTRY VARCHAR(100) COMMENT 'Industry of the customer',
	BUSINESS_LINE VARCHAR(15) COMMENT 'business line (AEROSPACE, INDUSTRIAL, BUILDINGS, ENERGY)',
	primary key (CUSTOMER_ID)
)COMMENT='Information about direct customers who purchase products from manufacturing plants'
;

-- Shipment (simplified for direct MFG plant to customer shipments)
CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SHIPMENT (
	SHIPMENT_ID INTEGER NOT NULL COMMENT 'Unique identifier for the shipment',
	ORIGIN_MFG_PLANT_ID INTEGER COMMENT 'Foreign key referencing the originating manufacturing plant',
	DESTINATION_CUSTOMER_ID INTEGER COMMENT 'Foreign key referencing the destination customer',
	SHIP_DATE DATE COMMENT 'Date the shipment was shipped',
	EXPECTED_DELIVERY_DATE DATE COMMENT 'Expected delivery date of the shipment',
	ACTUAL_DELIVERY_DATE DATE COMMENT 'Actual delivery date of the shipment',
	SHIPPING_COST NUMBER(10,2) COMMENT 'Cost of shipping',
	TRACKING_NUMBER VARCHAR(50) COMMENT 'Tracking number for the shipment',
	primary key (SHIPMENT_ID)
)COMMENT='Information about shipments from manufacturing plants directly to customers'
;

-- Orders (simplified for direct customer to MFG plant orders)
CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.ORDERS (
	ORDER_ID INTEGER NOT NULL COMMENT 'Unique identifier for the order',
	CUSTOMER_ID INTEGER NOT NULL COMMENT 'Foreign key referencing the customer',
	MFG_PLANT_ID INTEGER COMMENT 'Foreign key referencing the manufacturing plant fulfilling the order',
	ORDER_DATE TIMESTAMP_NTZ(9) COMMENT 'Date and time the order was placed',
	PRODUCT_ID INTEGER NOT NULL COMMENT 'Foreign key referencing the product',
	QUANTITY NUMBER(38,0) NOT NULL COMMENT 'Quantity of the product ordered',
	UNIT_PRICE NUMBER(10,2) NOT NULL COMMENT 'Price per unit at the time of order',
	TOTAL_PRICE NUMBER(10,2) NOT NULL COMMENT 'Total price of the order line',
	ORDER_STATUS VARCHAR(50) COMMENT 'Status of the order (e.g., Placed, In Production, Shipped, Delivered, Cancelled)',
	primary key (ORDER_ID)
)COMMENT='Information about customer orders placed directly with manufacturing plants'
;

CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.RAW_MATERIAL (
	MATERIAL_ID INTEGER NOT NULL COMMENT 'Unique identifier for each raw material.',
	MATERIAL_NAME VARCHAR(16777216) COMMENT 'Names of raw materials used in the supply chain network.',
	MATERIAL_DESCRIPTION VARCHAR(16777216) COMMENT 'Detailed descriptions of raw materials.',
	SUPPLIER_ID INTEGER COMMENT 'Foreign key referencing the primary supplier for this material',
	MATERIAL_COST NUMBER(10,2) COMMENT 'The cost of the raw material from the supplier',
	PLANT_TRANSPORT_COST NUMBER(10,2) COMMENT 'Base cost for transporting this material between plants (before surcharge multiplier)',
	BUSINESS_LINE VARCHAR(15) COMMENT 'business line (AEROSPACE, INDUSTRIAL, BUILDINGS, ENERGY)',
	primary key (MATERIAL_ID)
)COMMENT='Raw materials sourced from suppliers and used in manufacturing plants to produce components and products'
;

CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.TRANSPORT_COST_SURCHARGE (
	SOURCE_FACILITY_ID INTEGER NOT NULL COMMENT 'Unique identifier for the source facility with excess inventory',
	DESTINATION_FACILITY_ID INTEGER NOT NULL COMMENT 'Unique identifier for the destination facility that will receive materials',
	TRANSPORT_COST_SURCHARGE NUMBER(3,
	2) NOT NULL COMMENT 'Transport costs multiplier between facilities depending on distance and transport difficulty'
)COMMENT='Transport cost surcharge for moving materials between manufacturing plants'
;

-- Run the following statement to create a Snowflake managed internal stage to store the semantic model specification file.

-- Run the following statement to create a Snowflake managed internal stage to store the PDF documents.

  skip_header = 1  
  field_optionally_enclosed_by = '"'  
  type = 'CSV';  
 
 -- Run the following statement to create a Snowflake managed internal stage to store the csv data files.

-- Conversation History table for storing chat threads and messages
CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.CONVERSATION_HISTORY (
	CONVERSATION_ID STRING NOT NULL COMMENT 'Unique identifier for each conversation thread',
	THREAD_NAME STRING NOT NULL COMMENT 'User-friendly name for the conversation thread',
	CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'Timestamp when the conversation was created',
	UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'Timestamp when the conversation was last updated',
	MESSAGES VARIANT COMMENT 'JSON array of messages in the conversation thread',
	primary key (CONVERSATION_ID)
)COMMENT='Storage for conversation history and chat threads for the Supply Chain Assistant';

/*************************************************************************************************/
-- SECTION 3: Demo Data
/*************************************************************************************************/


-- BILL_OF_MATERIALS (123 rows)
INSERT INTO SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.BILL_OF_MATERIALS
  (BOM_ID,
  PARENT_PRODUCT_ID,
  PARENT_COMPONENT_ID,
  CHILD_MATERIAL_ID,
  CHILD_COMPONENT_ID,
  QUANTITY_REQUIRED,
  UNIT_OF_MEASURE,
  SCRAP_FACTOR,
  EFFECTIVE_DATE,
  EXPIRATION_DATE)
VALUES
  (10001, 5001, NULL, 101, NULL, 2.5, 'kg', 0.05, '2024-01-01', NULL),
  (10002, 5001, NULL, 102, NULL, 1.2, 'm2', 0.03, '2024-01-01', NULL),
  (10003, 5001, NULL, NULL, 1001, 1, 'pieces', 0.02, '2024-01-01', NULL),
  (10004, 5001, NULL, NULL, 1002, 2, 'pieces', 0.01, '2024-01-01', NULL),
  (10005, 5002, NULL, 103, NULL, 3.8, 'kg', 0.04, '2024-01-01', NULL),
  (10006, 5002, NULL, 104, NULL, 0.8, 'kg', 0.06, '2024-01-01', NULL),
  (10007, 5002, NULL, NULL, 1003, 1, 'pieces', 0.02, '2024-01-01', NULL),
  (10008, 5002, NULL, NULL, 1004, 1, 'pieces', 0.03, '2024-01-01', NULL),
  (10009, 5003, NULL, 105, NULL, 1.5, 'kg', 0.03, '2024-01-01', NULL),
  (10010, 5003, NULL, 106, NULL, 2.2, 'm', 0.02, '2024-01-01', NULL),
  (10011, 5003, NULL, NULL, 1005, 3, 'pieces', 0.01, '2024-01-01', NULL),
  (10012, 5004, NULL, 107, NULL, 4.2, 'kg', 0.05, '2024-01-01', NULL),
  (10013, 5004, NULL, 108, NULL, 1.8, 'kg', 0.04, '2024-01-01', NULL),
  (10014, 5004, NULL, NULL, 1001, 2, 'pieces', 0.02, '2024-01-01', NULL),
  (10015, 5005, NULL, 109, NULL, 2.1, 'kg', 0.03, '2024-01-01', NULL),
  (10016, 5005, NULL, 110, NULL, 3.5, 'm', 0.02, '2024-01-01', NULL),
  (10017, 5005, NULL, NULL, 1002, 1, 'pieces', 0.01, '2024-01-01', NULL),
  (10018, 6001, NULL, 111, NULL, 5.5, 'kg', 0.06, '2024-01-01', NULL),
  (10019, 6001, NULL, 112, NULL, 2.8, 'kg', 0.04, '2024-01-01', NULL),
  (10020, 6001, NULL, NULL, 2001, 1, 'pieces', 0.02, '2024-01-01', NULL),
  (10021, 6001, NULL, NULL, 2002, 2, 'pieces', 0.03, '2024-01-01', NULL),
  (10022, 6002, NULL, 113, NULL, 3.2, 'kg', 0.05, '2024-01-01', NULL),
  (10023, 6002, NULL, 114, NULL, 1.6, 'kg', 0.03, '2024-01-01', NULL),
  (10024, 6002, NULL, NULL, 2003, 1, 'pieces', 0.02, '2024-01-01', NULL),
  (10025, 6002, NULL, NULL, 2004, 3, 'pieces', 0.01, '2024-01-01', NULL),
  (10026, 6003, NULL, 115, NULL, 2.9, 'kg', 0.04, '2024-01-01', NULL),
  (10027, 6003, NULL, 116, NULL, 4.1, 'm', 0.02, '2024-01-01', NULL),
  (10028, 6003, NULL, NULL, 2005, 2, 'pieces', 0.02, '2024-01-01', NULL),
  (10029, 6004, NULL, 117, NULL, 1.7, 'kg', 0.03, '2024-01-01', NULL),
  (10030, 6004, NULL, 118, NULL, 2.4, 'kg', 0.04, '2024-01-01', NULL),
  (10031, 6004, NULL, NULL, 2006, 1, 'pieces', 0.01, '2024-01-01', NULL),
  (10032, 6005, NULL, 119, NULL, 3.6, 'kg', 0.05, '2024-01-01', NULL),
  (10033, 6005, NULL, 120, NULL, 1.9, 'm', 0.02, '2024-01-01', NULL),
  (10034, 6005, NULL, NULL, 2007, 2, 'pieces', 0.02, '2024-01-01', NULL),
  (10035, 6005, NULL, NULL, 2008, 1, 'pieces', 0.03, '2024-01-01', NULL),
  (10036, 7001, NULL, 121, NULL, 1.3, 'kg', 0.03, '2024-01-01', NULL),
  (10037, 7001, NULL, 122, NULL, 0.9, 'kg', 0.02, '2024-01-01', NULL),
  (10038, 7001, NULL, NULL, 3001, 1, 'pieces', 0.01, '2024-01-01', NULL),
  (10039, 7002, NULL, 123, NULL, 2.7, 'kg', 0.04, '2024-01-01', NULL),
  (10040, 7002, NULL, 124, NULL, 1.4, 'kg', 0.03, '2024-01-01', NULL),
  (10041, 7002, NULL, NULL, 3002, 1, 'pieces', 0.02, '2024-01-01', NULL),
  (10042, 7003, NULL, 125, NULL, 3.8, 'kg', 0.05, '2024-01-01', NULL),
  (10043, 7003, NULL, 126, NULL, 2.1, 'm', 0.02, '2024-01-01', NULL),
  (10044, 7003, NULL, NULL, 3003, 2, 'pieces', 0.01, '2024-01-01', NULL),
  (10045, 7004, NULL, 127, NULL, 1.6, 'kg', 0.03, '2024-01-01', NULL),
  (10046, 7004, NULL, 128, NULL, 4.3, 'm', 0.02, '2024-01-01', NULL),
  (10047, 7004, NULL, NULL, 3004, 3, 'pieces', 0.02, '2024-01-01', NULL),
  (10048, 7005, NULL, 129, NULL, 2.8, 'kg', 0.04, '2024-01-01', NULL),
  (10049, 7005, NULL, 130, NULL, 1.2, 'kg', 0.03, '2024-01-01', NULL),
  (10050, 7005, NULL, NULL, 3005, 1, 'pieces', 0.01, '2024-01-01', NULL),
  (10051, 7005, NULL, NULL, 3006, 2, 'pieces', 0.02, '2024-01-01', NULL),
  (10052, 8001, NULL, 131, NULL, 8.5, 'kg', 0.06, '2024-01-01', NULL),
  (10053, 8001, NULL, 132, NULL, 12.3, 'm2', 0.04, '2024-01-01', NULL),
  (10054, 8001, NULL, NULL, 4001, 2, 'pieces', 0.02, '2024-01-01', NULL),
  (10055, 8001, NULL, NULL, 4002, 1, 'pieces', 0.03, '2024-01-01', NULL),
  (10056, 8002, NULL, 133, NULL, 6.7, 'kg', 0.05, '2024-01-01', NULL),
  (10057, 8002, NULL, 134, NULL, 9.2, 'kg', 0.04, '2024-01-01', NULL),
  (10058, 8002, NULL, NULL, 4003, 3, 'pieces', 0.02, '2024-01-01', NULL),
  (10059, 8003, NULL, 135, NULL, 15.4, 'kg', 0.07, '2024-01-01', NULL),
  (10060, 8003, NULL, 136, NULL, 7.8, 'm', 0.03, '2024-01-01', NULL),
  (10061, 8003, NULL, NULL, 4004, 1, 'pieces', 0.01, '2024-01-01', NULL),
  (10062, 8003, NULL, NULL, 4005, 2, 'pieces', 0.02, '2024-01-01', NULL),
  (10063, 8004, NULL, 137, NULL, 4.9, 'kg', 0.04, '2024-01-01', NULL),
  (10064, 8004, NULL, 138, NULL, 3.1, 'kg', 0.03, '2024-01-01', NULL),
  (10065, 8004, NULL, NULL, 4006, 4, 'pieces', 0.02, '2024-01-01', NULL),
  (10066, 8005, NULL, 139, NULL, 11.2, 'kg', 0.06, '2024-01-01', NULL),
  (10067, 8005, NULL, 140, NULL, 5.6, 'm2', 0.03, '2024-01-01', NULL),
  (10068, 8005, NULL, NULL, 4007, 2, 'pieces', 0.02, '2024-01-01', NULL),
  (10069, 8005, NULL, NULL, 4008, 1, 'pieces', 0.01, '2024-01-01', NULL),
  (10070, 1001, NULL, 101, NULL, 0.8, 'kg', 0.02, '2024-01-01', NULL),
  (10071, 1001, NULL, 102, NULL, 0.3, 'm2', 0.01, '2024-01-01', NULL),
  (10072, 1002, NULL, 103, NULL, 1.2, 'kg', 0.03, '2024-01-01', NULL),
  (10073, 1002, NULL, 104, NULL, 0.5, 'kg', 0.04, '2024-01-01', NULL),
  (10074, 1003, NULL, 105, NULL, 0.7, 'kg', 0.02, '2024-01-01', NULL),
  (10075, 1003, NULL, 106, NULL, 0.9, 'm', 0.01, '2024-01-01', NULL),
  (10076, 1004, NULL, 107, NULL, 1.1, 'kg', 0.03, '2024-01-01', NULL),
  (10077, 1004, NULL, 108, NULL, 0.6, 'kg', 0.02, '2024-01-01', NULL),
  (10078, 1005, NULL, 109, NULL, 0.9, 'kg', 0.02, '2024-01-01', NULL),
  (10079, 1005, NULL, 110, NULL, 1.3, 'm', 0.01, '2024-01-01', NULL),
  (10080, 2001, NULL, 111, NULL, 1.5, 'kg', 0.04, '2024-01-01', NULL),
  (10081, 2001, NULL, 112, NULL, 0.8, 'kg', 0.02, '2024-01-01', NULL),
  (10082, 2002, NULL, 113, NULL, 1.1, 'kg', 0.03, '2024-01-01', NULL),
  (10083, 2002, NULL, 114, NULL, 0.6, 'kg', 0.02, '2024-01-01', NULL),
  (10084, 2003, NULL, 115, NULL, 0.9, 'kg', 0.03, '2024-01-01', NULL),
  (10085, 2003, NULL, 116, NULL, 1.4, 'm', 0.01, '2024-01-01', NULL),
  (10086, 2004, NULL, 117, NULL, 0.7, 'kg', 0.02, '2024-01-01', NULL),
  (10087, 2004, NULL, 118, NULL, 0.8, 'kg', 0.03, '2024-01-01', NULL),
  (10088, 2005, NULL, 119, NULL, 1.2, 'kg', 0.04, '2024-01-01', NULL),
  (10089, 2005, NULL, 120, NULL, 0.7, 'm', 0.01, '2024-01-01', NULL),
  (10090, 2006, NULL, 121, NULL, 0.5, 'kg', 0.02, '2024-01-01', NULL),
  (10091, 2006, NULL, 122, NULL, 0.4, 'kg', 0.01, '2024-01-01', NULL),
  (10092, 2007, NULL, 123, NULL, 0.8, 'kg', 0.03, '2024-01-01', NULL),
  (10093, 2007, NULL, 124, NULL, 0.6, 'kg', 0.02, '2024-01-01', NULL),
  (10094, 2008, NULL, 125, NULL, 1.0, 'kg', 0.03, '2024-01-01', NULL),
  (10095, 2008, NULL, 126, NULL, 0.9, 'm', 0.01, '2024-01-01', NULL),
  (10096, 3001, NULL, 127, NULL, 0.4, 'kg', 0.02, '2024-01-01', NULL),
  (10097, 3001, NULL, 128, NULL, 1.1, 'm', 0.01, '2024-01-01', NULL),
  (10098, 3002, NULL, 129, NULL, 0.9, 'kg', 0.03, '2024-01-01', NULL),
  (10099, 3002, NULL, 130, NULL, 0.5, 'kg', 0.02, '2024-01-01', NULL),
  (10100, 3003, NULL, 131, NULL, 1.3, 'kg', 0.04, '2024-01-01', NULL),
  (10101, 3003, NULL, 132, NULL, 0.8, 'm2', 0.02, '2024-01-01', NULL),
  (10102, 3004, NULL, 133, NULL, 0.6, 'kg', 0.02, '2024-01-01', NULL),
  (10103, 3004, NULL, 134, NULL, 1.2, 'kg', 0.03, '2024-01-01', NULL),
  (10104, 3005, NULL, 135, NULL, 0.7, 'kg', 0.02, '2024-01-01', NULL),
  (10105, 3005, NULL, 136, NULL, 0.9, 'm', 0.01, '2024-01-01', NULL),
  (10106, 3006, NULL, 137, NULL, 0.8, 'kg', 0.03, '2024-01-01', NULL),
  (10107, 3006, NULL, 138, NULL, 0.6, 'kg', 0.02, '2024-01-01', NULL),
  (10108, 4001, NULL, 139, NULL, 2.1, 'kg', 0.04, '2024-01-01', NULL),
  (10109, 4001, NULL, 140, NULL, 1.4, 'm2', 0.02, '2024-01-01', NULL),
  (10110, 4002, NULL, 131, NULL, 1.8, 'kg', 0.03, '2024-01-01', NULL),
  (10111, 4002, NULL, 132, NULL, 2.5, 'm2', 0.02, '2024-01-01', NULL),
  (10112, 4003, NULL, 133, NULL, 1.6, 'kg', 0.04, '2024-01-01', NULL),
  (10113, 4003, NULL, 134, NULL, 2.2, 'kg', 0.03, '2024-01-01', NULL),
  (10114, 4004, NULL, 135, NULL, 3.1, 'kg', 0.05, '2024-01-01', NULL),
  (10115, 4004, NULL, 136, NULL, 1.9, 'm', 0.02, '2024-01-01', NULL),
  (10116, 4005, NULL, 137, NULL, 1.3, 'kg', 0.03, '2024-01-01', NULL),
  (10117, 4005, NULL, 138, NULL, 0.9, 'kg', 0.02, '2024-01-01', NULL),
  (10118, 4006, NULL, 139, NULL, 2.4, 'kg', 0.04, '2024-01-01', NULL),
  (10119, 4006, NULL, 140, NULL, 1.7, 'm2', 0.02, '2024-01-01', NULL),
  (10120, 4007, NULL, 131, NULL, 1.9, 'kg', 0.03, '2024-01-01', NULL),
  (10121, 4007, NULL, 132, NULL, 2.8, 'm2', 0.02, '2024-01-01', NULL),
  (10122, 4008, NULL, 133, NULL, 1.5, 'kg', 0.04, '2024-01-01', NULL),
  (10123, 4008, NULL, 134, NULL, 2.1, 'kg', 0.03, '2024-01-01', NULL);

-- COMPONENT (52 rows)
INSERT INTO SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.COMPONENT
  (COMPONENT_ID, COMPONENT_NAME, COMPONENT_DESCRIPTION, BILL_OF_MATERIALS_ID, BUSINESS_LINE)
VALUES
  (1001,
  'Flight Control PCB',
  'Primary flight control printed circuit board with redundant processing units for commercial aircraft',
  5001,
  'AEROSPACE'),
  (1002,
  'Turbine Blade Assembly',
  'High-temperature resistant turbine blade assembly for jet engines with ceramic coating',
  5002,
  'AEROSPACE'),
  (1003,
  'Navigation Sensor Module',
  'Integrated GPS/INS navigation sensor module for aircraft positioning and guidance',
  5003,
  'AEROSPACE'),
  (1004, 'Engine Control Unit', 'Full authority digital engine control (FADEC) unit for turbofan engines', 5004, 'AEROSPACE'),
  (1005, 'Hydraulic Actuator', 'Primary hydraulic flight surface actuator with integrated position feedback', 5005, 'AEROSPACE'),
  (1006, 'Avionics Display Unit', 'High-resolution cockpit display unit with touch interface and redundant processing', 5006, 'AEROSPACE'),
  (1007, 'Radar Antenna Module', 'Weather radar antenna module with electronic beam steering capability', 5007, 'AEROSPACE'),
  (1008, 'Landing Gear Actuator', 'Electro-hydraulic landing gear retraction actuator with position sensors', 5008, 'AEROSPACE'),
  (1009, 'Oxygen System Controller', 'Aircraft oxygen system controller with pressure regulation and monitoring', 5009, 'AEROSPACE'),
  (1010, 'Communications Radio Module', 'VHF communications radio module with digital signal processing', 5010, 'AEROSPACE'),
  (2001, 'PLC I/O Module', 'Industrial programmable logic controller input/output expansion module', 6001, 'INDUSTRIAL'),
  (2002, 'Variable Frequency Drive', 'Three-phase variable frequency drive for industrial motor speed control', 6002, 'INDUSTRIAL'),
  (2003, 'HMI Touch Panel', '10-inch industrial human-machine interface touchscreen panel with Ethernet connectivity', 6003, 'INDUSTRIAL'),
  (2004, 'Servo Motor', 'High-precision servo motor with integrated encoder for industrial automation', 6004, 'INDUSTRIAL'),
  (2005, 'Safety Relay Module', 'Dual-channel safety relay module for emergency stop and safety interlock systems', 6005, 'INDUSTRIAL'),
  (2006, 'Flow Sensor', 'Ultrasonic flow sensor for liquid measurement in industrial process control', 6006, 'INDUSTRIAL'),
  (2007, 'Pressure Transmitter', '4-20mA pressure transmitter for industrial process monitoring', 6007, 'INDUSTRIAL'),
  (2008, 'Temperature Controller', 'PID temperature controller with thermocouple input for process control', 6008, 'INDUSTRIAL'),
  (2009, 'Proximity Sensor', 'Inductive proximity sensor for metal object detection in automation', 6009, 'INDUSTRIAL'),
  (2010, 'Pneumatic Valve', 'Solenoid-operated pneumatic valve with manual override capability', 6010, 'INDUSTRIAL'),
  (2011, 'Encoder Module', 'High-resolution rotary encoder for position feedback in servo systems', 6011, 'INDUSTRIAL'),
  (2012, 'Vision System Camera', 'Industrial vision system camera with integrated image processing', 6012, 'INDUSTRIAL'),
  (2013, 'Robotic Gripper', 'Pneumatic robotic gripper with force feedback and position control', 6013, 'INDUSTRIAL'),
  (2014, 'Conveyor Motor Drive', 'Heavy-duty motor drive system for industrial conveyor applications', 6014, 'INDUSTRIAL'),
  (3001, 'Smart Thermostat', 'WiFi-enabled smart thermostat with learning algorithms and mobile app control', 7001, 'BUILDINGS'),
  (3002, 'Access Control Reader', 'RFID card reader for building access control and security systems', 7002, 'BUILDINGS'),
  (3003, 'Fire Alarm Panel', 'Addressable fire alarm control panel with network communication capabilities', 7003, 'BUILDINGS'),
  (3004, 'LED Lighting Controller', 'Intelligent LED lighting controller with dimming and color temperature adjustment', 7004, 'BUILDINGS'),
  (3005, 'Security Camera Module', 'IP security camera module with night vision and motion detection', 7005, 'BUILDINGS'),
  (3006, 'Building Automation Gateway', 'BACnet/IP gateway for building automation system integration', 7006, 'BUILDINGS'),
  (3007, 'HVAC Damper Actuator', 'Electric actuator for HVAC damper control with position feedback', 7007, 'BUILDINGS'),
  (3008, 'Occupancy Sensor', 'PIR occupancy sensor for automatic lighting and HVAC control', 7008, 'BUILDINGS'),
  (3009, 'Air Quality Monitor', 'Multi-sensor air quality monitor for CO2 temperature and humidity', 7009, 'BUILDINGS'),
  (3010, 'Smart Lock Module', 'Electronic door lock with keypad biometric and mobile app access', 7010, 'BUILDINGS'),
  (3011, 'Emergency Lighting Unit', 'Battery backup LED emergency lighting with self-testing capability', 7011, 'BUILDINGS'),
  (3012, 'Elevator Control Panel', 'Microprocessor-based elevator control panel with safety interlocks', 7012, 'BUILDINGS'),
  (3013, 'Fire Suppression Controller', 'Intelligent fire suppression system controller with zone control', 7013, 'BUILDINGS'),
  (3014, 'Intercom System Module', 'IP-based intercom system module with video calling capability', 7014, 'BUILDINGS'),
  (4001, 'Battery Management PCB', 'Lithium-ion battery management system PCB with cell balancing and monitoring', 8001, 'ENERGY'),
  (4002, 'Solar Inverter Module', 'Grid-tie solar inverter power module with MPPT control', 8002, 'ENERGY'),
  (4003, 'Energy Storage Controller', 'Intelligent energy storage system controller with grid integration capabilities', 8003, 'ENERGY'),
  (4004, 'DC-DC Converter', 'High-efficiency isolated DC-DC converter for energy storage applications', 8004, 'ENERGY'),
  (4005, 'Grid Protection Relay', 'Microprocessor-based grid protection relay with communication interface', 8005, 'ENERGY'),
  (4006, 'Power Meter Module', 'Smart power metering module with demand response capabilities', 8006, 'ENERGY'),
  (4007, 'Wind Turbine Controller', 'Wind turbine pitch control system with weather monitoring', 8007, 'ENERGY'),
  (4008, 'Microgrid Controller', 'Intelligent microgrid controller for distributed energy resource management', 8008, 'ENERGY'),
  (4009, 'Solar Panel Optimizer', 'Power optimizer for individual solar panels with maximum power point tracking', 8009, 'ENERGY'),
  (4010, 'Energy Management Gateway', 'Smart grid energy management gateway with demand response capability', 8010, 'ENERGY'),
  (4011, 'Electric Vehicle Charger', 'Level 2 electric vehicle charging station with smart grid integration', 8011, 'ENERGY'),
  (4012, 'Fuel Cell Controller', 'Hydrogen fuel cell system controller with safety monitoring', 8012, 'ENERGY'),
  (4013, 'Battery Thermal Manager', 'Thermal management system for large-scale battery energy storage', 8013, 'ENERGY'),
  (4014, 'Grid Synchronization Unit', 'Power electronics unit for renewable energy grid synchronization', 8014, 'ENERGY');

-- CUSTOMER (40 rows)
INSERT INTO SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.CUSTOMER
  (CUSTOMER_ID, CUSTOMER_NAME, ADDRESS, CITY, STATE, COUNTRY, ZIP_CODE, CONTACT_PERSON_ID, INDUSTRY, BUSINESS_LINE)
VALUES
  (3001, 'American Airlines', '1 Skyview Dr', 'Fort Worth', 'TX', 'USA', 76155, 30001, 'Commercial Aviation', 'AEROSPACE'),
  (3002, 'Delta Air Lines', '1050 Delta Blvd', 'Atlanta', 'GA', 'USA', 30354, 30002, 'Commercial Aviation', 'AEROSPACE'),
  (3003,
  'Boeing Commercial Airplanes',
  '100 N Riverside Plaza',
  'Seattle',
  'WA',
  'USA',
  98101,
  30003,
  'Aircraft Manufacturing',
  'AEROSPACE'),
  (3004, 'United Airlines', '233 S Wacker Dr', 'Chicago', 'IL', 'USA', 60606, 30004, 'Commercial Aviation', 'AEROSPACE'),
  (3005, 'Southwest Airlines', '2702 Love Field Dr', 'Dallas', 'TX', 'USA', 75235, 30005, 'Commercial Aviation', 'AEROSPACE'),
  (3006, 'Airbus Americas', '2551 Riva Rd', 'Annapolis', 'MD', 'USA', 21401, 30006, 'Aircraft Manufacturing', 'AEROSPACE'),
  (3007, 'Lockheed Martin Aeronautics', '1 Lockheed Blvd', 'Fort Worth', 'TX', 'USA', 76108, 30007, 'Defense Aerospace', 'AEROSPACE'),
  (3008, 'Northrop Grumman', '2980 Fairview Park Dr', 'Falls Church', 'VA', 'USA', 22042, 30008, 'Defense Aerospace', 'AEROSPACE'),
  (3009, 'Raytheon Technologies', '870 Winter St', 'Waltham', 'MA', 'USA', 02451, 30009, 'Defense Aerospace', 'AEROSPACE'),
  (3010, 'JetBlue Airways', '27-01 Queens Plaza N', 'Long Island City', 'NY', 'USA', 11101, 30010, 'Commercial Aviation', 'AEROSPACE'),
  (4001, 'General Electric', '1 River Rd', 'Schenectady', 'NY', 'USA', 12345, 40001, 'Industrial Manufacturing', 'INDUSTRIAL'),
  (4002, 'Siemens USA', '300 New Jersey Ave NW', 'Washington', 'DC', 'USA', 20001, 40002, 'Industrial Automation', 'INDUSTRIAL'),
  (4003, 'Rockwell Automation', '1201 S 2nd St', 'Milwaukee', 'WI', 'USA', 53204, 40003, 'Industrial Automation', 'INDUSTRIAL'),
  (4004, 'ABB Inc', '3450 Harvester Rd', 'Burlington', 'ON', 'Canada', 'L7N3W5', 40004, 'Industrial Automation', 'INDUSTRIAL'),
  (4005, 'Schneider Electric', '800 Federal St', 'Andover', 'MA', 'USA', 01810, 40005, 'Industrial Automation', 'INDUSTRIAL'),
  (4006, 'Emerson Electric', '8000 W Florissant Ave', 'St. Louis', 'MO', 'USA', 63136, 40006, 'Industrial Automation', 'INDUSTRIAL'),
  (4007, 'Caterpillar Inc', '510 Lake Cook Rd', 'Deerfield', 'IL', 'USA', 60015, 40007, 'Heavy Machinery', 'INDUSTRIAL'),
  (4008, 'Ford Motor Company', '1 American Rd', 'Dearborn', 'MI', 'USA', 48126, 40008, 'Automotive Manufacturing', 'INDUSTRIAL'),
  (4009, 'General Motors', '300 Renaissance Center', 'Detroit', 'MI', 'USA', 48265, 40009, 'Automotive Manufacturing', 'INDUSTRIAL'),
  (4010, '3M Company', '3M Center', 'St. Paul', 'MN', 'USA', 55144, 40010, 'Industrial Manufacturing', 'INDUSTRIAL'),
  (5001, 'Johnson Controls', '5757 N Green Bay Ave', 'Milwaukee', 'WI', 'USA', 53209, 50001, 'Building Technologies', 'BUILDINGS'),
  (5002,
  'Honeywell Building Technologies',
  '715 Peachtree St NE',
  'Atlanta',
  'GA',
  'USA',
  30308,
  50002,
  'Building Automation',
  'BUILDINGS'),
  (5003, 'Carrier Global', '13995 Pasteur Blvd', 'Palm Beach Gardens', 'FL', 'USA', 33418, 50003, 'HVAC Systems', 'BUILDINGS'),
  (5004, 'Trane Technologies', '170 Scott Rd', 'Piscataway', 'NJ', 'USA', 08854, 50004, 'Climate Solutions', 'BUILDINGS'),
  (5005, 'Otis Elevator Company', '1 Carrier Pl', 'Farmington', 'CT', 'USA', 06032, 50005, 'Elevator Systems', 'BUILDINGS'),
  (5006, 'Tyco International', '9 Roszel Rd', 'Princeton', 'NJ', 'USA', 08540, 50006, 'Security Systems', 'BUILDINGS'),
  (5007, 'Allegion', '11819 N Pennsylvania St', 'Carmel', 'IN', 'USA', 46032, 50007, 'Security Products', 'BUILDINGS'),
  (5008, 'ASSA ABLOY', '110 110th Ave NE', 'Bellevue', 'WA', 'USA', 98004, 50008, 'Access Solutions', 'BUILDINGS'),
  (5009, 'Philips Lighting', '200 Franklin Square Dr', 'Somerset', 'NJ', 'USA', 08873, 50009, 'Lighting Solutions', 'BUILDINGS'),
  (5010, 'Acuity Brands', '1170 Peachtree St NE', 'Atlanta', 'GA', 'USA', 30309, 50010, 'Lighting Systems', 'BUILDINGS'),
  (6001, 'Tesla Energy', '3500 Deer Creek Rd', 'Palo Alto', 'CA', 'USA', 94304, 60001, 'Energy Storage', 'ENERGY'),
  (6002, 'NextEra Energy', '700 Universe Blvd', 'Juno Beach', 'FL', 'USA', 33408, 60002, 'Renewable Energy', 'ENERGY'),
  (6003, 'First Solar', '350 W Washington St', 'Tempe', 'AZ', 'USA', 85281, 60003, 'Solar Energy', 'ENERGY'),
  (6004, 'General Electric Renewable Energy', '1 River Rd', 'Schenectady', 'NY', 'USA', 12345, 60004, 'Wind Energy', 'ENERGY'),
  (6005, 'Vestas Wind Systems', '1417 NW Everett St', 'Portland', 'OR', 'USA', 97209, 60005, 'Wind Turbines', 'ENERGY'),
  (6006, 'SolarEdge Technologies', '47300 Kato Rd', 'Fremont', 'CA', 'USA', 94538, 60006, 'Solar Inverters', 'ENERGY'),
  (6007, 'Enphase Energy', '47281 Bayside Pkwy', 'Fremont', 'CA', 'USA', 94538, 60007, 'Solar Microinverters', 'ENERGY'),
  (6008, 'BYD America', '1800 S Figueroa St', 'Los Angeles', 'CA', 'USA', 90015, 60008, 'Energy Storage', 'ENERGY'),
  (6009, 'Fluence Energy', '4300 Wilson Blvd', 'Arlington', 'VA', 'USA', 22203, 60009, 'Energy Storage', 'ENERGY'),
  (6010, 'ExxonMobil', '5959 Las Colinas Blvd', 'Irving', 'TX', 'USA', 75039, 60010, 'Energy Infrastructure', 'ENERGY');

-- MFG_INVENTORY (173 rows)
INSERT INTO SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.MFG_INVENTORY
  (MFG_PLANT_ID,
  MATERIAL_ID,
  COMPONENT_ID,
  PRODUCT_ID,
  QUANTITY_ON_HAND,
  QUANTITY_ON_ORDER,
  SAFETY_STOCK_LEVEL,
  REPLENISHMENT_POINT,
  LAST_UPDATED_TIMESTAMP,
  MATERIAL_LEAD_TIME,
  DAYS_FORWARD_COVERAGE,
  LEAD_TIME_VARIABILITY)
VALUES
  (1001, 101, NULL, NULL, 750, 500, 1000, 1800, '2024-12-20T09:27:34.709Z', 14, 12, 3),
  (1001, 102, NULL, NULL, 600, 300, 800, 1400, '2024-12-20T09:27:34.709Z', 21, 18, 4),
  (1001, 103, NULL, NULL, 35, 25, 50, 90, '2024-12-20T09:27:34.709Z', 7, 8, 2),
  (1001, NULL, 1001, NULL, 450, 75, 200, 350, '2024-12-20T09:27:34.709Z', 10, 28, 2),
  (1001, NULL, 1002, NULL, 325, 50, 150, 275, '2024-12-20T09:27:34.709Z', 12, 32, 3),
  (1001, NULL, NULL, 5001, 85, 15, 25, 45, '2024-12-20T09:27:34.709Z', 18, 42, 4),
  (1001, NULL, NULL, 5002, 65, 10, 20, 35, '2024-12-20T09:27:34.709Z', 15, 38, 3),
  (1002, 101, NULL, NULL, 3500, 350, 900, 1600, '2024-12-20T09:27:34.709Z', 14, 65, 3),
  (1002, 102, NULL, NULL, 4200, 400, 800, 1400, '2024-12-20T09:27:34.709Z', 21, 85, 4),
  (1002, 104, NULL, NULL, 650, 350, 750, 1300, '2024-12-20T09:27:34.709Z', 16, 15, 3),
  (1002, 105, NULL, NULL, 400, 200, 500, 900, '2024-12-20T09:27:34.709Z', 12, 12, 2),
  (1002, 106, NULL, NULL, 875, 125, 350, 650, '2024-12-20T09:27:34.709Z', 18, 29, 4),
  (1002, NULL, 1003, NULL, 285, 45, 125, 225, '2024-12-20T09:27:34.709Z', 11, 26, 2),
  (1002, NULL, 1004, NULL, 195, 30, 85, 155, '2024-12-20T09:27:34.709Z', 14, 31, 3),
  (1002, NULL, NULL, 5003, 75, 12, 18, 32, '2024-12-20T09:27:34.709Z', 20, 45, 4),
  (1002, NULL, NULL, 5004, 55, 8, 15, 28, '2024-12-20T09:27:34.709Z', 17, 39, 3),
  (1003, 103, NULL, NULL, 2850, 450, 1100, 1900, '2024-12-20T09:27:34.709Z', 19, 48, 4),
  (1003, 107, NULL, NULL, 450, 275, 650, 1150, '2024-12-20T09:27:34.709Z', 15, 12, 3),
  (1003, 108, NULL, NULL, 925, 150, 375, 700, '2024-12-20T09:27:34.709Z', 22, 33, 5),
  (1003, NULL, 1005, NULL, 385, 60, 165, 295, '2024-12-20T09:27:34.709Z', 13, 27, 3),
  (1003, NULL, 1006, NULL, 245, 40, 105, 195, '2024-12-20T09:27:34.709Z', 16, 34, 3),
  (1003, NULL, NULL, 5005, 95, 18, 25, 48, '2024-12-20T09:27:34.709Z', 21, 43, 4),
  (1004, 104, NULL, NULL, 3250, 525, 1250, 2200, '2024-12-20T09:27:34.709Z', 17, 52, 4),
  (1004, 105, NULL, NULL, 3750, 325, 750, 1350, '2024-12-20T09:27:34.709Z', 14, 75, 3),
  (1004, 106, NULL, NULL, 1425, 225, 575, 1025, '2024-12-20T09:27:34.709Z', 21, 44, 4),
  (1004, 107, NULL, NULL, 465, 75, 195, 355, '2024-12-20T09:27:34.709Z', 12, 29, 2),
  (1004, 108, NULL, NULL, 325, 55, 145, 265, '2024-12-20T09:27:34.709Z', 15, 31, 3),
  (1004, NULL, NULL, 5006, 115, 22, 30, 58, '2024-12-20T09:27:34.709Z', 19, 46, 4),
  (1004, NULL, NULL, 5007, 85, 15, 22, 42, '2024-12-20T09:27:34.709Z', 16, 38, 3),
  (1005, 109, NULL, NULL, 2750, 425, 1050, 1875, '2024-12-20T09:27:34.709Z', 18, 49, 4),
  (1005, 110, NULL, NULL, 1950, 315, 785, 1425, '2024-12-20T09:27:34.709Z', 16, 41, 3),
  (1005, 111, NULL, NULL, 325, 215, 535, 965, '2024-12-20T09:27:34.709Z', 12, 8, 2),
  (1005, NULL, 1009, NULL, 445, 70, 185, 335, '2024-12-20T09:27:34.709Z', 14, 28, 3),
  (1005, NULL, 1010, NULL, 295, 50, 125, 235, '2024-12-20T09:27:34.709Z', 17, 35, 4),
  (1005, NULL, NULL, 5008, 105, 20, 28, 52, '2024-12-20T09:27:34.709Z', 20, 47, 4),
  (1005, NULL, NULL, 5009, 75, 14, 20, 38, '2024-12-20T09:27:34.709Z', 18, 41, 3),
  (1006, 110, NULL, NULL, 450, 285, 685, 1225, '2024-12-20T09:27:34.709Z', 15, 9, 3),
  (1006, 111, NULL, NULL, 3850, 195, 475, 865, '2024-12-20T09:27:34.709Z', 22, 95, 5),
  (1006, 112, NULL, NULL, 365, 60, 155, 285, '2024-12-20T09:27:34.709Z', 10, 26, 2),
  (1006, 113, NULL, NULL, 255, 45, 115, 205, '2024-12-20T09:27:34.709Z', 12, 30, 3),
  (1006, NULL, 1001, NULL, 365, 60, 155, 285, '2024-12-20T09:27:34.709Z', 10, 26, 2),
  (1006, NULL, 1002, NULL, 255, 45, 115, 205, '2024-12-20T09:27:34.709Z', 12, 30, 3),
  (1006, NULL, NULL, 5010, 95, 18, 25, 48, '2024-12-20T09:27:34.709Z', 21, 44, 4),
  (1007, 112, NULL, NULL, 3450, 575, 1325, 2375, '2024-12-20T09:27:34.709Z', 16, 51, 3),
  (1007, 113, NULL, NULL, 4500, 375, 885, 1575, '2024-12-20T09:27:34.709Z', 18, 85, 4),
  (1007, 114, NULL, NULL, 1575, 265, 625, 1125, '2024-12-20T09:27:34.709Z', 14, 35, 3),
  (1007, 115, NULL, NULL, 485, 80, 205, 375, '2024-12-20T09:27:34.709Z', 11, 27, 2),
  (1007, NULL, 2001, NULL, 485, 80, 205, 375, '2024-12-20T09:27:34.709Z', 11, 27, 2),
  (1007, NULL, 2002, NULL, 335, 55, 145, 265, '2024-12-20T09:27:34.709Z', 13, 32, 3),
  (1007, NULL, NULL, 6001, 125, 25, 35, 68, '2024-12-20T09:27:34.709Z', 19, 45, 4),
  (1007, NULL, NULL, 6002, 95, 18, 25, 48, '2024-12-20T09:27:34.709Z', 17, 40, 3),
  (1008, 114, NULL, NULL, 850, 465, 1085, 1975, '2024-12-20T09:27:34.709Z', 15, 12, 3),
  (1008, 115, NULL, NULL, 1925, 315, 775, 1425, '2024-12-20T09:27:34.709Z', 19, 42, 4),
  (1008, 116, NULL, NULL, 385, 225, 555, 1025, '2024-12-20T09:27:34.709Z', 12, 8, 2),
  (1008, 117, NULL, NULL, 425, 70, 175, 325, '2024-12-20T09:27:34.709Z', 14, 29, 3),
  (1008, NULL, 2003, NULL, 425, 70, 175, 325, '2024-12-20T09:27:34.709Z', 14, 29, 3),
  (1008, NULL, 2004, NULL, 285, 50, 125, 235, '2024-12-20T09:27:34.709Z', 16, 36, 3),
  (1008, NULL, NULL, 6003, 105, 20, 28, 52, '2024-12-20T09:27:34.709Z', 20, 46, 4),
  (1008, NULL, NULL, 6004, 85, 15, 22, 42, '2024-12-20T09:27:34.709Z', 18, 39, 3),
  (1009, 116, NULL, NULL, 4250, 685, 1625, 2925, '2024-12-20T09:27:34.709Z', 17, 54, 4),
  (1009, 117, NULL, NULL, 4750, 445, 1085, 1975, '2024-12-20T09:27:34.709Z', 21, 85, 5),
  (1009, 118, NULL, NULL, 850, 305, 745, 1365, '2024-12-20T09:27:34.709Z', 13, 18, 3),
  (1009, 119, NULL, NULL, 565, 95, 235, 435, '2024-12-20T09:27:34.709Z', 12, 31, 2),
  (1009, NULL, 2005, NULL, 565, 95, 235, 435, '2024-12-20T09:27:34.709Z', 12, 31, 2),
  (1009, NULL, 2006, NULL, 385, 65, 165, 305, '2024-12-20T09:27:34.709Z', 15, 33, 3),
  (1009, NULL, NULL, 6005, 145, 28, 38, 75, '2024-12-20T09:27:34.709Z', 22, 49, 5),
  (1009, NULL, NULL, 6006, 115, 22, 30, 58, '2024-12-20T09:27:34.709Z', 19, 43, 4),
  (1010, 118, NULL, NULL, 650, 595, 1385, 2525, '2024-12-20T09:27:34.709Z', 18, 8, 4),
  (1010, 119, NULL, NULL, 2450, 405, 935, 1675, '2024-12-20T09:27:34.709Z', 16, 45, 3),
  (1010, 120, NULL, NULL, 1725, 285, 685, 1225, '2024-12-20T09:27:34.709Z', 20, 41, 4),
  (1010, NULL, 2007, NULL, 505, 85, 215, 395, '2024-12-20T09:27:34.709Z', 14, 30, 3),
  (1010, NULL, 2008, NULL, 345, 60, 155, 285, '2024-12-20T09:27:34.709Z', 17, 37, 4),
  (1010, NULL, NULL, 6007, 135, 26, 35, 68, '2024-12-20T09:27:34.709Z', 21, 47, 4),
  (1010, NULL, NULL, 6008, 105, 20, 28, 52, '2024-12-20T09:27:34.709Z', 18, 42, 3),
  (1011, 120, NULL, NULL, 3150, 525, 1185, 2175, '2024-12-20T09:27:34.709Z', 15, 49, 3),
  (1011, 121, NULL, NULL, 2175, 365, 855, 1575, '2024-12-20T09:27:34.709Z', 19, 44, 4),
  (1011, 122, NULL, NULL, 525, 255, 605, 1125, '2024-12-20T09:27:34.709Z', 12, 10, 2),
  (1011, NULL, 2009, NULL, 445, 75, 185, 335, '2024-12-20T09:27:34.709Z', 13, 28, 3),
  (1011, NULL, 2010, NULL, 305, 55, 135, 255, '2024-12-20T09:27:34.709Z', 16, 34, 3),
  (1011, NULL, NULL, 6009, 125, 25, 35, 68, '2024-12-20T09:27:34.709Z', 20, 46, 4),
  (1011, NULL, NULL, 6010, 95, 18, 25, 48, '2024-12-20T09:27:34.709Z', 17, 40, 3),
  (1012, 121, NULL, NULL, 2950, 485, 1125, 2025, '2024-12-20T09:27:34.709Z', 16, 48, 3),
  (1012, 122, NULL, NULL, 4075, 335, 805, 1475, '2024-12-20T09:27:34.709Z', 22, 95, 5),
  (1012, 123, NULL, NULL, 425, 235, 565, 1025, '2024-12-20T09:27:34.709Z', 14, 8, 3),
  (1012, NULL, 2011, NULL, 385, 65, 165, 305, '2024-12-20T09:27:34.709Z', 11, 29, 2),
  (1012, NULL, 2012, NULL, 265, 45, 125, 225, '2024-12-20T09:27:34.709Z', 18, 36, 4),
  (1012, NULL, NULL, 6001, 115, 22, 30, 58, '2024-12-20T09:27:34.709Z', 19, 44, 4),
  (1012, NULL, NULL, 6002, 85, 15, 22, 42, '2024-12-20T09:27:34.709Z', 16, 38, 3),
  (1013, 123, NULL, NULL, 1850, 305, 745, 1365, '2024-12-20T09:27:34.709Z', 12, 41, 2),
  (1013, 124, NULL, NULL, 325, 225, 535, 965, '2024-12-20T09:27:34.709Z', 15, 7, 3),
  (1013, 125, NULL, NULL, 925, 155, 375, 675, '2024-12-20T09:27:34.709Z', 8, 32, 2),
  (1013, NULL, 3001, NULL, 285, 50, 125, 235, '2024-12-20T09:27:34.709Z', 10, 26, 2),
  (1013, NULL, 3002, NULL, 195, 35, 85, 165, '2024-12-20T09:27:34.709Z', 12, 29, 3),
  (1013, NULL, NULL, 7001, 75, 15, 20, 38, '2024-12-20T09:27:34.709Z', 16, 35, 3),
  (1013, NULL, NULL, 7002, 55, 10, 15, 28, '2024-12-20T09:27:34.709Z', 14, 31, 3),
  (1014, 124, NULL, NULL, 4300, 365, 855, 1575, '2024-12-20T09:27:34.709Z', 13, 85, 3),
  (1014, 125, NULL, NULL, 3525, 255, 605, 1125, '2024-12-20T09:27:34.709Z', 16, 75, 3),
  (1014, 126, NULL, NULL, 1085, 185, 435, 795, '2024-12-20T09:27:34.709Z', 11, 34, 2),
  (1014, 127, NULL, NULL, 325, 55, 145, 265, '2024-12-20T09:27:34.709Z', 14, 28, 3),
  (1014, NULL, 3003, NULL, 325, 55, 145, 265, '2024-12-20T09:27:34.709Z', 14, 28, 3),
  (1014, NULL, 3004, NULL, 225, 40, 105, 185, '2024-12-20T09:27:34.709Z', 17, 33, 4),
  (1014, NULL, NULL, 7003, 85, 16, 22, 42, '2024-12-20T09:27:34.709Z', 18, 40, 4),
  (1014, NULL, NULL, 7004, 65, 12, 18, 32, '2024-12-20T09:27:34.709Z', 15, 36, 3),
  (1015, 126, NULL, NULL, 750, 295, 695, 1275, '2024-12-20T09:27:34.709Z', 14, 9, 3),
  (1015, 127, NULL, NULL, 1225, 205, 485, 895, '2024-12-20T09:27:34.709Z', 18, 35, 4),
  (1015, 128, NULL, NULL, 275, 145, 345, 635, '2024-12-20T09:27:34.709Z', 9, 7, 2),
  (1015, NULL, 3005, NULL, 265, 45, 125, 225, '2024-12-20T09:27:34.709Z', 12, 27, 2),
  (1015, NULL, 3006, NULL, 185, 35, 85, 155, '2024-12-20T09:27:34.709Z', 15, 32, 3),
  (1015, NULL, NULL, 7005, 75, 14, 20, 38, '2024-12-20T09:27:34.709Z', 19, 42, 4),
  (1015, NULL, NULL, 7006, 55, 10, 15, 28, '2024-12-20T09:27:34.709Z', 16, 37, 3),
  (1016, 128, NULL, NULL, 1450, 245, 575, 1025, '2024-12-20T09:27:34.709Z', 11, 38, 2),
  (1016, 129, NULL, NULL, 1025, 175, 405, 745, '2024-12-20T09:27:34.709Z', 12, 34, 2),
  (1016, 130, NULL, NULL, 225, 125, 295, 535, '2024-12-20T09:27:34.709Z', 15, 5, 3),
  (1016, NULL, 3007, NULL, 225, 40, 105, 185, '2024-12-20T09:27:34.709Z', 13, 26, 3),
  (1016, NULL, 3008, NULL, 155, 28, 75, 135, '2024-12-20T09:27:34.709Z', 16, 31, 3),
  (1016, NULL, NULL, 7007, 65, 12, 18, 32, '2024-12-20T09:27:34.709Z', 17, 36, 3),
  (1016, NULL, NULL, 7008, 45, 8, 12, 22, '2024-12-20T09:27:34.709Z', 14, 29, 3),
  (1017, 129, NULL, NULL, 1650, 275, 655, 1175, '2024-12-20T09:27:34.709Z', 10, 40, 2),
  (1017, 130, NULL, NULL, 3525, 195, 465, 855, '2024-12-20T09:27:34.709Z', 13, 85, 3),
  (1017, 131, NULL, NULL, 825, 140, 325, 595, '2024-12-20T09:27:34.709Z', 16, 32, 3),
  (1017, NULL, 3009, NULL, 245, 42, 115, 205, '2024-12-20T09:27:34.709Z', 11, 28, 2),
  (1017, NULL, 3010, NULL, 175, 30, 85, 155, '2024-12-20T09:27:34.709Z', 14, 33, 3),
  (1017, NULL, NULL, 7009, 75, 15, 20, 38, '2024-12-20T09:27:34.709Z', 18, 41, 4),
  (1017, NULL, NULL, 7010, 55, 10, 15, 28, '2024-12-20T09:27:34.709Z', 15, 35, 3),
  (1018, 131, NULL, NULL, 350, 225, 535, 975, '2024-12-20T09:27:34.709Z', 12, 6, 2),
  (1018, 132, NULL, NULL, 975, 165, 385, 705, '2024-12-20T09:27:34.709Z', 15, 33, 3),
  (1018, 133, NULL, NULL, 185, 115, 275, 495, '2024-12-20T09:27:34.709Z', 9, 4, 2),
  (1018, NULL, 3011, NULL, 205, 35, 95, 175, '2024-12-20T09:27:34.709Z', 13, 25, 3),
  (1018, NULL, 3012, NULL, 145, 25, 65, 125, '2024-12-20T09:27:34.709Z', 17, 30, 4),
  (1018, NULL, NULL, 7001, 65, 12, 18, 32, '2024-12-20T09:27:34.709Z', 16, 34, 3),
  (1018, NULL, NULL, 7002, 45, 8, 12, 22, '2024-12-20T09:27:34.709Z', 14, 28, 3),
  (1019, 132, NULL, NULL, 2850, 475, 1085, 1975, '2024-12-20T09:27:34.709Z', 18, 46, 4),
  (1019, 133, NULL, NULL, 4950, 325, 785, 1425, '2024-12-20T09:27:34.709Z', 21, 95, 5),
  (1019, 134, NULL, NULL, 1385, 235, 555, 1025, '2024-12-20T09:27:34.709Z', 15, 38, 3),
  (1019, NULL, 4001, NULL, 405, 70, 175, 325, '2024-12-20T09:27:34.709Z', 14, 31, 3),
  (1019, NULL, 4002, NULL, 285, 50, 125, 235, '2024-12-20T09:27:34.709Z', 17, 36, 4),
  (1019, NULL, NULL, 8001, 95, 18, 25, 48, '2024-12-20T09:27:34.709Z', 22, 48, 5),
  (1019, NULL, NULL, 8002, 75, 14, 20, 38, '2024-12-20T09:27:34.709Z', 19, 43, 4),
  (1020, 134, NULL, NULL, 550, 425, 975, 1775, '2024-12-20T09:27:34.709Z', 16, 8, 3),
  (1020, 135, NULL, NULL, 1775, 295, 705, 1275, '2024-12-20T09:27:34.709Z', 20, 40, 4),
  (1020, 136, NULL, NULL, 245, 210, 495, 895, '2024-12-20T09:27:34.709Z', 12, 5, 2),
  (1020, NULL, 4003, NULL, 365, 62, 155, 285, '2024-12-20T09:27:34.709Z', 13, 29, 3),
  (1020, NULL, 4004, NULL, 255, 45, 115, 205, '2024-12-20T09:27:34.709Z', 16, 34, 3),
  (1020, NULL, NULL, 8003, 85, 16, 22, 42, '2024-12-20T09:27:34.709Z', 21, 45, 4),
  (1020, NULL, NULL, 8004, 65, 12, 18, 32, '2024-12-20T09:27:34.709Z', 18, 39, 4),
  (1021, 135, NULL, NULL, 3250, 545, 1235, 2275, '2024-12-20T09:27:34.709Z', 19, 49, 4),
  (1021, 136, NULL, NULL, 4550, 385, 855, 1575, '2024-12-20T09:27:34.709Z', 23, 95, 5),
  (1021, 137, NULL, NULL, 1585, 265, 635, 1175, '2024-12-20T09:27:34.709Z', 14, 37, 3),
  (1021, NULL, 4005, NULL, 465, 80, 195, 375, '2024-12-20T09:27:34.709Z', 15, 32, 3),
  (1021, NULL, 4006, NULL, 325, 55, 145, 265, '2024-12-20T09:27:34.709Z', 18, 38, 4),
  (1021, NULL, NULL, 8005, 105, 20, 28, 52, '2024-12-20T09:27:34.709Z', 24, 50, 5),
  (1021, NULL, NULL, 8006, 85, 15, 22, 42, '2024-12-20T09:27:34.709Z', 20, 44, 4),
  (1022, 137, NULL, NULL, 950, 495, 1125, 2025, '2024-12-20T09:27:34.709Z', 17, 12, 4),
  (1022, 138, NULL, NULL, 2025, 340, 805, 1475, '2024-12-20T09:27:34.709Z', 18, 41, 4),
  (1022, 139, NULL, NULL, 425, 240, 565, 1025, '2024-12-20T09:27:34.709Z', 21, 9, 5),
  (1022, NULL, 4007, NULL, 425, 72, 175, 335, '2024-12-20T09:27:34.709Z', 16, 33, 3),
  (1022, NULL, 4008, NULL, 295, 50, 125, 235, '2024-12-20T09:27:34.709Z', 19, 37, 4),
  (1022, NULL, NULL, 8007, 115, 22, 30, 58, '2024-12-20T09:27:34.709Z', 22, 46, 4),
  (1022, NULL, NULL, 8008, 95, 18, 25, 48, '2024-12-20T09:27:34.709Z', 20, 42, 4),
  (1023, 138, NULL, NULL, 2650, 445, 1005, 1825, '2024-12-20T09:27:34.709Z', 16, 45, 3),
  (1023, 139, NULL, NULL, 4875, 305, 725, 1325, '2024-12-20T09:27:34.709Z', 19, 85, 4),
  (1023, 140, NULL, NULL, 285, 215, 515, 935, '2024-12-20T09:27:34.709Z', 13, 5, 3),
  (1023, NULL, 4009, NULL, 385, 65, 165, 305, '2024-12-20T09:27:34.709Z', 14, 30, 3),
  (1023, NULL, 4010, NULL, 265, 45, 125, 225, '2024-12-20T09:27:34.709Z', 17, 35, 4),
  (1023, NULL, NULL, 8009, 105, 20, 28, 52, '2024-12-20T09:27:34.709Z', 21, 47, 4),
  (1023, NULL, NULL, 8010, 85, 15, 22, 42, '2024-12-20T09:27:34.709Z', 18, 40, 4),
  (1024, 140, NULL, NULL, 350, 395, 895, 1625, '2024-12-20T09:27:34.709Z', 15, 6, 3),
  (1024, 101, NULL, NULL, 625, 275, 645, 1175, '2024-12-20T09:27:34.709Z', 22, 8, 5),
  (1024, 102, NULL, NULL, 145, 195, 455, 825, '2024-12-20T09:27:34.709Z', 11, 4, 2),
  (1024, NULL, 4011, NULL, 345, 58, 145, 275, '2024-12-20T09:27:34.709Z', 12, 28, 2),
  (1024, NULL, 4012, NULL, 235, 40, 105, 195, '2024-12-20T09:27:34.709Z', 20, 36, 4),
  (1024, NULL, NULL, 8001, 95, 18, 25, 48, '2024-12-20T09:27:34.709Z', 18, 41, 4),
  (1024, NULL, NULL, 8002, 75, 14, 20, 38, '2024-12-20T09:27:34.709Z', 16, 37, 3);

-- MFG_PLANT (24 rows)
INSERT INTO SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.MFG_PLANT
  (MFG_PLANT_ID,
  MFG_PLANT_NAME,
  ADDRESS,
  CITY,
  STATE,
  COUNTRY,
  ZIP_CODE,
  LATITUDE,
  LONGITUDE,
  PLANT_MANAGER_CONTACT_ID,
  SQUARE_FOOTAGE,
  NUMBER_OF_EMPLOYEES,
  IS_ACTIVE,
  BUSINESS_LINE)
VALUES
  (1001,
  'Phoenix Aerospace Manufacturing',
  '1200 Aviation Blvd',
  'Phoenix',
  'AZ',
  'USA',
  85001,
  33.4484,
  -112.0740,
  10001,
  450000.00,
  850,
  TRUE,
  'AEROSPACE'),
  (1002,
  'Seattle Aircraft Components',
  '4500 Boeing Way',
  'Seattle',
  'WA',
  'USA',
  98101,
  47.6062,
  -122.3321,
  10002,
  380000.00,
  625,
  TRUE,
  'AEROSPACE'),
  (1003,
  'Wichita Aviation Systems',
  '800 Aerospace Dr',
  'Wichita',
  'KS',
  'USA',
  67201,
  37.6922,
  -97.3375,
  10003,
  520000.00,
  945,
  TRUE,
  'AEROSPACE'),
  (1004,
  'Fort Worth Defense Systems',
  '1500 Military Ave',
  'Fort Worth',
  'TX',
  'USA',
  76108,
  32.7555,
  -97.3308,
  10004,
  675000.00,
  1245,
  TRUE,
  'AEROSPACE'),
  (1005,
  'Long Beach Aircraft Assembly',
  '2800 Lakewood Blvd',
  'Long Beach',
  'CA',
  'USA',
  90806,
  33.7701,
  -118.1937,
  10005,
  890000.00,
  1850,
  TRUE,
  'AEROSPACE'),
  (1006,
  'Cincinnati Engine Components',
  '3200 Jet Engine Dr',
  'Cincinnati',
  'OH',
  'USA',
  45215,
  39.1031,
  -84.5120,
  10006,
  425000.00,
  765,
  TRUE,
  'AEROSPACE'),
  (1007,
  'Atlanta Industrial Automation',
  '2100 Technology Pkwy',
  'Atlanta',
  'GA',
  'USA',
  30309,
  33.7490,
  -84.3880,
  10007,
  485000.00,
  925,
  TRUE,
  'INDUSTRIAL'),
  (1008,
  'Milwaukee Process Control',
  '1800 Industrial Blvd',
  'Milwaukee',
  'WI',
  'USA',
  53204,
  43.0389,
  -87.9065,
  10008,
  365000.00,
  685,
  TRUE,
  'INDUSTRIAL'),
  (1009,
  'Houston Petrochemical Systems',
  '4200 Refinery Rd',
  'Houston',
  'TX',
  'USA',
  77001,
  29.7604,
  -95.3698,
  10009,
  750000.00,
  1450,
  TRUE,
  'INDUSTRIAL'),
  (1010,
  'Detroit Automotive Systems',
  '1600 Motor City Dr',
  'Detroit',
  'MI',
  'USA',
  48201,
  42.3314,
  -83.0458,
  10010,
  620000.00,
  1125,
  TRUE,
  'INDUSTRIAL'),
  (1011,
  'Chicago Manufacturing Control',
  '3500 Industrial Way',
  'Chicago',
  'IL',
  'USA',
  60601,
  41.8781,
  -87.6298,
  10011,
  445000.00,
  825,
  TRUE,
  'INDUSTRIAL'),
  (1012,
  'St. Louis Material Handling',
  '2400 Assembly Ave',
  'St. Louis',
  'MO',
  'USA',
  63101,
  38.6270,
  -90.1994,
  10012,
  535000.00,
  975,
  TRUE,
  'INDUSTRIAL'),
  (1013,
  'Denver Building Automation',
  '1900 Smart Building Dr',
  'Denver',
  'CO',
  'USA',
  80202,
  39.7392,
  -104.9903,
  10013,
  325000.00,
  485,
  TRUE,
  'BUILDINGS'),
  (1014,
  'Nashville HVAC Systems',
  '2600 Climate Control Ln',
  'Nashville',
  'TN',
  'USA',
  37201,
  36.1627,
  -86.7816,
  10014,
  395000.00,
  625,
  TRUE,
  'BUILDINGS'),
  (1015,
  'Tampa Security Systems',
  '1400 Safety Blvd',
  'Tampa',
  'FL',
  'USA',
  33601,
  27.9506,
  -82.4572,
  10015,
  285000.00,
  425,
  TRUE,
  'BUILDINGS'),
  (1016,
  'Phoenix Smart Lighting',
  '3100 LED Technology Dr',
  'Phoenix',
  'AZ',
  'USA',
  85003,
  33.4734,
  -112.0880,
  10016,
  245000.00,
  365,
  TRUE,
  'BUILDINGS'),
  (1017,
  'Portland Building Controls',
  '2200 Automation Ave',
  'Portland',
  'OR',
  'USA',
  97201,
  45.5152,
  -122.6784,
  10017,
  335000.00,
  515,
  TRUE,
  'BUILDINGS'),
  (1018,
  'Miami Facility Management',
  '1800 Property Control Way',
  'Miami',
  'FL',
  'USA',
  33101,
  25.7617,
  -80.1918,
  10018,
  275000.00,
  385,
  TRUE,
  'BUILDINGS'),
  (1019,
  'Austin Energy Storage',
  '3400 Battery Park Dr',
  'Austin',
  'TX',
  'USA',
  78701,
  30.2672,
  -97.7431,
  10019,
  685000.00,
  1285,
  TRUE,
  'ENERGY'),
  (1020,
  'San Francisco Solar Systems',
  '2800 Renewable Energy Blvd',
  'San Francisco',
  'CA',
  'USA',
  94103,
  37.7749,
  -122.4194,
  10020,
  425000.00,
  745,
  TRUE,
  'ENERGY'),
  (1021,
  'Portland Wind Power',
  '1600 Turbine Manufacturing Way',
  'Portland',
  'OR',
  'USA',
  97202,
  45.5051,
  -122.6750,
  10021,
  595000.00,
  1085,
  TRUE,
  'ENERGY'),
  (1022,
  'Phoenix Grid Solutions',
  '4100 Smart Grid Ave',
  'Phoenix',
  'AZ',
  'USA',
  85004,
  33.4484,
  -112.0640,
  10022,
  365000.00,
  625,
  TRUE,
  'ENERGY'),
  (1023,
  'Denver Microgrid Systems',
  '2300 Distributed Energy Dr',
  'Denver',
  'CO',
  'USA',
  80203,
  39.7317,
  -104.9542,
  10023,
  445000.00,
  785,
  TRUE,
  'ENERGY'),
  (1024,
  'San Jose EV Charging',
  '1700 Electric Vehicle Way',
  'San Jose',
  'CA',
  'USA',
  95101,
  37.3382,
  -121.8863,
  10024,
  315000.00,
  485,
  TRUE,
  'ENERGY');

-- ORDERS (50 rows)
INSERT INTO SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.ORDERS
  (ORDER_ID, CUSTOMER_ID, MFG_PLANT_ID, ORDER_DATE, PRODUCT_ID, QUANTITY, UNIT_PRICE, TOTAL_PRICE, ORDER_STATUS)
VALUES
  (1, 3001, 1001, '2024-11-15T08:30:00.000Z', 5001, 2, 125000.00, 250000.00, 'Delivered'),
  (2, 3002, 1002, '2024-12-02T14:15:00.000Z', 5002, 1, 85000.00, 85000.00, 'Shipped'),
  (3, 3003, 1003, '2024-12-10T09:45:00.000Z', 5003, 3, 95000.00, 285000.00, 'In Production'),
  (4, 3004, 1001, '2024-12-18T11:20:00.000Z', 5004, 1, 72000.00, 72000.00, 'Placed'),
  (5, 3005, 1002, '2024-12-22T16:30:00.000Z', 5005, 2, 58000.00, 116000.00, 'Placed'),
  (6, 3006, 1004, '2024-11-20T10:15:00.000Z', 5006, 1, 89000.00, 89000.00, 'Delivered'),
  (7, 3007, 1005, '2024-11-28T13:45:00.000Z', 5007, 1, 145000.00, 145000.00, 'Shipped'),
  (8, 3008, 1006, '2024-12-05T12:00:00.000Z', 5008, 2, 67000.00, 134000.00, 'In Production'),
  (9, 3009, 1004, '2024-12-12T15:30:00.000Z', 5009, 1, 78000.00, 78000.00, 'Placed'),
  (10, 3010, 1005, '2024-12-15T09:00:00.000Z', 5010, 3, 95000.00, 285000.00, 'Placed'),
  (11, 4001, 1007, '2024-11-25T11:45:00.000Z', 6001, 2, 145000.00, 290000.00, 'Delivered'),
  (12, 4002, 1008, '2024-12-01T14:20:00.000Z', 6002, 1, 185000.00, 185000.00, 'Shipped'),
  (13, 4003, 1009, '2024-12-08T10:30:00.000Z', 6003, 1, 95000.00, 95000.00, 'In Production'),
  (14, 4004, 1007, '2024-12-14T16:15:00.000Z', 6004, 2, 78000.00, 156000.00, 'Placed'),
  (15, 4005, 1008, '2024-12-20T13:00:00.000Z', 6005, 2, 65000.00, 130000.00, 'Placed'),
  (16, 4006, 1010, '2024-11-18T09:30:00.000Z', 6006, 1, 52000.00, 52000.00, 'Delivered'),
  (17, 4007, 1011, '2024-11-30T12:45:00.000Z', 6007, 2, 125000.00, 250000.00, 'Shipped'),
  (18, 4008, 1012, '2024-12-07T15:20:00.000Z', 6008, 1, 165000.00, 165000.00, 'In Production'),
  (19, 4009, 1010, '2024-12-13T11:00:00.000Z', 6009, 3, 115000.00, 345000.00, 'Placed'),
  (20, 4010, 1011, '2024-12-19T14:30:00.000Z', 6010, 1, 195000.00, 195000.00, 'Placed'),
  (21, 5001, 1013, '2024-11-22T10:15:00.000Z', 7001, 2, 89000.00, 178000.00, 'Delivered'),
  (22, 5002, 1014, '2024-12-03T13:45:00.000Z', 7002, 1, 125000.00, 125000.00, 'Shipped'),
  (23, 5003, 1015, '2024-12-09T11:30:00.000Z', 7003, 1, 95000.00, 95000.00, 'In Production'),
  (24, 5004, 1013, '2024-12-16T15:20:00.000Z', 7004, 5, 35000.00, 175000.00, 'Placed'),
  (25, 5005, 1014, '2024-12-21T12:00:00.000Z', 7005, 2, 78000.00, 156000.00, 'Placed'),
  (26, 5006, 1016, '2024-11-19T09:30:00.000Z', 7006, 1, 85000.00, 85000.00, 'Delivered'),
  (27, 5007, 1017, '2024-12-04T14:45:00.000Z', 7007, 2, 145000.00, 290000.00, 'Shipped'),
  (28, 5008, 1018, '2024-12-11T16:20:00.000Z', 7008, 1, 185000.00, 185000.00, 'In Production'),
  (29, 5009, 1015, '2024-12-17T10:00:00.000Z', 7009, 3, 95000.00, 285000.00, 'Placed'),
  (30, 5010, 1016, '2024-12-23T13:30:00.000Z', 7010, 1, 65000.00, 65000.00, 'Placed'),
  (31, 6001, 1019, '2024-11-21T11:15:00.000Z', 8001, 1, 450000.00, 450000.00, 'Delivered'),
  (32, 6002, 1020, '2024-12-05T15:45:00.000Z', 8002, 2, 285000.00, 570000.00, 'Shipped'),
  (33, 6003, 1021, '2024-12-12T12:30:00.000Z', 8003, 1, 650000.00, 650000.00, 'In Production'),
  (34, 6004, 1019, '2024-12-18T14:20:00.000Z', 8004, 3, 125000.00, 375000.00, 'Placed'),
  (35, 6005, 1020, '2024-12-24T16:00:00.000Z', 8005, 2, 85000.00, 170000.00, 'Placed'),
  (36, 6006, 1022, '2024-11-26T10:45:00.000Z', 8006, 1, 95000.00, 95000.00, 'Delivered'),
  (37, 6007, 1023, '2024-12-06T13:15:00.000Z', 8007, 1, 185000.00, 185000.00, 'Shipped'),
  (38, 6008, 1024, '2024-12-13T15:30:00.000Z', 8008, 2, 425000.00, 850000.00, 'In Production'),
  (39, 6009, 1022, '2024-12-19T11:45:00.000Z', 8009, 1, 375000.00, 375000.00, 'Placed'),
  (40, 6010, 1023, '2024-12-25T14:00:00.000Z', 8010, 3, 155000.00, 465000.00, 'Placed'),
  (41, 3001, 1003, '2024-11-17T09:15:00.000Z', 5002, 1, 85000.00, 85000.00, 'Delivered'),
  (42, 3002, 1001, '2024-12-04T16:30:00.000Z', 5003, 2, 95000.00, 190000.00, 'Shipped'),
  (43, 3004, 1006, '2024-12-11T13:45:00.000Z', 5001, 1, 125000.00, 125000.00, 'In Production'),
  (44, 4002, 1009, '2024-12-16T10:20:00.000Z', 6002, 1, 185000.00, 185000.00, 'Placed'),
  (45, 4005, 1012, '2024-12-22T14:15:00.000Z', 6005, 3, 65000.00, 195000.00, 'Placed'),
  (46, 5002, 1015, '2024-11-23T12:30:00.000Z', 7003, 2, 95000.00, 190000.00, 'Delivered'),
  (47, 5004, 1017, '2024-12-07T15:45:00.000Z', 7001, 1, 89000.00, 89000.00, 'Shipped'),
  (48, 6003, 1022, '2024-12-14T11:00:00.000Z', 8002, 2, 285000.00, 570000.00, 'In Production'),
  (49, 6007, 1024, '2024-12-20T16:30:00.000Z', 8004, 1, 125000.00, 125000.00, 'Placed'),
  (50, 6010, 1021, '2024-12-26T13:15:00.000Z', 8003, 1, 650000.00, 650000.00, 'Placed');

-- PRODUCT (40 rows)
INSERT INTO SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.PRODUCT
  (PRODUCT_ID, PRODUCT_NAME, PRODUCT_DESCRIPTION, PRODUCT_CATEGORY, UNIT_PRICE, BUSINESS_LINE)
VALUES
  (5001,
  'Flight Management System',
  'Complete flight management system for commercial aircraft with navigation and autopilot capabilities',
  'Avionics',
  125000.00,
  'AEROSPACE'),
  (5002,
  'Engine Monitoring System',
  'Real-time engine health monitoring system with predictive maintenance capabilities',
  'Engine Systems',
  85000.00,
  'AEROSPACE'),
  (5003,
  'Weather Radar System',
  'Advanced weather detection radar system for aircraft with turbulence prediction',
  'Safety Systems',
  95000.00,
  'AEROSPACE'),
  (5004,
  'Fuel Management System',
  'Automated fuel management and distribution system for large commercial aircraft',
  'Aircraft Systems',
  72000.00,
  'AEROSPACE'),
  (5005,
  'Landing Gear Controller',
  'Electronic landing gear control system with position monitoring and safety interlocks',
  'Aircraft Control',
  58000.00,
  'AEROSPACE'),
  (5006,
  'Navigation System',
  'Inertial navigation system with GPS integration for commercial aircraft',
  'Navigation',
  89000.00,
  'AEROSPACE'),
  (5007,
  'Communication System',
  'Integrated aircraft communication system with satellite and ground connectivity',
  'Communication',
  145000.00,
  'AEROSPACE'),
  (5008,
  'Cabin Pressure System',
  'Aircraft cabin pressurization and environmental control system',
  'Environmental Systems',
  67000.00,
  'AEROSPACE'),
  (5009,
  'Emergency Systems',
  'Aircraft emergency systems including oxygen masks and evacuation equipment',
  'Emergency Systems',
  78000.00,
  'AEROSPACE'),
  (5010,
  'Avionics Display System',
  'Primary flight display and multifunction display system for cockpit',
  'Display Systems',
  95000.00,
  'AEROSPACE'),
  (6001,
  'SCADA System',
  'Supervisory control and data acquisition system for industrial process monitoring',
  'Process Control',
  145000.00,
  'INDUSTRIAL'),
  (6002,
  'DCS Control System',
  'Distributed control system for large-scale industrial process automation',
  'Process Control',
  185000.00,
  'INDUSTRIAL'),
  (6003,
  'Safety Instrumented System',
  'SIL-rated safety system for critical industrial process protection',
  'Safety Systems',
  95000.00,
  'INDUSTRIAL'),
  (6004,
  'MES Production System',
  'Manufacturing execution system for production planning and tracking',
  'Manufacturing Software',
  78000.00,
  'INDUSTRIAL'),
  (6005,
  'Quality Control System',
  'Automated quality inspection and control system with machine vision',
  'Quality Systems',
  65000.00,
  'INDUSTRIAL'),
  (6006,
  'Asset Management System',
  'Industrial asset monitoring and predictive maintenance system',
  'Asset Management',
  52000.00,
  'INDUSTRIAL'),
  (6007,
  'Robotic Control System',
  'Advanced robotic control system with vision and motion planning capabilities',
  'Robotics',
  125000.00,
  'INDUSTRIAL'),
  (6008,
  'Motor Drive System',
  'Variable frequency drive system for industrial motor control and energy efficiency',
  'Drive Systems',
  165000.00,
  'INDUSTRIAL'),
  (6009,
  'Process Monitoring System',
  'Real-time process monitoring and control system for industrial applications',
  'Monitoring Systems',
  115000.00,
  'INDUSTRIAL'),
  (6010,
  'Material Handling System',
  'Automated material handling system with conveyor and sorting capabilities',
  'Material Handling',
  195000.00,
  'INDUSTRIAL'),
  (7001,
  'Building Management System',
  'Integrated building automation system for HVAC climate and energy control',
  'Building Automation',
  89000.00,
  'BUILDINGS'),
  (7002,
  'Security System',
  'Complete building security system with access control and surveillance',
  'Security Systems',
  125000.00,
  'BUILDINGS'),
  (7003, 'Fire Safety System', 'Comprehensive fire detection alarm and suppression system', 'Safety Systems', 95000.00, 'BUILDINGS'),
  (7004,
  'Smart Lighting System',
  'Intelligent LED lighting system with occupancy sensing and daylight harvesting',
  'Lighting Systems',
  35000.00,
  'BUILDINGS'),
  (7005,
  'HVAC Control System',
  'Advanced HVAC control system with energy optimization and zone control',
  'Climate Control',
  78000.00,
  'BUILDINGS'),
  (7006,
  'Energy Management System',
  'Building energy monitoring and optimization system with demand response',
  'Energy Management',
  85000.00,
  'BUILDINGS'),
  (7007,
  'Access Control System',
  'Advanced access control system with biometric and card-based authentication',
  'Access Control',
  145000.00,
  'BUILDINGS'),
  (7008,
  'Elevator Control System',
  'Modern elevator control system with destination dispatch and energy recovery',
  'Elevator Systems',
  185000.00,
  'BUILDINGS'),
  (7009,
  'Parking Management System',
  'Automated parking management system with license plate recognition',
  'Parking Systems',
  95000.00,
  'BUILDINGS'),
  (7010,
  'Emergency Communication System',
  'Building-wide emergency communication and notification system',
  'Emergency Systems',
  65000.00,
  'BUILDINGS'),
  (8001,
  'Battery Energy Storage System',
  'Large-scale lithium-ion battery energy storage system for grid applications',
  'Energy Storage',
  450000.00,
  'ENERGY'),
  (8002,
  'Solar Power System',
  'Complete photovoltaic solar power generation system with inverters and monitoring',
  'Solar Energy',
  285000.00,
  'ENERGY'),
  (8003,
  'Wind Power System',
  'Wind turbine power generation system with grid synchronization controls',
  'Wind Energy',
  650000.00,
  'ENERGY'),
  (8004,
  'Microgrid Controller',
  'Intelligent microgrid management system for distributed energy resources',
  'Grid Control',
  125000.00,
  'ENERGY'),
  (8005,
  'Grid-Scale Inverter',
  'High-power grid-tie inverter for utility-scale renewable energy integration',
  'Power Electronics',
  85000.00,
  'ENERGY'),
  (8006,
  'Energy Management Platform',
  'Cloud-based energy management and optimization platform for smart grids',
  'Energy Software',
  95000.00,
  'ENERGY'),
  (8007,
  'Electric Vehicle Charging System',
  'Level 3 DC fast charging system for electric vehicles with smart grid integration',
  'EV Charging',
  185000.00,
  'ENERGY'),
  (8008,
  'Fuel Cell Power System',
  'Hydrogen fuel cell power generation system for stationary applications',
  'Fuel Cell Systems',
  425000.00,
  'ENERGY'),
  (8009,
  'Grid Stabilization System',
  'Power electronics system for grid frequency and voltage stabilization',
  'Grid Systems',
  375000.00,
  'ENERGY'),
  (8010,
  'Energy Analytics Platform',
  'Advanced energy analytics platform with AI-powered optimization',
  'Analytics Systems',
  155000.00,
  'ENERGY');

-- RAW_MATERIAL (40 rows)
INSERT INTO SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.RAW_MATERIAL
  (MATERIAL_ID, MATERIAL_NAME, MATERIAL_DESCRIPTION, SUPPLIER_ID, MATERIAL_COST, PLANT_TRANSPORT_COST, BUSINESS_LINE)
VALUES
  (101,
  'Aluminum Alloy 6061-T6',
  'High-strength aluminum alloy suitable for aerospace and automotive applications',
  9001,
  8.50,
  2.15,
  'AEROSPACE'),
  (102, 'Carbon Fiber Composite', 'Lightweight high-strength carbon fiber reinforced polymer sheets', 9003, 45.75, 8.25, 'AEROSPACE'),
  (103,
  'Titanium Grade 5 Alloy',
  'Aerospace-grade titanium alloy with excellent strength-to-weight ratio',
  9002,
  125.00,
  18.50,
  'AEROSPACE'),
  (104, 'Inconel 718', 'High-temperature nickel-chromium superalloy for jet engine components', 9001, 85.25, 12.75, 'AEROSPACE'),
  (105, 'Aluminum 7075-T6', 'Ultra-high strength aluminum alloy for aerospace structural applications', 9001, 12.80, 3.20, 'AEROSPACE'),
  (106, 'Kevlar Aramid Fiber', 'High-strength aramid fiber for ballistic and structural applications', 9003, 38.90, 7.50, 'AEROSPACE'),
  (107, 'Magnesium AZ91D', 'Lightweight magnesium alloy for aerospace and automotive components', 9002, 22.45, 5.85, 'AEROSPACE'),
  (108, 'Stainless Steel 15-5 PH', 'Precipitation-hardening stainless steel for aerospace applications', 9001, 18.60, 4.25, 'AEROSPACE'),
  (109, 'Ceramic Matrix Composite', 'Advanced ceramic matrix composite for high-temperature applications', 9003, 95.30, 15.40, 'AEROSPACE'),
  (110,
  'Titanium 6Al-4V Wire',
  'Titanium alloy wire for additive manufacturing and welding applications',
  9002,
  145.75,
  22.80,
  'AEROSPACE'),
  (111, 'Carbon Steel A36', 'General purpose structural carbon steel for industrial applications', 9007, 3.25, 1.80, 'INDUSTRIAL'),
  (112, 'Stainless Steel 304', 'Austenitic stainless steel for industrial equipment and piping', 9007, 8.75, 2.95, 'INDUSTRIAL'),
  (113, 'Copper C101', 'High-conductivity oxygen-free copper for electrical applications', 9009, 12.40, 3.60, 'INDUSTRIAL'),
  (114, 'Aluminum 6063-T5', 'Extruded aluminum alloy for industrial framing and structures', 9007, 6.85, 2.40, 'INDUSTRIAL'),
  (115, 'Brass C360', 'Free-machining brass for industrial fittings and components', 9009, 9.95, 3.15, 'INDUSTRIAL'),
  (116, 'PVC Plastic Resin', 'Polyvinyl chloride resin for industrial pipe and fitting applications', 9008, 2.85, 1.25, 'INDUSTRIAL'),
  (117, 'Nylon 6/6 Plastic', 'High-strength nylon polymer for industrial gears and bearings', 9008, 7.40, 2.60, 'INDUSTRIAL'),
  (118, 'Polyurethane Elastomer', 'Flexible polyurethane for industrial seals and gaskets', 9008, 11.25, 3.80, 'INDUSTRIAL'),
  (119, 'Silicon Steel', 'Electrical silicon steel for transformer and motor cores', 9007, 5.65, 2.10, 'INDUSTRIAL'),
  (120, 'Tool Steel D2', 'High-carbon high-chromium tool steel for industrial cutting tools', 9007, 15.80, 4.45, 'INDUSTRIAL'),
  (121, 'ABS Plastic Resin', 'Acrylonitrile butadiene styrene plastic for building components', 9014, 4.20, 1.90, 'BUILDINGS'),
  (122, 'Polycarbonate Sheet', 'Clear polycarbonate sheet for building glazing and safety applications', 9014, 8.95, 3.25, 'BUILDINGS'),
  (123, 'Fiberglass Insulation', 'Thermal insulation fiberglass for building envelope applications', 9014, 1.85, 0.95, 'BUILDINGS'),
  (124, 'Vinyl Siding Material', 'PVC vinyl siding material for exterior building cladding', 9014, 3.60, 1.65, 'BUILDINGS'),
  (125, 'Gypsum Wallboard', 'Gypsum-based wallboard for interior building construction', 9014, 2.15, 1.20, 'BUILDINGS'),
  (126, 'Ceramic Tile Material', 'Porcelain ceramic tile material for building flooring applications', 9014, 6.75, 2.85, 'BUILDINGS'),
  (127, 'LED Semiconductor', 'High-efficiency LED semiconductor chips for lighting applications', 9017, 12.50, 4.20, 'BUILDINGS'),
  (128, 'Copper Wire 12 AWG', 'Solid copper electrical wire for building wiring systems', 9009, 4.85, 2.05, 'BUILDINGS'),
  (129, 'Steel Reinforcement Bar', 'Carbon steel rebar for concrete reinforcement in buildings', 9014, 2.95, 1.45, 'BUILDINGS'),
  (130, 'Glass Fiber Mesh', 'Alkali-resistant glass fiber mesh for building facade systems', 9014, 3.40, 1.75, 'BUILDINGS'),
  (131, 'Lithium Iron Phosphate', 'LiFePO4 cathode material for energy storage battery applications', 9027, 28.50, 6.75, 'ENERGY'),
  (132, 'Silicon Solar Cell', 'High-efficiency monocrystalline silicon solar cell material', 9021, 15.80, 4.95, 'ENERGY'),
  (133, 'Neodymium Magnet', 'Rare earth permanent magnet for wind turbine generators', 9023, 45.25, 8.60, 'ENERGY'),
  (134, 'Electrolyte Solution', 'Lithium salt electrolyte solution for battery manufacturing', 9027, 22.90, 5.40, 'ENERGY'),
  (135, 'Graphite Anode Material', 'Synthetic graphite anode material for lithium-ion batteries', 9027, 18.75, 4.25, 'ENERGY'),
  (136, 'Silver Paste', 'Conductive silver paste for solar cell metallization', 9021, 85.60, 12.30, 'ENERGY'),
  (137, 'Copper Foil', 'High-purity copper foil for battery current collectors', 9024, 24.40, 5.85, 'ENERGY'),
  (138, 'Separator Film', 'Polyethylene separator film for lithium-ion battery cells', 9027, 16.25, 3.90, 'ENERGY'),
  (139, 'Aluminum Frame', 'Extruded aluminum frame for solar panel mounting systems', 9024, 8.95, 2.75, 'ENERGY'),
  (140, 'Tempered Glass', 'Low-iron tempered glass for solar panel front covers', 9021, 12.60, 3.45, 'ENERGY');

-- SHIPMENT (45 rows)
INSERT INTO SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SHIPMENT
  (SHIPMENT_ID,
  ORIGIN_MFG_PLANT_ID,
  DESTINATION_CUSTOMER_ID,
  SHIP_DATE,
  EXPECTED_DELIVERY_DATE,
  ACTUAL_DELIVERY_DATE,
  SHIPPING_COST,
  TRACKING_NUMBER)
VALUES
  (1001, 1001, 3001, '2024-11-16', '2024-11-20', '2024-11-19', 2850.75, 'TRK001001AA'),
  (1002, 1002, 3002, '2024-12-03', '2024-12-08', '2024-12-07', 1950.25, 'TRK002001BB'),
  (1003, 1003, 3003, '2024-12-11', '2024-12-17', '2024-12-16', 3450.60, 'TRK003001CC'),
  (1004, 1001, 3004, '2024-12-19', '2024-12-25', '2024-12-24', 2750.40, 'TRK004001DD'),
  (1005, 1002, 3005, '2024-12-23', '2024-12-29', '2024-12-28', 3150.80, 'TRK005001EE'),
  (1006, 1004, 3006, '2024-11-21', '2024-11-27', '2024-11-26', 1850.30, 'TRK006001FF'),
  (1007, 1005, 3007, '2024-11-29', '2024-12-05', '2024-12-04', 2950.45, 'TRK007001GG'),
  (1008, 1006, 3008, '2024-12-06', '2024-12-12', '2024-12-11', 4250.85, 'TRK008001HH'),
  (1009, 1004, 3009, '2024-12-13', '2024-12-19', '2024-12-18', 3750.65, 'TRK009001II'),
  (1010, 1005, 3010, '2024-12-16', '2024-12-22', '2024-12-21', 2650.95, 'TRK010001JJ'),
  (1011, 1007, 4001, '2024-11-26', '2024-12-02', '2024-12-01', 1950.50, 'TRK011001KK'),
  (1012, 1008, 4002, '2024-12-02', '2024-12-08', '2024-12-07', 2150.75, 'TRK012001LL'),
  (1013, 1009, 4003, '2024-12-09', '2024-12-15', '2024-12-14', 3350.40, 'TRK013001MM'),
  (1014, 1007, 4004, '2024-12-15', '2024-12-21', '2024-12-20', 2850.60, 'TRK014001NN'),
  (1015, 1008, 4005, '2024-12-21', '2024-12-27', '2024-12-26', 2450.85, 'TRK015001OO'),
  (1016, 1010, 4006, '2024-11-19', '2024-11-25', '2024-11-24', 2750.25, 'TRK016001PP'),
  (1017, 1011, 4007, '2024-12-01', '2024-12-07', '2024-12-06', 1950.70, 'TRK017001QQ'),
  (1018, 1012, 4008, '2024-12-08', '2024-12-14', '2024-12-13', 4850.90, 'TRK018001RR'),
  (1019, 1010, 4009, '2024-12-14', '2024-12-20', '2024-12-19', 3650.55, 'TRK019001SS'),
  (1020, 1011, 4010, '2024-12-20', '2024-12-26', '2024-12-25', 2950.80, 'TRK020001TT'),
  (1021, 1013, 5001, '2024-11-23', '2024-11-29', '2024-11-28', 1850.45, 'TRK021001UU'),
  (1022, 1014, 5002, '2024-12-04', '2024-12-10', '2024-12-09', 2150.60, 'TRK022001VV'),
  (1023, 1015, 5003, '2024-12-10', '2024-12-16', '2024-12-15', 3250.75, 'TRK023001WW'),
  (1024, 1013, 5004, '2024-12-17', '2024-12-23', '2024-12-22', 2750.90, 'TRK024001XX'),
  (1025, 1014, 5005, '2024-12-22', '2024-12-28', '2024-12-27', 2350.40, 'TRK025001YY'),
  (1026, 1016, 5006, '2024-11-20', '2024-11-26', '2024-11-25', 1950.85, 'TRK026001ZZ'),
  (1027, 1017, 5007, '2024-12-05', '2024-12-11', '2024-12-10', 2650.75, 'TRK027001AAA'),
  (1028, 1018, 5008, '2024-12-12', '2024-12-18', '2024-12-17', 3450.90, 'TRK028001BBB'),
  (1029, 1015, 5009, '2024-12-18', '2024-12-24', '2024-12-23', 2850.65, 'TRK029001CCC'),
  (1030, 1016, 5010, '2024-12-24', '2024-12-30', '2024-12-29', 2150.50, 'TRK030001DDD'),
  (1031, 1019, 6001, '2024-11-22', '2024-11-28', '2024-11-27', 4850.75, 'TRK031001EEE'),
  (1032, 1020, 6002, '2024-12-06', '2024-12-12', '2024-12-11', 5250.90, 'TRK032001FFF'),
  (1033, 1021, 6003, '2024-12-13', '2024-12-19', '2024-12-18', 6850.40, 'TRK033001GGG'),
  (1034, 1019, 6004, '2024-12-19', '2024-12-25', '2024-12-24', 4250.65, 'TRK034001HHH'),
  (1035, 1020, 6005, '2024-12-25', '2024-12-31', '2024-12-30', 3650.85, 'TRK035001III'),
  (1036, 1022, 6006, '2024-11-27', '2024-12-03', '2024-12-02', 2950.50, 'TRK036001JJJ'),
  (1037, 1023, 6007, '2024-12-07', '2024-12-13', '2024-12-12', 3850.75, 'TRK037001KKK'),
  (1038, 1024, 6008, '2024-12-14', '2024-12-20', '2024-12-19', 7250.90, 'TRK038001LLL'),
  (1039, 1022, 6009, '2024-12-20', '2024-12-26', '2024-12-25', 5450.65, 'TRK039001MMM'),
  (1040, 1023, 6010, '2024-12-26', '2025-01-01', '2024-12-31', 4850.80, 'TRK040001NNN'),
  (1041, 1003, 3001, '2024-11-18', '2024-11-24', '2024-11-23', 2150.45, 'TRK041001OOO'),
  (1042, 1001, 3002, '2024-12-05', '2024-12-11', '2024-12-10', 2650.60, 'TRK042001PPP'),
  (1043, 1006, 3004, '2024-12-12', '2024-12-18', '2024-12-17', 3250.75, 'TRK043001QQQ'),
  (1044, 1009, 4002, '2024-12-17', '2024-12-23', '2024-12-22', 3850.90, 'TRK044001RRR'),
  (1045, 1012, 4005, '2024-12-23', '2024-12-29', '2024-12-28', 4250.40, 'TRK045001SSS');

-- SUPPLIERS (35 rows)
INSERT INTO SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLIERS
  (SUPPLIER_ID,
  SUPPLIER_NAME,
  ADDRESS,
  CITY,
  STATE,
  COUNTRY,
  ZIP_CODE,
  CONTACT_PERSON_NAME,
  CONTACT_EMAIL,
  CONTACT_PHONE,
  SUPPLIER_TYPE,
  BUSINESS_LINE,
  IS_PREFERRED,
  PAYMENT_TERMS)
VALUES
  (9001,
  'Aerospace Materials Corp',
  '1200 Aviation Blvd',
  'Seattle',
  'WA',
  'USA',
  98101,
  'Sarah Johnson',
  'sarah.johnson@aeromat.com',
  '206-555-0101',
  'Raw Materials',
  'AEROSPACE',
  TRUE,
  'Net 30'),
  (9002,
  'Titanium Alloys International',
  '4500 Industrial Way',
  'Phoenix',
  'AZ',
  'USA',
  85001,
  'Michael Chen',
  'm.chen@titaniumalloys.com',
  '602-555-0102',
  'Raw Materials',
  'AEROSPACE',
  TRUE,
  'Net 45'),
  (9003,
  'Carbon Fiber Solutions',
  '800 Composite Dr',
  'Wichita',
  'KS',
  'USA',
  67201,
  'Jennifer Davis',
  'j.davis@carbonfibersol.com',
  '316-555-0103',
  'Raw Materials',
  'AEROSPACE',
  FALSE,
  'Net 60'),
  (9004,
  'Precision Electronics Ltd',
  '2100 Circuit Ave',
  'Austin',
  'TX',
  'USA',
  78701,
  'Robert Kim',
  'r.kim@precisionelec.com',
  '512-555-0104',
  'Components',
  'AEROSPACE',
  TRUE,
  'Net 30'),
  (9005,
  'Avionics Systems Inc',
  '3300 Flight Control Rd',
  'Fort Worth',
  'TX',
  'USA',
  76155,
  'Lisa Wang',
  'l.wang@avionicsys.com',
  '817-555-0105',
  'Components',
  'AEROSPACE',
  TRUE,
  'Net 30'),
  (9006,
  'Hydraulic Components Co',
  '1750 Pressure Ln',
  'San Diego',
  'CA',
  'USA',
  92101,
  'David Miller',
  'd.miller@hydrauliccomp.com',
  '619-555-0106',
  'Components',
  'AEROSPACE',
  FALSE,
  'Net 45'),
  (9007,
  'Steel Works Industries',
  '5000 Foundry St',
  'Pittsburgh',
  'PA',
  'USA',
  15201,
  'Amanda Rodriguez',
  'a.rodriguez@steelworks.com',
  '412-555-0107',
  'Raw Materials',
  'INDUSTRIAL',
  TRUE,
  'Net 30'),
  (9008,
  'Advanced Polymers LLC',
  '2800 Chemical Blvd',
  'Houston',
  'TX',
  'USA',
  77001,
  'Thomas Anderson',
  't.anderson@advpolymers.com',
  '713-555-0108',
  'Raw Materials',
  'INDUSTRIAL',
  TRUE,
  'Net 45'),
  (9009,
  'Copper Wire Specialists',
  '900 Conductor Ave',
  'Detroit',
  'MI',
  'USA',
  48201,
  'Rachel Green',
  'r.green@copperwire.com',
  '313-555-0109',
  'Raw Materials',
  'INDUSTRIAL',
  FALSE,
  'Net 30'),
  (9010,
  'Industrial Electronics Corp',
  '4200 Automation Dr',
  'Milwaukee',
  'WI',
  'USA',
  53201,
  'Kevin Brown',
  'k.brown@indelec.com',
  '414-555-0110',
  'Components',
  'INDUSTRIAL',
  TRUE,
  'Net 30'),
  (9011,
  'Motor Technologies Inc',
  '1600 Drive Systems Way',
  'Cleveland',
  'OH',
  'USA',
  44101,
  'Maria Garcia',
  'm.garcia@motortech.com',
  '216-555-0111',
  'Components',
  'INDUSTRIAL',
  TRUE,
  'Net 45'),
  (9012,
  'Sensor Solutions Ltd',
  '3100 Measurement Rd',
  'Chicago',
  'IL',
  'USA',
  60601,
  'James Wilson',
  'j.wilson@sensorsol.com',
  '312-555-0112',
  'Components',
  'INDUSTRIAL',
  FALSE,
  'Net 60'),
  (9013,
  'Control Systems Pro',
  '2500 Logic Ln',
  'Atlanta',
  'GA',
  'USA',
  30301,
  'Susan Taylor',
  's.taylor@controlsys.com',
  '404-555-0113',
  'Components',
  'INDUSTRIAL',
  TRUE,
  'Net 30'),
  (9014,
  'Smart Building Materials',
  '1800 Construction Ave',
  'Denver',
  'CO',
  'USA',
  80201,
  'Mark Thompson',
  'm.thompson@smartbuild.com',
  '303-555-0114',
  'Raw Materials',
  'BUILDINGS',
  TRUE,
  'Net 30'),
  (9015,
  'HVAC Components Direct',
  '3600 Climate Dr',
  'Nashville',
  'TN',
  'USA',
  37201,
  'Nicole Martinez',
  'n.martinez@hvaccomp.com',
  '615-555-0115',
  'Components',
  'BUILDINGS',
  TRUE,
  'Net 45'),
  (9016,
  'Security Systems Supply',
  '1200 Safety Blvd',
  'Las Vegas',
  'NV',
  'USA',
  89101,
  'Christopher Lee',
  'c.lee@securitysys.com',
  '702-555-0116',
  'Components',
  'BUILDINGS',
  FALSE,
  'Net 30'),
  (9017,
  'LED Lighting Solutions',
  '2900 Illumination St',
  'Portland',
  'OR',
  'USA',
  97201,
  'Ashley Davis',
  'a.davis@ledlighting.com',
  '503-555-0117',
  'Components',
  'BUILDINGS',
  TRUE,
  'Net 30'),
  (9018,
  'Access Control Tech',
  '4100 Entry Way',
  'Boston',
  'MA',
  'USA',
  02101,
  'Daniel Johnson',
  'd.johnson@accesscontrol.com',
  '617-555-0118',
  'Components',
  'BUILDINGS',
  TRUE,
  'Net 45'),
  (9019,
  'Fire Safety Systems',
  '1500 Protection Ave',
  'Phoenix',
  'AZ',
  'USA',
  85002,
  'Laura Wilson',
  'l.wilson@firesafety.com',
  '602-555-0119',
  'Components',
  'BUILDINGS',
  FALSE,
  'Net 60'),
  (9020,
  'Building Automation Parts',
  '3400 Integration Rd',
  'Miami',
  'FL',
  'USA',
  33101,
  'Ryan Martinez',
  'r.martinez@buildauto.com',
  '305-555-0120',
  'Components',
  'BUILDINGS',
  TRUE,
  'Net 30'),
  (9021,
  'Solar Panel Materials',
  '2200 Renewable Dr',
  'San Francisco',
  'CA',
  'USA',
  94101,
  'Jessica Chen',
  'j.chen@solarmaterials.com',
  '415-555-0121',
  'Raw Materials',
  'ENERGY',
  TRUE,
  'Net 30'),
  (9022,
  'Battery Technologies Corp',
  '1900 Energy Storage Way',
  'Austin',
  'TX',
  'USA',
  78702,
  'Andrew Kim',
  'a.kim@batterytech.com',
  '512-555-0122',
  'Components',
  'ENERGY',
  TRUE,
  'Net 45'),
  (9023,
  'Wind Turbine Components',
  '5200 Turbine Blvd',
  'Kansas City',
  'MO',
  'USA',
  64101,
  'Melissa Rodriguez',
  'm.rodriguez@windcomp.com',
  '816-555-0123',
  'Components',
  'ENERGY',
  FALSE,
  'Net 30'),
  (9024,
  'Energy Storage Materials',
  '3800 Grid Ave',
  'Seattle',
  'WA',
  'USA',
  98102,
  'Jonathan Brown',
  'j.brown@energystorage.com',
  '206-555-0124',
  'Raw Materials',
  'ENERGY',
  TRUE,
  'Net 30'),
  (9025,
  'Power Electronics Ltd',
  '1400 Inverter Ln',
  'San Jose',
  'CA',
  'USA',
  95101,
  'Stephanie Taylor',
  's.taylor@powerelec.com',
  '408-555-0125',
  'Components',
  'ENERGY',
  TRUE,
  'Net 45'),
  (9026,
  'Renewable Systems Supply',
  '2600 Green Energy St',
  'Portland',
  'OR',
  'USA',
  97202,
  'Brian Anderson',
  'b.anderson@renewablesys.com',
  '503-555-0126',
  'Components',
  'ENERGY',
  FALSE,
  'Net 60'),
  (9027,
  'Lithium Materials Inc',
  '4300 Battery Raw Dr',
  'Reno',
  'NV',
  'USA',
  89501,
  'Christina Davis',
  'c.davis@lithiummaterials.com',
  '775-555-0127',
  'Raw Materials',
  'ENERGY',
  TRUE,
  'Net 30'),
  (9028,
  'Smart Grid Components',
  '1100 Distribution Way',
  'Denver',
  'CO',
  'USA',
  80202,
  'Matthew Wilson',
  'm.wilson@smartgrid.com',
  '303-555-0128',
  'Components',
  'ENERGY',
  TRUE,
  'Net 45'),
  (9029,
  'Energy Efficiency Parts',
  '3500 Conservation Rd',
  'Minneapolis',
  'MN',
  'USA',
  55401,
  'Amanda Johnson',
  'a.johnson@energyeff.com',
  '612-555-0129',
  'Components',
  'ENERGY',
  FALSE,
  'Net 30'),
  (9030,
  'Sustainable Tech Supply',
  '2000 Clean Energy Ave',
  'Salt Lake City',
  'UT',
  'USA',
  84101,
  'Tyler Martinez',
  't.martinez@sustaintech.com',
  '801-555-0130',
  'Components',
  'ENERGY',
  TRUE,
  'Net 30'),
  (9031,
  'Precision Machining Works',
  '1700 Manufacturing Dr',
  'Grand Rapids',
  'MI',
  'USA',
  49501,
  'Emily Thompson',
  'e.thompson@precisionmach.com',
  '616-555-0131',
  'Raw Materials',
  'INDUSTRIAL',
  TRUE,
  'Net 30'),
  (9032,
  'Aerospace Fasteners Pro',
  '2300 Assembly Ln',
  'Long Beach',
  'CA',
  'USA',
  90801,
  'Jacob Garcia',
  'j.garcia@aerofasteners.com',
  '562-555-0132',
  'Components',
  'AEROSPACE',
  TRUE,
  'Net 45'),
  (9033,
  'Industrial Coatings Corp',
  '4600 Surface Treatment St',
  'Cincinnati',
  'OH',
  'USA',
  45201,
  'Sarah Miller',
  's.miller@indcoatings.com',
  '513-555-0133',
  'Raw Materials',
  'INDUSTRIAL',
  FALSE,
  'Net 30'),
  (9034,
  'Building Systems Integration',
  '1300 Facility Ave',
  'Tampa',
  'FL',
  'USA',
  33601,
  'Michael Davis',
  'm.davis@buildsysint.com',
  '813-555-0134',
  'Components',
  'BUILDINGS',
  TRUE,
  'Net 30'),
  (9035,
  'Energy Management Solutions',
  '3700 Efficiency Blvd',
  'Charlotte',
  'NC',
  'USA',
  28201,
  'Jennifer Wilson',
  'j.wilson@energymgmt.com',
  '704-555-0135',
  'Components',
  'ENERGY',
  TRUE,
  'Net 45');

-- TRANSPORT_COST_SURCHARGE (552 rows)
INSERT INTO SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.TRANSPORT_COST_SURCHARGE
  (SOURCE_FACILITY_ID, DESTINATION_FACILITY_ID, TRANSPORT_COST_SURCHARGE)
VALUES
  (1001, 1002, 1.25),
  (1001, 1003, 1.30),
  (1001, 1004, 1.15),
  (1001, 1005, 1.35),
  (1001, 1006, 1.20),
  (1001, 1007, 1.40),
  (1001, 1008, 1.10),
  (1001, 1009, 1.45),
  (1001, 1010, 1.05),
  (1001, 1011, 1.30),
  (1001, 1012, 1.50),
  (1001, 1013, 1.18),
  (1001, 1014, 1.32),
  (1001, 1015, 1.42),
  (1001, 1016, 1.08),
  (1001, 1017, 1.38),
  (1001, 1018, 1.48),
  (1001, 1019, 1.22),
  (1001, 1020, 1.28),
  (1001, 1021, 1.35),
  (1001, 1022, 1.12),
  (1001, 1023, 1.25),
  (1001, 1024, 1.45),
  (1002, 1001, 1.25),
  (1002, 1003, 1.15),
  (1002, 1004, 1.40),
  (1002, 1005, 1.45),
  (1002, 1006, 1.35),
  (1002, 1007, 1.25),
  (1002, 1008, 1.20),
  (1002, 1009, 1.50),
  (1002, 1010, 1.55),
  (1002, 1011, 1.40),
  (1002, 1012, 1.10),
  (1002, 1013, 1.28),
  (1002, 1014, 1.38),
  (1002, 1015, 1.52),
  (1002, 1016, 1.18),
  (1002, 1017, 1.12),
  (1002, 1018, 1.58),
  (1002, 1019, 1.32),
  (1002, 1020, 1.22),
  (1002, 1021, 1.15),
  (1002, 1022, 1.35),
  (1002, 1023, 1.42),
  (1002, 1024, 1.48),
  (1003, 1001, 1.30),
  (1003, 1002, 1.15),
  (1003, 1004, 1.25),
  (1003, 1005, 1.20),
  (1003, 1006, 1.10),
  (1003, 1007, 1.35),
  (1003, 1008, 1.40),
  (1003, 1009, 1.30),
  (1003, 1010, 1.45),
  (1003, 1011, 1.25),
  (1003, 1012, 1.50),
  (1003, 1013, 1.22),
  (1003, 1014, 1.18),
  (1003, 1015, 1.45),
  (1003, 1016, 1.32),
  (1003, 1017, 1.42),
  (1003, 1018, 1.55),
  (1003, 1019, 1.38),
  (1003, 1020, 1.48),
  (1003, 1021, 1.35),
  (1003, 1022, 1.28),
  (1003, 1023, 1.15),
  (1003, 1024, 1.52),
  (1004, 1001, 1.15),
  (1004, 1002, 1.40),
  (1004, 1003, 1.25),
  (1004, 1005, 1.10),
  (1004, 1006, 1.05),
  (1004, 1007, 1.30),
  (1004, 1008, 1.35),
  (1004, 1009, 1.20),
  (1004, 1010, 1.50),
  (1004, 1011, 1.45),
  (1004, 1012, 1.55),
  (1004, 1013, 1.35),
  (1004, 1014, 1.25),
  (1004, 1015, 1.38),
  (1004, 1016, 1.22),
  (1004, 1017, 1.48),
  (1004, 1018, 1.42),
  (1004, 1019, 1.12),
  (1004, 1020, 1.58),
  (1004, 1021, 1.45),
  (1004, 1022, 1.18),
  (1004, 1023, 1.32),
  (1004, 1024, 1.28),
  (1005, 1001, 1.35),
  (1005, 1002, 1.45),
  (1005, 1003, 1.20),
  (1005, 1004, 1.10),
  (1005, 1006, 1.25),
  (1005, 1007, 1.40),
  (1005, 1008, 1.30),
  (1005, 1009, 1.15),
  (1005, 1010, 1.35),
  (1005, 1011, 1.05),
  (1005, 1012, 1.50),
  (1005, 1013, 1.42),
  (1005, 1014, 1.38),
  (1005, 1015, 1.28),
  (1005, 1016, 1.45),
  (1005, 1017, 1.35),
  (1005, 1018, 1.22),
  (1005, 1019, 1.18),
  (1005, 1020, 1.12),
  (1005, 1021, 1.52),
  (1005, 1022, 1.48),
  (1005, 1023, 1.55),
  (1005, 1024, 1.32),
  (1006, 1001, 1.20),
  (1006, 1002, 1.35),
  (1006, 1003, 1.10),
  (1006, 1004, 1.05),
  (1006, 1005, 1.25),
  (1006, 1007, 1.15),
  (1006, 1008, 1.45),
  (1006, 1009, 1.40),
  (1006, 1010, 1.55),
  (1006, 1011, 1.30),
  (1006, 1012, 1.25),
  (1006, 1013, 1.32),
  (1006, 1014, 1.42),
  (1006, 1015, 1.35),
  (1006, 1016, 1.28),
  (1006, 1017, 1.52),
  (1006, 1018, 1.38),
  (1006, 1019, 1.48),
  (1006, 1020, 1.45),
  (1006, 1021, 1.18),
  (1006, 1022, 1.22),
  (1006, 1023, 1.58),
  (1006, 1024, 1.15),
  (1007, 1001, 1.40),
  (1007, 1002, 1.25),
  (1007, 1003, 1.35),
  (1007, 1004, 1.30),
  (1007, 1005, 1.40),
  (1007, 1006, 1.15),
  (1007, 1008, 1.05),
  (1007, 1009, 1.45),
  (1007, 1010, 1.50),
  (1007, 1011, 1.35),
  (1007, 1012, 1.20),
  (1007, 1013, 1.18),
  (1007, 1014, 1.12),
  (1007, 1015, 1.32),
  (1007, 1016, 1.38),
  (1007, 1017, 1.55),
  (1007, 1018, 1.25),
  (1007, 1019, 1.42),
  (1007, 1020, 1.52),
  (1007, 1021, 1.48),
  (1007, 1022, 1.35),
  (1007, 1023, 1.28),
  (1007, 1024, 1.45),
  (1008, 1001, 1.10),
  (1008, 1002, 1.20),
  (1008, 1003, 1.40),
  (1008, 1004, 1.35),
  (1008, 1005, 1.30),
  (1008, 1006, 1.45),
  (1008, 1007, 1.05),
  (1008, 1009, 1.25),
  (1008, 1010, 1.15),
  (1008, 1011, 1.50),
  (1008, 1012, 1.55),
  (1008, 1013, 1.38),
  (1008, 1014, 1.48),
  (1008, 1015, 1.22),
  (1008, 1016, 1.42),
  (1008, 1017, 1.28),
  (1008, 1018, 1.35),
  (1008, 1019, 1.52),
  (1008, 1020, 1.32),
  (1008, 1021, 1.25),
  (1008, 1022, 1.58),
  (1008, 1023, 1.45),
  (1008, 1024, 1.18),
  (1009, 1001, 1.45),
  (1009, 1002, 1.50),
  (1009, 1003, 1.30),
  (1009, 1004, 1.20),
  (1009, 1005, 1.15),
  (1009, 1006, 1.40),
  (1009, 1007, 1.45),
  (1009, 1008, 1.25),
  (1009, 1010, 1.35),
  (1009, 1011, 1.10),
  (1009, 1012, 1.55),
  (1009, 1013, 1.48),
  (1009, 1014, 1.35),
  (1009, 1015, 1.18),
  (1009, 1016, 1.52),
  (1009, 1017, 1.22),
  (1009, 1018, 1.12),
  (1009, 1019, 1.28),
  (1009, 1020, 1.38),
  (1009, 1021, 1.42),
  (1009, 1022, 1.32),
  (1009, 1023, 1.58),
  (1009, 1024, 1.25),
  (1010, 1001, 1.05),
  (1010, 1002, 1.55),
  (1010, 1003, 1.45),
  (1010, 1004, 1.50),
  (1010, 1005, 1.35),
  (1010, 1006, 1.55),
  (1010, 1007, 1.50),
  (1010, 1008, 1.15),
  (1010, 1009, 1.35),
  (1010, 1011, 1.40),
  (1010, 1012, 1.25),
  (1010, 1013, 1.52),
  (1010, 1014, 1.28),
  (1010, 1015, 1.42),
  (1010, 1016, 1.35),
  (1010, 1017, 1.38),
  (1010, 1018, 1.48),
  (1010, 1019, 1.58),
  (1010, 1020, 1.25),
  (1010, 1021, 1.32),
  (1010, 1022, 1.45),
  (1010, 1023, 1.18),
  (1010, 1024, 1.22),
  (1011, 1001, 1.30),
  (1011, 1002, 1.40),
  (1011, 1003, 1.25),
  (1011, 1004, 1.45),
  (1011, 1005, 1.05),
  (1011, 1006, 1.30),
  (1011, 1007, 1.35),
  (1011, 1008, 1.50),
  (1011, 1009, 1.10),
  (1011, 1010, 1.40),
  (1011, 1012, 1.45),
  (1011, 1013, 1.25),
  (1011, 1014, 1.52),
  (1011, 1015, 1.38),
  (1011, 1016, 1.48),
  (1011, 1017, 1.32),
  (1011, 1018, 1.42),
  (1011, 1019, 1.35),
  (1011, 1020, 1.58),
  (1011, 1021, 1.28),
  (1011, 1022, 1.15),
  (1011, 1023, 1.22),
  (1011, 1024, 1.55),
  (1012, 1001, 1.50),
  (1012, 1002, 1.10),
  (1012, 1003, 1.50),
  (1012, 1004, 1.55),
  (1012, 1005, 1.50),
  (1012, 1006, 1.25),
  (1012, 1007, 1.20),
  (1012, 1008, 1.55),
  (1012, 1009, 1.55),
  (1012, 1010, 1.25),
  (1012, 1011, 1.45),
  (1012, 1013, 1.35),
  (1012, 1014, 1.22),
  (1012, 1015, 1.48),
  (1012, 1016, 1.58),
  (1012, 1017, 1.42),
  (1012, 1018, 1.28),
  (1012, 1019, 1.45),
  (1012, 1020, 1.18),
  (1012, 1021, 1.38),
  (1012, 1022, 1.52),
  (1012, 1023, 1.32),
  (1012, 1024, 1.12),
  (1013, 1001, 1.18),
  (1013, 1002, 1.28),
  (1013, 1003, 1.22),
  (1013, 1004, 1.35),
  (1013, 1005, 1.42),
  (1013, 1006, 1.32),
  (1013, 1007, 1.18),
  (1013, 1008, 1.38),
  (1013, 1009, 1.48),
  (1013, 1010, 1.52),
  (1013, 1011, 1.25),
  (1013, 1012, 1.35),
  (1013, 1014, 1.15),
  (1013, 1015, 1.25),
  (1013, 1016, 1.12),
  (1013, 1017, 1.45),
  (1013, 1018, 1.38),
  (1013, 1019, 1.32),
  (1013, 1020, 1.48),
  (1013, 1021, 1.55),
  (1013, 1022, 1.28),
  (1013, 1023, 1.20),
  (1013, 1024, 1.42),
  (1014, 1001, 1.32),
  (1014, 1002, 1.38),
  (1014, 1003, 1.18),
  (1014, 1004, 1.25),
  (1014, 1005, 1.38),
  (1014, 1006, 1.42),
  (1014, 1007, 1.12),
  (1014, 1008, 1.48),
  (1014, 1009, 1.35),
  (1014, 1010, 1.28),
  (1014, 1011, 1.52),
  (1014, 1012, 1.22),
  (1014, 1013, 1.15),
  (1014, 1015, 1.35),
  (1014, 1016, 1.28),
  (1014, 1017, 1.42),
  (1014, 1018, 1.45),
  (1014, 1019, 1.38),
  (1014, 1020, 1.32),
  (1014, 1021, 1.48),
  (1014, 1022, 1.55),
  (1014, 1023, 1.25),
  (1014, 1024, 1.18),
  (1015, 1001, 1.42),
  (1015, 1002, 1.52),
  (1015, 1003, 1.45),
  (1015, 1004, 1.38),
  (1015, 1005, 1.28),
  (1015, 1006, 1.35),
  (1015, 1007, 1.32),
  (1015, 1008, 1.22),
  (1015, 1009, 1.18),
  (1015, 1010, 1.42),
  (1015, 1011, 1.38),
  (1015, 1012, 1.48),
  (1015, 1013, 1.25),
  (1015, 1014, 1.35),
  (1015, 1016, 1.45),
  (1015, 1017, 1.52),
  (1015, 1018, 1.15),
  (1015, 1019, 1.28),
  (1015, 1020, 1.55),
  (1015, 1021, 1.32),
  (1015, 1022, 1.42),
  (1015, 1023, 1.48),
  (1015, 1024, 1.12),
  (1016, 1001, 1.08),
  (1016, 1002, 1.18),
  (1016, 1003, 1.32),
  (1016, 1004, 1.22),
  (1016, 1005, 1.45),
  (1016, 1006, 1.28),
  (1016, 1007, 1.38),
  (1016, 1008, 1.42),
  (1016, 1009, 1.52),
  (1016, 1010, 1.35),
  (1016, 1011, 1.48),
  (1016, 1012, 1.58),
  (1016, 1013, 1.12),
  (1016, 1014, 1.28),
  (1016, 1015, 1.45),
  (1016, 1017, 1.25),
  (1016, 1018, 1.35),
  (1016, 1019, 1.15),
  (1016, 1020, 1.42),
  (1016, 1021, 1.48),
  (1016, 1022, 1.05),
  (1016, 1023, 1.38),
  (1016, 1024, 1.52),
  (1017, 1001, 1.38),
  (1017, 1002, 1.12),
  (1017, 1003, 1.42),
  (1017, 1004, 1.48),
  (1017, 1005, 1.35),
  (1017, 1006, 1.52),
  (1017, 1007, 1.55),
  (1017, 1008, 1.28),
  (1017, 1009, 1.22),
  (1017, 1010, 1.38),
  (1017, 1011, 1.32),
  (1017, 1012, 1.42),
  (1017, 1013, 1.45),
  (1017, 1014, 1.42),
  (1017, 1015, 1.52),
  (1017, 1016, 1.25),
  (1017, 1018, 1.48),
  (1017, 1019, 1.35),
  (1017, 1020, 1.18),
  (1017, 1021, 1.15),
  (1017, 1022, 1.58),
  (1017, 1023, 1.28),
  (1017, 1024, 1.32),
  (1018, 1001, 1.48),
  (1018, 1002, 1.58),
  (1018, 1003, 1.55),
  (1018, 1004, 1.42),
  (1018, 1005, 1.22),
  (1018, 1006, 1.38),
  (1018, 1007, 1.25),
  (1018, 1008, 1.35),
  (1018, 1009, 1.12),
  (1018, 1010, 1.48),
  (1018, 1011, 1.42),
  (1018, 1012, 1.28),
  (1018, 1013, 1.38),
  (1018, 1014, 1.45),
  (1018, 1015, 1.15),
  (1018, 1016, 1.35),
  (1018, 1017, 1.48),
  (1018, 1019, 1.52),
  (1018, 1020, 1.32),
  (1018, 1021, 1.58),
  (1018, 1022, 1.25),
  (1018, 1023, 1.42),
  (1018, 1024, 1.18),
  (1019, 1001, 1.22),
  (1019, 1002, 1.32),
  (1019, 1003, 1.38),
  (1019, 1004, 1.12),
  (1019, 1005, 1.18),
  (1019, 1006, 1.48),
  (1019, 1007, 1.42),
  (1019, 1008, 1.52),
  (1019, 1009, 1.28),
  (1019, 1010, 1.58),
  (1019, 1011, 1.35),
  (1019, 1012, 1.45),
  (1019, 1013, 1.32),
  (1019, 1014, 1.38),
  (1019, 1015, 1.28),
  (1019, 1016, 1.15),
  (1019, 1017, 1.35),
  (1019, 1018, 1.52),
  (1019, 1020, 1.25),
  (1019, 1021, 1.42),
  (1019, 1022, 1.48),
  (1019, 1023, 1.55),
  (1019, 1024, 1.08),
  (1020, 1001, 1.28),
  (1020, 1002, 1.22),
  (1020, 1003, 1.48),
  (1020, 1004, 1.58),
  (1020, 1005, 1.12),
  (1020, 1006, 1.45),
  (1020, 1007, 1.52),
  (1020, 1008, 1.32),
  (1020, 1009, 1.38),
  (1020, 1010, 1.25),
  (1020, 1011, 1.58),
  (1020, 1012, 1.18),
  (1020, 1013, 1.48),
  (1020, 1014, 1.32),
  (1020, 1015, 1.55),
  (1020, 1016, 1.42),
  (1020, 1017, 1.18),
  (1020, 1018, 1.32),
  (1020, 1019, 1.25),
  (1020, 1021, 1.35),
  (1020, 1022, 1.38),
  (1020, 1023, 1.45),
  (1020, 1024, 1.15),
  (1021, 1001, 1.35),
  (1021, 1002, 1.15),
  (1021, 1003, 1.35),
  (1021, 1004, 1.45),
  (1021, 1005, 1.52),
  (1021, 1006, 1.18),
  (1021, 1007, 1.48),
  (1021, 1008, 1.25),
  (1021, 1009, 1.42),
  (1021, 1010, 1.32),
  (1021, 1011, 1.28),
  (1021, 1012, 1.38),
  (1021, 1013, 1.55),
  (1021, 1014, 1.48),
  (1021, 1015, 1.32),
  (1021, 1016, 1.48),
  (1021, 1017, 1.15),
  (1021, 1018, 1.58),
  (1021, 1019, 1.42),
  (1021, 1020, 1.35),
  (1021, 1022, 1.22),
  (1021, 1023, 1.38),
  (1021, 1024, 1.28),
  (1022, 1001, 1.12),
  (1022, 1002, 1.35),
  (1022, 1003, 1.28),
  (1022, 1004, 1.18),
  (1022, 1005, 1.48),
  (1022, 1006, 1.22),
  (1022, 1007, 1.35),
  (1022, 1008, 1.58),
  (1022, 1009, 1.32),
  (1022, 1010, 1.45),
  (1022, 1011, 1.15),
  (1022, 1012, 1.52),
  (1022, 1013, 1.28),
  (1022, 1014, 1.55),
  (1022, 1015, 1.42),
  (1022, 1016, 1.05),
  (1022, 1017, 1.58),
  (1022, 1018, 1.25),
  (1022, 1019, 1.48),
  (1022, 1020, 1.38),
  (1022, 1021, 1.22),
  (1022, 1023, 1.32),
  (1022, 1024, 1.42),
  (1023, 1001, 1.25),
  (1023, 1002, 1.42),
  (1023, 1003, 1.15),
  (1023, 1004, 1.32),
  (1023, 1005, 1.55),
  (1023, 1006, 1.58),
  (1023, 1007, 1.28),
  (1023, 1008, 1.45),
  (1023, 1009, 1.58),
  (1023, 1010, 1.18),
  (1023, 1011, 1.22),
  (1023, 1012, 1.32),
  (1023, 1013, 1.20),
  (1023, 1014, 1.25),
  (1023, 1015, 1.48),
  (1023, 1016, 1.38),
  (1023, 1017, 1.28),
  (1023, 1018, 1.42),
  (1023, 1019, 1.55),
  (1023, 1020, 1.45),
  (1023, 1021, 1.38),
  (1023, 1022, 1.32),
  (1023, 1024, 1.35),
  (1024, 1001, 1.45),
  (1024, 1002, 1.48),
  (1024, 1003, 1.52),
  (1024, 1004, 1.28),
  (1024, 1005, 1.32),
  (1024, 1006, 1.15),
  (1024, 1007, 1.45),
  (1024, 1008, 1.18),
  (1024, 1009, 1.25),
  (1024, 1010, 1.22),
  (1024, 1011, 1.55),
  (1024, 1012, 1.12),
  (1024, 1013, 1.42),
  (1024, 1014, 1.18),
  (1024, 1015, 1.12),
  (1024, 1016, 1.52),
  (1024, 1017, 1.32),
  (1024, 1018, 1.18),
  (1024, 1019, 1.08),
  (1024, 1020, 1.15),
  (1024, 1021, 1.28),
  (1024, 1022, 1.42),
  (1024, 1023, 1.35);


/*************************************************************************************************/
-- SECTION 4: Normalize Dates to Current Period
/*************************************************************************************************/

UPDATE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.ORDERS
SET ORDER_DATE = DATEADD(
    DAY,
    (SELECT DATEDIFF(DAY, MAX(ORDER_DATE), CURRENT_DATE()) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.ORDERS),
    ORDER_DATE
);

UPDATE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SHIPMENT
SET
    SHIP_DATE = DATEADD(
        DAY,
        (SELECT DATEDIFF(DAY, MAX(SHIP_DATE), CURRENT_DATE()) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SHIPMENT),
        SHIP_DATE
    ),
    EXPECTED_DELIVERY_DATE = DATEADD(
        DAY,
        (SELECT DATEDIFF(DAY, MAX(EXPECTED_DELIVERY_DATE), CURRENT_DATE()) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SHIPMENT),
        EXPECTED_DELIVERY_DATE
    ),
    ACTUAL_DELIVERY_DATE = DATEADD(
        DAY,
        (SELECT DATEDIFF(DAY, MAX(ACTUAL_DELIVERY_DATE), CURRENT_DATE()) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SHIPMENT),
        ACTUAL_DELIVERY_DATE
    );

UPDATE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.MFG_INVENTORY
SET LAST_UPDATED_TIMESTAMP = DATEADD(
    DAY,
    (SELECT DATEDIFF(DAY, MAX(LAST_UPDATED_TIMESTAMP), CURRENT_TIMESTAMP()) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.MFG_INVENTORY),
    LAST_UPDATED_TIMESTAMP
);

UPDATE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.BILL_OF_MATERIALS
SET EFFECTIVE_DATE = DATEADD(
    DAY,
    (SELECT DATEDIFF(DAY, MAX(EFFECTIVE_DATE), CURRENT_DATE()) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.BILL_OF_MATERIALS),
    EFFECTIVE_DATE
);

/*************************************************************************************************/
-- SECTION 5: Semantic Model (YAML staged for Cortex Analyst)
/*************************************************************************************************/

COPY INTO @SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SEMANTIC_STAGE/supply_chain_network.yaml
FROM (SELECT 'name: supply_chain_network
tables:
  - name: SUPPLIERS
    base_table:
      database: SF_SOLUTIONS
      schema: SUPPLY_CHAIN_ENTITIES
      table: SUPPLIERS
    dimensions:
      - name: ADDRESS
        synonyms:
          - location
          - street_address
          - supplier_location
          - vendor_address
        description: Street address of the supplier
        expr: ADDRESS
        data_type: VARCHAR(255)
        sample_values:
          - 1200 Aviation Blvd
          - 4500 Industrial Way
          - 800 Composite Dr
      - name: BUSINESS_LINE
        synonyms:
          - business_unit
          - company_segment
          - department
          - division
          - industry_sector
          - organization_unit
          - product_line
        description: business line (AEROSPACE, INDUSTRIAL, BUILDINGS, ENERGY)
        expr: BUSINESS_LINE
        data_type: VARCHAR(15)
        sample_values:
          - AEROSPACE
          - INDUSTRIAL
          - BUILDINGS
          - ENERGY
      - name: CITY
        synonyms:
          - municipality
          - supplier_city
          - town
          - vendor_city
        description: City of the supplier
        expr: CITY
        data_type: VARCHAR(100)
        sample_values:
          - Seattle
          - Phoenix
          - Wichita
      - name: CONTACT_PERSON_NAME
        synonyms:
          - contact_name
          - supplier_contact
          - vendor_contact
        description: Primary contact person at the supplier
        expr: CONTACT_PERSON_NAME
        data_type: VARCHAR(255)
        sample_values:
          - Sarah Johnson
          - Michael Chen
          - Jennifer Davis
      - name: COUNTRY
        synonyms:
          - nation
          - supplier_country
          - vendor_country
        description: Country of the supplier
        expr: COUNTRY
        data_type: VARCHAR(50)
        sample_values:
          - USA
      - name: IS_PREFERRED
        synonyms:
          - is_preferred_vendor
          - preferred_status
          - preferred_vendor
        description: Indicates if this is a preferred supplier
        expr: IS_PREFERRED
        data_type: BOOLEAN
        sample_values:
          - ''TRUE''
          - ''FALSE''
      - name: STATE
        synonyms:
          - province
          - supplier_state
          - vendor_state
        description: State/Province of the supplier
        expr: STATE
        data_type: VARCHAR(50)
        sample_values:
          - WA
          - AZ
          - KS
      - name: SUPPLIER_ID
        synonyms:
          - supplier_key
          - supplier_number
          - vendor_id
          - vendor_number
        description: Unique identifier for the supplier
        expr: SUPPLIER_ID
        data_type: INTEGER
        sample_values:
          - ''9001''
          - ''9002''
          - ''9003''
      - name: SUPPLIER_NAME
        synonyms:
          - supplier_business_name
          - supplier_company
          - vendor_company
          - vendor_name
        description: Name of the supplier company
        expr: SUPPLIER_NAME
        data_type: VARCHAR(255)
        sample_values:
          - Aerospace Materials Corp
          - Titanium Alloys International
          - Carbon Fiber Solutions
      - name: SUPPLIER_TYPE
        synonyms:
          - supplier_category
          - vendor_category
          - vendor_type
        description: Type of supplier (Raw Materials, Components, Services, etc.)
        expr: SUPPLIER_TYPE
        data_type: VARCHAR(100)
        sample_values:
          - Raw Materials
          - Components
          - Services
    primary_key:
      columns:
        - SUPPLIER_ID
  - name: BILL_OF_MATERIALS
    base_table:
      database: SF_SOLUTIONS
      schema: SUPPLY_CHAIN_ENTITIES
      table: BILL_OF_MATERIALS
    dimensions:
      - name: BOM_ID
        synonyms:
          - bill_of_materials_id
          - bom_key
          - bom_number
        description: Unique identifier for the bill of materials entry
        expr: BOM_ID
        data_type: INTEGER
        sample_values:
          - ''10001''
          - ''10002''
          - ''10003''
      - name: CHILD_COMPONENT_ID
        synonyms:
          - child_part_id
          - component_id
          - required_component_id
        description: Component used in this BOM
        expr: CHILD_COMPONENT_ID
        data_type: INTEGER
        sample_values:
          - ''1001''
          - ''1002''
          - ''1003''
      - name: CHILD_MATERIAL_ID
        synonyms:
          - material_id
          - raw_material_id
          - required_material_id
        description: Raw material used in this BOM
        expr: CHILD_MATERIAL_ID
        data_type: INTEGER
        sample_values:
          - ''101''
          - ''102''
          - ''103''
      - name: PARENT_COMPONENT_ID
        synonyms:
          - component_id
          - parent_assembly_id
          - sub_assembly_id
        description: Component that uses these materials (for sub-assemblies)
        expr: PARENT_COMPONENT_ID
        data_type: INTEGER
        sample_values:
          - ''1001''
          - ''1002''
          - ''1003''
      - name: PARENT_PRODUCT_ID
        synonyms:
          - finished_product_id
          - parent_item_id
          - product_id
        description: Product that uses these materials/components
        expr: PARENT_PRODUCT_ID
        data_type: INTEGER
        sample_values:
          - ''5001''
          - ''5002''
          - ''5003''
      - name: UNIT_OF_MEASURE
        synonyms:
          - measurement_unit
          - unit
          - uom
        description: Unit of measure (pieces, kg, meters, etc.)
        expr: UNIT_OF_MEASURE
        data_type: VARCHAR(50)
        sample_values:
          - pieces
          - kg
          - m2
          - m
    time_dimensions:
      - name: EFFECTIVE_DATE
        synonyms:
          - activation_date
          - start_date
          - valid_from_date
        description: Date when this BOM version becomes effective
        expr: EFFECTIVE_DATE
        data_type: DATE
        sample_values:
          - ''2024-01-01''
    facts:
      - name: QUANTITY_REQUIRED
        synonyms:
          - quantity_per_unit
          - required_quantity
          - usage_quantity
        description: Quantity of the child item required per parent item
        expr: QUANTITY_REQUIRED
        data_type: NUMBER(10,4)
        sample_values:
          - ''2.5000''
          - ''1.2000''
          - ''3.8000''
      - name: SCRAP_FACTOR
        synonyms:
          - loss_factor
          - scrap_percentage
          - waste_factor
        description: Expected scrap/waste factor (0.05 = 5% scrap)
        expr: SCRAP_FACTOR
        data_type: NUMBER(5,4)
        sample_values:
          - ''0.0500''
          - ''0.0300''
          - ''0.0200''
    primary_key:
      columns:
        - BOM_ID
  - name: MFG_PLANT
    base_table:
      database: SF_SOLUTIONS
      schema: SUPPLY_CHAIN_ENTITIES
      table: MFG_PLANT
    dimensions:
      - name: ADDRESS
        synonyms:
          - facility_location
          - location
          - mailing_address
          - physical_address
          - site_address
          - street_address
        description: Street address of the facility
        expr: ADDRESS
        data_type: VARCHAR(255)
        sample_values:
          - 1 Skyview Dr
          - 1050 Delta Blvd
          - 100 N Riverside Plaza
      - name: BUSINESS_LINE
        synonyms:
          - business_unit
          - company_segment
          - department
          - division
          - industry_sector
          - organization_unit
          - product_line
        description: business line (AEROSPACE, INDUSTRIAL, BUILDINGS, ENERGY)
        expr: BUSINESS_LINE
        data_type: VARCHAR(15)
        sample_values:
          - AEROSPACE
          - INDUSTRIAL
          - BUILDINGS
          - ENERGY
      - name: CITY
        synonyms:
          - city_name
          - metropolis
          - metropolitan_area
          - municipality
          - town
          - urban_area
          - urban_center
        description: City of the facility
        expr: CITY
        data_type: VARCHAR(100)
        sample_values:
          - Fort Worth
          - Atlanta
          - Seattle
      - name: COUNTRY
        synonyms:
          - geographical_area
          - homeland
          - land
          - nation
          - nationality
          - region
          - state
          - territory
        description: Country of the facility
        expr: COUNTRY
        data_type: VARCHAR(50)
        sample_values:
          - USA
      - name: IS_ACTIVE
        synonyms:
          - active_status
          - current_status
          - is_current
          - is_enabled
          - is_open
          - is_operational
          - is_running
          - is_valid
          - status
        description: Indicates if the facility is currently active
        expr: IS_ACTIVE
        data_type: BOOLEAN
        sample_values:
          - ''TRUE''
      - name: MFG_PLANT_ID
        synonyms:
          - manufacturing_plant
          - mfg_plant
          - plant_id
          - plant_number
        description: Unique identifier for the Manufacturing Plant
        expr: MFG_PLANT_ID
        data_type: INTEGER
        sample_values:
          - ''1001''
          - ''1002''
          - ''1003''
      - name: MFG_PLANT_NAME
        synonyms:
          - facility_name
          - plant_name
        description: Name of the Manufacturing Plant
        expr: MFG_PLANT_NAME
        data_type: VARCHAR(255)
        sample_values:
          - Phoenix Aerospace Manufacturing
          - Seattle Aircraft Components
          - Wichita Aviation Systems
      - name: STATE
        synonyms:
          - administrative_area
          - county
          - geographic_area
          - locality
          - prefecture
          - province
        description: State/Province of the facility
        expr: STATE
        data_type: VARCHAR(50)
        sample_values:
          - TX
          - GA
          - WA
      - name: ZIP_CODE
        synonyms:
          - geographic_code
          - mailing_code
          - postal
          - postal_code
          - postcode
          - zip
        description: Postal code of the facility
        expr: ZIP_CODE
        data_type: VARCHAR(20)
        sample_values:
          - ''76155''
          - ''30354''
          - ''98101''
    facts:
      - name: LATITUDE
        synonyms:
          - geographic_latitude
          - lat
          - latitude_coordinate
          - latitude_position
          - latitude_value
        description: Latitude coordinate of the facility
        expr: LATITUDE
        data_type: NUMBER(10,6)
        sample_values:
          - ''33.4484''
          - ''47.6062''
          - ''37.6922''
      - name: LONGITUDE
        synonyms:
          - east_west_coordinate
          - easting
          - geographic_longitude
          - longitudinal_coordinate
          - meridian_coordinate
        description: Longitude coordinate of the facility
        expr: LONGITUDE
        data_type: NUMBER(11,6)
        sample_values:
          - ''-112.0740''
          - ''-122.3321''
          - ''-97.3375''
      - name: NUMBER_OF_EMPLOYEES
        synonyms:
          - employee_count
          - headcount
          - staff_size
          - workforce
        description: Number of employees at the manufacturing plant
        expr: NUMBER_OF_EMPLOYEES
        data_type: NUMBER(38,0)
        sample_values:
          - ''850''
          - ''625''
          - ''945''
      - name: SQUARE_FOOTAGE
        synonyms:
          - building_area
          - facility_size
          - floor_space
          - plant_area
        description: Total square footage of the manufacturing plant
        expr: SQUARE_FOOTAGE
        data_type: NUMBER(10,2)
        sample_values:
          - ''450000.00''
          - ''380000.00''
          - ''520000.00''
    primary_key:
      columns:
        - MFG_PLANT_ID
  - name: COMPONENT
    base_table:
      database: SF_SOLUTIONS
      schema: SUPPLY_CHAIN_ENTITIES
      table: COMPONENT
    dimensions:
      - name: BILL_OF_MATERIALS_ID
        synonyms:
          - assembly_id
          - bill_of_materials_reference
          - bom_id
          - bom_reference_id
          - component_material_reference
          - material_id
        description: Foreign key referencing a bill_of_materials table (if applicable)
        expr: BILL_OF_MATERIALS_ID
        data_type: INTEGER
        sample_values:
          - ''5001''
          - ''5002''
          - ''5003''
      - name: BUSINESS_LINE
        synonyms:
          - business_unit
          - company_segment
          - department
          - division
          - market_segment
          - organization_unit
          - product_line
        description: business line (AEROSPACE, INDUSTRIAL, BUILDINGS, ENERGY)
        expr: BUSINESS_LINE
        data_type: VARCHAR(15)
        sample_values:
          - AEROSPACE
          - INDUSTRIAL
          - BUILDINGS
          - ENERGY
      - name: COMPONENT_DESCRIPTION
        synonyms:
          - component_commentary
          - component_details
          - component_info
          - component_notes
          - component_summary
          - part_description
        description: Description of the component
        expr: COMPONENT_DESCRIPTION
        data_type: VARCHAR(1024)
        sample_values:
          - Primary flight control printed circuit board with redundant processing units for commercial aircraft
          - High-temperature resistant turbine blade assembly for jet engines with ceramic coating
          - Integrated GPS/INS navigation sensor module for aircraft positioning and guidance
      - name: COMPONENT_ID
        synonyms:
          - component_key
          - component_number
          - component_reference
          - part_id
          - part_number
        description: Unique identifier for the component
        expr: COMPONENT_ID
        data_type: INTEGER
        sample_values:
          - ''1001''
          - ''1002''
          - ''1003''
      - name: COMPONENT_NAME
        synonyms:
          - assembly_name
          - component_title
          - element_name
          - item_name
          - module_name
          - part_name
          - unit_name
        description: Name of the component
        expr: COMPONENT_NAME
        data_type: VARCHAR(255)
        sample_values:
          - Flight Control PCB
          - Turbine Blade Assembly
          - Navigation Sensor Module
    primary_key:
      columns:
        - COMPONENT_ID
  - name: PRODUCT
    base_table:
      database: SF_SOLUTIONS
      schema: SUPPLY_CHAIN_ENTITIES
      table: PRODUCT
    dimensions:
      - name: BUSINESS_LINE
        synonyms:
          - business_unit
          - company_segment
          - department
          - division
          - organization_unit
          - product_line
        description: business line (AEROSPACE, INDUSTRIAL, BUILDINGS, ENERGY)
        expr: BUSINESS_LINE
        data_type: VARCHAR(15)
        sample_values:
          - AEROSPACE
          - INDUSTRIAL
          - BUILDINGS
          - ENERGY
      - name: PRODUCT_CATEGORY
        synonyms:
          - category_name
          - product_classification
          - product_family
          - product_group
          - product_segment
          - product_type
        description: Category of the product
        expr: PRODUCT_CATEGORY
        data_type: VARCHAR(100)
        sample_values:
          - Avionics
          - Engine Systems
          - Safety Systems
      - name: PRODUCT_DESCRIPTION
        synonyms:
          - item_description
          - item_info
          - product_details
          - product_info
          - product_overview
          - product_summary
        description: Description of the product
        expr: PRODUCT_DESCRIPTION
        data_type: VARCHAR(1024)
        sample_values:
          - Complete flight management system for commercial aircraft with navigation and autopilot capabilities
          - Real-time engine health monitoring system with predictive maintenance capabilities
          - Advanced weather detection radar system for aircraft with turbulence prediction
      - name: PRODUCT_ID
        synonyms:
          - item_id
          - product_code
          - product_key
          - product_number
          - sku
        description: Unique identifier for the product
        expr: PRODUCT_ID
        data_type: INTEGER
        sample_values:
          - ''5001''
          - ''5002''
          - ''5003''
      - name: PRODUCT_NAME
        synonyms:
          - item_name
          - product_heading
          - product_label
          - product_title
          - system_name
        description: Name of the product
        expr: PRODUCT_NAME
        data_type: VARCHAR(255)
        sample_values:
          - Flight Management System
          - Engine Monitoring System
          - Weather Radar System
    facts:
      - name: UNIT_PRICE
        synonyms:
          - cost_per_item
          - cost_per_unit
          - item_price
          - price_per_item
          - price_per_unit
          - product_price
          - unit_cost
        description: Price per unit of the product
        expr: UNIT_PRICE
        data_type: NUMBER(10,2)
        sample_values:
          - ''125000.00''
          - ''85000.00''
          - ''95000.00''
    primary_key:
      columns:
        - PRODUCT_ID
  - name: CUSTOMER
    base_table:
      database: SF_SOLUTIONS
      schema: SUPPLY_CHAIN_ENTITIES
      table: CUSTOMER
    dimensions:
      - name: ADDRESS
        synonyms:
          - customer_location
          - geographical_address
          - location
          - mailing_address
          - physical_address
          - residence
          - street_address
        description: Street address of the customer
        expr: ADDRESS
        data_type: VARCHAR(255)
        sample_values:
          - 1 Skyview Dr
          - 1050 Delta Blvd
          - 100 N Riverside Plaza
      - name: BUSINESS_LINE
        synonyms:
          - business_unit
          - category
          - classification
          - department
          - division
          - product_line
          - segment
        description: business line (AEROSPACE, INDUSTRIAL, BUILDINGS, ENERGY)
        expr: BUSINESS_LINE
        data_type: VARCHAR(15)
        sample_values:
          - AEROSPACE
          - INDUSTRIAL
          - BUILDINGS
          - ENERGY
      - name: CITY
        synonyms:
          - city_name
          - metropolis
          - metropolitan_area
          - municipality
          - town
          - urban_area
          - urban_center
        description: City of the customer
        expr: CITY
        data_type: VARCHAR(100)
        sample_values:
          - Fort Worth
          - Atlanta
          - Seattle
      - name: CONTACT_PERSON_ID
        synonyms:
          - account_manager_id
          - contact_person_reference
          - contact_reference_id
          - key_contact_id
          - person_of_contact_id
          - point_of_contact_id
        description: Foreign key referencing a contacts table (if applicable)
        expr: CONTACT_PERSON_ID
        data_type: INTEGER
        sample_values:
          - ''30001''
          - ''30002''
          - ''30003''
      - name: COUNTRY
        synonyms:
          - homeland
          - land
          - nation
          - nationality
          - region
          - state
          - territory
          - territory_name
        description: Country of the customer
        expr: COUNTRY
        data_type: VARCHAR(50)
        sample_values:
          - USA
      - name: CUSTOMER_ID
        synonyms:
          - account_id
          - account_number
          - client_id
          - customer_key
          - customer_number
        description: Unique identifier for the customer
        expr: CUSTOMER_ID
        data_type: INTEGER
        sample_values:
          - ''3001''
          - ''3002''
          - ''3003''
      - name: CUSTOMER_NAME
        synonyms:
          - account_name
          - business_name
          - client_name
          - client_title
          - company_name
          - customer_title
          - entity_name
          - organization_name
        description: Name of the customer
        expr: CUSTOMER_NAME
        data_type: VARCHAR(255)
        sample_values:
          - American Airlines
          - Delta Air Lines
          - Boeing Commercial Airplanes
      - name: INDUSTRY
        synonyms:
          - business_category
          - business_sector
          - economic_sector
          - field
          - industry_type
          - market
          - market_segment
          - sector
        description: Industry of the customer
        expr: INDUSTRY
        data_type: VARCHAR(100)
        sample_values:
          - Commercial Aviation
          - Aircraft Manufacturing
          - Defense Aerospace
      - name: STATE
        synonyms:
          - administrative_area
          - county
          - geographic_area
          - prefecture
          - province
        description: State/Province of the customer
        expr: STATE
        data_type: VARCHAR(50)
        sample_values:
          - TX
          - GA
          - WA
      - name: ZIP_CODE
        synonyms:
          - post_code
          - postal
          - postal_code
          - postcode
          - zip
          - zip_postal_code
        description: Postal code of the customer
        expr: ZIP_CODE
        data_type: VARCHAR(20)
        sample_values:
          - ''76155''
          - ''30354''
          - ''98101''
    primary_key:
      columns:
        - CUSTOMER_ID
  - name: ORDERS
    base_table:
      database: SF_SOLUTIONS
      schema: SUPPLY_CHAIN_ENTITIES
      table: ORDERS
    dimensions:
      - name: CUSTOMER_ID
        synonyms:
          - account_id
          - buyer_id
          - client_id
          - customer_number
          - purchaser_id
        description: Foreign key referencing the customer
        expr: CUSTOMER_ID
        data_type: INTEGER
        sample_values:
          - ''3001''
          - ''3002''
          - ''3003''
      - name: MFG_PLANT_ID
        synonyms:
          - fulfillment_plant
          - manufacturing_plant_id
          - plant_id
          - production_facility_id
        description: Foreign key referencing the manufacturing plant fulfilling the order
        expr: MFG_PLANT_ID
        data_type: INTEGER
        sample_values:
          - ''1001''
          - ''1002''
          - ''1003''
      - name: ORDER_ID
        synonyms:
          - order_key
          - order_number
          - order_reference
          - purchase_id
          - transaction_id
        description: Unique identifier for the order
        expr: ORDER_ID
        data_type: INTEGER
        sample_values:
          - ''1''
          - ''2''
          - ''3''
      - name: ORDER_STATUS
        synonyms:
          - delivery_status
          - fulfillment_status
          - order_condition
          - order_progress
          - order_state
          - shipment_status
          - status
        description: Status of the order (e.g., Placed, In Production, Shipped, Delivered, Cancelled)
        expr: ORDER_STATUS
        data_type: VARCHAR(50)
        sample_values:
          - Delivered
          - Shipped
          - In Production
      - name: PRODUCT_ID
        synonyms:
          - item_id
          - item_reference
          - product_code
          - product_key
          - product_reference
          - sku
        description: Foreign key referencing the product
        expr: PRODUCT_ID
        data_type: INTEGER
        sample_values:
          - ''5001''
          - ''5002''
          - ''5003''
    time_dimensions:
      - name: ORDER_DATE
        synonyms:
          - order_creation_date
          - order_initiation_date
          - order_placement_date
          - order_submission_date
          - order_timestamp
        description: Date and time the order was placed
        expr: ORDER_DATE
        data_type: TIMESTAMP_NTZ(9)
        sample_values:
          - ''2024-11-15T08:30:00.000Z''
          - ''2024-12-02T14:15:00.000Z''
          - ''2024-12-10T09:45:00.000Z''
    facts:
      - name: QUANTITY
        synonyms:
          - amount
          - count
          - item_quantity
          - number_ordered
          - ordered_amount
          - product_count
        description: Quantity of the product ordered
        expr: QUANTITY
        data_type: NUMBER(38,0)
        sample_values:
          - ''2''
          - ''1''
          - ''3''
      - name: TOTAL_PRICE
        synonyms:
          - grand_total
          - order_total
          - total_amount
          - total_charge
          - total_cost
          - total_order_value
          - total_value
        description: Total price of the order line
        expr: TOTAL_PRICE
        data_type: NUMBER(10,2)
        sample_values:
          - ''250000.00''
          - ''85000.00''
          - ''285000.00''
      - name: UNIT_PRICE
        synonyms:
          - cost_per_item
          - item_price
          - price_per_item
          - price_per_unit
          - unit_cost
          - unit_rate
        description: Price per unit at the time of order
        expr: UNIT_PRICE
        data_type: NUMBER(10,2)
        sample_values:
          - ''125000.00''
          - ''85000.00''
          - ''95000.00''
    primary_key:
      columns:
        - ORDER_ID
  - name: SHIPMENT
    base_table:
      database: SF_SOLUTIONS
      schema: SUPPLY_CHAIN_ENTITIES
      table: SHIPMENT
    dimensions:
      - name: DESTINATION_CUSTOMER_ID
        synonyms:
          - customer_id
          - delivery_customer_id
          - destination_customer
          - receiving_customer_id
          - recipient_customer_id
          - target_customer_id
        description: Foreign key referencing the destination customer
        expr: DESTINATION_CUSTOMER_ID
        data_type: INTEGER
        sample_values:
          - ''3001''
          - ''3002''
          - ''4003''
      - name: ORIGIN_MFG_PLANT_ID
        synonyms:
          - origin_plant_id
          - originating_facility_id
          - shipping_facility_id
          - source_facility_id
          - source_plant_id
          - starting_facility_id
        description: Foreign key referencing the originating manufacturing plant
        expr: ORIGIN_MFG_PLANT_ID
        data_type: INTEGER
        sample_values:
          - ''1001''
          - ''1002''
          - ''1006''
      - name: SHIPMENT_ID
        synonyms:
          - delivery_id
          - shipment_code
          - shipment_key
          - shipment_number
          - shipment_reference
        description: Unique identifier for the shipment
        expr: SHIPMENT_ID
        data_type: INTEGER
        sample_values:
          - ''1001''
          - ''1002''
          - ''1003''
      - name: TRACKING_NUMBER
        synonyms:
          - consignment_number
          - package_number
          - shipping_id
          - tracking_code
          - tracking_id
          - waybill_number
        description: Tracking number for the shipment
        expr: TRACKING_NUMBER
        data_type: VARCHAR(50)
        sample_values:
          - TRK001001AA
          - TRK002001BB
          - TRK003001CC
    time_dimensions:
      - name: ACTUAL_DELIVERY_DATE
        synonyms:
          - actual_arrival_date
          - actual_completion_date
          - actual_shipment_delivery_date
          - date_delivered
          - delivery_date_actual
          - shipment_arrival_date
        description: Actual delivery date of the shipment
        expr: ACTUAL_DELIVERY_DATE
        data_type: DATE
        sample_values:
          - ''2024-11-19''
          - ''2024-12-07''
          - ''2024-12-11''
      - name: EXPECTED_DELIVERY_DATE
        synonyms:
          - anticipated_delivery_date
          - estimated_delivery_date
          - expected_arrival_date
          - planned_delivery_date
          - projected_delivery_date
          - scheduled_arrival_date
        description: Expected delivery date of the shipment
        expr: EXPECTED_DELIVERY_DATE
        data_type: DATE
        sample_values:
          - ''2024-11-20''
          - ''2024-12-08''
          - ''2024-12-12''
      - name: SHIP_DATE
        synonyms:
          - date_shipped
          - departure_date
          - dispatch_date
          - send_date
          - shipment_date
          - shipping_date
        description: Date the shipment was shipped
        expr: SHIP_DATE
        data_type: DATE
        sample_values:
          - ''2024-11-16''
          - ''2024-12-03''
          - ''2024-12-06''
    facts:
      - name: SHIPPING_COST
        synonyms:
          - delivery_fee
          - freight_cost
          - logistics_expense
          - shipment_fee
          - shipping_expense
          - transportation_cost
        description: Cost of shipping
        expr: SHIPPING_COST
        data_type: NUMBER(10,2)
        sample_values:
          - ''2850.75''
          - ''1950.25''
          - ''3450.60''
    primary_key:
      columns:
        - SHIPMENT_ID
  - name: MFG_INVENTORY
    base_table:
      database: SF_SOLUTIONS
      schema: SUPPLY_CHAIN_ENTITIES
      table: MFG_INVENTORY
    dimensions:
      - name: COMPONENT_ID
        synonyms:
          - assembly_id
          - component_key
          - component_number
          - component_reference
          - part_id
          - subassembly_id
        description: Foreign key referencing component table (if applicable)
        expr: COMPONENT_ID
        data_type: INTEGER
        sample_values:
          - ''1001''
          - ''1002''
          - ''1003''
      - name: MATERIAL_ID
        synonyms:
          - inventory_material_id
          - material_code
          - material_identifier
          - material_number
          - raw_material_id
        description: Foreign key referencing raw_material table (if applicable)
        expr: MATERIAL_ID
        data_type: INTEGER
        sample_values:
          - ''101''
          - ''102''
          - ''103''
      - name: MFG_PLANT_ID
        synonyms:
          - facility_id
          - manufacturing_plant_id
          - plant_code
          - plant_id
        description: Foreign key referencing mfg_plant
        expr: MFG_PLANT_ID
        data_type: INTEGER
        sample_values:
          - ''1001''
          - ''1002''
          - ''1003''
      - name: PRODUCT_ID
        synonyms:
          - finished_goods_id
          - item_id
          - product_key
          - product_number
          - sku
        description: Foreign key referencing product table (if applicable)
        expr: PRODUCT_ID
        data_type: INTEGER
        sample_values:
          - ''5001''
          - ''5002''
          - ''5003''
    time_dimensions:
      - name: LAST_UPDATED_TIMESTAMP
        synonyms:
          - inventory_last_updated
          - last_inventory_sync
          - last_inventory_update
          - last_refresh_date
          - last_sync_timestamp
          - last_update
          - timestamp_last_updated
        description: Timestamp of the last inventory update
        expr: LAST_UPDATED_TIMESTAMP
        data_type: TIMESTAMP_NTZ(9)
        sample_values:
          - ''2024-12-20T09:27:34.709Z''
    facts:
      - name: DAYS_FORWARD_COVERAGE
        synonyms:
          - days_of_inventory_on_hand
          - days_supply
          - forward_inventory_coverage
          - inventory_coverage
          - inventory_runway
          - inventory_sustainability
          - production_sustainability_days
        description: Number of days current inventory can sustain demand
        expr: DAYS_FORWARD_COVERAGE
        data_type: NUMBER(38,0)
        sample_values:
          - ''45''
          - ''38''
          - ''30''
      - name: LEAD_TIME_VARIABILITY
        synonyms:
          - lead_time_uncertainty
          - lead_variability
          - lead_variance
        description: Variability in lead time, measured in days
        expr: LEAD_TIME_VARIABILITY
        data_type: NUMBER(38,0)
        sample_values:
          - ''3''
          - ''4''
          - ''2''
      - name: MATERIAL_LEAD_TIME
        synonyms:
          - days_to_acquire_material
          - lead_time_for_material
          - material_acquisition_time
          - material_procurement_time
          - material_replenishment_time
          - procurement_lead_time
        description: Lead time in days to acquire/produce this item
        expr: MATERIAL_LEAD_TIME
        data_type: NUMBER(38,0)
        sample_values:
          - ''14''
          - ''21''
          - ''7''
      - name: QUANTITY_ON_HAND
        synonyms:
          - available_quantity
          - current_inventory
          - current_stock
          - inventory_level
          - on_hand_quantity
          - quantity_in_stock
          - stock_level
          - stock_on_hand
        description: Current quantity on hand
        expr: QUANTITY_ON_HAND
        data_type: NUMBER(38,0)
        sample_values:
          - ''2500''
          - ''1800''
          - ''150''
      - name: QUANTITY_ON_ORDER
        synonyms:
          - items_on_order
          - ordered_quantity
          - pending_arrivals
          - quantity_ordered
          - quantity_pending_delivery
          - stock_ordered
        description: Quantity currently on order
        expr: QUANTITY_ON_ORDER
        data_type: NUMBER(38,0)
        sample_values:
          - ''500''
          - ''300''
          - ''25''
      - name: REPLENISHMENT_POINT
        synonyms:
          - inventory_target
          - replenishment_level
          - replenishment_threshold
          - target_inventory_level
          - target_stock_level
        description: Target inventory level for replenishment calculations
        expr: REPLENISHMENT_POINT
        data_type: NUMBER(38,0)
        sample_values:
          - ''1800''
          - ''1400''
          - ''90''
      - name: SAFETY_STOCK_LEVEL
        synonyms:
          - inventory_buffer
          - min_stock_level
          - minimum_inventory_level
          - minimum_inventory_threshold
          - minimum_stock_requirement
          - safety_stock_quantity
        description: Minimum inventory level to maintain
        expr: SAFETY_STOCK_LEVEL
        data_type: NUMBER(38,0)
        sample_values:
          - ''1000''
          - ''800''
          - ''50''
    filters:
      - name: excess_inventory
        synonyms:
          - excess inventory
          - overstock
          - surplus inventory
          - surplus stock
        description: Identifies items with more than 3 times safety stock level and coverage greater than twice the lead time
        expr: quantity_on_hand > 3 * safety_stock_level AND days_forward_coverage > 2 * material_lead_time
      - name: low_inventory
        synonyms:
          - below safety stock
          - insufficient inventory
          - inventory shortage
          - low stock
          - replenishment needed
          - stockout risk
        description: Identifies inventory items where the current quantity on hand is below the established safety stock level and coverage is insufficient
        expr: quantity_on_hand < safety_stock_level AND DAYS_FORWARD_COVERAGE <= MATERIAL_LEAD_TIME + LEAD_TIME_VARIABILITY
    primary_key:
      columns:
        - MATERIAL_ID
        - COMPONENT_ID
        - PRODUCT_ID
  - name: RAW_MATERIAL
    base_table:
      database: SF_SOLUTIONS
      schema: SUPPLY_CHAIN_ENTITIES
      table: RAW_MATERIAL
    dimensions:
      - name: BUSINESS_LINE
        synonyms:
          - business_unit
          - company_segment
          - department
          - division
          - industry_sector
          - organization_unit
          - product_line
        description: business line (AEROSPACE, INDUSTRIAL, BUILDINGS, ENERGY)
        expr: BUSINESS_LINE
        data_type: VARCHAR(15)
        sample_values:
          - AEROSPACE
          - INDUSTRIAL
          - BUILDINGS
          - ENERGY
      - name: MATERIAL_DESCRIPTION
        synonyms:
          - item_description
          - material_characteristics
          - material_info
          - material_specifications
          - product_description
          - raw_material_details
        description: Detailed descriptions of raw materials
        expr: MATERIAL_DESCRIPTION
        data_type: VARCHAR(16777216)
        sample_values:
          - High-strength aluminum alloy suitable for aerospace and automotive applications
          - Lightweight high-strength carbon fiber reinforced polymer sheets
          - Aerospace-grade titanium alloy with excellent strength-to-weight ratio
      - name: MATERIAL_ID
        synonyms:
          - material_id
          - material_key
          - material_number
          - raw_material_code
          - raw_material_identifier
        description: Unique identifier for each raw material
        expr: MATERIAL_ID
        data_type: INTEGER
        sample_values:
          - ''101''
          - ''102''
          - ''103''
      - name: MATERIAL_NAME
        synonyms:
          - item_name
          - item_title
          - material_label
          - material_title
          - product_name
          - raw_material_name
          - raw_material_title
        description: Names of raw materials used in the supply chain network
        expr: MATERIAL_NAME
        data_type: VARCHAR(16777216)
        sample_values:
          - Aluminum Alloy 6061-T6
          - Carbon Fiber Composite
          - Titanium Grade 5 Alloy
      - name: SUPPLIER_ID
        synonyms:
          - material_supplier_id
          - primary_supplier_id
          - vendor_id
        description: Foreign key referencing the primary supplier for this material
        expr: SUPPLIER_ID
        data_type: INTEGER
        sample_values:
          - ''9001''
          - ''9002''
          - ''9003''
    facts:
      - name: MATERIAL_COST
        synonyms:
          - material_expense
          - material_price
          - procurement_cost
          - purchase_price
          - raw_material_expense
          - supplier_cost
          - unit_cost
        description: The cost of the raw material from the supplier
        expr: MATERIAL_COST
        data_type: NUMBER(10,2)
        sample_values:
          - ''8.50''
          - ''45.75''
          - ''125.00''
      - name: PLANT_TRANSPORT_COST
        synonyms:
          - inter_plant_transport_cost
          - logistics_base_cost
          - material_transfer_cost
          - plant_to_plant_cost
          - transfer_base_rate
          - transport_base_cost
        description: Base cost for transporting this material between plants (before surcharge multiplier)
        expr: PLANT_TRANSPORT_COST
        data_type: NUMBER(10,2)
        sample_values:
          - ''2.15''
          - ''8.25''
          - ''18.50''
    primary_key:
      columns:
        - MATERIAL_ID
  - name: TRANSPORT_COST_SURCHARGE
    base_table:
      database: SF_SOLUTIONS
      schema: SUPPLY_CHAIN_ENTITIES
      table: TRANSPORT_COST_SURCHARGE
    dimensions:
      - name: DESTINATION_FACILITY_ID
        synonyms:
          - delivery_plant_id
          - destination_plant_id
          - receiving_plant_id
          - recipient_plant_id
          - target_facility_id
        description: Unique identifier for the destination facility that will receive materials
        expr: DESTINATION_FACILITY_ID
        data_type: INTEGER
        sample_values:
          - ''1001''
          - ''1002''
          - ''1003''
      - name: SOURCE_FACILITY_ID
        synonyms:
          - initial_plant_id
          - origin_facility_id
          - origin_plant_id
          - sending_plant_id
          - starting_plant_id
        description: Unique identifier for the source facility with excess inventory
        expr: SOURCE_FACILITY_ID
        data_type: INTEGER
        sample_values:
          - ''1001''
          - ''1002''
          - ''1003''
    facts:
      - name: TRANSPORT_COST_SURCHARGE
        synonyms:
          - delivery_cost_factor
          - freight_charge
          - logistics_surcharge
          - shipping_cost_multiplier
          - transfer_cost_rate
          - transportation_fee
        description: Transport costs multiplier between facilities depending on distance and transport difficulty
        expr: TRANSPORT_COST_SURCHARGE
        data_type: NUMBER(3,2)
        sample_values:
          - ''1.25''
          - ''1.40''
          - ''1.15''
    primary_key:
      columns:
        - SOURCE_FACILITY_ID
        - DESTINATION_FACILITY_ID
relationships:
  - name: MFG_PLANT_to_MFG_inventory
    join_type: inner
    relationship_type: many_to_one
    left_table: MFG_INVENTORY
    relationship_columns:
      - left_column: MFG_PLANT_ID
        right_column: MFG_PLANT_ID
    right_table: MFG_PLANT
  - name: MFG_inventory_to_raw_material
    join_type: left_outer
    relationship_type: many_to_one
    left_table: MFG_INVENTORY
    relationship_columns:
      - left_column: MATERIAL_ID
        right_column: MATERIAL_ID
    right_table: RAW_MATERIAL
  - name: MFG_inventory_to_component
    join_type: left_outer
    relationship_type: many_to_one
    left_table: MFG_INVENTORY
    relationship_columns:
      - left_column: COMPONENT_ID
        right_column: COMPONENT_ID
    right_table: COMPONENT
  - name: MFG_inventory_to_product
    join_type: left_outer
    relationship_type: many_to_one
    left_table: MFG_INVENTORY
    relationship_columns:
      - left_column: PRODUCT_ID
        right_column: PRODUCT_ID
    right_table: PRODUCT
  - name: orders_to_customer
    relationship_type: many_to_one
    join_type: inner
    left_table: ORDERS
    relationship_columns:
      - left_column: CUSTOMER_ID
        right_column: CUSTOMER_ID
    right_table: CUSTOMER
  - name: orders_to_mfg_plant
    relationship_type: many_to_one
    join_type: inner
    left_table: ORDERS
    relationship_columns:
      - left_column: MFG_PLANT_ID
        right_column: MFG_PLANT_ID
    right_table: MFG_PLANT
  - name: orders_to_product
    join_type: inner
    relationship_type: many_to_one
    left_table: ORDERS
    relationship_columns:
      - left_column: PRODUCT_ID
        right_column: PRODUCT_ID
    right_table: PRODUCT
  - name: shipment_to_origin_MFG_PLANT
    join_type: inner
    relationship_type: many_to_one
    left_table: SHIPMENT
    relationship_columns:
      - left_column: ORIGIN_MFG_PLANT_ID
        right_column: MFG_PLANT_ID
    right_table: MFG_PLANT
  - name: shipment_to_destination_customer
    join_type: inner
    relationship_type: many_to_one
    left_table: SHIPMENT
    relationship_columns:
      - left_column: DESTINATION_CUSTOMER_ID
        right_column: CUSTOMER_ID
    right_table: CUSTOMER
  - name: MFG_PLANT_to_transport_cost_surcharge_source
    join_type: inner
    relationship_type: many_to_one
    left_table: TRANSPORT_COST_SURCHARGE
    relationship_columns:
      - left_column: SOURCE_FACILITY_ID
        right_column: MFG_PLANT_ID
    right_table: MFG_PLANT
  - name: MFG_PLANT_to_transport_cost_surcharge_destination
    join_type: inner
    relationship_type: many_to_one
    left_table: TRANSPORT_COST_SURCHARGE
    relationship_columns:
      - left_column: DESTINATION_FACILITY_ID
        right_column: MFG_PLANT_ID
    right_table: MFG_PLANT
  - name: raw_material_to_supplier
    join_type: left_outer
    relationship_type: many_to_one
    left_table: RAW_MATERIAL
    relationship_columns:
      - left_column: SUPPLIER_ID
        right_column: SUPPLIER_ID
    right_table: SUPPLIERS
  - name: bill_of_materials_to_parent_product
    join_type: left_outer
    relationship_type: many_to_one
    left_table: BILL_OF_MATERIALS
    relationship_columns:
      - left_column: PARENT_PRODUCT_ID
        right_column: PRODUCT_ID
    right_table: PRODUCT
  - name: bill_of_materials_to_parent_component
    join_type: left_outer
    relationship_type: many_to_one
    left_table: BILL_OF_MATERIALS
    relationship_columns:
      - left_column: PARENT_COMPONENT_ID
        right_column: COMPONENT_ID
    right_table: COMPONENT
  - name: bill_of_materials_to_child_material
    join_type: left_outer
    relationship_type: many_to_one
    left_table: BILL_OF_MATERIALS
    relationship_columns:
      - left_column: CHILD_MATERIAL_ID
        right_column: MATERIAL_ID
    right_table: RAW_MATERIAL
  - name: bill_of_materials_to_child_component
    join_type: left_outer
    relationship_type: many_to_one
    left_table: BILL_OF_MATERIALS
    relationship_columns:
      - left_column: CHILD_COMPONENT_ID
        right_column: COMPONENT_ID
    right_table: COMPONENT
verified_queries:
  - name: Active MFG Plants
    question: How many active MFG plants do we have?
    use_as_onboarding_question: true
    sql: SELECT COUNT(*) AS active_plant_count FROM MFG_PLANT WHERE is_active = TRUE
    verified_by: Reid Lewis
    verified_at: 1740767188
  - name: AEROSPACE Business Line Orders
    question: How many orders are scheduled for the AEROSPACE business line?
    use_as_onboarding_question: true
    sql: SELECT COUNT(*) AS aerospace_order_count FROM orders AS o JOIN product AS p ON o.product_id = p.product_id WHERE p.business_line = ''AEROSPACE''
    verified_by: Reid Lewis
    verified_at: 1740767472
  - name: Finished Goods Inventory
    question: What''s the total quantity of finished goods we have in our manufacturing plants?
    use_as_onboarding_question: true
    sql: SELECT SUM(quantity_on_hand) AS total_finished_goods_quantity FROM mfg_inventory WHERE product_id IS NOT NULL
    verified_by: Reid Lewis
    verified_at: 1740767486
  - name: Top Customers by Revenue
    question: Who are our top 5 customers by order value?
    use_as_onboarding_question: true
    sql: SELECT c.customer_name, SUM(o.total_price) AS total_order_value FROM orders AS o JOIN customer AS c ON o.customer_id = c.customer_id GROUP BY c.customer_name ORDER BY total_order_value DESC LIMIT 5
    verified_by: Reid Lewis
    verified_at: 1740767647
  - name: Recent Orders
    question: How many orders did we receive in the last month?
    use_as_onboarding_question: true
    sql: SELECT COUNT(*) AS order_count_last_30_days FROM orders WHERE order_date >= DATEADD(DAY, -30, CURRENT_DATE)
    verified_by: Reid Lewis
    verified_at: 1740767520
  - name: Low Inventory Materials
    question: Which raw materials at our Manufacturing Plants are running low on inventory?
    use_as_onboarding_question: true
    sql: SELECT mp.mfg_plant_name, rm.material_name, mi.quantity_on_hand, mi.safety_stock_level, mi.days_forward_coverage, mi.material_lead_time FROM mfg_inventory AS mi JOIN MFG_PLANT AS mp ON mi.MFG_PLANT_ID = mp.MFG_PLANT_ID JOIN raw_material AS rm ON mi.material_id = rm.material_id WHERE mi.quantity_on_hand < mi.safety_stock_level AND mi.days_forward_coverage <= mi.material_lead_time + mi.lead_time_variability
    verified_by: Reid Lewis
    verified_at: 1741189275
  - name: Late Shipments Analysis
    question: How many of our shipments were late last quarter?
    use_as_onboarding_question: true
    sql: SELECT COUNT(*) AS late_shipment_count FROM shipment WHERE actual_delivery_date > expected_delivery_date AND ship_date >= DATE_TRUNC(''QUARTER'', CURRENT_DATE) - INTERVAL ''3 MONTHS'' AND ship_date < DATE_TRUNC(''QUARTER'', CURRENT_DATE)
    verified_by: Reid Lewis
    verified_at: 1740767671
  - name: Plant Production Capacity
    question: What is the average production capacity utilization across our manufacturing plants?
    use_as_onboarding_question: true
    sql: SELECT mp.mfg_plant_name, mp.square_footage, mp.number_of_employees, COUNT(DISTINCT mi.product_id) as products_produced FROM mfg_plant mp LEFT JOIN mfg_inventory mi ON mp.mfg_plant_id = mi.mfg_plant_id WHERE mi.product_id IS NOT NULL GROUP BY mp.mfg_plant_name, mp.square_footage, mp.number_of_employees ORDER BY products_produced DESC
    verified_by: Reid Lewis
    verified_at: 1740767692
  - name: Material Transfer Cost Analysis
    question: For plants with low inventory, what would it cost to transfer materials from plants with excess inventory versus purchasing new materials?
    use_as_onboarding_question: false
    sql: WITH low_inventory AS (SELECT mi.mfg_plant_id AS low_plant_id, mp.mfg_plant_name AS low_plant_name, mi.material_id, rm.material_name, mi.quantity_on_hand AS low_qty, mi.replenishment_point, (mi.replenishment_point - mi.quantity_on_hand) AS units_needed, rm.material_cost, rm.plant_transport_cost FROM mfg_inventory AS mi JOIN mfg_plant AS mp ON mi.mfg_plant_id = mp.mfg_plant_id JOIN raw_material AS rm ON mi.material_id = rm.material_id WHERE mi.quantity_on_hand < mi.safety_stock_level AND mi.days_forward_coverage <= mi.material_lead_time + mi.lead_time_variability), excess_inventory AS (SELECT mi.mfg_plant_id AS excess_plant_id, mp.mfg_plant_name AS excess_plant_name, mi.material_id, mi.quantity_on_hand AS excess_qty, mi.replenishment_point AS excess_replenishment_point, (mi.quantity_on_hand - mi.replenishment_point) AS available_to_transfer FROM mfg_inventory AS mi JOIN mfg_plant AS mp ON mi.mfg_plant_id = mp.mfg_plant_id WHERE mi.quantity_on_hand > 3 * mi.safety_stock_level AND mi.days_forward_coverage > 2 * mi.material_lead_time) SELECT l.low_plant_name, l.material_name, l.units_needed, l.material_cost * l.units_needed AS supplier_purchase_cost, e.excess_plant_name, LEAST(l.units_needed, e.available_to_transfer) AS transferrable_units, l.plant_transport_cost * LEAST(l.units_needed, e.available_to_transfer) * tcs.transport_cost_surcharge AS transfer_cost FROM low_inventory AS l LEFT JOIN excess_inventory AS e ON l.material_id = e.material_id LEFT JOIN transport_cost_surcharge AS tcs ON e.excess_plant_id = tcs.source_facility_id AND l.low_plant_id = tcs.destination_facility_id ORDER BY l.low_plant_name, l.material_name
    verified_by: Reid Lewis
    verified_at: 1741191526
  - name: Show me the material names and their lead times for materials containing ''steel'' or ''copper'' in their names
    question: Show me the material names and their lead times for materials containing ''steel'' or ''copper'' in their names
    sql: |-
      SELECT
        DISTINCT r.material_name,
        i.material_lead_time
      FROM
        mfg_inventory AS i
        LEFT OUTER JOIN raw_material AS r ON i.material_id = r.material_id
      WHERE
        LOWER(r.material_name) LIKE ''%steel%''
        OR LOWER(r.material_name) LIKE ''%copper%''
      ORDER BY
        r.material_name
    use_as_onboarding_question: false
    verified_by: Reid Lewis
    verified_at: 1760015223
module_custom_instructions:
  question_categorization: |+
    If a user mentions terms like ''airplane,'' ''avionics,'' ''flight,'' or ''aircraft,'' they are likely referring to the AEROSPACE business line. Terms like ''factory,'' ''PLC,'' ''process control,'' or ''manufacturing'' likely refer to INDUSTRIAL. ''Thermostat,'' ''HVAC,'' ''building management,'' or ''climate control'' usually refer to BUILDINGS. ''Energy,'' ''solar,'' ''wind,'' ''battery,'' or ''sustainability'' generally refer to ENERGY.

    Manufacturing plant inventory (MFG_INVENTORY) can contain three types of items:
    1. Raw materials (material_id populated) - sourced from suppliers
    2. Components (component_id populated) - manufactured from raw materials  
    3. Finished products (product_id populated) - assembled from components, sold directly to customers

    When a user asks about ''inventory,'' consider the context:
    - At manufacturing plants: could mean raw materials, components, or finished products
    - If unspecified, assume they want all inventory types unless context suggests otherwise
    - ''Raw materials'' = materials sourced from suppliers
    - ''Components'' = parts manufactured in-house
    - ''Finished goods/products'' = final products sold to customers

  sql_generation: |-
    Unless explicitly specified otherwise, assume users are asking about current data, not historical data. For example, ''inventory levels'' should refer to the current `quantity_on_hand`, not past inventory.

    The ''business_line'' column is crucial. Many queries will implicitly or explicitly refer to one of the four business lines: AEROSPACE, INDUSTRIAL, BUILDINGS, and ENERGY. Pay close attention to this.

    The supply chain flow is: Suppliers → Manufacturing Plants → Customers (direct sales only).

    We now have detailed supplier information in the SUPPLIERS table, which includes contact details, business lines, and preferred supplier status. Raw materials are linked to their primary suppliers.

    The BILL_OF_MATERIALS table shows the detailed breakdown of what raw materials and components are needed to manufacture each product or component, including quantities, units of measure, and scrap factors.

    For material transfer analysis, users may ask about transferring raw materials from manufacturing plants with excess inventory to those with shortages. Compare the cost of purchasing new materials versus transferring existing materials between plants, factoring in transport_cost_surcharge.')
OVERWRITE = TRUE
SINGLE = TRUE;

ALTER STAGE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SEMANTIC_STAGE REFRESH;

/*************************************************************************************************/
-- SECTION 6: Cortex Search Service (pre-chunked documentation)
/*************************************************************************************************/

CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.PARSED_PDFS (
    PAGE_CONTENT VARCHAR,
    TITLE VARCHAR,
    INPUT_STAGE VARCHAR,
    RELATIVE_PATH VARCHAR
);

INSERT INTO SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.PARSED_PDFS
  (PAGE_CONTENT, TITLE, INPUT_STAGE, RELATIVE_PATH)
VALUES
  ('Supply Chain Network Overview. Document Version: 3.0 Date: October 9, 2025. 1. INTRODUCTION. This document outlines th'
      || 'e structure and operation of a global supply chain network (GSCN), which encompasses the interconnected organizations,'
      || ' resources, and processes involved in creating and distributing advanced technology systems to end customers. The GSCN'
      || ' effectiveness is crucial for competitiveness, profitability, and customer satisfaction. COMPANY DESCRIPTION: Our comp'
      || 'any is a leading manufacturer and supplier of high-performance advanced technology systems, specializing in aerospace '
      || 'avionics, industrial automation, building management, and renewable energy solutions. With a commitment to quality, re'
      || 'liability, and innovation, we serve a diverse customer base across four key business sectors.',
  'Supply Chain Network Overview',
  'SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SCN_PDF',
  'Supply Chain Network Overview.pdf'),
  ('CORPORATE STRUCTURE DESCRIPTION: Our company operates with a multi-divisional structure designed to effectively manage'
      || ' its product portfolio, serve diverse markets, and optimize its supply chain. The company structure is organized aroun'
      || 'd four primary business lines, with integrated supply chain operations supporting all divisions. 2. LINES OF BUSINESS '
      || '(PRODUCT DIVISIONS): The company is structured into four primary lines of business, each responsible for the design, p'
      || 'roduction, and marketing of a specific product category: AEROSPACE, INDUSTRIAL, BUILDINGS, and ENERGY.',
  'Supply Chain Network Overview',
  'SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SCN_PDF',
  'Supply Chain Network Overview.pdf'),
  ('AEROSPACE BUSINESS LINE: Responsible for the development and manufacturing of advanced aviation systems and avionics e'
      || 'quipment. Product Portfolio: Flight Management Systems, Engine Monitoring Systems, Weather Radar Systems, Fuel Managem'
      || 'ent Systems, Navigation Systems, Communication Systems, Avionics Display Systems, Landing Gear Controllers, Cabin Pres'
      || 'sure Systems, and Emergency Systems. Focuses on serving: Commercial Aviation (American Airlines, Delta Air Lines, Unit'
      || 'ed Airlines, Southwest Airlines, JetBlue Airways), Aircraft Manufacturing (Boeing Commercial Airplanes, Airbus America'
      || 's), Defense Aerospace (Lockheed Martin Aeronautics, Northrop Grumman, Raytheon Technologies). Manufacturing Facilities'
      || ' (6 Plants): Phoenix Aerospace Manufacturing (Phoenix, AZ), Seattle Aircraft Components (Seattle, WA), Wichita Aviatio'
      || 'n Systems (Wichita, KS), Fort Worth Defense Systems (Fort Worth, TX), Long Beach Aircraft Assembly (Long Beach, CA), C'
      || 'incinnati Engine Components (Cincinnati, OH).',
  'Supply Chain Network Overview',
  'SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SCN_PDF',
  'Supply Chain Network Overview.pdf'),
  ('INDUSTRIAL BUSINESS LINE: Oversees the production of industrial automation and process control systems. Product Portfo'
      || 'lio: SCADA Systems, DCS Control Systems, Safety Instrumented Systems, MES Production Systems, Quality Control Systems,'
      || ' Asset Management Systems, Robotic Control Systems, Motor Drive Systems, Process Monitoring Systems, and Material Hand'
      || 'ling Systems. Caters to sectors including: Industrial Manufacturing (General Electric, 3M Company), Industrial Automat'
      || 'ion (Siemens USA, Rockwell Automation, ABB Inc, Schneider Electric, Emerson Electric), Heavy Machinery (Caterpillar In'
      || 'c), Automotive Manufacturing (Ford Motor Company, General Motors). Manufacturing Facilities (6 Plants): Atlanta Indust'
      || 'rial Automation, Milwaukee Process Control, Houston Petrochemical Systems, Detroit Automotive Systems, Chicago Manufac'
      || 'turing Control, St. Louis Material Handling.',
  'Supply Chain Network Overview',
  'SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SCN_PDF',
  'Supply Chain Network Overview.pdf'),
  ('BUILDINGS BUSINESS LINE: Manages the production of building automation, security, and climate control systems. Product'
      || ' Portfolio: Building Management Systems, Security Systems, Fire Safety Systems, Smart Lighting Systems, HVAC Control S'
      || 'ystems, Energy Management Systems, Access Control Systems, Elevator Control Systems, Parking Management Systems, and E'
      || 'mergency Communication Systems. Serves industries such as: Building Technologies (Johnson Controls), Building Automati'
      || 'on (Honeywell Building Technologies), HVAC Systems (Carrier Global, Trane Technologies), Elevator Systems (Otis Elevat'
      || 'or Company), Security Systems (Tyco International, Allegion, ASSA ABLOY), Lighting Solutions (Philips Lighting, Acuity'
      || ' Brands). Manufacturing Facilities (6 Plants): Denver Building Automation, Nashville HVAC Systems, Tampa Security Syst'
      || 'ems, Phoenix Smart Lighting, Portland Building Controls, Miami Facility Management.',
  'Supply Chain Network Overview',
  'SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SCN_PDF',
  'Supply Chain Network Overview.pdf'),
  ('ENERGY BUSINESS LINE: Develops and manufactures renewable energy systems and energy storage solutions. Product Portfol'
      || 'io: Battery Energy Storage Systems, Solar Power Systems, Wind Power Systems, Microgrid Controllers, Grid-Scale Inverte'
      || 'rs, Energy Management Platforms, Electric Vehicle Charging Systems, Fuel Cell Power Systems, Grid Stabilization System'
      || 's, and Energy Analytics Platforms. Provides solutions for: Energy Storage (Tesla Energy, BYD America, Fluence Energy),'
      || ' Renewable Energy (NextEra Energy, General Electric Renewable Energy), Solar Energy (First Solar, SolarEdge Technologi'
      || 'es, Enphase Energy), Wind Energy (Vestas Wind Systems), Energy Infrastructure (ExxonMobil). Manufacturing Facilities ('
      || '6 Plants): Austin Energy Storage, San Francisco Solar Systems, Portland Wind Power, Phoenix Grid Solutions, Denver Mic'
      || 'rogrid Systems, San Jose EV Charging.',
  'Supply Chain Network Overview',
  'SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SCN_PDF',
  'Supply Chain Network Overview.pdf'),
  ('3. KEY STRUCTURAL FEATURES: Product-Based Divisions allows for specialized expertise. Regional Distribution: All 24 ma'
      || 'nufacturing facilities are strategically located across the United States. Integrated Supply Chain: Centralized supply'
      || ' chain management with direct relationships. Simplified Distribution Model: Direct sales from manufacturing plants to '
      || 'customers, eliminating intermediary distributors. 4. GLOBAL SUPPLY CHAIN OVERVIEW: Our company operates an integrated '
      || 'supply chain network, encompassing suppliers, manufacturing facilities, and direct customer relationships across the U'
      || 'nited States. SUPPLIERS (35 Supplier Partners): We collaborate with a diverse portfolio of 35 specialized suppliers. E'
      || 'ach business line maintains dedicated supplier relationships. Of the 35 suppliers, 20 have preferred status.',
  'Supply Chain Network Overview',
  'SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SCN_PDF',
  'Supply Chain Network Overview.pdf'),
  ('5. CORE COMPONENTS: The supply chain network comprises three primary interacting entities: Suppliers, Manufacturers, a'
      || 'nd Customers. 5.1 SUPPLIERS: Provide raw materials and specialized components categorized by business line, supplier t'
      || 'ype, geographic location, and preferred status. 5.2 MANUFACTURERS: Transform inputs from suppliers into finished goods'
      || '. Key operational aspects include production planning, inventory management, quality control, and Bill of Materials (B'
      || 'OM) management. 5.3 CUSTOMERS: Purchase finished goods directly from manufacturing plants. These are typically large e'
      || 'nterprise customers and industry leaders.',
  'Supply Chain Network Overview',
  'SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SCN_PDF',
  'Supply Chain Network Overview.pdf'),
  ('6. FLOWS IN THE SUPPLY CHAIN NETWORK: Product Flow (Suppliers to Manufacturing Plants to Customers), Information Flow '
      || '(demand forecasts, order tracking, inventory visibility, production schedules), Financial Flow (purchase orders, payme'
      || 'nt terms Net 30 to Net 60, customer invoicing, cost tracking). 7. KEY PROCESSES: Planning (forecasting demand, coordin'
      || 'ating production), Sourcing/Procurement, Production/Manufacturing, Inventory Management (Raw Materials, Components, Fi'
      || 'nished Products), Logistics/Distribution (direct shipping from plants to customers), Returns.',
  'Supply Chain Network Overview',
  'SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SCN_PDF',
  'Supply Chain Network Overview.pdf'),
  ('8. FACILITY TYPES AND OPERATIONS: 24 manufacturing facilities across the United States. Total Manufacturing Capacity: '
      || '11,400,000 square feet and 20,780 employees. AEROSPACE (6 Facilities): 3,340,000 sq ft, 6,280 employees. INDUSTRIAL (6'
      || ' Facilities): 3,200,000 sq ft, 5,985 employees. BUILDINGS (6 Facilities): 1,860,000 sq ft, 2,800 employees. ENERGY (6 '
      || 'Facilities): 2,830,000 sq ft, 5,810 employees. Each facility has Raw Materials Warehouse and Finished Goods Warehouse.'
      || ' Centralized ERP system provides real-time visibility.',
  'Supply Chain Network Overview',
  'SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SCN_PDF',
  'Supply Chain Network Overview.pdf'),
  ('9. MATERIAL FLOW: Raw Material Sourcing from 35 specialized suppliers, Manufacturing Plant Production according to BOM'
      || ' specifications, Direct Customer Delivery with no intermediate distributors, Order Fulfillment Process tracked through'
      || ' lifecycle (Placed, In Production, Shipped, Delivered). 10. INVENTORY MANAGEMENT: Safety Stock, Replenishment Point, Q'
      || 'uantity on Hand, Material Lead Time. Low Inventory Alerts trigger replenishment when below safety stock. Excess Invent'
      || 'ory Identification when greater than 3x safety stock. Inter-Plant Material Transfer optimization comparing transfer co'
      || 'st vs supplier purchase cost.',
  'Supply Chain Network Overview',
  'SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SCN_PDF',
  'Supply Chain Network Overview.pdf'),
  ('11. SHIPMENT TRACKING: Unique shipment ID and tracking number. Key data: origin, destination, dates, shipping costs. P'
      || 'erformance measured by on-time delivery rate. 12. DAMAGED GOODS PROCESS: Detection and Reporting, Resolution Process ('
      || 'return, repair, or scrap), Quality Improvement feedback loop. 13. KEY PERFORMANCE INDICATORS: Efficiency (Total Supply'
      || ' Chain Cost, Inventory Turnover, Production Cycle Time, Capacity Utilization), Effectiveness (OTIF, Order Fulfillment '
      || 'Rate, Customer Satisfaction), Inventory (Low Inventory Occurrences, Excess Levels, Accuracy), Supplier (On-Time Delive'
      || 'ry, Quality, Lead Time), Logistics (Shipping Cost per Unit, Late Shipments, Damaged Goods Rate).',
  'Supply Chain Network Overview',
  'SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SCN_PDF',
  'Supply Chain Network Overview.pdf'),
  ('14. ENABLING TECHNOLOGIES: Core Systems (ERP, SCP, WMS, TMS), Advanced Technologies (BI and Analytics, IoT, AI, Cloud '
      || 'Computing). 15. CHALLENGES AND TRENDS: Operational Challenges (Demand Volatility, Supply Disruptions, Complexity Manag'
      || 'ement, Cost Pressures), Strategic Trends (Technology Advancement, Customer Expectations, Sustainability, Supply Chain '
      || 'Resilience). 16. PERFORMANCE MEASUREMENT across Efficiency, Effectiveness, Inventory Health, and Sustainability dimens'
      || 'ions. 17. TECHNOLOGY AND SYSTEMS SUMMARY. 18. SUSTAINABILITY COMMITMENT: Sustainable Sourcing, Operational Sustainabil'
      || 'ity, Product Sustainability. 19. CONCLUSION: Streamlined direct supply chain model connecting suppliers to plants to c'
      || 'ustomers.',
  'Supply Chain Network Overview',
  'SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SCN_PDF',
  'Supply Chain Network Overview.pdf');

CREATE OR REPLACE CORTEX SEARCH SERVICE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_INFO
ON PAGE_CONTENT
WAREHOUSE = SF_SOLUTIONS_WH
TARGET_LAG = '1 hour'
AS (
    SELECT
        '' AS PAGE_URL,
        PAGE_CONTENT,
        TITLE,
        RELATIVE_PATH
    FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.PARSED_PDFS
);

/*************************************************************************************************/
-- SECTION 7: Snowflake Intelligence Agent
/*************************************************************************************************/

CREATE OR REPLACE AGENT SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_ASSISTANT
COMMENT = 'Intelligent Supply Chain Assistant with Cortex Analyst and Search'
FROM SPECIFICATION $$
{
    "models": {"orchestration": "claude-sonnet-4-5"},
    "tools": [
        {
            "tool_spec": {
                "name": "Supply_Chain_Data",
                "type": "cortex_analyst_text_to_sql",
                "description": "This Cortex Analyst tool contains the semantic model for supply chain network data. Use it to answer data-driven questions about inventory levels, orders, shipments, plants, customers, suppliers, and materials."
            }
        },
        {
            "tool_spec": {
                "name": "Supply_Chain_Documents",
                "type": "cortex_search",
                "description": "This search service is indexed on documentation about business processes, policies, and conceptual information about the supply chain network. Use it for non-data questions about how the business operates."
            }
        }
    ],
    "tool_resources": {
        "Supply_Chain_Data": {
            "type": "cortex_analyst_text_to_sql",
            "semantic_model_file": "@SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SEMANTIC_STAGE/supply_chain_network.yaml"
        },
        "Supply_Chain_Documents": {
            "type": "cortex_search",
            "search_service": "SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_INFO"
        }
    }
}
$$;

/*************************************************************************************************/
-- SECTION 8: Verification
/*************************************************************************************************/

SELECT
    'Supply Chain Intelligence Platform deployed successfully!' AS STATUS,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLIERS) AS SUPPLIERS,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.MFG_PLANT) AS PLANTS,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.MFG_INVENTORY) AS INVENTORY_RECORDS,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.ORDERS) AS ORDERS,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.CUSTOMER) AS CUSTOMERS;
