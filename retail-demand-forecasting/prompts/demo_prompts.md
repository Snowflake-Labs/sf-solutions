# Cloud Agents Demo Prompts — Retail Demand Forecasting & Inventory Optimization
# These prompts showcase Cortex Code / Cloud Agents capabilities in a retail setting.
# Each prompt is designed to demonstrate a different capability.

### --- 1. Data Exploration & Understanding ---

**Prompt 1-1: Table Discovery**
```
I have a retail database called SF_SOLUTIONS. Can you explore the tables in the RETAIL_DEMAND_FORECAST_RAW schema and tell me what data is available? Summarize the row counts and key columns.
```

**Prompt 1-2: Data Profiling**
```
Profile the DAILY_SALES table in SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_RAW. Show me:
- Date range covered
- Number of unique stores and products
- Total revenue and units sold
- Any anomalies or data quality issues
```

**Prompt 1-3: Quick Analysis with Visualization**
```
Show me the weekly sales trend for the top 5 products by total revenue from SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_RAW.DAILY_SALES. Visualize it as a line chart.
```

---

### --- 2. ML Model Building (Snowflake ML Forecasting) ---

**Prompt 2-1: Prepare Forecast Input**
```
I need to build a demand forecast model. Using SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_RAW.DAILY_SALES, create a weekly aggregation view in the RETAIL_DEMAND_FORECAST_ANALYTICS schema that groups by store and product. Include a SERIES_ID column (concatenation of STORE_ID and PRODUCT_ID) and a TOTAL_UNITS target column.
```

**Prompt 2-2: Build Forecast Model**
```
Using Snowflake ML Forecasting, build a multi-series demand forecast model called DEMAND_FORECAST_MODEL in SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_ANALYTICS. Use the WEEKLY_DEMAND_WITH_SERIES view as input, with SERIES_ID as the series column, WEEK_START as the timestamp, and TOTAL_UNITS as the target. Skip errors for any series that fail.
```

**Prompt 2-3: Generate & Store Predictions**
```
Call the DEMAND_FORECAST_MODEL to generate an 8-week forecast with 95% prediction intervals. Store the results in SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_ML.DEMAND_FORECAST with columns: SERIES_ID, STORE_ID, PRODUCT_ID, FORECAST_WEEK, FORECASTED_UNITS, FORECAST_LOWER_95, FORECAST_UPPER_95.
```

**Prompt 2-4: Evaluate Model**
```
Show me the evaluation metrics for DEMAND_FORECAST_MODEL. Which product-store combinations have the best and worst accuracy? Visualize the forecast vs. actuals for the top 3 highest-volume series.
```

---

### --- 3. Inventory Optimization Logic ---

**Prompt 3-1: Build Replenishment Alerts**
```
Create a replenishment alert system that:
1. Joins INVENTORY_SNAPSHOT with the ML forecast
2. Calculates days of stock remaining based on forecasted demand
3. Assigns alert levels: STOCKOUT, CRITICAL (stock below reorder point AND <3 days supply), REORDER_NOW, LOW_STOCK (<7 days supply), EXPIRING_SOON (≤3 days to expiry)
4. Suggests order quantities based on the 95th percentile forecast

Create this as a view called REPLENISHMENT_ALERTS in the RETAIL_DEMAND_FORECAST_ANALYTICS schema.
```

**Prompt 3-2: Alert Dashboard Query**
```
Which stores have the most critical inventory issues right now? Show me a summary of alerts by store with the total units that need to be ordered. Visualize it as a bar chart.
```

**Prompt 3-3: Automate Daily Checks**
```
Create a Snowflake Task that runs daily at 6 AM ET to refresh the replenishment alerts and store the results in a table called DAILY_ALERTS. Use COMPUTE_WH warehouse.
```

---

### --- 4. End-to-End Orchestration ---

**Prompt 4-1: Full Pipeline Demo**
```
Walk me through the complete retail demand forecasting pipeline:
1. Show me the data we have in SF_SOLUTIONS
2. Build the weekly demand aggregation
3. Train a forecast model using Snowflake ML
4. Generate predictions for the next 8 weeks
5. Create inventory alerts based on the predictions
6. Summarize which stores need immediate attention

Execute each step and show me the results along the way.
```
