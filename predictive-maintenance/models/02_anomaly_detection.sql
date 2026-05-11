----------------------------------------------------------------------
-- Predictive Maintenance
-- Step 2: Build anomaly detection model using Snowflake ML
----------------------------------------------------------------------

USE SCHEMA SF_SOLUTIONS.PRED_MAINT_ANALYTICS;

----------------------------------------------------------------------
-- Feature engineering: hourly stats aggregated to daily
----------------------------------------------------------------------
CREATE OR REPLACE VIEW DAILY_EQUIPMENT_FEATURES AS
SELECT
    READING_TIME::DATE AS READING_DATE,
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,
    AVG(TEMPERATURE_C) AS AVG_TEMP,
    MAX(TEMPERATURE_C) AS MAX_TEMP,
    STDDEV(TEMPERATURE_C) AS STD_TEMP,
    AVG(VIBRATION_MM_S) AS AVG_VIBRATION,
    MAX(VIBRATION_MM_S) AS MAX_VIBRATION,
    STDDEV(VIBRATION_MM_S) AS STD_VIBRATION,
    AVG(PRESSURE_BAR) AS AVG_PRESSURE,
    MIN(PRESSURE_BAR) AS MIN_PRESSURE,
    AVG(CURRENT_AMPS) AS AVG_CURRENT,
    MAX(CURRENT_AMPS) AS MAX_CURRENT,
    MAX(OPERATING_HOURS) AS OPERATING_HOURS
FROM SF_SOLUTIONS.PRED_MAINT_RAW.SENSOR_READINGS
GROUP BY 1, 2, 3;

----------------------------------------------------------------------
-- Build anomaly detection model (unsupervised, per equipment type)
----------------------------------------------------------------------
CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION equipment_anomaly_model(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'DAILY_EQUIPMENT_FEATURES'),
    SERIES_COLNAME => 'EQUIPMENT_ID',
    TIMESTAMP_COLNAME => 'READING_DATE',
    TARGET_COLNAME => 'AVG_VIBRATION',
    LABEL_COLNAME => '',
    CONFIG_OBJECT => {
        'ON_ERROR': 'SKIP'
    }
);

----------------------------------------------------------------------
-- Detect anomalies on latest data
----------------------------------------------------------------------
CALL equipment_anomaly_model!DETECT_ANOMALIES(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'DAILY_EQUIPMENT_FEATURES'),
    SERIES_COLNAME => 'EQUIPMENT_ID',
    TIMESTAMP_COLNAME => 'READING_DATE',
    TARGET_COLNAME => 'AVG_VIBRATION',
    CONFIG_OBJECT => {
        'prediction_interval': 0.99
    }
);

----------------------------------------------------------------------
-- Store anomaly results
----------------------------------------------------------------------
CREATE OR REPLACE TABLE SF_SOLUTIONS.PRED_MAINT_ML.ANOMALY_RESULTS AS
SELECT
    SERIES AS EQUIPMENT_ID,
    TS AS READING_DATE,
    Y AS ACTUAL_VIBRATION,
    FORECAST,
    LOWER,
    UPPER,
    IS_ANOMALY,
    PERCENTILE,
    DISTANCE
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

----------------------------------------------------------------------
-- Evaluation
----------------------------------------------------------------------
CALL equipment_anomaly_model!SHOW_EVALUATION_METRICS();
