----------------------------------------------------------------------
-- 予知保全（Predictive Maintenance）
-- Step 1: サンプルデータ作成（日本市場版）
----------------------------------------------------------------------

USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SF_SOLUTIONS;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.PRED_MAINT_RAW;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.PRED_MAINT_ANALYTICS;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.PRED_MAINT_ML;

USE SCHEMA SF_SOLUTIONS.PRED_MAINT_RAW;

----------------------------------------------------------------------
-- 設備マスタ
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
('EQ001', 'CNC旋盤 A1号機', 'CNC旋盤', 'メーカーA', '2020-03-15', '第一工場', 'ライン1', 25000, '2025-01-10'),
('EQ002', 'CNC旋盤 A2号機', 'CNC旋盤', 'メーカーA', '2021-06-20', '第一工場', 'ライン1', 25000, '2025-02-15'),
('EQ003', '油圧プレス B1号機', 'プレス機', 'メーカーB', '2019-11-01', '第一工場', 'ライン2', 30000, '2024-12-01'),
('EQ004', '油圧プレス B2号機', 'プレス機', 'メーカーB', '2020-08-10', '第二工場', 'ライン3', 30000, '2025-03-01'),
('EQ005', 'コンベアモーター C1', 'モーター', 'メーカーC', '2018-05-22', '第二工場', 'ライン3', 40000, '2025-01-20'),
('EQ006', 'コンベアモーター C2', 'モーター', 'メーカーC', '2019-09-14', '第二工場', 'ライン4', 40000, '2024-11-15'),
('EQ007', '産業ロボット D1', 'ロボット', 'メーカーD', '2021-01-05', '第一工場', 'ライン2', 50000, '2025-02-28'),
('EQ008', '溶接ステーション E1', '溶接機', 'メーカーE', '2020-04-18', '第二工場', 'ライン4', 20000, '2025-01-05'),
('EQ009', 'コンプレッサー F1', 'コンプレッサー', 'メーカーF', '2019-07-30', '第一工場', 'ライン1', 35000, '2024-10-20'),
('EQ010', '包装機 G1', '包装機', 'メーカーG', '2022-02-14', '第二工場', 'ライン3', 45000, '2025-03-15');

----------------------------------------------------------------------
-- 保全履歴
----------------------------------------------------------------------
CREATE OR REPLACE TABLE MAINTENANCE_LOG (
    LOG_ID INT AUTOINCREMENT,
    EQUIPMENT_ID VARCHAR(10),
    MAINTENANCE_DATE DATE,
    MAINTENANCE_TYPE VARCHAR(30),
    DESCRIPTION VARCHAR(500),
    DOWNTIME_HOURS DECIMAL(6,1),
    COST_JPY DECIMAL(12,0),
    TECHNICIAN VARCHAR(50)
);

INSERT INTO MAINTENANCE_LOG (EQUIPMENT_ID, MAINTENANCE_DATE, MAINTENANCE_TYPE, DESCRIPTION, DOWNTIME_HOURS, COST_JPY, TECHNICIAN) VALUES
('EQ001', '2024-06-15', '予防保全', 'ベアリング定期交換', 4.0, 180000, '田中'),
('EQ001', '2024-09-20', '事後保全', 'スピンドルモーター過熱 - 緊急修理', 16.0, 675000, '佐藤'),
('EQ001', '2025-01-10', '予防保全', 'フルサービス＆キャリブレーション', 8.0, 300000, '田中'),
('EQ003', '2024-05-10', '事後保全', '油圧シール破損', 24.0, 900000, '鈴木'),
('EQ003', '2024-08-22', '予防保全', '作動油交換', 3.0, 120000, '鈴木'),
('EQ003', '2024-12-01', '予防保全', '年次オーバーホール', 12.0, 525000, '鈴木'),
('EQ005', '2024-04-12', '事後保全', 'モーター巻線故障', 32.0, 1200000, '高橋'),
('EQ005', '2024-10-05', '予防保全', 'ベアリング潤滑・アライメント調整', 2.0, 75000, '高橋'),
('EQ005', '2025-01-20', '予防保全', '振動解析・バランシング', 4.0, 225000, '高橋'),
('EQ006', '2024-07-18', '事後保全', '過熱 - 冷却ファン交換', 8.0, 330000, '渡辺'),
('EQ006', '2024-11-15', '予防保全', '全体点検', 6.0, 270000, '渡辺'),
('EQ008', '2024-08-30', '事後保全', '電極摩耗 - 予定外停止', 12.0, 450000, '伊藤'),
('EQ008', '2025-01-05', '予防保全', 'チップ交換＆キャリブレーション', 3.0, 135000, '伊藤'),
('EQ009', '2024-06-25', '事後保全', '圧力バルブ漏れ', 18.0, 825000, '山本'),
('EQ009', '2024-10-20', '予防保全', 'フィルター・オイル交換', 2.0, 90000, '山本');

