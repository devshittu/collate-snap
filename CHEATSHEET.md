# Collate v3.0 Quick Reference Cheatsheet

## 📚 Table of Contents

- [Installation](#-installation)
- [Basic Commands](#-basic-commands)
- [New in v3](#-new-in-v3)
- [Configuration](#-configuration)
- [Common Use Cases](#-common-use-cases)
- [Pattern Syntax](#-pattern-syntax)
- [Troubleshooting](#-troubleshooting)
- [Tips & Tricks](#-tips--tricks)

---

## 🚀 Installation

### Quick Install

```bash
# Clone/download the project, then:
chmod +x install.sh
./install.sh
```

### Manual Install

```bash
mkdir -p ~/.local/bin ~/.collate
cp collate.sh ~/.local/bin/collate
chmod +x ~/.local/bin/collate
ln -s ~/.local/bin/collate ~/.local/bin/col8
cp config.yaml ~/.collate/config.yaml

# Add to PATH if needed
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Uninstall

```bash
./uninstall.sh
```

---

## 📖 Basic Commands

### Initialize Project

```bash
collate init                    # Create .collate/config.yaml with sensible defaults
col8 init                       # Same (col8 is an alias)
collate init --help             # Show help for init command
```

### Combine Files

```bash
# Basic usage
collate ./src -o output.txt     # Combine files from ./src into output.txt
col8 . -o combined.txt          # Combine current directory

# With verbose output
collate ./project -o out.txt -v # Show progress for each file

# Using default output location
collate ./src                   # Outputs to ./.temp/flat/output.txt

# With date in filename
collate . -o ./output-$(date +%Y%m%d).txt
```

### Remove Project Config

```bash
collate uninit                  # Remove .collate directory
collate uninit --help           # Show help
```

### Help

```bash
collate --help                  # Main help
collate init --help             # Init help
collate uninit --help           # Uninit help
```

---

## ⚙️ Configuration

### Config File Locations

**System-wide** (applies to all projects):

```bash
~/.collate/config.yaml
```

**Project-specific** (overrides/adds to system config):

```bash
.collate/config.yaml
```

### Default Exclusions on Init

When you run `collate init`, these are automatically added:

```yaml
exclude_dirs:
  - cache
  - logs
  - docs
  - .git
  - coverage
  - .pytest_cache
  - .mypy_cache
  - htmlcov

exclude_files:
  - "*.log"
  - "*.md"
  - ".env"
  - ".env.*"
```

### Configuration Syntax

```yaml
# Directories to exclude
exclude_dirs:
  - cache           # Simple name
  - build/          # Trailing slash (auto-stripped)
  - ./temp          # Leading ./ (auto-stripped)
  - backup_*        # Wildcards supported!
  - 'node_modules'  # Quotes optional

# Files to exclude  
exclude_files:
  - "*.log"         # Extension wildcard
  - "temp_*"        # Prefix wildcard
  - "*.backup"      # Any wildcard pattern
  - ".env*"         # Dot files with wildcards

# Override exclusions (highest priority)
allow_dirs:
  - docs/api        # Include only docs/api subdirectory
  
allow_files:
  - "README.md"     # Include README.md even if *.md is excluded
  - ".env.example"  # Include example env file

# Exclude dot directories (true/false)
exclude_dot_dirs: true
```

---

## 💡 Common Use Cases

### 1. Combine Source Code for AI Analysis

```bash
# Initialize with sensible defaults
collate init

# Combine all source files
collate ./src -o code-review.txt

# Share with AI assistant for code review
```

### 2. Create Documentation Bundle

```bash
# Allow docs despite default exclusion
cat >> .collate/config.yaml << 'EOF'
allow_dirs:
  - docs
EOF

collate . -o documentation-bundle.txt
```

### 3. Export Project Snapshot

```bash
# Exclude tests and large files
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - tests
  - __tests__
  - node_modules
  - .git

exclude_files:
  - "*.min.js"
  - "*.min.css"
  - "*.jpg"
  - "*.png"
  - "package-lock.json"
EOF

collate . -o project-snapshot-$(date +%Y%m%d).txt
```

### 4. Combine Config Files Only

```bash
cat > .collate/config.yaml << 'EOF'
# Exclude everything by default
exclude_dirs:
  - "*"

# Only allow config files
allow_files:
  - "*.yaml"
  - "*.yml"
  - "*.json"
  - "*.toml"
  - ".env.example"
EOF

collate . -o configs.txt
```

### 5. Create Test Suite Bundle

```bash
cat > .collate/config.yaml << 'EOF'
# Include only test files
allow_dirs:
  - tests
  - __tests__
  - test

allow_files:
  - "test_*.py"
  - "*_test.py"
  - "*.test.js"
  - "*.spec.js"
EOF

collate . -o test-suite.txt
```

### 6. Backend API Documentation

```bash
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - frontend
  - public
  - static
  - migrations

allow_files:
  - "*.py"
  - "requirements.txt"
  - "Dockerfile"
  - "docker-compose.yml"
EOF

collate . -o backend-api.txt
```

---

## 🎯 Pattern Syntax

### Directory Patterns

| Pattern | Matches | Example |
|---------|---------|---------|
| `cache` | Exact name | `cache/`, `src/cache/` |
| `cache/` | Trailing slash (stripped) | Same as `cache` |
| `./cache` | Leading ./ (stripped) | Same as `cache` |
| `cache_*` | Wildcard prefix | `cache_old/`, `cache_backup/` |
| `*_cache` | Wildcard suffix | `tmp_cache/`, `api_cache/` |
| `temp*` | Starts with | `temp/`, `temporary/` |
| `.git` | Dot directories | `.git/`, `.github/` |

### File Patterns

| Pattern | Matches | Example |
|---------|---------|---------|
| `*.log` | Extension | `app.log`, `error.log` |
| `*.min.js` | Multiple extensions | `bundle.min.js` |
| `test_*` | Prefix | `test_utils.py`, `test_api.py` |
| `*_backup.txt` | Suffix | `data_backup.txt` |
| `.env*` | Dot files | `.env`, `.env.local` |
| `temp_*.log` | Combined | `temp_app.log` |

### NOT Supported

❌ `**/*.log` - Recursive path patterns (use `*.log` instead)  
❌ `src/**/*.py` - Deep path wildcards  
❌ `cache/*/sub` - Mid-path wildcards

**Reason**: Collate matches on basename (filename/dirname), not full paths. This keeps it simple and fast.

---

## 🐛 Troubleshooting

### "collate: command not found"

```bash
# Check if ~/.local/bin is in PATH
echo $PATH | grep .local/bin

# Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify installation
which collate
```

### Files Not Being Excluded

```bash
# Check your config syntax
cat .collate/config.yaml

# Common issues:
# - Missing quotes around wildcards: use "*.log" not *.log
# - Tabs instead of spaces (YAML requires spaces)
# - Wrong indentation (use 2 spaces)

# Test with verbose mode to see what's included
collate . -o test.txt -v

# Enable debug mode
DEBUG_EXCLUDE=1 collate . -o test.txt 2>&1 | grep "your-file"
```

### Output File Already Exists

```bash
# Collate prompts for overwrite
collate . -o output.txt
# Overwrite? (y/N): y

# Or use a unique filename
collate . -o output-$(date +%Y%m%d-%H%M%S).txt
```

### Too Many/Few Files Combined

```bash
# Check what configs are active
cat ~/.collate/config.yaml    # System-wide
cat .collate/config.yaml       # Project-specific

# Remember: project config ADDS to system config
# Use allow_dirs/allow_files to override exclusions
```

### Color Codes in Output

If you see `\033[0;33m` in prompts:

```bash
# Reinstall the fixed version
./install.sh

# This was fixed in v2 - ensure you have the latest version
collate --help | head -1
```

---

## 💎 Tips & Tricks

### 1. Quick Daily Snapshots

```bash
# Add to your shell alias
alias snapshot='collate . -o ~/snapshots/$(basename $(pwd))-$(date +%Y%m%d).txt'

# Usage
cd ~/projects/my-app
snapshot
```

### 2. Git Hook for Pre-Commit Review

```bash
# .git/hooks/pre-commit
#!/bin/bash
collate . -o .git/review-$(date +%Y%m%d).txt
echo "Code snapshot created: .git/review-$(date +%Y%m%d).txt"
```

### 3. Pipe to Clipboard

```bash
# Linux
collate ./src -o /tmp/code.txt && cat /tmp/code.txt | xclip -selection clipboard

# macOS
collate ./src -o /tmp/code.txt && cat /tmp/code.txt | pbcopy
```

### 4. Combine Multiple Directories

```bash
# Create temporary structure
mkdir -p /tmp/combined/{backend,frontend}
cp -r ./api/* /tmp/combined/backend/
cp -r ./web/* /tmp/combined/frontend/
collate /tmp/combined -o full-stack.txt
rm -rf /tmp/combined
```

### 5. Token Count Before Sending to AI

```bash
# Combine and count tokens (approximate)
collate . -o output.txt
wc -w output.txt              # Word count
echo $(( $(wc -c < output.txt) / 4 ))  # Rough token estimate
```

### 6. Exclude by Size

```bash
# First, combine everything
collate . -o full.txt

# Then filter large files
find . -type f -size +1M > .large-files.txt

# Add to config
cat .large-files.txt | while read f; do
    echo "  - \"$(basename $f)\"" >> .collate/config.yaml
done
```

### 7. Project Templates

```bash
# Python project
cat > ~/.collate/templates/python.yaml << 'EOF'
exclude_dirs:
  - __pycache__
  - .pytest_cache
  - .mypy_cache
  - venv
  - .venv
  - dist
  - build
  - *.egg-info

exclude_files:
  - "*.pyc"
  - "*.pyo"
  - ".coverage"
EOF

# Copy template when needed
cp ~/.collate/templates/python.yaml .collate/config.yaml
```

### 8. Multi-Project Workspace

```bash
# workspace/
# ├── project1/
# │   └── .collate/config.yaml
# ├── project2/
# │   └── .collate/config.yaml
# └── combine-all.sh

# combine-all.sh
for project in */; do
    cd "$project"
    collate . -o "../combined-${project%/}.txt"
    cd ..
done
```

### 9. Incremental Updates

```bash
# Only combine files modified in last 24 hours
find . -type f -mtime -1 -print0 | \
  xargs -0 -I {} sh -c 'echo "===== {} ====="; cat {}'  > recent-changes.txt
```

### 10. Verify Output

```bash
# Combine and verify
collate . -o output.txt

# Check line count
wc -l output.txt

# Check file count
grep -c "===== FILE:" output.txt

# Search for specific content
grep -n "function myFunction" output.txt
```

---

## 📊 Quick Reference Card

```bash
# ESSENTIAL COMMANDS
collate init                          # Initialize project config
collate . -o output.txt               # Combine current directory
collate ./src -o code.txt -v          # Verbose mode
collate uninit                        # Remove project config

# CONFIGURATION SHORTCUTS
echo "  - cache" >> .collate/config.yaml           # Add directory exclusion
echo '  - "*.log"' >> .collate/config.yaml         # Add file exclusion

# DEBUGGING
DEBUG_EXCLUDE=1 collate . -o test.txt              # Debug exclusions
collate . -o test.txt -v                           # Verbose output

# COMMON PATTERNS
collate . -o snapshot-$(date +%Y%m%d).txt          # Daily snapshot
collate . -o /tmp/code.txt && cat /tmp/code.txt    # View output
find . -name "*.py" | wc -l                        # Count files before combining
```

---

## 🔗 Additional Resources

- **Config Examples**: See `.collate/config.yaml` after running `collate init`
- **System Config**: `~/.collate/config.yaml` for global settings
- **Pattern Testing**: Use `DEBUG_EXCLUDE=1` to see exclusion logic
- **Verification**: Run `./verify_fixes.sh` to test installation

---

## 📝 License & Support

- **License**: MIT
- **Issues**: Check config syntax, reinstall with `./install.sh`
- **Updates**: Pull latest version and run `./install.sh`

---

**Pro Tip**: Create project-specific configs for different use cases (AI review, documentation, deployment) and switch between them as needed!

```bash
# Save different configs
cp .collate/config.yaml .collate/config-ai-review.yaml
cp .collate/config.yaml .collate/config-docs.yaml

# Switch between them
cp .collate/config-ai-review.yaml .collate/config.yaml
collate . -o review.txt
```

Happy combining! 🚀
