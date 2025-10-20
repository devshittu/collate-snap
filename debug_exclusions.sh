#!/bin/bash

# Direct test of exclusion logic to debug why *.log isn't being excluded

set -e

TEST_DIR="/tmp/collate_debug_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "=== Setting up test environment ==="
mkdir -p src
echo "test log" > error.log
echo "source code" > src/main.py

echo ""
echo "=== Initializing collate ==="
collate init

echo ""
echo "=== Checking config file ==="
echo "Project config (.collate/config.yaml):"
cat .collate/config.yaml | grep -A10 "exclude_files:"

echo ""
echo "System config (~/.collate/config.yaml):"
if [[ -f ~/.collate/config.yaml ]]; then
    cat ~/.collate/config.yaml | grep -A10 "exclude_files:"
else
    echo "No system config found"
fi

echo ""
echo "=== Testing pattern matching directly in bash ==="
filename="error.log"
pattern="*.log"

echo "Testing: if [[ \"$filename\" == $pattern ]]; then"
if [[ "$filename" == $pattern ]]; then
    echo "  ✓ Pattern matches!"
else
    echo "  ✗ Pattern does NOT match!"
fi

echo ""
echo "Testing with quotes: if [[ \"$filename\" == \"$pattern\" ]]; then"
if [[ "$filename" == "$pattern" ]]; then
    echo "  ✓ Pattern matches!"
else
    echo "  ✗ Pattern does NOT match!"
fi

echo ""
echo "=== Running collate ==="
collate . -o output.txt

echo ""
echo "=== Checking output ==="
if grep -q "test log" output.txt; then
    echo "✗ PROBLEM: error.log WAS included in output"
    echo ""
    echo "Output file contents:"
    cat output.txt
else
    echo "✓ GOOD: error.log was excluded"
fi

echo ""
echo "=== Let's manually trace through the exclusion logic ==="

# Read the config manually
echo "Reading exclude_files from .collate/config.yaml:"
EXCLUDE_FILES_FROM_CONFIG=$(grep -A10 "^exclude_files:" .collate/config.yaml | grep '^\s*-' | sed 's/^\s*-\s*//' | tr -d '"')
echo "$EXCLUDE_FILES_FROM_CONFIG"

echo ""
echo "Now testing each pattern against error.log:"
while IFS= read -r pattern; do
    if [[ -n "$pattern" ]]; then
        echo -n "  Testing '$pattern': "
        if [[ "error.log" == $pattern ]]; then
            echo "✓ MATCHES"
        else
            echo "✗ no match"
        fi
    fi
done <<< "$EXCLUDE_FILES_FROM_CONFIG"

# Cleanup
cd /
rm -rf "$TEST_DIR"