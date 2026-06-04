---
description: >
  Manage the Clinical Quality and Patient Safety Agent solution.
  Usage: /snowflake-solutions:clinical-quality-agent install
         /snowflake-solutions:clinical-quality-agent teardown
  Triggers: clinical quality, patient safety, healthcare agent, CQO demo.
---

# Clinical Quality and Patient Safety Agent

Parse the action from `$ARGUMENTS`:
- If `$ARGUMENTS` is "install" or empty → run **Install** flow
- If `$ARGUMENTS` is "teardown" → run **Teardown** flow
- Otherwise → show usage help

## Overview

- **Industry:** Healthcare
- **Database:** SF_SOLUTIONS
- **Schema:** CLINICAL_QUALITY_SAFETY
- **Features:** Cortex Agent, Cortex Analyst, Cortex Search (PubMed), Snowflake Intelligence
- **Role Required:** ACCOUNTADMIN

## Pre-Installation

Before proceeding, the user should install PubMed from the Snowflake Marketplace (free, strongly recommended):

**URL:** https://app.snowflake.com/marketplace/listing/GZTYZ4386LY/cybersyn-pubmed-biomedical-research-corpus

Ask the user: "Have you installed the PubMed Biomedical Research Corpus from the Marketplace? (The agent will still work without it, but PubMed search will be unavailable.)"

## Installation Steps

1. Locate the sf-solutions repository:
   - Check `~/project/sf-solutions/`
   - Check current working directory
   - If not found: `git clone https://github.com/Snowflake-Labs/sf-solutions.git /tmp/sf-solutions`

2. Present the installation plan:
   ```
   Solution: Clinical Quality and Patient Safety Agent v1.0.0
   Industry: Healthcare & Life Sciences
   Database: SF_SOLUTIONS
   Schema:   CLINICAL_QUALITY_SAFETY
   Role:     ACCOUNTADMIN

   What will be created:
     - 8 clinical quality tables (75K patients generated)
     - Cortex Agent (clinical_quality_safety_agent)
     - Semantic model for Cortex Analyst
     - Email connector function

   Marketplace prerequisite (strongly recommended):
     - PubMed Biomedical Research Corpus (free)
       https://app.snowflake.com/marketplace/listing/GZTYZ4386LY

   Proceed with installation?
   ```

3. Wait for user confirmation.

4. Execute `clinical-quality-agent/scripts/setup.sql` against Snowflake.
   - The script is self-contained (~3400 lines)
   - Includes DDL, data generation, semantic model upload, and agent creation
   - Expected runtime: 2-5 minutes (data generation for 75K patients)

5. Verify installation:
   ```sql
   SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
   FROM SF_SOLUTIONS.INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA = 'CLINICAL_QUALITY_SAFETY'
   ORDER BY TABLE_NAME;
   ```

6. Show summary:
   ```
   Installed: Clinical Quality and Patient Safety Agent v1.0.0

   Tables created (8):
     PATIENTS, ADMISSIONS, DIAGNOSES, PROCEDURES,
     INFECTIONS, QUALITY_EVENTS, OUTCOMES, RISK_FACTORS

   Agent: clinical_quality_safety_agent
     → Open in Snowflake Intelligence: AI & ML > Agents

   Try asking:
     - "How many patients died in the last year?"
     - "Show me our quarterly mortality trend"
     - "Find PubMed articles on preventing CAUTI infections"

   Teardown: /snowflake-solutions:teardown clinical-quality-agent
   ```

## Teardown

If `$ARGUMENTS` is "teardown":

1. Confirm with user: "This will drop SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY and all its objects. Proceed?"
2. Execute:
   ```sql
   DROP AGENT IF EXISTS SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.CLINICAL_QUALITY_SAFETY_AGENT;
   DROP SCHEMA IF EXISTS SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY CASCADE;
   ```
3. Confirm: "Clinical Quality and Patient Safety Agent removed."

## Usage Help

If `$ARGUMENTS` is not recognized, show:
```
Usage:
  /snowflake-solutions:clinical-quality-agent install    — Install the solution
  /snowflake-solutions:clinical-quality-agent teardown   — Remove the solution
```
