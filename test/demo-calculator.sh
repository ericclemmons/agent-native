#!/usr/bin/env bash
# test/demo-calculator.sh — Test agent-native with Calculator.app
# Computes 5 + 3 = 8, verifies the result.
#
# Requires: accessibility permissions, jq, Calculator.app
# Usage: ./test/demo-calculator.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="${AGENT_NATIVE_BIN:-$ROOT_DIR/.build/release/agent-native}"

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

PASS=0
FAIL=0

pass() { ((PASS++)) || true; echo -e "  ${GREEN}ok${RESET} $1"; }
fail() { ((FAIL++)) || true; echo -e "  ${RED}FAIL${RESET} $1"; echo "    $2"; }

cleanup() {
    osascript -e 'quit app "Calculator"' 2>/dev/null || true
}
trap cleanup EXIT

if [[ ! -f "$BIN" ]]; then
    echo "Build first: swift build -c release"
    exit 1
fi

command -v jq >/dev/null || { echo "jq is required: brew install jq"; exit 1; }

echo -e "${BOLD}Calculator test: 5 + 3 = 8${RESET}\n"

# -- Open Calculator --
echo -e "${BOLD}Opening Calculator...${RESET}"
$BIN open Calculator
sleep 1

# -- Snapshot and find button refs by label --
echo -e "\n${BOLD}Snapshotting Calculator...${RESET}"
SNAP=$($BIN snapshot Calculator -i --json)

ref_for() {
    echo "$SNAP" | jq -r --arg lbl "$1" '.[] | select(.role == "AXButton" and .label == $lbl) | .ref'
}

# -- Clear --
CLEAR_REF=$(ref_for "All Clear")
if [[ -n "$CLEAR_REF" ]]; then
    $BIN click "@$CLEAR_REF" > /dev/null 2>&1 || true
    pass "cleared (All Clear)"
    sleep 0.3
    SNAP=$($BIN snapshot Calculator -i --json)
fi

# -- Find button refs --
REF_5=$(ref_for "5")
REF_ADD=$(ref_for "Add")
REF_3=$(ref_for "3")
REF_EQ=$(ref_for "Equals")

if [[ -z "$REF_5" || -z "$REF_ADD" || -z "$REF_3" || -z "$REF_EQ" ]]; then
    echo -e "${RED}Could not find button refs.${RESET}"
    echo "  5=@${REF_5:-?}  Add=@${REF_ADD:-?}  3=@${REF_3:-?}  Equals=@${REF_EQ:-?}"
    exit 1
fi
pass "found refs: 5=@$REF_5  Add=@$REF_ADD  3=@$REF_3  Equals=@$REF_EQ"

# -- Press: 5 + 3 = --
echo -e "\n${BOLD}Computing 5 + 3 = ...${RESET}"

$BIN click "@$REF_5" > /dev/null 2>&1; sleep 0.2; pass "clicked 5"
$BIN click "@$REF_ADD" > /dev/null 2>&1; sleep 0.2; pass "clicked + (Add)"
$BIN click "@$REF_3" > /dev/null 2>&1; sleep 0.2; pass "clicked 3"
$BIN click "@$REF_EQ" > /dev/null 2>&1; sleep 0.3; pass "clicked = (Equals)"

# -- Read the result --
echo -e "\n${BOLD}Reading result...${RESET}"

# The display is an AXStaticText in the full (non-interactive) snapshot.
# Calculator wraps values with invisible Unicode marks — strip non-ASCII.
DISPLAY=$($BIN snapshot Calculator --json | \
    jq -r '.[] | select(.role == "AXStaticText" and .value != null) | .value' | \
    LC_ALL=C sed 's/[^[:print:]]//g' | \
    tail -1)

echo "  Display shows: ${DISPLAY:-<empty>}"

if [[ "$DISPLAY" == *8* ]]; then
    pass "5 + 3 = 8 verified!"
else
    fail "expected 8" "got: ${DISPLAY:-<nothing>}"
fi

# -- Summary --
echo -e "\n${BOLD}Results:${RESET} ${GREEN}$PASS passed${RESET}, ${RED}$FAIL failed${RESET}"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
