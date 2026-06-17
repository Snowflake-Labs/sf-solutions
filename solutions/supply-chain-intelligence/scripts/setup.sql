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
-- Extracted to semantic/supply_chain_network.yaml for direct PUT upload.
-- Execute: PUT file://.../semantic/supply_chain_network.yaml @SEMANTIC_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE
/*************************************************************************************************/

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
