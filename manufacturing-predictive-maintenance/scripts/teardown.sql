/*--
 Product Analytics SnowCore Industries Predictive Maintenance Dashboard - Teardown Script
 This script removes all objects created by the setup script
--*/

USE ROLE accountadmin;

-- Drop database (cascades to all schemas, tables, views, etc.)
DROP DATABASE IF EXISTS SNOWCORE_INDUSTRIES;

-- Drop warehouse
DROP WAREHOUSE IF EXISTS SNOWCORE_INDUSTRIES_STREAMLIT_WH;

-- Drop warehouse
DROP WAREHOUSE IF EXISTS SNOWCORE_INDUSTRIES_WH;

SELECT 'Teardown completed successfully! All demo objects have been removed.' as status;
