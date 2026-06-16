/*--
 Product Analytics SnowCore Industries Predictive Maintenance Dashboard - Teardown Script
 This script removes all objects created by the setup script
--*/

USE ROLE ACCOUNTADMIN;

-- Drop database (cascades to all schemas, tables, views, etc.)
DROP DATABASE IF EXISTS SF_SOLUTIONS;

-- Drop warehouse
DROP WAREHOUSE IF EXISTS SF_SOLUTIONS_STREAMLIT_WH;

-- Drop warehouse
DROP WAREHOUSE IF EXISTS SF_SOLUTIONS_WH;

SELECT 'Teardown completed successfully! All demo objects have been removed.' AS STATUS;
