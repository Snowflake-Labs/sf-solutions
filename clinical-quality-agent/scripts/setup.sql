-- ============================================================
-- Clinical Quality and Patient Safety Agent - Setup Script
-- Database: SF_SOLUTIONS  Schema: CLINICAL_QUALITY_SAFETY
-- ============================================================
-- Prerequisites:
--   Install PubMed from Snowflake Marketplace:
--   Data Products > Marketplace > "PubMed Biomedical Research Corpus" > Get
-- ============================================================

-- ============================================================
-- Section 1: Infrastructure
-- ============================================================
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS SF_SOLUTIONS;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY;

USE DATABASE SF_SOLUTIONS;
USE SCHEMA CLINICAL_QUALITY_SAFETY;

CREATE WAREHOUSE IF NOT EXISTS SF_SOLUTIONS_WH
    WAREHOUSE_SIZE = XSMALL
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE SF_SOLUTIONS_WH;

-- ============================================================
-- Section 2: Tables and Data Generation
-- ============================================================
CREATE OR REPLACE TABLE PATIENTS (
    patient_id STRING PRIMARY KEY,
    medical_record_number STRING UNIQUE NOT NULL,
    first_name STRING NOT NULL,
    last_name STRING NOT NULL,
    date_of_birth DATE NOT NULL,
    gender STRING NOT NULL, -- M, F, Other
    race STRING,
    ethnicity STRING,
    insurance_type STRING, -- Medicare, Medicaid, Commercial, Uninsured
    primary_language STRING,
    created_date TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_date TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 2. ADMISSIONS table - Hospital admission and discharge tracking
CREATE OR REPLACE TABLE ADMISSIONS (
    admission_id STRING PRIMARY KEY,
    patient_id STRING NOT NULL,
    admission_date TIMESTAMP_NTZ NOT NULL,
    discharge_date TIMESTAMP_NTZ,
    admission_type STRING NOT NULL, -- Emergency, Elective, Urgent, Observation
    discharge_disposition STRING, -- Home, SNF, Rehab, AMA, Expired, Transfer
    primary_service STRING, -- Medicine, Surgery, ICU, Emergency, etc.
    room_type STRING, -- ICU, Step-down, Med-Surg, Emergency
    length_of_stay_days NUMBER(10,2),
    attending_physician STRING,
    is_readmission BOOLEAN DEFAULT FALSE,
    days_since_last_discharge NUMBER(5,0),
    severity_of_illness_score NUMBER(3,1), -- Risk adjustment score 1.0-4.0
    mortality_risk_score NUMBER(5,3), -- 0.000-1.000
    created_date TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (patient_id) REFERENCES PATIENTS(patient_id)
);

-- 3. DIAGNOSES table - ICD-10 diagnosis codes and clinical conditions
CREATE OR REPLACE TABLE DIAGNOSES (
    diagnosis_id STRING PRIMARY KEY,
    admission_id STRING NOT NULL,
    patient_id STRING NOT NULL,
    icd10_code STRING NOT NULL,
    diagnosis_description STRING NOT NULL,
    diagnosis_type STRING NOT NULL, -- Primary, Secondary, Comorbidity
    present_on_admission BOOLEAN NOT NULL,
    complication_flag BOOLEAN DEFAULT FALSE,
    hospital_acquired BOOLEAN DEFAULT FALSE,
    diagnosis_date DATE NOT NULL,
    physician_name STRING,
    created_date TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (admission_id) REFERENCES ADMISSIONS(admission_id),
    FOREIGN KEY (patient_id) REFERENCES PATIENTS(patient_id)
);

-- 4. PROCEDURES table - Medical procedures and interventions
CREATE OR REPLACE TABLE PROCEDURES (
    procedure_id STRING PRIMARY KEY,
    admission_id STRING NOT NULL,
    patient_id STRING NOT NULL,
    cpt_code STRING,
    icd10_procedure_code STRING,
    procedure_description STRING NOT NULL,
    procedure_date TIMESTAMP_NTZ NOT NULL,
    procedure_type STRING, -- Surgical, Diagnostic, Therapeutic
    procedure_location STRING, -- OR, ICU, Floor, Emergency
    surgeon_name STRING,
    anesthesia_type STRING,
    procedure_duration_minutes NUMBER(5,0),
    complication_occurred BOOLEAN DEFAULT FALSE,
    infection_risk_level STRING, -- Low, Medium, High
    created_date TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (admission_id) REFERENCES ADMISSIONS(admission_id),
    FOREIGN KEY (patient_id) REFERENCES PATIENTS(patient_id)
);

-- 5. INFECTIONS table - Healthcare-associated infections (HAI) tracking
CREATE OR REPLACE TABLE INFECTIONS (
    infection_id STRING PRIMARY KEY,
    admission_id STRING NOT NULL,
    patient_id STRING NOT NULL,
    infection_type STRING NOT NULL, -- CLABSI, CAUTI, VAP, SSI, CDIFF, etc.
    infection_site STRING, -- Bloodstream, Urinary, Respiratory, Surgical Site
    pathogen STRING, -- E.coli, Staph aureus, C.diff, etc.
    onset_date DATE NOT NULL,
    resolution_date DATE,
    days_to_onset NUMBER(5,0), -- Days from admission to infection
    severity STRING NOT NULL, -- Mild, Moderate, Severe, Life-threatening
    device_associated BOOLEAN DEFAULT FALSE,
    device_type STRING, -- Central line, Foley catheter, Ventilator
    device_days NUMBER(5,0), -- Days device was in place
    antibiotic_resistance BOOLEAN DEFAULT FALSE,
    treatment_started_date DATE,
    infection_preventable BOOLEAN,
    contributed_to_death BOOLEAN DEFAULT FALSE,
    healthcare_associated BOOLEAN DEFAULT TRUE,
    created_date TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (admission_id) REFERENCES ADMISSIONS(admission_id),
    FOREIGN KEY (patient_id) REFERENCES PATIENTS(patient_id)
);

-- 6. QUALITY_EVENTS table - Patient safety events and quality indicators
CREATE OR REPLACE TABLE QUALITY_EVENTS (
    event_id STRING PRIMARY KEY,
    admission_id STRING NOT NULL,
    patient_id STRING NOT NULL,
    event_type STRING NOT NULL, -- Pressure_Injury, Fall, Medication_Error, etc.
    event_subtype STRING, -- Stage I-IV for pressure injuries, etc.
    event_date DATE NOT NULL,
    severity STRING NOT NULL, -- Minor, Moderate, Major, Catastrophic
    harm_level STRING, -- No harm, Temporary harm, Permanent harm, Death
    preventable BOOLEAN,
    reported_by STRING, -- Nurse, Physician, Patient, Family
    location STRING, -- ICU, Med-Surg, Emergency, etc.
    contributing_factors STRING, -- Free text
    corrective_actions STRING, -- Free text
    event_resolved BOOLEAN DEFAULT FALSE,
    resolution_date DATE,
    contributed_to_death BOOLEAN DEFAULT FALSE,
    created_date TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (admission_id) REFERENCES ADMISSIONS(admission_id),
    FOREIGN KEY (patient_id) REFERENCES PATIENTS(patient_id)
);

-- 7. OUTCOMES table - Patient outcomes including mortality
CREATE OR REPLACE TABLE OUTCOMES (
    outcome_id STRING PRIMARY KEY,
    admission_id STRING NOT NULL,
    patient_id STRING NOT NULL,
    outcome_type STRING NOT NULL, -- Death, Discharge, Transfer, AMA
    outcome_date TIMESTAMP_NTZ NOT NULL,
    primary_cause STRING, -- For deaths: underlying cause
    contributing_factors STRING, -- Contributing diagnoses/conditions
    expected_vs_actual STRING, -- Expected, Unexpected
    preventable BOOLEAN,
    quality_issue_related BOOLEAN DEFAULT FALSE,
    infection_related BOOLEAN DEFAULT FALSE,
    procedure_related BOOLEAN DEFAULT FALSE,
    medication_related BOOLEAN DEFAULT FALSE,
    readmission_within_30_days BOOLEAN DEFAULT FALSE,
    readmission_within_90_days BOOLEAN DEFAULT FALSE,
    satisfaction_score NUMBER(3,1), -- 1.0-5.0 patient satisfaction
    created_date TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (admission_id) REFERENCES ADMISSIONS(admission_id),
    FOREIGN KEY (patient_id) REFERENCES PATIENTS(patient_id)
);

-- 8. RISK_FACTORS table - Patient risk factors and comorbidities
CREATE OR REPLACE TABLE RISK_FACTORS (
    risk_factor_id STRING PRIMARY KEY,
    patient_id STRING NOT NULL,
    admission_id STRING,
    risk_factor_type STRING NOT NULL, -- Comorbidity, Social, Environmental
    risk_factor_name STRING NOT NULL,
    icd10_code STRING,
    severity_score NUMBER(3,1), -- 1.0-5.0
    present_on_admission BOOLEAN DEFAULT TRUE,
    chronic_condition BOOLEAN DEFAULT FALSE,
    affects_mortality_risk BOOLEAN DEFAULT FALSE,
    affects_infection_risk BOOLEAN DEFAULT FALSE,
    affects_los_risk BOOLEAN DEFAULT FALSE,
    documented_date DATE NOT NULL,
    created_date TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (patient_id) REFERENCES PATIENTS(patient_id),
    FOREIGN KEY (admission_id) REFERENCES ADMISSIONS(admission_id)
);

-- NOTE: No traditional indexes needed for regular Snowflake tables
-- Snowflake automatically optimizes query performance through:
-- 1. Automatic micro-partitioning
-- 2. Columnar storage
-- 3. Query optimization engine
-- 4. Automatic statistics collection

-- Optional: Add clustering keys for very large tables (if needed later)
-- ALTER TABLE ADMISSIONS CLUSTER BY (admission_date);
-- ALTER TABLE INFECTIONS CLUSTER BY (onset_date);

SELECT 'Clinical quality and patient safety tables created successfully (without indexes)!' AS status; 



-- Clinical Quality and Patient Safety Demo - SIMPLE Data Generation with HIGH Death Rates
-- This version uses the simplest possible logic to guarantee 25%+ death rates for excellent demo results
-- Run this after creating the tables with 02_create_tables_fixed.sql



-- Clear existing data first
TRUNCATE TABLE PATIENTS;
TRUNCATE TABLE ADMISSIONS;
TRUNCATE TABLE DIAGNOSES;

-- 1. Generate PATIENTS data (50,000 records with realistic demographics)
INSERT INTO PATIENTS (
    patient_id, 
    medical_record_number, 
    first_name, 
    last_name, 
    date_of_birth, 
    gender, 
    race, 
    ethnicity, 
    primary_language, 
    insurance_type
)
SELECT 
    'PAT' || LPAD(SEQ4(), 10, '0') AS patient_id,
    'MRN' || LPAD(SEQ4(), 8, '0') AS medical_record_number,
    CASE (UNIFORM(1, 20, RANDOM()))
        WHEN 1 THEN 'John' WHEN 2 THEN 'Mary' WHEN 3 THEN 'James' WHEN 4 THEN 'Patricia'
        WHEN 5 THEN 'Robert' WHEN 6 THEN 'Jennifer' WHEN 7 THEN 'Michael' WHEN 8 THEN 'Linda'
        WHEN 9 THEN 'William' WHEN 10 THEN 'Elizabeth' WHEN 11 THEN 'David' WHEN 12 THEN 'Barbara'
        WHEN 13 THEN 'Richard' WHEN 14 THEN 'Susan' WHEN 15 THEN 'Joseph' WHEN 16 THEN 'Jessica'
        WHEN 17 THEN 'Thomas' WHEN 18 THEN 'Sarah' WHEN 19 THEN 'Christopher' ELSE 'Karen'
    END AS first_name,
    CASE (UNIFORM(1, 20, RANDOM()))
        WHEN 1 THEN 'Smith' WHEN 2 THEN 'Johnson' WHEN 3 THEN 'Williams' WHEN 4 THEN 'Brown'
        WHEN 5 THEN 'Jones' WHEN 6 THEN 'Garcia' WHEN 7 THEN 'Miller' WHEN 8 THEN 'Davis'
        WHEN 9 THEN 'Rodriguez' WHEN 10 THEN 'Martinez' WHEN 11 THEN 'Hernandez' WHEN 12 THEN 'Lopez'
        WHEN 13 THEN 'Gonzalez' WHEN 14 THEN 'Wilson' WHEN 15 THEN 'Anderson' WHEN 16 THEN 'Thomas'
        WHEN 17 THEN 'Taylor' WHEN 18 THEN 'Moore' WHEN 19 THEN 'Jackson' ELSE 'Martin'
    END AS last_name,
    DATEADD(DAY, -UNIFORM(18*365, 95*365, RANDOM()), CURRENT_DATE()) AS date_of_birth,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 50 THEN 'M' ELSE 'F' END AS gender,
    CASE 
        WHEN UNIFORM(1, 100, RANDOM()) <= 60 THEN 'White'
        WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN 'Black or African American'
        WHEN UNIFORM(1, 100, RANDOM()) <= 90 THEN 'Hispanic or Latino'
        ELSE 'Asian'
    END AS race,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN 'Not Hispanic or Latino' ELSE 'Hispanic or Latino' END AS ethnicity,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN 'English' ELSE 'Spanish' END AS primary_language,
    CASE 
        WHEN UNIFORM(1, 100, RANDOM()) <= 40 THEN 'Medicare'
        WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN 'Commercial'
        ELSE 'Medicaid'
    END AS insurance_type
FROM TABLE(GENERATOR(ROWCOUNT => 50000));

-- 2. Generate ADMISSIONS with SIMPLE but HIGH death rate logic
INSERT INTO ADMISSIONS (
    admission_id, patient_id, admission_date, discharge_date, admission_type, 
    discharge_disposition, primary_service, room_type, length_of_stay_days, 
    attending_physician, is_readmission, days_since_last_discharge, 
    severity_of_illness_score, mortality_risk_score
)
SELECT 
    'ADM' || LPAD(SEQ4(), 10, '0') AS admission_id,
    p.patient_id,
    DATEADD(DAY, UNIFORM(0, 730, RANDOM()), $start_date::DATE) AS admission_date,
    NULL AS discharge_date, -- Will be calculated later
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 50 THEN 'Emergency' ELSE 'Elective' END AS admission_type,
    -- SIMPLE HIGH DEATH RATE: 30% die!
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 30 THEN 'Expired' ELSE 'Home' END AS discharge_disposition,
    CASE 
        WHEN UNIFORM(1, 100, RANDOM()) <= 40 THEN 'Medicine'
        WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN 'Surgery'
        ELSE 'ICU'
    END AS primary_service,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 50 THEN 'ICU' ELSE 'Med-Surg' END AS room_type,
    UNIFORM(1, 14, RANDOM()) AS length_of_stay_days,
    'Dr. Smith' AS attending_physician,
    FALSE AS is_readmission,
    NULL AS days_since_last_discharge,
    ROUND(UNIFORM(1.0, 4.0, RANDOM()), 1) AS severity_of_illness_score,
    ROUND(UNIFORM(0.001, 0.900, RANDOM()), 3) AS mortality_risk_score
FROM PATIENTS p
WHERE UNIFORM(1, 100, RANDOM()) <= 80; -- 80% of patients have admissions

-- Update discharge dates
UPDATE ADMISSIONS 
SET discharge_date = DATEADD(DAY, length_of_stay_days, admission_date);

-- Generate diagnoses for deaths
INSERT INTO DIAGNOSES (
    diagnosis_id, admission_id, patient_id, icd10_code, diagnosis_description, 
    diagnosis_type, present_on_admission, diagnosis_date, physician_name,
    complication_flag, hospital_acquired
)
SELECT 
    'DX' || LPAD(SEQ4(), 10, '0') AS diagnosis_id,
    a.admission_id,
    a.patient_id,
    'A41.9' AS icd10_code,
    'Sepsis, unspecified organism' AS diagnosis_description,
    'Primary' AS diagnosis_type,
    TRUE AS present_on_admission,
    a.admission_date AS diagnosis_date,
    a.attending_physician AS physician_name,
    TRUE AS complication_flag,
    FALSE AS hospital_acquired
FROM ADMISSIONS a
WHERE a.discharge_disposition = 'Expired';

COMMIT;

-- Verify high death rate
SELECT 
    'SIMPLE VERSION - HIGH DEATH RATE CONFIRMED!' AS message,
    COUNT(*) AS total_admissions,
    SUM(CASE WHEN discharge_disposition = 'Expired' THEN 1 ELSE 0 END) AS deaths,
    ROUND(SUM(CASE WHEN discharge_disposition = 'Expired' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS death_rate_percent
FROM ADMISSIONS;

-- Show all discharge dispositions
SELECT 
    discharge_disposition,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS percentage
FROM ADMISSIONS
GROUP BY discharge_disposition
ORDER BY count DESC; 

-- Clinical Quality and Patient Safety Demo - REALISTIC Data Generation
-- This version creates realistic healthcare relationships and statistics
-- Mortality rate: 2-3% (realistic vs 30% unrealistic)
-- Proper age stratification, comorbidity patterns, and clinical relationships

USE DATABASE SF_SOLUTIONS;
USE SCHEMA CLINICAL_QUALITY_SAFETY;

-- ========================================
-- CONFIGURABLE PARAMETERS FOR HEALTH SYSTEM SIZE
-- ========================================
-- Adjust these based on your desired health system type:
--
-- LARGE NATIONAL SYSTEM (HCA-scale): 
--   patients=2000000, admission_rate=85%, multi_admission_rate=20%
--   → ~1.7M patients, ~2-3M admissions over 2 years
--
-- REGIONAL HEALTH SYSTEM (5-15 hospitals):
--   patients=150000, admission_rate=80%, multi_admission_rate=18%
--   → ~150K patients, ~200-300K admissions over 2 years
--
-- SINGLE LARGE ACADEMIC MEDICAL CENTER (current default):
--   patients=75000, admission_rate=75%, multi_admission_rate=15%
--   → ~75K patients, ~65-85K admissions over 2 years
--
-- SINGLE COMMUNITY HOSPITAL:
--   patients=25000, admission_rate=70%, multi_admission_rate=12%
--   → ~25K patients, ~20-30K admissions over 2 years
-- ========================================

SET start_date = '2023-07-01';
SET end_date = CURRENT_DATE() - 1;

-- Configure your health system size here:
SET num_patients = 75000;           -- Total unique patients in the system
SET admission_rate_pct = 75;        -- % of patients who have at least one admission
SET multi_admission_rate_pct = 18;  -- % of admitted patients who have multiple admissions
SET avg_los_days = 5.2;             -- Average length of stay (national avg: 4.5-5.5)

-- ========================================
-- DEMO SCENARIO: CONCERNING QUALITY TRENDS
-- ========================================
-- This configuration creates data WORSE than national averages with
-- a deteriorating trend over time - perfect for CQO demo showing
-- urgent need for quality improvement intervention.
--
-- Quality degradation multipliers (1.0 = national average):
--   mortality_multiplier: How much worse than national avg (1.15 = 15% worse)
--   hai_multiplier: How much higher HAI rates are
--   trend_degradation: % increase per quarter (0.05 = 5% worse each quarter)
--   preventable_rate: % of deaths flagged as potentially preventable
-- ========================================
SET mortality_multiplier = 1.20;    -- 20% higher mortality than national avg
SET hai_multiplier = 1.25;          -- 25% higher HAI rates than national avg  
SET trend_degradation = 0.06;       -- 6% worsening per quarter (compounding)
SET preventable_death_rate = 35;    -- 35% of deaths flagged as potentially preventable

-- Clear existing data first
TRUNCATE TABLE PATIENTS;
TRUNCATE TABLE ADMISSIONS;
TRUNCATE TABLE DIAGNOSES;

-- 1. Generate PATIENTS with realistic age distribution (more elderly)
-- Using configurable $num_patients variable for health system size
INSERT INTO PATIENTS (
    patient_id, 
    medical_record_number, 
    first_name, 
    last_name, 
    date_of_birth, 
    gender, 
    race, 
    ethnicity, 
    primary_language, 
    insurance_type
)
SELECT 
    'PAT' || LPAD(SEQ4(), 10, '0') AS patient_id,
    'MRN' || LPAD(SEQ4(), 8, '0') AS medical_record_number,
    CASE (UNIFORM(1, 20, RANDOM()))
        WHEN 1 THEN 'John' WHEN 2 THEN 'Mary' WHEN 3 THEN 'James' WHEN 4 THEN 'Patricia'
        WHEN 5 THEN 'Robert' WHEN 6 THEN 'Jennifer' WHEN 7 THEN 'Michael' WHEN 8 THEN 'Linda'
        WHEN 9 THEN 'William' WHEN 10 THEN 'Elizabeth' WHEN 11 THEN 'David' WHEN 12 THEN 'Barbara'
        WHEN 13 THEN 'Richard' WHEN 14 THEN 'Susan' WHEN 15 THEN 'Joseph' WHEN 16 THEN 'Jessica'
        WHEN 17 THEN 'Thomas' WHEN 18 THEN 'Sarah' WHEN 19 THEN 'Christopher' ELSE 'Karen'
    END AS first_name,
    CASE (UNIFORM(1, 20, RANDOM()))
        WHEN 1 THEN 'Smith' WHEN 2 THEN 'Johnson' WHEN 3 THEN 'Williams' WHEN 4 THEN 'Brown'
        WHEN 5 THEN 'Jones' WHEN 6 THEN 'Garcia' WHEN 7 THEN 'Miller' WHEN 8 THEN 'Davis'
        WHEN 9 THEN 'Rodriguez' WHEN 10 THEN 'Martinez' WHEN 11 THEN 'Hernandez' WHEN 12 THEN 'Lopez'
        WHEN 13 THEN 'Gonzalez' WHEN 14 THEN 'Wilson' WHEN 15 THEN 'Anderson' WHEN 16 THEN 'Thomas'
        WHEN 17 THEN 'Taylor' WHEN 18 THEN 'Moore' WHEN 19 THEN 'Jackson' ELSE 'Martin'
    END AS last_name,
    -- Realistic age distribution: more elderly patients in hospital (matches US inpatient demographics)
    CASE 
        WHEN UNIFORM(1, 100, RANDOM()) <= 5 THEN DATEADD(DAY, -UNIFORM(18*365, 30*365, RANDOM()), CURRENT_DATE()) -- 18-30 years: 5%
        WHEN UNIFORM(1, 100, RANDOM()) <= 15 THEN DATEADD(DAY, -UNIFORM(30*365, 50*365, RANDOM()), CURRENT_DATE()) -- 30-50 years: 10%
        WHEN UNIFORM(1, 100, RANDOM()) <= 35 THEN DATEADD(DAY, -UNIFORM(50*365, 65*365, RANDOM()), CURRENT_DATE()) -- 50-65 years: 20%
        WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN DATEADD(DAY, -UNIFORM(65*365, 80*365, RANDOM()), CURRENT_DATE()) -- 65-80 years: 35%
        ELSE DATEADD(DAY, -UNIFORM(80*365, 95*365, RANDOM()), CURRENT_DATE()) -- 80+ years: 30%
    END AS date_of_birth,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 48 THEN 'M' ELSE 'F' END AS gender, -- Slightly more female
    -- Race/ethnicity distribution based on US Census health data
    CASE 
        WHEN UNIFORM(1, 100, RANDOM()) <= 60 THEN 'White'
        WHEN UNIFORM(1, 100, RANDOM()) <= 75 THEN 'Black or African American'
        WHEN UNIFORM(1, 100, RANDOM()) <= 88 THEN 'Hispanic or Latino'
        WHEN UNIFORM(1, 100, RANDOM()) <= 95 THEN 'Asian'
        ELSE 'Other'
    END AS race,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 82 THEN 'Not Hispanic or Latino' ELSE 'Hispanic or Latino' END AS ethnicity,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 85 THEN 'English' ELSE 'Spanish' END AS primary_language,
    -- Insurance tied to age (Medicare for 65+) - reflects US payer mix
    CASE 
        WHEN DATEDIFF(YEAR, DATEADD(DAY, -UNIFORM(18*365, 95*365, RANDOM()), CURRENT_DATE()), CURRENT_DATE()) >= 65 
             AND UNIFORM(1, 100, RANDOM()) <= 85 THEN 'Medicare'
        WHEN UNIFORM(1, 100, RANDOM()) <= 50 THEN 'Commercial'
        WHEN UNIFORM(1, 100, RANDOM()) <= 75 THEN 'Medicaid'
        ELSE 'Medicare Advantage'
    END AS insurance_type
FROM TABLE(GENERATOR(ROWCOUNT => $num_patients));

-- 2. Generate ADMISSIONS with NATIONAL AVERAGE mortality rates by condition
-- Based on CDC/CMS/AHA benchmarks 2024-2025:
-- Overall hospital mortality: 1.5-2.5%
-- Sepsis mortality: 13-20% (severe sepsis)
-- Cardiac arrest (IHCA) mortality: 46-51%
-- AMI mortality: 3-7% in-hospital
-- Heart failure mortality: 8-12% in-hospital
-- COPD exacerbation mortality: 2-4%
-- Pneumonia mortality: 5-10%
INSERT INTO ADMISSIONS (
    admission_id, patient_id, admission_date, discharge_date, admission_type, 
    discharge_disposition, primary_service, room_type, length_of_stay_days, 
    attending_physician, is_readmission, days_since_last_discharge, 
    severity_of_illness_score, mortality_risk_score
)
WITH patient_ages AS (
    SELECT 
        patient_id,
        DATEDIFF(YEAR, date_of_birth, CURRENT_DATE()) AS age
    FROM PATIENTS
),
admission_base AS (
    SELECT 
        'ADM' || LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM()), 10, '0') AS admission_id,
        p.patient_id,
        pa.age,
        -- Seasonal admission patterns across full date range (2023-07-01 to 2025-07-20)
        DATEADD(DAY, 
            -- Generate base random day across entire range, then apply seasonal bias
            CASE 
                -- Winter months get 35% of admissions (Dec, Jan, Feb)
                WHEN UNIFORM(1, 100, RANDOM()) <= 35 THEN 
                    -- Randomly pick winter months across the full range
                    CASE (UNIFORM(1, 6, RANDOM()))
                        WHEN 1 THEN UNIFORM(153, 183, RANDOM()) -- Dec 2023
                        WHEN 2 THEN UNIFORM(184, 214, RANDOM()) -- Jan-Feb 2024
                        WHEN 3 THEN UNIFORM(518, 548, RANDOM()) -- Dec 2024  
                        WHEN 4 THEN UNIFORM(549, 579, RANDOM()) -- Jan-Feb 2025
                        WHEN 5 THEN UNIFORM(884, 914, RANDOM()) -- Dec 2025 (if in range)
                        ELSE UNIFORM(0, DATEDIFF(DAY, $start_date::DATE, $end_date::DATE), RANDOM()) -- Fallback
                    END
                -- Spring months get 25% (Mar, Apr, May)
                WHEN UNIFORM(1, 100, RANDOM()) <= 60 THEN
                    CASE (UNIFORM(1, 4, RANDOM()))
                        WHEN 1 THEN UNIFORM(245, 336, RANDOM()) -- Mar-May 2024
                        WHEN 2 THEN UNIFORM(610, 701, RANDOM()) -- Mar-May 2025
                        ELSE UNIFORM(0, DATEDIFF(DAY, $start_date::DATE, $end_date::DATE), RANDOM()) -- Fallback
                    END
                -- Summer months get 20% (Jun, Jul, Aug)
                WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN
                    CASE (UNIFORM(1, 4, RANDOM()))
                        WHEN 1 THEN UNIFORM(62, 152, RANDOM())  -- Jun-Aug 2023 (partial)
                        WHEN 2 THEN UNIFORM(337, 428, RANDOM()) -- Jun-Aug 2024
                        WHEN 3 THEN UNIFORM(702, 792, RANDOM()) -- Jun-Aug 2025 (if in range)
                        ELSE UNIFORM(0, DATEDIFF(DAY, $start_date::DATE, $end_date::DATE), RANDOM()) -- Fallback
                    END
                -- Fall months get 20% (Sep, Oct, Nov)
                ELSE 
                    CASE (UNIFORM(1, 4, RANDOM()))
                        WHEN 1 THEN UNIFORM(429, 517, RANDOM()) -- Sep-Nov 2024
                        WHEN 2 THEN UNIFORM(793, 881, RANDOM()) -- Sep-Nov 2025 (if in range)
                        ELSE UNIFORM(0, DATEDIFF(DAY, $start_date::DATE, $end_date::DATE), RANDOM()) -- Fallback
                    END
            END, 
            $start_date::DATE
        ) AS admission_date,
        -- Admission type based on age and severity
        CASE 
            WHEN pa.age > 75 AND UNIFORM(1, 100, RANDOM()) <= 60 THEN 'Emergency'
            WHEN pa.age > 65 AND UNIFORM(1, 100, RANDOM()) <= 45 THEN 'Emergency'
            WHEN UNIFORM(1, 100, RANDOM()) <= 35 THEN 'Emergency'
            WHEN UNIFORM(1, 100, RANDOM()) <= 65 THEN 'Elective'
            ELSE 'Urgent'
        END AS admission_type,
        -- Assign a preliminary diagnosis category for mortality risk calculation
        -- This determines condition-specific mortality
        CASE 
            WHEN UNIFORM(1, 100, RANDOM()) <= 3 THEN 'cardiac_arrest'     -- 3% of admissions
            WHEN UNIFORM(1, 100, RANDOM()) <= 8 THEN 'sepsis'             -- 5% of admissions (severe)
            WHEN UNIFORM(1, 100, RANDOM()) <= 12 THEN 'ami'               -- 4% AMI
            WHEN UNIFORM(1, 100, RANDOM()) <= 22 THEN 'heart_failure'     -- 10% heart failure
            WHEN UNIFORM(1, 100, RANDOM()) <= 30 THEN 'copd'              -- 8% COPD
            WHEN UNIFORM(1, 100, RANDOM()) <= 38 THEN 'pneumonia'         -- 8% pneumonia
            WHEN UNIFORM(1, 100, RANDOM()) <= 45 THEN 'resp_failure'      -- 7% respiratory failure
            ELSE 'other'                                                   -- 55% other conditions
        END AS diagnosis_category,
        -- Severity based on age
        CASE 
            WHEN pa.age > 80 THEN ROUND(UNIFORM(2.5, 4.0, RANDOM()), 1)
            WHEN pa.age > 65 THEN ROUND(UNIFORM(2.0, 3.5, RANDOM()), 1)
            WHEN pa.age > 50 THEN ROUND(UNIFORM(1.5, 3.0, RANDOM()), 1)
            ELSE ROUND(UNIFORM(1.0, 2.5, RANDOM()), 1)
        END AS severity_of_illness_score
    FROM PATIENTS p
    JOIN patient_ages pa ON p.patient_id = pa.patient_id
    WHERE UNIFORM(1, 100, RANDOM()) <= $admission_rate_pct -- Configurable % of patients have admissions
),
-- Add multiple admissions for ~18% of patients (realistic readmission/chronic disease pattern)
-- This creates a second admission for patients with high severity or chronic conditions
additional_admissions AS (
    SELECT 
        'ADM' || LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM()) + 100000, 10, '0') AS admission_id,
        p.patient_id,
        pa.age,
        -- Second admission typically 30-180 days after first
        DATEADD(DAY, UNIFORM(30, 180, RANDOM()), ab.admission_date) AS admission_date,
        -- Second admissions more often emergency/urgent
        CASE WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN 'Emergency' ELSE 'Urgent' END AS admission_type,
        ab.diagnosis_category, -- Same chronic condition
        ROUND(ab.severity_of_illness_score + UNIFORM(0.0, 0.5, RANDOM()), 1) AS severity_of_illness_score
    FROM admission_base ab
    JOIN PATIENTS p ON ab.patient_id = p.patient_id
    JOIN patient_ages pa ON p.patient_id = pa.patient_id
    WHERE 
        -- ~18% of admitted patients have a second admission
        UNIFORM(1, 100, RANDOM()) <= $multi_admission_rate_pct
        -- More likely for chronic conditions and elderly
        AND (ab.diagnosis_category IN ('heart_failure', 'copd', 'sepsis') OR pa.age > 70)
        -- Ensure the second admission is within our date range
        AND DATEADD(DAY, 180, ab.admission_date) <= $end_date::DATE
),
-- Calculate mortality for additional admissions
additional_with_mortality AS (
    SELECT 
        aa.*,
        CASE aa.diagnosis_category
            WHEN 'cardiac_arrest' THEN 
                CASE WHEN aa.age > 80 THEN ROUND(UNIFORM(0.55, 0.65, RANDOM()), 3) ELSE ROUND(UNIFORM(0.45, 0.55, RANDOM()), 3) END
            WHEN 'sepsis' THEN 
                CASE WHEN aa.age > 80 THEN ROUND(UNIFORM(0.25, 0.35, RANDOM()), 3) ELSE ROUND(UNIFORM(0.15, 0.25, RANDOM()), 3) END
            WHEN 'heart_failure' THEN 
                CASE WHEN aa.age > 80 THEN ROUND(UNIFORM(0.15, 0.22, RANDOM()), 3) ELSE ROUND(UNIFORM(0.10, 0.15, RANDOM()), 3) END
            WHEN 'copd' THEN 
                CASE WHEN aa.age > 80 THEN ROUND(UNIFORM(0.05, 0.10, RANDOM()), 3) ELSE ROUND(UNIFORM(0.03, 0.06, RANDOM()), 3) END
            ELSE ROUND(UNIFORM(0.01, 0.04, RANDOM()), 3)
        END AS mortality_risk_score
    FROM additional_admissions aa
),
-- Calculate mortality risk with WORSE THAN NATIONAL AVERAGES + TIME-BASED DEGRADATION
-- This creates a concerning trend for the CQO demo - quality gets worse over time
admission_with_base_mortality AS (
    SELECT 
        ab.*,
        -- Calculate quarters since start for trend degradation (Q1=0, Q2=1, Q3=2, etc.)
        FLOOR(DATEDIFF(DAY, $start_date::DATE, ab.admission_date) / 91.25) AS quarters_elapsed,
        -- BASE MORTALITY RATES (already elevated above national avg by ~15-20%)
        CASE ab.diagnosis_category
            -- Cardiac arrest: 46-51% national → ~55-68% in our system (WORSE)
            WHEN 'cardiac_arrest' THEN 
                CASE 
                    WHEN ab.age > 80 THEN ROUND(UNIFORM(0.58, 0.72, RANDOM()), 3)
                    WHEN ab.age > 65 THEN ROUND(UNIFORM(0.52, 0.62, RANDOM()), 3)
                    ELSE ROUND(UNIFORM(0.46, 0.56, RANDOM()), 3)
                END
            -- Sepsis: 13-20% national → ~20-32% in our system (WORSE - major problem area)
            WHEN 'sepsis' THEN 
                CASE 
                    WHEN ab.age > 80 THEN ROUND(UNIFORM(0.28, 0.38, RANDOM()), 3)
                    WHEN ab.age > 65 THEN ROUND(UNIFORM(0.20, 0.28, RANDOM()), 3)
                    ELSE ROUND(UNIFORM(0.14, 0.22, RANDOM()), 3)
                END
            -- AMI: 3-7% national → ~5-11% in our system (WORSE)
            WHEN 'ami' THEN 
                CASE 
                    WHEN ab.age > 80 THEN ROUND(UNIFORM(0.10, 0.16, RANDOM()), 3)
                    WHEN ab.age > 65 THEN ROUND(UNIFORM(0.06, 0.11, RANDOM()), 3)
                    ELSE ROUND(UNIFORM(0.03, 0.07, RANDOM()), 3)
                END
            -- Heart failure: 8-12% national → ~12-20% in our system (WORSE)
            WHEN 'heart_failure' THEN 
                CASE 
                    WHEN ab.age > 80 THEN ROUND(UNIFORM(0.16, 0.24, RANDOM()), 3)
                    WHEN ab.age > 65 THEN ROUND(UNIFORM(0.11, 0.17, RANDOM()), 3)
                    ELSE ROUND(UNIFORM(0.07, 0.12, RANDOM()), 3)
                END
            -- COPD: 2-4% national → ~4-8% in our system (WORSE)
            WHEN 'copd' THEN 
                CASE 
                    WHEN ab.age > 80 THEN ROUND(UNIFORM(0.06, 0.11, RANDOM()), 3)
                    WHEN ab.age > 65 THEN ROUND(UNIFORM(0.03, 0.07, RANDOM()), 3)
                    ELSE ROUND(UNIFORM(0.02, 0.05, RANDOM()), 3)
                END
            -- Pneumonia: 5-10% national → ~9-16% in our system (WORSE)
            WHEN 'pneumonia' THEN 
                CASE 
                    WHEN ab.age > 80 THEN ROUND(UNIFORM(0.13, 0.20, RANDOM()), 3)
                    WHEN ab.age > 65 THEN ROUND(UNIFORM(0.08, 0.14, RANDOM()), 3)
                    ELSE ROUND(UNIFORM(0.05, 0.10, RANDOM()), 3)
                END
            -- Respiratory failure: 15-25% national → ~24-38% in our system (WORSE)
            WHEN 'resp_failure' THEN 
                CASE 
                    WHEN ab.age > 80 THEN ROUND(UNIFORM(0.32, 0.45, RANDOM()), 3)
                    WHEN ab.age > 65 THEN ROUND(UNIFORM(0.24, 0.34, RANDOM()), 3)
                    ELSE ROUND(UNIFORM(0.18, 0.26, RANDOM()), 3)
                END
            -- Other conditions: elevated baseline
            ELSE 
                CASE 
                    WHEN ab.age > 85 THEN ROUND(UNIFORM(0.03, 0.07, RANDOM()), 3)
                    WHEN ab.age > 75 THEN ROUND(UNIFORM(0.015, 0.04, RANDOM()), 3)
                    WHEN ab.age > 65 THEN ROUND(UNIFORM(0.008, 0.022, RANDOM()), 3)
                    WHEN ab.age > 50 THEN ROUND(UNIFORM(0.005, 0.014, RANDOM()), 3)
                    ELSE ROUND(UNIFORM(0.002, 0.008, RANDOM()), 3)
                END
        END AS base_mortality_risk
    FROM admission_base ab
),
-- Apply TIME-BASED TREND DEGRADATION (quality gets progressively worse)
-- This creates the "concerning trend" the CQO needs to identify and address
admission_with_mortality AS (
    SELECT 
        awbm.admission_id,
        awbm.patient_id,
        awbm.age,
        awbm.admission_date,
        awbm.admission_type,
        awbm.diagnosis_category,
        awbm.severity_of_illness_score,
        awbm.quarters_elapsed,
        awbm.base_mortality_risk,
        -- Apply compounding degradation: risk increases ~6% each quarter
        -- Q1: 1.0x, Q2: 1.06x, Q3: 1.12x, Q4: 1.19x, Q5: 1.26x, Q6: 1.34x, Q7: 1.42x, Q8: 1.50x
        -- This means mortality is ~50% higher by end of 2-year period vs beginning
        LEAST(0.95, ROUND(awbm.base_mortality_risk * POWER(1 + $trend_degradation, awbm.quarters_elapsed), 3)) AS mortality_risk_score
    FROM admission_with_base_mortality awbm
)
SELECT 
    admission_id,
    patient_id,
    admission_date,
    NULL AS discharge_date, -- Will be calculated later
    admission_type,
    -- REALISTIC mortality: die only if random chance is less than mortality risk
    -- This uses the condition-specific mortality rates from admission_with_mortality
    CASE 
        WHEN UNIFORM(1, 1000, RANDOM()) / 1000.0 < mortality_risk_score THEN 'Expired'
        WHEN UNIFORM(1, 100, RANDOM()) <= 5 THEN 'Transfer' 
        WHEN UNIFORM(1, 100, RANDOM()) <= 2 THEN 'AMA'
        WHEN UNIFORM(1, 100, RANDOM()) <= 15 THEN 'SNF' -- Skilled nursing facility
        WHEN UNIFORM(1, 100, RANDOM()) <= 8 THEN 'Rehab'
        ELSE 'Home'
    END AS discharge_disposition,
    -- Service based on diagnosis category and age
    CASE 
        WHEN diagnosis_category IN ('cardiac_arrest', 'sepsis', 'resp_failure') THEN 'ICU'
        WHEN diagnosis_category IN ('ami', 'heart_failure') THEN 'Cardiology'
        WHEN diagnosis_category IN ('copd', 'pneumonia') AND age > 70 THEN 'ICU'
        WHEN diagnosis_category IN ('copd', 'pneumonia') THEN 'Medicine'
        WHEN age > 75 AND admission_type = 'Emergency' AND UNIFORM(1, 100, RANDOM()) <= 40 THEN 'ICU'
        WHEN admission_type = 'Emergency' AND UNIFORM(1, 100, RANDOM()) <= 25 THEN 'ICU'
        WHEN admission_type = 'Elective' AND UNIFORM(1, 100, RANDOM()) <= 60 THEN 'Surgery'
        WHEN UNIFORM(1, 100, RANDOM()) <= 45 THEN 'Medicine'
        WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN 'Surgery'
        WHEN UNIFORM(1, 100, RANDOM()) <= 85 THEN 'Cardiology'
        ELSE 'Emergency'
    END AS primary_service,
    -- Room type based on diagnosis category and severity
    CASE 
        WHEN diagnosis_category IN ('cardiac_arrest', 'sepsis', 'resp_failure') THEN 'ICU'
        WHEN severity_of_illness_score >= 3.5 OR admission_type = 'Emergency' AND UNIFORM(1, 100, RANDOM()) <= 30 THEN 'ICU'
        WHEN severity_of_illness_score >= 3.0 AND UNIFORM(1, 100, RANDOM()) <= 20 THEN 'Step-down'
        WHEN UNIFORM(1, 100, RANDOM()) <= 5 THEN 'Emergency'
        ELSE 'Med-Surg'
    END AS room_type,
    -- Length of stay based on age, severity, diagnosis category
    CASE 
        WHEN diagnosis_category = 'cardiac_arrest' THEN UNIFORM(7, 28, RANDOM())  -- Longer for arrests
        WHEN diagnosis_category = 'sepsis' THEN UNIFORM(5, 21, RANDOM())          -- Sepsis typically longer
        WHEN diagnosis_category = 'resp_failure' THEN UNIFORM(6, 21, RANDOM())    -- Resp failure
        WHEN age > 80 AND severity_of_illness_score >= 3.0 THEN UNIFORM(5, 21, RANDOM())
        WHEN age > 65 AND severity_of_illness_score >= 2.5 THEN UNIFORM(3, 14, RANDOM())
        WHEN severity_of_illness_score >= 3.0 THEN UNIFORM(4, 18, RANDOM())
        WHEN admission_type = 'Elective' THEN UNIFORM(1, 5, RANDOM())
        ELSE UNIFORM(2, 8, RANDOM())
    END AS length_of_stay_days,
    CASE (UNIFORM(1, 10, RANDOM()))
        WHEN 1 THEN 'Dr. Smith' WHEN 2 THEN 'Dr. Johnson' WHEN 3 THEN 'Dr. Williams'
        WHEN 4 THEN 'Dr. Brown' WHEN 5 THEN 'Dr. Jones' WHEN 6 THEN 'Dr. Garcia'
        WHEN 7 THEN 'Dr. Miller' WHEN 8 THEN 'Dr. Davis' WHEN 9 THEN 'Dr. Rodriguez'
        ELSE 'Dr. Martinez'
    END AS attending_physician,
    FALSE AS is_readmission,
    NULL AS days_since_last_discharge,
    severity_of_illness_score,
    mortality_risk_score
