#!/usr/bin/env bash
# PreToolUse(Write|Edit) hook: block writing files that contain credentials,
# PII patterns, or Snowflake internal URLs.
#
# Reads hook payload from stdin (JSON).
# Exit 2 to block; exit 0 to allow. Fail-open if jq is missing.
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)

# Extract content being written (Write tool uses "content"; Edit uses "new_string")
content=$(printf '%s' "$payload" | jq -r '.tool_input.content // .tool_input.new_string // ""')
[[ -z "$content" ]] && exit 0

# Write content to a temp file for grep (avoids passing dashes as grep options)
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT
printf '%s' "$content" > "$tmpfile"

# --- Check 1: Private key blocks ---
# Use -F (fixed string) for the leading dashes to avoid BSD grep option parsing issues
if grep -qF -- '-----BEGIN' "$tmpfile"; then
    jq -n '{
        decision: "block",
        systemMessage: "Blocked: private key or certificate content detected. Remove all -----BEGIN ...----- blocks before writing to a committed file."
    }'
    exit 2
fi

# --- Check 2: Snowflake account locator URLs ---
# Pattern: <2-letter prefix><5-6 digits>.<region>.snowflakecomputing.com
if grep -qiE '[a-z]{2}[0-9]{5,6}\.(us|eu|ap|ca|sa|me|af)-[a-z]+-[0-9]+\.snowflakecomputing\.com' "$tmpfile"; then
    jq -n '{
        decision: "block",
        systemMessage: "Blocked: Snowflake account locator URL detected. Replace with a generic placeholder (e.g., <your-account-locator>.snowflakecomputing.com). This is a public repository."
    }'
    exit 2
fi

# --- Check 3: Hardcoded passwords ---
# Matches: password = "secret" or password: 'secret'
if grep -qiE 'password[[:space:]]*[=:][[:space:]]*[^[:space:]<][^[:space:]]{3,}' "$tmpfile"; then
    # Exclude obvious placeholders: <...>, ${...}, $(...), CHANGEME, etc.
    if ! grep -iE 'password[[:space:]]*[=:][[:space:]]*(<|[$]{|CHANGE|YOUR_|PLACEHOLDER|example)' "$tmpfile" > /dev/null 2>&1; then
        jq -n '{
            decision: "block",
            systemMessage: "Blocked: potential hardcoded password detected. Use an environment variable or generic placeholder instead."
        }'
        exit 2
    fi
fi

# --- Check 4: Snowflake internal hostnames ---
if grep -qiE '(sfcdev|\.int\.snowflakecomputing\.com|snowflake-internal)' "$tmpfile"; then
    jq -n '{
        decision: "block",
        systemMessage: "Blocked: Snowflake internal hostname detected. This is a public repository — remove all internal infrastructure references."
    }'
    exit 2
fi

# --- Check 5: Bearer tokens / API keys ---
if grep -qE 'Bearer[[:space:]]+[A-Za-z0-9_./-]{20,}' "$tmpfile"; then
    jq -n '{
        decision: "block",
        systemMessage: "Blocked: Bearer token detected. Never commit authentication tokens. Use environment variables or Snowflake secrets."
    }'
    exit 2
fi

exit 0
