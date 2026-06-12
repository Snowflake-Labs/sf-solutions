---
description: >
  Manage the Clinical Quality and Patient Safety Agent solution.
  Usage: /snowflake-solutions:clinical-quality-agent install
         /snowflake-solutions:clinical-quality-agent teardown
         /snowflake-solutions:clinical-quality-agent (defaults to install)
  AI-powered clinical quality analytics for Chief Quality Officers.
  Triggers: clinical, quality, patient safety, healthcare, HAI, mortality, cortex agent.
---

# Clinical Quality and Patient Safety Agent

Parse the action from `$ARGUMENTS`:
- If `$ARGUMENTS` is "install" or empty → run **Install** flow
- If `$ARGUMENTS` is "teardown" → run **Teardown** flow
- Otherwise → show usage help

## Overview

- **Industry:** Healthcare & Life Sciences
- **Database:** SF_SOLUTIONS
- **Schema:** CLINICAL_QUALITY_SAFETY
- **Features:** Cortex Agent, Cortex Analyst, Cortex Search (PubMed), Semantic Model, Snowflake Intelligence
- **Role Required:** ACCOUNTADMIN
- **Optional Marketplace Dataset:** PubMed Biomedical Research Corpus (free, strongly recommended)

## Install

1. Clone or locate the sf-solutions repository:
   ```bash
   git clone https://github.com/Snowflake-Labs/sf-solutions.git /tmp/sf-solutions
   ```
   Or check `~/project/sf-solutions/`, current directory.

2. Read `solutions/clinical-quality-agent/manifest.json` from the repository.

3. Present the installation plan:
   ```
   Solution: Clinical Quality and Patient Safety Agent v1.0.0
   Industry: Healthcare & Life Sciences
   Database: SF_SOLUTIONS
   Schema:   CLINICAL_QUALITY_SAFETY
   Role:     ACCOUNTADMIN

   What will be created:
     - 8 clinical quality tables (75K patients with realistic data)
     - Semantic model for Cortex Analyst (text-to-SQL)
     - Cortex Agent with Analyst + PubMed Search + Email tools
     - Accessible via Snowflake Intelligence UI

   Optional prerequisite:
     - PubMed Biomedical Research Corpus (free Marketplace dataset)
     - Enables medical literature search (38M+ articles)
     - Without it, the Agent still works for analytics but cannot search research literature

   Proceed with installation?
   ```

4. Wait for user confirmation.

5. Check if PubMed dataset is installed:
   ```sql
   SHOW CORTEX SEARCH SERVICES IN SCHEMA PUBMED_BIOMEDICAL_RESEARCH_CORPUS.OA_COMM;
   ```
   - If available: inform user that PubMed search will be enabled
   - If not available: inform user the Agent will work without literature search, and suggest installing PubMed from Marketplace:
     `https://app.snowflake.com/marketplace/listing/GZTYZ4386LY/cybersyn-pubmed-biomedical-research-corpus`

6. Read `solutions/clinical-quality-agent/scripts/setup.sql` from the repository and execute it against Snowflake statement by statement.
   - Data generation may take 2-5 minutes (use timeout_seconds: 600)
   - Log progress after each major section

7. Verify installation:
   ```sql
   SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
   FROM SF_SOLUTIONS.INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA = 'CLINICAL_QUALITY_SAFETY'
   ORDER BY TABLE_NAME;
   ```

8. **[MANDATORY — DO NOT SKIP]** Show the Snowflake Intelligence Agent URL.
   Execute this query:
   ```sql
   SELECT 'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
       || '/#/cortex-agents/SF_SOLUTIONS.CLINICAL_QUALITY_SAFETY.CLINICAL_QUALITY_SAFETY_AGENT' AS AGENT_URL;
   ```
   Display it to the user:
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Cortex Agent:
   <paste the full URL here>
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

   This step is NON-OPTIONAL. The user must always see the Agent URL after install.

9. Show final summary:
   ```
   Installation complete: Clinical Quality and Patient Safety Agent v1.0.0

   Next Actions:
   1. Open the Cortex Agent URL above in Snowflake Intelligence
   2. Try: "How many patients died in the last year?"
   3. Try: "Show me catheter infections that resulted in death"
   4. Try: "Search PubMed for CAUTI prevention" (requires PubMed dataset)

   Teardown: /snowflake-solutions:clinical-quality-agent teardown
   ```

## Teardown

If `$ARGUMENTS` is "teardown":

1. Confirm with user: "This will drop the CLINICAL_QUALITY_SAFETY schema and the Cortex Agent. Proceed?"
2. Read and execute `solutions/clinical-quality-agent/scripts/teardown.sql` from the repository.
3. Confirm: "Clinical Quality and Patient Safety Agent removed."

## Next Actions

If the user asks "what next?", "what can I do?", or "how to customize":

Read and present the content from `NEXT_ACTIONS.md` (located in this skill's directory).
Present the relevant section based on user intent:
- Just exploring → Quick Exploration section
- Wants to use own data → Customize with Your Data section
- Wants to add tools → Extend the Agent section
- Ready for production → Production Deployment section

## Usage Help

```
Usage:
  /snowflake-solutions:clinical-quality-agent install    — Install the solution
  /snowflake-solutions:clinical-quality-agent teardown   — Remove the solution
```
