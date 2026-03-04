#!/usr/bin/env bash
# test/integration.sh — Integration tests for agent-native
# Runs against TestFixture app. Requires macOS with accessibility permissions.
#
# Usage:
#   ./test/integration.sh           # Run all tests
#   ./test/integration.sh --quick   # Build + basic tests only (no AX)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$ROOT_DIR/.build/release/agent-native"
FIXTURE_SRC="$ROOT_DIR/TestFixture/TestFixture.swift"
FIXTURE_BIN="$ROOT_DIR/.build/TestFixture"
FIXTURE_PID=""

# -- Helpers --

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { ((PASS++)); echo -e "  ${GREEN}ok${RESET} $1"; }
fail() { ((FAIL++)); echo -e "  ${RED}FAIL${RESET} $1"; echo "    $2"; }
skip() { ((SKIP++)); echo -e "  ${YELLOW}skip${RESET} $1"; }

assert_ok() {
    local desc="$1"; shift
    if output=$("$@" 2>&1); then
        pass "$desc"
    else
        fail "$desc" "exit=$?, output: $output"
    fi
}

assert_contains() {
    local desc="$1"; local needle="$2"; shift 2
    if output=$("$@" 2>&1); then
        if echo "$output" | grep -qi "$needle"; then
            pass "$desc"
        else
            fail "$desc" "output did not contain '$needle': $output"
        fi
    else
        fail "$desc" "command failed (exit=$?): $output"
    fi
}

assert_json() {
    local desc="$1"; shift
    if output=$("$@" 2>&1); then
        if echo "$output" | python3 -m json.tool > /dev/null 2>&1; then
            pass "$desc"
        else
            fail "$desc" "invalid JSON: $output"
        fi
    else
        fail "$desc" "command failed (exit=$?): $output"
    fi
}

assert_equals() {
    local desc="$1"; local expected="$2"; shift 2
    if output=$("$@" 2>&1); then
        local trimmed
        trimmed=$(echo "$output" | xargs)
        if [[ "$trimmed" == "$expected" ]]; then
            pass "$desc"
        else
            fail "$desc" "expected '$expected', got '$trimmed'"
        fi
    else
        fail "$desc" "command failed (exit=$?): $output"
    fi
}

