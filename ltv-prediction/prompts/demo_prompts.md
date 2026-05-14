# Demo Prompts — Customer Lifetime Value Prediction

### --- 1. Data Exploration ---

**Prompt 1-1: Profile Transaction Data**
```
Profile the ML_LTV_TRANSACTIONS table in SF_SOLUTIONS.LTV_RAW. Show the date range, number of customers, total transactions, and breakdown by product category and channel.
```

**Prompt 1-2: Customer Behavior**
```
Analyze transaction patterns in SF_SOLUTIONS.LTV_RAW.ML_LTV_TRANSACTIONS. Show the monthly transaction volume trend and top 10 customers by total spend. Visualize the monthly trend as a line chart.
```

---

### --- 2. Feature Engineering ---

**Prompt 2-1: Explore Features**
```
Profile the CUSTOMER_FEATURES table in SF_SOLUTIONS.LTV_ANALYTICS. Show the distribution of key features like total_spend, txn_count, and recency_days. Which features correlate most with FUTURE_LTV?
```

---

### --- 3. Model Evaluation ---

**Prompt 3-1: Model Metrics**
```
Show the evaluation metrics for LTV_REGRESSION_MODEL in SF_SOLUTIONS.LTV_ANALYTICS. What are the R², MAE, and RMSE? Also show feature importance — which features matter most?
```

**Prompt 3-2: Prediction Accuracy**
```
Compare predicted vs actual LTV from SF_SOLUTIONS.LTV_ML.LTV_PREDICTIONS. Show the average absolute error by LTV range bucket. Visualize predicted vs actual as a scatter plot.
```

---

### --- 4. Customer Segments ---

**Prompt 4-1: Segment Summary**
```
Show the customer segments from SF_SOLUTIONS.LTV_ANALYTICS.CUSTOMER_SEGMENTS. For each segment (Platinum/Gold/Silver/Bronze), show customer count, average predicted LTV, average historical spend, and average transaction frequency. Visualize as a bar chart.
```

**Prompt 4-2: Platinum Deep Dive**
```
Who are the Platinum customers? Show the top 20 by predicted LTV with their key metrics. What behaviors differentiate them from Bronze customers?
```

---

### --- 5. End-to-End ---

**Prompt 5-1: Full Pipeline Review**
```
Walk me through the LTV prediction pipeline in SF_SOLUTIONS:
1. Show the raw transaction data summary
2. Explain the customer features that were engineered
3. Show model evaluation metrics and feature importance
4. Analyze prediction accuracy
5. Summarize the customer segments and their business implications
```
