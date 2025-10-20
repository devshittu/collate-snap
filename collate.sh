#!/bin/bash

# System-wide command: collate (alias: col8)
# VERSION: 3.0.0
# Combines files into a single output file with configurable exclusions.
# Supports project-specific configs (.collate/config.yaml) and system-wide settings (~/.collate/config.yaml).

# Configuration paths
SYSTEM_CONFIG="$HOME/.collate/config.yaml"
PROJECT_CONFIG=".collate/config.yaml"
DEFAULT_OUTPUT="./.temp/flat/output.txt"
VERSION="3.0.0"

# ANSI color codes
if [[ -t 1 ]]; then
    GREEN="\033[0;32m"
    RED="\033[0;31m"
    YELLOW="\033[0;33m"
    BLUE="\033[0;34m"
    CYAN="\033[0;36m"
    NC="\033[0m"
else
    GREEN=""
    RED=""
    YELLOW=""
    BLUE=""
    CYAN=""
    NC=""
fi

# Global arrays for configurations
declare -a SYSTEM_EXCLUDE_DIRS
declare -a SYSTEM_EXCLUDE_FILES
SYSTEM_EXCLUDE_DOT_DIRS_DEFAULT=true

declare -a PROJECT_EXCLUDE_DIRS
declare -a PROJECT_EXCLUDE_FILES
PROJECT_EXCLUDE_DOT_DIRS=""

declare -a PROJECT_ALLOW_DIRS
declare -a PROJECT_ALLOW_FILES

declare -a EXCLUDE_DIRS
declare -a EXCLUDE_FILES
declare -a ALLOW_DIRS
declare -a ALLOW_FILES
EXCLUDE_DOT_DIRS_FINAL=false

# Global variables
input_path_global=""
output_file_global=""
absolute_input_path_global=""
absolute_output_file_global=""
RECURSIVE_MODE=false
MAX_DEPTH=0
DRY_RUN=false
SHOW_STATS=false
INCLUDE_PATTERNS=()
MAX_FILE_SIZE=""

# --- Utility Functions ---

