#!/usr/bin/env bash
# test/demo-textedit.sh — Test agent-native with TextEdit.app
# Opens TextEdit, types text, saves to /tmp/agent-native-test.txt, verifies.
#
# Requires: accessibility permissions, jq, TextEdit.app
# Usage: ./test/demo-textedit.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="${AGENT_NATIVE_BIN:-$ROOT_DIR/.build/release/agent-native}"
OUTPUT_FILE="/tmp/agent-native-test.txt"
TEST_TEXT="Hello from agent-native $(date +%s)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

PASS=0
FAIL=0

pass() { ((PASS++)) || true; echo -e "  ${GREEN}ok${RESET} $1"; }
fail() { ((FAIL++)) || true; echo -e "  ${RED}FAIL${RESET} $1"; echo "    $2"; }

cleanup() {
    osascript -e 'tell application "TextEdit" to close every document saving no' 2>/dev/null || true
    osascript -e 'quit app "TextEdit"' 2>/dev/null || true
    # Restore rich text default
    defaults write com.apple.TextEdit RichText -int 1 2>/dev/null || true
}
trap cleanup EXIT

if [[ ! -f "$BIN" ]]; then
    echo "Build first: swift build -c release"
    exit 1
fi

command -v jq >/dev/null || { echo "jq is required: brew install jq"; exit 1; }

echo -e "${BOLD}TextEdit test: type and save to $OUTPUT_FILE${RESET}\n"

# -- Set plain text mode --
defaults write com.apple.TextEdit RichText -int 0 2>/dev/null || true

# -- Open TextEdit with a new document --
echo -e "${BOLD}Opening TextEdit...${RESET}"
$BIN open TextEdit
sleep 2
osascript -e 'tell application "TextEdit" to make new document' 2>/dev/null || true
sleep 1
pass "TextEdit opened"

# -- Find the text area --
echo -e "\n${BOLD}Snapshotting TextEdit...${RESET}"
SNAP=$($BIN snapshot TextEdit -i --json)

TEXT_REF=$(echo "$SNAP" | jq -r '.[] | select(.role == "AXTextArea" or .role == "AXTextField") | .ref' | head -1)

if [[ -z "$TEXT_REF" ]]; then
    echo -e "${RED}Could not find text area. Snapshot:${RESET}"
    $BIN snapshot TextEdit -i
    exit 1
fi
pass "found text area: @$TEXT_REF"

# -- Type text --
echo -e "\n${BOLD}Typing text...${RESET}"
$BIN fill "@$TEXT_REF" "$TEST_TEXT" > /dev/null 2>&1
sleep 0.5
pass "filled text area"

# -- Verify text was typed --
TYPED=$($BIN get value "@$TEXT_REF" 2>/dev/null)
if echo "$TYPED" | grep -q "Hello from agent-native"; then
    pass "text verified in editor"
else
    fail "text not found in editor" "got: $TYPED"
fi

# -- Save via AppleScript --
echo -e "\n${BOLD}Saving to $OUTPUT_FILE...${RESET}"
osascript -e "tell application \"TextEdit\" to save front document in POSIX file \"$OUTPUT_FILE\"" 2>/dev/null
sleep 1

# -- Verify file --
if [[ -f "$OUTPUT_FILE" ]]; then
    pass "file created at $OUTPUT_FILE"
    CONTENTS=$(cat "$OUTPUT_FILE")
    if echo "$CONTENTS" | grep -q "Hello from agent-native"; then
        pass "file contents verified"
        echo -e "  ${YELLOW}Contents:${RESET} $CONTENTS"
    else
        fail "file contents wrong" "got: $CONTENTS"
    fi
else
    fail "file not saved" "$OUTPUT_FILE does not exist"
fi

# -- Summary --
echo -e "\n${BOLD}Results:${RESET} ${GREEN}$PASS passed${RESET}, ${RED}$FAIL failed${RESET}"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
