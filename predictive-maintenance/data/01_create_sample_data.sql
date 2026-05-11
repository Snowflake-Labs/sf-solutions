----------------------------------------------------------------------
-- Predictive Maintenance
-- Step 1: Create synthetic IoT sensor and equipment data
----------------------------------------------------------------------

USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SF_SOLUTIONS;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.PRED_MAINT_RAW;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.PRED_MAINT_ANALYTICS;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.PRED_MAINT_ML;

USE SCHEMA SF_SOLUTIONS.PRED_MAINT_RAW;

----------------------------------------------------------------------
-- Equipment dimension
----------------------------------------------------------------------
CREATE OR REPLACE TABLE EQUIPMENT (
    EQUIPMENT_ID VARCHAR(10),
    EQUIPMENT_NAME VARCHAR(100),
    EQUIPMENT_TYPE VARCHAR(50),
    MANUFACTURER VARCHAR(100),
    INSTALL_DATE DATE,
    PLANT VARCHAR(50),
    LINE VARCHAR(20),
    EXPECTED_LIFE_HOURS INT,
    LAST_MAINTENANCE_DATE DATE
);

INSERT INTO EQUIPMENT VALUES
('EQ001', 'CNC Lathe A1', 'CNC Lathe', 'Haas Automation', '2020-03-15', 'Plant-North', 'Line-1', 25000, '2025-01-10'),
('EQ002', 'CNC Lathe A2', 'CNC Lathe', 'Haas Automation', '2021-06-20', 'Plant-North', 'Line-1', 25000, '2025-02-15'),
('EQ003', 'Hydraulic Press B1', 'Press', 'Schuler Group', '2019-11-01', 'Plant-North', 'Line-2', 30000, '2024-12-01'),
('EQ004', 'Hydraulic Press B2', 'Press', 'Schuler Group', '2020-08-10', 'Plant-South', 'Line-3', 30000, '2025-03-01'),
('EQ005', 'Conveyor Motor C1', 'Motor', 'Siemens', '2018-05-22', 'Plant-South', 'Line-3', 40000, '2025-01-20'),
('EQ006', 'Conveyor Motor C2', 'Motor', 'Siemens', '2019-09-14', 'Plant-South', 'Line-4', 40000, '2024-11-15'),
('EQ007', 'Robotic Arm D1', 'Robot', 'FANUC', '2021-01-05', 'Plant-North', 'Line-2', 50000, '2025-02-28'),
('EQ008', 'Welding Station E1', 'Welder', 'Lincoln Electric', '2020-04-18', 'Plant-South', 'Line-4', 20000, '2025-01-05'),
('EQ009', 'Compressor F1', 'Compressor', 'Atlas Copco', '2019-07-30', 'Plant-North', 'Line-1', 35000, '2024-10-20'),
('EQ010', 'Packaging Unit G1', 'Packaging', 'Bosch', '2022-02-14', 'Plant-South', 'Line-3', 45000, '2025-03-15');

----------------------------------------------------------------------
-- Maintenance history
----------------------------------------------------------------------
CREATE OR REPLACE TABLE MAINTENANCE_LOG (
    LOG_ID INT AUTOINCREMENT,
    EQUIPMENT_ID VARCHAR(10),
    MAINTENANCE_DATE DATE,
    MAINTENANCE_TYPE VARCHAR(30),
    DESCRIPTION VARCHAR(500),
    DOWNTIME_HOURS DECIMAL(6,1),
    COST_USD DECIMAL(10,2),
    TECHNICIAN VARCHAR(50)
);

