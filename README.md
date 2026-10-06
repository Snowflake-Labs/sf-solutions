# Snowflake Industry Solutions

Disclaimer: This application is not part of the Snowflake Service and is governed by the terms in LICENSE, unless expressly agreed to in writing. You use this application at your own risk, and Snowflake has no obligation to support your use of this application. [Learn more](./LEGAL.md)

---

End-to-end solution accelerators built on Snowflake, Cortex Code, showcasing Cortex AI, Snowflake ML, and the modern data platform.

---

## Solution Catalog

### [sf-hcls-solutions](https://github.com/Snowflake-Labs/sf-hcls-solutions) — Healthcare & Life Sciences

| # | Solution | Description | Key Snowflake Features |
|---|----------|-------------|----------------------|
| 1 | [Clinical Quality Agent](https://github.com/Snowflake-Labs/sf-hcls-solutions/tree/main/solutions/clinical-quality-agent) | AI-powered Cortex Agent for Chief Quality Officers to analyze patient outcomes, infections, mortality rates, and safety indicators using natural language | Cortex Agent, Cortex Analyst, Cortex Search, Notifications |
| 2 | [Medical Device Streaming](https://github.com/Snowflake-Labs/sf-hcls-solutions/tree/main/solutions/medical-device-streaming) | Real-time medical device data streaming platform for ECG, EDA, and PPG biosignal data with live analytics | Snowpipe Streaming, ASOF Joins, Dynamic Tables |

### [sf-mleu-solutions](https://github.com/Snowflake-Labs/sf-mleu-solutions) — Manufacturing, Logistics, Energy & Utilities

| # | Solution | Description | Key Snowflake Features |
|---|----------|-------------|----------------------|
| 1 | [GNN Supply Chain Risk](https://github.com/Snowflake-Labs/sf-mleu-solutions/tree/main/solutions/gnn-supply-chain-risk) | AI-driven N-tier supply chain resilience using Graph Neural Networks. Identifies hidden Tier-2+ supplier dependencies and concentration risks | PyTorch Geometric, GPU Compute (SPCS), Cortex Agent, Semantic Model |
| 2 | [Predictive Maintenance](https://github.com/Snowflake-Labs/sf-mleu-solutions/tree/main/solutions/predictive-maintenance) | Predictive maintenance solution for industrial equipment using Snowflake ML | Snowflake ML, Cortex AI Functions |
| 3 | [Supply Chain Intelligence](https://github.com/Snowflake-Labs/sf-mleu-solutions/tree/main/solutions/supply-chain-intelligence) | Agentic AI platform for supply chain management with multi-agent orchestration | Cortex Agent, Cortex Analyst, Cortex Search, Streamlit |

### [sf-marketing-solutions](https://github.com/Snowflake-Labs/sf-marketing-solutions) — Advertising, AdTech & MarTech

| # | Solution | Description | Key Snowflake Features |
|---|----------|-------------|----------------------|
| 1 | [OpenRTB Analyst Agent](https://github.com/Snowflake-Labs/sf-marketing-solutions/tree/main/solutions/openrtb-analyst-agent) | Programmatic advertising analytics with OpenRTB bid request data and natural language queries | Cortex Agent, Semantic View, Dynamic Tables |
| 2 | [SSP Impression Analytics](https://github.com/Snowflake-Labs/sf-marketing-solutions/tree/main/solutions/ssp-impression-analytics) | SSP impression analytics with Cortex Agent and Semantic View | Cortex Agent, Semantic View |

### [sf-rcg-solutions](https://github.com/Snowflake-Labs/sf-rcg-solutions) — Retail, CPG & General

| # | Solution | Description | Key Snowflake Features |
|---|----------|-------------|----------------------|
| 1 | [Customer Lifetime Value Prediction](https://github.com/Snowflake-Labs/sf-rcg-solutions/tree/main/solutions/ltv-prediction) | Predict customer lifetime value using Snowflake ML regression models | Snowflake ML Regression, Cortex AI Functions |

---

## Requirements for sf-solutions plugin

| Requirement | Details |
|-------------|---------|
| CoCo | [Snowflake CoCo CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) or [Snowflake CoCo Desktop](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop) |
| Snowflake account | A non-trial account, or a trial account with AI features enabled |
| Edition | Enterprise Edition recommended. Check each solution's README for its required edition |

> AI features (CoCo, Cortex Agents, Cortex AI Functions) are disabled by default on self-service trial accounts. To enable them, add a credit card to the account.

## How to Install

There are two ways to install a solution. Option 1 is recommended.

### Option 1: Use the sf-solutions plugin (recommended)

Install the `sf-solutions` plugin into CoCo, then install any solution by name.

#### Snowflake CoCo Desktop (GUI)

1. Open **Settings** and select **Plugins** in the left menu.
2. Click the **+** button at the top right, then select **Add from GitHub**.
3. In the **Add plugin from GitHub** dialog, enter the following URL and press **Enter**:

   ```
   https://github.com/Snowflake-Labs/sf-solutions/tree/main/plugins/cortex-code
   ```

4. CoCo clones the repository and registers the plugin. Confirm that the **sf-solutions** card appears in the Plugins list with its toggle turned on.

#### Snowflake CoCo CLI

```bash
cortex plugin install github:Snowflake-Labs/sf-solutions/plugins/cortex-code
cortex plugin list   # confirm "sf-solutions" is listed as [enabled, managed]
```

If a CoCo session is already running, run `/plugin reload` (or restart CoCo) to load the plugin. To get the latest version later, run `cortex plugin update sf-solutions`.

> CoCo may also list an older bundled `sf-solutions` plugin as `[disabled, bundled]`. The plugin installed above takes precedence.

Then, in CoCo:

```
$sf-solutions:list                          # List all available solutions
$sf-solutions:list <industry>               # Filter by industry (e.g. hcls, rcg)
$sf-solutions:install <solution-name>       # Install a solution
$sf-solutions:teardown <solution-name>      # Remove a solution
$sf-solutions:next <solution-name>          # Post-install guidance
```

The plugin shows the disclaimer and the installation plan (target account, objects, scripts, and source commit), and waits for your confirmation before making any change.

### Option 2: Install manually from the solution folder

Each solution is self-contained. Clone the industry repo that contains the solution (see the catalog above), go to the solution's folder, and follow the installation steps in that solution's `README.md`.

```bash
git clone https://github.com/Snowflake-Labs/sf-<industry>-solutions.git
cd sf-<industry>-solutions/solutions/<solution-name>
```

Read the disclaimer and the Prerequisites in the solution's `README.md` before running anything.

---

## Related Resources

### Web Pages

- [Snowflake ML](https://www.snowflake.com/en/data-cloud/snowflake-ml/) - Integrated set of capabilities for development, MLOps and inference leading with agentic ML
- [Snowflake Notebooks](https://www.snowflake.com/en/data-cloud/notebooks/) - Jupyter-based notebooks in Snowflake Workspaces
- [CoCo](https://www.snowflake.com/en/data-cloud/cortex/cortex-code/) - Snowflake's AI native coding agent that boosts ML productivity

### Technical Documentation

- [CoCo Documentation](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code) - Getting started with Cortex Code
- [CoCo Desktop](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop)
- [CoC CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) - Command-line experience
- [Snowflake ML Documentation](https://docs.snowflake.com/en/developer-guide/snowflake-ml/overview) - Official Snowflake ML developer guide
- [Snowflake ML Quickstart](https://quickstarts.snowflake.com/guide/getting-started-with-snowflake-ml/) - Hands-on guides to get started with Snowflake ML