cleanup() {
    if [[ -n "$FIXTURE_PID" ]]; then
        kill "$FIXTURE_PID" 2>/dev/null || true
        wait "$FIXTURE_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# -- Build --

echo -e "\n${BOLD}Building agent-native...${RESET}"
cd "$ROOT_DIR"
swift build -c release 2>&1 | tail -1
if [[ ! -f "$BIN" ]]; then
    echo -e "${RED}Build failed${RESET}"
    exit 1
fi
echo -e "${GREEN}Build OK${RESET}\n"

# -- CLI basics --

echo -e "${BOLD}CLI basics${RESET}"
assert_ok      "version flag"          "$BIN" --version
assert_ok      "help flag"             "$BIN" --help
assert_contains "help lists commands"  "snapshot" "$BIN" --help
assert_contains "help lists commands"  "click"    "$BIN" --help

# -- apps command --

echo -e "\n${BOLD}apps command${RESET}"
assert_ok       "apps runs"            "$BIN" apps
assert_json     "apps --json"          "$BIN" apps --format json
assert_contains "apps shows Finder"    "Finder" "$BIN" apps

# -- Quick mode stops here --

if [[ "${1:-}" == "--quick" ]]; then
    echo -e "\n${BOLD}Quick mode -- skipping AX tests${RESET}"
    echo -e "\n${BOLD}Results:${RESET} ${GREEN}$PASS passed${RESET}, ${RED}$FAIL failed${RESET}, ${YELLOW}$SKIP skipped${RESET}"
    [[ $FAIL -eq 0 ]] && exit 0 || exit 1
fi

# -- Check accessibility --

echo -e "\n${BOLD}Checking accessibility permissions...${RESET}"
if ! "$BIN" tree Finder --depth 1 > /dev/null 2>&1; then
    echo -e "${YELLOW}Accessibility access not granted. Skipping AX tests.${RESET}"
    echo -e "Grant access: System Settings > Privacy & Security > Accessibility"
    echo -e "\n${BOLD}Results:${RESET} ${GREEN}$PASS passed${RESET}, ${RED}$FAIL failed${RESET}, ${YELLOW}$SKIP skipped${RESET}"
    exit 0
fi
echo -e "${GREEN}Accessibility OK${RESET}\n"

# -- Build & launch fixture --

echo -e "${BOLD}Building test fixture...${RESET}"
swiftc -o "$FIXTURE_BIN" "$FIXTURE_SRC" -framework Cocoa 2>&1
echo -e "${GREEN}Fixture built${RESET}"

echo -e "${BOLD}Launching test fixture...${RESET}"
"$FIXTURE_BIN" &
FIXTURE_PID=$!
sleep 2

if ! kill -0 "$FIXTURE_PID" 2>/dev/null; then
    echo -e "${RED}Fixture failed to launch${RESET}"
    exit 1
fi
echo -e "${GREEN}Fixture running (pid $FIXTURE_PID)${RESET}\n"

APP="Agent Native Test Fixture"

# -- tree --

echo -e "${BOLD}tree command${RESET}"
assert_ok       "tree runs"                "$BIN" tree "$APP"
assert_ok       "tree --depth 2"           "$BIN" tree "$APP" --depth 2
assert_json     "tree --format json"       "$BIN" tree "$APP" --format json
assert_contains "tree shows window title"  "Agent Native Test Fixture" "$BIN" tree "$APP"

# -- snapshot --

echo -e "\n${BOLD}snapshot command${RESET}"
assert_ok       "snapshot runs"            "$BIN" snapshot "$APP"
assert_ok       "snapshot -i"              "$BIN" snapshot "$APP" -i
assert_ok       "snapshot -i -c"           "$BIN" snapshot "$APP" -i -c
assert_json     "snapshot --json"          "$BIN" snapshot "$APP" --json
assert_contains "snapshot has refs"        "ref=" "$BIN" snapshot "$APP" -i
assert_contains "snapshot shows Submit"    "Submit" "$BIN" snapshot "$APP" -i
assert_contains "snapshot shows checkbox"  "notifications" "$BIN" snapshot "$APP" -i

# -- find --

echo -e "\n${BOLD}find command${RESET}"
assert_ok       "find buttons"             "$BIN" find "$APP" --role AXButton
assert_ok       "find by title"            "$BIN" find "$APP" --title "Submit"
assert_ok       "find checkboxes"          "$BIN" find "$APP" --role AXCheckBox
assert_contains "find Submit button"       "Submit" "$BIN" find "$APP" --title "Submit"
assert_json     "find --format json"       "$BIN" find "$APP" --role AXButton --format json

# -- inspect --

echo -e "\n${BOLD}inspect command${RESET}"
assert_ok       "inspect by title"         "$BIN" inspect "$APP" --title "Submit"
assert_contains "inspect shows actions"    "AXPress" "$BIN" inspect "$APP" --title "Submit"
assert_contains "inspect shows role"       "AXButton" "$BIN" inspect "$APP" --title "Submit"

# -- snapshot -> @ref interaction --

echo -e "\n${BOLD}snapshot -> ref workflow${RESET}"

"$BIN" snapshot "$APP" -i > /dev/null 2>&1

SUBMIT_REF=$("$BIN" snapshot "$APP" -i 2>/dev/null | grep -i "Submit" | grep -o 'ref=n[0-9]*' | head -1 | sed 's/ref=//')
if [[ -n "$SUBMIT_REF" ]]; then
    pass "found Submit ref: @$SUBMIT_REF"
    assert_ok "click @ref" "$BIN" click "@$SUBMIT_REF"
else
    fail "could not find Submit ref" "snapshot output did not contain Submit with ref"
fi

CHECKBOX_REF=$("$BIN" snapshot "$APP" -i 2>/dev/null | grep -i "notifications" | grep -o 'ref=n[0-9]*' | head -1 | sed 's/ref=//')
if [[ -n "$CHECKBOX_REF" ]]; then
    pass "found checkbox ref: @$CHECKBOX_REF"
    assert_ok "check @ref"   "$BIN" check "@$CHECKBOX_REF"
    assert_ok "uncheck @ref" "$BIN" uncheck "@$CHECKBOX_REF"
else
    skip "checkbox ref interaction"
fi

# -- get --

echo -e "\n${BOLD}get command${RESET}"
assert_ok       "get title"               "$BIN" get title "$APP"
assert_contains "get title value"         "Agent Native Test Fixture" "$BIN" get title "$APP"
assert_ok       "get text by title"       "$BIN" get text "$APP" --title "Submit"

# -- is --

echo -e "\n${BOLD}is command${RESET}"
assert_ok       "is enabled (Submit)"      "$BIN" is enabled "$APP" --title "Submit"
assert_equals   "Submit is enabled"        "true" "$BIN" is enabled "$APP" --title "Submit"

# -- fill / type --

echo -e "\n${BOLD}fill / type commands${RESET}"

"$BIN" snapshot "$APP" -i > /dev/null 2>&1
INPUT_REF=$("$BIN" snapshot "$APP" -i 2>/dev/null | grep -i "Main Input\|main-input\|Type here" | grep -o 'ref=n[0-9]*' | head -1 | sed 's/ref=//')
if [[ -n "$INPUT_REF" ]]; then
    pass "found input ref: @$INPUT_REF"
    assert_ok "fill @ref"  "$BIN" fill "@$INPUT_REF" "hello world"
    assert_ok "type @ref"  "$BIN" type "@$INPUT_REF" "appended"
else
    assert_ok "fill by label" "$BIN" fill "$APP" "hello world" --label "Main Input"
fi

# -- focus / hover --

echo -e "\n${BOLD}focus / hover commands${RESET}"
assert_ok       "focus by title"           "$BIN" focus "$APP" --title "Submit"

# -- wait --

echo -e "\n${BOLD}wait command${RESET}"
assert_ok       "wait for existing element" "$BIN" wait "$APP" --title "Submit" --timeout 2

# -- JSON output --

echo -e "\n${BOLD}JSON output consistency${RESET}"
assert_json     "snapshot --json valid"    "$BIN" snapshot "$APP" -i --json
assert_json     "find --json valid"        "$BIN" find "$APP" --role AXButton --format json
assert_json     "apps --json valid"        "$BIN" apps --format json
assert_json     "get title --json valid"   "$BIN" get title "$APP" --json
assert_json     "is enabled --json valid"  "$BIN" is enabled "$APP" --title "Submit" --json

# -- error handling --

echo -e "\n${BOLD}error handling${RESET}"
if ! "$BIN" tree "NonExistentApp12345" > /dev/null 2>&1; then
    pass "tree nonexistent app fails gracefully"
else
    fail "tree nonexistent app should fail" ""
fi

if ! "$BIN" click "@n99999" > /dev/null 2>&1; then
    pass "click invalid ref fails gracefully"
else
    fail "click invalid ref should fail" ""
fi

if ! "$BIN" wait "$APP" --title "NonExistent" --timeout 1 > /dev/null 2>&1; then
    pass "wait timeout fails gracefully"
else
    fail "wait timeout should fail" ""
fi

# -- Results --

echo -e "\n${BOLD}Results:${RESET} ${GREEN}$PASS passed${RESET}, ${RED}$FAIL failed${RESET}, ${YELLOW}$SKIP skipped${RESET}"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
