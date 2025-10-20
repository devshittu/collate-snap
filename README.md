# Collate

> 🚀 Recursively combine files into a single output file with smart exclusions

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-5.0+-green.svg)](https://www.gnu.org/software/bash/)

Collate is a command-line utility that intelligently combines multiple files into a single output file. Perfect for:

- 📝 Creating code snapshots for AI assistants
- 📚 Bundling documentation
- 🔍 Code reviews
- 📦 Project exports
- 🧪 Test suite consolidation

## ✨ Features

- ✅ **Recursive file processing** - Traverse directories automatically
- ✅ **Smart exclusions** - Exclude directories and files with wildcard support
- ✅ **Flexible configuration** - Project-specific and system-wide configs
- ✅ **Interactive prompts** - Clean, colored terminal output
- ✅ **Progress tracking** - Visual progress bar for large operations
- ✅ **Allow overrides** - Include specific files even if they match exclusions
- ✅ **Two commands** - Use `collate` or `col8` (shorter alias)

## 📦 Installation

### Via Install Script (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/collate/main/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/YOUR_USERNAME/collate.git
cd collate
chmod +x install.sh
./install.sh
```

### Via Snap (Linux)

```bash
sudo snap install collate
```

### Via Homebrew (macOS/Linux)

```bash
brew tap YOUR_USERNAME/collate
brew install collate
```

## 🚀 Quick Start

```bash
# Initialize project configuration
collate init

# Combine files from a directory
collate ./src -o output.txt

# Use verbose mode
collate ./project -o combined.txt -v

# Use shorter alias
col8 . -o code.txt
```

## 📖 Usage

### Basic Commands

```bash
collate init                    # Create .collate/config.yaml
collate <path> -o <output>      # Combine files
collate uninit                  # Remove project config
collate --help                  # Show help
```

### Examples

```bash
# Combine source code for AI review
collate ./src -o review.txt

# Create daily snapshot
collate . -o snapshot-$(date +%Y%m%d).txt

# Combine with verbose output
collate ./project -o output.txt -v

# Use default output location
collate ./src
# Output: ./.temp/flat/output.txt
```

## ⚙️ Configuration

### Default Exclusions

When you run `collate init`, sensible defaults are created:

```yaml
exclude_dirs:
  - cache
  - logs
  - docs
  - .git
  - coverage
  - node_modules
  - __pycache__

exclude_files:
  - "*.log"
  - "*.md"
  - ".env"
```

### Custom Configuration

Edit `.collate/config.yaml`:

```yaml
# Exclude additional directories
exclude_dirs:
  - backup_*        # Wildcards supported!
  - temp

# Exclude file patterns
exclude_files:
  - "*.backup"
  - "test_*.py"

# Override exclusions (include despite matching exclude rules)
allow_dirs:
  - docs/api

allow_files:
  - "README.md"
```

### Pattern Support

**Directories:**

- `cache` - Simple name
- `cache/` - Trailing slash (auto-stripped)
- `./cache` - Leading ./ (auto-stripped)
- `cache_*` - Wildcard patterns ✨
- `temp*` - Prefix wildcards

**Files:**

- `*.log` - Extension wildcards
- `temp_*` - Prefix wildcards
- `*_backup.txt` - Suffix wildcards

## 📚 Documentation

- [Cheatsheet](CHEATSHEET.md) - Quick reference guide
- [Packaging Guide](PACKAGING.md) - Distribution instructions

## 🎯 Use Cases

### 1. AI Code Review

```bash
collate init
collate ./src -o code-review.txt
# Share with AI assistant
```

### 2. Project Documentation

```bash
# Include docs despite default exclusion
echo "allow_dirs:\n  - docs" >> .collate/config.yaml
collate . -o documentation.txt
```

### 3. Test Suite Export

```bash
# Only include test files
cat > .collate/config.yaml << 'EOF'
allow_files:
  - "test_*.py"
  - "*_test.js"
EOF
collate . -o tests.txt
```

### 4. Backend API Bundle

```bash
cat > .collate/config.yaml << 'EOF'
exclude_dirs:
  - frontend
  - public

allow_files:
  - "*.py"
  - "requirements.txt"
  - "Dockerfile"
EOF
collate . -o backend.txt
```

## 🔧 Development

### Run Tests

```bash
./verify_fixes.sh           # Comprehensive verification
./test_collate.sh           # Original test suite
./test_pattern_flexibility.sh  # Pattern testing
```

### Project Structure

```
collate/
├── collate.sh              # Main script
├── config.yaml             # Default system config
├── install.sh              # Installation script
├── uninstall.sh            # Uninstallation script
├── verify_fixes.sh         # Test suite
├── snapcraft.yaml          # Snap package config
├── README.md               # This file
├── CHEATSHEET.md           # Quick reference
├── PACKAGING.md            # Distribution guide
└── LICENSE                 # MIT license
```

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -am 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open a Pull Request

### Testing Your Changes

```bash
# Run all tests
./verify_fixes.sh

# Test specific functionality
./test_pattern_flexibility.sh

# Manual testing
./install.sh  # Install your modified version
collate init  # Test init
collate . -o test.txt  # Test combining
```

## 📝 Changelog

### v0.1.0 (2025-01-20)

- ✨ Initial release
- ✅ Recursive file combination
- ✅ Wildcard pattern support
- ✅ Project and system configs
- ✅ Interactive prompts
- ✅ Progress indicators
- ✅ Allow overrides

## 🐛 Troubleshooting

### "collate: command not found"

```bash
# Add ~/.local/bin to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Files not being excluded

```bash
# Check config syntax
cat .collate/config.yaml

# Test with verbose mode
collate . -o test.txt -v

# Enable debug mode
DEBUG_EXCLUDE=1 collate . -o test.txt 2>&1 | less
```

### Color codes showing as text

```bash
# Reinstall latest version
./install.sh
```

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

## 👤 Author

**Your Name**

- GitHub: [@YOUR_USERNAME](https://github.com/YOUR_USERNAME)
- Email: <devshittu@gmail.com>

## 🌟 Show Your Support

Give a ⭐️ if this project helped you!

## 📮 Feedback

Found a bug or have a feature request? [Open an issue](https://github.com/YOUR_USERNAME/collate/issues)!

---

Made with ❤️ for developers who love clean, combined code files
