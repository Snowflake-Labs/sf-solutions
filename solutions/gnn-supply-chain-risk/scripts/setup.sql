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
-- Sections 4-9: Demo Data (moved to data.sql)
-- Run: scripts/data.sql after this script completes table creation.
-- ============================================================

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
-- Section 12: Semantic Model
-- Extracted to semantic/supply_chain_risk.yaml for direct PUT upload.
-- Execute: PUT file://.../semantic/supply_chain_risk.yaml @SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.SEMANTIC_MODELS/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE
-- ============================================================

ALTER STAGE SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.SEMANTIC_MODELS REFRESH;


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
    COMMENT = 'GNN Supply Chain Risk Copilot - answers questions via semantic model and scenario analysis UDF'
    FROM SPECIFICATION $$
{
    "tools": [
        {
            "tool_spec": {
                "name": "SUPPLY_CHAIN_ANALYTICS",
                "type": "cortex_analyst_text_to_sql",
                "description": "Answers structured questions about vendor risk scores, regional exposure, bottlenecks, and predicted hidden supplier links using SQL."
            }
        }
    ],
    "tool_resources": {
        "SUPPLY_CHAIN_ANALYTICS": {
            "type": "cortex_analyst_text_to_sql",
            "semantic_model_file": "@SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.SEMANTIC_MODELS/supply_chain_risk.yaml",
            "execution_environment": {"type": "warehouse", "warehouse": "SF_SOLUTIONS_WH"}
        }
    }
}
$$;

-- ============================================================
-- Section 16: Stored Procedure - RUN_RISK_SCORING
-- Alternative to the GNN notebook for accounts without SPCS/EAI.
-- Uses NetworkX PageRank + Betweenness Centrality (CPU only).
-- Populates: RISK_SCORES, PREDICTED_LINKS, BOTTLENECKS
-- ============================================================
CREATE OR REPLACE PROCEDURE SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RUN_RISK_SCORING()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'pandas', 'numpy', 'networkx', 'scikit-learn')
HANDLER = 'run'
AS
$$
import numpy as np
import pandas as pd
import networkx as nx
from difflib import SequenceMatcher

