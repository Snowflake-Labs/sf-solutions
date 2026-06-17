-- LTV PREDICTION: Deploy Streamlit Dashboard
-- Run this AFTER setup.sql has completed successfully.
-- Prerequisites: streamlit_app.py and environment.yml must already be uploaded
-- to @SF_SOLUTIONS.LTV_ML.STREAMLIT_STAGE via PUT command.
/*************************************************************************************************/

USE ROLE ACCOUNTADMIN;
USE DATABASE SF_SOLUTIONS;
USE WAREHOUSE SF_SOLUTIONS_WH;
USE SCHEMA LTV_ML;

CREATE STAGE IF NOT EXISTS SF_SOLUTIONS.LTV_ML.STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE);

-- Create Streamlit app
CREATE OR REPLACE STREAMLIT SF_SOLUTIONS.LTV_ML.LTV_PREDICTION_DASHBOARD
    FROM '@SF_SOLUTIONS.LTV_ML.STREAMLIT_STAGE'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = SF_SOLUTIONS_WH;

ALTER STREAMLIT SF_SOLUTIONS.LTV_ML.LTV_PREDICTION_DASHBOARD ADD LIVE VERSION FROM LAST;

-- Show Streamlit URL
SELECT
    'LTV Prediction Dashboard deployed!' AS STATUS,
    'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
        || '/#/streamlit-apps/SF_SOLUTIONS.LTV_ML.LTV_PREDICTION_DASHBOARD' AS STREAMLIT_URL;
