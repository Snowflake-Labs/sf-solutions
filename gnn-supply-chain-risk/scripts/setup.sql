-- ============================================================
-- GNN Supply Chain Risk Intelligence - Setup Script
-- Database: SF_SOLUTIONS  Schema: GNN_SUPPLY_CHAIN_RISK
-- ============================================================
-- Requires: ACCOUNTADMIN role
-- NOTE: GPU Compute Pool and External Access Integration require
--       Snowpark Container Services to be enabled on the account.
--       Comment out Sections 4 and 5 if not available.
-- ============================================================

-- ============================================================
-- Section 1: Infrastructure
-- ============================================================
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS SF_SOLUTIONS;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK;

USE DATABASE SF_SOLUTIONS;
USE SCHEMA GNN_SUPPLY_CHAIN_RISK;

CREATE WAREHOUSE IF NOT EXISTS SF_SOLUTIONS_WH
    WAREHOUSE_SIZE = XSMALL
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE SF_SOLUTIONS_WH;

-- ============================================================
-- Section 2: Stages
-- ============================================================
CREATE STAGE IF NOT EXISTS SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.MODELS_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for ML models and notebooks';

CREATE STAGE IF NOT EXISTS SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.DATA_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for data files';

CREATE STAGE IF NOT EXISTS SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.SEMANTIC_MODELS
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for semantic model YAML files';

