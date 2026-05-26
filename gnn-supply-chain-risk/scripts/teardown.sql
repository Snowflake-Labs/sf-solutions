-- ============================================================
-- GNN Supply Chain Risk Intelligence - Teardown Script
-- ============================================================
-- Drops GNN_SUPPLY_CHAIN_RISK schema and its objects.
-- Does NOT drop the shared SF_SOLUTIONS database or warehouse.
-- ============================================================

USE ROLE ACCOUNTADMIN;

DROP CORTEX AGENT IF EXISTS SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.SUPPLY_CHAIN_RISK_AGENT;

DROP EXTERNAL ACCESS INTEGRATION IF EXISTS GNN_PYPI_ACCESS;
DROP NETWORK RULE IF EXISTS SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK.PYPI_NETWORK_RULE;
DROP COMPUTE POOL IF EXISTS GNN_SUPPLY_CHAIN_COMPUTE_POOL;

DROP SCHEMA IF EXISTS SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK CASCADE;

SELECT 'GNN Supply Chain Risk Intelligence removed.' AS STATUS;
