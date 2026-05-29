# snowflake-solutions — Claude Code Plugin

Install pre-built Snowflake industry solutions into your account with one command.

## Prerequisites

1. **Claude Code CLI** installed
2. **snowflake-cortex-code plugin** installed (provides Snowflake SQL execution):
   ```
   /plugin install @claude-official snowflake-cortex-code
   ```
3. Snowflake account with ACCOUNTADMIN access

## Installation

### From local (development)

```bash
claude --plugin-dir ./sf-solutions-installer
```

### From GitHub

```
/plugin install https://github.com/Snowflake-Labs/sf-solutions
```

## Usage

```
/snowflake-solutions:list                              # Show available solutions
/snowflake-solutions:install <slug>                    # Install a solution
/snowflake-solutions:teardown <slug>                   # Remove a solution
```

### Examples

```
/snowflake-solutions:install clinical-quality-agent
/snowflake-solutions:install gnn-supply-chain-risk
/snowflake-solutions:install supply-chain-intelligence
/snowflake-solutions:teardown clinical-quality-agent
```

## Available Solutions

| Slug | Name | Industry |
|------|------|----------|
| `ltv-prediction` | Customer Lifetime Value Prediction | Retail / CPG |
| `manufacturing-predictive-maintenance` | Manufacturing Predictive Maintenance | Manufacturing |
| `supply-chain-intelligence` | Supply Chain Intelligence Platform | Manufacturing |
| `gnn-supply-chain-risk` | GNN Supply Chain Risk Intelligence | Manufacturing |
| `clinical-quality-agent` | Clinical Quality and Patient Safety Agent | Healthcare |

## How It Works

1. Reads the solution's `manifest.json` for metadata
2. Shows marketplace prerequisites (if any) with install URLs
3. Presents an installation plan and waits for confirmation
4. Executes `scripts/setup.sql` via the `snowflake-cortex-code` plugin
5. Verifies all objects were created
6. Shows a summary with next steps

## License

MIT
