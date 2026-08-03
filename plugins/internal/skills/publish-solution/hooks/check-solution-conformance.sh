#!/usr/bin/env bash
# Conformance check: validate that a generated solution directory meets
# sf-*-solutions standards.
#
# Usage: check-solution-conformance.sh <target_dir> <meta_json>
#
# <target_dir>  - path to the generated solution directory
# <meta_json>   - path to .convert-meta.json written during Phase 1
#                 (contains source DB/WH names for generic replacement checks)
#
# Exit 1 if any conformance errors found; exit 0 on PASS.
set -euo pipefail

TARGET="${1:-}"
META="${2:-}"

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 <target_dir> <meta_json>"
    exit 1
fi

ERRORS=0

# ---------------------------------------------------------------------------
# 1. Required files
# ---------------------------------------------------------------------------
REQUIRED_FILES=(
    "manifest.json"
    "README.md"
    "NEXT_ACTIONS.md"
    "scripts/setup.sql"
    "scripts/teardown.sql"
)

for f in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$TARGET/$f" ]]; then
        echo "MISSING: $TARGET/$f"
        ERRORS=$((ERRORS + 1))
    fi
done

# ---------------------------------------------------------------------------
# 2. manifest.json field checks
# ---------------------------------------------------------------------------
MANIFEST="$TARGET/manifest.json"
if [[ -f "$MANIFEST" ]] && command -v jq >/dev/null 2>&1; then

    # database must be SF_SOLUTIONS
    DB=$(jq -r '.database // ""' "$MANIFEST")
    if [[ "$DB" != "SF_SOLUTIONS" ]]; then
        echo "FAIL: manifest.json .database = '$DB', expected 'SF_SOLUTIONS'"
        ERRORS=$((ERRORS + 1))
    fi

    # Required string/array fields must be non-empty
    for field in name display_name version industry description role; do
        VAL=$(jq -r ".$field // empty" "$MANIFEST")
        if [[ -z "$VAL" ]]; then
            echo "FAIL: manifest.json missing required field: $field"
            ERRORS=$((ERRORS + 1))
        fi
    done

    # install_scripts and teardown_scripts must be non-empty arrays
    for field in install_scripts teardown_scripts; do
        COUNT=$(jq -r ".$field | length" "$MANIFEST" 2>/dev/null || echo 0)
        if [[ "$COUNT" -eq 0 ]]; then
            echo "FAIL: manifest.json .$field is empty or missing"
            ERRORS=$((ERRORS + 1))
        fi
    done
fi

# ---------------------------------------------------------------------------
# 3. Source DB/WH names must not remain in generated SQL files
#    Reads source names dynamically from .convert-meta.json (generic check —
#    never hardcodes a specific source name like IROP_DB).
# ---------------------------------------------------------------------------
SETUP_SQL="$TARGET/scripts/setup.sql"

if [[ -f "$META" ]] && command -v jq >/dev/null 2>&1; then

    # Check source database names
    while IFS= read -r src_db; do
        [[ -z "$src_db" ]] && continue
        if [[ -f "$SETUP_SQL" ]] && grep -qi "\b${src_db}\b" "$SETUP_SQL"; then
            echo "FAIL: scripts/setup.sql still references source database '$src_db' — replace with SF_SOLUTIONS"
            ERRORS=$((ERRORS + 1))
        fi
        # Also check teardown.sql
        TEARDOWN_SQL="$TARGET/scripts/teardown.sql"
        if [[ -f "$TEARDOWN_SQL" ]] && grep -qi "\b${src_db}\b" "$TEARDOWN_SQL"; then
            echo "FAIL: scripts/teardown.sql still references source database '$src_db'"
            ERRORS=$((ERRORS + 1))
        fi
    done < <(jq -r '.source_databases[]? // empty' "$META" 2>/dev/null)

    # Check source warehouse names
    while IFS= read -r src_wh; do
        [[ -z "$src_wh" ]] && continue
        if [[ -f "$SETUP_SQL" ]] && grep -qi "\b${src_wh}\b" "$SETUP_SQL"; then
            echo "FAIL: scripts/setup.sql still references source warehouse '$src_wh' — replace with SF_SOLUTIONS_WH"
            ERRORS=$((ERRORS + 1))
        fi
    done < <(jq -r '.source_warehouses[]? // empty' "$META" 2>/dev/null)

else
    # META not available — fall back to checking that SF_SOLUTIONS appears at all
    if [[ -f "$SETUP_SQL" ]] && ! grep -q "SF_SOLUTIONS" "$SETUP_SQL"; then
        echo "WARN: scripts/setup.sql does not reference SF_SOLUTIONS (no .convert-meta.json for source name check)"
    fi
fi

# ---------------------------------------------------------------------------
# 4. setup.sql must reference SF_SOLUTIONS
# ---------------------------------------------------------------------------
if [[ -f "$SETUP_SQL" ]]; then
    if ! grep -q "SF_SOLUTIONS" "$SETUP_SQL"; then
        echo "FAIL: scripts/setup.sql does not reference SF_SOLUTIONS"
        ERRORS=$((ERRORS + 1))
    fi
fi

# ---------------------------------------------------------------------------
# 5. teardown.sql safety — must NOT drop SF_SOLUTIONS DB or WH
# ---------------------------------------------------------------------------
TEARDOWN_SQL="$TARGET/scripts/teardown.sql"
if [[ -f "$TEARDOWN_SQL" ]]; then
    if grep -qiE "DROP[[:space:]]+DATABASE[[:space:]]+(IF[[:space:]]+EXISTS[[:space:]]+)?SF_SOLUTIONS[[:space:];]" "$TEARDOWN_SQL"; then
        echo "FAIL: scripts/teardown.sql must not DROP DATABASE SF_SOLUTIONS"
        ERRORS=$((ERRORS + 1))
    fi
    if grep -qiE "DROP[[:space:]]+WAREHOUSE[[:space:]]+(IF[[:space:]]+EXISTS[[:space:]]+)?SF_SOLUTIONS_WH[[:space:];]" "$TEARDOWN_SQL"; then
        echo "FAIL: scripts/teardown.sql must not DROP WAREHOUSE SF_SOLUTIONS_WH"
        ERRORS=$((ERRORS + 1))
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [[ $ERRORS -gt 0 ]]; then
    echo "Conformance check: FAILED ($ERRORS error(s)). Fix before committing."
    exit 1
fi

echo "Conformance check: PASSED"
exit 0