FROM admission_with_mortality

UNION ALL

-- Additional admissions (readmissions/multiple admissions for chronic patients)
SELECT 
    admission_id,
    patient_id,
    admission_date,
    NULL AS discharge_date,
    admission_type,
    CASE 
        WHEN UNIFORM(1, 1000, RANDOM()) / 1000.0 < mortality_risk_score THEN 'Expired'
        WHEN UNIFORM(1, 100, RANDOM()) <= 5 THEN 'Transfer' 
        WHEN UNIFORM(1, 100, RANDOM()) <= 2 THEN 'AMA'
        WHEN UNIFORM(1, 100, RANDOM()) <= 18 THEN 'SNF' -- Higher SNF rate for readmissions
        WHEN UNIFORM(1, 100, RANDOM()) <= 10 THEN 'Rehab'
        ELSE 'Home'
    END AS discharge_disposition,
    CASE 
        WHEN diagnosis_category IN ('cardiac_arrest', 'sepsis', 'resp_failure') THEN 'ICU'
        WHEN diagnosis_category IN ('ami', 'heart_failure') THEN 'Cardiology'
        WHEN diagnosis_category IN ('copd', 'pneumonia') AND age > 70 THEN 'ICU'
        WHEN diagnosis_category IN ('copd', 'pneumonia') THEN 'Medicine'
        ELSE 'Medicine'
    END AS primary_service,
    CASE 
        WHEN diagnosis_category IN ('cardiac_arrest', 'sepsis', 'resp_failure') THEN 'ICU'
        WHEN severity_of_illness_score >= 3.5 THEN 'ICU'
        WHEN severity_of_illness_score >= 3.0 THEN 'Step-down'
        ELSE 'Med-Surg'
    END AS room_type,
    -- Readmissions often have longer LOS
    CASE 
        WHEN diagnosis_category IN ('sepsis', 'heart_failure') THEN UNIFORM(5, 18, RANDOM())
        WHEN age > 80 THEN UNIFORM(4, 14, RANDOM())
        ELSE UNIFORM(3, 10, RANDOM())
    END AS length_of_stay_days,
    CASE (UNIFORM(1, 10, RANDOM()))
        WHEN 1 THEN 'Dr. Smith' WHEN 2 THEN 'Dr. Johnson' WHEN 3 THEN 'Dr. Williams'
        WHEN 4 THEN 'Dr. Brown' WHEN 5 THEN 'Dr. Jones' WHEN 6 THEN 'Dr. Garcia'
        WHEN 7 THEN 'Dr. Miller' WHEN 8 THEN 'Dr. Davis' WHEN 9 THEN 'Dr. Rodriguez'
        ELSE 'Dr. Martinez'
    END AS attending_physician,
    TRUE AS is_readmission, -- Flag these as readmissions
    UNIFORM(30, 180, RANDOM()) AS days_since_last_discharge,
    severity_of_illness_score,
    mortality_risk_score
