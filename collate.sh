#!/bin/bash

# System-wide command: collate (alias: col8)
# Combines files recursively into a single output file with configurable exclusions.
# Supports project-specific configs (.collate/config.yaml) and system-wide settings (/etc/collate/config.yaml).
# Commands: init (initialize project config), uninit (remove project config), <path> (combine files).

# Configuration paths
SYSTEM_CONFIG="/etc/collate/config.yaml"
PROJECT_CONFIG=".collate/config.yaml"
DEFAULT_OUTPUT="./temp/flat/output.txt"

# ANSI color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color

# Function to display usage
usage() {
    cat << EOF
${GREEN}collate - Combine files recursively into a single output file${NC}
Usage: collate <command> [options]
       col8 <command> [options]

${YELLOW}Commands:${NC}
  init                Initialize .collate directory with config.yaml
  uninit              Remove .collate directory and its contents
  <relative_path>     Combine files from relative_path

${YELLOW}Options (for combine):${NC}
  -o <output_file>    Specify output file (default: $DEFAULT_OUTPUT)
  -v                  Enable verbose output
  --help              Show this help message

${YELLOW}Examples:${NC}
  collate ./my_folder -o output.txt    Combine files into output.txt
  col8 init                           Initialize project-specific config
  collate uninit                       Remove project-specific config
  col8 ./my_folder -v                 Combine with verbose output
  collate init --help                  Show help for init command

Run 'collate <command> --help' or 'col8 <command> --help' for command-specific help.
EOF
    exit 0
}

# Function to display init-specific help
init_help() {
    cat << EOF
${GREEN}collate init - Initialize project-specific configuration${NC}
Usage: collate init [--help]
       col8 init [--help]

Initializes a .collate directory with a config.yaml file in the current directory.
The config.yaml appends to system-wide settings at /etc/collate/config.yaml.

${YELLOW}Options:${NC}
  --help              Show this help message

${YELLOW}Example:${NC}
  collate init        Creates .collate/config.yaml
  col8 init           Creates .collate/config.yaml
EOF
    exit 0
}

# Function to display uninit-specific help
uninit_help() {
    cat << EOF
${GREEN}collate uninit - Remove project-specific configuration${NC}
Usage: collate uninit [--help]
       col8 uninit [--help]

Removes the .collate directory and its contents from the current directory.

${YELLOW}Options:${NC}
  --help              Show this help message

${YELLOW}Example:${NC}
  collate uninit      Removes .collate/
  col8 uninit         Removes .collate/
EOF
    exit 0
}

# Function to log messages (info, error, warning)
log_info() { echo -e "${GREEN}$1${NC}"; }
log_error() { echo -e "${RED}Error: $1${NC}" >&2; exit 1; }
log_warning() { echo -e "${YELLOW}Warning: $1${NC}"; }

# Function to check if a file has a valid extension
has_extension() {
    local filename="$1"
    [[ "$filename" =~ \.[a-zA-Z0-9]+$ ]] && return 0 || return 1
}

# Function to prompt for overwrite confirmation
prompt_overwrite() {
    local output_file="$1"
    if [[ -f "$output_file" && -t 1 ]]; then
        log_warning "Output file '$output_file' already exists."
        read -p "${YELLOW}Overwrite? (y/N): ${NC}" confirm
        if [[ ! "$confirm" =~ ^[yY]$ ]]; then
            log_error "Operation cancelled by user."
        fi
    fi
}

