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

ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"supply_chain_intelligence_platform","version":{"major":1,"minor":0},"attributes":{"is_quickstart":1,"source":"sql"}}';

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

USE DATABASE SF_SOLUTIONS;
USE SCHEMA SUPPLY_CHAIN_ENTITIES;

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
	PRIMARY KEY (SUPPLIER_ID)
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
	PRIMARY KEY (BOM_ID)
)COMMENT='Bill of materials defining what raw materials and components are needed to produce products and components'
;

-- Component
CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.COMPONENT (
	COMPONENT_ID INTEGER NOT NULL COMMENT 'Unique identifier for the component',
	COMPONENT_NAME VARCHAR(255) NOT NULL COMMENT 'Name of the component',
	COMPONENT_DESCRIPTION VARCHAR(1024) COMMENT 'Description of the component',
	BILL_OF_MATERIALS_ID INTEGER COMMENT 'Foreign key referencing a bill_of_materials table (if applicable)',
	BUSINESS_LINE VARCHAR(15) COMMENT 'business line (AEROSPACE, INDUSTRIAL, BUILDINGS, ENERGY)',
	PRIMARY KEY (COMPONENT_ID)
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
	PRIMARY KEY (PRODUCT_ID)
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
	PRIMARY KEY (CUSTOMER_ID)
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
	PRIMARY KEY (SHIPMENT_ID)
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
	PRIMARY KEY (ORDER_ID)
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
	PRIMARY KEY (MATERIAL_ID)
)COMMENT='Raw materials sourced from suppliers and used in manufacturing plants to produce components and products'
;

CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.TRANSPORT_COST_SURCHARGE (
	SOURCE_FACILITY_ID INTEGER NOT NULL COMMENT 'Unique identifier for the source facility with excess inventory',
	DESTINATION_FACILITY_ID INTEGER NOT NULL COMMENT 'Unique identifier for the destination facility that will receive materials',
	TRANSPORT_COST_SURCHARGE NUMBER(3,
	2) NOT NULL COMMENT 'Transport costs multiplier between facilities depending on distance and transport difficulty'
)COMMENT='Transport cost surcharge for moving materials between manufacturing plants'
;

-- Conversation History table for storing chat threads and messages
CREATE OR REPLACE TABLE SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.CONVERSATION_HISTORY (
	CONVERSATION_ID STRING NOT NULL COMMENT 'Unique identifier for each conversation thread',
	THREAD_NAME STRING NOT NULL COMMENT 'User-friendly name for the conversation thread',
	CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'Timestamp when the conversation was created',
	UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'Timestamp when the conversation was last updated',
	MESSAGES VARIANT COMMENT 'JSON array of messages in the conversation thread',
	PRIMARY KEY (CONVERSATION_ID)
)COMMENT='Storage for conversation history and chat threads for the Supply Chain Assistant';


/*************************************************************************************************/
-- SECTION 3-4: Demo Data + Date Normalization
-- Extracted to scripts/data.sql for efficient batch execution.
-- Execute: snow sql -f scripts/data.sql
/*************************************************************************************************/

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
FILE_FORMAT = (TYPE = 'CSV' FIELD_DELIMITER = NONE RECORD_DELIMITER = NONE COMPRESSION = NONE ESCAPE_UNENCLOSED_FIELD = NONE)
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
