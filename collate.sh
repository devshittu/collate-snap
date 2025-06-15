#!/bin/bash

# System-wide command: collate (alias: col8)
# Combines files recursively into a single output file with configurable exclusions.
# Supports project-specific configs (.collate/config.yaml) and system-wide settings (/etc/collate/config.yaml).
# Commands: init (initialize project config), uninit (remove project config), <path> (combine files).

# Configuration paths - These paths are intentional and left as specified by the user.
SYSTEM_CONFIG="$HOME/.collate/config.yaml"
PROJECT_CONFIG=".collate/config.yaml"
DEFAULT_OUTPUT="./.temp/flat/output.txt" # Changed to .temp as .collate is often hidden and .temp indicates temporary

# ANSI color codes - Conditionally set based on terminal interactivity
# These variables will contain the color codes ONLY if output is a terminal.
if [[ -t 1 ]]; then # Check if stdout is a terminal
    GREEN="\033[0;32m"
    RED="\033[0;31m"
    YELLOW="\033[0;33m"
    NC="\033[0m" # No Color
else
    GREEN=""
    RED=""
    YELLOW=""
    NC="" # No Color
fi

# Global arrays for configurations (populated by load_config)
declare -a SYSTEM_EXCLUDE_DIRS
declare -a SYSTEM_EXCLUDE_FILES
SYSTEM_EXCLUDE_DOT_DIRS_DEFAULT=true # Default system-wide setting (boolean)

declare -a PROJECT_EXCLUDE_DIRS
declare -a PROJECT_EXCLUDE_FILES
PROJECT_EXCLUDE_DOT_DIRS="" # Will be overridden if specified in project config

declare -a PROJECT_ALLOW_DIRS
declare -a PROJECT_ALLOW_FILES

declare -a EXCLUDE_DIRS # Combined list of excluded directories
declare -a EXCLUDE_FILES # Combined list of excluded files
declare -a ALLOW_DIRS # Combined list of allowed directories (project only)
declare -a ALLOW_FILES # Combined list of allowed files (project only)
EXCLUDE_DOT_DIRS_FINAL=false # Final boolean for dot directory exclusion after combining

# Global variables for input and output paths (used across functions)
input_path_global=""
output_file_global=""
absolute_input_path_global="" # Absolute resolved path of user's input
absolute_output_file_global="" # Absolute resolved path of the final output file


# --- Utility Functions (Must be defined BEFORE they are called) ---

# Function to log messages (info, error, warning)
log_info() { echo -e "${GREEN}$1${NC}"; }
# log_error now takes an optional exit_code. Defaults to 1.
log_error() {
    local message="$1"
    local exit_code="${2:-1}" # Default exit code is 1
    echo -e "${RED}Error: $message${NC}" >&2
    exit "$exit_code"
}
log_warning() { echo -e "${YELLOW}$1${NC}"; } # log_warning itself uses -e for its argument


# Function to check if a file has a valid extension
has_extension() {
    local filename="$1"
    [[ "$filename" =~ \.[a-zA-Z0-9]+$ ]] && return 0 || return 1
}

