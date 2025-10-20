#!/bin/bash

# System-wide command: collate (alias: col8)
# Combines files recursively into a single output file with configurable exclusions.
# Supports project-specific configs (.collate/config.yaml) and system-wide settings (~/.collate/config.yaml).
# Commands: init (initialize project config), uninit (remove project config), <path> (combine files).

# Configuration paths
SYSTEM_CONFIG="$HOME/.collate/config.yaml"
PROJECT_CONFIG=".collate/config.yaml"
DEFAULT_OUTPUT="./.temp/flat/output.txt"

# ANSI color codes - Conditionally set based on terminal interactivity
if [[ -t 1 ]]; then
    GREEN="\033[0;32m"
    RED="\033[0;31m"
    YELLOW="\033[0;33m"
    NC="\033[0m"
else
    GREEN=""
    RED=""
    YELLOW=""
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

# Global variables for input and output paths
input_path_global=""
output_file_global=""
absolute_input_path_global=""
absolute_output_file_global=""

# --- Utility Functions ---

log_info() { echo -e "${GREEN}$1${NC}"; }
log_error() {
    local message="$1"
    local exit_code="${2:-1}"
    echo -e "${RED}Error: $message${NC}" >&2
    exit "$exit_code"
}
log_warning() { echo -e "${YELLOW}$1${NC}"; }

has_extension() {
    local filename="$1"
    [[ "$filename" =~ \.[a-zA-Z0-9]+$ ]] && return 0 || return 1
}

