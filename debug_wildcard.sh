#!/bin/bash

# Debug why cache_* wildcard isn't matching

TEST_DIR="/tmp/wildcard_debug_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "=== Creating test setup ==="
mkdir -p {cache,cache_old,cache_backup}
echo "data" > cache/file.txt
echo "old" > cache_old/file.txt
echo "backup" > cache_backup/file.txt

collate init > /dev/null

cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - cache_*
EOF

echo ""
echo "=== Config contents ==="
cat .collate/config.yaml

echo ""
echo "=== Manual pattern test in bash ==="
pattern="cache_*"
for dir in cache cache_old cache_backup; do
    echo -n "Testing '$dir' against '$pattern': "
    if [[ "$dir" == $pattern ]]; then
        echo "✓ MATCHES"
    else
        echo "✗ no match"
    fi
done

echo ""
echo "=== Running collate with DEBUG_EXCLUDE=1 ==="
DEBUG_EXCLUDE=1 collate . -o output.txt 2>&1 | grep -E "(cache_old|cache_backup|EXCLUDE_DIRS|Testing pattern)"

echo ""
echo "=== Checking output ==="
echo "Files in output:"
grep "===== FILE:" output.txt

if grep -q "cache_old" output.txt; then
    echo "✗ cache_old was INCLUDED (should be excluded)"
else
    echo "✓ cache_old was EXCLUDED"
fi

if grep -q "cache_backup" output.txt; then
    echo "✗ cache_backup was INCLUDED (should be excluded)"
else
    echo "✓ cache_backup was EXCLUDED"
fi

# Cleanup
cd /
rm -rf "$TEST_DIR"