-- ============================================================
-- Section 3: Tables
-- ============================================================
CREATE OR REPLACE TABLE SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VENDORS (
    VENDOR_ID VARCHAR(20) PRIMARY KEY,
    NAME VARCHAR(255) NOT NULL,
    COUNTRY_CODE VARCHAR(3) NOT NULL,
    CITY VARCHAR(100),
    PHONE VARCHAR(50),
    TIER NUMBER DEFAULT 1,
    FINANCIAL_HEALTH_SCORE FLOAT DEFAULT 0.5,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.MATERIALS (
    MATERIAL_ID VARCHAR(20) PRIMARY KEY,
    DESCRIPTION VARCHAR(255) NOT NULL,
    MATERIAL_GROUP VARCHAR(10) NOT NULL,
    UNIT_OF_MEASURE VARCHAR(10) DEFAULT 'PC',
    CRITICALITY_SCORE FLOAT DEFAULT 0.5,
    INVENTORY_DAYS NUMBER DEFAULT 30,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.PURCHASE_ORDERS (
    PO_ID VARCHAR(20) PRIMARY KEY,
    VENDOR_ID VARCHAR(20) NOT NULL,
    MATERIAL_ID VARCHAR(20) NOT NULL,
    QUANTITY NUMBER NOT NULL,
    UNIT_PRICE FLOAT NOT NULL,
    ORDER_DATE DATE NOT NULL,
    DELIVERY_DATE DATE,
    STATUS VARCHAR(20) DEFAULT 'OPEN',
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (VENDOR_ID) REFERENCES SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VENDORS(VENDOR_ID),
    FOREIGN KEY (MATERIAL_ID) REFERENCES SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.MATERIALS(MATERIAL_ID)
);

CREATE OR REPLACE TABLE SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.BILL_OF_MATERIALS (
    BOM_ID VARCHAR(20) PRIMARY KEY,
    PARENT_MATERIAL_ID VARCHAR(20) NOT NULL,
    CHILD_MATERIAL_ID VARCHAR(20) NOT NULL,
    QUANTITY_PER_UNIT FLOAT NOT NULL DEFAULT 1.0,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (PARENT_MATERIAL_ID) REFERENCES SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.MATERIALS(MATERIAL_ID),
    FOREIGN KEY (CHILD_MATERIAL_ID) REFERENCES SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.MATERIALS(MATERIAL_ID)
);

CREATE OR REPLACE TABLE SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.TRADE_DATA (
    BOL_ID VARCHAR(20) PRIMARY KEY,
    SHIPPER_NAME VARCHAR(255) NOT NULL,
    SHIPPER_COUNTRY VARCHAR(3),
    CONSIGNEE_NAME VARCHAR(255) NOT NULL,
    CONSIGNEE_COUNTRY VARCHAR(3),
    HS_CODE VARCHAR(10) NOT NULL,
    HS_DESCRIPTION VARCHAR(255),
    SHIP_DATE DATE NOT NULL,
    WEIGHT_KG FLOAT,
    VALUE_USD FLOAT,
    PORT_OF_ORIGIN VARCHAR(100),
    PORT_OF_DESTINATION VARCHAR(100),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.REGIONS (
    REGION_CODE VARCHAR(3) PRIMARY KEY,
    REGION_NAME VARCHAR(100) NOT NULL,
    BASE_RISK_SCORE FLOAT DEFAULT 0.0,
    GEOPOLITICAL_RISK FLOAT DEFAULT 0.0,
    NATURAL_DISASTER_RISK FLOAT DEFAULT 0.0,
    INFRASTRUCTURE_SCORE FLOAT DEFAULT 0.5,
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RISK_SCORES (
    SCORE_ID NUMBER AUTOINCREMENT PRIMARY KEY,
    NODE_ID VARCHAR(50) NOT NULL,
    NODE_TYPE VARCHAR(20) NOT NULL,
    RISK_SCORE FLOAT NOT NULL,
    RISK_CATEGORY VARCHAR(20),
    CONFIDENCE FLOAT,
    EMBEDDING ARRAY,
    CONTRIBUTING_FACTORS VARIANT,
    MODEL_VERSION VARCHAR(50),
    CALCULATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.PREDICTED_LINKS (
    LINK_ID NUMBER AUTOINCREMENT PRIMARY KEY,
    SOURCE_NODE_ID VARCHAR(50) NOT NULL,
    SOURCE_NODE_TYPE VARCHAR(20) NOT NULL,
    TARGET_NODE_ID VARCHAR(50) NOT NULL,
    TARGET_NODE_TYPE VARCHAR(20) NOT NULL,
    LINK_TYPE VARCHAR(50) NOT NULL,
    PROBABILITY FLOAT NOT NULL,
    EVIDENCE_STRENGTH VARCHAR(20),
    SUPPORTING_DATA VARIANT,
    MODEL_VERSION VARCHAR(50),
    PREDICTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.BOTTLENECKS (
    BOTTLENECK_ID NUMBER AUTOINCREMENT PRIMARY KEY,
    NODE_ID VARCHAR(50) NOT NULL,
    NODE_TYPE VARCHAR(20) NOT NULL,
    DEPENDENT_COUNT NUMBER NOT NULL,
    DEPENDENT_NODES ARRAY,
    IMPACT_SCORE FLOAT NOT NULL,
    DESCRIPTION VARCHAR(500),
    MITIGATION_STATUS VARCHAR(20) DEFAULT 'UNMITIGATED',
    IDENTIFIED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================
-- Section 4: Demo Data - VENDORS (50 rows)
-- ============================================================
INSERT INTO SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VENDORS (VENDOR_ID, NAME, COUNTRY_CODE, CITY, PHONE, TIER, FINANCIAL_HEALTH_SCORE) VALUES
    ('V10001', 'BHP Copper', 'MEX', 'Monterrey', '+52-350-328-3286', 1, 0.78),
    ('V10002', 'Antofagasta PLC', 'MEX', 'Monterrey', '+52-132-130-2535', 1, 0.44),
    ('V10003', 'First Quantum', 'USA', 'Charlotte', '+1-325-559-5557', 1, 0.83),
    ('V10004', 'Gamma Manufacturing', 'CHN', 'Shenzhen', '+86-259-320-6514', 1, 0.37),
    ('V10005', 'Freeport-McMoRan', 'JPN', 'Nagoya', '+81-926-144-8527', 1, 0.65),
    ('V10006', 'Freeport Cobalt', 'COD', 'Likasi', '+243-949-743-6925', 1, 0.68),
    ('V10007', 'Alpha Industries', 'DEU', 'Munich', '+49-975-338-2654', 1, 0.55),
    ('V10008', 'NXP Semiconductors', 'USA', 'Houston', '+1-314-786-5374', 1, 0.76),
    ('V10009', 'Codelco', 'MEX', 'Monterrey', '+52-646-846-5010', 1, 0.41),
    ('V10010', 'Umicore Materials', 'JPN', 'Osaka', '+81-941-132-6168', 1, 0.56),
    ('V10011', 'CALB', 'CHN', 'Beijing', '+86-505-758-8517', 1, 0.39),
    ('V10012', 'Theta Systems', 'CHN', 'Beijing', '+86-508-470-4593', 1, 0.95),
    ('V10013', 'Samsung SDI Co.', 'CHN', 'Guangzhou', '+86-981-212-3504', 1, 0.71),
    ('V10014', 'Zeta Precision', 'DEU', 'Berlin', '+49-710-579-9669', 1, 0.46),
    ('V10015', 'DuPont Electronics', 'USA', 'Charlotte', '+1-868-373-6573', 1, 0.37),
    ('V10016', 'STMicroelectronics', 'USA', 'Phoenix', '+1-612-880-3927', 1, 0.63),
    ('V10017', 'Southern Copper', 'CHN', 'Beijing', '+86-256-482-3646', 1, 0.65),
    ('V10018', 'Beta Components', 'DEU', 'Munich', '+49-214-471-6038', 1, 0.46),
    ('V10019', 'Gotion High-Tech', 'KOR', 'Seoul', '+82-935-170-9727', 1, 0.80),
    ('V10020', 'Mitsubishi Chemical', 'CHN', 'Guangzhou', '+86-640-993-7932', 1, 0.93),
    ('V10021', 'Epsilon Tech', 'AUS', 'Sydney', '+61-548-629-8397', 1, 0.38),
    ('V10022', 'Svolt Energy', 'KOR', 'Ulsan', '+82-335-702-4608', 1, 0.30),
    ('V10023', 'Texas Instruments', 'DEU', 'Munich', '+49-980-438-2160', 1, 0.63),
    ('V10024', 'BYD Battery', 'KOR', 'Daegu', '+82-840-684-8744', 1, 0.46),
    ('V10025', 'Infineon Technologies', 'USA', 'Phoenix', '+1-774-541-6804', 1, 0.58),
    ('V10026', 'Copper Corp 26', 'USA', 'Charlotte', '+1-200-162-7596', 1, 0.77),
    ('V10027', 'Ganfeng Lithium', 'CHL', 'Santiago', '+56-649-559-3296', 1, 0.57),
    ('V10028', 'Sumitomo Chemical', 'KOR', 'Busan', '+82-927-982-2604', 1, 0.33),
    ('V10029', 'BASF Materials', 'COD', 'Lubumbashi', '+243-516-597-8886', 1, 0.44),
    ('V10030', 'Renesas Electronics', 'USA', 'Charlotte', '+1-499-371-8454', 1, 0.49),
    ('V10031', '3M Advanced Materials', 'MEX', 'Tijuana', '+52-403-322-1958', 1, 0.68),
    ('V10032', 'ON Semiconductor', 'USA', 'Houston', '+1-614-973-9701', 1, 0.40),
    ('V10033', 'Materials Corp 33', 'COD', 'Lubumbashi', '+243-709-169-4853', 1, 0.56),
    ('V10034', 'Albemarle Corp', 'AUS', 'Sydney', '+61-734-183-7868', 1, 0.73),
    ('V10035', 'Materials Corp 35', 'USA', 'Houston', '+1-785-833-6147', 1, 0.46),
    ('V10036', 'Materials Corp 36', 'JPN', 'Nagoya', '+81-109-569-2638', 1, 0.35),
    ('V10037', 'Panasonic Energy', 'KOR', 'Ulsan', '+82-170-350-7054', 1, 0.49),
    ('V10038', 'Copper Corp 38', 'USA', 'Houston', '+1-641-108-5905', 1, 0.91),
    ('V10039', 'LG Energy Solution', 'CHN', 'Shenzhen', '+86-860-666-3546', 1, 0.48),
    ('V10040', 'Materials Corp 40', 'MEX', 'Guadalajara', '+52-803-749-5325', 1, 0.63),
    ('V10041', 'EVE Energy', 'KOR', 'Seoul', '+82-949-383-1722', 1, 0.30),
    ('V10042', 'Electronics Corp 42', 'DEU', 'Frankfurt', '+49-552-664-8007', 1, 0.66),
    ('V10043', 'Delta Materials', 'CHN', 'Shenzhen', '+86-540-230-1685', 1, 0.50),
    ('V10044', 'Materials Corp 44', 'CHL', 'Santiago', '+56-798-355-2684', 1, 0.53),
    ('V10045', 'Copper Corp 45', 'USA', 'Phoenix', '+1-258-342-3662', 1, 0.93),
    ('V10046', 'Sigma Lithium', 'CHL', 'Concepcion', '+56-440-901-7745', 1, 0.82),
    ('V10047', 'SQM Mining', 'CHL', 'Antofagasta', '+56-491-993-1634', 1, 0.86),
    ('V10048', 'SK On', 'KOR', 'Daegu', '+82-328-124-4164', 1, 0.56),
    ('V10049', 'Generic Corp 49', 'KOR', 'Seoul', '+82-459-756-9346', 1, 0.56),
    ('V10050', 'Materials Corp 50', 'COD', 'Kinshasa', '+243-998-367-3925', 1, 0.68);

-- ============================================================
-- Section 5: Demo Data - MATERIALS (26 rows)
-- ============================================================
INSERT INTO SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.MATERIALS (MATERIAL_ID, DESCRIPTION, MATERIAL_GROUP, UNIT_OF_MEASURE, CRITICALITY_SCORE, INVENTORY_DAYS) VALUES
    ('M-1000', 'EV Battery Pack 85kWh', 'FIN', 'PC', 1.0, 31),
    ('M-2001', 'Battery Module 400V', 'SEMI', 'PC', 0.95, 17),
    ('M-2002', 'Battery Management System', 'SEMI', 'PC', 0.9, 21),
    ('M-2003', 'Thermal Management Assembly', 'SEMI', 'PC', 0.85, 53),
    ('M-2004', 'Battery Enclosure Assembly', 'SEMI', 'PC', 0.8, 42),
    ('M-2005', 'High-Voltage Harness', 'SEMI', 'PC', 0.85, 37),
    ('M-3001', 'Lithium Hydroxide Grade A', 'RAW', 'KG', 0.95, 35),
    ('M-3002', 'Lithium Carbonate Battery Grade', 'RAW', 'KG', 0.95, 42),
    ('M-3003', 'Cobalt Oxide Powder', 'RAW', 'KG', 0.9, 53),
    ('M-3004', 'Nickel Sulfate Battery Grade', 'RAW', 'KG', 0.85, 47),
    ('M-3005', 'Manganese Dioxide', 'RAW', 'KG', 0.75, 22),
    ('M-3006', 'Synthetic Graphite Anode', 'RAW', 'KG', 0.85, 39),
    ('M-3007', 'Silicon Anode Additive', 'RAW', 'KG', 0.7, 51),
    ('M-3008', 'Copper Foil 8 Micron', 'RAW', 'KG', 0.85, 27),
    ('M-3009', 'Copper Busbar 5mm', 'RAW', 'KG', 0.8, 31),
    ('M-3010', 'Aluminum Foil 15 Micron', 'RAW', 'KG', 0.8, 17),
    ('M-3011', 'Aluminum Housing Profile', 'RAW', 'KG', 0.7, 60),
    ('M-3012', 'Electrolyte LiPF6 Solution', 'RAW', 'L', 0.9, 42),
    ('M-3013', 'Ceramic Coated Separator', 'RAW', 'M2', 0.9, 15),
    ('M-3014', 'BMS Controller IC', 'RAW', 'PC', 0.85, 48),
    ('M-3015', 'Cell Monitoring ASIC', 'RAW', 'PC', 0.85, 49),
    ('M-3016', 'Power MOSFET Module', 'RAW', 'PC', 0.8, 58),
    ('M-3017', 'Thermal Interface Material', 'RAW', 'KG', 0.75, 57),
    ('M-3018', 'Cooling Plate Aluminum', 'RAW', 'PC', 0.7, 27),
    ('M-3019', 'High-Voltage Cable 35mm2', 'RAW', 'M', 0.8, 38),
    ('M-3020', 'Connector Assembly HV', 'RAW', 'PC', 0.75, 42);

-- ============================================================
-- Section 6: Demo Data - REGIONS (9 rows)
-- ============================================================
INSERT INTO SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.REGIONS (REGION_CODE, REGION_NAME, BASE_RISK_SCORE, GEOPOLITICAL_RISK, NATURAL_DISASTER_RISK, INFRASTRUCTURE_SCORE) VALUES
    ('CHN', 'China', 0.3, 0.5, 0.2, 0.7),
    ('KOR', 'South Korea', 0.2, 0.3, 0.3, 0.9),
    ('JPN', 'Japan', 0.2, 0.1, 0.5, 0.95),
    ('USA', 'United States', 0.1, 0.1, 0.2, 0.9),
    ('MEX', 'Mexico', 0.3, 0.2, 0.3, 0.6),
    ('DEU', 'Germany', 0.1, 0.1, 0.1, 0.95),
    ('CHL', 'Chile', 0.4, 0.2, 0.6, 0.7),
    ('AUS', 'Australia', 0.8, 0.85, 0.85, 0.45),
    ('COD', 'DR Congo', 0.7, 0.8, 0.3, 0.3);

-- ============================================================
-- Section 7: Demo Data - BILL_OF_MATERIALS (23 rows)
-- ============================================================
INSERT INTO SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.BILL_OF_MATERIALS (BOM_ID, PARENT_MATERIAL_ID, CHILD_MATERIAL_ID, QUANTITY_PER_UNIT) VALUES
    ('BOM-0001', 'M-1000', 'M-2001', 1),
    ('BOM-0002', 'M-1000', 'M-2002', 3),
    ('BOM-0003', 'M-1000', 'M-2003', 3),
    ('BOM-0004', 'M-1000', 'M-2004', 1),
    ('BOM-0005', 'M-1000', 'M-2005', 3),
    ('BOM-0006', 'M-2001', 'M-3001', 5.32),
    ('BOM-0007', 'M-2001', 'M-3002', 6.84),
    ('BOM-0008', 'M-2001', 'M-3003', 3.6),
    ('BOM-0009', 'M-2001', 'M-3004', 7.12),
    ('BOM-0010', 'M-2001', 'M-3006', 5.77),
    ('BOM-0011', 'M-2001', 'M-3008', 2.32),
    ('BOM-0012', 'M-2001', 'M-3010', 6.82),
    ('BOM-0013', 'M-2001', 'M-3012', 4.1),
    ('BOM-0014', 'M-2001', 'M-3013', 7.61),
    ('BOM-0015', 'M-2002', 'M-3014', 2.15),
    ('BOM-0016', 'M-2002', 'M-3015', 5.91),
    ('BOM-0017', 'M-2002', 'M-3016', 4.36),
    ('BOM-0018', 'M-2003', 'M-3017', 8.42),
    ('BOM-0019', 'M-2003', 'M-3018', 3.39),
    ('BOM-0020', 'M-2004', 'M-3011', 2.5),
    ('BOM-0021', 'M-2005', 'M-3009', 7.96),
    ('BOM-0022', 'M-2005', 'M-3019', 6.26),
    ('BOM-0023', 'M-2005', 'M-3020', 3.56);

-- ============================================================
-- Section 8: Demo Data - PURCHASE_ORDERS (120 rows)
-- ============================================================
INSERT INTO SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.PURCHASE_ORDERS (PO_ID, VENDOR_ID, MATERIAL_ID, QUANTITY, UNIT_PRICE, ORDER_DATE, DELIVERY_DATE, STATUS) VALUES
    ('PO-9001', 'V10033', 'M-3007', 8252, 397.9, '2023-03-28', '2023-04-21', 'CLOSED'),
    ('PO-9002', 'V10022', 'M-3020', 2030, 410.12, '2023-05-01', '2023-06-23', 'CLOSED'),
    ('PO-9003', 'V10002', 'M-3005', 1257, 126.2, '2023-09-01', '2023-09-24', 'CLOSED'),
    ('PO-9004', 'V10013', 'M-3019', 6791, 249.72, '2023-05-05', '2023-06-06', 'OPEN'),
    ('PO-9005', 'V10050', 'M-2001', 267, 1484.79, '2023-12-23', '2024-03-12', 'CLOSED'),
    ('PO-9006', 'V10047', 'M-3008', 2488, 230.95, '2023-08-26', '2023-11-15', 'CLOSED'),
    ('PO-9007', 'V10040', 'M-2004', 467, 3736.73, '2023-09-16', '2023-11-23', 'CLOSED'),
    ('PO-9008', 'V10029', 'M-2004', 182, 3883.0, '2023-11-23', '2024-01-11', 'CLOSED'),
    ('PO-9009', 'V10030', 'M-3009', 1769, 358.2, '2023-05-01', '2023-06-18', 'CLOSED'),
    ('PO-9010', 'V10006', 'M-3018', 2767, 79.66, '2023-07-16', '2023-08-18', 'CLOSED'),
    ('PO-9011', 'V10022', 'M-3014', 9390, 235.63, '2023-02-01', '2023-03-13', 'CLOSED'),
    ('PO-9012', 'V10045', 'M-3019', 820, 429.08, '2023-10-22', '2023-12-23', 'CLOSED'),
    ('PO-9013', 'V10020', 'M-3012', 6889, 427.46, '2023-08-03', '2023-10-24', 'CLOSED'),
    ('PO-9014', 'V10027', 'M-3009', 8456, 19.37, '2023-06-22', '2023-08-26', 'CLOSED'),
    ('PO-9015', 'V10040', 'M-3005', 9251, 18.35, '2023-07-21', '2023-10-18', 'OPEN'),
    ('PO-9016', 'V10010', 'M-3014', 8064, 94.96, '2023-05-14', '2023-07-15', 'CLOSED'),
    ('PO-9017', 'V10022', 'M-3011', 6711, 142.74, '2023-08-04', '2023-09-19', 'OPEN'),
    ('PO-9018', 'V10004', 'M-3018', 6233, 115.99, '2023-02-05', '2023-02-24', 'OPEN'),
    ('PO-9019', 'V10002', 'M-2002', 368, 1185.72, '2023-03-06', '2023-05-19', 'OPEN'),
    ('PO-9020', 'V10030', 'M-3007', 4698, 384.61, '2023-03-27', '2023-04-24', 'CLOSED'),
    ('PO-9021', 'V10038', 'M-2001', 63, 4679.99, '2023-10-22', '2023-12-23', 'CLOSED'),
    ('PO-9022', 'V10005', 'M-2002', 353, 3607.76, '2023-11-18', '2024-01-02', 'OPEN'),
    ('PO-9023', 'V10044', 'M-3010', 2483, 399.13, '2023-10-17', '2023-11-05', 'CLOSED'),
    ('PO-9024', 'V10005', 'M-3012', 8789, 325.53, '2023-01-07', '2023-03-15', 'CLOSED'),
    ('PO-9025', 'V10041', 'M-3012', 8032, 355.12, '2023-08-11', '2023-09-16', 'CLOSED'),
    ('PO-9026', 'V10050', 'M-3018', 8421, 235.11, '2023-10-31', '2023-12-18', 'CLOSED'),
    ('PO-9027', 'V10018', 'M-2001', 280, 1597.39, '2023-08-26', '2023-11-20', 'CLOSED'),
    ('PO-9028', 'V10025', 'M-3016', 3479, 246.34, '2023-07-01', '2023-08-17', 'CLOSED'),
    ('PO-9029', 'V10045', 'M-3020', 5026, 280.12, '2023-09-22', '2023-10-30', 'OPEN'),
    ('PO-9030', 'V10028', 'M-3014', 9596, 380.29, '2023-12-20', '2024-03-03', 'CLOSED'),
    ('PO-9031', 'V10011', 'M-3001', 5320, 114.69, '2023-12-21', '2024-02-04', 'CLOSED'),
    ('PO-9032', 'V10031', 'M-3012', 9568, 267.81, '2023-08-06', '2023-10-29', 'CLOSED'),
    ('PO-9033', 'V10018', 'M-3015', 5523, 129.44, '2023-03-03', '2023-04-10', 'CLOSED'),
    ('PO-9034', 'V10049', 'M-3018', 3533, 99.81, '2023-09-05', '2023-10-24', 'CLOSED'),
    ('PO-9035', 'V10019', 'M-2002', 166, 2123.96, '2023-06-04', '2023-06-19', 'CLOSED'),
    ('PO-9036', 'V10034', 'M-3002', 5286, 350.22, '2023-03-06', '2023-05-21', 'OPEN'),
    ('PO-9037', 'V10019', 'M-2005', 290, 2654.21, '2023-06-24', '2023-07-31', 'OPEN'),
    ('PO-9038', 'V10008', 'M-3016', 1570, 203.35, '2023-02-07', '2023-05-05', 'OPEN'),
    ('PO-9039', 'V10020', 'M-3019', 1895, 496.99, '2023-03-02', '2023-05-26', 'CLOSED'),
    ('PO-9040', 'V10015', 'M-3020', 9061, 193.29, '2023-08-15', '2023-10-06', 'CLOSED'),
    ('PO-9041', 'V10004', 'M-3020', 2125, 474.06, '2023-04-17', '2023-05-28', 'CLOSED'),
    ('PO-9042', 'V10011', 'M-3006', 3347, 278.24, '2023-03-22', '2023-04-05', 'CLOSED'),
    ('PO-9043', 'V10031', 'M-3020', 5271, 21.16, '2023-05-28', '2023-07-17', 'CLOSED'),
    ('PO-9044', 'V10047', 'M-3008', 4834, 394.97, '2023-11-17', '2024-02-14', 'CLOSED'),
    ('PO-9045', 'V10015', 'M-3018', 2941, 454.66, '2023-03-14', '2023-04-06', 'OPEN'),
    ('PO-9046', 'V10039', 'M-3010', 9825, 460.99, '2023-08-13', '2023-09-11', 'CLOSED'),
    ('PO-9047', 'V10018', 'M-3013', 8699, 272.29, '2023-08-13', '2023-09-06', 'OPEN'),
    ('PO-9048', 'V10039', 'M-2003', 178, 616.39, '2023-04-28', '2023-07-24', 'OPEN'),
    ('PO-9049', 'V10037', 'M-2003', 70, 3933.99, '2023-03-31', '2023-06-13', 'CLOSED'),
    ('PO-9050', 'V10038', 'M-2002', 273, 3356.53, '2023-09-09', '2023-10-04', 'CLOSED'),
    ('PO-9051', 'V10021', 'M-3011', 2213, 429.58, '2023-06-18', '2023-08-23', 'CLOSED'),
    ('PO-9052', 'V10049', 'M-3013', 9512, 23.17, '2023-02-15', '2023-04-10', 'CLOSED'),
    ('PO-9053', 'V10033', 'M-3013', 518, 330.54, '2023-10-05', '2023-12-17', 'CLOSED'),
    ('PO-9054', 'V10024', 'M-3017', 8667, 314.58, '2023-01-27', '2023-03-08', 'CLOSED'),
    ('PO-9055', 'V10029', 'M-3010', 8441, 65.11, '2023-11-19', '2024-01-02', 'CLOSED'),
    ('PO-9056', 'V10034', 'M-3001', 7184, 51.14, '2023-02-28', '2023-05-12', 'OPEN'),
    ('PO-9057', 'V10032', 'M-3005', 5281, 256.89, '2023-05-20', '2023-07-26', 'CLOSED'),
    ('PO-9058', 'V10030', 'M-2002', 332, 1150.89, '2023-04-08', '2023-07-07', 'CLOSED'),
    ('PO-9059', 'V10050', 'M-2003', 454, 4344.86, '2023-06-24', '2023-09-10', 'CLOSED'),
    ('PO-9060', 'V10047', 'M-3010', 5391, 419.55, '2023-10-24', '2024-01-08', 'CLOSED'),
    ('PO-9061', 'V10026', 'M-3016', 5946, 278.2, '2023-10-06', '2023-12-07', 'CLOSED'),
    ('PO-9062', 'V10045', 'M-2002', 172, 3073.09, '2023-04-30', '2023-07-05', 'OPEN'),
    ('PO-9063', 'V10030', 'M-3016', 6825, 494.26, '2023-11-30', '2024-01-02', 'CLOSED'),
    ('PO-9064', 'V10033', 'M-2002', 352, 1993.98, '2023-02-21', '2023-05-02', 'OPEN'),
    ('PO-9065', 'V10003', 'M-3015', 2861, 207.94, '2023-12-02', '2024-01-04', 'OPEN'),
    ('PO-9066', 'V10026', 'M-3009', 7012, 326.67, '2023-06-18', '2023-09-08', 'CLOSED'),
    ('PO-9067', 'V10035', 'M-2004', 68, 3278.57, '2023-05-01', '2023-06-20', 'CLOSED'),
    ('PO-9068', 'V10008', 'M-3014', 2146, 224.62, '2023-12-22', '2024-02-12', 'OPEN'),
    ('PO-9069', 'V10017', 'M-3002', 6373, 190.55, '2023-03-16', '2023-04-30', 'CLOSED'),
    ('PO-9070', 'V10010', 'M-3006', 3368, 44.09, '2023-07-15', '2023-08-28', 'CLOSED'),
    ('PO-9071', 'V10015', 'M-2002', 286, 3370.57, '2023-08-24', '2023-10-09', 'OPEN'),
    ('PO-9072', 'V10019', 'M-2004', 396, 2959.69, '2023-02-07', '2023-04-18', 'CLOSED'),
    ('PO-9073', 'V10041', 'M-2003', 267, 3606.41, '2023-08-22', '2023-10-13', 'CLOSED'),
    ('PO-9074', 'V10007', 'M-2004', 171, 2216.14, '2023-07-03', '2023-09-28', 'CLOSED'),
    ('PO-9075', 'V10002', 'M-2003', 474, 3462.03, '2023-05-21', '2023-06-05', 'OPEN'),
    ('PO-9076', 'V10019', 'M-2004', 447, 4094.87, '2023-11-07', '2024-01-05', 'CLOSED'),
    ('PO-9077', 'V10017', 'M-3020', 2740, 315.98, '2023-11-18', '2023-12-07', 'CLOSED'),
    ('PO-9078', 'V10039', 'M-3002', 6477, 367.52, '2023-02-16', '2023-04-08', 'CLOSED'),
    ('PO-9079', 'V10011', 'M-3006', 2665, 394.32, '2023-07-07', '2023-09-26', 'CLOSED'),
    ('PO-9080', 'V10047', 'M-3009', 8394, 483.86, '2023-06-01', '2023-07-28', 'OPEN'),
    ('PO-9081', 'V10011', 'M-3003', 4196, 430.77, '2023-12-12', '2024-02-14', 'CLOSED'),
    ('PO-9082', 'V10001', 'M-3013', 4832, 270.6, '2023-08-21', '2023-10-21', 'CLOSED'),
    ('PO-9083', 'V10007', 'M-3012', 4330, 238.38, '2023-11-14', '2024-02-07', 'CLOSED'),
    ('PO-9084', 'V10042', 'M-2002', 82, 3359.32, '2023-08-26', '2023-10-17', 'CLOSED'),
    ('PO-9085', 'V10004', 'M-3002', 5486, 497.98, '2023-03-01', '2023-03-27', 'CLOSED'),
    ('PO-9086', 'V10025', 'M-2002', 282, 2169.55, '2023-12-23', '2024-03-15', 'CLOSED'),
    ('PO-9087', 'V10027', 'M-3005', 2122, 417.68, '2023-11-12', '2024-01-17', 'CLOSED'),
    ('PO-9088', 'V10014', 'M-3012', 7764, 225.12, '2023-05-01', '2023-06-30', 'OPEN'),
    ('PO-9089', 'V10035', 'M-2003', 380, 2114.03, '2023-07-23', '2023-09-10', 'CLOSED'),
    ('PO-9090', 'V10006', 'M-2004', 389, 1454.48, '2023-11-24', '2024-02-22', 'OPEN'),
    ('PO-9091', 'V10016', 'M-3011', 2563, 394.55, '2023-04-16', '2023-05-08', 'CLOSED'),
    ('PO-9092', 'V10026', 'M-3008', 2917, 395.38, '2023-11-02', '2023-11-16', 'CLOSED'),
    ('PO-9093', 'V10009', 'M-2002', 326, 1627.94, '2023-03-31', '2023-04-28', 'OPEN'),
    ('PO-9094', 'V10016', 'M-3012', 5804, 12.81, '2023-05-16', '2023-06-05', 'CLOSED'),
    ('PO-9095', 'V10008', 'M-3017', 1541, 240.74, '2023-07-05', '2023-09-22', 'OPEN'),
    ('PO-9096', 'V10035', 'M-3008', 1210, 364.99, '2023-12-04', '2024-02-22', 'CLOSED'),
    ('PO-9097', 'V10004', 'M-3001', 8347, 424.41, '2023-08-07', '2023-09-03', 'CLOSED'),
    ('PO-9098', 'V10007', 'M-3015', 1823, 164.45, '2023-03-17', '2023-04-08', 'CLOSED'),
    ('PO-9099', 'V10036', 'M-3019', 5827, 193.55, '2023-11-02', '2024-01-22', 'CLOSED'),
    ('PO-9100', 'V10028', 'M-3020', 2124, 397.58, '2023-02-28', '2023-05-23', 'CLOSED'),
    ('PO-9101', 'V10027', 'M-3008', 6053, 414.57, '2023-07-24', '2023-09-29', 'OPEN'),
    ('PO-9102', 'V10043', 'M-3011', 4676, 190.28, '2023-03-20', '2023-06-02', 'OPEN'),
    ('PO-9103', 'V10006', 'M-3003', 7575, 52.8, '2023-07-10', '2023-08-09', 'OPEN'),
    ('PO-9104', 'V10036', 'M-3018', 5900, 336.66, '2023-07-30', '2023-09-27', 'CLOSED'),
    ('PO-9105', 'V10019', 'M-2001', 357, 1906.02, '2023-02-23', '2023-05-21', 'CLOSED'),
    ('PO-9106', 'V10016', 'M-3016', 2273, 178.31, '2023-10-12', '2023-12-12', 'OPEN'),
    ('PO-9107', 'V10015', 'M-3019', 7530, 423.35, '2023-11-15', '2024-02-08', 'OPEN'),
    ('PO-9108', 'V10003', 'M-3009', 3455, 140.27, '2023-06-08', '2023-08-04', 'CLOSED'),
    ('PO-9109', 'V10037', 'M-3005', 7066, 39.44, '2023-11-21', '2023-12-08', 'OPEN'),
    ('PO-9110', 'V10025', 'M-3007', 7378, 229.55, '2023-03-22', '2023-05-22', 'CLOSED'),
    ('PO-9111', 'V10039', 'M-3019', 1891, 442.25, '2023-03-21', '2023-04-24', 'OPEN'),
    ('PO-9112', 'V10030', 'M-3009', 7447, 245.4, '2023-08-15', '2023-10-21', 'CLOSED'),
    ('PO-9113', 'V10008', 'M-3017', 6155, 217.81, '2023-05-26', '2023-08-23', 'CLOSED'),
    ('PO-9114', 'V10003', 'M-3010', 4112, 200.66, '2023-11-03', '2023-11-24', 'OPEN'),
    ('PO-9115', 'V10050', 'M-3007', 2748, 383.26, '2023-05-29', '2023-07-23', 'OPEN'),
    ('PO-9116', 'V10014', 'M-3014', 2616, 193.2, '2023-12-27', '2024-02-08', 'CLOSED'),
    ('PO-9117', 'V10021', 'M-3002', 807, 232.58, '2023-02-09', '2023-04-04', 'CLOSED'),
    ('PO-9118', 'V10019', 'M-3014', 2387, 205.49, '2023-06-16', '2023-07-21', 'CLOSED'),
    ('PO-9119', 'V10006', 'M-3012', 7655, 423.02, '2023-05-05', '2023-07-13', 'CLOSED'),
    ('PO-9120', 'V10020', 'M-3013', 6062, 114.68, '2023-03-28', '2023-04-20', 'OPEN');

-- ============================================================
-- Section 9: Demo Data - TRADE_DATA (150 rows)
-- ============================================================
INSERT INTO SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.TRADE_DATA (BOL_ID, SHIPPER_NAME, SHIPPER_COUNTRY, CONSIGNEE_NAME, CONSIGNEE_COUNTRY, HS_CODE, HS_DESCRIPTION, SHIP_DATE, WEIGHT_KG, VALUE_USD, PORT_OF_ORIGIN, PORT_OF_DESTINATION) VALUES
    ('BL-88001', 'Jiangxi Graphite Ltd', 'CHN', 'Electronics Corp 42', 'DEU', '3801.10', 'Industrial Materials', '2023-05-01', 11737, 272063.42, 'Port of Shanghai', 'Port of Hamburg'),
    ('BL-88002', 'Pacific Copper Mining', 'CHL', 'Umicore Materials', 'JPN', '7408.11', 'Copper Wire', '2023-04-01', 46153, 2513978.48, 'Port of Antofagasta', 'Port of Yokohama'),
    ('BL-88003', 'Korean Precision Chemicals', 'KOR', 'BASF Materials', 'COD', '3920.10', 'Industrial Materials', '2023-11-18', 25718, 606589.02, 'Port of Busan', 'Port of Dar es Salaam'),
    ('BL-88004', 'Vulcan Materials Refiner', 'CHL', 'EVE Energy', 'KOR', '2825.20', 'Lithium Hydroxide', '2023-05-21', 43759, 658813.22, 'Port of Antofagasta', 'Port of Busan'),
    ('BL-88005', 'Shanghai Battery Materials', 'CHN', 'Renesas Electronics', 'USA', '8507.90', 'Industrial Materials', '2023-01-20', 8728, 376930.76, 'Port of Shanghai', 'Port of Los Angeles'),
    ('BL-88006', 'Congo Cobalt Mines', 'COD', 'Freeport Cobalt', 'COD', '8106.00', 'Cobalt and Cobalt Products', '2023-08-25', 43032, 2577120.79, 'Port of Dar es Salaam', 'Port of Dar es Salaam'),
    ('BL-88007', 'Queensland Minerals', 'AUS', 'BYD Battery', 'KOR', '2825.20', 'Lithium Hydroxide', '2023-11-06', 36170, 1993800.98, 'Port of Fremantle', 'Port of Busan'),
    ('BL-88008', 'Queensland Minerals', 'AUS', 'LG Energy Solution', 'CHN', '2836.91', 'Lithium Carbonate', '2023-09-16', 47344, 1208706.62, 'Port of Fremantle', 'Port of Shanghai'),
    ('BL-88009', 'Pacific Copper Mining', 'CHL', 'BASF Materials', 'COD', '7408.11', 'Copper Wire', '2023-07-06', 29435, 2726102.24, 'Port of Antofagasta', 'Port of Dar es Salaam'),
    ('BL-88010', 'Tokyo Chemical Works', 'JPN', 'Svolt Energy', 'KOR', '2826.19', 'Industrial Materials', '2023-11-20', 47421, 1902456.6, 'Port of Yokohama', 'Port of Busan'),
    ('BL-88011', 'Jiangxi Graphite Ltd', 'CHN', 'Materials Corp 44', 'CHL', '3801.10', 'Industrial Materials', '2023-05-26', 21514, 1616476.53, 'Port of Shanghai', 'Port of Antofagasta'),
    ('BL-88012', 'Korean Precision Chemicals', 'KOR', 'Svolt Energy', 'KOR', '3920.10', 'Industrial Materials', '2023-10-26', 48490, 1102107.6, 'Port of Busan', 'Port of Busan'),
    ('BL-88013', 'Jiangxi Graphite Ltd', 'CHN', 'Electronics Corp 42', 'DEU', '3801.10', 'Industrial Materials', '2023-03-08', 43996, 3246687.52, 'Port of Shanghai', 'Port of Hamburg'),
    ('BL-88014', 'Vulcan Materials Refiner', 'CHL', 'Infineon Technologies', 'USA', '2825.20', 'Lithium Hydroxide', '2023-03-07', 48916, 3583330.74, 'Port of Antofagasta', 'Port of Los Angeles'),
    ('BL-88015', 'Shanghai Battery Materials', 'CHN', 'Delta Materials', 'CHN', '8507.90', 'Industrial Materials', '2023-09-18', 28712, 334229.17, 'Port of Shanghai', 'Port of Shanghai'),
    ('BL-88016', 'Congo Cobalt Mines', 'COD', 'Zeta Precision', 'DEU', '8106.00', 'Cobalt and Cobalt Products', '2023-09-06', 17583, 534327.57, 'Port of Dar es Salaam', 'Port of Hamburg'),
    ('BL-88017', 'Atacama Mining Corp', 'CHL', 'Gotion High-Tech', 'KOR', '2836.91', 'Lithium Carbonate', '2023-09-17', 40374, 3438281.51, 'Port of Antofagasta', 'Port of Busan'),
    ('BL-88018', 'Shanghai Battery Materials', 'CHN', 'Svolt Energy', 'KOR', '8507.90', 'Industrial Materials', '2023-11-02', 29688, 709031.04, 'Port of Shanghai', 'Port of Busan'),
    ('BL-88019', 'Atacama Mining Corp', 'CHL', 'Materials Corp 50', 'COD', '2836.91', 'Lithium Carbonate', '2023-08-13', 7863, 369382.31, 'Port of Antofagasta', 'Port of Dar es Salaam'),
    ('BL-88020', 'Pacific Copper Mining', 'CHL', 'Materials Corp 40', 'MEX', '7409.11', 'Copper Plates', '2023-08-18', 20335, 1180670.51, 'Port of Antofagasta', 'Port of Manzanillo'),
    ('BL-88021', 'Congo Cobalt Mines', 'COD', '3M Advanced Materials', 'MEX', '8106.00', 'Cobalt and Cobalt Products', '2023-07-08', 49453, 4709988.55, 'Port of Dar es Salaam', 'Port of Manzanillo'),
    ('BL-88022', 'Bavaria Specialty Metals', 'DEU', 'Gotion High-Tech', 'KOR', '7502.10', 'Industrial Materials', '2023-09-15', 39567, 1886533.76, 'Port of Hamburg', 'Port of Busan'),
    ('BL-88023', 'Atacama Mining Corp', 'CHL', 'LG Energy Solution', 'CHN', '2836.91', 'Lithium Carbonate', '2023-05-09', 8419, 570017.77, 'Port of Antofagasta', 'Port of Shanghai'),
    ('BL-88024', 'Jiangxi Graphite Ltd', 'CHN', 'Alpha Industries', 'DEU', '3801.10', 'Industrial Materials', '2023-05-26', 10496, 825830.68, 'Port of Shanghai', 'Port of Hamburg'),
    ('BL-88025', 'Congo Cobalt Mines', 'COD', 'Materials Corp 33', 'COD', '8106.00', 'Cobalt and Cobalt Products', '2023-08-12', 11010, 1047900.9, 'Port of Dar es Salaam', 'Port of Dar es Salaam'),
    ('BL-88026', 'Pacific Copper Mining', 'CHL', 'Texas Instruments', 'DEU', '7408.11', 'Copper Wire', '2023-08-01', 8490, 387830.48, 'Port of Antofagasta', 'Port of Hamburg'),
    ('BL-88027', 'Jiangxi Graphite Ltd', 'CHN', 'Freeport Cobalt', 'COD', '3801.10', 'Industrial Materials', '2023-04-25', 6847, 264853.18, 'Port of Shanghai', 'Port of Dar es Salaam'),
    ('BL-88028', 'Vulcan Materials Refiner', 'CHL', 'Electronics Corp 42', 'DEU', '2825.20', 'Lithium Hydroxide', '2023-03-16', 14017, 188490.62, 'Port of Antofagasta', 'Port of Hamburg'),
    ('BL-88029', 'Bavaria Specialty Metals', 'DEU', 'Codelco', 'MEX', '7502.10', 'Industrial Materials', '2023-08-18', 45327, 474691.9, 'Port of Hamburg', 'Port of Manzanillo'),
    ('BL-88030', 'Vulcan Materials Refiner', 'CHL', 'Svolt Energy', 'KOR', '2836.91', 'Lithium Carbonate', '2023-10-08', 44903, 2581897.15, 'Port of Antofagasta', 'Port of Busan'),
    ('BL-88031', 'Vulcan Materials Refiner', 'CHL', 'STMicroelectronics', 'USA', '2825.20', 'Lithium Hydroxide', '2023-03-04', 8129, 255734.73, 'Port of Antofagasta', 'Port of Los Angeles'),
    ('BL-88032', 'Korean Precision Chemicals', 'KOR', 'NXP Semiconductors', 'USA', '3920.10', 'Industrial Materials', '2023-11-02', 40130, 460659.56, 'Port of Busan', 'Port of Los Angeles'),
    ('BL-88033', 'Shanghai Battery Materials', 'CHN', 'Sigma Lithium', 'CHL', '8507.90', 'Industrial Materials', '2023-05-30', 33130, 335964.38, 'Port of Shanghai', 'Port of Antofagasta'),
    ('BL-88034', 'Jiangxi Graphite Ltd', 'CHN', 'Ganfeng Lithium', 'CHL', '3801.10', 'Industrial Materials', '2023-12-07', 48792, 863874.85, 'Port of Shanghai', 'Port of Antofagasta'),
    ('BL-88035', 'Jiangxi Graphite Ltd', 'CHN', 'Albemarle Corp', 'AUS', '3801.10', 'Industrial Materials', '2023-07-19', 35810, 498407.1, 'Port of Shanghai', 'Port of Fremantle'),
    ('BL-88036', 'Tokyo Chemical Works', 'JPN', 'Southern Copper', 'CHN', '2826.19', 'Industrial Materials', '2023-07-02', 9427, 386810.78, 'Port of Yokohama', 'Port of Shanghai'),
    ('BL-88037', 'Vulcan Materials Refiner', 'CHL', 'SK On', 'KOR', '2825.20', 'Lithium Hydroxide', '2023-03-10', 7905, 329693.16, 'Port of Antofagasta', 'Port of Busan'),
    ('BL-88038', 'Jiangxi Graphite Ltd', 'CHN', 'Theta Systems', 'CHN', '3801.10', 'Industrial Materials', '2023-12-23', 36361, 2430959.24, 'Port of Shanghai', 'Port of Shanghai'),
    ('BL-88039', 'Atacama Mining Corp', 'CHL', 'SK On', 'KOR', '2825.20', 'Lithium Hydroxide', '2023-01-19', 24231, 681937.62, 'Port of Antofagasta', 'Port of Busan'),
    ('BL-88040', 'Pacific Copper Mining', 'CHL', 'Epsilon Tech', 'AUS', '7409.11', 'Copper Plates', '2023-09-21', 31098, 3079356.4, 'Port of Antofagasta', 'Port of Fremantle'),
    ('BL-88041', 'Shanghai Battery Materials', 'CHN', 'First Quantum', 'USA', '8507.90', 'Industrial Materials', '2023-05-27', 28394, 2487100.53, 'Port of Shanghai', 'Port of Los Angeles'),
    ('BL-88042', 'Queensland Minerals', 'AUS', 'Svolt Energy', 'KOR', '2825.20', 'Lithium Hydroxide', '2023-03-05', 29118, 1436263.53, 'Port of Fremantle', 'Port of Busan'),
    ('BL-88043', 'Tokyo Chemical Works', 'JPN', 'Infineon Technologies', 'USA', '2826.19', 'Industrial Materials', '2023-04-06', 37519, 2712104.59, 'Port of Yokohama', 'Port of Los Angeles'),
    ('BL-88044', 'Jiangxi Graphite Ltd', 'CHN', 'Albemarle Corp', 'AUS', '3801.10', 'Industrial Materials', '2023-02-12', 32820, 561334.59, 'Port of Shanghai', 'Port of Fremantle'),
    ('BL-88045', 'Korean Precision Chemicals', 'KOR', 'Theta Systems', 'CHN', '3920.10', 'Industrial Materials', '2023-06-14', 11723, 201708.31, 'Port of Busan', 'Port of Shanghai'),
    ('BL-88046', 'Congo Cobalt Mines', 'COD', 'LG Energy Solution', 'CHN', '8106.00', 'Cobalt and Cobalt Products', '2023-03-27', 34091, 1419522.94, 'Port of Dar es Salaam', 'Port of Shanghai'),
    ('BL-88047', 'Queensland Minerals', 'AUS', 'LG Energy Solution', 'CHN', '2825.20', 'Lithium Hydroxide', '2023-05-21', 46908, 4606480.77, 'Port of Fremantle', 'Port of Shanghai'),
    ('BL-88048', 'Queensland Minerals', 'AUS', 'SK On', 'KOR', '2825.20', 'Lithium Hydroxide', '2023-09-20', 49525, 1208350.84, 'Port of Fremantle', 'Port of Busan'),
    ('BL-88049', 'Queensland Minerals', 'AUS', 'SK On', 'KOR', '2836.91', 'Lithium Carbonate', '2023-03-06', 9406, 293839.53, 'Port of Fremantle', 'Port of Busan'),
    ('BL-88050', 'Jiangxi Graphite Ltd', 'CHN', 'Panasonic Energy', 'KOR', '3801.10', 'Industrial Materials', '2023-11-06', 15055, 1070645.13, 'Port of Shanghai', 'Port of Busan'),
    ('BL-88051', 'Jiangxi Graphite Ltd', 'CHN', 'Generic Corp 49', 'KOR', '3801.10', 'Industrial Materials', '2023-10-21', 14023, 808445.43, 'Port of Shanghai', 'Port of Busan'),
    ('BL-88052', 'Tokyo Chemical Works', 'JPN', 'Beta Components', 'DEU', '2826.19', 'Industrial Materials', '2023-02-28', 6698, 510459.52, 'Port of Yokohama', 'Port of Hamburg'),
    ('BL-88053', 'Bavaria Specialty Metals', 'DEU', 'Materials Corp 36', 'JPN', '7502.10', 'Industrial Materials', '2023-05-15', 22058, 1618249.94, 'Port of Hamburg', 'Port of Yokohama'),
    ('BL-88054', 'Pacific Copper Mining', 'CHL', 'Gotion High-Tech', 'KOR', '7409.11', 'Copper Plates', '2023-04-13', 13037, 289624.22, 'Port of Antofagasta', 'Port of Busan'),
    ('BL-88055', 'Vulcan Materials Refiner', 'CHL', 'Sigma Lithium', 'CHL', '2825.20', 'Lithium Hydroxide', '2023-02-14', 49690, 4823930.61, 'Port of Antofagasta', 'Port of Antofagasta'),
    ('BL-88056', 'Jiangxi Graphite Ltd', 'CHN', 'Sigma Lithium', 'CHL', '3801.10', 'Industrial Materials', '2023-10-09', 40531, 1464490.63, 'Port of Shanghai', 'Port of Antofagasta'),
    ('BL-88057', 'Congo Cobalt Mines', 'COD', 'Sigma Lithium', 'CHL', '8106.00', 'Cobalt and Cobalt Products', '2023-07-05', 38341, 1157198.3, 'Port of Dar es Salaam', 'Port of Antofagasta'),
    ('BL-88058', 'Pacific Copper Mining', 'CHL', 'STMicroelectronics', 'USA', '7409.11', 'Copper Plates', '2023-01-14', 28651, 1715104.14, 'Port of Antofagasta', 'Port of Los Angeles'),
    ('BL-88059', 'Jiangxi Graphite Ltd', 'CHN', 'Materials Corp 36', 'JPN', '3801.10', 'Industrial Materials', '2023-11-10', 10650, 169519.56, 'Port of Shanghai', 'Port of Yokohama'),
    ('BL-88060', 'Tokyo Chemical Works', 'JPN', 'SQM Mining', 'CHL', '2826.19', 'Industrial Materials', '2023-09-27', 31921, 2528935.15, 'Port of Yokohama', 'Port of Antofagasta'),
    ('BL-88061', 'Korean Precision Chemicals', 'KOR', 'Epsilon Tech', 'AUS', '3920.10', 'Industrial Materials', '2023-08-19', 35528, 2529942.1, 'Port of Busan', 'Port of Fremantle'),
    ('BL-88062', 'Jiangxi Graphite Ltd', 'CHN', 'Materials Corp 50', 'COD', '3801.10', 'Industrial Materials', '2023-03-08', 33352, 1842956.17, 'Port of Shanghai', 'Port of Dar es Salaam'),
    ('BL-88063', 'Queensland Minerals', 'AUS', 'BYD Battery', 'KOR', '2825.20', 'Lithium Hydroxide', '2023-03-26', 15614, 609562.25, 'Port of Fremantle', 'Port of Busan'),
    ('BL-88064', 'Pacific Copper Mining', 'CHL', 'Albemarle Corp', 'AUS', '7409.11', 'Copper Plates', '2023-02-10', 21423, 592713.84, 'Port of Antofagasta', 'Port of Fremantle'),
    ('BL-88065', 'Shanghai Battery Materials', 'CHN', 'EVE Energy', 'KOR', '8507.90', 'Industrial Materials', '2023-11-11', 39962, 735642.74, 'Port of Shanghai', 'Port of Busan'),
    ('BL-88066', 'Atacama Mining Corp', 'CHL', 'Copper Corp 38', 'USA', '2836.91', 'Lithium Carbonate', '2023-03-29', 48170, 3189004.62, 'Port of Antofagasta', 'Port of Los Angeles'),
    ('BL-88067', 'Korean Precision Chemicals', 'KOR', 'Panasonic Energy', 'KOR', '3920.10', 'Industrial Materials', '2023-01-15', 10323, 145467.2, 'Port of Busan', 'Port of Busan'),
    ('BL-88068', 'Korean Precision Chemicals', 'KOR', 'Zeta Precision', 'DEU', '3920.10', 'Industrial Materials', '2023-11-13', 46876, 596531.36, 'Port of Busan', 'Port of Hamburg'),
    ('BL-88069', 'Shanghai Battery Materials', 'CHN', 'Mitsubishi Chemical', 'CHN', '8507.90', 'Industrial Materials', '2023-05-06', 49891, 2322342.6, 'Port of Shanghai', 'Port of Shanghai'),
    ('BL-88070', 'Bavaria Specialty Metals', 'DEU', 'Gamma Manufacturing', 'CHN', '7502.10', 'Industrial Materials', '2023-08-14', 32238, 1727395.91, 'Port of Hamburg', 'Port of Shanghai'),
    ('BL-88071', 'Pacific Copper Mining', 'CHL', 'Umicore Materials', 'JPN', '7409.11', 'Copper Plates', '2023-06-13', 27634, 2702153.98, 'Port of Antofagasta', 'Port of Yokohama'),
    ('BL-88072', 'Atacama Mining Corp', 'CHL', 'Materials Corp 33', 'COD', '2836.91', 'Lithium Carbonate', '2023-06-13', 20842, 1083419.91, 'Port of Antofagasta', 'Port of Dar es Salaam'),
    ('BL-88073', 'Congo Cobalt Mines', 'COD', 'Umicore Materials', 'JPN', '8106.00', 'Cobalt and Cobalt Products', '2023-01-26', 24019, 2283837.98, 'Port of Dar es Salaam', 'Port of Yokohama'),
    ('BL-88074', 'Korean Precision Chemicals', 'KOR', 'CALB', 'CHN', '3920.10', 'Industrial Materials', '2023-10-23', 25494, 690506.75, 'Port of Busan', 'Port of Shanghai'),
    ('BL-88075', 'Atacama Mining Corp', 'CHL', 'Materials Corp 33', 'COD', '2825.20', 'Lithium Hydroxide', '2023-09-13', 25220, 1381131.05, 'Port of Antofagasta', 'Port of Dar es Salaam'),
    ('BL-88076', 'Vulcan Materials Refiner', 'CHL', 'Materials Corp 33', 'COD', '2825.20', 'Lithium Hydroxide', '2023-05-04', 19099, 1193706.03, 'Port of Antofagasta', 'Port of Dar es Salaam'),
    ('BL-88077', 'Queensland Minerals', 'AUS', 'SK On', 'KOR', '2825.20', 'Lithium Hydroxide', '2023-05-27', 40172, 431285.25, 'Port of Fremantle', 'Port of Busan'),
    ('BL-88078', 'Vulcan Materials Refiner', 'CHL', 'Southern Copper', 'CHN', '2825.20', 'Lithium Hydroxide', '2023-07-26', 28982, 407829.36, 'Port of Antofagasta', 'Port of Shanghai'),
    ('BL-88079', 'Queensland Minerals', 'AUS', 'BYD Battery', 'KOR', '2825.20', 'Lithium Hydroxide', '2023-10-11', 23913, 397382.83, 'Port of Fremantle', 'Port of Busan'),
    ('BL-88080', 'Shanghai Battery Materials', 'CHN', 'Materials Corp 36', 'JPN', '8507.90', 'Industrial Materials', '2023-11-16', 49590, 3223046.64, 'Port of Shanghai', 'Port of Yokohama'),
    ('BL-88081', 'Atacama Mining Corp', 'CHL', 'Copper Corp 26', 'USA', '2825.20', 'Lithium Hydroxide', '2023-06-23', 41558, 3927454.21, 'Port of Antofagasta', 'Port of Los Angeles'),
    ('BL-88082', 'Atacama Mining Corp', 'CHL', 'Materials Corp 33', 'COD', '2825.20', 'Lithium Hydroxide', '2023-09-14', 7638, 107522.43, 'Port of Antofagasta', 'Port of Dar es Salaam'),
    ('BL-88083', 'Atacama Mining Corp', 'CHL', '3M Advanced Materials', 'MEX', '2825.20', 'Lithium Hydroxide', '2023-03-18', 44731, 4042870.63, 'Port of Antofagasta', 'Port of Manzanillo'),
    ('BL-88084', 'Atacama Mining Corp', 'CHL', 'Materials Corp 40', 'MEX', '2825.20', 'Lithium Hydroxide', '2023-03-25', 30752, 3049227.36, 'Port of Antofagasta', 'Port of Manzanillo'),
    ('BL-88085', 'Congo Cobalt Mines', 'COD', 'Materials Corp 33', 'COD', '8106.00', 'Cobalt and Cobalt Products', '2023-12-29', 41891, 1549177.39, 'Port of Dar es Salaam', 'Port of Dar es Salaam'),
    ('BL-88086', 'Queensland Minerals', 'AUS', 'Svolt Energy', 'KOR', '2825.20', 'Lithium Hydroxide', '2023-10-26', 25163, 2056016.72, 'Port of Fremantle', 'Port of Busan'),
    ('BL-88087', 'Queensland Minerals', 'AUS', 'LG Energy Solution', 'CHN', '2836.91', 'Lithium Carbonate', '2023-01-27', 43241, 2302167.73, 'Port of Fremantle', 'Port of Shanghai'),
    ('BL-88088', 'Shanghai Battery Materials', 'CHN', 'Materials Corp 40', 'MEX', '8507.90', 'Industrial Materials', '2023-03-17', 49612, 1577547.02, 'Port of Shanghai', 'Port of Manzanillo'),
    ('BL-88089', 'Korean Precision Chemicals', 'KOR', 'NXP Semiconductors', 'USA', '3920.10', 'Industrial Materials', '2023-01-10', 33903, 1296190.46, 'Port of Busan', 'Port of Los Angeles'),
    ('BL-88090', 'Atacama Mining Corp', 'CHL', 'Zeta Precision', 'DEU', '2825.20', 'Lithium Hydroxide', '2023-09-14', 45073, 4184887.67, 'Port of Antofagasta', 'Port of Hamburg'),
    ('BL-88091', 'Queensland Minerals', 'AUS', 'BYD Battery', 'KOR', '2825.20', 'Lithium Hydroxide', '2023-12-06', 36350, 2082598.5, 'Port of Fremantle', 'Port of Busan'),
    ('BL-88092', 'Jiangxi Graphite Ltd', 'CHN', 'Renesas Electronics', 'USA', '3801.10', 'Industrial Materials', '2023-10-07', 28218, 1998629.35, 'Port of Shanghai', 'Port of Los Angeles'),
    ('BL-88093', 'Congo Cobalt Mines', 'COD', 'Samsung SDI Co.', 'CHN', '8106.00', 'Cobalt and Cobalt Products', '2023-05-23', 41574, 1532622.37, 'Port of Dar es Salaam', 'Port of Shanghai'),
    ('BL-88094', 'Congo Cobalt Mines', 'COD', 'Sigma Lithium', 'CHL', '8106.00', 'Cobalt and Cobalt Products', '2023-12-20', 37047, 1427556.76, 'Port of Dar es Salaam', 'Port of Antofagasta'),
    ('BL-88095', 'Jiangxi Graphite Ltd', 'CHN', 'SQM Mining', 'CHL', '3801.10', 'Industrial Materials', '2023-05-28', 12987, 800166.89, 'Port of Shanghai', 'Port of Antofagasta'),
    ('BL-88096', 'Shanghai Battery Materials', 'CHN', 'Copper Corp 26', 'USA', '8507.90', 'Industrial Materials', '2023-03-16', 24035, 331346.12, 'Port of Shanghai', 'Port of Los Angeles'),
    ('BL-88097', 'Vulcan Materials Refiner', 'CHL', 'BASF Materials', 'COD', '2825.20', 'Lithium Hydroxide', '2023-09-03', 19023, 536184.57, 'Port of Antofagasta', 'Port of Dar es Salaam'),
    ('BL-88098', 'Shanghai Battery Materials', 'CHN', 'Materials Corp 36', 'JPN', '8507.90', 'Industrial Materials', '2023-03-12', 12158, 795266.12, 'Port of Shanghai', 'Port of Yokohama'),
    ('BL-88099', 'Korean Precision Chemicals', 'KOR', 'Gamma Manufacturing', 'CHN', '3920.10', 'Industrial Materials', '2023-11-23', 20259, 298297.56, 'Port of Busan', 'Port of Shanghai'),
    ('BL-88100', 'Tokyo Chemical Works', 'JPN', '3M Advanced Materials', 'MEX', '2826.19', 'Industrial Materials', '2023-12-15', 14009, 146622.82, 'Port of Yokohama', 'Port of Manzanillo'),
    ('BL-88101', 'Shanghai Battery Materials', 'CHN', 'CALB', 'CHN', '8507.90', 'Industrial Materials', '2023-12-01', 36175, 1916203.02, 'Port of Shanghai', 'Port of Shanghai'),
    ('BL-88102', 'Pacific Copper Mining', 'CHL', 'Gotion High-Tech', 'KOR', '7409.11', 'Copper Plates', '2023-05-27', 47329, 725299.54, 'Port of Antofagasta', 'Port of Busan'),
    ('BL-88103', 'Vulcan Materials Refiner', 'CHL', 'DuPont Electronics', 'USA', '2836.91', 'Lithium Carbonate', '2023-03-31', 32386, 2895374.71, 'Port of Antofagasta', 'Port of Los Angeles'),
    ('BL-88104', 'Atacama Mining Corp', 'CHL', 'First Quantum', 'USA', '2825.20', 'Lithium Hydroxide', '2023-09-11', 17210, 1622813.28, 'Port of Antofagasta', 'Port of Los Angeles'),
    ('BL-88105', 'Congo Cobalt Mines', 'COD', 'BHP Copper', 'MEX', '8106.00', 'Cobalt and Cobalt Products', '2023-10-18', 44503, 874798.24, 'Port of Dar es Salaam', 'Port of Manzanillo'),
    ('BL-88106', 'Jiangxi Graphite Ltd', 'CHN', 'Electronics Corp 42', 'DEU', '3801.10', 'Industrial Materials', '2023-03-10', 38044, 1982924.39, 'Port of Shanghai', 'Port of Hamburg'),
    ('BL-88107', 'Pacific Copper Mining', 'CHL', 'Svolt Energy', 'KOR', '7408.11', 'Copper Wire', '2023-08-23', 47486, 1574343.21, 'Port of Antofagasta', 'Port of Busan'),
    ('BL-88108', 'Atacama Mining Corp', 'CHL', 'BYD Battery', 'KOR', '2825.20', 'Lithium Hydroxide', '2023-10-18', 49197, 3845013.55, 'Port of Antofagasta', 'Port of Busan'),
    ('BL-88109', 'Atacama Mining Corp', 'CHL', 'EVE Energy', 'KOR', '2825.20', 'Lithium Hydroxide', '2023-08-07', 38769, 1531894.98, 'Port of Antofagasta', 'Port of Busan'),
    ('BL-88110', 'Tokyo Chemical Works', 'JPN', 'Theta Systems', 'CHN', '2826.19', 'Industrial Materials', '2023-09-02', 26207, 2469335.83, 'Port of Yokohama', 'Port of Shanghai'),
    ('BL-88111', 'Queensland Minerals', 'AUS', 'BYD Battery', 'KOR', '2825.20', 'Lithium Hydroxide', '2023-05-17', 26602, 988932.69, 'Port of Fremantle', 'Port of Busan'),
    ('BL-88112', 'Korean Precision Chemicals', 'KOR', 'Electronics Corp 42', 'DEU', '3920.10', 'Industrial Materials', '2023-12-21', 20486, 319401.12, 'Port of Busan', 'Port of Hamburg'),
    ('BL-88113', 'Vulcan Materials Refiner', 'CHL', 'CALB', 'CHN', '2825.20', 'Lithium Hydroxide', '2023-12-18', 37933, 3530786.24, 'Port of Antofagasta', 'Port of Shanghai'),
    ('BL-88114', 'Congo Cobalt Mines', 'COD', 'EVE Energy', 'KOR', '8106.00', 'Cobalt and Cobalt Products', '2023-07-08', 45280, 1352804.82, 'Port of Dar es Salaam', 'Port of Busan'),
    ('BL-88115', 'Atacama Mining Corp', 'CHL', 'Renesas Electronics', 'USA', '2825.20', 'Lithium Hydroxide', '2023-08-01', 40994, 3777667.61, 'Port of Antofagasta', 'Port of Los Angeles'),
    ('BL-88116', 'Shanghai Battery Materials', 'CHN', 'Zeta Precision', 'DEU', '8507.90', 'Industrial Materials', '2023-12-15', 44047, 3901778.19, 'Port of Shanghai', 'Port of Hamburg'),
    ('BL-88117', 'Vulcan Materials Refiner', 'CHL', 'Albemarle Corp', 'AUS', '2825.20', 'Lithium Hydroxide', '2023-02-09', 41973, 843606.56, 'Port of Antofagasta', 'Port of Fremantle'),
    ('BL-88118', 'Shanghai Battery Materials', 'CHN', 'Samsung SDI Co.', 'CHN', '8507.90', 'Industrial Materials', '2023-03-26', 26503, 2303209.84, 'Port of Shanghai', 'Port of Shanghai'),
    ('BL-88119', 'Bavaria Specialty Metals', 'DEU', 'Zeta Precision', 'DEU', '7502.10', 'Industrial Materials', '2023-02-16', 38447, 1925942.58, 'Port of Hamburg', 'Port of Hamburg'),
    ('BL-88120', 'Queensland Minerals', 'AUS', 'SK On', 'KOR', '2825.20', 'Lithium Hydroxide', '2023-10-16', 8783, 529542.42, 'Port of Fremantle', 'Port of Busan'),
    ('BL-88121', 'Congo Cobalt Mines', 'COD', 'Copper Corp 26', 'USA', '8106.00', 'Cobalt and Cobalt Products', '2023-01-02', 19280, 1196285.71, 'Port of Dar es Salaam', 'Port of Los Angeles'),
    ('BL-88122', 'Queensland Minerals', 'AUS', 'Svolt Energy', 'KOR', '2836.91', 'Lithium Carbonate', '2023-02-05', 35937, 462011.05, 'Port of Fremantle', 'Port of Busan'),
    ('BL-88123', 'Tokyo Chemical Works', 'JPN', 'Codelco', 'MEX', '2826.19', 'Industrial Materials', '2023-07-11', 30066, 1514374.57, 'Port of Yokohama', 'Port of Manzanillo'),
    ('BL-88124', 'Tokyo Chemical Works', 'JPN', 'Materials Corp 44', 'CHL', '2826.19', 'Industrial Materials', '2023-12-01', 27791, 574634.09, 'Port of Yokohama', 'Port of Antofagasta'),
    ('BL-88125', 'Shanghai Battery Materials', 'CHN', 'Codelco', 'MEX', '8507.90', 'Industrial Materials', '2023-01-02', 6489, 636338.34, 'Port of Shanghai', 'Port of Manzanillo'),
    ('BL-88126', 'Bavaria Specialty Metals', 'DEU', 'Materials Corp 35', 'USA', '7502.10', 'Industrial Materials', '2023-09-30', 29856, 2510962.43, 'Port of Hamburg', 'Port of Los Angeles'),
    ('BL-88127', 'Pacific Copper Mining', 'CHL', 'Umicore Materials', 'JPN', '7409.11', 'Copper Plates', '2023-04-07', 12395, 159890.03, 'Port of Antofagasta', 'Port of Yokohama'),
    ('BL-88128', 'Tokyo Chemical Works', 'JPN', 'Antofagasta PLC', 'MEX', '2826.19', 'Industrial Materials', '2023-04-16', 9409, 179530.35, 'Port of Yokohama', 'Port of Manzanillo'),
    ('BL-88129', 'Queensland Minerals', 'AUS', 'Svolt Energy', 'KOR', '2836.91', 'Lithium Carbonate', '2023-01-23', 31362, 1552627.65, 'Port of Fremantle', 'Port of Busan'),
    ('BL-88130', 'Shanghai Battery Materials', 'CHN', 'Materials Corp 50', 'COD', '8507.90', 'Industrial Materials', '2023-03-13', 38023, 3779999.88, 'Port of Shanghai', 'Port of Dar es Salaam'),
    ('BL-88131', 'Pacific Copper Mining', 'CHL', 'SQM Mining', 'CHL', '7409.11', 'Copper Plates', '2023-10-23', 44185, 3513964.08, 'Port of Antofagasta', 'Port of Antofagasta'),
    ('BL-88132', 'Jiangxi Graphite Ltd', 'CHN', 'Umicore Materials', 'JPN', '3801.10', 'Industrial Materials', '2023-07-31', 24693, 858423.82, 'Port of Shanghai', 'Port of Yokohama'),
    ('BL-88133', 'Shanghai Battery Materials', 'CHN', 'SK On', 'KOR', '8507.90', 'Industrial Materials', '2023-11-17', 49482, 2397306.53, 'Port of Shanghai', 'Port of Busan'),
    ('BL-88134', 'Bavaria Specialty Metals', 'DEU', 'Texas Instruments', 'DEU', '7502.10', 'Industrial Materials', '2023-09-26', 25888, 1881222.88, 'Port of Hamburg', 'Port of Hamburg'),
    ('BL-88135', 'Tokyo Chemical Works', 'JPN', 'Infineon Technologies', 'USA', '2826.19', 'Industrial Materials', '2023-10-03', 36032, 1141750.92, 'Port of Yokohama', 'Port of Los Angeles'),
    ('BL-88136', 'Pacific Copper Mining', 'CHL', 'Sigma Lithium', 'CHL', '7408.11', 'Copper Wire', '2023-08-26', 8776, 531954.92, 'Port of Antofagasta', 'Port of Antofagasta'),
    ('BL-88137', 'Tokyo Chemical Works', 'JPN', 'Codelco', 'MEX', '2826.19', 'Industrial Materials', '2023-05-05', 21711, 614427.94, 'Port of Yokohama', 'Port of Manzanillo'),
    ('BL-88138', 'Vulcan Materials Refiner', 'CHL', 'BYD Battery', 'KOR', '2836.91', 'Lithium Carbonate', '2023-10-02', 17483, 255921.34, 'Port of Antofagasta', 'Port of Busan'),
    ('BL-88139', 'Tokyo Chemical Works', 'JPN', 'LG Energy Solution', 'CHN', '2826.19', 'Industrial Materials', '2023-02-07', 17331, 1428395.99, 'Port of Yokohama', 'Port of Shanghai'),
    ('BL-88140', 'Korean Precision Chemicals', 'KOR', 'Materials Corp 36', 'JPN', '3920.10', 'Industrial Materials', '2023-09-03', 18689, 1649353.71, 'Port of Busan', 'Port of Yokohama'),
    ('BL-88141', 'Jiangxi Graphite Ltd', 'CHN', 'BHP Copper', 'MEX', '3801.10', 'Industrial Materials', '2023-04-08', 12688, 979756.33, 'Port of Shanghai', 'Port of Manzanillo'),
    ('BL-88142', 'Bavaria Specialty Metals', 'DEU', 'Copper Corp 45', 'USA', '7502.10', 'Industrial Materials', '2023-07-23', 20684, 1234568.73, 'Port of Hamburg', 'Port of Los Angeles'),
    ('BL-88143', 'Congo Cobalt Mines', 'COD', 'Materials Corp 35', 'USA', '8106.00', 'Cobalt and Cobalt Products', '2023-06-07', 22141, 938070.23, 'Port of Dar es Salaam', 'Port of Los Angeles'),
    ('BL-88144', 'Bavaria Specialty Metals', 'DEU', 'SQM Mining', 'CHL', '7502.10', 'Industrial Materials', '2023-06-13', 18312, 794071.37, 'Port of Hamburg', 'Port of Antofagasta'),
    ('BL-88145', 'Tokyo Chemical Works', 'JPN', 'DuPont Electronics', 'USA', '2826.19', 'Industrial Materials', '2023-01-09', 22090, 1320938.72, 'Port of Yokohama', 'Port of Los Angeles'),
    ('BL-88146', 'Korean Precision Chemicals', 'KOR', 'Ganfeng Lithium', 'CHL', '3920.10', 'Industrial Materials', '2023-03-20', 17857, 708706.4, 'Port of Busan', 'Port of Antofagasta'),
    ('BL-88147', 'Tokyo Chemical Works', 'JPN', 'STMicroelectronics', 'USA', '2826.19', 'Industrial Materials', '2023-10-09', 47900, 4546275.65, 'Port of Yokohama', 'Port of Los Angeles'),
    ('BL-88148', 'Jiangxi Graphite Ltd', 'CHN', 'ON Semiconductor', 'USA', '3801.10', 'Industrial Materials', '2023-08-24', 16025, 1217090.76, 'Port of Shanghai', 'Port of Los Angeles'),
    ('BL-88149', 'Jiangxi Graphite Ltd', 'CHN', 'SQM Mining', 'CHL', '3801.10', 'Industrial Materials', '2023-04-05', 40529, 4017604.05, 'Port of Shanghai', 'Port of Antofagasta'),
    ('BL-88150', 'Queensland Minerals', 'AUS', 'Svolt Energy', 'KOR', '2836.91', 'Lithium Carbonate', '2023-01-04', 32026, 716557.34, 'Port of Fremantle', 'Port of Busan');

-- ============================================================
-- Section 10: Analytics Views
-- ============================================================
CREATE OR REPLACE VIEW SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VW_SUPPLIER_RISK AS
SELECT
    v.VENDOR_ID,
    v.NAME AS VENDOR_NAME,
    v.COUNTRY_CODE,
    v.TIER,
    r.BASE_RISK_SCORE AS REGION_RISK,
    rs.RISK_SCORE AS GNN_RISK_SCORE,
    rs.RISK_CATEGORY,
    rs.CONFIDENCE,
    COALESCE(po_stats.TOTAL_ORDERS, 0) AS TOTAL_ORDERS,
    COALESCE(po_stats.TOTAL_VALUE, 0) AS TOTAL_ORDER_VALUE
FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VENDORS v
LEFT JOIN SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.REGIONS r ON v.COUNTRY_CODE = r.REGION_CODE
LEFT JOIN SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RISK_SCORES rs
    ON v.VENDOR_ID = rs.NODE_ID AND rs.NODE_TYPE = 'SUPPLIER'
LEFT JOIN (
    SELECT VENDOR_ID, COUNT(*) AS TOTAL_ORDERS, SUM(QUANTITY * UNIT_PRICE) AS TOTAL_VALUE
    FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.PURCHASE_ORDERS
    GROUP BY VENDOR_ID
) po_stats ON v.VENDOR_ID = po_stats.VENDOR_ID;

CREATE OR REPLACE VIEW SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VW_MATERIAL_RISK AS
SELECT
    m.MATERIAL_ID,
    m.DESCRIPTION,
    m.MATERIAL_GROUP,
    m.CRITICALITY_SCORE,
    rs.RISK_SCORE AS GNN_RISK_SCORE,
    rs.RISK_CATEGORY,
    COALESCE(supplier_count.NUM_SUPPLIERS, 0) AS NUM_SUPPLIERS,
    COALESCE(supplier_count.AVG_SUPPLIER_RISK, 0) AS AVG_SUPPLIER_RISK
FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.MATERIALS m
LEFT JOIN SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RISK_SCORES rs
    ON m.MATERIAL_ID = rs.NODE_ID AND rs.NODE_TYPE = 'PART'
LEFT JOIN (
    SELECT
        po.MATERIAL_ID,
        COUNT(DISTINCT po.VENDOR_ID) AS NUM_SUPPLIERS,
        AVG(COALESCE(rs2.RISK_SCORE, 0.5)) AS AVG_SUPPLIER_RISK
    FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.PURCHASE_ORDERS po
    LEFT JOIN SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RISK_SCORES rs2
        ON po.VENDOR_ID = rs2.NODE_ID AND rs2.NODE_TYPE = 'SUPPLIER'
    GROUP BY po.MATERIAL_ID
) supplier_count ON m.MATERIAL_ID = supplier_count.MATERIAL_ID;

CREATE OR REPLACE VIEW SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VW_HIDDEN_DEPENDENCIES AS
SELECT
    pl.LINK_ID,
    pl.SOURCE_NODE_ID,
    pl.SOURCE_NODE_TYPE,
    CASE
        WHEN pl.SOURCE_NODE_TYPE = 'SUPPLIER' THEN v1.NAME
        ELSE pl.SOURCE_NODE_ID
    END AS SOURCE_NAME,
    pl.TARGET_NODE_ID,
    pl.TARGET_NODE_TYPE,
    CASE
        WHEN pl.TARGET_NODE_TYPE = 'SUPPLIER' THEN v2.NAME
        ELSE pl.TARGET_NODE_ID
    END AS TARGET_NAME,
    pl.PROBABILITY,
    pl.EVIDENCE_STRENGTH,
    pl.PREDICTED_AT
FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.PREDICTED_LINKS pl
LEFT JOIN SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VENDORS v1 ON pl.SOURCE_NODE_ID = v1.VENDOR_ID
LEFT JOIN SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VENDORS v2 ON pl.TARGET_NODE_ID = v2.VENDOR_ID
WHERE pl.PROBABILITY >= 0.5
ORDER BY pl.PROBABILITY DESC;

CREATE OR REPLACE VIEW SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VW_RISK_SUMMARY AS
SELECT
    'SUPPLIERS' AS CATEGORY,
    COUNT(*) AS TOTAL_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'CRITICAL' THEN 1 ELSE 0 END) AS CRITICAL_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'HIGH' THEN 1 ELSE 0 END) AS HIGH_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'MEDIUM' THEN 1 ELSE 0 END) AS MEDIUM_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'LOW' THEN 1 ELSE 0 END) AS LOW_COUNT,
    AVG(RISK_SCORE) AS AVG_RISK_SCORE
FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RISK_SCORES WHERE NODE_TYPE = 'SUPPLIER'
UNION ALL
SELECT
    'PARTS' AS CATEGORY,
    COUNT(*) AS TOTAL_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'CRITICAL' THEN 1 ELSE 0 END) AS CRITICAL_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'HIGH' THEN 1 ELSE 0 END) AS HIGH_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'MEDIUM' THEN 1 ELSE 0 END) AS MEDIUM_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'LOW' THEN 1 ELSE 0 END) AS LOW_COUNT,
    AVG(RISK_SCORE) AS AVG_RISK_SCORE
FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RISK_SCORES WHERE NODE_TYPE = 'PART';

-- ============================================================
-- Section 11: Risk Scenario Analysis UDF
-- ============================================================
CREATE OR REPLACE FUNCTION SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.ANALYZE_RISK_SCENARIO(
    SCENARIO_TYPE VARCHAR,
    TARGET_REGION VARCHAR DEFAULT NULL,
    TARGET_VENDOR VARCHAR DEFAULT NULL,
    SHOCK_INTENSITY FLOAT DEFAULT 0.5
)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
SELECT OBJECT_CONSTRUCT(
    'scenario_type', SCENARIO_TYPE,
    'target', COALESCE(TARGET_REGION, TARGET_VENDOR, 'all'),
    'shock_intensity', SHOCK_INTENSITY,
    'analysis', CASE
        WHEN SCENARIO_TYPE = 'REGIONAL_DISRUPTION' THEN
            (SELECT OBJECT_CONSTRUCT(
                'affected_vendors', COUNT(DISTINCT v.VENDOR_ID),
                'avg_current_risk', ROUND(AVG(rs.RISK_SCORE), 3),
                'projected_risk', ROUND(LEAST(1.0, AVG(rs.RISK_SCORE) + (SHOCK_INTENSITY * 0.3)), 3),
                'recommendation', CASE
                    WHEN COUNT(*) > 5 THEN 'High concentration risk - diversify suppliers'
                    ELSE 'Moderate exposure - monitor closely'
                END
            )
            FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VENDORS v
            JOIN SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RISK_SCORES rs ON v.VENDOR_ID = rs.NODE_ID
            WHERE v.COUNTRY_CODE = TARGET_REGION
            )
        WHEN SCENARIO_TYPE = 'VENDOR_FAILURE' THEN
            (SELECT OBJECT_CONSTRUCT(
                'vendor_name', v.NAME,
                'current_risk', rs.RISK_SCORE,
                'dependent_materials', (
                    SELECT COUNT(DISTINCT MATERIAL_ID)
                    FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.PURCHASE_ORDERS
                    WHERE VENDOR_ID = TARGET_VENDOR
                ),
                'bottleneck_impact', COALESCE(b.IMPACT_SCORE, 0),
                'recommendation', CASE
                    WHEN rs.RISK_SCORE > 0.7 THEN 'Immediate action required - identify alternates'
                    WHEN rs.RISK_SCORE > 0.4 THEN 'Develop contingency plan'
                    ELSE 'Low priority - standard monitoring'
                END
            )
            FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VENDORS v
            JOIN SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RISK_SCORES rs ON v.VENDOR_ID = rs.NODE_ID
            LEFT JOIN SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.BOTTLENECKS b ON v.VENDOR_ID = b.NODE_ID
            WHERE v.VENDOR_ID = TARGET_VENDOR
            )
        WHEN SCENARIO_TYPE = 'PORTFOLIO_SUMMARY' THEN
            (SELECT OBJECT_CONSTRUCT(
                'total_vendors', COUNT(DISTINCT VENDOR_ID),
                'critical_count', SUM(CASE WHEN rs.RISK_CATEGORY = 'CRITICAL' THEN 1 ELSE 0 END),
                'high_risk_count', SUM(CASE WHEN rs.RISK_CATEGORY IN ('CRITICAL', 'HIGH') THEN 1 ELSE 0 END),
                'avg_portfolio_risk', ROUND(AVG(rs.RISK_SCORE), 3),
                'total_bottlenecks', (SELECT COUNT(*) FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.BOTTLENECKS),
                'health_score', ROUND((1 - AVG(rs.RISK_SCORE)) * 100, 1)
            )
            FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VENDORS v
            JOIN SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RISK_SCORES rs ON v.VENDOR_ID = rs.NODE_ID
            )
        ELSE
            OBJECT_CONSTRUCT('error', 'Unknown scenario type. Use: REGIONAL_DISRUPTION, VENDOR_FAILURE, or PORTFOLIO_SUMMARY')
    END
)
$$;

