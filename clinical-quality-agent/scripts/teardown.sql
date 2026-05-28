-- ============================================================
-- Clinical Quality and Patient Safety Agent - Teardown Script
-- ============================================================
-- Drops CLINICAL_QUALITY_SAFETY schema and agent.
-- Does NOT drop the shared SF_SOLUTIONS database or warehouse.
-- ============================================================

USE ROLE ACCOUNTADMIN;

DROP AGENT IF EXISTS SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.CLINICAL_QUALITY_SAFETY_AGENT;

DROP SCHEMA IF EXISTS SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY CASCADE;

SELECT 'Clinical Quality and Patient Safety Agent removed.' AS STATUS;