log_info() { echo -e "${GREEN}$1${NC}"; }
log_error() {
    local message="$1"
    local exit_code="${2:-1}"
    echo -e "${RED}Error: $message${NC}" >&2
    exit "$exit_code"
}
log_warning() { echo -e "${YELLOW}$1${NC}"; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${CYAN}[DEBUG] $1${NC}" >&2; }

has_extension() {
    local filename="$1"
    [[ "$filename" =~ \.[a-zA-Z0-9]+$ ]] && return 0 || return 1
}

# Format file size for display
format_size() {
    local size=$1
    if (( size < 1024 )); then
        echo "${size}B"
    elif (( size < 1048576 )); then
        echo "$((size / 1024))KB"
    else
        echo "$((size / 1048576))MB"
    fi
}

prompt_overwrite() {
    local output_file_path="$1"
    if [[ -f "$output_file_path" ]]; then
        log_warning "Output file '$output_file_path' already exists."
        
        local confirm
        if [[ -t 0 && -t 1 ]]; then
            echo -ne "${YELLOW}Overwrite? (y/N): ${NC}"
            read confirm
        else
            echo -n "Overwrite? (y/N): "
            read confirm
        fi
        
        if [[ ! "$confirm" =~ ^[yY]$ ]]; then
            log_error "Operation cancelled by user." 1
        fi
    fi
}

parse_yaml() {
    local file="$1"
    local prefix="$2"
    if [[ ! -f "$file" ]]; then
        return
    fi
    local current_key=""
    while IFS= read -r line; do
        line=$(echo "$line" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')
        [[ "$line" =~ ^# || -z "$line" ]] && continue
        
        if [[ "$line" =~ ^[a-zA-Z_]+: ]]; then
            current_key=$(echo "$line" | cut -d':' -f1 | tr -d ' ')
            local value=$(echo "$line" | cut -d':' -f2- | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')
            
            if [[ "$current_key" == "exclude_dot_dirs" ]]; then
                if [[ "$prefix" == "SYSTEM" ]]; then
                    SYSTEM_EXCLUDE_DOT_DIRS_DEFAULT="$value"
                else
                    PROJECT_EXCLUDE_DOT_DIRS="$value"
                fi
            fi
        elif [[ "$line" =~ ^-\  ]]; then
            local value=$(echo "$line" | sed 's/^- //')
            value=$(echo "$value" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/")
            if [[ "$current_key" == "exclude_dirs" || "$current_key" == "allow_dirs" ]]; then
                value="${value%/}"
                value="${value#./}"
            fi
            
            if [[ "$current_key" == "exclude_dirs" ]]; then
                if [[ "$prefix" == "SYSTEM" ]]; then
                    SYSTEM_EXCLUDE_DIRS+=("$value")
                else
                    PROJECT_EXCLUDE_DIRS+=("$value")
                fi
            elif [[ "$current_key" == "allow_dirs" ]]; then
                PROJECT_ALLOW_DIRS+=("$value")
            elif [[ "$current_key" == "exclude_files" ]]; then
                if [[ "$prefix" == "SYSTEM" ]]; then
                    SYSTEM_EXCLUDE_FILES+=("$value")
                else
                    PROJECT_EXCLUDE_FILES+=("$value")
                fi
            elif [[ "$current_key" == "allow_files" ]]; then
                PROJECT_ALLOW_FILES+=("$value")
            fi
        else
            current_key=""
        fi
    done < "$file"
}

load_config() {
    SYSTEM_EXCLUDE_DIRS=()
    SYSTEM_EXCLUDE_FILES=()
    SYSTEM_EXCLUDE_DOT_DIRS_DEFAULT=true
    PROJECT_EXCLUDE_DIRS=()
    PROJECT_EXCLUDE_FILES=()
    PROJECT_EXCLUDE_DOT_DIRS=""
    PROJECT_ALLOW_DIRS=()
    PROJECT_ALLOW_FILES=()

    parse_yaml "$SYSTEM_CONFIG" "SYSTEM"

    if [[ -f "$PROJECT_CONFIG" ]]; then
        parse_yaml "$PROJECT_CONFIG" "PROJECT"
    fi

    EXCLUDE_DIRS=("${SYSTEM_EXCLUDE_DIRS[@]}")
    for proj_dir in "${PROJECT_EXCLUDE_DIRS[@]}"; do
        EXCLUDE_DIRS+=("$proj_dir")
    done

    EXCLUDE_FILES=("${SYSTEM_EXCLUDE_FILES[@]}")
    for proj_file in "${PROJECT_EXCLUDE_FILES[@]}"; do
        EXCLUDE_FILES+=("$proj_file")
    done

    ALLOW_DIRS=("${PROJECT_ALLOW_DIRS[@]}")
    ALLOW_FILES=("${PROJECT_ALLOW_FILES[@]}")
    
    local dot_dirs_setting="${PROJECT_EXCLUDE_DOT_DIRS:-$SYSTEM_EXCLUDE_DOT_DIRS_DEFAULT}"
    [[ "$dot_dirs_setting" == "true" ]] && EXCLUDE_DOT_DIRS_FINAL=true || EXCLUDE_DOT_DIRS_FINAL=false
}

should_exclude() {
    local path="$1"
    local filename=$(basename "$path")
    
    log_debug "Checking: $path"
    
    if [[ "$path" == "$absolute_output_file_global" ]]; then
        log_debug "  -> EXCLUDED (output file)"
        return 0
    fi

    local relative_path="$path"
    if [[ "$path" == "$absolute_input_path_global/"* ]]; then
        relative_path="${path#$absolute_input_path_global/}"
    fi
    
    # Check against include patterns if specified
    if [[ ${#INCLUDE_PATTERNS[@]} -gt 0 ]]; then
        local matched=false
        for pattern in "${INCLUDE_PATTERNS[@]}"; do
            if [[ "$filename" == $pattern ]]; then
                matched=true
                break
            fi
        done
        if [[ "$matched" == false ]]; then
            log_debug "  -> EXCLUDED (doesn't match include patterns)"
            return 0
        fi
    fi
    
    # Check file size if max size specified
    if [[ -n "$MAX_FILE_SIZE" ]]; then
        local file_size=$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null)
        if [[ $file_size -gt $MAX_FILE_SIZE ]]; then
            log_debug "  -> EXCLUDED (file too large: $(format_size $file_size))"
            return 0
        fi
    fi
    
    # ALLOW_FILES has highest precedence
    for allowed_file_pattern in "${ALLOW_FILES[@]}"; do
        if [[ "$filename" == $allowed_file_pattern ]]; then
            log_debug "  -> ALLOWED (by allow_files)"
            return 1
        fi
    done

    # ALLOW_DIRS
    for allowed_dir_pattern in "${ALLOW_DIRS[@]}"; do
        allowed_dir_pattern="${allowed_dir_pattern%/}"
        allowed_dir_pattern="${allowed_dir_pattern#./}"
        
        local IFS='/'
        local -a path_parts=($relative_path)
        for part in "${path_parts[@]}"; do
            if [[ "$part" == $allowed_dir_pattern ]]; then
                log_debug "  -> ALLOWED (in allowed dir)"
                return 1
            fi
        done
        
        if [[ "$relative_path" == "$allowed_dir_pattern/"* ]]; then
            log_debug "  -> ALLOWED (starts with allowed dir)"
            return 1
        fi
    done

    # Check dot directories
    if [[ "$EXCLUDE_DOT_DIRS_FINAL" == true ]]; then
        local IFS='/'
        local -a path_parts=($relative_path)
        for part in "${path_parts[@]}"; do
            if [[ "$part" == .* && "$part" != "." && "$part" != ".." ]]; then
                log_debug "  -> EXCLUDED (dot directory)"
                return 0
            fi
        done
    fi

    # EXCLUDE_DIRS
    for excluded_dir_pattern in "${EXCLUDE_DIRS[@]}"; do
        excluded_dir_pattern="${excluded_dir_pattern%/}"
        excluded_dir_pattern="${excluded_dir_pattern#./}"
        
        local IFS='/'
        local -a path_parts=($relative_path)
        for part in "${path_parts[@]}"; do
            if [[ "$part" == $excluded_dir_pattern ]]; then
                log_debug "  -> EXCLUDED (dir match)"
                return 0
            fi
        done
        
        if [[ "$relative_path" == "$excluded_dir_pattern/"* ]]; then
            log_debug "  -> EXCLUDED (starts with excluded dir)"
            return 0
        fi
    done

    # EXCLUDE_FILES
    for excluded_file_pattern in "${EXCLUDE_FILES[@]}"; do
        if [[ "$filename" == $excluded_file_pattern ]]; then
            log_debug "  -> EXCLUDED (file match)"
            return 0
        fi
    done

    log_debug "  -> INCLUDED"
    return 1
}

show_progress() {
    local current="$1"
    local total="$2"
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    local bar=$(printf "%${filled}s" | tr ' ' '#')
    bar+=$(printf "%${empty}s" | tr ' ' '-')
    printf "\r${GREEN}Progress: %d%% (%d/%d files) [%s]${NC}" "$percent" "$current" "$total" "$bar"
}

# NEW: Show statistics about the operation
show_statistics() {
    local files_processed=$1
    local total_size=$2
    local output_file=$3
    
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          Collation Statistics          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}Files processed:${NC} $files_processed"
    echo -e "${CYAN}Total input size:${NC} $(format_size $total_size)"
    
    if [[ -f "$output_file" ]]; then
        local output_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null)
        echo -e "${CYAN}Output file size:${NC} $(format_size $output_size)"
        echo -e "${CYAN}Output location:${NC} $output_file"
    fi
    echo ""
}

flatten_files() {
    local input_path="$1"
    local output_file="$2"
    local verbose="$3"
    
    absolute_input_path_global=$(realpath -m "$input_path" 2>/dev/null)
    if [[ -z "$absolute_input_path_global" || (! -d "$absolute_input_path_global" && ! -f "$absolute_input_path_global") ]]; then
        log_error "Input path '$input_path' does not exist."
    fi
    input_path_global="$input_path"

    local output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir" || log_error "Failed to create output directory: $output_dir"

    absolute_output_file_global=$(realpath -m "$output_file" 2>/dev/null)
    output_file_global="$output_file"

    if [[ "$DRY_RUN" == false ]]; then
        prompt_overwrite "$output_file"
        : > "$output_file" || log_error "Failed to create/write to output file: $output_file"
    fi

    local all_files_found=()
    
    # NEW: Different behavior for recursive vs non-recursive
    if [[ "$RECURSIVE_MODE" == true ]]; then
        if [[ "$MAX_DEPTH" -gt 0 ]]; then
            log_debug "Searching recursively with max depth: $MAX_DEPTH"
            while IFS= read -r -d '' f; do
                all_files_found+=("$f")
            done < <(find "$absolute_input_path_global" -maxdepth "$MAX_DEPTH" -type f -print0 2>/dev/null)
        else
            log_debug "Searching recursively (unlimited depth)"
            while IFS= read -r -d '' f; do
                all_files_found+=("$f")
            done < <(find "$absolute_input_path_global" -type f -print0 2>/dev/null)
        fi
    else
        log_debug "Searching non-recursively (current level only)"
        # Non-recursive: only files in the immediate directory
        if [[ -d "$absolute_input_path_global" ]]; then
            while IFS= read -r -d '' f; do
                all_files_found+=("$f")
            done < <(find "$absolute_input_path_global" -maxdepth 1 -type f -print0 2>/dev/null)
        elif [[ -f "$absolute_input_path_global" ]]; then
            all_files_found+=("$absolute_input_path_global")
        fi
    fi

    local files_to_process=()
    local total_size=0
    
    for file_abs_path in "${all_files_found[@]}"; do
        if ! should_exclude "$file_abs_path"; then
            files_to_process+=("$file_abs_path")
            if [[ -f "$file_abs_path" ]]; then
                local file_size=$(stat -f%z "$file_abs_path" 2>/dev/null || stat -c%s "$file_abs_path" 2>/dev/null)
                total_size=$((total_size + file_size))
            fi
        fi
    done

    local total_files_to_process=${#files_to_process[@]}
    if [[ "$total_files_to_process" -eq 0 ]]; then
        log_error "No files found to process after applying exclusions. Check input path or configuration."
    fi

    # DRY RUN: Just list files without combining
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}DRY RUN - Files that would be processed:${NC}"
        echo ""
        for file_path in "${files_to_process[@]}"; do
            local file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null)
            echo -e "${CYAN}$(format_size $file_size)${NC}\t$file_path"
        done
        echo ""
        echo -e "${YELLOW}Total: $total_files_to_process files, $(format_size $total_size)${NC}"
        return 0
    fi

    local processed_count=0
    local current_wd=$(pwd)

    for file_absolute_path in "${files_to_process[@]}"; do
        ((processed_count++))
        
        local path_in_header=""
        local abs_input_path_dir=$(realpath -m "$input_path_global" 2>/dev/null)
        
        if [[ "$file_absolute_path" == "$abs_input_path_dir/"* ]]; then
            path_in_header="${input_path_global}/${file_absolute_path#$abs_input_path_dir/}"
        elif [[ "$file_absolute_path" == "$current_wd/"* ]]; then
            path_in_header="${file_absolute_path#$current_wd/}"
        else
            if [[ "$file_absolute_path" == /* ]]; then
                 path_in_header="${file_absolute_path#$current_wd/}"
                 if [[ "$path_in_header" == "$file_absolute_path" ]]; then
                     path_in_header=$(basename "$file_absolute_path")
                 fi
            else
                path_in_header="$file_absolute_path"
            fi
        fi

        if [[ -f "$absolute_input_path_global" && "$file_absolute_path" == "$absolute_input_path_global" ]]; then
            path_in_header=$(basename "$input_path_global")
        fi

        [[ "$verbose" == "true" ]] && log_info "Processed: $path_in_header (Full path: $file_absolute_path)"
        [[ "$verbose" != "true" ]] && show_progress "$processed_count" "$total_files_to_process"

        {
            echo "===== FILE: $path_in_header ====="
            cat "$file_absolute_path" 2>/dev/null || log_error "Failed to read file: $file_absolute_path"
            echo -e "\n===== END: $path_in_header =====\n"
        } >> "$output_file" || log_error "Failed to append to output file: $output_file"
    done

    [[ "$verbose" != "true" ]] && echo ""
    
    if [[ ! -s "$output_file" ]]; then
        log_error "No content was written to '$output_file'. This might indicate an issue with file processing."
    fi

    log_info "Files combined successfully into '$output_file'"
    
    # Show statistics if requested
    if [[ "$SHOW_STATS" == true ]]; then
        show_statistics "$processed_count" "$total_size" "$output_file"
    fi
}

usage() {
    echo -e "${GREEN}collate v${VERSION} - Combine files into a single output file${NC}"
    echo "Usage: collate <command> [options]"
    echo "       col8 <command> [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  init                Initialize .collate directory with config.yaml"
    echo "  uninit              Remove .collate directory and its contents"
    echo "  list                List files that would be processed (dry run)"
    echo "  <path>              Combine files from path"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  -o, --output <file>     Specify output file (default: $DEFAULT_OUTPUT)"
    echo "  -r, --recursive         Enable recursive directory traversal"
    echo "  -d, --depth <n>         Max recursion depth (requires -r)"
    echo "  -i, --include <pattern> Only include files matching pattern (can specify multiple)"
    echo "  -s, --max-size <size>   Skip files larger than size (e.g., 1M, 500K)"
    echo "  -v, --verbose           Show detailed progress"
    echo "  -n, --dry-run           Show what would be processed without combining"
    echo "  --stats                 Show statistics after completion"
    echo "  --debug                 Enable debug output"
    echo "  --version               Show version information"
    echo "  --help                  Show this help message"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  ${CYAN}# Non-recursive (default) - only current directory${NC}"
    echo "  collate ./src -o output.txt"
    echo ""
    echo -e "  ${CYAN}# Recursive - include subdirectories${NC}"
    echo "  collate ./src -r -o output.txt"
    echo "  collate ./src -ro output.txt          # Combined flags"
    echo ""
    echo -e "  ${CYAN}# Recursive with max depth${NC}"
    echo "  collate . -r -d 2 -o output.txt"
    echo ""
    echo -e "  ${CYAN}# Include only specific files${NC}"
    echo "  collate . -r -i \"*.py\" -i \"*.js\" -o code.txt"
    echo ""
    echo -e "  ${CYAN}# Skip large files${NC}"
    echo "  collate . -r -s 1M -o output.txt"
    echo ""
    echo -e "  ${CYAN}# Dry run to see what would be processed${NC}"
    echo "  collate . -r --dry-run"
    echo "  collate . -rn                         # Combined flags"
    echo ""
    echo -e "  ${CYAN}# With statistics${NC}"
    echo "  collate ./src -r -o output.txt --stats"
    echo ""
    echo -e "  ${CYAN}# List files without combining${NC}"
    echo "  collate list ./src -r"
    echo ""
    echo -e "${YELLOW}Notes:${NC}"
    echo "  • Non-recursive is now the default (use -r for old behavior)"
    echo "  • Flags can be combined: -nr = -n -r, -rv = -r -v"
    echo "  • Exclude/allow rules from config still apply"
    echo "  • Use DEBUG=1 for verbose exclusion logging"
    echo ""
    echo "Run 'collate <command> --help' for command-specific help."
    exit 0
}

show_version() {
    echo -e "${GREEN}collate${NC} version ${CYAN}${VERSION}${NC}"
    echo "A smart file combination utility"
    echo ""
    echo -e "${YELLOW}Features:${NC}"
    echo "  ✓ Non-recursive by default (explicit -r flag)"
    echo "  ✓ Configurable exclusions with wildcards"
    echo "  ✓ Project and system-wide configs"
    echo "  ✓ Include pattern filtering"
    echo "  ✓ File size limits"
    echo "  ✓ Dry run mode"
    echo "  ✓ Statistics reporting"
    echo ""
    echo "License: MIT"
    exit 0
}

list_command() {
    shift # Remove 'list' from arguments
    DRY_RUN=true
    # Parse remaining arguments as if running collate
}

init_help() {
    echo -e "${GREEN}collate init - Initialize project-specific configuration${NC}"
    echo "Usage: collate init [--help]"
    echo ""
    echo "Initializes a .collate directory with a config.yaml file in the current directory."
    echo ""
    echo -e "${YELLOW}Example:${NC}"
    echo "  collate init        Creates .collate/config.yaml"
    exit 0
}

uninit_help() {
    echo -e "${GREEN}collate uninit - Remove project-specific configuration${NC}"
    echo "Usage: collate uninit [--help]"
    echo ""
    echo "Removes the .collate directory and its contents from the current directory."
    echo ""
    echo -e "${YELLOW}Example:${NC}"
    echo "  collate uninit      Removes .collate/"
    exit 0
}

init_project() {
    if [[ "$1" == "--help" ]]; then
        init_help
    fi
    if [[ -d ".collate" ]]; then
        log_error ".collate directory already exists in $(pwd)"
    fi

    mkdir -p ".collate" || log_error "Failed to create .collate directory"

    local system_excludes=""
    if [[ -f "$SYSTEM_CONFIG" ]]; then
        system_excludes=$(grep -E 'exclude_dirs:|exclude_files:|exclude_dot_dirs:' "$SYSTEM_CONFIG" | \
                          sed -E 's/^(exclude_dirs|exclude_files|exclude_dot_dirs):/# From system config: \1:/g; s/^- /#  - /g')
        system_excludes+=$(grep -E '^[[:space:]]*- ' "$SYSTEM_CONFIG" | \
                           sed 's/^[[:space:]]*- /#  - /g')
    fi

    cat << EOF > ".collate/config.yaml"
# Project-specific configuration for collate v${VERSION}
# Appends to system-wide settings at ~/.collate/config.yaml
# System-wide exclusions (for reference, these are applied automatically):
$system_excludes

# Directories to exclude (add to system-wide exclusions)
exclude_dirs:
  - cache
  - logs
  - docs
  - .git
  - coverage
  - node_modules
  - data

# Files to exclude (add to system-wide exclusions)
exclude_files:
  - "*.log"
  - "*.md"
  - ".env"
  - ".env.*"

# Override exclusions (highest priority)
# allow_dirs:
#   - docs/api
# allow_files:
#   - "README.md"

# Exclude dot directories (true/false)
# exclude_dot_dirs: true
EOF

    if [[ ! -f ".collate/config.yaml" ]]; then
        log_error "Failed to create .collate/config.yaml"
    fi

    log_info ".collate directory initialized with config.yaml"
    exit 0
}

uninit_project() {
    if [[ "$1" == "--help" ]]; then
        uninit_help
    fi
    if [[ ! -d ".collate" ]]; then
        log_error ".collate directory does not exist in $(pwd)" 1
    fi

    local confirm
    if [[ -t 0 && -t 1 ]]; then
        log_warning "This will remove the .collate directory and its contents."
        echo -ne "${YELLOW}Proceed? (y/N): ${NC}"
        read confirm
        if [[ ! "$confirm" =~ ^[yY]$ ]]; then
            log_error "Operation cancelled by user." 1
        fi
    else
        log_info "Non-interactive session: Automatically proceeding with .collate directory removal."
        confirm="y"
    fi

    rm -rf ".collate" || log_error "Failed to remove .collate directory" 1
    log_info ".collate directory removed successfully"
    exit 0
}

# --- Main Script Logic ---

load_config

if [[ $# -eq 0 ]]; then
    usage
fi

COMMAND="$1"

case "$COMMAND" in
    init)
        shift
        init_project "$@"
        ;;
    uninit)
        shift
        uninit_project "$@"
        ;;
    list)
        shift
        DRY_RUN=true
        ;;
    --help|-h)
        usage
        ;;
    --version)
        show_version
        ;;
    *)
        # Not a command, treat as input path
        ;;
esac

# Parse options for combine operation
INPUT_PATH=""
OUTPUT_FILE_OPT_PROVIDED=false

# Reset OPTIND for this parsing session
OPTIND=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            OUTPUT_FILE="$2"
            OUTPUT_FILE_OPT_PROVIDED=true
            shift 2
            ;;
        -r|--recursive)
            RECURSIVE_MODE=true
            shift
            ;;
        -d|--depth)
            MAX_DEPTH="$2"
            if [[ ! "$MAX_DEPTH" =~ ^[0-9]+$ ]]; then
                log_error "Depth must be a positive integer"
            fi
            shift 2
            ;;
        -i|--include)
            INCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        -s|--max-size)
            local size_arg="$2"
            # Convert size to bytes
            if [[ "$size_arg" =~ ^([0-9]+)([KMG]?)$ ]]; then
                local num="${BASH_REMATCH[1]}"
                local unit="${BASH_REMATCH[2]}"
                case "$unit" in
                    K) MAX_FILE_SIZE=$((num * 1024)) ;;
                    M) MAX_FILE_SIZE=$((num * 1048576)) ;;
                    G) MAX_FILE_SIZE=$((num * 1073741824)) ;;
                    *) MAX_FILE_SIZE=$num ;;
                esac
            else
                log_error "Invalid size format. Use: 1M, 500K, 1G, or plain bytes"
            fi
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --stats)
            SHOW_STATS=true
            shift
            ;;
        --debug)
            DEBUG=1
            shift
            ;;
        --help|-h)
            usage
            ;;
        --version)
            show_version
            ;;
        # Handle combined single-letter flags (e.g., -nr, -rv, -rnv)
        -[rnv]*)
            # Extract the flag without the leading dash
            local flags="${1#-}"
            # Process each character
            for (( i=0; i<${#flags}; i++ )); do
                case "${flags:$i:1}" in
                    r) RECURSIVE_MODE=true ;;
                    n) DRY_RUN=true ;;
                    v) VERBOSE=true ;;
                    *)
                        log_error "Unknown flag in combined option: -${flags:$i:1}"
                        ;;
                esac
            done
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            ;;
        *)
            if [[ -z "$INPUT_PATH" ]]; then
                INPUT_PATH="$1"
            fi
            shift
            ;;
    esac
done

# Validate depth flag
if [[ "$MAX_DEPTH" -gt 0 && "$RECURSIVE_MODE" == false ]]; then
    log_error "Depth flag (-d) requires recursive mode (-r)"
fi

# Set default input path if not provided
if [[ -z "$INPUT_PATH" ]]; then
    INPUT_PATH="."
fi

# Determine output file
if [[ "$OUTPUT_FILE_OPT_PROVIDED" == false && "$DRY_RUN" == false ]]; then
    if [[ -t 0 && -t 1 ]]; then
        echo -ne "${YELLOW}Warning: No output file specified via -o option. Enter desired output file path (or press Enter for default: ${DEFAULT_OUTPUT}): ${NC}"
        read input_for_output
        OUTPUT_FILE="${input_for_output:-$DEFAULT_OUTPUT}"
    else
        echo "Warning: No output file specified via -o option. Using default: ${DEFAULT_OUTPUT}" >&2
        OUTPUT_FILE="$DEFAULT_OUTPUT"
    fi
fi

# Add extension if missing
if [[ "$DRY_RUN" == false ]]; then
    if ! has_extension "$OUTPUT_FILE"; then
        if [[ -t 1 ]]; then
            log_warning "Output file '$OUTPUT_FILE' has no extension. Using .txt extension."
        else
            echo "Warning: Output file '$OUTPUT_FILE' has no extension. Using .txt extension." >&2
        fi
        OUTPUT_FILE="${OUTPUT_FILE}.txt"
    fi
fi

: "${VERBOSE:=false}"

# Run the combine operation
flatten_files "$INPUT_PATH" "$OUTPUT_FILE" "$VERBOSE"