def run(session):
    DB_SCHEMA = 'SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK'
    MODEL_VERSION = 'networkx-lite-v1'

    vendors_df   = session.sql(f'SELECT * FROM {DB_SCHEMA}.VENDORS').to_pandas()
    materials_df = session.sql(f'SELECT * FROM {DB_SCHEMA}.MATERIALS').to_pandas()
    po_df        = session.sql(f'SELECT * FROM {DB_SCHEMA}.PURCHASE_ORDERS').to_pandas()
    bom_df       = session.sql(f'SELECT * FROM {DB_SCHEMA}.BILL_OF_MATERIALS').to_pandas()
    trade_df     = session.sql(f'SELECT * FROM {DB_SCHEMA}.TRADE_DATA').to_pandas()
    regions_df   = session.sql(f'SELECT * FROM {DB_SCHEMA}.REGIONS').to_pandas()

    region_map = regions_df.set_index('REGION_CODE').to_dict('index')

    G = nx.DiGraph()

    for _, v in vendors_df.iterrows():
        reg = region_map.get(v['COUNTRY_CODE'], {})
        base_risk = float(reg.get('BASE_RISK_SCORE', 0.3))
        geo_risk  = float(reg.get('GEOPOLITICAL_RISK', 0.3))
        fin_risk  = 1.0 - float(v['FINANCIAL_HEALTH_SCORE'])
        node_risk = 0.50 * fin_risk + 0.30 * base_risk + 0.20 * geo_risk
        G.add_node(f"V_{v['VENDOR_ID']}", node_type='SUPPLIER', raw_id=v['VENDOR_ID'],
                   name=v['NAME'], country=v['COUNTRY_CODE'], initial_risk=node_risk)

    for _, m in materials_df.iterrows():
        node_risk = float(1.0 - m['CRITICALITY_SCORE']) * 0.5 + 0.1
        G.add_node(f"M_{m['MATERIAL_ID']}", node_type='PART', raw_id=m['MATERIAL_ID'],
                   name=m['DESCRIPTION'], initial_risk=node_risk)

    shipper_stats = trade_df.groupby('SHIPPER_NAME').agg(
        COUNTRY=('SHIPPER_COUNTRY', 'first'), COUNT=('BOL_ID', 'count')
    ).reset_index()
    for _, s in shipper_stats.iterrows():
        reg = region_map.get(s['COUNTRY'], {})
        node_risk = float(reg.get('BASE_RISK_SCORE', 0.4))
        G.add_node(f"E_{s['SHIPPER_NAME']}", node_type='EXTERNAL_SUPPLIER',
                   raw_id=s['SHIPPER_NAME'], name=s['SHIPPER_NAME'],
                   country=s['COUNTRY'], shipment_count=int(s['COUNT']), initial_risk=node_risk)

    for _, po in po_df.iterrows():
        src, dst = f"V_{po['VENDOR_ID']}", f"M_{po['MATERIAL_ID']}"
        spend = float(po['QUANTITY']) * float(po['UNIT_PRICE'])
        if G.has_node(src) and G.has_node(dst):
            if G.has_edge(src, dst):
                G[src][dst]['weight'] += spend
            else:
                G.add_edge(src, dst, weight=spend, edge_type='SUPPLIES')

    for _, b in bom_df.iterrows():
        src, dst = f"M_{b['PARENT_MATERIAL_ID']}", f"M_{b['CHILD_MATERIAL_ID']}"
        if G.has_node(src) and G.has_node(dst):
            G.add_edge(src, dst, weight=float(b['QUANTITY_PER_UNIT']), edge_type='CONTAINS')

    vendor_names = [(v['VENDOR_ID'], v['NAME'].lower()) for _, v in vendors_df.iterrows()]
    trade_edges = []

    def best_vendor_match(consignee, threshold=0.65):
        consignee_l = consignee.lower()
        best_id, best_score = None, 0.0
        for vid, vname in vendor_names:
            if vname in consignee_l or consignee_l in vname:
                return vid, 1.0
            score = SequenceMatcher(None, vname, consignee_l).ratio()
            if score > best_score:
                best_score, best_id = score, vid
        return (best_id, best_score) if best_score >= threshold else (None, 0.0)

    for _, t in trade_df.iterrows():
        shipper_node = f"E_{t['SHIPPER_NAME']}"
        vid, score = best_vendor_match(t['CONSIGNEE_NAME'])
        if vid:
            vendor_node = f"V_{vid}"
            if G.has_node(shipper_node) and G.has_node(vendor_node):
                if G.has_edge(shipper_node, vendor_node):
                    G[shipper_node][vendor_node]['trade_count'] += 1
                else:
                    G.add_edge(shipper_node, vendor_node, weight=1.0, edge_type='SHIPS_TO',
                               trade_count=1, match_score=score)
                trade_edges.append((t['SHIPPER_NAME'], vid, score))

    initial_risks = nx.get_node_attributes(G, 'initial_risk')
    total_risk = sum(initial_risks.values()) or 1.0
    personalization = {n: v / total_risk for n, v in initial_risks.items()}
    pagerank = nx.pagerank(G, alpha=0.85, personalization=personalization, weight='weight', max_iter=200, tol=1e-6)
    betweenness = nx.betweenness_centrality(G, normalized=True)

    def norm01(vals_dict):
        arr = np.array(list(vals_dict.values()))
        lo, hi = arr.min(), arr.max()
        normed = (arr - lo) / (hi - lo + 1e-9)
        return dict(zip(vals_dict.keys(), normed))

    pr_norm = norm01(pagerank)
    bc_norm = norm01(betweenness)

    risk_records = []
    for node_id, data in G.nodes(data=True):
        ntype = data['node_type']
        if ntype not in ('SUPPLIER', 'PART'):
            continue
        base = data['initial_risk']
        pr = pr_norm.get(node_id, 0.0)
        bc = bc_norm.get(node_id, 0.0)
        score = float(np.clip(0.50 * base + 0.35 * pr + 0.15 * bc, 0.05, 0.95))
        if score >= 0.70: category = 'CRITICAL'
        elif score >= 0.50: category = 'HIGH'
        elif score >= 0.30: category = 'MEDIUM'
        else: category = 'LOW'
        confidence = float(np.clip(0.60 + 0.40 * bc, 0.55, 0.95))
        risk_records.append({'NODE_ID': data['raw_id'], 'NODE_TYPE': ntype,
                             'RISK_SCORE': round(score, 4), 'RISK_CATEGORY': category,
                             'CONFIDENCE': round(confidence, 4), 'MODEL_VERSION': MODEL_VERSION})

    risk_df = pd.DataFrame(risk_records)

    shipper_vendor_map = {}
    for shipper_name, vendor_id, match_score in trade_edges:
        entry = shipper_vendor_map.setdefault(shipper_name, {})
        if vendor_id not in entry:
            entry[vendor_id] = {'count': 0, 'match_score': match_score}
        entry[vendor_id]['count'] += 1
        entry[vendor_id]['match_score'] = max(entry[vendor_id]['match_score'], match_score)

    link_records = []
    for shipper_name, vendor_map in shipper_vendor_map.items():
        for vendor_id, stats in vendor_map.items():
            trade_count = stats['count']
            probability = min(0.50 + 0.05 * trade_count, 0.95)
            if trade_count >= 5: evidence = 'STRONG'
            elif trade_count >= 2: evidence = 'MODERATE'
            else: evidence = 'WEAK'
            link_records.append({'SOURCE_NODE_ID': shipper_name, 'SOURCE_NODE_TYPE': 'EXTERNAL_SUPPLIER',
                                 'TARGET_NODE_ID': vendor_id, 'TARGET_NODE_TYPE': 'SUPPLIER',
                                 'LINK_TYPE': 'INFERRED_SUPPLIES', 'PROBABILITY': round(probability, 4),
                                 'EVIDENCE_STRENGTH': evidence, 'MODEL_VERSION': MODEL_VERSION})

    link_df = pd.DataFrame(link_records) if link_records else pd.DataFrame()

    risk_lookup = dict(zip(risk_df['NODE_ID'], risk_df['RISK_SCORE']))
    bottleneck_records = []
    for node_id, data in G.nodes(data=True):
        if data['node_type'] != 'EXTERNAL_SUPPLIER':
            continue
        dependent_vendors = [G.nodes[s]['raw_id'] for s in G.successors(node_id)
                             if G.nodes[s].get('node_type') == 'SUPPLIER']
        if len(dependent_vendors) < 2:
            continue
        dep_risks = [risk_lookup.get(v, 0.3) for v in dependent_vendors]
        avg_dep_risk = float(np.mean(dep_risks))
        impact_score = float(np.clip(0.15 * len(dependent_vendors) + 0.50 * avg_dep_risk
                                     + 0.35 * bc_norm.get(node_id, 0.0), 0.10, 0.99))
        description = f"{len(dependent_vendors)} Tier-1 vendor(s) depend on this supplier (country: {data.get('country', 'UNK')})"
        bottleneck_records.append({'NODE_ID': data['raw_id'], 'NODE_TYPE': 'EXTERNAL_SUPPLIER',
                                   'DEPENDENT_COUNT': len(dependent_vendors), 'IMPACT_SCORE': round(impact_score, 4),
                                   'DESCRIPTION': description, 'MITIGATION_STATUS': 'UNMITIGATED'})

    bottleneck_df = pd.DataFrame(bottleneck_records).sort_values('IMPACT_SCORE', ascending=False) if bottleneck_records else pd.DataFrame()

    # Write results using INSERT to avoid column mismatch with AUTOINCREMENT columns
    session.sql(f'TRUNCATE TABLE IF EXISTS {DB_SCHEMA}.RISK_SCORES').collect()
    session.sql(f'TRUNCATE TABLE IF EXISTS {DB_SCHEMA}.PREDICTED_LINKS').collect()
    session.sql(f'TRUNCATE TABLE IF EXISTS {DB_SCHEMA}.BOTTLENECKS').collect()

    for _, row in risk_df.iterrows():
        node_id = row['NODE_ID'].replace("'", "''")
        node_type = row['NODE_TYPE']
        risk_score = row['RISK_SCORE']
        risk_cat = row['RISK_CATEGORY']
        conf = row['CONFIDENCE']
        mv = MODEL_VERSION.replace("'", "''")
        session.sql(f"""INSERT INTO {DB_SCHEMA}.RISK_SCORES (NODE_ID, NODE_TYPE, RISK_SCORE, RISK_CATEGORY, CONFIDENCE, MODEL_VERSION)
                        VALUES ('{node_id}', '{node_type}', {risk_score}, '{risk_cat}', {conf}, '{mv}')""").collect()

    if not link_df.empty:
        for _, row in link_df.iterrows():
            src_id = row['SOURCE_NODE_ID'].replace("'", "''")
            src_type = row['SOURCE_NODE_TYPE']
            tgt_id = row['TARGET_NODE_ID'].replace("'", "''")
            tgt_type = row['TARGET_NODE_TYPE']
            lt = row['LINK_TYPE']
            prob = row['PROBABILITY']
            ev = row['EVIDENCE_STRENGTH']
            mv = MODEL_VERSION.replace("'", "''")
            session.sql(f"""INSERT INTO {DB_SCHEMA}.PREDICTED_LINKS (SOURCE_NODE_ID, SOURCE_NODE_TYPE, TARGET_NODE_ID, TARGET_NODE_TYPE, LINK_TYPE, PROBABILITY, EVIDENCE_STRENGTH, MODEL_VERSION)
                            VALUES ('{src_id}', '{src_type}', '{tgt_id}', '{tgt_type}', '{lt}', {prob}, '{ev}', '{mv}')""").collect()

    if not bottleneck_df.empty:
        for _, row in bottleneck_df.iterrows():
            nid = row['NODE_ID'].replace("'", "''")
            ntype = row['NODE_TYPE']
            dc = int(row['DEPENDENT_COUNT'])
            imp = row['IMPACT_SCORE']
            desc = row['DESCRIPTION'].replace("'", "''")
            ms = row['MITIGATION_STATUS']
            session.sql(f"""INSERT INTO {DB_SCHEMA}.BOTTLENECKS (NODE_ID, NODE_TYPE, DEPENDENT_COUNT, IMPACT_SCORE, DESCRIPTION, MITIGATION_STATUS)
                            VALUES ('{nid}', '{ntype}', {dc}, {imp}, '{desc}', '{ms}')""").collect()

    return f"Done: {len(risk_df)} risk scores, {len(link_df)} predicted links, {len(bottleneck_df)} bottlenecks"
$$;

-- ============================================================
-- Section 17: Verification
-- ============================================================
SELECT
    'GNN Supply Chain Risk Intelligence deployed!' AS STATUS,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.VENDORS) AS VENDOR_COUNT,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.MATERIALS) AS MATERIAL_COUNT,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.PURCHASE_ORDERS) AS PO_COUNT,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.TRADE_DATA) AS TRADE_DATA_COUNT,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.REGIONS) AS REGION_COUNT,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RISK_SCORES) AS RISK_SCORES_COUNT,
    'NOTE: Run CALL SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.RUN_RISK_SCORING() or deploy the GNN notebook to populate RISK_SCORES, PREDICTED_LINKS, BOTTLENECKS tables' AS NEXT_STEP;
