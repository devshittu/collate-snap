#!/bin/bash

# Test different pattern formats for exclude_dirs and exclude_files

set -e

# Color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

TEST_DIR="/tmp/collate_pattern_test_$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo -e "${BLUE}=== Testing Pattern Flexibility ===${NC}"
echo ""

# Create test structure
mkdir -p {cache,cache_old,cache_backup,logs,temp_files,src,.hidden}
echo "cache data" > cache/data.txt
echo "old cache" > cache_old/old.txt
echo "backup cache" > cache_backup/backup.txt
echo "logs" > logs/app.log
echo "temp" > temp_files/temp.txt
echo "source" > src/main.py
echo "hidden" > .hidden/secret.txt

echo -e "${YELLOW}Test structure created:${NC}"
find . -type f | sort

echo ""
echo -e "${BLUE}=== Test 1: Basic directory name (cache) ===${NC}"
collate init > /dev/null
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - cache
exclude_files:
  - "*.log"
EOF

collate . -o test1.txt 2>&1 | grep -v "^Progress:"
if ! grep -q "cache data" test1.txt; then
    echo -e "${GREEN}✓ PASS${NC}: 'cache' excluded"
else
    echo -e "${RED}✗ FAIL${NC}: 'cache' not excluded"
fi

echo ""
echo -e "${BLUE}=== Test 2: Directory with trailing slash (cache/) ===${NC}"
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - cache/
exclude_files:
  - "*.log"
EOF

collate . -o test2.txt 2>&1 | grep -v "^Progress:"
if ! grep -q "cache data" test2.txt; then
    echo -e "${GREEN}✓ PASS${NC}: 'cache/' excluded"
else
    echo -e "${RED}✗ FAIL${NC}: 'cache/' not excluded"
fi

echo ""
echo -e "${BLUE}=== Test 3: Directory with leading ./ (./cache) ===${NC}"
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - ./cache
exclude_files:
  - "*.log"
EOF

collate . -o test3.txt 2>&1 | grep -v "^Progress:"
if ! grep -q "cache data" test3.txt; then
    echo -e "${GREEN}✓ PASS${NC}: './cache' excluded"
else
    echo -e "${RED}✗ FAIL${NC}: './cache' not excluded"
fi

echo ""
echo -e "${BLUE}=== Test 4: Wildcard directory pattern (cache_*) ===${NC}"
# Clean up previous test output files before this test
rm -f test*.txt
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - cache_*
exclude_files:
  - "*.log"
  - "test*.txt"
EOF

collate . -o test4.txt 2>&1 | grep -v "^Progress:"
OLD_EXCLUDED=false
BACKUP_EXCLUDED=false
! grep -q "old cache" test4.txt && OLD_EXCLUDED=true
! grep -q "backup cache" test4.txt && BACKUP_EXCLUDED=true

if $OLD_EXCLUDED && $BACKUP_EXCLUDED; then
    echo -e "${GREEN}✓ PASS${NC}: 'cache_*' matched cache_old and cache_backup"
else
    echo -e "${RED}✗ FAIL${NC}: 'cache_*' didn't match all cache_* directories"
    echo -e "${YELLOW}  cache_old excluded: $OLD_EXCLUDED${NC}"
    echo -e "${YELLOW}  cache_backup excluded: $BACKUP_EXCLUDED${NC}"
    echo -e "${YELLOW}  Files in output:${NC}"
    grep "===== FILE:" test4.txt
fi

echo ""
echo -e "${BLUE}=== Test 5: Directory with single quotes ('cache') ===${NC}"
rm -f test*.txt  # Clean previous outputs
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - 'cache'
exclude_files:
  - "*.log"
  - "test*.txt"
EOF

collate . -o test5.txt 2>&1 | grep -v "^Progress:"
if ! grep -q "cache data" test5.txt; then
    echo -e "${GREEN}✓ PASS${NC}: 'cache' (single quotes) excluded"
else
    echo -e "${RED}✗ FAIL${NC}: 'cache' (single quotes) not excluded"
fi

echo ""
echo -e "${BLUE}=== Test 6: Directory with double quotes (\"cache\") ===${NC}"
rm -f test*.txt  # Clean previous outputs
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - "cache"
exclude_files:
  - "*.log"
  - "test*.txt"
EOF

collate . -o test6.txt 2>&1 | grep -v "^Progress:"
if ! grep -q "cache data" test6.txt; then
    echo -e "${GREEN}✓ PASS${NC}: \"cache\" (double quotes) excluded"
