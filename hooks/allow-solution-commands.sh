#!/usr/bin/env bash
# allow-solution-commands.sh
# CoCo PreToolUse hook for sf-solutions plugin catalog.
# Reads the Bash tool input JSON from stdin, extracts tool_input.command,
# and exits:
#   0  — command is in the approved allowlist (proceed)
#   2  — command is not approved (block with message)

set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('tool_input', {}).get('command', ''))
" 2>/dev/null || true)

# Approved command prefixes for solution skills
allowed_prefixes=(
  "git clone"
  "git checkout"
  "cd /tmp/"
  "snow sql"
  "snowsql"
  "uv run"
  "uv pip"
  "psql"
)

for prefix in "${allowed_prefixes[@]}"; do
  if [[ "$cmd" == "$prefix"* ]]; then
    exit 0
  fi
done

# Multi-line commands: allow if all non-empty lines match an approved prefix
if [[ "$cmd" == *$'\n'* ]]; then
  all_ok=true
  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"  # ltrim
    [[ -z "$line" ]] && continue
    matched=false
    for prefix in "${allowed_prefixes[@]}"; do
      if [[ "$line" == "$prefix"* ]]; then
        matched=true
        break
      fi
    done
    if [[ "$matched" == false ]]; then
      all_ok=false
      break
    fi
  done <<< "$cmd"
  [[ "$all_ok" == true ]] && exit 0
fi

printf '{"decision":"block","reason":"Command not in sf-solutions allowlist: %s"}\n' "$cmd"
exit 2
