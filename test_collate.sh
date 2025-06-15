#!/bin/bash

# Test suite for collate utility
# Ensures 100% coverage of functionality, including init, uninit, and combine commands

# ANSI color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

# Test directory
TEST_DIR="/tmp/collate_test"

# Initialize test environment
setup_test_env() {
    # Ensure test directory exists and is clean
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR" || { echo "Failed to create test directory: $TEST_DIR"; exit 1; }
    cd "$TEST_DIR" || { echo "Failed to change to test directory: $TEST_DIR"; exit 1; }

    # Clean up any previous .collate or output files
    rm -rf .collate output.txt
    
    # Create necessary directories first
    mkdir -p test_dir/.hidden # Ensure .hidden directory exists before creating files in it
    
    # Create test files, matching user's recent setup
    echo "Content of file1" > test_dir/file1.txt
    echo "Content of file2" > test_dir/file2.md # Changed to .md as per your setup
    echo "Hidden content of file3" > test_dir/.hidden/file3.txt 

    # Additional directories and files for testing exclusions
    mkdir -p test_dir/temp test_dir/__pycache__
    echo "Temp file content" > test_dir/temp/temp.txt
    echo "Pyc file content" > test_dir/__pycache__/code.pyc
    # Updated .gitignore content to be specific for testing
    echo "temp/" > test_dir/.gitignore
    echo "__pycache__/" >> test_dir/.gitignore
    echo ".hidden/" >> test_dir/.gitignore # Exclude .hidden directory for some tests
    echo ".gitignore-test-content" > test_dir/.gitignore-test-content # For testing inclusion if .gitignore itself is not excluded
}

# Test counter
TEST_COUNT=0
PASS_COUNT=0

# Test function - REVISED FOR PIPE ISSUES AND BETTER DEBUGGING
run_test() {
    local test_name="$1"
    local command_string="$2"
    local expected_output_pattern="$3" # This is now a regex pattern
    local expected_exit_code="$4"
    local output_file_to_check="$5" # If output is redirected to a file
    local check_output_content="$6" # True if content of output_file_to_check should be checked, false if stdout/stderr

    ((TEST_COUNT++))
    echo -n "Test $TEST_COUNT: $test_name... "

    # Use a temporary file to capture the command's actual stdout/stderr
    local temp_log=$(mktemp)
    
    # Execute the command string via bash -c to ensure proper parsing of pipes and shell constructs
    bash -c "$command_string" >"$temp_log" 2>&1
    local exit_code=$?
    local captured_output=$(cat "$temp_log") # Get the output from stdout/stderr
    rm -f "$temp_log"

    local result_status="FAIL" # Assume failure
    local debug_info=""

    if [[ $exit_code -eq $expected_exit_code ]]; then
        if [[ -n "$output_file_to_check" && -f "$output_file_to_check" ]]; then
            local file_content=$(cat "$output_file_to_check" 2>/dev/null)
            if [[ "$check_output_content" == "true" ]]; then # Check content of the output file
                if [[ "$file_content" =~ $expected_output_pattern ]]; then
                    result_status="${GREEN}PASS${NC}"
                    ((PASS_COUNT++))
                else
                    debug_info="\n--- Actual file content ($output_file_to_check) ---\n$file_content\n--- Expected pattern ---\n$expected_output_pattern"
                fi
            else # check_output_content is false, meaning output file should NOT contain pattern
                if [[ ! "$file_content" =~ $expected_output_pattern ]]; then
                    result_status="${GREEN}PASS${NC}"
                    ((PASS_COUNT++))
                else
                    debug_info="\n--- Actual file content ($output_file_to_check) ---\n$file_content\n--- Expected pattern (not to match) ---\n$expected_output_pattern"
                fi
            fi
        else # Checking stdout/stderr output directly
            if [[ "$check_output_content" == "true" ]]; then # Check content of stdout/stderr
                if [[ "$captured_output" =~ $expected_output_pattern ]]; then
                    result_status="${GREEN}PASS${NC}"
                    ((PASS_COUNT++))
                else
                    debug_info="\n--- Actual output (stdout/stderr) ---\n$captured_output\n--- Expected pattern ---\n$expected_output_pattern"
                fi
            else # check_output_content is false, meaning stdout/stderr should NOT contain pattern
                if [[ ! "$captured_output" =~ $expected_output_pattern ]]; then
                    result_status="${GREEN}PASS${NC}"
                    ((PASS_COUNT++))
                else
                    debug_info="\n--- Actual output (stdout/stderr) ---\n$captured_output\n--- Expected pattern (not to match) ---\n$expected_output_pattern"
                fi
            fi
        fi
    else
        debug_info="\n--- Actual output (stdout/stderr) ---\n$captured_output\n--- Exit code $exit_code, expected $expected_exit_code ---"
    fi

    echo -e "$result_status$debug_info"
}