-- ============================================================
-- Section 12: Semantic Model Stage + YAML
-- ============================================================
COPY INTO @SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.SEMANTIC_MODELS/supply_chain_risk.yaml
FROM (
    SELECT 'name: supply_chain_risk_semantic_view
description: |
  GNN Supply Chain Risk Analytics - Enables natural language queries for
  supply chain risk assessment, vendor analysis, and bottleneck identification.

tables:
  - name: vendors
    base_table:
      database: SF_SOLUTIONS
      schema: GNN_SUPPLY_CHAIN_RISK
      table: VENDORS
    primary_key:
      columns: [vendor_id]

    dimensions:
      - name: vendor_id
        expr: vendor_id
        data_type: TEXT
        description: Unique identifier for the vendor

      - name: vendor_name
        expr: name
        synonyms: ["supplier name", "company name", "vendor"]
        data_type: TEXT
        description: Full name of the vendor company

      - name: country
        expr: country_code
        synonyms: ["country code", "region", "location"]
        data_type: TEXT
        sample_values: ["USA", "CHN", "DEU", "JPN", "KOR", "MEX", "AUS", "CHL", "COD"]
        description: ISO 3-letter country code where vendor is located

      - name: city
        expr: city
        data_type: TEXT
        description: City where vendor is headquartered

      - name: tier
        expr: tier
        synonyms: ["supplier tier", "vendor tier"]
        data_type: NUMBER
        sample_values: ["1", "2"]
        description: Supplier tier (1=direct, 2=inferred via GNN)

    facts:
      - name: financial_health
        expr: financial_health_score
        synonyms: ["financial score", "health score"]
        data_type: NUMBER
        description: Financial health score from 0 (poor) to 1 (excellent)

    metrics:
      - name: total_vendors
        expr: COUNT(DISTINCT vendors.vendor_id)
        synonyms: ["vendor count", "number of vendors", "supplier count"]
        description: Total number of vendors

      - name: avg_financial_health
        expr: AVG(vendors.financial_health)
        synonyms: ["average health", "mean financial score"]
        description: Average financial health score across vendors

  - name: regions
    base_table:
      database: SF_SOLUTIONS
      schema: GNN_SUPPLY_CHAIN_RISK
      table: REGIONS
    primary_key:
      columns: [region_code]

    dimensions:
      - name: region_code
        expr: region_code
        data_type: TEXT
        sample_values: ["USA", "CHN", "DEU", "JPN", "KOR", "MEX", "AUS", "CHL", "COD"]
        description: ISO 3-letter country/region code

      - name: region_name
        expr: region_name
        synonyms: ["country name", "region", "country"]
        data_type: TEXT
        sample_values: ["United States", "China", "Germany", "Japan", "South Korea"]
        description: Full name of the region/country

    facts:
      - name: geopolitical_risk
        expr: geopolitical_risk
        synonyms: ["political risk", "geo risk"]
        data_type: NUMBER
        description: Geopolitical risk factor from 0 (stable) to 1 (high risk)

      - name: natural_disaster_risk
        expr: natural_disaster_risk
        synonyms: ["disaster risk", "natural risk"]
        data_type: NUMBER
        description: Natural disaster risk from 0 (low) to 1 (high)

      - name: infrastructure_score
        expr: infrastructure_score
        synonyms: ["infrastructure quality", "logistics score"]
        data_type: NUMBER
        description: Infrastructure quality from 0 (poor) to 1 (excellent)

      - name: base_risk
        expr: base_risk_score
        synonyms: ["baseline risk", "regional risk"]
        data_type: NUMBER
        description: Combined baseline regional risk score

    metrics:
      - name: avg_regional_risk
        expr: AVG(regions.base_risk)
        description: Average risk score across regions

  - name: risk_scores
    base_table:
      database: SF_SOLUTIONS
      schema: GNN_SUPPLY_CHAIN_RISK
      table: RISK_SCORES
    primary_key:
      columns: [score_id]

    dimensions:
      - name: score_id
        expr: score_id
        data_type: NUMBER
        description: Unique identifier for risk score record

      - name: node_id
        expr: node_id
        data_type: TEXT
        description: ID of the node (vendor, material, or external supplier)

      - name: node_type
        expr: node_type
        synonyms: ["entity type", "type"]
        data_type: TEXT
        sample_values: ["SUPPLIER", "PART", "EXTERNAL_SUPPLIER"]
        description: Type of entity

      - name: risk_category
        expr: risk_category
        synonyms: ["risk level", "risk tier", "severity"]
        data_type: TEXT
        sample_values: ["CRITICAL", "HIGH", "MEDIUM", "LOW"]
        description: Categorical risk level

    time_dimensions:
      - name: calculated_at
        expr: calculated_at
        data_type: TIMESTAMP
        description: When the risk score was computed

    facts:
      - name: risk_score
        expr: risk_score
        synonyms: ["risk", "score"]
        data_type: NUMBER
        description: GNN-computed risk score from 0 to 1

      - name: confidence
        expr: confidence
        synonyms: ["certainty"]
        data_type: NUMBER
        description: Model confidence in the risk prediction

    metrics:
      - name: avg_risk_score
        expr: AVG(risk_scores.risk_score)
        synonyms: ["average risk", "mean risk"]
        description: Average risk score across all nodes

      - name: critical_count
        expr: COUNT(CASE WHEN risk_scores.risk_category = ''CRITICAL'' THEN 1 END)
        synonyms: ["critical risks"]
        description: Count of nodes with CRITICAL risk

      - name: high_risk_count
        expr: COUNT(CASE WHEN risk_scores.risk_category IN (''CRITICAL'', ''HIGH'') THEN 1 END)
        synonyms: ["high risk count"]
        description: Count of high risk nodes

  - name: bottlenecks
    base_table:
      database: SF_SOLUTIONS
      schema: GNN_SUPPLY_CHAIN_RISK
      table: BOTTLENECKS
    primary_key:
      columns: [bottleneck_id]

    dimensions:
      - name: bottleneck_id
        expr: bottleneck_id
        data_type: NUMBER
        description: Unique identifier for bottleneck

      - name: node_id
        expr: node_id
        synonyms: ["bottleneck node", "spof id"]
        data_type: TEXT
        description: ID of the bottleneck node

      - name: node_type
        expr: node_type
        data_type: TEXT
        sample_values: ["SUPPLIER", "PART", "EXTERNAL_SUPPLIER"]
        description: Type of bottleneck entity

      - name: mitigation_status
        expr: mitigation_status
        synonyms: ["status"]
        data_type: TEXT
        sample_values: ["UNMITIGATED", "IN_PROGRESS", "MITIGATED"]
        description: Current mitigation status

    time_dimensions:
      - name: identified_at
        expr: identified_at
        data_type: TIMESTAMP
        description: When the bottleneck was identified

    facts:
      - name: dependent_count
        expr: dependent_count
        synonyms: ["dependents", "affected vendors"]
        data_type: NUMBER
        description: Number of downstream nodes dependent on this bottleneck

      - name: impact_score
        expr: impact_score
        synonyms: ["impact", "severity"]
        data_type: NUMBER
        description: Calculated impact score

    metrics:
      - name: total_bottlenecks
        expr: COUNT(DISTINCT bottlenecks.bottleneck_id)
        synonyms: ["bottleneck count"]
        description: Total number of identified bottlenecks

      - name: avg_dependent_count
        expr: AVG(bottlenecks.dependent_count)
        description: Average dependents per bottleneck

      - name: unmitigated_count
        expr: COUNT(CASE WHEN bottlenecks.mitigation_status = ''UNMITIGATED'' THEN 1 END)
        synonyms: ["open bottlenecks"]
        description: Count of unmitigated bottlenecks

relationships:
  - name: vendors_to_regions
    left_table: vendors
    right_table: regions
    relationship_columns:
      - left_column: country
        right_column: region_code
    description: Links vendors to their geographic regions

  - name: risk_to_vendors
    left_table: risk_scores
    right_table: vendors
    relationship_columns:
      - left_column: node_id
        right_column: vendor_id
    description: Links risk scores to vendor master data

filters:
  - name: critical_only
    expr: risk_category = ''CRITICAL''
    description: Filter to only CRITICAL risk items

  - name: high_risk
    expr: risk_category IN (''CRITICAL'', ''HIGH'')
    description: Filter to HIGH or CRITICAL risk items

  - name: unmitigated
    expr: mitigation_status = ''UNMITIGATED''
    description: Filter to unmitigated bottlenecks

verified_queries:
  - name: portfolio_risk_overview
    question: "What is our overall portfolio risk?"
    use_as_onboarding_question: true
    sql: |
      SELECT
        COUNT(*) AS total_nodes,
        AVG(risk_score) AS avg_risk,
        COUNT(CASE WHEN risk_category = ''CRITICAL'' THEN 1 END) AS critical_count,
        COUNT(CASE WHEN risk_category = ''HIGH'' THEN 1 END) AS high_count
      FROM __risk_scores

  - name: risk_by_region
    question: "Which regions have the highest supply chain risk?"
    use_as_onboarding_question: true
    sql: |
      SELECT
        r.region_name,
        r.base_risk AS regional_risk,
        COUNT(v.vendor_id) AS vendor_count
      FROM __regions r
      LEFT JOIN __vendors v ON v.country = r.region_code
      GROUP BY r.region_name, r.base_risk
      ORDER BY r.base_risk DESC

  - name: top_bottlenecks
    question: "What are our biggest bottlenecks?"
    use_as_onboarding_question: true
    sql: |
      SELECT
        node_id,
        node_type,
        dependent_count,
        impact_score,
        mitigation_status
      FROM __bottlenecks
      ORDER BY impact_score DESC
      LIMIT 10

  - name: critical_suppliers
    question: "Which suppliers have critical risk scores?"
    sql: |
      SELECT
        rs.node_id AS vendor_id,
        v.vendor_name,
        v.country,
        rs.risk_score,
        rs.risk_category
      FROM __risk_scores rs
      JOIN __vendors v ON rs.node_id = v.vendor_id
      WHERE rs.risk_category = ''CRITICAL''
      ORDER BY rs.risk_score DESC
'
)
OVERWRITE = TRUE
SINGLE = TRUE;

