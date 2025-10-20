#!/bin/bash

# Quick verification script for collate fixes
# Tests that directory exclusions work correctly

# REMOVED: set -e (so it doesn't exit on first error)

# Color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

PASSED=0
FAILED=0
TEST_DIR="/tmp/collate_fix_test_$$"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Collate Fix Verification${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Cleanup function
cleanup() {
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

trap cleanup EXIT

# Test function with error details
test_case() {
    local test_name="$1"
    local test_result="$2"
    local error_msg="$3"
    
    if [[ "$test_result" == "0" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        if [[ -n "$error_msg" ]]; then
            echo -e "${RED}  └─ $error_msg${NC}"
        fi
        ((FAILED++))
    fi
}

# Setup test environment
echo -e "${YELLOW}Setting up test environment...${NC}"
echo -e "${YELLOW}Test directory: $TEST_DIR${NC}\n"

mkdir -p "$TEST_DIR" || {
    echo -e "${RED}Failed to create test directory${NC}"
    exit 1
}
cd "$TEST_DIR" || {
    echo -e "${RED}Failed to cd to test directory${NC}"
    exit 1
}

# Create test structure with directories that should be excluded
mkdir -p {cache,logs,docs,src,build}
echo "cached data" > cache/data.txt
echo "log entry" > logs/app.log
echo "documentation" > docs/README.md
echo "source code" > src/main.py
echo "build artifact" > build/output.o

# Create some files that should be excluded
echo "error log" > error.log
echo "temp backup" > file.backup

# Test 1: Check if collate command exists
echo -e "${BLUE}Test 1: Checking if collate is installed${NC}"
if command -v collate &> /dev/null; then
    test_case "collate command exists" 0
    COLLATE_PATH=$(which collate)
    echo -e "  ${YELLOW}└─ Found at: $COLLATE_PATH${NC}"
else
    test_case "collate command exists" 1 "Run install.sh first"
    echo -e "\n${RED}Cannot continue without collate installed${NC}\n"
    exit 1
fi

# Test 2: Initialize project
echo -e "\n${BLUE}Test 2: Initialize project with collate init${NC}"
# Capture both stdout and stderr
INIT_OUTPUT=$(collate init 2>&1)
INIT_EXIT=$?

if [[ $INIT_EXIT -eq 0 && -f ".collate/config.yaml" ]]; then
    test_case "collate init creates config" 0
    echo -e "  ${YELLOW}└─ Config created at: $TEST_DIR/.collate/config.yaml${NC}"
else
    test_case "collate init creates config" 1 "Exit code: $INIT_EXIT"
    echo -e "${RED}Init output:${NC}"
    echo "$INIT_OUTPUT"
fi

# Test 3: Check default exclusions in config
echo -e "\n${BLUE}Test 3: Check default exclusions in config${NC}"
if [[ -f ".collate/config.yaml" ]]; then
    HAS_CACHE=$(grep -c "cache" .collate/config.yaml || true)
    HAS_LOGS=$(grep -c "logs" .collate/config.yaml || true)
    HAS_DOCS=$(grep -c "docs" .collate/config.yaml || true)
    
    if [[ $HAS_CACHE -gt 0 && $HAS_LOGS -gt 0 && $HAS_DOCS -gt 0 ]]; then
        test_case "Config has default exclusions (cache, logs, docs)" 0
        echo -e "  ${YELLOW}└─ Found: cache($HAS_CACHE), logs($HAS_LOGS), docs($HAS_DOCS)${NC}"
    else
        test_case "Config has default exclusions (cache, logs, docs)" 1 \
            "Missing defaults - cache:$HAS_CACHE, logs:$HAS_LOGS, docs:$HAS_DOCS"
    fi
else
    test_case "Config has default exclusions (cache, logs, docs)" 1 "Config file not found"
fi

# Test 4: Run collate and check output
echo -e "\n${BLUE}Test 4: Run collate and verify exclusions${NC}"
echo -e "${YELLOW}First, let's check what config was loaded...${NC}"

# Check what's actually in the arrays by running a quick test
cat > test_config_load.sh << 'EOFTEST'
#!/bin/bash
source ~/.local/bin/collate

# Show what was loaded
echo "=== System Config ==="
echo "SYSTEM_EXCLUDE_FILES: ${SYSTEM_EXCLUDE_FILES[@]}"
echo ""
echo "=== Project Config ==="
cat .collate/config.yaml | grep -A5 "exclude_files:"
echo ""
echo "=== Combined Arrays ==="
echo "EXCLUDE_FILES array has ${#EXCLUDE_FILES[@]} items"
for item in "${EXCLUDE_FILES[@]}"; do
    echo "  - '$item'"
done
EOFTEST

chmod +x test_config_load.sh
./test_config_load.sh 2>&1 || true

echo -e "\n${YELLOW}Now running collate with verbose mode...${NC}"
COLLATE_OUTPUT=$(collate . -o output.txt -v 2>&1)
COLLATE_EXIT=$?

if [[ $COLLATE_EXIT -ne 0 ]]; then
    echo -e "${RED}Collate failed with exit code: $COLLATE_EXIT${NC}"
    echo -e "${RED}Output (first 100 lines):${NC}"
    echo "$COLLATE_OUTPUT" | head -100
fi

if [[ -f "output.txt" ]]; then
    FILE_SIZE=$(wc -c < output.txt)
    echo -e "  ${YELLOW}└─ Output file created: $FILE_SIZE bytes${NC}"
    
    # Show what was actually included
    echo -e "  ${YELLOW}└─ Files in output:${NC}"
    grep "===== FILE:" output.txt | head -5 | sed 's/^/      /'
    
    # Test 4a: cache directory excluded
    if ! grep -q "cached data" output.txt; then
        test_case "cache/ directory is excluded" 0
    else
        test_case "cache/ directory is excluded" 1 "Found 'cached data' in output"
    fi

    # Test 4b: logs directory excluded
    if ! grep -q "log entry" output.txt; then
        test_case "logs/ directory is excluded" 0
    else
        test_case "logs/ directory is excluded" 1 "Found 'log entry' in output"
    fi

    # Test 4c: docs directory excluded
    if ! grep -q "documentation" output.txt; then
        test_case "docs/ directory is excluded" 0
    else
        test_case "docs/ directory is excluded" 1 "Found 'documentation' in output"
    fi

    # Test 4d: src directory included
    if grep -q "source code" output.txt; then
        test_case "src/ directory is included" 0
    else
        test_case "src/ directory is included" 1 "Did not find 'source code' in output"
    fi

    # Test 4e: .log files excluded
    if ! grep -q "error log" output.txt; then
        test_case "*.log files are excluded" 0
    else
        test_case "*.log files are excluded" 1 "Found 'error log' in output"
    fi
else
    echo -e "${RED}output.txt was not created${NC}"
    test_case "cache/ directory is excluded" 1 "No output file"
    test_case "logs/ directory is excluded" 1 "No output file"
    test_case "docs/ directory is excluded" 1 "No output file"
    test_case "src/ directory is included" 1 "No output file"
    test_case "*.log files are excluded" 1 "No output file"
fi

# Test 5: Add custom exclusion
echo -e "\n${BLUE}Test 5: Add custom exclusion (build directory)${NC}"
if [[ -f ".collate/config.yaml" ]]; then
    # Check if exclude_dirs section exists
    if grep -q "^exclude_dirs:" .collate/config.yaml; then
        # Add to existing section
        sed -i '/^exclude_dirs:/a\  - build' .collate/config.yaml
    else
        # Create new section
        echo -e "\nexclude_dirs:\n  - build" >> .collate/config.yaml
    fi
    
    echo -e "  ${YELLOW}└─ Added 'build' to exclude_dirs${NC}"
    
    COLLATE2_OUTPUT=$(collate . -o output2.txt 2>&1)
    COLLATE2_EXIT=$?
    
    if [[ -f "output2.txt" ]]; then
        if ! grep -q "build artifact" output2.txt; then
            test_case "Custom exclusion (build/) works" 0
        else
            test_case "Custom exclusion (build/) works" 1 "Found 'build artifact' in output"
        fi
    else
        test_case "Custom exclusion (build/) works" 1 "output2.txt not created"
        echo -e "${RED}Collate output: $COLLATE2_OUTPUT${NC}"
    fi
else
    test_case "Custom exclusion (build/) works" 1 "Config file not found"
fi

# Test 6: Test allow override
echo -e "\n${BLUE}Test 6: Test allow_files override${NC}"
if [[ -f ".collate/config.yaml" ]]; then
    cat >> .collate/config.yaml << 'EOF'

allow_files:
  - "README.md"
EOF
    
    echo -e "  ${YELLOW}└─ Added README.md to allow_files${NC}"
    
    COLLATE3_OUTPUT=$(collate . -o output3.txt 2>&1)
    COLLATE3_EXIT=$?
    
    if [[ -f "output3.txt" ]]; then
        if grep -q "README.md" output3.txt; then
            test_case "allow_files override works" 0
        else
            test_case "allow_files override works" 1 "README.md not found in output"
            echo -e "  ${YELLOW}└─ This might be expected if docs/ is excluded before allow_files is checked${NC}"
        fi
    else
        test_case "allow_files override works" 1 "output3.txt not created"
    fi
else
    test_case "allow_files override works" 1 "Config file not found"
fi

# Test 7: col8 alias works
echo -e "\n${BLUE}Test 7: Test col8 alias${NC}"
if command -v col8 &> /dev/null; then
    COL8_OUTPUT=$(col8 --help 2>&1)
    COL8_EXIT=$?
    if [[ $COL8_EXIT -eq 0 ]]; then
        test_case "col8 alias works" 0
        COL8_PATH=$(which col8)
        echo -e "  ${YELLOW}└─ Found at: $COL8_PATH${NC}"
    else
        test_case "col8 alias works" 1 "Exit code: $COL8_EXIT"
    fi
else
    test_case "col8 alias works" 1 "col8 command not found"
fi

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   Test Summary${NC}"
echo -e "${BLUE}========================================${NC}\n"

TOTAL=$((PASSED + FAILED))
PASS_PERCENT=$((PASSED * 100 / TOTAL))

echo -e "Total Tests: ${BLUE}$TOTAL${NC}"
echo -e "Passed:      ${GREEN}$PASSED${NC}"
echo -e "Failed:      ${RED}$FAILED${NC}"
echo -e "Success:     ${YELLOW}${PASS_PERCENT}%${NC}\n"

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ All tests passed! ($PASSED/$TOTAL)        ║${NC}"
    echo -e "${GREEN}║                                        ║${NC}"
    echo -e "${GREEN}║  Your collate installation is working ║${NC}"
    echo -e "${GREEN}║  correctly! All fixes verified.        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"
    exit 0
else
    echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠ Some tests failed ($PASSED/$TOTAL passed)    ║${NC}"
    echo -e "${YELLOW}║                                        ║${NC}"
    echo -e "${YELLOW}║  Failed: $FAILED test(s)                    ║${NC}"
    echo -e "${YELLOW}║  Review output above for details      ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}Debug info:${NC}"
    echo -e "Test directory: $TEST_DIR"
    if [[ -f "$TEST_DIR/.collate/config.yaml" ]]; then
        echo -e "\n${YELLOW}Config file contents:${NC}"
        cat "$TEST_DIR/.collate/config.yaml"
    fi
    
    exit 1
fi