FROM additional_with_mortality;

-- Update discharge dates based on length of stay
UPDATE ADMISSIONS 
SET discharge_date = DATEADD(DAY, length_of_stay_days, admission_date);

-- 3. Generate REALISTIC DIAGNOSES with proper comorbidity patterns
INSERT INTO DIAGNOSES (
    diagnosis_id, admission_id, patient_id, icd10_code, diagnosis_description, 
    diagnosis_type, present_on_admission, diagnosis_date, physician_name,
    complication_flag, hospital_acquired
)
WITH patient_ages AS (
    SELECT 
        a.admission_id,
        a.patient_id,
        DATEDIFF(YEAR, p.date_of_birth, a.admission_date) AS age,
        a.discharge_disposition,
        a.primary_service,
        a.severity_of_illness_score,
        a.admission_date
    FROM ADMISSIONS a
    JOIN PATIENTS p ON a.patient_id = p.patient_id
),
-- Primary diagnoses based on age and service
primary_diagnoses AS (
    SELECT 
        'DX' || LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM()), 10, '0') AS diagnosis_id,
        pa.admission_id,
        pa.patient_id,
        -- Age-appropriate primary diagnoses
        CASE 
            WHEN pa.discharge_disposition = 'Expired' THEN
                CASE 
                    WHEN UNIFORM(1, 100, RANDOM()) <= 25 THEN 'A41.9'  -- Sepsis
                    WHEN UNIFORM(1, 100, RANDOM()) <= 45 THEN 'I46.9'  -- Cardiac arrest
                    WHEN UNIFORM(1, 100, RANDOM()) <= 60 THEN 'J44.0'  -- COPD with exacerbation
                    WHEN UNIFORM(1, 100, RANDOM()) <= 75 THEN 'I50.9'  -- Heart failure
                    WHEN UNIFORM(1, 100, RANDOM()) <= 85 THEN 'J96.00' -- Respiratory failure
                    WHEN UNIFORM(1, 100, RANDOM()) <= 95 THEN 'R65.20' -- Severe sepsis
                    ELSE 'I21.9' -- Acute MI
                END
            WHEN pa.age > 75 THEN
                CASE 
                    WHEN UNIFORM(1, 100, RANDOM()) <= 20 THEN 'I50.9'  -- Heart failure
                    WHEN UNIFORM(1, 100, RANDOM()) <= 35 THEN 'J44.1'  -- COPD
                    WHEN UNIFORM(1, 100, RANDOM()) <= 50 THEN 'N39.0'  -- UTI
                    WHEN UNIFORM(1, 100, RANDOM()) <= 65 THEN 'I10'    -- Hypertension
                    WHEN UNIFORM(1, 100, RANDOM()) <= 75 THEN 'E11.9'  -- Diabetes
                    WHEN UNIFORM(1, 100, RANDOM()) <= 85 THEN 'G93.1'  -- Anoxic brain damage
                    WHEN UNIFORM(1, 100, RANDOM()) <= 90 THEN 'S72.9'  -- Hip fracture
                    ELSE 'J18.9' -- Pneumonia
                END
            WHEN pa.primary_service = 'Surgery' THEN
                CASE 
                    WHEN UNIFORM(1, 100, RANDOM()) <= 25 THEN 'K80.2'  -- Gallstones
                    WHEN UNIFORM(1, 100, RANDOM()) <= 40 THEN 'K57.9'  -- Diverticulitis
                    WHEN UNIFORM(1, 100, RANDOM()) <= 55 THEN 'M25.5'  -- Joint pain
                    WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN 'K40.9'  -- Inguinal hernia
                    WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN 'I25.1'  -- CAD
                    WHEN UNIFORM(1, 100, RANDOM()) <= 90 THEN 'K35.9'  -- Appendicitis
                    ELSE 'C78.0' -- Secondary malignancy
                END
            WHEN pa.primary_service = 'ICU' THEN
                CASE 
                    WHEN UNIFORM(1, 100, RANDOM()) <= 30 THEN 'A41.9'  -- Sepsis
                    WHEN UNIFORM(1, 100, RANDOM()) <= 50 THEN 'J96.00' -- Respiratory failure
                    WHEN UNIFORM(1, 100, RANDOM()) <= 65 THEN 'I46.9'  -- Cardiac arrest
                    WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN 'R65.20' -- Severe sepsis
                    WHEN UNIFORM(1, 100, RANDOM()) <= 90 THEN 'I21.9'  -- Acute MI
                    ELSE 'G93.1' -- Anoxic brain damage
                END
            ELSE
                CASE 
                    WHEN UNIFORM(1, 100, RANDOM()) <= 15 THEN 'I50.9'  -- Heart failure
                    WHEN UNIFORM(1, 100, RANDOM()) <= 25 THEN 'J18.9'  -- Pneumonia
                    WHEN UNIFORM(1, 100, RANDOM()) <= 35 THEN 'E11.9'  -- Diabetes
                    WHEN UNIFORM(1, 100, RANDOM()) <= 45 THEN 'I10'    -- Hypertension
                    WHEN UNIFORM(1, 100, RANDOM()) <= 55 THEN 'N39.0'  -- UTI
                    WHEN UNIFORM(1, 100, RANDOM()) <= 65 THEN 'J44.1'  -- COPD
                    WHEN UNIFORM(1, 100, RANDOM()) <= 75 THEN 'K59.0'  -- Constipation
                    WHEN UNIFORM(1, 100, RANDOM()) <= 85 THEN 'R50.9'  -- Fever
                    WHEN UNIFORM(1, 100, RANDOM()) <= 95 THEN 'G47.0'  -- Sleep apnea
                    ELSE 'M79.3' -- Panniculitis
                END
        END AS icd10_code,
        'Primary' AS diagnosis_type,
        TRUE AS present_on_admission,
        pa.admission_date AS diagnosis_date,
        FALSE AS complication_flag,
        FALSE AS hospital_acquired
    FROM patient_ages pa
)
SELECT 
    pd.diagnosis_id,
    pd.admission_id,
    pd.patient_id,
    pd.icd10_code,
    -- Add realistic descriptions for codes
    CASE pd.icd10_code
        WHEN 'A41.9' THEN 'Sepsis, unspecified organism'
        WHEN 'I46.9' THEN 'Cardiac arrest, cause unspecified'
        WHEN 'J44.0' THEN 'Chronic obstructive pulmonary disease with acute exacerbation'
        WHEN 'I50.9' THEN 'Heart failure, unspecified'
        WHEN 'J96.00' THEN 'Acute respiratory failure, unspecified whether with hypoxia or hypercapnia'
        WHEN 'R65.20' THEN 'Severe sepsis without septic shock'
        WHEN 'I21.9' THEN 'Acute myocardial infarction, unspecified'
        WHEN 'J44.1' THEN 'Chronic obstructive pulmonary disease with acute exacerbation'
        WHEN 'N39.0' THEN 'Urinary tract infection, site not specified'
        WHEN 'I10' THEN 'Essential hypertension'
        WHEN 'E11.9' THEN 'Type 2 diabetes mellitus without complications'
        WHEN 'G93.1' THEN 'Anoxic brain damage, not elsewhere classified'
        WHEN 'S72.9' THEN 'Unspecified fracture of unspecified part of unspecified femur'
        WHEN 'J18.9' THEN 'Pneumonia, unspecified organism'
        WHEN 'K80.2' THEN 'Calculus of gallbladder without cholangitis or cholecystitis'
        WHEN 'K57.9' THEN 'Diverticular disease of intestine, part unspecified, without perforation or abscess'
        WHEN 'M25.5' THEN 'Pain in joint'
        WHEN 'K40.9' THEN 'Unilateral or unspecified inguinal hernia, without obstruction or gangrene'
        WHEN 'I25.1' THEN 'Atherosclerotic heart disease of native coronary artery'
        WHEN 'K35.9' THEN 'Acute appendicitis, unspecified'
        WHEN 'C78.0' THEN 'Secondary malignant neoplasm of lung'
        WHEN 'K59.0' THEN 'Constipation'
        WHEN 'R50.9' THEN 'Fever, unspecified'
        WHEN 'G47.0' THEN 'Disorders of initiating and maintaining sleep'
        ELSE 'Other specified condition'
    END AS diagnosis_description,
    pd.diagnosis_type,
    pd.present_on_admission,
    pd.diagnosis_date,
    'Dr. Attending' AS physician_name,
    pd.complication_flag,
    pd.hospital_acquired
FROM primary_diagnoses pd;

COMMIT;

-- ========================================
-- VERIFICATION QUERIES - VOLUME & BENCHMARK COMPARISON
-- ========================================