-- ============================================================
-- Section 13: GPU Compute Pool
-- REQUIRED FOR: gnn_supply_chain_risk.ipynb (original PyTorch Geometric notebook)
-- NOT NEEDED FOR: gnn_supply_chain_risk_lite.ipynb (networkx/scikit-learn, CPU only)
--
-- Trial accounts: COMMENT OUT this entire section.
-- Enterprise accounts with SPCS enabled: leave as-is.
-- ============================================================
-- CREATE COMPUTE POOL IF NOT EXISTS GNN_SUPPLY_CHAIN_COMPUTE_POOL
--     MIN_NODES = 1
--     MAX_NODES = 1
--     INSTANCE_FAMILY = GPU_NV_S
--     AUTO_RESUME = TRUE
--     AUTO_SUSPEND_SECS = 600
--     COMMENT = 'GPU compute pool for PyTorch Geometric GNN training';

-- ============================================================
-- Section 14: External Access Integration (PyPI for torch-geometric)
-- REQUIRED FOR: gnn_supply_chain_risk.ipynb (original PyTorch Geometric notebook)
-- NOT NEEDED FOR: gnn_supply_chain_risk_lite.ipynb (all packages via Snowflake conda)
--
-- Trial accounts: COMMENT OUT this entire section.
-- Enterprise accounts with EAI support: leave as-is.
-- ============================================================
-- CREATE OR REPLACE NETWORK RULE SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.PYPI_NETWORK_RULE
--     TYPE = HOST_PORT
--     MODE = EGRESS
--     VALUE_LIST = (
--         'pypi.org:443',
--         'files.pythonhosted.org:443',
--         'download.pytorch.org:443',
--         'data.pyg.org:443'
--     )
--     COMMENT = 'Required for PyTorch Geometric and dependencies in GNN notebook';
--
-- CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION GNN_PYPI_ACCESS
--     ALLOWED_NETWORK_RULES = (SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.PYPI_NETWORK_RULE)
--     ENABLED = TRUE;