INSERT INTO MAINTENANCE_LOG (EQUIPMENT_ID, MAINTENANCE_DATE, MAINTENANCE_TYPE, DESCRIPTION, DOWNTIME_HOURS, COST_USD, TECHNICIAN) VALUES
('EQ001', '2024-06-15', 'Preventive', 'Scheduled bearing replacement', 4.0, 1200.00, 'J. Smith'),
('EQ001', '2024-09-20', 'Corrective', 'Spindle motor overheating - emergency repair', 16.0, 4500.00, 'M. Johnson'),
('EQ001', '2025-01-10', 'Preventive', 'Full service and calibration', 8.0, 2000.00, 'J. Smith'),
('EQ003', '2024-05-10', 'Corrective', 'Hydraulic seal failure', 24.0, 6000.00, 'R. Williams'),
('EQ003', '2024-08-22', 'Preventive', 'Hydraulic fluid replacement', 3.0, 800.00, 'R. Williams'),
('EQ003', '2024-12-01', 'Preventive', 'Annual overhaul', 12.0, 3500.00, 'R. Williams'),
('EQ005', '2024-04-12', 'Corrective', 'Motor winding failure', 32.0, 8000.00, 'A. Davis'),
('EQ005', '2024-10-05', 'Preventive', 'Bearing lubrication and alignment', 2.0, 500.00, 'A. Davis'),
('EQ005', '2025-01-20', 'Preventive', 'Vibration analysis and balancing', 4.0, 1500.00, 'A. Davis'),
('EQ006', '2024-07-18', 'Corrective', 'Overheating - cooling fan replaced', 8.0, 2200.00, 'K. Brown'),
('EQ006', '2024-11-15', 'Preventive', 'Full inspection', 6.0, 1800.00, 'K. Brown'),
('EQ008', '2024-08-30', 'Corrective', 'Electrode wear - unplanned stop', 12.0, 3000.00, 'T. Wilson'),
('EQ008', '2025-01-05', 'Preventive', 'Tip replacement and calibration', 3.0, 900.00, 'T. Wilson'),
('EQ009', '2024-06-25', 'Corrective', 'Pressure valve leak', 18.0, 5500.00, 'P. Garcia'),
('EQ009', '2024-10-20', 'Preventive', 'Filter and oil change', 2.0, 600.00, 'P. Garcia');

