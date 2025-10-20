#!/bin/bash

# Test that color codes don't leak in non-interactive contexts

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m"

TEST_DIR="/tmp/color_leak_test_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo -e "${BLUE}=== Testing Color Code Leaks ===${NC}"
echo ""

# Create test files
mkdir -p src
echo "source" > src/main.py

collate init > /dev/null 2>&1

# Test 1: Overwrite prompt with command substitution (non-interactive stdin)
echo -e "${YELLOW}Test 1: Overwrite prompt with command substitution${NC}"
echo "test" > output.txt
OUTPUT=$(echo "n" | collate . -o output.txt 2>&1)

if echo "$OUTPUT" | grep -q '\\033\['; then
    echo -e "${RED}✗ FAIL${NC}: Found ANSI escape codes in output:"
    echo "$OUTPUT" | grep '\\033'
else
    echo -e "${GREEN}✓ PASS${NC}: No ANSI escape codes leaked"
fi

# Test 2: Using date substitution like the user's command
echo ""
echo -e "${YELLOW}Test 2: Overwrite with date substitution (like user's command)${NC}"
touch "./test-$(date +%Y%m%d).txt"
OUTPUT=$(echo "n" | collate . -o "./test-$(date +%Y%m%d).txt" 2>&1)

if echo "$OUTPUT" | grep -q '\\033\['; then
    echo -e "${RED}✗ FAIL${NC}: Found ANSI escape codes:"
    echo "$OUTPUT" | grep '\\033'
else
    echo -e "${GREEN}✓ PASS${NC}: No ANSI escape codes with date substitution"
fi

# Test 3: Uninit prompt
echo ""
echo -e "${YELLOW}Test 3: Uninit prompt in non-interactive mode${NC}"
OUTPUT=$(echo "n" | collate uninit 2>&1)

if echo "$OUTPUT" | grep -q '\\033\['; then
    echo -e "${RED}✗ FAIL${NC}: Found ANSI escape codes:"
    echo "$OUTPUT" | grep '\\033'
else
    echo -e "${GREEN}✓ PASS${NC}: No ANSI escape codes in uninit"
fi

# Test 4: No output file specified
echo ""
echo -e "${YELLOW}Test 4: No output file in non-interactive mode${NC}"
OUTPUT=$(collate . 2>&1 < /dev/null | head -5)

if echo "$OUTPUT" | grep -q '\\033\['; then
    echo -e "${RED}✗ FAIL${NC}: Found ANSI escape codes:"
    echo "$OUTPUT" | grep '\\033'
else
    echo -e "${GREEN}✓ PASS${NC}: No ANSI escape codes when no output file"
fi

# Cleanup
cd /
rm -rf "$TEST_DIR"

echo ""
echo -e "${GREEN}=== All color leak tests completed ===${NC}"