else
    echo -e "${RED}✗ FAIL${NC}: \"cache\" (double quotes) not excluded"
fi

echo ""
echo -e "${BLUE}=== Test 7: File wildcard pattern (temp_*) ===${NC}"
rm -f test*.txt  # Clean previous outputs
echo "temp file 1" > temp_file1.txt
echo "temp file 2" > temp_file2.log
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - cache
exclude_files:
  - "temp_*"
  - "test*.txt"
EOF

collate . -o test7.txt 2>&1 | grep -v "^Progress:"
TEMP1_EXCLUDED=false
TEMP2_EXCLUDED=false
! grep -q "temp file 1" test7.txt && TEMP1_EXCLUDED=true
! grep -q "temp file 2" test7.txt && TEMP2_EXCLUDED=true

if $TEMP1_EXCLUDED && $TEMP2_EXCLUDED; then
    echo -e "${GREEN}✓ PASS${NC}: 'temp_*' matched temp_file1.txt and temp_file2.log"
else
    echo -e "${RED}✗ FAIL${NC}: 'temp_*' didn't match all temp_* files"
    echo -e "${YELLOW}  temp_file1.txt excluded: $TEMP1_EXCLUDED${NC}"
    echo -e "${YELLOW}  temp_file2.log excluded: $TEMP2_EXCLUDED${NC}"
fi

echo ""
echo -e "${BLUE}=== Test 8: Complex wildcard (**/*.log) - NOT SUPPORTED ===${NC}"
rm -f test*.txt  # Clean previous outputs
mkdir -p deep/nested/logs
echo "deep log" > deep/nested/logs/deep.log
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - cache
exclude_files:
  - "**/*.log"
  - "test*.txt"
EOF

collate . -o test8.txt 2>&1 | grep -v "^Progress:"
# This won't work because we only match on basename, not full path
if grep -q "deep log" test8.txt; then
    echo -e "${YELLOW}⚠ NOTE${NC}: '**/*.log' NOT supported (only basename matching)"
    echo -e "${YELLOW}   Use '*.log' instead to match all .log files${NC}"
fi

echo ""
echo -e "${GREEN}=== Summary ===${NC}"
echo -e "${YELLOW}Supported patterns:${NC}"
echo "  exclude_dirs:"
echo -e "    ${GREEN}✓${NC} cache          (simple name)"
echo -e "    ${GREEN}✓${NC} cache/         (trailing slash - auto-stripped)"
echo -e "    ${GREEN}✓${NC} ./cache        (leading ./ - auto-stripped)"
echo -e "    ${GREEN}✓${NC} cache_*        (wildcards)"
echo -e "    ${GREEN}✓${NC} 'cache'        (single quotes - auto-stripped)"
echo -e "    ${GREEN}✓${NC} \"cache\"        (double quotes - auto-stripped)"
echo ""
echo "  exclude_files:"
echo -e "    ${GREEN}✓${NC} *.log          (extension wildcard)"
echo -e "    ${GREEN}✓${NC} temp_*         (prefix wildcard)"
echo -e "    ${GREEN}✓${NC} '*.log'        (single quotes - auto-stripped)"
echo -e "    ${GREEN}✓${NC} \"*.log\"        (double quotes - auto-stripped)"
echo ""
echo -e "${YELLOW}  NOT supported:${NC}"
echo -e "    ${RED}✗${NC} **/*.log       (path-based wildcards)"
echo -e "    ${RED}✗${NC} cache/**/sub   (recursive globs)"

# Cleanup
cd /
rm -rf "$TEST_DIR"

collate init > /dev/null
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - cache
exclude_files:
  - "*.log"
EOF

collate . -o test1.txt 2>&1 | grep -v "^Progress:"
if ! grep -q "cache data" test1.txt; then
    echo "✓ PASS: 'cache' excluded"
else
    echo "✗ FAIL: 'cache' not excluded"
fi

echo ""
echo "=== Test 2: Directory with trailing slash (cache/) ==="
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - cache/
exclude_files:
  - "*.log"
EOF

collate . -o test2.txt 2>&1 | grep -v "^Progress:"
if ! grep -q "cache data" test2.txt; then
    echo "✓ PASS: 'cache/' excluded"
else
    echo "✗ FAIL: 'cache/' not excluded"
fi

echo ""
echo "=== Test 3: Directory with leading ./ (./cache) ==="
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - ./cache
exclude_files:
  - "*.log"
EOF