# FIXED: Proper color handling in prompts
prompt_overwrite() {
    local output_file_path="$1"
    if [[ -f "$output_file_path" ]]; then
        log_warning "Output file '$output_file_path' already exists."
        
        local confirm
        if [[ -t 0 && -t 1 ]]; then
            # Interactive terminal - use echo for color, then read
            echo -ne "${YELLOW}Overwrite? (y/N): ${NC}"
            read confirm
        else
            # Non-interactive - plain text only
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
            # Remove surrounding quotes from patterns
            value=$(echo "$value" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/")
            # Normalize directory patterns - remove trailing slash and leading ./
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
    local dirname_part=$(dirname "$path")
    
    if [[ "${DEBUG_EXCLUDE:-0}" == "1" ]]; then
        echo "[DEBUG] Checking: $path" >&2
        echo "[DEBUG]   filename: $filename" >&2
    fi
    
    if [[ "$path" == "$absolute_output_file_global" ]]; then
        [[ "${DEBUG_EXCLUDE:-0}" == "1" ]] && echo "[DEBUG]   -> EXCLUDED (output file)" >&2
        return 0
    fi

    local relative_path="$path"
    if [[ "$path" == "$absolute_input_path_global/"* ]]; then
        relative_path="${path#$absolute_input_path_global/}"
    fi
    
    [[ "${DEBUG_EXCLUDE:-0}" == "1" ]] && echo "[DEBUG]   relative_path: $relative_path" >&2
    
    if [[ "${DEBUG_EXCLUDE:-0}" == "1" && ${#ALLOW_FILES[@]} -gt 0 ]]; then
        echo "[DEBUG]   Checking ALLOW_FILES: ${ALLOW_FILES[*]}" >&2
    fi
    
    for allowed_file_pattern in "${ALLOW_FILES[@]}"; do
        if [[ "${DEBUG_EXCLUDE:-0}" == "1" ]]; then
            echo "[DEBUG]     Testing pattern: '$allowed_file_pattern' against '$filename'" >&2
        fi
        if [[ "$filename" == $allowed_file_pattern ]]; then
            [[ "${DEBUG_EXCLUDE:-0}" == "1" ]] && echo "[DEBUG]   -> ALLOWED (by allow_files)" >&2
            return 1
        fi
    done

    if [[ "${DEBUG_EXCLUDE:-0}" == "1" && ${#ALLOW_DIRS[@]} -gt 0 ]]; then
        echo "[DEBUG]   Checking ALLOW_DIRS: ${ALLOW_DIRS[*]}" >&2
    fi
    
    for allowed_dir_pattern in "${ALLOW_DIRS[@]}"; do
        allowed_dir_pattern="${allowed_dir_pattern%/}"
        allowed_dir_pattern="${allowed_dir_pattern#./}"
        
        local IFS='/'
        local -a path_parts=($relative_path)
        for part in "${path_parts[@]}"; do
            if [[ "$part" == $allowed_dir_pattern ]]; then
                [[ "${DEBUG_EXCLUDE:-0}" == "1" ]] && echo "[DEBUG]   -> ALLOWED (in allowed dir: $allowed_dir_pattern)" >&2
                return 1
            fi
        done
        
        if [[ "$relative_path" == "$allowed_dir_pattern/"* ]]; then
            [[ "${DEBUG_EXCLUDE:-0}" == "1" ]] && echo "[DEBUG]   -> ALLOWED (starts with allowed dir: $allowed_dir_pattern)" >&2
            return 1
        fi
    done

    if [[ "$EXCLUDE_DOT_DIRS_FINAL" == true ]]; then
        [[ "${DEBUG_EXCLUDE:-0}" == "1" ]] && echo "[DEBUG]   Checking dot directories..." >&2
        local IFS='/'
        local -a path_parts=($relative_path)
        for part in "${path_parts[@]}"; do
            if [[ "$part" == .* && "$part" != "." && "$part" != ".." ]]; then
                [[ "${DEBUG_EXCLUDE:-0}" == "1" ]] && echo "[DEBUG]   -> EXCLUDED (dot directory: $part)" >&2
                return 0
            fi
        done
    fi

    if [[ "${DEBUG_EXCLUDE:-0}" == "1" && ${#EXCLUDE_DIRS[@]} -gt 0 ]]; then
        echo "[DEBUG]   Checking EXCLUDE_DIRS: ${EXCLUDE_DIRS[*]}" >&2
    fi
    
    for excluded_dir_pattern in "${EXCLUDE_DIRS[@]}"; do
        excluded_dir_pattern="${excluded_dir_pattern%/}"
        excluded_dir_pattern="${excluded_dir_pattern#./}"
        
        local IFS='/'
        local -a path_parts=($relative_path)
        for part in "${path_parts[@]}"; do
            if [[ "$part" == $excluded_dir_pattern ]]; then
                [[ "${DEBUG_EXCLUDE:-0}" == "1" ]] && echo "[DEBUG]   -> EXCLUDED (dir match: $excluded_dir_pattern)" >&2
                return 0
            fi
        done
        
        if [[ "$relative_path" == "$excluded_dir_pattern/"* ]]; then
            [[ "${DEBUG_EXCLUDE:-0}" == "1" ]] && echo "[DEBUG]   -> EXCLUDED (starts with dir: $excluded_dir_pattern)" >&2
            return 0
        fi
    done

    if [[ "${DEBUG_EXCLUDE:-0}" == "1" && ${#EXCLUDE_FILES[@]} -gt 0 ]]; then
        echo "[DEBUG]   Checking EXCLUDE_FILES: ${EXCLUDE_FILES[*]}" >&2
    fi
    
    for excluded_file_pattern in "${EXCLUDE_FILES[@]}"; do
        if [[ "${DEBUG_EXCLUDE:-0}" == "1" ]]; then
            echo "[DEBUG]     Testing pattern: '$excluded_file_pattern' against '$filename'" >&2
        fi
        if [[ "$filename" == $excluded_file_pattern ]]; then
            [[ "${DEBUG_EXCLUDE:-0}" == "1" ]] && echo "[DEBUG]   -> EXCLUDED (file match: $excluded_file_pattern)" >&2
            return 0
        fi
    done

    [[ "${DEBUG_EXCLUDE:-0}" == "1" ]] && echo "[DEBUG]   -> INCLUDED (no exclusion rules matched)" >&2
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

    prompt_overwrite "$output_file"

    : > "$output_file" || log_error "Failed to create/write to output file: $output_file"

    local all_files_found=()
    while IFS= read -r -d '' f; do
        all_files_found+=("$f")
    done < <(find "$absolute_input_path_global" -type f -print0 2>/dev/null)

    local files_to_process=()
    for file_abs_path in "${all_files_found[@]}"; do
        if ! should_exclude "$file_abs_path"; then
            files_to_process+=("$file_abs_path")
        fi
    done

    local total_files_to_process=${#files_to_process[@]}
    if [[ "$total_files_to_process" -eq 0 ]]; then
        log_error "No files found to process after applying exclusions. Check input path or configuration."
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
}

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

init_help() {
    cat << EOF
${GREEN}collate init - Initialize project-specific configuration${NC}
Usage: collate init [--help]
       col8 init [--help]

Initializes a .collate directory with a config.yaml file in the current directory.
The config.yaml appends to system-wide settings at ~/.collate/config.yaml.

${YELLOW}Options:${NC}
  --help              Show this help message

${YELLOW}Example:${NC}
  collate init        Creates .collate/config.yaml
  col8 init           Creates .collate/config.yaml
EOF
    exit 0
}

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
# Project-specific configuration for collate
# Appends to system-wide settings at ~/.collate/config.yaml
# System-wide exclusions (for reference, these are applied automatically):
$system_excludes

# Directories to exclude (add to system-wide exclusions)
# Common project directories you might want to exclude:
exclude_dirs:
  - cache
  - logs
  - docs
  - .git
  - coverage
  - .pytest_cache
  - .mypy_cache
  - htmlcov
  - node_modules

# Files to exclude (add to system-wide exclusions)
# Example:
exclude_files:
  - "*.log"
  - "*.md"
  - ".env"
  - ".env.*"
  - "*.bak"
  - "*.backup"
  - "*.bkp"

# Directories or files to allow (overrides system-wide exclusions)
# Example: If you want to include docs despite excluding it above:
# allow_dirs:
#   - docs/api
# allow_files:
#   - "README.md"

# Exclude directories starting with a dot (true/false, defaults to system-wide)
# exclude_dot_dirs: true
EOF

    if [[ ! -f ".collate/config.yaml" ]]; then
        log_error "Failed to create .collate/config.yaml"
    fi

    log_info ".collate directory initialized with config.yaml"
    exit 0
}

# FIXED: Proper color handling for uninit prompt
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
        # Use echo -ne for color output, NOT printf with string interpolation
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
        INPUT_PATH="$COMMAND"
        OUTPUT_FILE_OPT_PROVIDED=false

        OPTIND=1

        while getopts ":o:v" opt; do
            case $opt in
                o)
                    OUTPUT_FILE="$OPTARG"
                    OUTPUT_FILE_OPT_PROVIDED=true
                    ;;
                v)
                    VERBOSE=true
                    ;;
                \?)
                    log_error "Invalid option: -$OPTARG" 1
                    ;;
                :)
                    log_error "Option -$OPTARG requires an argument." 1
                    ;;
            esac
        done
        shift $((OPTIND-1))

        if [[ -n "$1" ]]; then
            INPUT_PATH="$1"
        fi
        
        if [[ "$OUTPUT_FILE_OPT_PROVIDED" == "true" ]]; then
            :
        elif [[ -t 0 && -t 1 ]]; then
            # Interactive - use echo -ne for color
            echo -ne "${YELLOW}Warning: No output file specified via -o option. Enter desired output file path (or press Enter for default: ${DEFAULT_OUTPUT}): ${NC}"
            read input_for_output
            OUTPUT_FILE="${input_for_output:-$DEFAULT_OUTPUT}"
        else
            # Non-interactive
            echo "Warning: No output file specified via -o option. Using default: ${DEFAULT_OUTPUT}" >&2
            OUTPUT_FILE="$DEFAULT_OUTPUT"
        fi

        if ! has_extension "$OUTPUT_FILE"; then
            if [[ -t 1 ]]; then
                log_warning "Output file '$OUTPUT_FILE' has no extension. Using .txt extension."
            else
                echo "Warning: Output file '$OUTPUT_FILE' has no extension. Using .txt extension." >&2
            fi
            OUTPUT_FILE="${OUTPUT_FILE}.txt"
        fi
        
        : "${VERBOSE:=false}"

        flatten_files "$INPUT_PATH" "$OUTPUT_FILE" "$VERBOSE"
        ;;
esac