-- 0. Health System Volume Summary
SELECT 
    'HEALTH SYSTEM VOLUME SUMMARY' AS metric,
    (SELECT COUNT(*) FROM PATIENTS) AS total_patients,
    COUNT(*) AS total_admissions,
    ROUND(COUNT(*) / 2.0, 0) AS approx_admissions_per_year,
    COUNT(DISTINCT patient_id) AS unique_patients_admitted,
    SUM(CASE WHEN is_readmission = TRUE THEN 1 ELSE 0 END) AS readmissions,
    ROUND(SUM(CASE WHEN is_readmission = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS readmission_rate_pct,
    ROUND(AVG(length_of_stay_days), 1) AS avg_length_of_stay
FROM ADMISSIONS;

-- 1. Overall Hospital Mortality (Target: 1.5-2.5%)
SELECT 
    'OVERALL HOSPITAL MORTALITY (National Avg: 1.5-2.5%)' AS metric,
    COUNT(*) AS total_admissions,
    SUM(CASE WHEN discharge_disposition = 'Expired' THEN 1 ELSE 0 END) AS deaths,
    ROUND(SUM(CASE WHEN discharge_disposition = 'Expired' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS death_rate_percent
FROM ADMISSIONS;

-- 2. Discharge Disposition Distribution
SELECT 
    discharge_disposition,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS percentage
FROM ADMISSIONS
GROUP BY discharge_disposition
ORDER BY count DESC;

-- 3. Mortality by Primary Diagnosis (Validates condition-specific rates)
-- National Benchmarks:
-- Cardiac Arrest: 46-51% | Sepsis: 13-20% | AMI: 3-7% | Heart Failure: 8-12%
-- COPD: 2-4% | Pneumonia: 5-10% | Respiratory Failure: 15-25%
SELECT 
    CASE d.icd10_code
        WHEN 'I46.9' THEN '1-Cardiac Arrest (Target: 46-51%)'
        WHEN 'A41.9' THEN '2-Sepsis (Target: 13-20%)'
        WHEN 'R65.20' THEN '3-Severe Sepsis (Target: 18-25%)'
        WHEN 'I21.9' THEN '4-AMI (Target: 3-7%)'
        WHEN 'I50.9' THEN '5-Heart Failure (Target: 8-12%)'
        WHEN 'J44.0' THEN '6-COPD Exacerbation (Target: 2-4%)'
        WHEN 'J44.1' THEN '6-COPD (Target: 2-4%)'
        WHEN 'J18.9' THEN '7-Pneumonia (Target: 5-10%)'
        WHEN 'J96.00' THEN '8-Resp Failure (Target: 15-25%)'
        ELSE '9-Other Conditions'
    END AS diagnosis_group,
    COUNT(*) AS total_cases,
    SUM(CASE WHEN a.discharge_disposition = 'Expired' THEN 1 ELSE 0 END) AS deaths,
    ROUND(SUM(CASE WHEN a.discharge_disposition = 'Expired' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS mortality_rate_pct
FROM ADMISSIONS a
JOIN DIAGNOSES d ON a.admission_id = d.admission_id AND d.diagnosis_type = 'Primary'
GROUP BY 
    CASE d.icd10_code
        WHEN 'I46.9' THEN '1-Cardiac Arrest (Target: 46-51%)'
        WHEN 'A41.9' THEN '2-Sepsis (Target: 13-20%)'
        WHEN 'R65.20' THEN '3-Severe Sepsis (Target: 18-25%)'
        WHEN 'I21.9' THEN '4-AMI (Target: 3-7%)'
        WHEN 'I50.9' THEN '5-Heart Failure (Target: 8-12%)'
        WHEN 'J44.0' THEN '6-COPD Exacerbation (Target: 2-4%)'
        WHEN 'J44.1' THEN '6-COPD (Target: 2-4%)'
        WHEN 'J18.9' THEN '7-Pneumonia (Target: 5-10%)'
        WHEN 'J96.00' THEN '8-Resp Failure (Target: 15-25%)'
        ELSE '9-Other Conditions'
    END
ORDER BY diagnosis_group;

-- 4. Mortality by Age Group
SELECT 
    CASE 
        WHEN DATEDIFF(YEAR, p.date_of_birth, a.admission_date) < 50 THEN 'Under 50'
        WHEN DATEDIFF(YEAR, p.date_of_birth, a.admission_date) < 65 THEN '50-64'
        WHEN DATEDIFF(YEAR, p.date_of_birth, a.admission_date) < 75 THEN '65-74'
        WHEN DATEDIFF(YEAR, p.date_of_birth, a.admission_date) < 85 THEN '75-84'
        ELSE '85+'
    END AS age_group,
    COUNT(*) AS total_admissions,
    SUM(CASE WHEN a.discharge_disposition = 'Expired' THEN 1 ELSE 0 END) AS deaths,
    ROUND(SUM(CASE WHEN a.discharge_disposition = 'Expired' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS death_rate_percent
FROM ADMISSIONS a
JOIN PATIENTS p ON a.patient_id = p.patient_id
GROUP BY 
    CASE 
        WHEN DATEDIFF(YEAR, p.date_of_birth, a.admission_date) < 50 THEN 'Under 50'
        WHEN DATEDIFF(YEAR, p.date_of_birth, a.admission_date) < 65 THEN '50-64'
        WHEN DATEDIFF(YEAR, p.date_of_birth, a.admission_date) < 75 THEN '65-74'
        WHEN DATEDIFF(YEAR, p.date_of_birth, a.admission_date) < 85 THEN '75-84'
        ELSE '85+'
    END
ORDER BY age_group;

-- 5. ICU Mortality Rate (National Avg: 8-15%)
SELECT 
    'ICU MORTALITY (National Avg: 8-15%)' AS metric,
    COUNT(*) AS icu_admissions,
    SUM(CASE WHEN discharge_disposition = 'Expired' THEN 1 ELSE 0 END) AS icu_deaths,
    ROUND(SUM(CASE WHEN discharge_disposition = 'Expired' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS icu_mortality_pct
FROM ADMISSIONS
WHERE room_type = 'ICU' OR primary_service = 'ICU';

-- ========================================
-- TREND ANALYSIS - SHOWS WORSENING QUALITY OVER TIME
-- This is the key insight for the CQO demo!
-- ========================================

-- 6. QUARTERLY MORTALITY TREND (Should show increasing mortality)
SELECT 
    'QUARTERLY MORTALITY TREND (Concerning!)' AS analysis_type,
    DATE_TRUNC('quarter', admission_date) AS quarter,
    COUNT(*) AS admissions,
    SUM(CASE WHEN discharge_disposition = 'Expired' THEN 1 ELSE 0 END) AS deaths,
    ROUND(SUM(CASE WHEN discharge_disposition = 'Expired' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS mortality_rate_pct,
    ROUND(AVG(mortality_risk_score) * 100, 2) AS avg_risk_score_pct
FROM ADMISSIONS
GROUP BY DATE_TRUNC('quarter', admission_date)
ORDER BY quarter;

-- 7. QUARTERLY SEPSIS MORTALITY TREND (Major problem area)
SELECT 
    'QUARTERLY SEPSIS MORTALITY (Major Concern!)' AS analysis_type,
    DATE_TRUNC('quarter', a.admission_date) AS quarter,
    COUNT(*) AS sepsis_cases,
    SUM(CASE WHEN a.discharge_disposition = 'Expired' THEN 1 ELSE 0 END) AS sepsis_deaths,
    ROUND(SUM(CASE WHEN a.discharge_disposition = 'Expired' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS sepsis_mortality_pct
FROM ADMISSIONS a
JOIN DIAGNOSES d ON a.admission_id = d.admission_id 
WHERE d.diagnosis_type = 'Primary' 
  AND d.icd10_code IN ('A41.9', 'R65.20')
GROUP BY DATE_TRUNC('quarter', a.admission_date)
ORDER BY quarter;

-- 8. PREVENTABLE DEATHS ANALYSIS
SELECT 
    'PREVENTABLE DEATHS ANALYSIS' AS analysis_type,
    COUNT(*) AS total_deaths,
    SUM(CASE WHEN preventable = TRUE THEN 1 ELSE 0 END) AS preventable_deaths,
    ROUND(SUM(CASE WHEN preventable = TRUE THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS preventable_pct,
    SUM(CASE WHEN infection_related = TRUE THEN 1 ELSE 0 END) AS infection_related_deaths,
    SUM(CASE WHEN quality_issue_related = TRUE THEN 1 ELSE 0 END) AS quality_issue_deaths,
    SUM(CASE WHEN procedure_related = TRUE THEN 1 ELSE 0 END) AS procedure_related_deaths
FROM OUTCOMES
WHERE outcome_type = 'Death';

-- 9. PREVENTABLE DEATHS BY QUARTER (Shows increasing preventable deaths)
SELECT 
    'PREVENTABLE DEATHS TREND (Action Needed!)' AS analysis_type,
    DATE_TRUNC('quarter', outcome_date) AS quarter,
    COUNT(*) AS total_deaths,
    SUM(CASE WHEN preventable = TRUE THEN 1 ELSE 0 END) AS preventable_deaths,
    ROUND(SUM(CASE WHEN preventable = TRUE THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS preventable_pct
FROM OUTCOMES
WHERE outcome_type = 'Death'
GROUP BY DATE_TRUNC('quarter', outcome_date)
ORDER BY quarter; 


-- Clinical Quality and Patient Safety Demo - REALISTIC Data Generation Part 2
-- Generate procedures, infections, quality events, outcomes, and risk factors
-- with proper clinical relationships and realistic statistics

USE DATABASE SF_SOLUTIONS;
USE SCHEMA CLINICAL_QUALITY_SAFETY;

-- 4. Generate PROCEDURES with realistic diagnosis-procedure relationships
INSERT INTO PROCEDURES (
    procedure_id, admission_id, patient_id, cpt_code, icd10_procedure_code,
    procedure_description, procedure_date, procedure_type, procedure_location,
    surgeon_name, anesthesia_type, procedure_duration_minutes, complication_occurred, infection_risk_level
)
WITH procedure_data AS (
    SELECT 
        'PROC' || LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM()), 10, '0') AS procedure_id,
        a.admission_id,
        a.patient_id,
        d.icd10_code AS primary_diagnosis,
        a.primary_service,
        a.room_type,
        DATEDIFF(YEAR, p.date_of_birth, a.admission_date) AS age,
        a.admission_date,
        a.length_of_stay_days,
        -- Procedure based on primary diagnosis (realistic patterns)
        CASE d.icd10_code
            -- Cardiac procedures for cardiac diagnoses
            WHEN 'I50.9' THEN CASE WHEN UNIFORM(1,4,RANDOM()) = 1 THEN '33533' ELSE '93458' END -- Heart cath/CABG
            WHEN 'I46.9' THEN '92950' -- CPR
            WHEN 'I21.9' THEN CASE WHEN UNIFORM(1,3,RANDOM()) = 1 THEN '92982' ELSE '93458' END -- PCI/cath
            WHEN 'I25.1' THEN '93458' -- Cardiac catheterization
            -- Respiratory procedures for resp diagnoses  
            WHEN 'J44.0' THEN CASE WHEN UNIFORM(1,3,RANDOM()) = 1 THEN '31500' ELSE '94010' END -- Intubation/PFT
            WHEN 'J96.00' THEN '31500' -- Intubation for resp failure
            WHEN 'J18.9' THEN CASE WHEN UNIFORM(1,4,RANDOM()) = 1 THEN '31500' ELSE '71020' END -- Intubation/CXR
            -- Surgical procedures for surgical diagnoses
            WHEN 'K80.2' THEN '47562' -- Laparoscopic cholecystectomy
            WHEN 'K35.9' THEN '44970' -- Laparoscopic appendectomy
            WHEN 'K40.9' THEN '49505' -- Inguinal hernia repair
            WHEN 'K57.9' THEN '44205' -- Laparoscopic partial colectomy
            WHEN 'S72.9' THEN '27447' -- Total knee replacement (hip fracture treatment)
            WHEN 'C78.0' THEN CASE WHEN UNIFORM(1,3,RANDOM()) = 1 THEN '32663' ELSE '38221' END -- Lung biopsy/LN biopsy
            -- Common procedures for other diagnoses
            WHEN 'N39.0' THEN '51702' -- Foley catheter for UTI
            WHEN 'A41.9' THEN CASE WHEN UNIFORM(1,3,RANDOM()) = 1 THEN '36556' ELSE '51702' END -- Central line/foley for sepsis
            WHEN 'R65.20' THEN CASE WHEN UNIFORM(1,2,RANDOM()) = 1 THEN '36556' ELSE '51702' END -- Central line/foley for severe sepsis  
            WHEN 'I46.9' THEN '51702' -- Foley catheter for cardiac arrest (fluid monitoring)
            WHEN 'J96.00' THEN '51702' -- Foley catheter for respiratory failure (fluid management)
            WHEN 'I50.9' THEN CASE WHEN UNIFORM(1,3,RANDOM()) = 1 THEN '51702' ELSE '36415' END -- Foley/blood draw for heart failure
            ELSE 
                (WITH random_proc AS (SELECT UNIFORM(1, 100, RANDOM()) AS rand_val)
                SELECT CASE 
                    WHEN rand_val <= 20 THEN '36415' -- Venipuncture: 20%
                    WHEN rand_val <= 35 THEN '51702' -- Foley catheter: 15% (cumulative 35%)
                    WHEN rand_val <= 50 THEN '93010' -- EKG: 15% (cumulative 50%)
                    WHEN rand_val <= 65 THEN '71020' -- Chest X-ray: 15% (cumulative 65%)
                    WHEN rand_val <= 80 THEN '36556' -- Central line: 15% (cumulative 80%)
                    ELSE '99213' -- Office visit: 20%
                END FROM random_proc)
        END AS cpt_code,
        -- ICD-10 procedure codes
        CASE d.icd10_code
            WHEN 'I50.9' THEN CASE WHEN UNIFORM(1,4,RANDOM()) = 1 THEN '021K0JZ' ELSE '4A023N7' END
            WHEN 'I46.9' THEN '5A12012'
            WHEN 'I21.9' THEN '4A023N7'
            WHEN 'J44.0' THEN CASE WHEN UNIFORM(1,3,RANDOM()) = 1 THEN '0BH17EZ' ELSE '4A09XBZ' END
            WHEN 'J96.00' THEN '0BH17EZ'
            WHEN 'K80.2' THEN '0FT40ZZ'
            WHEN 'K35.9' THEN '0DTJ0ZZ'
            WHEN 'N39.0' THEN '0TJB0ZZ'
            WHEN 'A41.9' THEN '05H033Z'
            ELSE '3E0G76Z'
        END AS icd10_procedure_code
    FROM ADMISSIONS a
    JOIN PATIENTS p ON a.patient_id = p.patient_id
    LEFT JOIN DIAGNOSES d ON a.admission_id = d.admission_id AND d.diagnosis_type = 'Primary'
    WHERE 
        -- Realistic procedure rates based on service line
        (a.primary_service = 'Surgery' AND UNIFORM(1, 100, RANDOM()) <= 85) OR  -- 85% surgery patients get procedures
        (a.primary_service = 'ICU' AND UNIFORM(1, 100, RANDOM()) <= 90) OR      -- 90% ICU patients get procedures
        (a.primary_service = 'Cardiology' AND UNIFORM(1, 100, RANDOM()) <= 75) OR -- 75% cardiology patients
        (a.primary_service = 'Emergency' AND UNIFORM(1, 100, RANDOM()) <= 45) OR  -- 45% emergency patients
        (UNIFORM(1, 100, RANDOM()) <= 35) -- 35% other patients
)
SELECT 
    pd.procedure_id,
    pd.admission_id,
    pd.patient_id,
    pd.cpt_code,
    pd.icd10_procedure_code,
    -- Realistic procedure descriptions
    CASE pd.cpt_code
        WHEN '33533' THEN 'Coronary artery bypass graft'
        WHEN '93458' THEN 'Left heart catheterization'
        WHEN '92950' THEN 'Cardiopulmonary resuscitation'
        WHEN '92982' THEN 'Percutaneous coronary intervention'
        WHEN '31500' THEN 'Endotracheal intubation'
        WHEN '94010' THEN 'Pulmonary function test'
        WHEN '47562' THEN 'Laparoscopic cholecystectomy'
        WHEN '44970' THEN 'Laparoscopic appendectomy'
        WHEN '49505' THEN 'Inguinal hernia repair'
        WHEN '44205' THEN 'Laparoscopic partial colectomy'
        WHEN '27447' THEN 'Total knee arthroplasty'
        WHEN '32663' THEN 'Thoracoscopic lung biopsy'
        WHEN '38221' THEN 'Bone marrow biopsy'
        WHEN '51702' THEN 'Foley catheter insertion'
        WHEN '36556' THEN 'Central venous catheter insertion'
        WHEN '36415' THEN 'Venipuncture for blood draw'
        WHEN '93010' THEN 'Electrocardiogram'
        WHEN '71020' THEN 'Chest X-ray'
        ELSE 'Medical procedure'
    END AS procedure_description,
    DATEADD(HOUR, 
        CASE 
            WHEN pd.length_of_stay_days > 2 THEN UNIFORM(1, 72, RANDOM()) -- Up to 3 days for longer stays
            ELSE UNIFORM(1, 24, RANDOM()) -- Within 1 day for short stays
        END, 
        pd.admission_date) AS procedure_date,
    -- Procedure type based on CPT code
    CASE 
        WHEN pd.cpt_code IN ('33533', '47562', '44970', '49505', '44205', '27447') THEN 'Surgical'
        WHEN pd.cpt_code IN ('93458', '92982', '32663', '38221') THEN 'Diagnostic'
        ELSE 'Therapeutic'
    END AS procedure_type,
    -- Location based on procedure type and complexity
    CASE 
        WHEN pd.cpt_code IN ('33533', '47562', '44970', '49505', '44205', '27447') THEN 'OR'
        WHEN pd.cpt_code IN ('93458', '92982') THEN 'Cardiac Cath Lab'
        WHEN pd.cpt_code IN ('31500', '92950') THEN 'ICU'
        WHEN pd.room_type = 'ICU' THEN 'ICU'
        WHEN pd.room_type = 'Emergency' THEN 'Emergency'
        ELSE 'Floor'
    END AS procedure_location,
    CASE (UNIFORM(1, 10, RANDOM()))
        WHEN 1 THEN 'Dr. Smith' WHEN 2 THEN 'Dr. Johnson' WHEN 3 THEN 'Dr. Williams'
        WHEN 4 THEN 'Dr. Brown' WHEN 5 THEN 'Dr. Jones' WHEN 6 THEN 'Dr. Garcia'
        WHEN 7 THEN 'Dr. Miller' WHEN 8 THEN 'Dr. Davis' WHEN 9 THEN 'Dr. Rodriguez'
        ELSE 'Dr. Martinez'
    END AS surgeon_name,
    -- Anesthesia type based on procedure
    CASE 
        WHEN pd.cpt_code IN ('33533', '47562', '44970', '49505', '44205', '27447') THEN 'General'
        WHEN pd.cpt_code IN ('93458', '92982', '32663', '38221') THEN 'Conscious sedation'
        WHEN pd.cpt_code = '31500' THEN 'General'
        WHEN pd.cpt_code IN ('36556', '51702') THEN 'Local'
        ELSE 'None'
    END AS anesthesia_type,
    -- Procedure duration based on complexity
    CASE 
        WHEN pd.cpt_code = '33533' THEN UNIFORM(240, 480, RANDOM()) -- CABG: 4-8 hours
        WHEN pd.cpt_code IN ('47562', '44970', '44205', '27447') THEN UNIFORM(60, 180, RANDOM()) -- Lap procedures: 1-3 hours
        WHEN pd.cpt_code IN ('93458', '92982') THEN UNIFORM(30, 90, RANDOM()) -- Cath procedures: 30-90 min
        WHEN pd.cpt_code = '31500' THEN UNIFORM(5, 15, RANDOM()) -- Intubation: 5-15 min
        WHEN pd.cpt_code IN ('36556', '51702') THEN UNIFORM(10, 30, RANDOM()) -- Line/catheter insertion: 10-30 min
        ELSE UNIFORM(5, 60, RANDOM()) -- Other procedures: 5-60 min
    END AS procedure_duration_minutes,
    -- Complication rate based on procedure complexity and patient age
    CASE 
        WHEN pd.cpt_code = '33533' AND pd.age > 75 THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 15 THEN TRUE ELSE FALSE END -- CABG in elderly: 15%
        WHEN pd.cpt_code = '33533' THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 8 THEN TRUE ELSE FALSE END -- CABG: 8%
        WHEN pd.cpt_code IN ('47562', '44970', '44205', '27447') THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 5 THEN TRUE ELSE FALSE END -- Major surgery: 5%
        WHEN pd.cpt_code IN ('93458', '92982') THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 3 THEN TRUE ELSE FALSE END -- Cath procedures: 3%
        WHEN pd.age > 80 THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 8 THEN TRUE ELSE FALSE END -- Elderly: higher risk
        ELSE CASE WHEN UNIFORM(1,100,RANDOM()) <= 2 THEN TRUE ELSE FALSE END -- General: 2%
    END AS complication_occurred,
    -- Infection risk based on procedure type
    CASE 
        WHEN pd.cpt_code IN ('33533', '47562', '44970', '49505', '44205', '27447') THEN 'High' -- Surgical procedures
        WHEN pd.cpt_code IN ('36556', '51702', '31500') THEN 'Medium' -- Device insertion
        ELSE 'Low' -- Diagnostic procedures
    END AS infection_risk_level
FROM procedure_data pd;

-- 5. Generate REALISTIC INFECTIONS with NATIONAL AVERAGE rates
-- Based on CDC/NHSN benchmarks 2024-2025:
-- CAUTI: 0.5-1.5 per 1,000 catheter days (~2-5% of catheterized patients for avg 5-day stay)
-- CLABSI: 0.5-1.0 per 1,000 central line days (~1-3% of patients with lines)
-- VAP: 0.5-2.0 per 1,000 ventilator days (~2-5% of ventilated patients)
-- SSI: 1-3% of surgical patients
-- C.diff: ~0.5% of hospitalized patients, higher in elderly/antibiotic exposed
INSERT INTO INFECTIONS (
    infection_id, admission_id, patient_id, infection_type, infection_site,
    pathogen, onset_date, resolution_date, days_to_onset, severity,
    device_associated, device_type, device_days, antibiotic_resistance,
    treatment_started_date, infection_preventable, contributed_to_death, healthcare_associated
)
WITH infection_candidates AS (
    SELECT 
        a.admission_id,
        a.patient_id,
        a.admission_date,
        a.discharge_date,
        a.length_of_stay_days,
        a.discharge_disposition,
        a.room_type,
        DATEDIFF(YEAR, p.date_of_birth, a.admission_date) AS age,
        -- Check if patient has high-risk procedures or devices
        COUNT(CASE WHEN pr.cpt_code IN ('36556', '51702', '31500') THEN 1 END) AS device_procedures,
        COUNT(CASE WHEN pr.infection_risk_level = 'High' THEN 1 END) AS high_risk_procedures,
        MAX(CASE WHEN pr.cpt_code = '36556' THEN 1 ELSE 0 END) AS has_central_line,
        MAX(CASE WHEN pr.cpt_code = '51702' THEN 1 ELSE 0 END) AS has_foley,
        MAX(CASE WHEN pr.cpt_code = '31500' THEN 1 ELSE 0 END) AS has_ventilator,
        MAX(CASE WHEN pr.infection_risk_level = 'High' THEN 1 ELSE 0 END) AS has_surgery
    FROM ADMISSIONS a
    JOIN PATIENTS p ON a.patient_id = p.patient_id
    LEFT JOIN PROCEDURES pr ON a.admission_id = pr.admission_id
    WHERE a.length_of_stay_days >= 2 -- Only patients with LOS >= 2 days can get HAI
    GROUP BY a.admission_id, a.patient_id, a.admission_date, a.discharge_date, 
             a.length_of_stay_days, a.discharge_disposition, a.room_type, p.date_of_birth
),
-- Calculate quarters for time-based HAI trend
infection_with_trend AS (
    SELECT 
        ic.*,
        FLOOR(DATEDIFF(DAY, $start_date::DATE, ic.admission_date) / 91.25) AS quarters_elapsed
    FROM infection_candidates ic
),
infection_data AS (
    SELECT 
        'INF' || LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM()), 10, '0') AS infection_id,
        iwt.admission_id,
        iwt.patient_id,
        -- Infection type based on devices - ELEVATED RATES (25% worse than national)
        -- Rates get progressively worse over time to show concerning trend
        CASE 
            -- CAUTI: ~5% of foley patients (national avg ~3%, ours is ~67% worse)
            WHEN iwt.has_foley = 1 AND UNIFORM(1, 100, RANDOM()) <= (5 * (1 + 0.04 * iwt.quarters_elapsed)) THEN 'CAUTI'
            -- CLABSI: ~3.5% of central line patients (national avg ~2%, ours is ~75% worse)
            WHEN iwt.has_central_line = 1 AND UNIFORM(1, 100, RANDOM()) <= (3.5 * (1 + 0.04 * iwt.quarters_elapsed)) THEN 'CLABSI'
            -- VAP: ~6% of ventilated patients (national avg ~4%, ours is ~50% worse)
            WHEN iwt.has_ventilator = 1 AND UNIFORM(1, 100, RANDOM()) <= (6 * (1 + 0.04 * iwt.quarters_elapsed)) THEN 'VAP'
            -- SSI: ~4% of surgery patients (national avg ~2%, ours is 2x worse)
            WHEN iwt.has_surgery = 1 AND UNIFORM(1, 100, RANDOM()) <= (4 * (1 + 0.03 * iwt.quarters_elapsed)) THEN 'SSI'
            -- C.diff: ~2.5% of elderly (national avg ~1.5%, ours is ~67% worse)
            WHEN iwt.age > 65 AND UNIFORM(1, 100, RANDOM()) <= (2.5 * (1 + 0.04 * iwt.quarters_elapsed)) THEN 'CDIFF'
            -- Hospital-acquired pneumonia: ~2% of ICU patients (national avg ~1%)
            WHEN iwt.room_type = 'ICU' AND UNIFORM(1, 100, RANDOM()) <= (2 * (1 + 0.03 * iwt.quarters_elapsed)) THEN 'Pneumonia'
            -- MRSA: ~1% general (national avg ~0.5%)
            WHEN UNIFORM(1, 100, RANDOM()) <= (1 * (1 + 0.03 * iwt.quarters_elapsed)) THEN 'MRSA'
            ELSE 'Sepsis'
        END AS infection_type,
        iwt.admission_date,
        iwt.length_of_stay_days,
        iwt.discharge_disposition,
        iwt.age,
        iwt.has_central_line,
        iwt.has_foley,
        iwt.has_ventilator,
        iwt.has_surgery,
        iwt.quarters_elapsed
    FROM infection_with_trend iwt
    WHERE 
        -- ELEVATED infection rates (~25% worse than national benchmarks)
        -- with time-based worsening trend
        (iwt.room_type = 'ICU' AND iwt.length_of_stay_days > 5 AND UNIFORM(1, 100, RANDOM()) <= (12 * (1 + 0.04 * iwt.quarters_elapsed))) OR -- ICU long stay: 12%+
        (iwt.device_procedures > 0 AND UNIFORM(1, 100, RANDOM()) <= (6 * (1 + 0.04 * iwt.quarters_elapsed))) OR -- Device-related: 6%+
        (iwt.high_risk_procedures > 0 AND UNIFORM(1, 100, RANDOM()) <= (5 * (1 + 0.03 * iwt.quarters_elapsed))) OR -- Surgery-related: 5%+
        (iwt.age > 75 AND iwt.length_of_stay_days > 7 AND UNIFORM(1, 100, RANDOM()) <= (8 * (1 + 0.04 * iwt.quarters_elapsed))) OR -- Elderly long stay: 8%+
        (UNIFORM(1, 100, RANDOM()) <= (1.0 * (1 + 0.03 * iwt.quarters_elapsed))) -- General population: 1%+
)
SELECT 
    id.infection_id,
    id.admission_id,
    id.patient_id,
    id.infection_type,
    -- Infection site based on type
    CASE id.infection_type
        WHEN 'CAUTI' THEN 'Urinary'
        WHEN 'CLABSI' THEN 'Bloodstream'
        WHEN 'VAP' THEN 'Respiratory'
        WHEN 'SSI' THEN 'Surgical Site'
        WHEN 'CDIFF' THEN 'Gastrointestinal'
        WHEN 'Pneumonia' THEN 'Respiratory'
        WHEN 'MRSA' THEN 'Skin/Soft Tissue'
        ELSE 'Bloodstream'
    END AS infection_site,
    -- Pathogen based on infection type
    CASE id.infection_type
        WHEN 'CAUTI' THEN CASE WHEN UNIFORM(1,4,RANDOM()) <= 2 THEN 'E. coli' ELSE 'Enterococcus' END
        WHEN 'CLABSI' THEN CASE WHEN UNIFORM(1,3,RANDOM()) = 1 THEN 'Staphylococcus aureus' ELSE 'Klebsiella pneumoniae' END
        WHEN 'VAP' THEN CASE WHEN UNIFORM(1,3,RANDOM()) = 1 THEN 'Pseudomonas aeruginosa' ELSE 'Acinetobacter' END
        WHEN 'SSI' THEN CASE WHEN UNIFORM(1,3,RANDOM()) = 1 THEN 'Staphylococcus aureus' ELSE 'E. coli' END
        WHEN 'CDIFF' THEN 'Clostridium difficile'
        WHEN 'Pneumonia' THEN 'Pseudomonas aeruginosa'
        WHEN 'MRSA' THEN 'Methicillin-resistant Staphylococcus aureus'
        ELSE 'Staphylococcus aureus'
    END AS pathogen,
            DATEADD(DAY, 
            CASE 
                WHEN id.length_of_stay_days > 10 THEN UNIFORM(3, 10, RANDOM())
                WHEN id.length_of_stay_days > 5 THEN UNIFORM(2, 5, RANDOM())
                ELSE UNIFORM(2, 3, RANDOM())
            END, 
            id.admission_date::DATE) AS onset_date,
        DATEADD(DAY, UNIFORM(7, 21, RANDOM()), 
            DATEADD(DAY, 
                CASE 
                    WHEN id.length_of_stay_days > 10 THEN UNIFORM(3, 10, RANDOM())
                    WHEN id.length_of_stay_days > 5 THEN UNIFORM(2, 5, RANDOM())
                    ELSE UNIFORM(2, 3, RANDOM())
                END, 
                id.admission_date::DATE)) AS resolution_date,
        CASE 
            WHEN id.length_of_stay_days > 10 THEN UNIFORM(3, 10, RANDOM())
            WHEN id.length_of_stay_days > 5 THEN UNIFORM(2, 5, RANDOM())
            ELSE UNIFORM(2, 3, RANDOM())
        END AS days_to_onset,
    -- Severity based on infection type and patient age
    CASE 
        WHEN id.infection_type IN ('CLABSI', 'VAP', 'Sepsis') AND id.age > 75 THEN 
            CASE WHEN UNIFORM(1,100,RANDOM()) <= 40 THEN 'Severe' ELSE 'Moderate' END
        WHEN id.infection_type IN ('CLABSI', 'VAP', 'Sepsis') THEN
            CASE WHEN UNIFORM(1,100,RANDOM()) <= 25 THEN 'Severe' ELSE 'Moderate' END
        WHEN id.age > 80 THEN
            CASE WHEN UNIFORM(1,100,RANDOM()) <= 30 THEN 'Severe' ELSE 'Moderate' END
        ELSE
            CASE 
                WHEN UNIFORM(1,100,RANDOM()) <= 15 THEN 'Severe'
                WHEN UNIFORM(1,100,RANDOM()) <= 60 THEN 'Moderate'
                ELSE 'Mild'
            END
    END AS severity,
    -- Device association based on infection type
    CASE id.infection_type
        WHEN 'CAUTI' THEN TRUE
        WHEN 'CLABSI' THEN TRUE  
        WHEN 'VAP' THEN TRUE
        ELSE FALSE
    END AS device_associated,
    -- Device type based on infection
    CASE id.infection_type
        WHEN 'CAUTI' THEN 'Foley catheter'
        WHEN 'CLABSI' THEN 'Central line'
        WHEN 'VAP' THEN 'Ventilator'
        WHEN 'SSI' THEN 'Surgical drain'
        ELSE NULL
    END AS device_type,
    -- Device days (realistic duration)
    CASE id.infection_type
        WHEN 'CAUTI' THEN UNIFORM(3, 15, RANDOM())
        WHEN 'CLABSI' THEN UNIFORM(3, 12, RANDOM())
        WHEN 'VAP' THEN UNIFORM(2, 10, RANDOM())
        WHEN 'SSI' THEN UNIFORM(1, 7, RANDOM())
        ELSE NULL
    END AS device_days,
    -- Antibiotic resistance rates
    CASE id.infection_type
        WHEN 'MRSA' THEN TRUE -- MRSA is resistant by definition
        WHEN 'CLABSI' THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 35 THEN TRUE ELSE FALSE END -- 35% resistant
        WHEN 'VAP' THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 40 THEN TRUE ELSE FALSE END -- 40% resistant
        WHEN 'CDIFF' THEN FALSE -- C.diff has specific treatment
        ELSE CASE WHEN UNIFORM(1,100,RANDOM()) <= 20 THEN TRUE ELSE FALSE END -- 20% general resistance
    END AS antibiotic_resistance,
            DATEADD(DAY, UNIFORM(0, 2, RANDOM()), 
            DATEADD(DAY, 
                CASE 
                    WHEN id.length_of_stay_days > 10 THEN UNIFORM(3, 10, RANDOM())
                    WHEN id.length_of_stay_days > 5 THEN UNIFORM(2, 5, RANDOM())
                    ELSE UNIFORM(2, 3, RANDOM())
                END, 
                id.admission_date::DATE)) AS treatment_started_date,
    -- Preventability based on infection type - ELEVATED RATES (showing improvement opportunities)
    -- These high rates create urgency for CQO intervention
    CASE id.infection_type
        WHEN 'CAUTI' THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 85 THEN TRUE ELSE FALSE END -- 85% preventable (high!)
        WHEN 'CLABSI' THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 80 THEN TRUE ELSE FALSE END -- 80% preventable (high!)
        WHEN 'VAP' THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 65 THEN TRUE ELSE FALSE END -- 65% preventable
        WHEN 'SSI' THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 75 THEN TRUE ELSE FALSE END -- 75% preventable
        WHEN 'CDIFF' THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 55 THEN TRUE ELSE FALSE END -- 55% preventable
        ELSE CASE WHEN UNIFORM(1,100,RANDOM()) <= 50 THEN TRUE ELSE FALSE END -- 50% general preventable
    END AS infection_preventable,
    -- Contribution to death based on infection type - NATIONAL ATTRIBUTABLE MORTALITY RATES
    -- Based on CDC/AHRQ data 2024-2025:
    -- CLABSI attributable mortality: 12-25%
    -- VAP attributable mortality: 20-35%
    -- CAUTI attributable mortality: 3-8% (higher in elderly due to urosepsis)
    -- C.diff attributable mortality: 5-15% (higher in frail elderly)
    -- SSI attributable mortality: 2-5%
    -- Sepsis overall mortality: 15-30% (varies by severity)
    CASE 
        WHEN id.discharge_disposition = 'Expired' AND id.infection_type = 'CLABSI' 
             THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 20 THEN TRUE ELSE FALSE END -- CLABSI: 20% attributable mortality
        WHEN id.discharge_disposition = 'Expired' AND id.infection_type = 'VAP' 
             THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 27 THEN TRUE ELSE FALSE END -- VAP: 27% attributable mortality
        WHEN id.discharge_disposition = 'Expired' AND id.infection_type = 'Sepsis' 
             THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 22 THEN TRUE ELSE FALSE END -- Hospital-acquired sepsis: 22%
        WHEN id.discharge_disposition = 'Expired' AND id.infection_type = 'CAUTI' AND id.age > 75
             THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 8 THEN TRUE ELSE FALSE END -- Elderly CAUTI (urosepsis risk): 8%
        WHEN id.discharge_disposition = 'Expired' AND id.infection_type = 'CAUTI'
             THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 4 THEN TRUE ELSE FALSE END -- Younger CAUTI: 4%
        WHEN id.discharge_disposition = 'Expired' AND id.infection_type = 'CDIFF' AND id.age > 65
             THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 12 THEN TRUE ELSE FALSE END -- Elderly C.diff: 12%
        WHEN id.discharge_disposition = 'Expired' AND id.infection_type = 'CDIFF'
             THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 6 THEN TRUE ELSE FALSE END -- Younger C.diff: 6%
        WHEN id.discharge_disposition = 'Expired' AND id.infection_type = 'SSI'
             THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 4 THEN TRUE ELSE FALSE END -- SSI: 4%
        WHEN id.discharge_disposition = 'Expired' AND id.infection_type = 'MRSA'
             THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 15 THEN TRUE ELSE FALSE END -- MRSA: 15%
        WHEN id.discharge_disposition = 'Expired' AND id.infection_type = 'Pneumonia'
             THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 18 THEN TRUE ELSE FALSE END -- HAP: 18%
        ELSE FALSE
    END AS contributed_to_death,
    TRUE AS healthcare_associated
FROM infection_data id;

-- 6. Generate REALISTIC RISK_FACTORS with proper comorbidity patterns
INSERT INTO RISK_FACTORS (
    risk_factor_id, patient_id, admission_id, risk_factor_type, risk_factor_name,
    icd10_code, severity_score, present_on_admission, chronic_condition,
    affects_mortality_risk, affects_infection_risk, affects_los_risk, documented_date
)
WITH patient_risk_data AS (
    SELECT 
        a.patient_id,
        a.admission_id,
        a.admission_date,
        DATEDIFF(YEAR, p.date_of_birth, a.admission_date) AS age,
        d.icd10_code AS primary_diagnosis,
        a.mortality_risk_score,
        a.length_of_stay_days
    FROM ADMISSIONS a
    JOIN PATIENTS p ON a.patient_id = p.patient_id
    LEFT JOIN DIAGNOSES d ON a.admission_id = d.admission_id AND d.diagnosis_type = 'Primary'
),
-- Generate age-appropriate comorbidities
risk_factors_base AS (
    SELECT 
        prd.patient_id,
        prd.admission_id,
        prd.admission_date,
        prd.age,
        prd.primary_diagnosis,
        -- Diabetes (more common with age and certain primary diagnoses)
        CASE 
            WHEN prd.primary_diagnosis IN ('I50.9', 'I25.1', 'N39.0') AND UNIFORM(1,100,RANDOM()) <= 60 THEN 1 -- 60% with cardiac/renal
            WHEN prd.age > 65 AND UNIFORM(1,100,RANDOM()) <= 35 THEN 1 -- 35% elderly
            WHEN prd.age > 50 AND UNIFORM(1,100,RANDOM()) <= 20 THEN 1 -- 20% middle-aged
            ELSE 0
        END AS has_diabetes,
        -- Hypertension (very common with age)
        CASE 
            WHEN prd.age > 75 AND UNIFORM(1,100,RANDOM()) <= 80 THEN 1 -- 80% very elderly
            WHEN prd.age > 65 AND UNIFORM(1,100,RANDOM()) <= 70 THEN 1 -- 70% elderly
            WHEN prd.age > 50 AND UNIFORM(1,100,RANDOM()) <= 50 THEN 1 -- 50% middle-aged
            WHEN prd.age > 35 AND UNIFORM(1,100,RANDOM()) <= 25 THEN 1 -- 25% younger adults
            ELSE 0
        END AS has_hypertension,
        -- COPD (smoking-related, more with resp diagnoses)
        CASE 
            WHEN prd.primary_diagnosis IN ('J44.0', 'J96.00', 'J18.9') AND UNIFORM(1,100,RANDOM()) <= 70 THEN 1 -- 70% with resp dx
            WHEN prd.age > 65 AND UNIFORM(1,100,RANDOM()) <= 25 THEN 1 -- 25% elderly
            WHEN prd.age > 50 AND UNIFORM(1,100,RANDOM()) <= 15 THEN 1 -- 15% middle-aged
            ELSE 0
        END AS has_copd,
        -- Heart failure (cardiac cluster)
        CASE 
            WHEN prd.primary_diagnosis IN ('I50.9', 'I46.9', 'I21.9', 'I25.1') AND UNIFORM(1,100,RANDOM()) <= 40 THEN 1
            WHEN prd.age > 75 AND UNIFORM(1,100,RANDOM()) <= 20 THEN 1
            ELSE 0
        END AS has_heart_failure,
        -- Chronic kidney disease (renal/cardiac/diabetes cluster)
        CASE 
            WHEN prd.primary_diagnosis IN ('N39.0', 'I50.9', 'E11.9') AND UNIFORM(1,100,RANDOM()) <= 45 THEN 1
            WHEN prd.age > 70 AND UNIFORM(1,100,RANDOM()) <= 18 THEN 1
            ELSE 0
        END AS has_ckd,
        -- Age as risk factor
        CASE WHEN prd.age >= 65 THEN 1 ELSE 0 END AS is_elderly,
        -- Obesity (common, affects multiple conditions)
        CASE 
            WHEN prd.primary_diagnosis = 'E11.9' AND UNIFORM(1,100,RANDOM()) <= 70 THEN 1 -- 70% with diabetes
            WHEN prd.age BETWEEN 40 AND 65 AND UNIFORM(1,100,RANDOM()) <= 40 THEN 1 -- 40% middle-aged
            WHEN UNIFORM(1,100,RANDOM()) <= 25 THEN 1 -- 25% general population
            ELSE 0
        END AS has_obesity
    FROM patient_risk_data prd
),
-- Expand into individual risk factor records
risk_factor_records AS (
    -- Diabetes records
    SELECT 
        patient_id, admission_id, admission_date,
        'Diabetes mellitus' AS risk_factor_name,
        'E11.9' AS icd10_code,
        'Comorbidity' AS risk_factor_type,
        ROUND(UNIFORM(2.5, 4.0, RANDOM()), 1) AS severity_score,
        TRUE AS affects_mortality_risk,
        TRUE AS affects_infection_risk,
        TRUE AS affects_los_risk
    FROM risk_factors_base 
    WHERE has_diabetes = 1
    
    UNION ALL
    
    -- Hypertension records  
    SELECT 
        patient_id, admission_id, admission_date,
        'Hypertension' AS risk_factor_name,
        'I10' AS icd10_code,
        'Comorbidity' AS risk_factor_type,
        ROUND(UNIFORM(1.5, 3.0, RANDOM()), 1) AS severity_score,
        TRUE AS affects_mortality_risk,
        FALSE AS affects_infection_risk,
        FALSE AS affects_los_risk
    FROM risk_factors_base 
    WHERE has_hypertension = 1
    
    UNION ALL
    
    -- COPD records
    SELECT 
        patient_id, admission_id, admission_date,
        'COPD' AS risk_factor_name,
        'J44.1' AS icd10_code,
        'Comorbidity' AS risk_factor_type,
        ROUND(UNIFORM(2.0, 4.5, RANDOM()), 1) AS severity_score,
        TRUE AS affects_mortality_risk,
        TRUE AS affects_infection_risk,
        TRUE AS affects_los_risk
    FROM risk_factors_base 
    WHERE has_copd = 1
    
    UNION ALL
    
    -- Heart failure records
    SELECT 
        patient_id, admission_id, admission_date,
        'Heart failure' AS risk_factor_name,
        'I50.9' AS icd10_code,
        'Comorbidity' AS risk_factor_type,
        ROUND(UNIFORM(2.5, 4.0, RANDOM()), 1) AS severity_score,
        TRUE AS affects_mortality_risk,
        TRUE AS affects_infection_risk,
        TRUE AS affects_los_risk
    FROM risk_factors_base 
    WHERE has_heart_failure = 1
    
    UNION ALL
    
    -- CKD records
    SELECT 
        patient_id, admission_id, admission_date,
        'Chronic kidney disease' AS risk_factor_name,
        'N18.6' AS icd10_code,
        'Comorbidity' AS risk_factor_type,
        ROUND(UNIFORM(2.0, 4.0, RANDOM()), 1) AS severity_score,
        TRUE AS affects_mortality_risk,
        TRUE AS affects_infection_risk,
        TRUE AS affects_los_risk
    FROM risk_factors_base 
    WHERE has_ckd = 1
    
    UNION ALL
    
    -- Elderly age records
    SELECT 
        patient_id, admission_id, admission_date,
        'Age > 65' AS risk_factor_name,
        'Z00.00' AS icd10_code,
        'Social' AS risk_factor_type,
        ROUND(UNIFORM(1.5, 3.5, RANDOM()), 1) AS severity_score,
        TRUE AS affects_mortality_risk,
        TRUE AS affects_infection_risk,
        TRUE AS affects_los_risk
    FROM risk_factors_base 
    WHERE is_elderly = 1
    
    UNION ALL
    
    -- Obesity records
    SELECT 
        patient_id, admission_id, admission_date,
        'Obesity' AS risk_factor_name,
        'E66.9' AS icd10_code,
        'Comorbidity' AS risk_factor_type,
        ROUND(UNIFORM(1.5, 3.0, RANDOM()), 1) AS severity_score,
        FALSE AS affects_mortality_risk,
        TRUE AS affects_infection_risk,
        TRUE AS affects_los_risk
    FROM risk_factors_base 
    WHERE has_obesity = 1
)
SELECT 
    'RF' || LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM()), 10, '0') AS risk_factor_id,
    rfr.patient_id,
    rfr.admission_id,
    rfr.risk_factor_type,
    rfr.risk_factor_name,
    rfr.icd10_code,
    rfr.severity_score,
    TRUE AS present_on_admission,
    TRUE AS chronic_condition,
    rfr.affects_mortality_risk,
    rfr.affects_infection_risk,
    rfr.affects_los_risk,
    rfr.admission_date::DATE AS documented_date
FROM risk_factor_records rfr;

COMMIT;

-- ========================================
-- HAI VERIFICATION QUERIES - NATIONAL BENCHMARK COMPARISON
-- ========================================

-- 6. Overall HAI Rate (National Avg: ~4-5% of hospitalized patients)
SELECT 
    'OVERALL HAI RATE (National Avg: 4-5%)' AS metric,
    (SELECT COUNT(*) FROM ADMISSIONS WHERE length_of_stay_days >= 2) AS eligible_admissions,
    COUNT(DISTINCT i.admission_id) AS admissions_with_hai,
    ROUND(COUNT(DISTINCT i.admission_id) * 100.0 / 
          NULLIF((SELECT COUNT(*) FROM ADMISSIONS WHERE length_of_stay_days >= 2), 0), 2) AS hai_rate_pct
FROM INFECTIONS i;

-- 7. HAI Rates by Type (National Benchmarks)
-- CAUTI: ~2-5% of catheterized patients
-- CLABSI: ~1-3% of central line patients
-- VAP: ~2-5% of ventilated patients
-- SSI: ~1-3% of surgical patients
SELECT 
    infection_type,
    COUNT(*) AS infection_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_of_all_hai,
    SUM(CASE WHEN contributed_to_death = TRUE THEN 1 ELSE 0 END) AS deaths_attributed,
    ROUND(SUM(CASE WHEN contributed_to_death = TRUE THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(COUNT(*), 0), 1) AS attributable_mortality_pct
FROM INFECTIONS
GROUP BY infection_type
ORDER BY infection_count DESC;

-- 8. HAI Attributable Mortality (National Benchmarks)
-- CLABSI: 12-25% | VAP: 20-35% | CAUTI: 3-8% | C.diff: 5-15%
SELECT 
    'HAI ATTRIBUTABLE MORTALITY' AS metric,
    infection_type,
    CASE infection_type
        WHEN 'CLABSI' THEN '12-25%'
        WHEN 'VAP' THEN '20-35%'
        WHEN 'CAUTI' THEN '3-8%'
        WHEN 'CDIFF' THEN '5-15%'
        WHEN 'SSI' THEN '2-5%'
        WHEN 'Sepsis' THEN '15-30%'
        ELSE 'Varies'
    END AS national_benchmark,
    COUNT(*) AS total_infections,
    SUM(CASE WHEN contributed_to_death = TRUE THEN 1 ELSE 0 END) AS deaths_attributed,
    ROUND(SUM(CASE WHEN contributed_to_death = TRUE THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(COUNT(*), 0), 1) AS actual_attributable_mortality_pct
FROM INFECTIONS
WHERE admission_id IN (SELECT admission_id FROM ADMISSIONS WHERE discharge_disposition = 'Expired')
GROUP BY infection_type
ORDER BY infection_type;

-- 9. QUARTERLY HAI TREND (Shows worsening infection rates)
SELECT 
    'QUARTERLY HAI TREND (Worsening!)' AS analysis_type,
    DATE_TRUNC('quarter', i.onset_date) AS quarter,
    COUNT(*) AS total_hai,
    SUM(CASE WHEN i.infection_type = 'CAUTI' THEN 1 ELSE 0 END) AS cauti_count,
    SUM(CASE WHEN i.infection_type = 'CLABSI' THEN 1 ELSE 0 END) AS clabsi_count,
    SUM(CASE WHEN i.infection_type = 'VAP' THEN 1 ELSE 0 END) AS vap_count,
    SUM(CASE WHEN i.infection_type = 'SSI' THEN 1 ELSE 0 END) AS ssi_count,
    SUM(CASE WHEN i.contributed_to_death = TRUE THEN 1 ELSE 0 END) AS hai_contributed_deaths
FROM INFECTIONS i
GROUP BY DATE_TRUNC('quarter', i.onset_date)
ORDER BY quarter;

-- 10. CAUTI-SPECIFIC QUARTERLY TREND (Often a focus area)
SELECT 
    'CAUTI QUARTERLY TREND (Major Opportunity!)' AS analysis_type,
    DATE_TRUNC('quarter', onset_date) AS quarter,
    COUNT(*) AS cauti_infections,
    SUM(CASE WHEN contributed_to_death = TRUE THEN 1 ELSE 0 END) AS cauti_deaths,
    SUM(CASE WHEN infection_preventable = TRUE THEN 1 ELSE 0 END) AS preventable_cautis,
    ROUND(SUM(CASE WHEN infection_preventable = TRUE THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS preventable_pct
FROM INFECTIONS
WHERE infection_type = 'CAUTI'
GROUP BY DATE_TRUNC('quarter', onset_date)
ORDER BY quarter;

SELECT 'Part 2: Realistic procedures, infections, and risk factors generated successfully!' AS status; 


-- Clinical Quality and Patient Safety Demo - REALISTIC Outcomes and Quality Events
-- Generate realistic outcomes and quality events tied to actual clinical conditions

USE DATABASE SF_SOLUTIONS;
USE SCHEMA CLINICAL_QUALITY_SAFETY;

-- 7. Generate REALISTIC OUTCOMES tied to infections, procedures, and risk factors
INSERT INTO OUTCOMES (
    outcome_id, admission_id, patient_id, outcome_type, outcome_date,
    primary_cause, contributing_factors, expected_vs_actual, preventable,
    quality_issue_related, infection_related, procedure_related, medication_related,
    readmission_within_30_days, readmission_within_90_days, satisfaction_score
)
WITH outcome_data AS (
    SELECT 
        a.admission_id,
        a.patient_id,
        a.discharge_disposition,
        a.discharge_date,
        a.mortality_risk_score,
        DATEDIFF(YEAR, p.date_of_birth, a.admission_date) AS age,
        d.icd10_code AS primary_diagnosis,
        -- Check for contributing factors
        COUNT(i.infection_id) AS infection_count,
        MAX(CASE WHEN i.contributed_to_death = TRUE THEN 1 ELSE 0 END) AS has_fatal_infection,
        MAX(CASE WHEN i.infection_type IN ('CLABSI', 'VAP', 'Sepsis') THEN 1 ELSE 0 END) AS has_severe_infection,
        COUNT(pr.procedure_id) AS procedure_count,
        MAX(CASE WHEN pr.complication_occurred = TRUE THEN 1 ELSE 0 END) AS has_procedure_complication,
        COUNT(rf.risk_factor_id) AS risk_factor_count,
        MAX(CASE WHEN rf.affects_mortality_risk = TRUE THEN 1 ELSE 0 END) AS has_mortality_risk_factors,
        COUNT(qe.event_id) AS quality_event_count,
        MAX(CASE WHEN qe.contributed_to_death = TRUE THEN 1 ELSE 0 END) AS has_fatal_quality_event
    FROM ADMISSIONS a
    JOIN PATIENTS p ON a.patient_id = p.patient_id
    LEFT JOIN DIAGNOSES d ON a.admission_id = d.admission_id AND d.diagnosis_type = 'Primary'
    LEFT JOIN INFECTIONS i ON a.admission_id = i.admission_id
    LEFT JOIN PROCEDURES pr ON a.admission_id = pr.admission_id
    LEFT JOIN RISK_FACTORS rf ON a.admission_id = rf.admission_id
    LEFT JOIN QUALITY_EVENTS qe ON a.admission_id = qe.admission_id
    GROUP BY a.admission_id, a.patient_id, a.discharge_disposition, a.discharge_date,
             a.mortality_risk_score, p.date_of_birth, a.admission_date, d.icd10_code
)
SELECT 
    'OUT' || LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM()), 10, '0') AS outcome_id,
    od.admission_id,
    od.patient_id,
    -- Outcome type based on discharge disposition
    CASE od.discharge_disposition
        WHEN 'Expired' THEN 'Death'
        WHEN 'Transfer' THEN 'Transfer'
        WHEN 'AMA' THEN 'AMA'
        WHEN 'SNF' THEN 'Discharge'
        WHEN 'Rehab' THEN 'Discharge'
        ELSE 'Discharge'
    END AS outcome_type,
    od.discharge_date AS outcome_date,
    -- Primary cause based on diagnosis and contributing factors
    CASE 
        WHEN od.discharge_disposition = 'Expired' THEN
            CASE
                WHEN od.has_fatal_infection = 1 AND od.primary_diagnosis = 'A41.9' THEN 'Sepsis/Infection'
                WHEN od.has_fatal_infection = 1 THEN 'Healthcare-associated infection'
                WHEN od.primary_diagnosis = 'I46.9' THEN 'Cardiac arrest'
                WHEN od.primary_diagnosis = 'I21.9' THEN 'Acute myocardial infarction'
                WHEN od.primary_diagnosis = 'J96.00' THEN 'Respiratory failure'
                WHEN od.primary_diagnosis = 'I50.9' THEN 'Heart failure'
                WHEN od.primary_diagnosis IN ('J44.0', 'J44.1') THEN 'COPD exacerbation'
                WHEN od.primary_diagnosis = 'R65.20' THEN 'Severe sepsis'
                WHEN od.age > 85 THEN 'Advanced age/multiple comorbidities'
                WHEN od.has_procedure_complication = 1 THEN 'Surgical complications'
                ELSE 'Multiple organ failure'
            END
        ELSE 'Condition improved/stable'
    END AS primary_cause,
    -- Contributing factors based on actual patient data
    CASE 
        WHEN od.discharge_disposition = 'Expired' THEN
            CASE
                WHEN od.risk_factor_count > 3 THEN 'Multiple comorbidities, advanced age'
                WHEN od.infection_count > 0 THEN 'Healthcare-associated infection, comorbid conditions'
                WHEN od.age > 80 THEN 'Advanced age, frailty'
                WHEN od.procedure_count > 0 THEN 'Surgical stress, underlying conditions'
                ELSE 'Severity of illness, patient factors'
            END
        ELSE 'Treatment response, patient compliance, family support'
    END AS contributing_factors,
    -- Expected vs actual based on mortality risk score
    CASE 
        WHEN od.discharge_disposition = 'Expired' AND od.mortality_risk_score > 0.050 THEN 'Expected'
        WHEN od.discharge_disposition = 'Expired' AND od.mortality_risk_score > 0.020 THEN 'Somewhat expected'
        WHEN od.discharge_disposition = 'Expired' THEN 'Unexpected'
        ELSE 'Expected'
    END AS expected_vs_actual,
    -- Preventability based on contributing factors
    -- ELEVATED PREVENTABLE DEATH RATE (~35%) to show quality improvement opportunities
    -- This creates a compelling case for CQO intervention
    CASE 
        WHEN od.discharge_disposition = 'Expired' AND od.has_fatal_infection = 1 THEN TRUE -- Deaths with HAI - 100% flagged
        WHEN od.discharge_disposition = 'Expired' AND od.has_procedure_complication = 1 THEN TRUE -- Deaths with procedure complications
        WHEN od.discharge_disposition = 'Expired' AND od.has_fatal_quality_event = 1 THEN TRUE -- Deaths with quality events
        WHEN od.discharge_disposition = 'Expired' AND od.infection_count > 0 THEN 
            CASE WHEN UNIFORM(1,100,RANDOM()) <= 80 THEN TRUE ELSE FALSE END -- 80% of deaths with ANY infection
        WHEN od.discharge_disposition = 'Expired' AND od.mortality_risk_score < 0.050 THEN TRUE -- Low-risk deaths are preventable
        WHEN od.discharge_disposition = 'Expired' AND od.quality_event_count > 0 THEN TRUE -- Any quality event involvement
        -- Additional ~35% of remaining deaths flagged as potentially preventable
        -- (missed diagnoses, delayed treatment, communication failures, etc.)
        WHEN od.discharge_disposition = 'Expired' AND UNIFORM(1,100,RANDOM()) <= $preventable_death_rate THEN TRUE
        ELSE FALSE
    END AS preventable,
    -- Quality issue related
    CASE WHEN od.quality_event_count > 0 OR od.has_procedure_complication = 1 THEN TRUE ELSE FALSE END AS quality_issue_related,
    -- Infection related
    CASE WHEN od.infection_count > 0 THEN TRUE ELSE FALSE END AS infection_related,
    -- Procedure related
    CASE WHEN od.has_procedure_complication = 1 THEN TRUE ELSE FALSE END AS procedure_related,
    -- Medication related (random but realistic rate)
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 5 THEN TRUE ELSE FALSE END AS medication_related,
    -- Readmission flags (would be calculated from future admissions in real system)
    FALSE AS readmission_within_30_days,
    FALSE AS readmission_within_90_days,
    -- Satisfaction score (lower for deaths and complications)
    CASE 
        WHEN od.discharge_disposition = 'Expired' THEN ROUND(UNIFORM(1.0, 3.0, RANDOM()), 1) -- Poor scores for deaths
        WHEN od.quality_event_count > 0 THEN ROUND(UNIFORM(2.0, 3.5, RANDOM()), 1) -- Lower for quality events
        WHEN od.infection_count > 0 THEN ROUND(UNIFORM(2.5, 4.0, RANDOM()), 1) -- Lower for infections
        ELSE ROUND(UNIFORM(3.5, 5.0, RANDOM()), 1) -- Good scores for routine care
    END AS satisfaction_score
FROM outcome_data od;

-- 8. Generate REALISTIC QUALITY_EVENTS based on actual risk factors
INSERT INTO QUALITY_EVENTS (
    event_id, admission_id, patient_id, event_type, event_subtype,
    event_date, severity, harm_level, preventable, reported_by,
    location, contributing_factors, corrective_actions, event_resolved,
    resolution_date, contributed_to_death
)
WITH quality_event_candidates AS (
    SELECT 
        a.admission_id,
        a.patient_id,
        a.admission_date,
        a.discharge_date,
        a.discharge_disposition,
        a.length_of_stay_days,
        a.room_type,
        DATEDIFF(YEAR, p.date_of_birth, a.admission_date) AS age,
        -- Risk factors for quality events
        COUNT(CASE WHEN rf.risk_factor_name = 'Age > 65' THEN 1 END) AS is_elderly,
        COUNT(CASE WHEN pr.cpt_code IN ('36556', '51702') THEN 1 END) AS has_devices,
        COUNT(CASE WHEN rf.risk_factor_name = 'COPD' THEN 1 END) AS has_copd,
        MAX(CASE WHEN a.room_type = 'ICU' THEN 1 ELSE 0 END) AS is_icu_patient
    FROM ADMISSIONS a
    JOIN PATIENTS p ON a.patient_id = p.patient_id
    LEFT JOIN RISK_FACTORS rf ON a.admission_id = rf.admission_id
    LEFT JOIN PROCEDURES pr ON a.admission_id = pr.admission_id
    WHERE a.length_of_stay_days >= 3 -- Quality events more likely with longer stays
    GROUP BY a.admission_id, a.patient_id, a.admission_date, a.discharge_date,
             a.discharge_disposition, a.length_of_stay_days, a.room_type, p.date_of_birth
),
quality_events_base AS (
    SELECT 
        qec.admission_id,
        qec.patient_id,
        qec.admission_date,
        qec.discharge_date,
        qec.discharge_disposition,
        qec.age,
        qec.room_type,
        qec.length_of_stay_days,
        -- Event type based on patient risk factors
        CASE 
            WHEN qec.age > 75 AND qec.length_of_stay_days > 7 AND UNIFORM(1, 100, RANDOM()) <= 40 THEN 'Pressure_Injury' -- Elderly long stay
            WHEN qec.age > 65 AND UNIFORM(1, 100, RANDOM()) <= 25 THEN 'Fall' -- Elderly fall risk
            WHEN qec.has_devices > 0 AND UNIFORM(1, 100, RANDOM()) <= 20 THEN 'Device_Malfunction' -- Device-related
            WHEN qec.is_icu_patient = 1 AND UNIFORM(1, 100, RANDOM()) <= 15 THEN 'Medication_Error' -- ICU complexity
            WHEN UNIFORM(1, 100, RANDOM()) <= 10 THEN 'Communication_Failure' -- General communication issues
            WHEN UNIFORM(1, 100, RANDOM()) <= 5 THEN 'Wrong_Site_Surgery' -- Rare but serious
            ELSE 'Fall' -- Default to falls (common)
        END AS event_type
    FROM quality_event_candidates qec
    WHERE 
        -- Quality event rates based on risk factors
        (qec.age > 75 AND qec.length_of_stay_days > 5 AND UNIFORM(1, 100, RANDOM()) <= 25) OR -- Elderly long stay: 25%
        (qec.is_icu_patient = 1 AND UNIFORM(1, 100, RANDOM()) <= 15) OR -- ICU patients: 15%
        (qec.has_devices > 0 AND UNIFORM(1, 100, RANDOM()) <= 12) OR -- Device patients: 12%
        (qec.age > 65 AND UNIFORM(1, 100, RANDOM()) <= 8) OR -- Elderly: 8%
        (UNIFORM(1, 100, RANDOM()) <= 3) -- General population: 3%
)
SELECT 
    'QE' || LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM()), 10, '0') AS event_id,
    qeb.admission_id,
    qeb.patient_id,
    qeb.event_type,
    -- Event subtype based on type
    CASE qeb.event_type
        WHEN 'Pressure_Injury' THEN 
            CASE 
                WHEN UNIFORM(1,100,RANDOM()) <= 40 THEN 'Stage II'
                WHEN UNIFORM(1,100,RANDOM()) <= 70 THEN 'Stage I'
                WHEN UNIFORM(1,100,RANDOM()) <= 90 THEN 'Stage III'
                ELSE 'Stage IV'
            END
        WHEN 'Fall' THEN
            CASE 
                WHEN UNIFORM(1,100,RANDOM()) <= 60 THEN 'No Injury'
                WHEN UNIFORM(1,100,RANDOM()) <= 85 THEN 'Minor Injury'
                ELSE 'Major Injury'
            END
        ELSE 'Standard'
    END AS event_subtype,
    DATEADD(DAY, 
        CASE 
            WHEN qeb.length_of_stay_days > 8 THEN UNIFORM(2, 8, RANDOM())
            WHEN qeb.length_of_stay_days > 5 THEN UNIFORM(2, 5, RANDOM())
            ELSE UNIFORM(2, 3, RANDOM())
        END, 
        qeb.admission_date::DATE) AS event_date,
    -- Severity based on event type and patient age
    CASE 
        WHEN qeb.event_type = 'Wrong_Site_Surgery' THEN 'Catastrophic'
        WHEN qeb.event_type = 'Pressure_Injury' AND qeb.age > 80 THEN
            CASE WHEN UNIFORM(1,100,RANDOM()) <= 40 THEN 'Major' ELSE 'Moderate' END
        WHEN qeb.event_type = 'Fall' AND qeb.age > 75 THEN
            CASE WHEN UNIFORM(1,100,RANDOM()) <= 30 THEN 'Major' ELSE 'Moderate' END
        WHEN qeb.age > 80 THEN
            CASE WHEN UNIFORM(1,100,RANDOM()) <= 25 THEN 'Major' ELSE 'Moderate' END
        ELSE
            CASE 
                WHEN UNIFORM(1,100,RANDOM()) <= 10 THEN 'Major'
                WHEN UNIFORM(1,100,RANDOM()) <= 40 THEN 'Moderate'
                ELSE 'Minor'
            END
    END AS severity,
    -- Harm level based on severity
    CASE 
        WHEN qeb.event_type = 'Wrong_Site_Surgery' THEN 'Permanent harm'
        WHEN qeb.event_type = 'Pressure_Injury' AND qeb.age > 80 THEN
            CASE WHEN UNIFORM(1,100,RANDOM()) <= 20 THEN 'Permanent harm' ELSE 'Temporary harm' END
        WHEN qeb.event_type = 'Fall' AND qeb.age > 75 THEN
            CASE WHEN UNIFORM(1,100,RANDOM()) <= 15 THEN 'Permanent harm' ELSE 'Temporary harm' END
        ELSE
            CASE 
                WHEN UNIFORM(1,100,RANDOM()) <= 5 THEN 'Permanent harm'
                WHEN UNIFORM(1,100,RANDOM()) <= 30 THEN 'Temporary harm'
                ELSE 'No harm'
            END
    END AS harm_level,
    -- Preventability based on event type
    CASE qeb.event_type
        WHEN 'Pressure_Injury' THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 80 THEN TRUE ELSE FALSE END -- 80% preventable
        WHEN 'Fall' THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 70 THEN TRUE ELSE FALSE END -- 70% preventable
        WHEN 'Medication_Error' THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 90 THEN TRUE ELSE FALSE END -- 90% preventable
        WHEN 'Wrong_Site_Surgery' THEN TRUE -- 100% preventable
        WHEN 'Communication_Failure' THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 85 THEN TRUE ELSE FALSE END -- 85% preventable
        ELSE CASE WHEN UNIFORM(1,100,RANDOM()) <= 60 THEN TRUE ELSE FALSE END -- 60% general preventable
    END AS preventable,
    CASE 
        WHEN qeb.room_type = 'ICU' AND UNIFORM(1,100,RANDOM()) <= 60 THEN 'Nurse'
        WHEN UNIFORM(1,100,RANDOM()) <= 70 THEN 'Nurse'
        WHEN UNIFORM(1,100,RANDOM()) <= 85 THEN 'Physician'
        WHEN UNIFORM(1,100,RANDOM()) <= 95 THEN 'Patient'
        ELSE 'Family'
    END AS reported_by,
    qeb.room_type AS location,
    'Event documented with contributing factors per protocol' AS contributing_factors,
    'Corrective actions implemented per quality improvement protocol' AS corrective_actions,
    CASE WHEN UNIFORM(1,100,RANDOM()) <= 90 THEN TRUE ELSE FALSE END AS event_resolved, -- 90% resolved
    DATEADD(DAY, UNIFORM(1, 14, RANDOM()), 
        DATEADD(DAY, 
            CASE 
                WHEN qeb.length_of_stay_days > 8 THEN UNIFORM(2, 8, RANDOM())
                WHEN qeb.length_of_stay_days > 5 THEN UNIFORM(2, 5, RANDOM())
                ELSE UNIFORM(2, 3, RANDOM())
            END, 
            qeb.admission_date::DATE)) AS resolution_date,
    -- Contribution to death (rare but possible for severe events)
    CASE 
        WHEN qeb.discharge_disposition = 'Expired' AND qeb.event_type = 'Wrong_Site_Surgery' THEN TRUE
        WHEN qeb.discharge_disposition = 'Expired' AND qeb.event_type IN ('Fall', 'Pressure_Injury') AND qeb.age > 80 
             THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 15 THEN TRUE ELSE FALSE END -- 15% for severe events in elderly
        WHEN qeb.discharge_disposition = 'Expired' 
             THEN CASE WHEN UNIFORM(1,100,RANDOM()) <= 5 THEN TRUE ELSE FALSE END -- 5% general contribution
        ELSE FALSE
    END AS contributed_to_death
FROM quality_events_base qeb;

-- Update infection-related deaths in outcomes (ensure consistency)
UPDATE OUTCOMES 
SET infection_related = TRUE,
    primary_cause = CASE 
        WHEN primary_cause = 'Multiple organ failure' AND outcome_type = 'Death' THEN 'Sepsis/Infection'
        ELSE primary_cause
    END
WHERE admission_id IN (
    SELECT DISTINCT i.admission_id 
    FROM INFECTIONS i 
    WHERE i.contributed_to_death = TRUE
) AND outcome_type = 'Death';

-- Update procedure-related outcomes
UPDATE OUTCOMES 
SET procedure_related = TRUE
WHERE admission_id IN (
    SELECT DISTINCT pr.admission_id 
    FROM PROCEDURES pr 
    WHERE pr.complication_occurred = TRUE
);

-- Update quality-event-related outcomes  
UPDATE OUTCOMES 
SET quality_issue_related = TRUE
WHERE admission_id IN (
    SELECT DISTINCT qe.admission_id 
    FROM QUALITY_EVENTS qe 
    WHERE qe.contributed_to_death = TRUE OR qe.harm_level IN ('Permanent harm', 'Death')
);

COMMIT;

SELECT 'Realistic outcomes and quality events generated successfully!' AS status; 


CREATE STAGE IF NOT EXISTS semantic_model_stage
COMMENT = 'Stage for clinical quality and patient safety semantic model YAML file';


-- Clinical Quality and Patient Safety Demo - Email Connector Procedure
-- Create the email connector procedure for sending reports and alerts


CREATE NOTIFICATION INTEGRATION IF NOT EXISTS EMAIL_CONNECTOR
  TYPE = EMAIL
  ENABLED = TRUE;


CREATE OR REPLACE PROCEDURE SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.EMAIL_CONNECTOR(
    "RECIPIENTS" VARCHAR, 
    "SUBJECT" VARCHAR, 
    "EMAIL_CONTENT" VARCHAR
)
RETURNS BOOLEAN
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
    var ret = snowflake.execute({
      sqlText: "call SYSTEM$SEND_EMAIL(''EMAIL_CONNECTOR'', ?, ?, ?)",
      binds: [RECIPIENTS, SUBJECT, EMAIL_CONTENT]
    })

    return true
';

-- Verify email connector was created
SELECT 'Email connector procedure created successfully!' AS status;

-- Note: You must configure an EMAIL_CONNECTOR notification integration in your Snowflake account
-- For email functionality to work. See: https://docs.snowflake.com/en/sql-reference/sql/create-notification-integration

-- ============================================================
-- Section 3: Semantic Model Stage and YAML Upload
-- ============================================================
CREATE STAGE IF NOT EXISTS SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.SEMANTIC_MODEL_STAGE
    COMMENT = 'Stage for clinical quality semantic model YAML';

COPY INTO @SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.SEMANTIC_MODEL_STAGE/02_semantic_model_realistic.yaml
FROM (
    SELECT 'name: clinical_quality_patient_safety_analytics
description: "Enhanced semantic model for clinical quality and patient safety analytics with realistic clinical relationships enabling Chief Quality Officers to analyze patient outcomes, infections, mortality, and safety indicators using natural language. Focus: Provider-side clinical quality and patient safety (not payer/insurance)."

# Define the logical tables and their relationships
tables:
  - name: patient_demographics
    description: >
      Patient demographic information with realistic age distribution (65% over 65) and 
      insurance patterns. Enables age-stratified mortality and risk analysis.
    
    base_table:
      database: SF_SOLUTIONS
      schema: CLINICAL_QUALITY_SAFETY  
      table: PATIENTS
      
    primary_key:
      columns:
        - patient_id
    
    dimensions:
      - name: patient_id
        synonyms: ["patient ID", "patient key", "patient number", "patient identifier"]
        description: "Unique identifier for each patient"
        expr: patient_id
        data_type: STRING
        unique: true
        
      - name: medical_record_number
        synonyms: ["MRN", "medical record number", "medical record ID", "record number"]
        description: "Medical record number for the patient"
        expr: medical_record_number
        data_type: STRING
        unique: true
        
      - name: patient_name
        synonyms: ["name", "patient name", "full name"]
        description: "Patient''s full name"
        expr: first_name || '' '' || last_name
        data_type: STRING
        
      - name: gender
        synonyms: ["sex", "patient gender"]
        description: "Patient''s gender"
        expr: gender
        data_type: STRING
        sample_values: ["M", "F", "Other"]
        is_enum: true
        
      - name: race
        synonyms: ["ethnicity", "race category", "racial background"]
        description: "Patient''s racial background"
        expr: race
        data_type: STRING
        sample_values: ["White", "Black or African American", "Hispanic or Latino", "Asian", "American Indian or Alaska Native", "Native Hawaiian or Other Pacific Islander", "Other"]
        
      - name: insurance_type
        synonyms: ["insurance", "payer", "coverage", "insurance plan"]
        description: "Type of insurance coverage"
        expr: insurance_type
        data_type: STRING
        sample_values: ["Medicare", "Medicaid", "Commercial", "Medicare Advantage", "Self-Pay", "Uninsured"]
        
      - name: primary_language
        synonyms: ["language", "preferred language"]
        description: "Patient''s primary language"
        expr: primary_language
        data_type: STRING
        sample_values: ["English", "Spanish", "Chinese", "Other"]
        
    time_dimensions:
      - name: date_of_birth
        synonyms: ["birth date", "DOB", "birthdate"]
        description: "Patient''s date of birth"
        expr: date_of_birth
        data_type: DATE
        
      - name: patient_age
        synonyms: ["age", "age in years", "patient age"]
        description: "Patient''s current age in years"
        expr: DATEDIFF(year, date_of_birth, CURRENT_DATE())
        data_type: NUMBER
        
      - name: age_group
        synonyms: ["age category", "age bracket", "age range"]
        description: "Patient age grouped into clinically meaningful ranges"
        expr: >
          CASE 
            WHEN DATEDIFF(year, date_of_birth, CURRENT_DATE()) < 50 THEN ''Under 50''
            WHEN DATEDIFF(year, date_of_birth, CURRENT_DATE()) < 65 THEN ''50-64''
            WHEN DATEDIFF(year, date_of_birth, CURRENT_DATE()) < 75 THEN ''65-74''
            WHEN DATEDIFF(year, date_of_birth, CURRENT_DATE()) < 85 THEN ''75-84''
            ELSE ''85+''
          END
        data_type: STRING
        sample_values: ["Under 50", "50-64", "65-74", "75-84", "85+"]
        
  - name: hospital_admissions
    description: >
      Hospital admissions with realistic 2-3% mortality rate, age-stratified risk scores,
      and proper length of stay patterns. Enables mortality analysis and risk adjustment.
    
    base_table:
      database: SF_SOLUTIONS
      schema: CLINICAL_QUALITY_SAFETY
      table: ADMISSIONS
      
    primary_key:
      columns:
        - admission_id
    
    dimensions:
      - name: admission_id
        synonyms: ["admission ID", "encounter ID", "visit ID", "stay ID"]
        description: "Unique identifier for each hospital admission"
        expr: admission_id
        data_type: STRING
        unique: true
        
      - name: patient_id
        synonyms: ["patient ID", "patient identifier"]
        description: "Patient identifier"
        expr: patient_id
        data_type: STRING
        
      - name: admission_type
        synonyms: ["type of admission", "admission category", "how admitted"]
        description: "Type of hospital admission"
        expr: admission_type
        data_type: STRING
        sample_values: ["Emergency", "Elective", "Urgent", "Observation"]
        is_enum: true
        
      - name: discharge_disposition
        synonyms: ["discharge status", "where discharged", "disposition", "outcome"]
        description: "Patient''s discharge disposition"
        expr: discharge_disposition
        data_type: STRING
        sample_values: ["Home", "SNF", "Rehab", "AMA", "Expired", "Transfer"]
        is_enum: true
        
      - name: primary_service
        synonyms: ["service", "department", "service line", "admitting service"]
        description: "Primary hospital service"
        expr: primary_service
        data_type: STRING
        sample_values: ["Medicine", "Surgery", "ICU", "Emergency", "Cardiology"]
        
      - name: room_type
        synonyms: ["unit", "ward", "room level", "care level"]
        description: "Type of hospital room/unit"
        expr: room_type
        data_type: STRING
        sample_values: ["ICU", "Step-down", "Med-Surg", "Emergency"]
        
      - name: attending_physician
        synonyms: ["attending", "physician", "doctor", "primary doctor"]
        description: "Attending physician"
        expr: attending_physician
        data_type: STRING
        
      - name: is_readmission
        synonyms: ["readmission", "return visit", "readmitted"]
        description: "Whether this is a readmission"
        expr: is_readmission
        data_type: BOOLEAN
        
    time_dimensions:
      - name: admission_date
        synonyms: ["admit date", "admission time", "when admitted"]
        description: "Date and time of admission"
        expr: admission_date
        data_type: TIMESTAMP_NTZ
        
      - name: discharge_date
        synonyms: ["discharge time", "when discharged", "release date"]
        description: "Date and time of discharge"
        expr: discharge_date
        data_type: TIMESTAMP_NTZ
        
      - name: admission_month
        synonyms: ["month admitted", "admission month"]
        description: "Month of admission (for seasonal analysis)"
        expr: DATE_TRUNC(''month'', admission_date)
        data_type: DATE
        
    facts:
      - name: length_of_stay_days
        synonyms: ["LOS", "length of stay", "days in hospital", "stay duration"]
        description: "Length of stay in days (correlated with age and complexity)"
        expr: length_of_stay_days
        data_type: NUMBER
        
      - name: severity_of_illness_score
        synonyms: ["severity score", "illness severity", "SOI", "acuity"]
        description: "Severity of illness score (1.0-4.0, age-stratified)"
        expr: severity_of_illness_score
        data_type: NUMBER
        
      - name: mortality_risk_score
        synonyms: ["mortality risk", "death risk", "risk score", "mortality probability"]
        description: "Predicted mortality risk (0.001-0.200, age-based)"
        expr: mortality_risk_score
        data_type: NUMBER
        
      - name: days_since_last_discharge
        synonyms: ["time between admissions", "days since discharge"]
        description: "Days since last discharge (for readmission analysis)"
        expr: days_since_last_discharge
        data_type: NUMBER
        
    metrics:
      - name: total_admissions
        synonyms: ["admission count", "number of admissions", "total encounters"]
        description: "Total number of hospital admissions"
        expr: COUNT(admission_id)
        
      - name: average_length_of_stay
        synonyms: ["average LOS", "mean length of stay", "avg days"]
        description: "Average length of stay in days"
        expr: AVG(length_of_stay_days)
        
      - name: icu_admissions
        synonyms: ["ICU admits", "critical care admissions", "intensive care"]
        description: "Number of ICU admissions"
        expr: COUNT(CASE WHEN room_type = ''ICU'' THEN admission_id END)
        
      - name: emergency_admissions
        synonyms: ["ED admits", "emergency admits", "urgent admissions"]
        description: "Number of emergency admissions"
        expr: COUNT(CASE WHEN admission_type = ''Emergency'' THEN admission_id END)
        
      - name: readmission_rate
        synonyms: ["readmission percentage", "return rate"]
        description: "Percentage of admissions that are readmissions"
        expr: COUNT(CASE WHEN is_readmission = TRUE THEN admission_id END) * 100.0 / COUNT(admission_id)
        
      - name: winter_admissions
        synonyms: ["seasonal admissions", "winter surge"]
        description: "Admissions during winter months (Dec-Feb)"
        expr: COUNT(CASE WHEN MONTH(admission_date) IN (12, 1, 2) THEN admission_id END)

  - name: medical_diagnoses
    description: >
      Medical diagnoses with age-appropriate patterns (elderly: heart failure, COPD; 
      deaths: sepsis, cardiac arrest). Enables diagnosis-specific outcome analysis.
    
    base_table:
      database: SF_SOLUTIONS
      schema: CLINICAL_QUALITY_SAFETY
      table: DIAGNOSES
      
    primary_key:
      columns:
        - diagnosis_id
    
    dimensions:
      - name: diagnosis_id
        synonyms: ["diagnosis ID", "diagnosis key", "condition ID"]
        description: "Unique identifier for each diagnosis"
        expr: diagnosis_id
        data_type: STRING
        unique: true
        
      - name: admission_id
        synonyms: ["admission ID", "encounter ID"]
        description: "Admission identifier"
        expr: admission_id
        data_type: STRING
        
      - name: patient_id
        synonyms: ["patient ID", "patient identifier"]
        description: "Patient identifier"
        expr: patient_id
        data_type: STRING
        
      - name: icd10_code
        synonyms: ["ICD code", "ICD-10", "diagnosis code"]
        description: "ICD-10 diagnosis code"
        expr: icd10_code
        data_type: STRING
        
      - name: diagnosis_description
        synonyms: ["diagnosis", "condition", "disease", "medical condition"]
        description: "Description of the medical diagnosis"
        expr: diagnosis_description
        data_type: STRING
        
      - name: diagnosis_type
        synonyms: ["type of diagnosis", "diagnosis category"]
        description: "Type of diagnosis"
        expr: diagnosis_type
        data_type: STRING
        sample_values: ["Primary", "Secondary", "Comorbidity"]
        is_enum: true
        
      - name: present_on_admission
        synonyms: ["POA", "present on admit", "admission diagnosis"]
        description: "Whether diagnosis was present on admission"
        expr: present_on_admission
        data_type: BOOLEAN
        
      - name: complication_flag
        synonyms: ["complication", "hospital complication", "nosocomial"]
        description: "Whether diagnosis is a hospital-acquired complication"
        expr: complication_flag
        data_type: BOOLEAN
        
    time_dimensions:
      - name: diagnosis_date
        synonyms: ["date diagnosed", "diagnosis time"]
        description: "Date the diagnosis was made"
        expr: diagnosis_date
        data_type: DATE
        
    metrics:
      - name: sepsis_cases
        synonyms: ["sepsis count", "infection cases", "septicemia"]
        description: "Number of sepsis cases (leading cause of hospital mortality)"
        expr: COUNT(CASE WHEN icd10_code IN (''A41.9'', ''R65.20'') THEN diagnosis_id END)
        
      - name: heart_failure_cases
        synonyms: ["CHF cases", "cardiac failure", "heart failure admissions"]
        description: "Number of heart failure cases (common in elderly)"
        expr: COUNT(CASE WHEN icd10_code = ''I50.9'' THEN diagnosis_id END)
        
      - name: respiratory_failure_cases
        synonyms: ["resp failure", "breathing problems", "ventilator cases"]
        description: "Number of respiratory failure cases"
        expr: COUNT(CASE WHEN icd10_code = ''J96.00'' THEN diagnosis_id END)

  - name: medical_procedures
    description: >
      Medical procedures with realistic diagnosis-procedure relationships (cardiac cath for MI,
      cholecystectomy for gallstones). Enables procedure-specific outcome analysis.
    
    base_table:
      database: SF_SOLUTIONS
      schema: CLINICAL_QUALITY_SAFETY
      table: PROCEDURES
      
    primary_key:
      columns:
        - procedure_id
    
    dimensions:
      - name: procedure_id
        synonyms: ["procedure ID", "procedure key", "intervention ID"]
        description: "Unique identifier for each procedure"
        expr: procedure_id
        data_type: STRING
        unique: true
        
      - name: admission_id
        synonyms: ["admission ID", "encounter ID"]
        description: "Admission identifier"
        expr: admission_id
        data_type: STRING
        
      - name: patient_id
        synonyms: ["patient ID", "patient identifier"]
        description: "Patient identifier"
        expr: patient_id
        data_type: STRING
        
      - name: cpt_code
        synonyms: ["CPT", "CPT procedure code", "procedure code"]
        description: "CPT procedure code"
        expr: cpt_code
        data_type: STRING
        
      - name: procedure_description
        synonyms: ["procedure", "procedure name", "intervention", "operation"]
        description: "Description of the medical procedure"
        expr: procedure_description
        data_type: STRING
        
      - name: procedure_type
        synonyms: ["type of procedure", "procedure category"]
        description: "Category of procedure"
        expr: procedure_type
        data_type: STRING
        sample_values: ["Surgical", "Diagnostic", "Therapeutic"]
        is_enum: true
        
      - name: procedure_location
        synonyms: ["location", "where performed", "procedure site"]
        description: "Where the procedure was performed"
        expr: procedure_location
        data_type: STRING
        sample_values: ["OR", "ICU", "Floor", "Emergency", "Cardiac Cath Lab"]
        
      - name: anesthesia_type
        synonyms: ["anesthesia", "type of anesthesia"]
        description: "Type of anesthesia used"
        expr: anesthesia_type
        data_type: STRING
        sample_values: ["Local", "Regional", "General", "Conscious sedation", "None"]
        
      - name: complication_occurred
        synonyms: ["complications", "procedural complications", "adverse events"]
        description: "Whether complications occurred during procedure"
        expr: complication_occurred
        data_type: BOOLEAN
        
      - name: infection_risk_level
        synonyms: ["infection risk", "risk level", "contamination risk"]
        description: "Risk level for post-procedure infection"
        expr: infection_risk_level
        data_type: STRING
        sample_values: ["Low", "Medium", "High"]
        is_enum: true
        
    time_dimensions:
      - name: procedure_date
        synonyms: ["date of procedure", "time of procedure", "when performed"]
        description: "Date and time procedure was performed"
        expr: procedure_date
        data_type: TIMESTAMP_NTZ
        
    facts:
      - name: procedure_duration_minutes
        synonyms: ["duration", "length of procedure", "procedure time"]
        description: "Duration of procedure in minutes (CABG: 4-8hrs, cath: 30-90min)"
        expr: procedure_duration_minutes
        data_type: NUMBER
        
    metrics:
      - name: total_procedures
        synonyms: ["procedure count", "number of procedures", "interventions"]
        description: "Total number of procedures performed"
        expr: COUNT(procedure_id)
        
      - name: surgical_procedures
        synonyms: ["surgery count", "operations", "surgical cases"]
        description: "Number of surgical procedures"
        expr: COUNT(CASE WHEN procedure_type = ''Surgical'' THEN procedure_id END)
        
      - name: cardiac_procedures
        synonyms: ["heart procedures", "cardiac interventions", "cardiology procedures"]
        description: "Number of cardiac procedures (cath, CABG, PCI)"
        expr: COUNT(CASE WHEN cpt_code IN (''93458'', ''33533'', ''92982'') THEN procedure_id END)
        
      - name: device_procedures
        synonyms: ["device placement", "line placement", "catheter procedures"]
        description: "Procedures involving device placement (central lines, catheters)"
        expr: COUNT(CASE WHEN cpt_code IN (''36556'', ''51702'', ''31500'') THEN procedure_id END)
        
      - name: procedure_complication_rate
        synonyms: ["complication rate", "procedure complications", "adverse event rate"]
        description: "Percentage of procedures with complications"
        expr: COUNT(CASE WHEN complication_occurred = TRUE THEN procedure_id END) * 100.0 / COUNT(procedure_id)
        
      - name: high_risk_procedures
        synonyms: ["high risk cases", "complex procedures"]
        description: "Number of high infection risk procedures"
        expr: COUNT(CASE WHEN infection_risk_level = ''High'' THEN procedure_id END)

  - name: healthcare_infections
    description: >
      Healthcare-associated infections with realistic device correlations (CAUTI with Foley,
      CLABSI with central lines). Enables device-specific infection rate analysis.
    
    base_table:
      database: SF_SOLUTIONS
      schema: CLINICAL_QUALITY_SAFETY
      table: INFECTIONS
      
    primary_key:
      columns:
        - infection_id
    
    dimensions:
      - name: infection_id
        synonyms: ["infection ID", "infection identifier", "HAI ID"]
        description: "Unique identifier for each infection"
        expr: infection_id
        data_type: STRING
        unique: true
        
      - name: admission_id
        synonyms: ["admission ID", "encounter ID"]
        description: "Admission identifier"
        expr: admission_id
        data_type: STRING
        
      - name: patient_id
        synonyms: ["patient ID", "patient identifier"]
        description: "Patient identifier"
        expr: patient_id
        data_type: STRING
        
      - name: infection_type
        synonyms: ["type of infection", "infection category", "HAI type"]
        description: "Type of healthcare-associated infection"
        expr: infection_type
        data_type: STRING
        sample_values: ["CAUTI", "CLABSI", "VAP", "SSI", "CDIFF", "MRSA", "Pneumonia", "Sepsis"]
        is_enum: true
        
      - name: infection_site
        synonyms: ["site of infection", "infection location", "affected site"]
        description: "Anatomical site of infection"
        expr: infection_site
        data_type: STRING
        sample_values: ["Urinary", "Bloodstream", "Respiratory", "Surgical Site", "Skin/Soft Tissue", "Gastrointestinal"]
        
      - name: pathogen
        synonyms: ["organism", "bacteria", "microorganism", "bug"]
        description: "Microorganism causing the infection (E.coli for CAUTI, Staph for CLABSI)"
        expr: pathogen
        data_type: STRING
        sample_values: ["E. coli", "Staphylococcus aureus", "Pseudomonas aeruginosa", "Klebsiella pneumoniae", "Enterococcus", "Candida albicans", "Clostridium difficile", "Acinetobacter"]
        
      - name: severity
        synonyms: ["infection severity", "severity level", "how severe"]
        description: "Severity level of the infection"
        expr: severity
        data_type: STRING
        sample_values: ["Mild", "Moderate", "Severe", "Life-threatening"]
        is_enum: true
        
      - name: device_associated
        synonyms: ["device related", "device infection", "medical device"]
        description: "Whether infection is associated with a medical device"
        expr: device_associated
        data_type: BOOLEAN
        
      - name: device_type
        synonyms: ["type of device", "device", "medical equipment"]
        description: "Type of medical device associated with infection"
        expr: device_type
        data_type: STRING
        sample_values: ["Foley catheter", "Central line", "Ventilator", "Peripheral IV", "Surgical drain"]
        
      - name: antibiotic_resistance
        synonyms: ["resistant", "antibiotic resistant", "drug resistant", "MDR"]
        description: "Whether infection shows antibiotic resistance"
        expr: antibiotic_resistance
        data_type: BOOLEAN
        
      - name: infection_preventable
        synonyms: ["preventable", "could have been prevented", "avoidable"]
        description: "Whether the infection was preventable (70% of CAUTI, 65% of CLABSI)"
        expr: infection_preventable
        data_type: BOOLEAN
        
      - name: contributed_to_death
        synonyms: ["caused death", "led to death", "death related", "fatal"]
        description: "Whether the infection contributed to patient death"
        expr: contributed_to_death
        data_type: BOOLEAN
        
    time_dimensions:
      - name: onset_date
        synonyms: ["infection date", "date of infection", "when infected"]
        description: "Date infection was identified"
        expr: onset_date
        data_type: DATE
        
      - name: resolution_date
        synonyms: ["resolved date", "cure date", "infection cleared"]
        description: "Date infection was resolved"
        expr: resolution_date
        data_type: DATE
        
    facts:
      - name: days_to_onset
        synonyms: ["days to infection", "incubation period", "onset days"]
        description: "Days from admission to infection onset"
        expr: days_to_onset
        data_type: NUMBER
        
      - name: device_days
        synonyms: ["device utilization", "days with device"]
        description: "Number of days device was in place"
        expr: device_days
        data_type: NUMBER
        
    metrics:
      - name: total_infections
        synonyms: ["infection count", "HAI count", "nosocomial infections"]
        description: "Total number of healthcare-associated infections"
        expr: COUNT(infection_id)
        
      - name: infection_rate
        synonyms: ["HAI rate", "infection percentage"]
        description: "Healthcare-associated infection rate per 100 admissions"
        expr: COUNT(infection_id) * 100.0 / COUNT(DISTINCT admission_id)
        
      - name: cauti_infections
        synonyms: ["catheter UTIs", "urinary tract infections", "Foley infections"]
        description: "Number of catheter-associated urinary tract infections"
        expr: COUNT(CASE WHEN infection_type = ''CAUTI'' THEN infection_id END)
        
      - name: clabsi_infections
        synonyms: ["central line infections", "bloodstream infections", "line sepsis"]
        description: "Number of central line-associated bloodstream infections"
        expr: COUNT(CASE WHEN infection_type = ''CLABSI'' THEN infection_id END)
        
      - name: vap_infections
        synonyms: ["ventilator pneumonia", "VAP cases", "respirator infections"]
        description: "Number of ventilator-associated pneumonia cases"
        expr: COUNT(CASE WHEN infection_type = ''VAP'' THEN infection_id END)
        
      - name: ssi_infections
        synonyms: ["surgical site infections", "wound infections", "post-op infections"]
        description: "Number of surgical site infections"
        expr: COUNT(CASE WHEN infection_type = ''SSI'' THEN infection_id END)
        
      - name: cdiff_infections
        synonyms: ["C diff", "C difficile", "antibiotic-associated colitis"]
        description: "Number of C. difficile infections"
        expr: COUNT(CASE WHEN infection_type = ''CDIFF'' THEN infection_id END)
        
      - name: device_associated_infections
        synonyms: ["device infections", "device-related HAI"]
        description: "Number of device-associated infections"
        expr: COUNT(CASE WHEN device_associated = TRUE THEN infection_id END)
        
      - name: preventable_infections
        synonyms: ["avoidable infections", "preventable HAI"]
        description: "Number of preventable infections"
        expr: COUNT(CASE WHEN infection_preventable = TRUE THEN infection_id END)
        
      - name: fatal_infections
        synonyms: ["deadly infections", "infections causing death"]
        description: "Number of infections that contributed to death"
        expr: COUNT(CASE WHEN contributed_to_death = TRUE THEN infection_id END)
        
      - name: resistant_infections
        synonyms: ["antibiotic resistant infections", "drug resistant bacteria"]
        description: "Number of antibiotic-resistant infections"
        expr: COUNT(CASE WHEN antibiotic_resistance = TRUE THEN infection_id END)
        
      - name: cauti_rate_per_1000_days
        synonyms: ["CAUTI device rate", "catheter infection rate"]
        description: "CAUTI infections per 1000 catheter days"
        expr: >
          COUNT(CASE WHEN infection_type = ''CAUTI'' THEN infection_id END) * 1000.0 / 
          NULLIF(SUM(CASE WHEN device_type = ''Foley catheter'' THEN device_days END), 0)
          
      - name: clabsi_rate_per_1000_days
        synonyms: ["CLABSI device rate", "central line infection rate"]
        description: "CLABSI infections per 1000 central line days"
        expr: >
          COUNT(CASE WHEN infection_type = ''CLABSI'' THEN infection_id END) * 1000.0 / 
          NULLIF(SUM(CASE WHEN device_type = ''Central line'' THEN device_days END), 0)

  - name: patient_outcomes
    description: >
      Patient outcomes with realistic mortality causes tied to infections and procedures.
      Enables analysis of preventable deaths and infection-mortality relationships.
    
    base_table:
      database: SF_SOLUTIONS
      schema: CLINICAL_QUALITY_SAFETY
      table: OUTCOMES
      
    primary_key:
      columns:
        - outcome_id
    
    dimensions:
      - name: outcome_id
        synonyms: ["outcome ID", "outcome identifier", "result ID"]
        description: "Unique identifier for each outcome"
        expr: outcome_id
        data_type: STRING
        unique: true
        
      - name: admission_id
        synonyms: ["admission ID", "encounter ID"]
        description: "Admission identifier"
        expr: admission_id
        data_type: STRING
        
      - name: patient_id
        synonyms: ["patient ID", "patient identifier"]
        description: "Patient identifier"
        expr: patient_id
        data_type: STRING
        
      - name: outcome_type
        synonyms: ["type of outcome", "result", "disposition"]
        description: "Type of patient outcome"
        expr: outcome_type
        data_type: STRING
        sample_values: ["Death", "Discharge", "Transfer", "AMA"]
        is_enum: true
        
      - name: primary_cause
        synonyms: ["cause of death", "primary diagnosis", "main cause"]
        description: "Primary cause of outcome (realistic: sepsis, cardiac arrest, resp failure)"
        expr: primary_cause
        data_type: STRING
        sample_values: ["Sepsis/Infection", "Cardiac arrest", "Respiratory failure", "Heart failure", "COPD exacerbation", "Multiple organ failure"]
        
      - name: expected_vs_actual
        synonyms: ["expected outcome", "mortality prediction", "anticipated result"]
        description: "Whether outcome was expected based on risk score"
        expr: expected_vs_actual
        data_type: STRING
        sample_values: ["Expected", "Somewhat expected", "Unexpected"]
        is_enum: true
        
      - name: preventable
        synonyms: ["avoidable", "could have been prevented", "preventable death"]
        description: "Whether the outcome was preventable"
        expr: preventable
        data_type: BOOLEAN
        
      - name: quality_issue_related
        synonyms: ["quality problem", "care quality issue", "system failure"]
        description: "Whether outcome is related to quality issues"
        expr: quality_issue_related
        data_type: BOOLEAN
        
      - name: infection_related
        synonyms: ["infection caused", "HAI related", "sepsis related"]
        description: "Whether outcome is related to healthcare-associated infection"
        expr: infection_related
        data_type: BOOLEAN
        
      - name: procedure_related
        synonyms: ["surgery related", "procedure complication"]
        description: "Whether outcome is related to procedure complications"
        expr: procedure_related
        data_type: BOOLEAN
        
      - name: medication_related
        synonyms: ["drug related", "medication error", "pharmacy issue"]
        description: "Whether outcome is related to medication issues"
        expr: medication_related
        data_type: BOOLEAN
        
      - name: readmission_within_30_days
        synonyms: ["30-day readmission", "readmitted within 30 days"]
        description: "Whether patient was readmitted within 30 days"
        expr: readmission_within_30_days
        data_type: BOOLEAN
        
      - name: readmission_within_90_days
        synonyms: ["90-day readmission", "readmitted within 90 days"]
        description: "Whether patient was readmitted within 90 days"
        expr: readmission_within_90_days
        data_type: BOOLEAN
        
    time_dimensions:
      - name: outcome_date
        synonyms: ["date of outcome", "outcome time", "when occurred"]
        description: "Date and time of the outcome"
        expr: outcome_date
        data_type: TIMESTAMP_NTZ
        
    facts:
      - name: satisfaction_score
        synonyms: ["patient satisfaction", "satisfaction rating", "HCAHPS score"]
        description: "Patient satisfaction score (lower for deaths and complications)"
        expr: satisfaction_score
        data_type: NUMBER
        
    metrics:
      - name: total_deaths
        synonyms: ["mortality count", "number of deaths", "death count", "fatalities"]
        description: "Total number of patient deaths"
        expr: COUNT(CASE WHEN outcome_type = ''Death'' THEN outcome_id END)
        
      - name: mortality_rate
        synonyms: ["death rate", "mortality percentage", "case fatality rate"]
        description: "Percentage of admissions resulting in death (realistic: 2-3%)"
        expr: >
          COUNT(CASE WHEN outcome_type = ''Death'' THEN outcome_id END) * 100.0 / 
          COUNT(DISTINCT admission_id)
        
      - name: infection_related_deaths
        synonyms: ["deaths from infection", "infection mortality", "sepsis deaths", "HAI deaths"]
        description: "Number of deaths related to healthcare-associated infections"
        expr: COUNT(CASE WHEN outcome_type = ''Death'' AND infection_related = TRUE THEN outcome_id END)
        
      - name: preventable_deaths
        synonyms: ["avoidable deaths", "preventable mortality"]
        description: "Number of deaths that were preventable"
        expr: COUNT(CASE WHEN outcome_type = ''Death'' AND preventable = TRUE THEN outcome_id END)
        
      - name: unexpected_deaths
        synonyms: ["unexpected mortality", "unanticipated deaths"]
        description: "Number of unexpected deaths (low predicted risk)"
        expr: COUNT(CASE WHEN outcome_type = ''Death'' AND expected_vs_actual = ''Unexpected'' THEN outcome_id END)
        
      - name: procedure_related_deaths
        synonyms: ["operative mortality", "surgical deaths", "procedure deaths"]
        description: "Number of deaths related to procedure complications"
        expr: COUNT(CASE WHEN outcome_type = ''Death'' AND procedure_related = TRUE THEN outcome_id END)
        
      - name: thirty_day_readmissions
        synonyms: ["30-day readmission count", "readmissions within 30 days"]
        description: "Number of 30-day readmissions"
        expr: COUNT(CASE WHEN readmission_within_30_days = TRUE THEN outcome_id END)
        
      - name: average_satisfaction_score
        synonyms: ["mean satisfaction", "avg patient satisfaction", "HCAHPS average"]
        description: "Average patient satisfaction score"
        expr: AVG(satisfaction_score)
        
      - name: sepsis_mortality_rate
        synonyms: ["sepsis death rate", "infection death rate"]
        description: "Mortality rate for sepsis/infection cases"
        expr: >
          COUNT(CASE WHEN outcome_type = ''Death'' AND primary_cause = ''Sepsis/Infection'' THEN outcome_id END) * 100.0 / 
          NULLIF(COUNT(CASE WHEN primary_cause = ''Sepsis/Infection'' THEN outcome_id END), 0)

  - name: quality_safety_events
    description: >
      Patient safety events with realistic age and device correlations (pressure injuries 
      in elderly, device malfunctions with device usage). Enables preventability analysis.
    
    base_table:
      database: SF_SOLUTIONS
      schema: CLINICAL_QUALITY_SAFETY
      table: QUALITY_EVENTS
      
    primary_key:
      columns:
        - event_id
    
    dimensions:
      - name: event_id
        synonyms: ["event ID", "safety event ID", "incident ID"]
        description: "Unique identifier for each quality event"
        expr: event_id
        data_type: STRING
        unique: true
        
      - name: admission_id
        synonyms: ["admission ID", "encounter ID"]
        description: "Admission identifier"
        expr: admission_id
        data_type: STRING
        
      - name: patient_id
        synonyms: ["patient ID", "patient identifier"]
        description: "Patient identifier"
        expr: patient_id
        data_type: STRING
        
      - name: event_type
        synonyms: ["type of event", "safety event type", "incident type"]
        description: "Type of patient safety event"
        expr: event_type
        data_type: STRING
        sample_values: ["Pressure_Injury", "Fall", "Medication_Error", "Wrong_Site_Surgery", "Device_Malfunction", "Communication_Failure"]
        
      - name: severity
        synonyms: ["event severity", "severity level", "how serious"]
        description: "Severity level of the safety event"
        expr: severity
        data_type: STRING
        sample_values: ["Minor", "Moderate", "Major", "Catastrophic"]
        is_enum: true
        
      - name: harm_level
        synonyms: ["harm", "patient harm", "level of harm", "injury level"]
        description: "Level of harm caused to patient"
        expr: harm_level
        data_type: STRING
        sample_values: ["No harm", "Temporary harm", "Permanent harm", "Death"]
        is_enum: true
        
      - name: preventable
        synonyms: ["could have been prevented", "preventable event", "avoidable"]
        description: "Whether the event was preventable (70-90% of events)"
        expr: preventable
        data_type: BOOLEAN
        
      - name: reported_by
        synonyms: ["who reported", "reporter", "reporting person"]
        description: "Who reported the safety event"
        expr: reported_by
        data_type: STRING
        sample_values: ["Nurse", "Physician", "Patient", "Family"]
        
      - name: location
        synonyms: ["where occurred", "event location", "unit"]
        description: "Hospital location where event occurred"
        expr: location
        data_type: STRING
        
      - name: event_resolved
        synonyms: ["resolved", "fixed", "completed"]
        description: "Whether the event has been resolved"
        expr: event_resolved
        data_type: BOOLEAN
        
      - name: contributed_to_death
        synonyms: ["caused death", "led to death", "death related", "fatal event"]
        description: "Whether the event contributed to patient death"
        expr: contributed_to_death
        data_type: BOOLEAN
        
    time_dimensions:
      - name: event_date
        synonyms: ["date of event", "when occurred", "event time"]
        description: "Date the safety event occurred"
        expr: event_date
        data_type: DATE
        
      - name: resolution_date
        synonyms: ["date resolved", "when fixed", "completion date"]
        description: "Date the event was resolved"
        expr: resolution_date
        data_type: DATE
        
    metrics:
      - name: total_quality_events
        synonyms: ["safety event count", "number of quality events", "adverse event count"]
        description: "Total number of patient safety events"
        expr: COUNT(event_id)
        
      - name: quality_event_rate
        synonyms: ["safety event rate", "incident rate"]
        description: "Safety events per 100 admissions"
        expr: COUNT(event_id) * 100.0 / COUNT(DISTINCT admission_id)
        
      - name: pressure_injuries
        synonyms: ["pressure ulcer count", "bedsore count", "skin breakdown"]
        description: "Number of pressure injury events (common in elderly)"
        expr: COUNT(CASE WHEN event_type = ''Pressure_Injury'' THEN event_id END)
        
      - name: falls
        synonyms: ["patient falls", "fall incidents", "fall injuries"]
        description: "Number of patient fall events"
        expr: COUNT(CASE WHEN event_type = ''Fall'' THEN event_id END)
        
      - name: medication_errors
        synonyms: ["drug errors", "pharmacy errors", "medication mistakes"]
        description: "Number of medication error events"
        expr: COUNT(CASE WHEN event_type = ''Medication_Error'' THEN event_id END)
        
      - name: preventable_events
        synonyms: ["avoidable events", "preventable incidents"]
        description: "Number of preventable safety events"
        expr: COUNT(CASE WHEN preventable = TRUE THEN event_id END)
        
      - name: serious_events
        synonyms: ["major events", "severe incidents", "serious safety events"]
        description: "Number of major or catastrophic events"
        expr: COUNT(CASE WHEN severity IN (''Major'', ''Catastrophic'') THEN event_id END)
        
      - name: events_causing_harm
        synonyms: ["harmful events", "events with injury"]
        description: "Number of events causing temporary or permanent harm"
        expr: COUNT(CASE WHEN harm_level IN (''Temporary harm'', ''Permanent harm'', ''Death'') THEN event_id END)

  - name: patient_risk_factors
    description: >
      Patient risk factors with realistic age-based comorbidity clusters (diabetes+hypertension 
      in elderly). Enables risk-stratified analysis and outcome prediction.
    
    base_table:
      database: SF_SOLUTIONS
      schema: CLINICAL_QUALITY_SAFETY
      table: RISK_FACTORS
      
    primary_key:
      columns:
        - risk_factor_id
    
    dimensions:
      - name: risk_factor_id
        synonyms: ["risk ID", "risk factor ID", "comorbidity ID"]
        description: "Unique identifier for each risk factor"
        expr: risk_factor_id
        data_type: STRING
        unique: true
        
      - name: patient_id
        synonyms: ["patient ID", "patient identifier"]
        description: "Patient identifier"
        expr: patient_id
        data_type: STRING
        
      - name: admission_id
        synonyms: ["admission ID", "encounter ID"]
        description: "Admission identifier"
        expr: admission_id
        data_type: STRING
        
      - name: risk_factor_type
        synonyms: ["type of risk", "risk category"]
        description: "Category of risk factor"
        expr: risk_factor_type
        data_type: STRING
        sample_values: ["Comorbidity", "Social", "Environmental"]
        is_enum: true
        
      - name: risk_factor_name
        synonyms: ["risk factor", "comorbidity", "condition"]
        description: "Name of the risk factor"
        expr: risk_factor_name
        data_type: STRING
        sample_values: ["Diabetes mellitus", "Hypertension", "COPD", "Heart failure", "Chronic kidney disease", "Age > 65", "Obesity"]
        
      - name: chronic_condition
        synonyms: ["chronic disease", "long-term condition"]
        description: "Whether this is a chronic condition"
        expr: chronic_condition
        data_type: BOOLEAN
        
      - name: affects_mortality_risk
        synonyms: ["increases death risk", "mortality risk factor"]
        description: "Whether this factor increases mortality risk"
        expr: affects_mortality_risk
        data_type: BOOLEAN
        
      - name: affects_infection_risk
        synonyms: ["increases infection risk", "infection risk factor"]
        description: "Whether this factor increases infection risk"
        expr: affects_infection_risk
        data_type: BOOLEAN
        
      - name: affects_los_risk
        synonyms: ["increases length of stay", "LOS risk factor"]
        description: "Whether this factor increases length of stay"
        expr: affects_los_risk
        data_type: BOOLEAN
        
    time_dimensions:
      - name: documented_date
        synonyms: ["date documented", "when identified"]
        description: "Date risk factor was documented"
        expr: documented_date
        data_type: DATE
        
    facts:
      - name: severity_score
        synonyms: ["risk score", "severity rating", "risk level"]
        description: "Severity score for this risk factor (1.0-4.5)"
        expr: severity_score
        data_type: NUMBER
        
    metrics:
      - name: total_risk_factors
        synonyms: ["comorbidity count", "risk factor count"]
        description: "Total number of documented risk factors"
        expr: COUNT(risk_factor_id)
        
      - name: diabetes_cases
        synonyms: ["diabetic patients", "diabetes mellitus"]
        description: "Number of patients with diabetes"
        expr: COUNT(CASE WHEN risk_factor_name = ''Diabetes mellitus'' THEN risk_factor_id END)
        
      - name: hypertension_cases
        synonyms: ["high blood pressure", "HTN patients"]
        description: "Number of patients with hypertension"
        expr: COUNT(CASE WHEN risk_factor_name = ''Hypertension'' THEN risk_factor_id END)
        
      - name: elderly_patients
        synonyms: ["patients over 65", "geriatric patients"]
        description: "Number of elderly patients (age > 65)"
        expr: COUNT(CASE WHEN risk_factor_name = ''Age > 65'' THEN risk_factor_id END)
        
      - name: high_mortality_risk_factors
        synonyms: ["death risk factors", "mortality risks"]
        description: "Number of risk factors that increase mortality"
        expr: COUNT(CASE WHEN affects_mortality_risk = TRUE THEN risk_factor_id END)
        
      - name: high_infection_risk_factors
        synonyms: ["infection risk factors", "HAI risks"]
        description: "Number of risk factors that increase infection risk"
        expr: COUNT(CASE WHEN affects_infection_risk = TRUE THEN risk_factor_id END)

# Define relationships between tables
relationships:
  - name: admissions_to_patient
    left_table: hospital_admissions
    right_table: patient_demographics
    relationship_columns:
      - left_column: patient_id
        right_column: patient_id
    join_type: left_outer
    relationship_type: many_to_one
    
  - name: diagnoses_to_admissions
    left_table: medical_diagnoses
    right_table: hospital_admissions
    relationship_columns:
      - left_column: admission_id
        right_column: admission_id
    join_type: left_outer
    relationship_type: many_to_one
    
  - name: procedures_to_admissions
    left_table: medical_procedures
    right_table: hospital_admissions
    relationship_columns:
      - left_column: admission_id
        right_column: admission_id
    join_type: left_outer
    relationship_type: many_to_one
    
  - name: infections_to_admissions
    left_table: healthcare_infections
    right_table: hospital_admissions
    relationship_columns:
      - left_column: admission_id
        right_column: admission_id
    join_type: left_outer
    relationship_type: many_to_one
    
  - name: quality_events_to_admissions
    left_table: quality_safety_events
    right_table: hospital_admissions
    relationship_columns:
      - left_column: admission_id
        right_column: admission_id
    join_type: left_outer
    relationship_type: many_to_one
    
  - name: outcomes_to_admissions
    left_table: patient_outcomes
    right_table: hospital_admissions
    relationship_columns:
      - left_column: admission_id
        right_column: admission_id
    join_type: left_outer
    relationship_type: many_to_one
    
  - name: risk_factors_to_admissions
    left_table: patient_risk_factors
    right_table: hospital_admissions
    relationship_columns:
      - left_column: admission_id
        right_column: admission_id
    join_type: left_outer
    relationship_type: many_to_one '
)
OVERWRITE = TRUE
SINGLE = TRUE;

-- ============================================================
-- Section 4: Cortex Agent
-- ============================================================
CREATE OR REPLACE AGENT clinical_quality_safety_agent
  COMMENT = 'Clinical Quality and Patient Safety Agent with Cortex Analyst, PubMed Search, and Email capabilities'
  PROFILE = '{"display_name": "Clinical Quality Assistant", "avatar": "healthcare-icon.png", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  instructions:
    response: "Respond as if talking to someone working in healthcare provider focused on analyzing and improving quality. Keep friendly tone. Be concise. Provide next possible questions as well."
    orchestration: "Whenever possible, use a chart to render the results of a question even if the user doesn't explicitly ask for one.\n\nWhen asking to send email or report call the EMAIL_SEND tool and make sure to format the email in a nicely presentable way in Rich Text."

  tools:
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: PATIENT_QUALITY_ANALYST
        description: |
          TABLE1: patient_demographics
          - Database: SF_SOLUTIONS, Schema: CLINICAL_QUALITY_SAFETY
          - Contains comprehensive patient demographic information with realistic age distribution where 65% of patients are over 65 years old, reflecting typical hospital populations. The table includes insurance patterns and demographic characteristics that enable age-stratified mortality and risk analysis.
          - This foundational table supports population health analytics and enables segmentation by key demographic factors that influence healthcare outcomes and quality metrics.
          - LIST OF COLUMNS: patient_id (unique patient identifier), medical_record_number (MRN for patient records), patient_name (full name combining first and last), gender (patient sex), race (racial background categories), insurance_type (coverage type like Medicare/Medicaid), primary_language (preferred language), date_of_birth (birth date), patient_age (current age in years), age_group (clinically meaningful age ranges)

          TABLE2: hospital_admissions
          - Database: SF_SOLUTIONS, Schema: CLINICAL_QUALITY_SAFETY
          - Tracks hospital admissions with realistic 2-3% mortality rates and includes comprehensive admission details like type, service, and disposition. Contains readmission tracking and length of stay metrics correlated with patient age and complexity.
          - Enables analysis of admission patterns, seasonal trends, readmission rates, and serves as the central hub connecting patients to their clinical encounters and outcomes.
          - LIST OF COLUMNS: admission_id (unique encounter identifier), patient_id (patient identifier - links to patient_demographics), admission_type (Emergency/Elective/Urgent), discharge_disposition (Home/SNF/Expired/etc), primary_service (Medicine/Surgery/ICU), room_type (ICU/Med-Surg/Emergency), attending_physician (primary doctor), is_readmission (return visit flag), admission_date (admit timestamp), discharge_date (discharge timestamp), admission_month (for seasonal analysis), length_of_stay_days (LOS duration), severity_of_illness_score (1.0-4.0 acuity), mortality_risk_score (0.001-0.200 death probability), days_since_last_discharge (readmission analysis)

          TABLE3: medical_diagnoses
          - Database: SF_SOLUTIONS, Schema: CLINICAL_QUALITY_SAFETY
          - Contains medical diagnoses with age-appropriate patterns where elderly patients show higher rates of heart failure, COPD, and diabetes. Includes ICD-10 coding and tracks hospital-acquired complications versus present-on-admission conditions.
          - Supports clinical outcome analysis and enables identification of high-risk diagnoses that correlate with mortality and infection rates, particularly sepsis as a leading cause of hospital deaths.
          - LIST OF COLUMNS: diagnosis_id (unique diagnosis identifier), admission_id (encounter identifier - links to hospital_admissions), patient_id (patient identifier), icd10_code (ICD-10 diagnosis code), diagnosis_description (condition name), diagnosis_type (Primary/Secondary/Comorbidity), present_on_admission (POA flag), complication_flag (hospital-acquired indicator), diagnosis_date (when diagnosed)

          TABLE4: medical_procedures
          - Database: SF_SOLUTIONS, Schema: CLINICAL_QUALITY_SAFETY
          - Documents medical procedures with realistic diagnosis-procedure relationships such as cardiac catheterization for MI patients and device placements. Includes procedure duration, location, anesthesia type, and complication tracking.
          - Enables analysis of procedural outcomes, complication rates, and supports quality improvement initiatives by identifying high-risk procedures and their associated mortality and infection risks.
          - LIST OF COLUMNS: procedure_id (unique procedure identifier), admission_id (encounter identifier - links to hospital_admissions), patient_id (patient identifier), cpt_code (CPT procedure code), procedure_description (procedure name), procedure_type (Surgical/Diagnostic/Therapeutic), procedure_location (OR/ICU/Floor), anesthesia_type (Local/Regional/General), complication_occurred (adverse event flag), infection_risk_level (Low/Medium/High), procedure_date (when performed), procedure_duration_minutes (length of procedure)

          TABLE5: healthcare_infections
          - Database: SF_SOLUTIONS, Schema: CLINICAL_QUALITY_SAFETY
          - Tracks healthcare-associated infections with realistic device correlations like CAUTI with Foley catheters and CLABSI with central lines. Contains pathogen information, severity levels, and antibiotic resistance patterns.
          - Critical for infection control analysis and quality improvement, enabling calculation of device-specific infection rates and identification of preventable infections that contribute to patient mortality.
          - LIST OF COLUMNS: infection_id (unique infection identifier), admission_id (encounter identifier - links to hospital_admissions), patient_id (patient identifier), infection_type (CAUTI/CLABSI/VAP/SSI), infection_site (anatomical location), pathogen (causative organism), severity (infection severity level), device_associated (medical device flag), device_type (Foley/Central line/Ventilator), antibiotic_resistance (drug resistance flag), infection_preventable (avoidable infection flag), contributed_to_death (mortality factor), onset_date (infection identification date), resolution_date (infection cleared date), days_to_onset (admission to infection days), device_days (device utilization days)

          TABLE6: patient_outcomes
          - Database: SF_SOLUTIONS, Schema: CLINICAL_QUALITY_SAFETY
          - Records patient outcomes with realistic mortality causes tied to infections and procedures, enabling analysis of preventable deaths and infection-mortality relationships. Includes expected versus actual outcomes based on risk scores.
          - Central to quality analytics for measuring mortality rates, preventable deaths, readmission patterns, and patient satisfaction scores, with specific focus on infection-related and procedure-related mortality.
          - LIST OF COLUMNS: outcome_id (unique outcome identifier), admission_id (encounter identifier - links to hospital_admissions), patient_id (patient identifier), outcome_type (Death/Discharge/Transfer), primary_cause (cause of outcome like sepsis/cardiac arrest), expected_vs_actual (outcome prediction accuracy), preventable (avoidable outcome flag), quality_issue_related (care quality problem flag), infection_related (HAI-caused outcome), procedure_related (surgery complication outcome), medication_related (drug-related outcome), readmission_within_30_days (30-day readmit flag), readmission_within_90_days (90-day readmit flag), outcome_date (outcome timestamp), satisfaction_score (patient satisfaction rating)

          TABLE7: quality_safety_events
          - Database: SF_SOLUTIONS, Schema: CLINICAL_QUALITY_SAFETY
          - Documents patient safety events with realistic age and device correlations such as pressure injuries in elderly patients and device malfunctions. Tracks event severity, harm levels, and preventability with 70-90% of events being preventable.
          - Essential for patient safety analysis and quality improvement initiatives, enabling identification of preventable adverse events and their contribution to patient harm and mortality.
          - LIST OF COLUMNS: event_id (unique safety event identifier), admission_id (encounter identifier - links to hospital_admissions), patient_id (patient identifier), event_type (Pressure_Injury/Fall/Medication_Error), severity (event severity level), harm_level (patient harm degree), preventable (avoidable event flag), reported_by (event reporter), location (hospital unit where occurred), event_resolved (resolution status), contributed_to_death (mortality factor), event_date (occurrence date), resolution_date (resolution completion date)

          TABLE8: patient_risk_factors
          - Database: SF_SOLUTIONS, Schema: CLINICAL_QUALITY_SAFETY
          - Contains patient risk factors with realistic age-based comorbidity clusters like diabetes and hypertension in elderly patients. Includes severity scores and flags indicating impact on mortality, infection, and length of stay risks.
          - Enables risk-stratified analysis and outcome prediction by identifying patients with multiple comorbidities and chronic conditions that increase vulnerability to adverse outcomes and healthcare-associated infections.
          - LIST OF COLUMNS: risk_factor_id (unique risk identifier), patient_id (patient identifier), admission_id (encounter identifier - links to hospital_admissions), risk_factor_type (Comorbidity/Social/Environmental), risk_factor_name (specific risk like diabetes/hypertension), chronic_condition (long-term condition flag), affects_mortality_risk (death risk factor), affects_infection_risk (HAI risk factor), affects_los_risk (length of stay factor), documented_date (documentation date), severity_score (risk severity 1.0-4.5)

          REASONING:
          This semantic model is specifically designed for healthcare quality analytics, enabling Chief Quality Officers to analyze patient outcomes, mortality rates, healthcare-associated infections, and patient safety events. The model centers around hospital admissions as the primary entity, with all other tables linking through admission_id and patient_id to create a comprehensive view of patient care episodes. The realistic clinical relationships built into the data (such as age-appropriate diagnoses, device-associated infections, and procedure-mortality correlations) make it particularly valuable for identifying quality improvement opportunities, analyzing preventable adverse events, and measuring key quality metrics like infection rates, mortality rates, and patient safety indicators.

          DESCRIPTION:
          This healthcare quality analytics semantic model enables comprehensive analysis of patient outcomes, mortality, infections, and safety events across hospital admissions in the SF_SOLUTIONS database. The model centers on hospital admissions with realistic clinical relationships connecting patient demographics, diagnoses, procedures, healthcare-associated infections, and patient outcomes to support quality improvement initiatives. It includes detailed tracking of preventable deaths, device-associated infections (CAUTI, CLABSI, VAP), patient safety events, and risk factors with age-appropriate comorbidity patterns reflecting typical hospital populations where 65% of patients are over 65. The interconnected tables enable analysis of infection-mortality relationships, procedure complications, readmission patterns, and quality metrics essential for Chief Quality Officers to identify improvement opportunities and measure healthcare quality performance. Key analytical capabilities include mortality rate analysis, infection control metrics, patient safety event tracking, and risk-stratified outcome prediction across all major clinical domains.

    - tool_spec:
        type: cortex_search
        name: PUBMED_SEARCH_SERVICE
        description: "This contains data from NCBI Pubmed - PubMed comprises more than 38 million citations for biomedical literature from MEDLINE, life science journals, and online books."

    - tool_spec:
        type: generic
        name: email_send
        description: |
          PROCEDURE/FUNCTION DETAILS:
          - Type: Custom Function
          - Language: JavaScript
          - Signature: (RECIPIENTS VARCHAR, SUBJECT VARCHAR, EMAIL_CONTENT VARCHAR)
          - Returns: BOOLEAN
          - Execution: CALLER with CALLED ON NULL INPUT
          - Volatility: VOLATILE
          - Primary Function: Email notification sending
          - Target: External email recipients via Snowflake's email system
          - Error Handling: Returns true on completion, relies on underlying SYSTEM$SEND_EMAIL error handling

          DESCRIPTION:
          This JavaScript-based custom function serves as a streamlined wrapper for Snowflake's built-in email notification system, enabling automated email delivery directly from database operations. The function accepts three parameters - recipient email addresses, subject line, and email content - and leverages Snowflake's SYSTEM$SEND_EMAIL procedure through the 'EMAIL_CONNECTOR' integration to send notifications to external parties. It executes with caller privileges and processes null inputs, making it suitable for integration into stored procedures, triggers, or scheduled tasks where email notifications are required. This function is particularly valuable for automated reporting, alert systems, and workflow notifications that need to communicate database events or results to business stakeholders. Users should ensure proper email connector configuration and appropriate permissions are in place, as the function's success depends on the underlying Snowflake email integration being properly set up and authorized.

          USAGE SCENARIOS:
          - Automated reporting: Send daily/weekly summary reports or data extracts to business users and stakeholders
          - Alert notifications: Trigger immediate email alerts when data quality issues, threshold breaches, or system anomalies are detected
          - Workflow integration: Notify team members when ETL processes complete, data loads finish, or scheduled maintenance tasks are performed
        input_schema:
          type: object
          properties:
            email_content:
              description: "5 word summary of the data that were sending."
              type: string
            recipients:
              description: "Ask the user for the email that they should send this to. This should be an input from the user."
              type: string
            subject:
              description: "Send data from the last prompt that the user sent. Add this information as the email content."
              type: string
          required:
            - email_content
            - recipients
            - subject

  tool_resources:
    PATIENT_QUALITY_ANALYST:
      semantic_model_file: "@SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.SEMANTIC_MODEL_STAGE/02_semantic_model_realistic.yaml"
      execution_environment:
        type: warehouse
        warehouse: SF_SOLUTIONS_WH
        query_timeout: 100
    PUBMED_SEARCH_SERVICE:
      name: "PUBMED_BIOMEDICAL_RESEARCH_CORPUS.OA_COMM.PUBMED_OA_CKE_SEARCH_SERVICE"
      max_results: 4
      id_column: "ARTICLE_URL"
      title_column: "ARTICLE_CITATION"
    email_send:
      type: procedure
      identifier: "SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.EMAIL_CONNECTOR"
      name: "EMAIL_CONNECTOR(VARCHAR, VARCHAR, VARCHAR)"
      execution_environment:
        type: warehouse
        warehouse: SF_SOLUTIONS_WH
  $$;


-- ============================================================
-- Section 5: Final Verification
-- ============================================================
SELECT
    'Clinical Quality and Patient Safety Agent deployed!' AS STATUS,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.PATIENTS) AS PATIENT_COUNT,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.ADMISSIONS) AS ADMISSION_COUNT,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.INFECTIONS) AS INFECTION_COUNT,
    (SELECT COUNT(*) FROM SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.OUTCOMES) AS OUTCOME_COUNT;
