# Predictive Maintenance

| | |
|---|---|
| **Solution Name** | Predictive Maintenance |
| **Industry** | Manufacturing |

An end-to-end Snowflake solution for **IoT-driven predictive maintenance** — detecting equipment anomalies from sensor data and scoring machine health to prevent unplanned downtime.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                             SF_SOLUTIONS                                  │
├──────────────────────────┬────────────────────────────┬──────────────────┤
│ PRED_MAINT_RAW           │ PRED_MAINT_ANALYTICS       │ PRED_MAINT_ML    │
│                          │                            │                  │
│ • EQUIPMENT              │ • DAILY_EQUIPMENT_FEATURES │ • ANOMALY_RESULTS│
│ • SENSOR_READINGS        │ • EQUIPMENT_HEALTH_SCORE   │                  │
│   (120K rows, hourly)    │ • MAINTENANCE_ALERTS       │ • equipment_     │
│ • MAINTENANCE_LOG        │ • PLANT_HEALTH_SUMMARY     │   anomaly_model  │
│                          │ • DAILY_HEALTH_SNAPSHOT    │                  │
└──────────────────────────┴────────────────────────────┴──────────────────┘
```

## Quick Start

### Step 1. Create sample data

```sql
-- English version (US plants):
@data/01_create_sample_data.sql

-- Japanese version (日本工場データ):
@data/01_create_sample_data_JA.sql
```

### Step 2. Run demo prompts

Once data is loaded, run prompts from `prompts/` in Cortex Code to interactively build the anomaly detection model, health scores, and alerts.

- English: [`prompts/demo_prompts.md`](prompts/demo_prompts.md)
- 日本語: [`prompts/demo_prompts_JA.md`](prompts/demo_prompts_JA.md)

> **Note:** Files in `models/` are reference implementations showing the expected output of the demo prompts.

## Demo Prompt Categories

| Category | Demonstrates |
|----------|-------------|
| Data Exploration | Sensor profiling, trend visualization, outlier detection |
| ML Anomaly Detection | Feature engineering, model build, anomaly scoring |
| Health Scoring & Alerts | Multi-factor health score, alert prioritization |
| End-to-End | Full pipeline from raw sensors to maintenance recommendations |

## Data Details

| Table | Rows (approx) | Description |
|-------|---------------|-------------|
| EQUIPMENT | 10 | Machine dimension (CNC, Press, Motor, Robot, Welder, Compressor, Packaging) |
| SENSOR_READINGS | ~120,000 | Hourly readings: temperature, vibration, pressure, current (Jan 2024 – May 2025) |
| MAINTENANCE_LOG | 15 | Historical maintenance events (preventive + corrective) |

### Sensor patterns built into synthetic data:
- **Baseline by equipment type**: Different normal ranges per machine category
- **Operating hours effect**: Higher readings during 8AM–5PM shift
- **Gradual degradation**: EQ001, EQ005, EQ009 show slow temperature rise after day 300
- **Vibration anomalies**: EQ003, EQ006, EQ008 show increasing vibration after day 250
- **Pressure drop**: EQ009 shows declining pressure (valve leak pattern)
- **Current creep**: EQ005, EQ006 show rising current draw (motor degradation)

## Prerequisites

- Snowflake account with SYSADMIN role access
- Warehouse (default: COMPUTE_WH)

## File Structure

```
predictive-maintenance/
├── README.md
├── data/
│   ├── 01_create_sample_data.sql       # Synthetic data (English / US plants)
│   └── 01_create_sample_data_JA.sql    # Synthetic data (日本語 / JP plants)
├── models/
│   ├── 02_anomaly_detection.sql        # Reference: ML anomaly detection
│   └── 03_health_scoring_alerts.sql    # Reference: Health scoring & alerts
└── prompts/
    ├── demo_prompts.md                 # Demo prompts (English)
    └── demo_prompts_JA.md              # Demo prompts (日本語)
```
