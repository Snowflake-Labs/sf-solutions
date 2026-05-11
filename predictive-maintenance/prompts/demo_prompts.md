# Demo Prompts — Predictive Maintenance

### --- 1. Data Exploration & Understanding ---

**Prompt 1-1: Table Discovery**
```
I have manufacturing IoT data in SF_SOLUTIONS. Explore the tables in the PRED_MAINT_RAW schema and summarize what data is available — row counts, key columns, and date ranges.
```

**Prompt 1-2: Sensor Data Profiling**
```
Profile the SENSOR_READINGS table in SF_SOLUTIONS.PRED_MAINT_RAW. Show me:
- Time range and reading frequency
- Number of equipment monitored
- Sensor types available (temperature, vibration, etc.)
- Any obvious outliers or missing data
```

**Prompt 1-3: Visualize Sensor Trends**
```
Show me the daily average vibration trend for each piece of equipment from SF_SOLUTIONS.PRED_MAINT_RAW.SENSOR_READINGS over the past 6 months. Visualize as a multi-line chart. Highlight any that show an upward trend.
```

---

### --- 2. ML Model Building (Anomaly Detection) ---

**Prompt 2-1: Feature Engineering**
```
Create a daily feature view in SF_SOLUTIONS.PRED_MAINT_ANALYTICS that aggregates hourly sensor readings into daily statistics per equipment: average, max, and standard deviation for temperature and vibration, plus average and max current.
```

**Prompt 2-2: Build Anomaly Detection Model**
```
Using Snowflake ML Anomaly Detection, build a model called EQUIPMENT_ANOMALY_MODEL in SF_SOLUTIONS.PRED_MAINT_ANALYTICS. Use EQUIPMENT_ID as the series column, READING_DATE as the timestamp, and AVG_VIBRATION as the target. Use 99% prediction intervals.
```

**Prompt 2-3: Detect & Store Anomalies**
```
Run anomaly detection on the latest sensor data and store the results in SF_SOLUTIONS.PRED_MAINT_ML.ANOMALY_RESULTS. Include the equipment ID, date, actual value, forecast bounds, and whether it's anomalous.
```

**Prompt 2-4: Investigate Anomalies**
```
Which equipment has the most anomalies in the past 30 days? Show me a breakdown by equipment with the count and average severity. Visualize the anomalous readings for the top 3 worst machines.
```

---

### --- 3. Health Scoring & Alerts ---

**Prompt 3-1: Equipment Health Score**
```
Create an equipment health scoring system that combines:
1. Anomaly frequency in the last 30 days
2. Number of corrective (unplanned) maintenance events in the past year
3. Days since last maintenance
4. Anomaly severity (distance from expected)

Score each machine 0-100 (100 = healthy) and assign status: CRITICAL, WARNING, MONITOR, or HEALTHY. Create this as a view called EQUIPMENT_HEALTH_SCORE.
```

**Prompt 3-2: Alert Dashboard**
```
Which equipment needs immediate attention? Show me all machines with CRITICAL or WARNING status, including their health score, anomaly count, and days since last maintenance. Visualize as a bar chart sorted by health score.
```

**Prompt 3-3: Plant Summary**
```
Give me a plant-level summary showing the number of healthy vs at-risk machines per plant, average health score, and total downtime hours in the past year.
```

---

### --- 4. End-to-End Orchestration ---

**Prompt 4-1: Full Pipeline**
```
Walk me through the complete predictive maintenance pipeline:
1. Show me what sensor and equipment data we have in SF_SOLUTIONS
2. Create daily feature aggregations from the raw sensor data
3. Build an anomaly detection model
4. Detect anomalies and identify at-risk equipment
5. Score equipment health and generate maintenance alerts
6. Summarize which machines need immediate attention

Execute each step and show results along the way.
```
