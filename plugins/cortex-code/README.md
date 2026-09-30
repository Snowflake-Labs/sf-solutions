# sf-solutions

Disclaimer: This application is not part of the Snowflake Service and is governed by the terms in LICENSE, unless expressly agreed to in writing. You use this application at your own risk, and Snowflake has no obligation to support your use of this application. [Learn more](../../LEGAL.md)

A Cortex Code plugin for discovering, installing, and managing Snowflake industry solution accelerators across multiple verticals.

## What It Does

- Lists available solutions from the [sf-solutions catalog](https://github.com/Snowflake-Labs/sf-solutions)
- Installs solutions into your Snowflake account (SQL scripts, Streamlit apps, Cortex Agents, Semantic Views)
- Supports both **script type** (SQL-based) and **plugin type** (CoCo plugin) solutions
- Provides teardown to cleanly remove installed solutions

## Usage

```
$sf-solutions:list                          # List all available solutions
$sf-solutions:list <industry>               # Filter by industry (e.g., healthcare, retail)
$sf-solutions:install <solution-name>       # Install a solution
$sf-solutions:teardown <solution-name>      # Remove a solution
$sf-solutions:next <solution-name>          # Post-install guidance
```

## Security

- A disclaimer is displayed before every installation
- Explicit user confirmation is required before any changes are made
- Plugin-type solutions undergo a grandchild plugin check (no recursive installs)
- All solutions run within the `SF_SOLUTIONS` database scope

## Supported Industries

| Industry | Repo |
|----------|------|
| Healthcare & Life Sciences | sf-hcls-solutions |
| Financial Services | sf-fsi-solutions |
| Manufacturing, Logistics, Energy & Utilities | sf-mleu-solutions |
| Retail, CPG & General | sf-rcg-solutions |
| Advertising, AdTech & MarTech | sf-marketing-solutions |
| Telecommunications | sf-telco-solutions |
| Media & Entertainment | sf-media-entertainment-solutions |
| Travel & Hospitality | sf-tnh-solutions |
| Public Sector & Government | sf-pubsec-solutions |