# Function to prompt for overwrite confirmation
prompt_overwrite() {
    local output_file_path="$1" # Use a distinct variable name for clarity
    if [[ -f "$output_file_path" ]]; then
        log_warning "Output file '$output_file_path' already exists." # This uses log_warning which will apply colors if interactive

        local prompt_string="Overwrite? (y/N): "
        if [[ -t 1 ]]; then
            read -p "${YELLOW}${prompt_string}${NC}" confirm
        else
            # For non-interactive, print raw prompt without colors
            read -p "${prompt_string}" confirm
        fi
        
        if [[ ! "$confirm" =~ ^[yY]$ ]]; then
            log_error "Operation cancelled by user." 1 # Explicitly exit with 1 on cancellation
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
    while IFS= read -r line; do
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')
        # Skip comments and empty lines
        [[ "$line" =~ ^# || -z "$line" ]] && continue
        
        # Handle key: value pairs
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
        # Handle array items (start with - )
        elif [[ "$line" =~ ^-\  ]]; then # Ensure space after hyphen
            local value=$(echo "$line" | sed 's/^- //')
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
            # If line is not a key-value or array item, reset current_key
            current_key=""
        fi
    done < "$file"
}

# Function to load configurations
load_config() {
    # Reset arrays to ensure clean state on repeated calls (e.g., in tests)
    SYSTEM_EXCLUDE_DIRS=()
    SYSTEM_EXCLUDE_FILES=()
    SYSTEM_EXCLUDE_DOT_DIRS_DEFAULT=true
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

    # Combine configurations (project appends to system unless overridden by 'allow')
    # Combine EXCLUDE_DIRS
    EXCLUDE_DIRS=("${SYSTEM_EXCLUDE_DIRS[@]}")
    for proj_dir in "${PROJECT_EXCLUDE_DIRS[@]}"; do
        EXCLUDE_DIRS+=("$proj_dir")
    done

    # Combine EXCLUDE_FILES
    EXCLUDE_FILES=("${SYSTEM_EXCLUDE_FILES[@]}")
    for proj_file in "${PROJECT_EXCLUDE_FILES[@]}"; do
        EXCLUDE_FILES+=("$proj_file")
    done

    # ALLOW lists are only from project config, as per design
    ALLOW_DIRS=("${PROJECT_ALLOW_DIRS[@]}")
    ALLOW_FILES=("${PROJECT_ALLOW_FILES[@]}")
    
    # Final EXCLUDE_DOT_DIRS setting: project setting takes precedence, then system setting
    local dot_dirs_setting="${PROJECT_EXCLUDE_DOT_DIRS:-$SYSTEM_EXCLUDE_DOT_DIRS_DEFAULT}"
    [[ "$dot_dirs_setting" == "true" ]] && EXCLUDE_DOT_DIRS_FINAL=true || EXCLUDE_DOT_DIRS_FINAL=false
}

# Function to check if a file/directory should be excluded
should_exclude() {
    local path="$1"
    local filename=$(basename "$path")
    local dirname_only=$(dirname "$path") # The directory part of the path
    local relative_path_to_check="$path" # Start with full path
    
    # Crucial: Exclude the output file itself right away
    if [[ "$path" == "$absolute_output_file_global" ]]; then
        return 0 # Exclude
    fi

    # If the path starts with the current working directory, make it relative for pattern matching
    # This ensures consistency with config entries like "temp/"
    local current_wd_for_exclude=$(pwd) # Use a distinct local variable
    if [[ "$path" == "$current_wd_for_exclude/"* ]]; then
        relative_path_to_check="${path#$current_wd_for_exclude/}"
    fi

    # 1. Check against ALLOW_FILES (highest precedence)
    for allowed_file_pattern in "${ALLOW_FILES[@]}"; do
        if [[ "$filename" == $allowed_file_pattern ]]; then # Using glob for patterns like *.log
            return 1 # DO NOT exclude
        fi
    done

    # 2. Check against ALLOW_DIRS (highest precedence for directories)
    for allowed_dir_pattern in "${ALLOW_DIRS[@]}"; do
        # Check if the path or any of its parent directories match an allowed directory pattern
        # This handles cases like 'test_dir/subdir/file.txt' matching 'test_dir'
        if [[ "$relative_path_to_check" == "$allowed_dir_pattern"* ]]; then
            return 1 # DO NOT exclude
        fi
        # Also check if the exact dirname matches
        if [[ "$dirname_only" == *"/$allowed_dir_pattern" ]]; then
            return 1 # DO NOT exclude
        fi
    done

    # 3. Check for dot directories exclusion if enabled
    if [[ "$EXCLUDE_DOT_DIRS_FINAL" == true ]]; then
        # Check if any component in the path (including filename) starts with a dot
        local temp_path_for_dots="$relative_path_to_check"
        while [[ "$temp_path_for_dots" != "." && "$temp_path_for_dots" != "/" ]]; do
            local current_segment=$(basename "$temp_path_for_dots")
            if [[ "$current_segment" == .* && "$current_segment" != "." && "$current_segment" != ".." ]]; then
                # Ensure it's not the root of the search
                if [[ "$relative_path_to_check" != "." ]]; then # Avoid excluding the root itself if it's a dot-dir
                    return 0 # Exclude
                fi
            fi
            # Check if we've reached the base of the input path to prevent infinite loops for relative paths
            if [[ "$temp_path_for_dots" == "$(basename "$absolute_input_path_global")" || \
                  "$temp_path_for_dots" == "$absolute_input_path_global" ]]; then break; fi
            temp_path_for_dots=$(dirname "$temp_path_for_dots")
        done
        # Special case: If the input path itself is a dot-dir (e.g., .collate), and exclude_dot_dirs is true, exclude it.
        if [[ "$(basename "$absolute_input_path_global")" == .* && "$absolute_input_path_global" == "$path" ]]; then
             return 0 # Exclude
        fi
    fi

    # 4. Check against EXCLUDE_DIRS
    for excluded_dir_pattern in "${EXCLUDE_DIRS[@]}"; do
        # Check if the path or any of its parent directories match an excluded directory pattern
        if [[ "$relative_path_to_check" == *"$excluded_dir_pattern"* ]]; then # Covers /path/to/excluded_dir/file
            return 0 # Exclude
        fi
        # Check if the specific directory name (basename) matches the pattern
        if [[ "$filename" == "$excluded_dir_pattern" ]]; then # Covers exact dir name match like "temp"
            return 0 # Exclude
        fi
        # Check if any part of the path matches a full segment
        if [[ "$relative_path_to_check" =~ (^|/)"$excluded_dir_pattern"(|/|$) ]]; then
            return 0 # Exclude
        fi
    done

    # 5. Check against EXCLUDE_FILES
    for excluded_file_pattern in "${EXCLUDE_FILES[@]}"; do
        if [[ "$filename" == $excluded_file_pattern ]]; then # Using glob for patterns like *.log
            return 0 # Exclude
        fi
    done

    return 1 # Do not exclude by default
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
    local output_file="$2" # This is the resolved output file path
    local verbose="$3"
    
    # Resolve and set global input and output path variables
    absolute_input_path_global=$(realpath -m "$input_path" 2>/dev/null)
    if [[ -z "$absolute_input_path_global" || (! -d "$absolute_input_path_global" && ! -f "$absolute_input_path_global") ]]; then
        log_error "Input path '$input_path' does not exist."
    fi
    # Use the provided input_path directly for relative path calculations later
    input_path_global="$input_path" 

    # Ensure output directory exists before resolving output_file_global
    local output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir" || log_error "Failed to create output directory: $output_dir"

    # Resolve and set the global absolute output file path
    absolute_output_file_global=$(realpath -m "$output_file" 2>/dev/null)
    output_file_global="$output_file" # Keep the original output file name for logs/prompts

    # Check for existing output file and prompt for overwrite, only if file exists
    prompt_overwrite "$output_file"

    # Clear or create the output file
    : > "$output_file" || log_error "Failed to create/write to output file: $output_file"

    local all_files_found=()
    # First pass: Collect all files, find will give absolute paths
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
    # Capture current working directory once for relative path calculations inside the loop
    local current_wd=$(pwd) 

    for file_absolute_path in "${files_to_process[@]}"; do
        ((processed_count++))
        
        # Calculate the path to display in the output file header
        local path_in_header=""
        
        # Get the absolute path of the input directory for relative calculation
        local abs_input_path_dir=$(realpath -m "$input_path_global" 2>/dev/null)
        
        if [[ "$file_absolute_path" == "$abs_input_path_dir/"* ]]; then
            # If the file is under the absolute input directory, make it relative to the original input
            path_in_header="${input_path_global}/${file_absolute_path#$abs_input_path_dir/}"
        elif [[ "$file_absolute_path" == "$current_wd/"* ]]; then
            # If not under input dir, but under current working directory, make it relative to current WD
            path_in_header="${file_absolute_path#$current_wd/}"
        else
            # Fallback to just the basename if it's an unusual path, or simply the full path.
            # For robustness, let's keep it relative to current_wd if possible, otherwise use basename
            if [[ "$file_absolute_path" == /* ]]; then # If it's an absolute path
                 path_in_header="${file_absolute_path#$current_wd/}" # Try to make it relative to current WD
                 if [[ "$path_in_header" == "$file_absolute_path" ]]; then # If still absolute, just use basename
                     path_in_header=$(basename "$file_absolute_path")
                 fi
            else
                path_in_header="$file_absolute_path" # It's already relative
            fi
        fi

        # If the input was a single file and matches the current file
        if [[ -f "$absolute_input_path_global" && "$file_absolute_path" == "$absolute_input_path_global" ]]; then
            path_in_header=$(basename "$input_path_global")
        fi

        [[ "$verbose" == "true" ]] && log_info "Processed: $path_in_header (Full path: $file_absolute_path)"
        [[ "$verbose" != "true" ]] && show_progress "$processed_count" "$total_files_to_process"

        # Append file path and content to output
        {
            echo "===== FILE: $path_in_header =====" # Display the user-friendly relative path
            cat "$file_absolute_path" 2>/dev/null || log_error "Failed to read file: $file_absolute_path"
            echo -e "\n===== END: $path_in_header =====\n" # Display the user-friendly relative path
        } >> "$output_file" || log_error "Failed to append to output file: $output_file"
    done

    [[ "$verbose" != "true" ]] && echo "" # Newline after progress bar
    if [[ ! -s "$output_file" ]]; then # Check if the output file is empty
        log_error "No content was written to '$output_file'. This might indicate an issue with file processing."
    fi

    log_info "Files combined successfully into '$output_file'" # Use single quotes for consistency
}

# --- Command-Specific Help Functions ---
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

# --- Project Management Functions ---

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
        # Use grep -v for comments, and sed to format for output
        system_excludes=$(grep -E 'exclude_dirs:|exclude_files:|exclude_dot_dirs:' "$SYSTEM_CONFIG" | \
                          sed -E 's/^(exclude_dirs|exclude_files|exclude_dot_dirs):/# From system config: \1:/g; s/^- /#  - /g')
        # Also include any array items not directly under a key line
        system_excludes+=$(grep -E '^[[:space:]]*- ' "$SYSTEM_CONFIG" | \
                           sed 's/^[[:space:]]*- /#  - /g')
    fi

    cat << EOF > ".collate/config.yaml"
# Project-specific configuration for collate
# Appends to system-wide settings at /etc/collate/config.yaml
# System-wide exclusions (for reference, these are applied automatically):
$system_excludes

# Directories to exclude (add to system-wide exclusions)
# Example:
# exclude_dirs:
#   - cache
#   - build

# Files to exclude (add to system-wide exclusions)
# Example:
# exclude_files:
#   - "*.log"
#   - "*.o"

# Directories or files to allow (overrides system-wide exclusions)
# Example:
# allow_dirs:
#   - .git
# allow_files:
#   - ".gitignore"

# Exclude directories starting with a dot (true/false, defaults to system-wide)
# Example:
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
        log_error ".collate directory does not exist in $(pwd)" 1 # Explicit exit 1
    fi

    if [[ -t 1 ]]; then # Check if connected to a terminal (interactive)
        log_warning "This will remove the .collate directory and its contents."
        read -p "${YELLOW}Proceed? (y/N): ${NC}" confirm
        if [[ ! "$confirm" =~ ^[yY]$ ]]; then
            log_error "Operation cancelled by user." 1 # Explicit exit 1
        fi
    else
        # Non-interactive, auto-confirm remove
        log_info "Non-interactive session: Automatically proceeding with .collate directory removal."
        confirm="y"
    fi


    rm -rf ".collate" || log_error "Failed to remove .collate directory" 1 # Explicit exit 1
    log_info ".collate directory removed successfully"
    exit 0
}

# --- Main Script Logic ---

# Load initial config (needed if combine command is run directly without explicit init)
load_config # This needs to be called once at the start of the script

# Main script execution logic (no 'local' outside functions)
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
        # Treat command as input path for combining
        INPUT_PATH="$COMMAND"
        OUTPUT_FILE_OPT_PROVIDED=false # Flag to track if -o was explicitly provided

        OPTIND=1 # Reset OPTIND for current getopts call

        while getopts ":o:v" opt; do # Colon before o indicates it takes an argument
            case $opt in
                o)
                    OUTPUT_FILE="$OPTARG"
                    OUTPUT_FILE_OPT_PROVIDED=true # Set flag
                    ;;
                v)
                    VERBOSE=true
                    ;;
                \?)
                    log_error "Invalid option: -$OPTARG" 1 # Specific error for invalid option
                    ;;
                :)
                    log_error "Option -$OPTARG requires an argument." 1
                    ;;
            esac
        done
        shift $((OPTIND-1)) # Shift past processed options

        # If after shifting, there's still an argument, it's the input path
        if [[ -n "$1" ]]; then
            INPUT_PATH="$1"
        fi
        
        # Determine the final OUTPUT_FILE:
        # 1. If -o was provided, use that.
        # 2. If -o was NOT provided AND we are in an interactive terminal, prompt the user.
        # 3. Otherwise (non-interactive or -o not provided), use DEFAULT_OUTPUT.

        if [[ "$OUTPUT_FILE_OPT_PROVIDED" == "true" ]]; then
            # OUTPUT_FILE already set by getopts
            : # Do nothing
        elif [[ -t 1 ]]; then # If no -o and interactive
            # Construct the prompt string conditionally
            prompt_string="Warning: No output file specified via -o option. Enter desired output file path (or press Enter for default: ${DEFAULT_OUTPUT}): "
            read -p "${YELLOW}${prompt_string}${NC}" input_for_output
            OUTPUT_FILE="${input_for_output:-$DEFAULT_OUTPUT}"
        else # Non-interactive and no -o
            # For non-interactive, print warning without ANSI codes to stderr
            echo "Warning: No output file specified via -o option. Using default: ${DEFAULT_OUTPUT}" >&2
            OUTPUT_FILE="$DEFAULT_OUTPUT"
        fi

        # Validate output file extension
        if ! has_extension "$OUTPUT_FILE"; then
            if [[ -t 1 ]]; then # Only warn with colors if interactive
                log_warning "Output file '$OUTPUT_FILE' has no extension. Using .txt extension."
            else
                echo "Warning: Output file '$OUTPUT_FILE' has no extension. Using .txt extension." >&2
            fi
            OUTPUT_FILE="${OUTPUT_FILE}.txt"
        fi
        
        # Ensure VERBOSE is set (it might not be if -v wasn't passed)
        : "${VERBOSE:=false}"

        # Run the combine operation
        flatten_files "$INPUT_PATH" "$OUTPUT_FILE" "$VERBOSE"
        ;;
esac