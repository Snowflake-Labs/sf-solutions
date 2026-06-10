/*************************************************************************************************/
-- CUSTOMER LIFETIME VALUE PREDICTION TEARDOWN
-- Removes all objects created by setup.sql
/*************************************************************************************************/

USE ROLE ACCOUNTADMIN;

DROP SCHEMA IF EXISTS SF_SOLUTIONS.LTV_ML;
DROP SCHEMA IF EXISTS SF_SOLUTIONS.LTV_ANALYTICS;
DROP SCHEMA IF EXISTS SF_SOLUTIONS.LTV_RAW;
