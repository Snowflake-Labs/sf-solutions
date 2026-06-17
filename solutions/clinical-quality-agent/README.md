# Clinical Quality and Patient Safety Agent

**AI-powered clinical quality analytics for Chief Quality Officers using Snowflake Cortex Agent**

## Overview

Enables hospital Chief Quality Officers to analyze patient outcomes, healthcare-associated infections (HAIs), mortality trends, and patient safety events using natural language queries via Snowflake Intelligence.

## Key Capabilities

| Tool | Purpose |
|------|---------|
| **Cortex Analyst** | Text-to-SQL across 8 clinical quality tables (75K patients) |
| **PubMed Search** | Evidence-based literature from 38M+ biomedical articles |
| **Email** | Automated quality report distribution |

## Clinical Quality Metrics

- Mortality analysis with national benchmark comparison (20% worse for demo)
- Healthcare-Associated Infections (CAUTI, CLABSI, VAP, SSI, C.diff)
- Patient safety events (pressure injuries, falls, medication errors)
- 30/90-day readmission tracking
- Preventable deaths identification (~35-50%)
- Quarterly trend analysis (worsening quality trends for demo impact)

## Data Model

| Table | Description |
|-------|-------------|
| `PATIENTS` | 75K patient demographics (65% elderly) |
| `ADMISSIONS` | Hospital encounters with mortality risk scores |
| `DIAGNOSES` | ICD-10 codes with age-appropriate patterns |
| `PROCEDURES` | CPT codes with device associations |
| `INFECTIONS` | HAIs linked to devices and mortality |
| `QUALITY_EVENTS` | Patient safety events with preventability |
| `OUTCOMES` | Deaths, discharges, preventability flags |
| `RISK_FACTORS` | Comorbidities affecting outcomes |

## Prerequisites

1. Snowflake account with Cortex Agent access
2. Optional: Email notification integration for report sending

## Pre-Installation: PubMed Marketplace Dataset (Strongly Recommended)

> **This step must be done BEFORE running setup.sql.**
> The Cortex Agent's medical literature search requires the PubMed dataset.
> Without it, the Agent still works for data analytics (Cortex Analyst) but
> cannot search biomedical research literature.

**Install PubMed (free, ~30 seconds):**

1. Open: <https://app.snowflake.com/marketplace/listing/GZTYZ4386LY/cybersyn-pubmed-biomedical-research-corpus>
2. Click **Get**
3. Accept terms and install with default database name `PUBMED_BIOMEDICAL_RESEARCH_CORPUS`

Or manually: Snowsight > **Data Products** > **Marketplace** > Search "PubMed Biomedical Research Corpus" > **Get**

Verify installation:
```sql
SHOW CORTEX SEARCH SERVICES IN SCHEMA PUBMED_BIOMEDICAL_RESEARCH_CORPUS.OA_COMM;
-- Should show: PUBMED_OA_CKE_SEARCH_SERVICE
```

## Installation

Execute `scripts/setup.sql` in Snowsight using ACCOUNTADMIN role.

This creates:
- Schema `SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY` with 8 tables
- 75K patients with realistic clinical data (configurable)
- Semantic model for Cortex Analyst
- `clinical_quality_safety_agent` Cortex Agent

## Usage

1. Navigate to **AI & ML > Agents** in Snowsight
2. Open `clinical_quality_safety_agent`
3. Ask questions in natural language

### Example Questions

- "How many patients died in the last year?"
- "Show me catheter infections that resulted in death"
- "What is our quarterly mortality trend?"
- "What percentage of deaths were preventable?"
- "Find PubMed articles on preventing CAUTI infections"
- "Compare our sepsis mortality to national benchmarks"

## Demo Storyline

1. **Discovery**: "Show me our mortality rate" (reveals elevated rates)
2. **Trends**: "How has this changed over time?" (worsening quarter-over-quarter)
3. **Root Cause**: "Show me sepsis mortality details" (identifies problem areas)
4. **Actionable**: "What percentage of deaths were preventable?" (35-50%)
5. **Evidence**: "Search PubMed for CAUTI prevention" (research support)
6. **Action**: "Email findings to the quality team" (automated reporting)

## Configuration

Edit parameters in setup.sql before running to adjust system size:

```sql
SET num_patients = 75000;
SET mortality_multiplier = 1.20;    -- 20% above national avg
SET hai_multiplier = 1.25;          -- 25% above national avg
SET trend_degradation = 0.06;       -- 6% quarterly worsening
```

## Teardown

Execute `scripts/teardown.sql` to remove all solution objects.

## License

MIT
