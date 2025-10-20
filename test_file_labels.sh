#!/bin/bash

# Test to verify file labels are present in output

TEST_DIR="/tmp/test_labels_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "=== Creating test files ==="
mkdir -p src
echo "File 1 content" > src/file1.txt
echo "File 2 content" > src/file2.py

echo ""
echo "=== Running collate ==="
collate init > /dev/null 2>&1
collate src -o output.txt

echo ""
echo "=== Checking output file ==="
echo "First 30 lines of output:"
head -30 output.txt

echo ""
echo "=== Looking for file labels ==="
if grep -q "===== FILE:" output.txt; then
    echo "✓ FOUND: ===== FILE: labels"
    grep "===== FILE:" output.txt
else
    echo "✗ MISSING: ===== FILE: labels"
fi

echo ""
if grep -q "===== END:" output.txt; then
    echo "✓ FOUND: ===== END: labels"
    grep "===== END:" output.txt
else
    echo "✗ MISSING: ===== END: labels"
fi

echo ""
echo "=== Full output file ==="
cat output.txt

# Cleanup
cd /
rm -rf "$TEST_DIR"