#!/bin/bash

# Comprehensive test that color codes don't leak in any context

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

TEST_DIR="/tmp/color_leak_test_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

TESTS_PASSED=0
TESTS_FAILED=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Testing ANSI Color Code Leaks${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Helper function to check for leaked ANSI codes
check_for_ansi_leak() {
    local test_name="$1"
    local output="$2"
    
    echo -n "Test: $test_name... "
    
    # Look for literal \033 or \x1b patterns (escaped ANSI codes)
    if echo "$output" | grep -qE '\\033\[|\\x1b\['; then
        echo -e "${RED}✗ FAIL${NC}"
        echo -e "${RED}  Found literal ANSI codes:${NC}"
        echo "$output" | grep -E '\\033\[|\\x1b\[' | head -3
        ((TESTS_FAILED++))
        return 1
    else
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    fi
}

# Setup
mkdir -p src
echo "source" > src/main.py
collate init > /dev/null 2>&1

echo -e "${YELLOW}=== Test 1: Overwrite prompt (simulating non-interactive) ===${NC}"
echo "existing content" > output.txt
OUTPUT=$(echo "n" | collate . -o output.txt 2>&1)
check_for_ansi_leak "Overwrite prompt with pipe input" "$OUTPUT"

echo ""
echo -e "${YELLOW}=== Test 2: Date substitution (user's original issue) ===${NC}"
TESTFILE="./output-$(date +%Y%m%d).txt"
echo "existing" > "$TESTFILE"
OUTPUT=$(echo "n" | collate . -o "$TESTFILE" 2>&1)
check_for_ansi_leak "Date substitution in filename" "$OUTPUT"

echo ""
echo -e "${YELLOW}=== Test 3: Uninit prompt ===${NC}"
OUTPUT=$(echo "n" | collate uninit 2>&1)
check_for_ansi_leak "Uninit proceed prompt" "$OUTPUT"

echo ""
echo -e "${YELLOW}=== Test 4: No output file specified (non-interactive) ===${NC}"
OUTPUT=$(collate . 2>&1 < /dev/null | head -10)
check_for_ansi_leak "No output file in non-interactive mode" "$OUTPUT"

echo ""
echo -e "${YELLOW}=== Test 5: Overwrite in subshell ===${NC}"
echo "test" > subshell_output.txt
OUTPUT=$( (echo "n" | collate . -o subshell_output.txt) 2>&1)
check_for_ansi_leak "Overwrite in subshell" "$OUTPUT"

echo ""
echo -e "${YELLOW}=== Test 6: Command substitution context ===${NC}"
echo "test" > cmd_output.txt
OUTPUT=$(bash -c 'echo "n" | collate . -o cmd_output.txt' 2>&1)
check_for_ansi_leak "Command substitution context" "$OUTPUT"

# Cleanup
cd /
rm -rf "$TEST_DIR"

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
TOTAL=$((TESTS_PASSED + TESTS_FAILED))
echo -e "Total:  ${BLUE}$TOTAL${NC}"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed! No ANSI code leaks detected.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. ANSI codes are leaking in non-interactive contexts.${NC}"
    echo -e "${YELLOW}Please ensure you've run: ./install.sh${NC}"
    exit 1
fi