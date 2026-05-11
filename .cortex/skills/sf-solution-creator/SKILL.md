---
name: sf-solution-creator
description: "Create new Snowflake industry solution accelerators in the sf-solutions repo. Use when: creating a new solution, adding a solution, scaffolding an accelerator, building industry demo. Triggers: new solution, create solution, add solution, scaffold accelerator, industry solution."
---

# SF Solution Creator

## When to Use

When the user wants to create a new solution accelerator in the `sf-solutions` repository. Each solution is a self-contained directory with synthetic data, ML/analytics logic, optional dbt pipeline, and demo prompts (EN + JP).

## Prerequisites

- Working directory is the sf-solutions repo root
- User has specified or will specify: solution name, industry, and use case

## Workflow

### Step 1: Gather Requirements

**Goal:** Understand what solution to build

**Actions:**

1. **Ask** the user for:
   ```
   - Solution name (e.g., "Predictive Maintenance")
   - Industry (e.g., Manufacturing, Finance, Retail)
   - Use case description (1-2 sentences)
   - Key Snowflake features to showcase (e.g., Snowflake ML, Cortex Search, Dynamic Tables)
   ```

2. **Derive** directory name from solution name (lowercase, hyphenated):
   - Example: "Media Mix Modeling" → `media-mix-modeling/`

3. **Check** the root `README.md` solution catalog to avoid duplicates

**Output:** Solution spec (name, industry, directory, features)

### Step 2: Create Directory Structure

**Goal:** Scaffold the solution directory

**Actions:**

1. **Create** directory tree:
   ```
   <solution-name>/
   ├── data/
   ├── models/
   ├── dbt_project/
   │   └── models/
   │       ├── staging/
   │       └── marts/
   └── prompts/
   ```

2. **If** user does not need dbt, skip `dbt_project/`

**Output:** Empty directory structure

### Step 3: Create Synthetic Data

**Goal:** Generate realistic sample data for the solution

**Actions:**

1. **Create** `data/01_create_sample_data.sql` with:
   - Database and schema creation (pattern: `<SOLUTION_NAME>_DB`)
   - Dimension tables with realistic reference data
   - Fact/transaction tables with 1-2 years of synthetic history
   - Built-in patterns: seasonality, trends, noise, realistic volumes
   - Verification query at the end

2. **Design** data to support the ML/analytics use case

**Guidelines:**
- Use `GENERATOR()` + `DATEADD()` for date spines
- Include 5-12 dimension entries for reasonable demo scale
- Target 50K-100K rows in main fact table
- Add realistic noise (±15%), seasonality, and growth trends

**Output:** SQL script that creates all sample data

### Step 4: Create ML/Analytics Logic

**Goal:** Build the core analytical models

**Actions:**

1. **Create** `models/02_<main_logic>.sql` with the primary ML or analytics workflow
2. **Create** `models/03_<secondary_logic>.sql` if needed (alerts, scoring, etc.)

**Common patterns:**
- Snowflake ML Forecasting: `CREATE SNOWFLAKE.ML.FORECAST`
- Anomaly Detection: `CREATE SNOWFLAKE.ML.ANOMALY_DETECTION`
- Classification: `CREATE SNOWFLAKE.ML.CLASSIFICATION`
- Cortex AI Functions: `AI_COMPLETE()`, `AI_EXTRACT()`, `AI_CLASSIFY()`
- Cortex Search: `CREATE CORTEX SEARCH SERVICE`

**Output:** SQL scripts for model training and inference

### Step 5: Create dbt Project (Optional)

**Goal:** Wrap the data pipeline in dbt

**Actions:**

1. **Create** `dbt_project/dbt_project.yml`
2. **Create** `dbt_project/profiles.yml.example`
3. **Create** staging models (`stg_*.sql`) from raw sources
4. **Create** mart models (`fct_*.sql`, `mart_*.sql`)
5. **Create** `sources.yml` and `schema.yml` with tests

**Output:** Complete dbt project

### Step 6: Create Demo Prompts

**Goal:** Write prompts showcasing Cloud Agents / Cortex Code capabilities

**Actions:**

1. **Create** `prompts/demo_prompts.md` with sections:
   - **English prompts** (5 categories × 2-3 prompts each):
     1. Data Exploration & Understanding
     2. ML Model Building
     3. Business Logic / Alerts
     4. dbt Pipeline (if applicable)
     5. End-to-End Orchestration
   - **Japanese prompts** (same structure, translated)

2. **Design** prompts to demonstrate:
   - Table discovery and profiling
   - Visualization (charts)
   - SQL generation and execution
   - ML model training
   - Multi-step orchestration

**Output:** Bilingual demo prompts file

### Step 7: Create README

**Goal:** Document the solution

**Actions:**

1. **Create** `<solution>/README.md` with:
   - Solution name + industry table
   - Architecture diagram (ASCII)
   - Quick start steps
   - Data details (tables, row counts, patterns)
   - File structure
   - Prerequisites

**Output:** Solution README

### Step 8: Update Root Catalog

**Goal:** Register the new solution in the root README's Solution Catalog table

**Actions:**

1. **Read** `<repo-root>/README.md`
2. **Add** a new row to the `## Solution Catalog` table with format:
   ```
   | <next#> | **<Solution Name>** | <Industry(s)> | `<directory>/` | <Key Snowflake Features> | ✅ Done |
   ```
3. **If** solution already exists in table (status was `📋 Planned`), update its status to `✅ Done` and fill in the directory name
4. **Verify** the table remains well-formatted (aligned columns, no duplicates)

**Status values:**
- `📋 Planned` — registered but not yet built
- `🚧 In Progress` — partially built
- `✅ Done` — fully built with data + models + prompts

**⚠️ MANDATORY STOPPING POINT**: Present the completed solution summary to user for review.

## Stopping Points

- ✋ After Step 1 (confirm requirements before building)
- ✋ After Step 8 (present final summary)

## Output

A complete solution directory with:
- Synthetic data generation SQL
- ML/Analytics model scripts
- dbt project (optional)
- Demo prompts (EN + JP)
- README documentation
- Updated root catalog

## Conventions

- Database: always `SF_SOLUTIONS` (shared across all solutions, created with `CREATE DATABASE IF NOT EXISTS`)
- Schema naming: `<SOLUTION_PREFIX>_RAW`, `<SOLUTION_PREFIX>_ANALYTICS`, `<SOLUTION_PREFIX>_ML`
  - Example: `RETAIL_DEMAND_FORECAST_RAW`, `RETAIL_DEMAND_FORECAST_ANALYTICS`
- SQL files numbered: `01_`, `02_`, `03_`
- First SQL file must include:
  ```sql
  CREATE DATABASE IF NOT EXISTS SF_SOLUTIONS;
  CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.<SOLUTION_PREFIX>_RAW;
  CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.<SOLUTION_PREFIX>_ANALYTICS;
  CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.<SOLUTION_PREFIX>_ML;
  ```
- All prompts bilingual: `demo_prompts.md` (English), `demo_prompts_JA.md` (Japanese)
- File naming for JA variants: append `_JA` before extension (e.g., `demo_prompts_JA.md`)
- Demo data should be self-contained (no external dependencies)
