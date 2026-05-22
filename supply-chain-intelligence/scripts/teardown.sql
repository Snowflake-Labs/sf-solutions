/*************************************************************************************************/
-- SUPPLY CHAIN INTELLIGENCE PLATFORM TEARDOWN
-- WARNING: This will permanently delete all solution data.
-- The shared SF_SOLUTIONS database and SF_SOLUTIONS_WH are NOT dropped.
/*************************************************************************************************/

USE ROLE ACCOUNTADMIN;

DROP CORTEX SEARCH SERVICE IF EXISTS SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_INFO;
DROP AGENT IF EXISTS SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_ASSISTANT;
DROP SCHEMA IF EXISTS SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES;

SELECT 'Supply Chain Intelligence teardown complete.' AS STATUS;