----------------------------------------------------------------------
-- IoTセンサーデータ（1年分、1時間毎、10設備）
-- センサー: 温度、振動、圧力、電流、稼働時間
-- パターン: 故障前の段階的劣化、通常ノイズ
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
        ROUND(
            CASE e.EQUIPMENT_TYPE
                WHEN 'CNC旋盤' THEN 45.0
                WHEN 'プレス機' THEN 55.0
                WHEN 'モーター' THEN 65.0
                WHEN 'ロボット' THEN 35.0
                WHEN '溶接機' THEN 80.0
                WHEN 'コンプレッサー' THEN 70.0
                WHEN '包装機' THEN 40.0
            END
            + (RANDOM() % 10 - 5) * 0.3
            + CASE WHEN HOUR(t.READING_TIME) BETWEEN 8 AND 17 THEN 5.0 ELSE 0.0 END
            + CASE WHEN DATEDIFF(DAY, '2024-01-01', t.READING_TIME) > 300
                   AND e.EQUIPMENT_ID IN ('EQ001', 'EQ005', 'EQ009')
                   THEN (DATEDIFF(DAY, '2024-10-28', t.READING_TIME) * 0.02)
                   ELSE 0 END
        , 2) AS TEMPERATURE_C,
        ROUND(
            CASE e.EQUIPMENT_TYPE
                WHEN 'CNC旋盤' THEN 2.5
                WHEN 'プレス機' THEN 4.0
                WHEN 'モーター' THEN 3.5
                WHEN 'ロボット' THEN 1.5
                WHEN '溶接機' THEN 2.0
                WHEN 'コンプレッサー' THEN 5.0
                WHEN '包装機' THEN 2.0
            END
            + ABS(RANDOM() % 100) * 0.01
            + CASE WHEN DATEDIFF(DAY, '2024-01-01', t.READING_TIME) > 250
                   AND e.EQUIPMENT_ID IN ('EQ003', 'EQ006', 'EQ008')
                   THEN POWER(DATEDIFF(DAY, '2024-09-08', t.READING_TIME) * 0.003, 1.5)
                   ELSE 0 END
        , 3) AS VIBRATION_MM_S,
        ROUND(
            CASE e.EQUIPMENT_TYPE
                WHEN 'プレス機' THEN 200.0
                WHEN 'コンプレッサー' THEN 8.0
                ELSE 1.0
            END
            + (RANDOM() % 20 - 10) * 0.1
            + CASE WHEN e.EQUIPMENT_ID = 'EQ009'
                   AND DATEDIFF(DAY, '2024-01-01', t.READING_TIME) > 200
                   THEN -0.5 * (DATEDIFF(DAY, '2024-07-20', t.READING_TIME) * 0.005)
                   ELSE 0 END
        , 2) AS PRESSURE_BAR,
        ROUND(
            CASE e.EQUIPMENT_TYPE
                WHEN 'CNC旋盤' THEN 15.0
                WHEN 'プレス機' THEN 45.0
                WHEN 'モーター' THEN 25.0
                WHEN 'ロボット' THEN 10.0
                WHEN '溶接機' THEN 80.0
                WHEN 'コンプレッサー' THEN 30.0
                WHEN '包装機' THEN 8.0
            END
            * (CASE WHEN HOUR(t.READING_TIME) BETWEEN 8 AND 17 THEN 1.0 ELSE 0.3 END)
            + (RANDOM() % 20 - 10) * 0.1
            + CASE WHEN e.EQUIPMENT_ID IN ('EQ005', 'EQ006')
                   AND DATEDIFF(DAY, '2024-01-01', t.READING_TIME) > 280
                   THEN 2.0 + DATEDIFF(DAY, '2024-10-08', t.READING_TIME) * 0.01
                   ELSE 0 END
        , 2) AS CURRENT_AMPS,
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
-- データ確認
----------------------------------------------------------------------
SELECT 'EQUIPMENT' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM EQUIPMENT
UNION ALL
SELECT 'MAINTENANCE_LOG', COUNT(*) FROM MAINTENANCE_LOG
UNION ALL
SELECT 'SENSOR_READINGS', COUNT(*) FROM SENSOR_READINGS;