----------------------------------------------------------------------
-- IoT sensor readings (1 year of hourly data for 10 machines)
-- Sensors: temperature, vibration, pressure, current, RPM
-- Patterns: gradual degradation before failures, normal noise
----------------------------------------------------------------------
CREATE OR REPLACE TABLE SENSOR_READINGS AS
WITH time_spine AS (
    SELECT DATEADD(HOUR, SEQ4(), '2024-01-01 00:00:00')::TIMESTAMP_NTZ AS READING_TIME
    FROM TABLE(GENERATOR(ROWCOUNT => 12000))
    WHERE READING_TIME <= '2025-05-01 00:00:00'
),
equipment_list AS (
    SELECT EQUIPMENT_ID, EQUIPMENT_TYPE,
           ROW_NUMBER() OVER (ORDER BY EQUIPMENT_ID) AS EQ_NUM
    FROM EQUIPMENT
),
base_readings AS (
    SELECT
        t.READING_TIME,
        e.EQUIPMENT_ID,
        e.EQUIPMENT_TYPE,
        -- Temperature (°C): baseline + trend + noise
        ROUND(
            CASE e.EQUIPMENT_TYPE
                WHEN 'CNC Lathe' THEN 45.0
                WHEN 'Press' THEN 55.0
                WHEN 'Motor' THEN 65.0
                WHEN 'Robot' THEN 35.0
                WHEN 'Welder' THEN 80.0
                WHEN 'Compressor' THEN 70.0
                WHEN 'Packaging' THEN 40.0
            END
            + (RANDOM() % 10 - 5) * 0.3
            + CASE WHEN HOUR(t.READING_TIME) BETWEEN 8 AND 17 THEN 5.0 ELSE 0.0 END
            + CASE WHEN DATEDIFF(DAY, '2024-01-01', t.READING_TIME) > 300
                   AND e.EQUIPMENT_ID IN ('EQ001', 'EQ005', 'EQ009')
                   THEN (DATEDIFF(DAY, '2024-10-28', t.READING_TIME) * 0.02)
                   ELSE 0 END
        , 2) AS TEMPERATURE_C,
        -- Vibration (mm/s): baseline + degradation signal
        ROUND(
            CASE e.EQUIPMENT_TYPE
                WHEN 'CNC Lathe' THEN 2.5
                WHEN 'Press' THEN 4.0
                WHEN 'Motor' THEN 3.5
                WHEN 'Robot' THEN 1.5
                WHEN 'Welder' THEN 2.0
                WHEN 'Compressor' THEN 5.0
                WHEN 'Packaging' THEN 2.0
            END
            + ABS(RANDOM() % 100) * 0.01
            + CASE WHEN DATEDIFF(DAY, '2024-01-01', t.READING_TIME) > 250
                   AND e.EQUIPMENT_ID IN ('EQ003', 'EQ006', 'EQ008')
                   THEN POWER(DATEDIFF(DAY, '2024-09-08', t.READING_TIME) * 0.003, 1.5)
                   ELSE 0 END
        , 3) AS VIBRATION_MM_S,
        -- Pressure (bar) - relevant for press & compressor
        ROUND(
            CASE e.EQUIPMENT_TYPE
                WHEN 'Press' THEN 200.0
                WHEN 'Compressor' THEN 8.0
                ELSE 1.0
            END
            + (RANDOM() % 20 - 10) * 0.1
            + CASE WHEN e.EQUIPMENT_ID = 'EQ009'
                   AND DATEDIFF(DAY, '2024-01-01', t.READING_TIME) > 200
                   THEN -0.5 * (DATEDIFF(DAY, '2024-07-20', t.READING_TIME) * 0.005)
                   ELSE 0 END
        , 2) AS PRESSURE_BAR,
        -- Current draw (Amps)
        ROUND(
            CASE e.EQUIPMENT_TYPE
                WHEN 'CNC Lathe' THEN 15.0
                WHEN 'Press' THEN 45.0
                WHEN 'Motor' THEN 25.0
                WHEN 'Robot' THEN 10.0
                WHEN 'Welder' THEN 80.0
                WHEN 'Compressor' THEN 30.0
                WHEN 'Packaging' THEN 8.0
            END
            * (CASE WHEN HOUR(t.READING_TIME) BETWEEN 8 AND 17 THEN 1.0 ELSE 0.3 END)
            + (RANDOM() % 20 - 10) * 0.1
            + CASE WHEN e.EQUIPMENT_ID IN ('EQ005', 'EQ006')
                   AND DATEDIFF(DAY, '2024-01-01', t.READING_TIME) > 280
                   THEN 2.0 + DATEDIFF(DAY, '2024-10-08', t.READING_TIME) * 0.01
                   ELSE 0 END
        , 2) AS CURRENT_AMPS,
        -- Operating hours accumulator
        ROUND(
            DATEDIFF(HOUR, '2020-01-01', t.READING_TIME)
            * (CASE WHEN HOUR(t.READING_TIME) BETWEEN 8 AND 17 THEN 1 ELSE 0 END)
            * 0.4
        , 0) AS OPERATING_HOURS
    FROM time_spine t
    CROSS JOIN equipment_list e
)
SELECT
    READING_TIME,
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,
    TEMPERATURE_C,
    VIBRATION_MM_S,
    PRESSURE_BAR,
    CURRENT_AMPS,
    OPERATING_HOURS
FROM base_readings
ORDER BY READING_TIME, EQUIPMENT_ID;

----------------------------------------------------------------------
-- Verify data
----------------------------------------------------------------------
SELECT 'EQUIPMENT' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM EQUIPMENT
UNION ALL
SELECT 'MAINTENANCE_LOG', COUNT(*) FROM MAINTENANCE_LOG
UNION ALL
SELECT 'SENSOR_READINGS', COUNT(*) FROM SENSOR_READINGS;