# Test cases
# Ensure a clean environment for each set of related tests

# Test 1-2: Init command tests
setup_test_env
run_test "Init command creates .collate/config.yaml" \
    "collate init" \
    ".collate directory initialized with config.yaml" \
    0 "" true

run_test "Init command fails if .collate exists" \
    "collate init" \
    ".collate directory already exists" \
    1 "" true

# Test 3-4: Uninit command tests
setup_test_env
collate init > /dev/null 2>&1 # Ensure .collate exists for uninit test
run_test "Uninit command removes .collate" \
    "echo y | collate uninit" \
    ".collate directory removed successfully" \
    0 "" true

run_test "Uninit command fails if .collate missing" \
    "collate uninit" \
    "Error: .collate directory does not exist." \
    1 "" true # Expected exit code 1 if directory is missing

# Test 5-12: Combine command tests
setup_test_env
# Expected combined content based on setup_test_env
# Assuming collate outputs file headers and then content
run_test "Combine command with default output" \
    "collate test_dir" \
    "===== FILE:.*test_dir/file1.txt ====\nContent of file1\n\n===== FILE:.*test_dir/file2.md ====\nContent of file2\n\n===== FILE:.*test_dir/.hidden/file3.txt ====\nHidden content of file3" \
    0 "output.txt" true

run_test "Combine command with verbose output" \
    "collate test_dir -o output.txt -v" \
    "Processed:.*test_dir/file1.txt" \
    0 "" true # Check verbose output on stdout/stderr, not the file content

run_test "Combine command skips excluded files (temp)" \
    "collate test_dir -o output.txt" \
    "Temp file content" \
    0 "output.txt" false # Check output.txt does NOT contain "Temp file content"

run_test "Combine command skips excluded files (__pycache__)" \
    "collate test_dir -o output.txt" \
    "Pyc file content" \
    0 "output.txt" false # Check output.txt does NOT contain "Pyc file content"

run_test "Combine command skips excluded files (.hidden)" \
    "collate test_dir -o output.txt" \
    "Hidden content of file3" \
    0 "output.txt" false # Check output.txt does NOT contain "Hidden content of file3"

run_test "Combine command includes allowed files (.gitignore-test-content example)" \
    "collate test_dir -o output.txt" \
    "===== FILE:.*test_dir/.gitignore-test-content ====\n.gitignore-test-content" \
    0 "output.txt" true

run_test "Combine command fails on invalid path" \
    "collate invalid_path" \
    "Input path 'invalid_path' does not exist." \
    1 "" true

run_test "Combine command adds .txt extension" \
    "echo output | collate test_dir" \
    "Warning: Output file 'output' has no extension. Using .txt extension." \
    0 "" true # Check stdout/stderr for warning, not output.txt content.

# Ensure output.txt exists for overwrite tests
setup_test_env
echo "Existing content" > output.txt # Create output.txt for overwrite test scenario
run_test "Combine command overwrites with prompt" \
    "echo y | collate test_dir -o output.txt" \
    "Files combined successfully into 'output.txt'." \
    0 "" true # Check stdout/stderr for success message, not output.txt content.

run_test "Combine command cancels overwrite" \
    "echo n | collate test_dir -o output.txt" \
    "Operation cancelled by user." \
    1 "" true # Check stdout/stderr for cancellation, not output.txt content.

# Test 13-15: Help commands
setup_test_env # Clean up before help tests, though not strictly necessary
run_test "Init help command" \
    "collate init --help" \
    "collate init - Initialize project-specific configuration" \
    0 "" true

run_test "Uninit help command" \
    "collate uninit --help" \
    "collate uninit - Remove project-specific configuration" \
    0 "" true

run_test "Main help command" \
    "collate --help" \
    "collate - Combine files recursively into a single output file" \
    0 "" true

# Test 16-18: Alias tests
setup_test_env # Clean environment for alias tests
run_test "Col8 alias works for combine" \
    "echo output.txt | col8 test_dir" \
    "Files combined successfully into 'output.txt'." \
    0 "" true # Check stdout/stderr for success message.

run_test "Col8 alias works for init" \
    "col8 init" \
    ".collate directory initialized with config.yaml" \
    0 "" true

setup_test_env
collate init > /dev/null 2>&1 # Ensure .collate exists for uninit alias test
run_test "Col8 alias works for uninit" \
    "echo y | col8 uninit" \
    ".collate directory removed successfully" \
    0 "" true

# Summary
echo -e "\n${GREEN}Test Summary: $PASS_COUNT/$TEST_COUNT tests passed${NC}"
if [[ $PASS_COUNT -eq $TEST_COUNT ]]; then
    exit 0
else
    exit 1
fi

# test_collate.sh