collate . -o test3.txt 2>&1 | grep -v "^Progress:"
if ! grep -q "cache data" test3.txt; then
    echo "✓ PASS: './cache' excluded"
else
    echo "✗ FAIL: './cache' not excluded"
fi

echo ""
echo "=== Test 4: Wildcard directory pattern (cache_*) ==="
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - cache_*
exclude_files:
  - "*.log"
EOF

collate . -o test4.txt 2>&1 | grep -v "^Progress:"
OLD_EXCLUDED=false
BACKUP_EXCLUDED=false
! grep -q "old cache" test4.txt && OLD_EXCLUDED=true
! grep -q "backup cache" test4.txt && BACKUP_EXCLUDED=true

if $OLD_EXCLUDED && $BACKUP_EXCLUDED; then
    echo "✓ PASS: 'cache_*' matched cache_old and cache_backup"
else
    echo "✗ FAIL: 'cache_*' didn't match all cache_* directories"
    echo "  cache_old excluded: $OLD_EXCLUDED"
    echo "  cache_backup excluded: $BACKUP_EXCLUDED"
fi

echo ""
echo "=== Test 5: Directory with single quotes ('cache') ==="
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - 'cache'
exclude_files:
  - "*.log"
EOF

collate . -o test5.txt 2>&1 | grep -v "^Progress:"
if ! grep -q "cache data" test5.txt; then
    echo "✓ PASS: 'cache' (single quotes) excluded"
else
    echo "✗ FAIL: 'cache' (single quotes) not excluded"
fi

echo ""
echo "=== Test 6: Directory with double quotes (\"cache\") ==="
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - "cache"
exclude_files:
  - "*.log"
EOF

collate . -o test6.txt 2>&1 | grep -v "^Progress:"
if ! grep -q "cache data" test6.txt; then
    echo "✓ PASS: \"cache\" (double quotes) excluded"
else
    echo "✗ FAIL: \"cache\" (double quotes) not excluded"
fi

echo ""
echo "=== Test 7: File wildcard pattern (temp_*) ==="
echo "temp file 1" > temp_file1.txt
echo "temp file 2" > temp_file2.log
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - cache
exclude_files:
  - "temp_*"
EOF

collate . -o test7.txt 2>&1 | grep -v "^Progress:"
TEMP1_EXCLUDED=false
TEMP2_EXCLUDED=false
! grep -q "temp file 1" test7.txt && TEMP1_EXCLUDED=true
! grep -q "temp file 2" test7.txt && TEMP2_EXCLUDED=true

if $TEMP1_EXCLUDED && $TEMP2_EXCLUDED; then
    echo "✓ PASS: 'temp_*' matched temp_file1.txt and temp_file2.log"
else
    echo "✗ FAIL: 'temp_*' didn't match all temp_* files"
    echo "  temp_file1.txt excluded: $TEMP1_EXCLUDED"
    echo "  temp_file2.log excluded: $TEMP2_EXCLUDED"
fi

echo ""
echo "=== Test 8: Complex wildcard (**/*.log) - NOT SUPPORTED ==="
mkdir -p deep/nested/logs
echo "deep log" > deep/nested/logs/deep.log
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - cache
exclude_files:
  - "**/*.log"
EOF

collate . -o test8.txt 2>&1 | grep -v "^Progress:"
# This won't work because we only match on basename, not full path
if grep -q "deep log" test8.txt; then
    echo "⚠ NOTE: '**/*.log' NOT supported (only basename matching)"
    echo "   Use '*.log' instead to match all .log files"
fi

echo ""
echo "=== Summary ==="
echo "Supported patterns:"
echo "  exclude_dirs:"
echo "    ✓ cache          (simple name)"
echo "    ✓ cache/         (trailing slash - auto-stripped)"
echo "    ✓ ./cache        (leading ./ - should be stripped)"
echo "    ✓ cache_*        (wildcards)"
echo "    ✓ 'cache'        (single quotes - auto-stripped)"
echo "    ✓ \"cache\"        (double quotes - auto-stripped)"
echo ""
echo "  exclude_files:"
echo "    ✓ *.log          (extension wildcard)"
echo "    ✓ temp_*         (prefix wildcard)"
echo "    ✓ '*.log'        (single quotes - auto-stripped)"
echo "    ✓ \"*.log\"        (double quotes - auto-stripped)"
echo ""
echo "  NOT supported:"
echo "    ✗ **/*.log       (path-based wildcards)"
echo "    ✗ cache/**/sub   (recursive globs)"

# Cleanup
cd /
rm -rf "$TEST_DIR"