# Function to parse YAML (simple key-value parser for shell)
parse_yaml() {
    local file="$1"
    local prefix="$2" # SYSTEM or PROJECT
    if [[ ! -f "$file" ]]; then
        return
    fi
    local current_key=""
    while IFS=': ' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^# || -z "$key" ]] && continue
        # Handle array items
        if [[ "$key" =~ ^- ]]; then
 ව
            if [[ "$current_key" == "exclude_dirs" || "$current_key" == "allow_dirs" ]]; then
                value=$(echo "$key" | sed 's/^- //')
                if [[ "$current_key" == "exclude_dirs" ]]; then
                    if [[ "$prefix" == "SYSTEM" ]]; then
                        SYSTEM_EXCLUDE_DIRS+=("$value")
                    else
                        PROJECT_EXCLUDE_DIRS+=("$value")
                    fi
                elif [[ "$current_key" == "allow_dirs" ]]; then
                    PROJECT_ALLOW_DIRS+=("$value")
                fi
            elif [[ "$current_key" == "exclude_files" || "$current_key" == "allow_files" ]]; then
                value=$(echo "$key" | sed 's/^- //')
                if [[ "$current_key" == "exclude_files" ]]; then
                    if [[ "$prefix" == "SYSTEM" ]]; then
                        SYSTEM_EXCLUDE_FILES+=("$value")
                    else
                        PROJECT_EXCLUDE_FILES+=("$value")
                    fi
                elif [[ "$current_key" == "allow_files" ]]; then
                    PROJECT_ALLOW_FILES+=("$value")
                fi
            fi
        else
            current_key="$key"
            if [[ "$current_key" == "exclude_dot_dirs" ]]; then
                if [[ "$prefix" == "SYSTEM" ]]; then
                    SYSTEM_EXCLUDE_DOT_DIRS="$value"
                else
                    PROJECT_EXCLUDE_DOT_DIRS="$value"
                fi
            fi
        fi
    done < <(grep -E '^[a-zA-Z_]+:|^-' "$file" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')
}

# Function to load configurations
load_config() {
    # Default values
    SYSTEM_EXCLUDE_DIRS=()
    SYSTEM_EXCLUDE_FILES=()
    SYSTEM_EXCLUDE_DOT_DIRS=true
    PROJECT_EXCLUDE_DIRS=()
    PROJECT_EXCLUDE_FILES=()
    PROJECT_EXCLUDE_DOT_DIRS=""
    PROJECT_ALLOW_DIRS=()
    PROJECT_ALLOW_FILES=()

    # Load system-wide config
    parse_yaml "$SYSTEM_CONFIG" "SYSTEM"

    # Load project-specific config if present
    if [[ -f "$PROJECT_CONFIG" ]]; then
        parse_yaml "$PROJECT_CONFIG" "PROJECT"
    fi

    # Combine configurations (project appends to system)
    EXCLUDE_DIRS=("${SYSTEM_EXCLUDE_DIRS[@]}" "${PROJECT_EXCLUDE_DIRS[@]}")
    EXCLUDE_FILES=("${SYSTEM_EXCLUDE_FILES[@]}" "${PROJECT_EXCLUDE_FILES[@]}")
    ALLOW_DIRS=("${PROJECT_ALLOW_DIRS[@]}")
    ALLOW_FILES=("${PROJECT_ALLOW_FILES[@]}")
    EXCLUDE_DOT_DIRS=${PROJECT_EXCLUDE_DOT_DIRS:-$SYSTEM_EXCLUDE_DOT_DIRS}
}

# Function to initialize .collate directory
init_project() {
    if [[ "$1" == "--help" ]]; then
        init_help
    fi
    if [[ -d ".collate" ]]; then
        log_error ".collate directory already exists in $(pwd)"
    fi

    mkdir -p ".collate" || log_error "Failed to create .collate directory"

    # Create config.yaml with system-wide exclusions as comments
    local system_excludes=""
    if [[ -f "$SYSTEM_CONFIG" ]]; then
        system_excludes=$(grep -E 'exclude_dirs|exclude_files' "$SYSTEM_CONFIG" | sed 's/^/# From system config: /')
    fi
    cat << EOF > ".collate/config.yaml"
# Project-specific configuration for collate
# Appends to system-wide settings at /etc/collate/config.yaml
# System-wide exclusions (for reference, these are applied automatically):
$system_excludes

# Directories to exclude (add to system-wide exclusions)
exclude_dirs:
  - cache
  - build

# Files to exclude (add to system-wide exclusions)
exclude_files:
  - "*.log"
  - "*.o"

# Directories or files to allow (overrides system-wide exclusions)
allow_dirs:
  - .git
allow_files:
  - ".gitignore"

# Exclude directories starting with a dot (true/false, defaults to system-wide)
# exclude_dot_dirs: true
EOF

    if [[ ! -f ".collate/config.yaml" ]]; then
        log_error "Failed to create .collate/config.yaml"
    fi

    log_info ".collate directory initialized with config.yaml"
    exit 0
}

# Function to remove .collate directory
uninit_project() {
    if [[ "$1" == "--help" ]]; then
        uninit_help
    fi
    if [[ ! -d ".collate" ]]; then
        log_error ".collate directory does not exist in $(pwd)"
    fi

    if [[ -t 1 ]]; then
        log_warning "This will remove the .collate directory and its contents."
        read -p "${YELLOW}Proceed? (y/N): ${NC}" confirm
        if [[ ! "$confirm" =~ ^[yY]$ ]]; then
            log_error "Operation cancelled by user."
        fi
    fi

    rm -rf ".collate" || log_error "Failed to remove .collate directory"
    log_info ".collate directory removed successfully"
    exit 0
}

# Function to display progress bar
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

# Function to flatten files
flatten_files() {
    local input_path="$1"
    local output_file="$2"
    local verbose="$3"

    # Resolve the input path to absolute
    input_path=$(realpath -m "$input_path" 2>/dev/null) || log_error "Failed to resolve path: $input_path"
    if [[ ! -d "$input_path" && ! -f "$input_path" ]]; then
        log_error "Input path does not exist: $input_path"
    fi

    # Ensure output directory exists
    local output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir" || log_error "Failed to create output directory: $output_dir"

    # Check for existing output file and prompt for overwrite
    prompt_overwrite "$output_file"

    # Clear or create the output file
    : > "$output_file" || log_error "Failed to create/write to output file: $output_file"

    # Count total files for progress
    local total_files=$(find "$input_path" -type f -print0 2>/dev/null | grep -zc .)
    [[ $total_files -eq 0 ]] && log_error "No files found in $input_path. Check exclusions or path."

    local current_file=0
    # Process files
    while IFS= read -r -d '' file; do
        # Skip if file or its parent directories should be excluded
        if should_exclude "$file"; then
            continue
        fi

        # Skip directories
        if [[ -d "$file" ]]; then
            continue
        fi

        # Update progress
        ((current_file++))
        [[ "$verbose" == "true" ]] && log_info "Processed: $file"
        [[ "$verbose" != "true" ]] && show_progress "$current_file" "$total_files"

        # Append file path and content to output
        {
            echo "===== FILE: $file ====="
            cat "$file" 2>/dev/null || log_error "Failed to read file: $file"
            echo -e "\n===== END: $file =====\n"
        } >> "$output_file" || log_error "Failed to append to output file: $output_file"
    done < <(find "$input_path" -type f -print0 2>/dev/null)

    [[ "$verbose" != "true" ]] && echo "" # Newline after progress bar
    if [[ ! -s "$output_file" ]]; then
        log_error "No files were processed. Check exclusions or input path."
    fi

    log_info "Files combined successfully into $output_file"
}

# Main script
if [[ $# -eq 0 ]]; then
    usage
fi

# Parse command
COMMAND="$1"
shift

case "$COMMAND" in
    init)
        init_project "$@"
        ;;
    uninit)
        uninit_project "$@"
        ;;
    --help)
        usage
        ;;
    *)
        # Treat command as input path for combining
        INPUT_PATH="$COMMAND"
        OUTPUT_FILE="$DEFAULT_OUTPUT"
        VERBOSE=false

        # Parse options
        while getopts "o:v" opt; do
            case $opt in
                o)
                    OUTPUT_FILE="$OPTARG"
                    ;;
                v)
                    VERBOSE=true
                    ;;
                \?)
                    usage
                    ;;
            esac
        done

        # Interactive prompt for output file if not provided and terminal is interactive
        if [[ -z "$OUTPUT_FILE" && -t 1 ]]; then
            read -p "${YELLOW}No output file specified. Enter output file path (default: $DEFAULT_OUTPUT): ${NC}" input
            OUTPUT_FILE="${input:-$DEFAULT_OUTPUT}"
        fi

        # Validate output file extension
        if ! has_extension "$OUTPUT_FILE"; then
            log_warning "Output file '$OUTPUT_FILE' has no extension. Using .txt extension."
            OUTPUT_FILE="${OUTPUT_FILE}.txt"
        fi

        # Load configurations
        load_config

        # Run the combine operation
        flatten_files "$INPUT_PATH" "$OUTPUT_FILE" "$VERBOSE"
        ;;
esac

# collate.sh