-- ============================================================
-- Section 15: Cortex Agent
-- ============================================================
CREATE OR REPLACE AGENT SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.SUPPLY_CHAIN_RISK_AGENT
    COMMENT = 'GNN Supply Chain Risk Copilot - answers questions via semantic view and scenario analysis UDF'
    FROM SPECIFICATION
    $$
    instructions:
      response: >
        You are a supply chain risk analyst. Answer questions about vendor risk scores,
        regional exposure, bottlenecks, and hidden Tier-2+ dependencies.
        When asked about scenarios, use the RISK_SCENARIO_ANALYZER tool.
      sample_questions:
        - question: "What is our overall portfolio risk?"
        - question: "Which regions have the highest supply chain risk?"
        - question: "What are our biggest bottlenecks?"
        - question: "Which suppliers have critical risk scores?"

    tools:
      - tool_spec:
          type: cortex_analyst_text_to_sql
          name: SUPPLY_CHAIN_ANALYTICS
          description: >
            Answers structured questions about vendor risk scores, regional exposure,
            bottlenecks, and predicted hidden supplier links using SQL.

    tool_resources:
      SUPPLY_CHAIN_ANALYTICS:
        semantic_model: "@SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.SEMANTIC_MODELS/supply_chain_risk.yaml"
    $$;

-- ============================================================
-- Section 16: Verification
-- ============================================================
SELECT
    'GNN Supply Chain Risk Intelligence deployed!' AS STATUS,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VENDORS) AS VENDOR_COUNT,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.MATERIALS) AS MATERIAL_COUNT,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.PURCHASE_ORDERS) AS PO_COUNT,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.TRADE_DATA) AS TRADE_DATA_COUNT,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.REGIONS) AS REGION_COUNT,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RISK_SCORES) AS RISK_SCORES_COUNT,
    'NOTE: Run GNN notebook to populate RISK_SCORES, PREDICTED_LINKS, BOTTLENECKS tables' AS NEXT_STEP;
