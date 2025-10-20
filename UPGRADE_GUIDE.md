# Collate Upgrade Guide

## 🎯 Quick Overview

You're upgrading from a manually installed `collate` script to a fixed version with:

- ✅ Working directory exclusions
- ✅ Better default configurations
- ✅ Automated installation
- ✅ No regressions

## 📋 Pre-Upgrade Checklist

Before upgrading, note your current setup:

```bash
# Check current installation
which collate
# Output: /home/mshittu/.local/bin/collate

# Check if you have any custom system config
ls -la ~/.collate/
# Note: Save any custom settings if they exist

# Check for project-specific configs
find ~/projects -name ".collate" -type d 2>/dev/null
# Note: These will continue to work after upgrade
```

## 🚀 Upgrade Steps

### Step 1: Backup Your Current Installation (Optional)

```bash
# Backup current script
cp ~/.local/bin/collate ~/.local/bin/collate.backup

# Backup system config if it exists
if [[ -f ~/.collate/config.yaml ]]; then
    cp ~/.collate/config.yaml ~/.collate/config.yaml.backup
fi
```

### Step 2: Download Fixed Files

You have these new/updated files:

1. `collate.sh` - Fixed script with working exclusions
2. `install.sh` - Automated installer
3. `uninstall.sh` - Clean removal script
4. `verify_fixes.sh` - Test script
5. `config.yaml` - System-wide config

Save them to a directory, for example: `~/downloads/collate-fixed/`

### Step 3: Run the Installer

```bash
cd ~/downloads/collate-fixed/

# Make installer executable
chmod +x install.sh

# Run installer
./install.sh
```

**What will happen:**

- Installer detects existing `~/.local/bin/collate`
- Overwrites it with the fixed version
- If `~/.collate/config.yaml` exists, asks if you want to overwrite
- Creates/updates `col8` symlink
- Verifies installation

**Installer output:**

```
========================================
   Collate Installation Script
========================================

Installation directories:
  Binary: /home/mshittu/.local/bin
  Config: /home/mshittu/.collate

Installing collate.sh...
Creating col8 alias...
Config file already exists at /home/mshittu/.collate/config.yaml
Overwrite existing config? (y/N): 
```

**Recommendation**:

- Say **Y** to overwrite config if you haven't customized it
- Say **N** if you have custom system-wide exclusions you want to keep

### Step 4: Verify the Installation

```bash
# Make verification script executable
chmod +x verify_fixes.sh

# Run verification
./verify_fixes.sh
```

**Expected output:**

```
========================================
   Collate Fix Verification
========================================

Setting up test environment...

Test 1: Checking if collate is installed
✓ PASS: collate command exists

Test 2: Initialize project with collate init
✓ PASS: collate init creates config

Test 3: Check default exclusions in config
✓ PASS: Config has default exclusions (cache, logs, docs)

Test 4: Run collate and verify exclusions
✓ PASS: cache/ directory is excluded
✓ PASS: logs/ directory is excluded
✓ PASS: docs/ directory is excluded
✓ PASS: src/ directory is included
✓ PASS: *.log files are excluded

Test 5: Add custom exclusion (build directory)
✓ PASS: Custom exclusion (build/) works

Test 6: Test allow_files override
✓ PASS: allow_files override works

Test 7: Test col8 alias
✓ PASS: col8 alias works

========================================
   Test Summary
========================================

✓ All tests passed! (11/11)

Your collate installation is working correctly!
All fixes have been verified.
```

### Step 5: Update Existing Projects

Your existing projects with `.collate/config.yaml` will continue to work, but won't have the new defaults.

**Option A: Keep existing configs** (they still work)

```bash
# No action needed
# Your current exclusions will continue to work
```

**Option B: Regenerate configs with better defaults**

```bash
cd ~/your-project

# Backup existing config
cp .collate/config.yaml .collate/config.yaml.old

# Remove and recreate
rm -rf .collate
collate init

# Compare and merge any custom settings from .old file
diff .collate/config.yaml.old .collate/config.yaml
```

## 🧪 Testing Your Upgrade

### Test 1: Basic Functionality

```bash
cd /tmp
mkdir test_collate
cd test_collate

# Create test files
mkdir -p {cache,src}
echo "cache data" > cache/data.txt
echo "source" > src/main.py

# Initialize
collate init

# Run collate
collate . -o output.txt

# Verify - should NOT contain cache data
cat output.txt | grep "cache data" && echo "FAIL: cache not excluded!" || echo "PASS: cache excluded"

# Verify - should contain source
cat output.txt | grep "source" && echo "PASS: src included" || echo "FAIL: src not included!"
```

### Test 2: Your Real Projects

```bash
cd ~/your-actual-project

# Run collate with verbose to see what's processed
collate . -o test-output.txt -v

# Check the output
less test-output.txt

# Verify cache, logs, docs are excluded
grep -c "cache/" test-output.txt  # Should be 0
grep -c "logs/" test-output.txt   # Should be 0
grep -c "docs
