#!/bin/bash

# build.sh - Optimized version with single-pass processing
# Added execution time tracking with --silent option
# Added support for .sh files in addition to .asm and binaries

# Set strict mode for better error handling
set -euo pipefail

# Configuration
ARCH_OUTPUT="../arch_output"
BASH_RUNNER="../basm/sbasm.sh"
JS_DIR="js/"
CHAIN_DIR="chain/"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize counters
processed_count=0
error_count=0

# Time tracking variables
START_TIME=0
TOTAL_CREATION_TIME=0
TOTAL_EXECUTION_TIME=0

# Silent mode flag
SILENT_MODE=false

# Buffer for accumulating content
declare -a TAG_BUFFER=()
CURRENT_TAG=""
CURRENT_CONTENT=""

# Function to get current timestamp in milliseconds
get_timestamp_ms() {
    echo $(($(date +%s%N)/1000000))
}

# Function to format milliseconds to human readable time
format_duration() {
    local ms=$1
    local seconds=$((ms / 1000))
    local milliseconds=$((ms % 1000))
    
    if (( seconds > 0 )); then
        echo "${seconds}.${milliseconds}s"
    else
        echo "${milliseconds}ms"
    fi
}

# Function to log messages (respects silent mode)
log_info() {
    if [[ "$SILENT_MODE" == false ]]; then
        echo -e "${GREEN}[INFO]${NC} $1"
    fi
}

log_warn() {
    if [[ "$SILENT_MODE" == false ]]; then
        echo -e "${YELLOW}[WARN]${NC} $1"
    fi
}

log_error() {
    # Always show errors
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function to check if content is a declaration
is_declaration() {
    local content="$1"
    
    # Trim leading whitespace
    local trimmed="${content#"${content%%[![:space:]]*}"}"
    
    # Check for declaration keywords with space after
    if [[ "$trimmed" =~ ^(let\ |const\ |var\ ) ]]; then
        echo "${BASH_REMATCH[1]% }"  # Return the keyword without the space
    else
        echo ""
    fi
}

# Function to parse method name from expression
parse_method_name() {
    local content="$1"
    
    # Remove whitespace
    local trimmed="${content//[[:space:]]/}"
    
    # Extract everything before first '('
    local method_part="${trimmed%%(*}"
    
    echo "$method_part"
}

# Function to check for available executable files in order of preference
# Returns: "binary", "asm", "sh", or ""
check_executable_exists() {
    local base_path="$1"
    
    # Check for binary (without extension) - HIGHEST PRIORITY
    if [[ -f "$base_path" ]] && [[ -x "$base_path" || -x "${base_path%.*}" ]]; then
        echo "binary"
        return 0
    # Check for .asm file - SECOND PRIORITY
    elif [[ -f "${base_path}.asm" ]]; then
        echo "asm"
        return 0
    # Check for .sh file - THIRD PRIORITY
    elif [[ -f "${base_path}.sh" ]]; then
        echo "sh"
        return 0
    else
        echo ""
        return 1
    fi
}

# Function to create temporary content file with time tracking
create_temp_file() {
    local file_path="$1"
    local content="$2"
    local creation_start_time=0
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$file_path")"
    
    # Start creation time tracking
    creation_start_time=$(get_timestamp_ms)
    
    # Write content to file
    echo -n "$content" > "$file_path"
    
    local result=$?
    local creation_end_time=$(get_timestamp_ms)
    local creation_duration=$((creation_end_time - creation_start_time))
    
    # Track total creation time
    TOTAL_CREATION_TIME=$((TOTAL_CREATION_TIME + creation_duration))
    
    if [[ $result -eq 0 ]]; then
        if [[ "$SILENT_MODE" == false ]]; then
            log_info "Created file: $file_path ($(format_duration $creation_duration))"
        fi
        return 0
    else
        log_error "Failed to create file: $file_path ($(format_duration $creation_duration))"
        return 1
    fi
}

# Function to execute basm.sh for .asm files
execute_basm() {
    local input_file="$1"
    local asm_file="$2"
    local execution_start_time=0
    
    if [[ "$SILENT_MODE" == false ]]; then
        log_info "Executing: bash $BASH_RUNNER $asm_file"
    fi
    
    # Record execution start time
    execution_start_time=$(get_timestamp_ms)
    
    # Execute with bash command and wait for completion
    if bash "$BASH_RUNNER" "$asm_file" >/dev/null 2>&1; then
        local execution_end_time=$(get_timestamp_ms)
        local execution_duration=$((execution_end_time - execution_start_time))
        TOTAL_EXECUTION_TIME=$((TOTAL_EXECUTION_TIME + execution_duration))
        
        if [[ "$SILENT_MODE" == false ]]; then
            log_info "Execution completed successfully ($(format_duration $execution_duration))"
        fi
        return 0
    else
        local exit_code=$?
        local execution_end_time=$(get_timestamp_ms)
        local execution_duration=$((execution_end_time - execution_start_time))
        TOTAL_EXECUTION_TIME=$((TOTAL_EXECUTION_TIME + execution_duration))
        
        if [[ "$SILENT_MODE" == false ]]; then
            log_error "Execution failed with exit code: $exit_code ($(format_duration $execution_duration))"
        fi
        return $exit_code
    fi
}

# Function to execute binary files directly
execute_binary() {
    local input_file="$1"
    local binary_file="$2"
    local execution_start_time=0
    
    # Make sure binary is executable
    chmod +x "$binary_file" 2>/dev/null || true
    
    if [[ "$SILENT_MODE" == false ]]; then
        log_info "Executing binary directly: $binary_file"
    fi
    
    # Record execution start time
    execution_start_time=$(get_timestamp_ms)
    
    # Execute binary directly and wait for completion
    if "$binary_file" >/dev/null 2>&1; then
        local execution_end_time=$(get_timestamp_ms)
        local execution_duration=$((execution_end_time - execution_start_time))
        TOTAL_EXECUTION_TIME=$((TOTAL_EXECUTION_TIME + execution_duration))
        
        if [[ "$SILENT_MODE" == false ]]; then
            log_info "Binary execution completed successfully ($(format_duration $execution_duration))"
        fi
        return 0
    else
        local exit_code=$?
        local execution_end_time=$(get_timestamp_ms)
        local execution_duration=$((execution_end_time - execution_start_time))
        TOTAL_EXECUTION_TIME=$((TOTAL_EXECUTION_TIME + execution_duration))
        
        if [[ "$SILENT_MODE" == false ]]; then
            log_error "Binary execution failed with exit code: $exit_code ($(format_duration $execution_duration))"
        fi
        return $exit_code
    fi
}

# Function to execute .sh files directly with bash
execute_sh() {
    local input_file="$1"
    local sh_file="$2"
    local execution_start_time=0
    
    # Make sure shell script is executable
    chmod +x "$sh_file" 2>/dev/null || true
    
    if [[ "$SILENT_MODE" == false ]]; then
        log_info "Executing shell script: bash $sh_file"
    fi
    
    # Record execution start time
    execution_start_time=$(get_timestamp_ms)
    
    # Execute shell script with bash and wait for completion
    if bash "$sh_file" >/dev/null 2>&1; then
        local execution_end_time=$(get_timestamp_ms)
        local execution_duration=$((execution_end_time - execution_start_time))
        TOTAL_EXECUTION_TIME=$((TOTAL_EXECUTION_TIME + execution_duration))
        
        if [[ "$SILENT_MODE" == false ]]; then
            log_info "Shell script execution completed successfully ($(format_duration $execution_duration))"
        fi
        return 0
    else
        local exit_code=$?
        local execution_end_time=$(get_timestamp_ms)
        local execution_duration=$((execution_end_time - execution_start_time))
        TOTAL_EXECUTION_TIME=$((TOTAL_EXECUTION_TIME + execution_duration))
        
        if [[ "$SILENT_MODE" == false ]]; then
            log_error "Shell script execution failed with exit code: $exit_code ($(format_duration $execution_duration))"
        fi
        return $exit_code
    fi
}

# Function to handle JavaScript-like content with support for .sh files
handle_js_content() {
    local content="$1"
    
    if [[ "$SILENT_MODE" == false ]]; then
        log_info "Processing JS content: ${content:0:50}..."
    fi
    
    # Step 1: Check for declarations
    local declaration_type
    declaration_type=$(is_declaration "$content")
    
    if [[ -n "$declaration_type" ]]; then
        # Declaration detected
        if [[ "$SILENT_MODE" == false ]]; then
            log_info "Processing declaration: $declaration_type"
        fi
        
        # Create declaration file with _input suffix
        local input_file="${JS_DIR}${declaration_type}_input"
        local base_file="${JS_DIR}${declaration_type}"
        
        if create_temp_file "$input_file" "$content"; then
            local file_type
            file_type=$(check_executable_exists "$base_file")
            
            case "$file_type" in
                "binary")
                    # Execute binary directly
                    if execute_binary "$input_file" "$base_file"; then
                        processed_count=$((processed_count + 1))
                    else
                        error_count=$((error_count + 1))
                    fi
                    ;;
                "asm")
                    # Execute .asm file with basm.sh
                    if execute_basm "$input_file" "${base_file}.asm"; then
                        processed_count=$((processed_count + 1))
                    else
                        error_count=$((error_count + 1))
                    fi
                    ;;
                "sh")
                    # Execute .sh file with bash
                    if execute_sh "$input_file" "${base_file}.sh"; then
                        processed_count=$((processed_count + 1))
                    else
                        error_count=$((error_count + 1))
                    fi
                    ;;
                *)
                    log_error "No executable found for declaration: $declaration_type (checked: $base_file, ${base_file}.asm, ${base_file}.sh)"
                    error_count=$((error_count + 1))
                    ;;
            esac
        else
            error_count=$((error_count + 1))
        fi
        return
    fi
    
    # Step 2: Try to parse as method call
    local method_name
    method_name=$(parse_method_name "$content")
    
    if [[ -n "$method_name" ]]; then
        # Handle dot notation
        local parts
        IFS='.' read -ra parts <<< "$method_name"
        
        # Build directory path
        local dir_path="$JS_DIR"
        local file_name=""
        
        if [[ ${#parts[@]} -eq 1 ]]; then
            # No dots: mymethod()
            dir_path+="${parts[0]}/"
            file_name="${parts[0]}"
        else
            # With dots: a.b.c()
            for ((i=0; i<${#parts[@]}-1; i++)); do
                dir_path+="${parts[i]}/"
            done
            file_name="${parts[-1]}"
        fi
        
        # Create input file with _input suffix
        local input_file="${dir_path}${file_name}_input"
        local base_file="${dir_path}${file_name}"
        
        if [[ "$SILENT_MODE" == false ]]; then
            log_info "Checking for executable: $base_file (binary, .asm, or .sh)"
        fi
        
        local file_type
        file_type=$(check_executable_exists "$base_file")
        if [[ -n "$file_type" ]]; then
            if create_temp_file "$input_file" "$content"; then
                case "$file_type" in
                    "binary")
                        if execute_binary "$input_file" "$base_file"; then
                            processed_count=$((processed_count + 1))
                        else
                            error_count=$((error_count + 1))
                        fi
                        ;;
                    "asm")
                        if execute_basm "$input_file" "${base_file}.asm"; then
                            processed_count=$((processed_count + 1))
                        else
                            error_count=$((error_count + 1))
                        fi
                        ;;
                    "sh")
                        if execute_sh "$input_file" "${base_file}.sh"; then
                            processed_count=$((processed_count + 1))
                        else
                            error_count=$((error_count + 1))
                        fi
                        ;;
                esac
                return
            else
                error_count=$((error_count + 1))
                return
            fi
        fi
    fi
    
    # Step 3: Fallback
    if [[ "$SILENT_MODE" == false ]]; then
        log_warn "No specific handler found, using fallback"
    fi
    
    # Create fallback input file with _input suffix
    local input_file="${JS_DIR}call_input"
    local base_file="${JS_DIR}call"
    
    if create_temp_file "$input_file" "$content"; then
        local file_type
        file_type=$(check_executable_exists "$base_file")
        
        case "$file_type" in
            "binary")
                if execute_binary "$input_file" "$base_file"; then
                    processed_count=$((processed_count + 1))
                else
                    error_count=$((error_count + 1))
                fi
                ;;
            "asm")
                if execute_basm "$input_file" "${base_file}.asm"; then
                    processed_count=$((processed_count + 1))
                else
                    error_count=$((error_count + 1))
                fi
                ;;
            "sh")
                if execute_sh "$input_file" "${base_file}.sh"; then
                    processed_count=$((processed_count + 1))
                else
                    error_count=$((error_count + 1))
                fi
                ;;
            *)
                log_error "Fallback executable not found: $base_file (binary, .asm, or .sh)"
                error_count=$((error_count + 1))
                ;;
        esac
    else
        error_count=$((error_count + 1))
    fi
}

# Function to handle chain blocks with .sh support
handle_chain_block() {
    local content="$1"
    
    if [[ "$SILENT_MODE" == false ]]; then
        log_info "Processing chain block (length: ${#content})"
    fi
    
    # Create chain input file with _input suffix
    local input_file="${CHAIN_DIR}chain_input"
    local base_file="${CHAIN_DIR}chain"
    
    if create_temp_file "$input_file" "$content"; then
        local file_type
        file_type=$(check_executable_exists "$base_file")
        
        case "$file_type" in
            "binary")
                if execute_binary "$input_file" "$base_file"; then
                    processed_count=$((processed_count + 1))
                else
                    error_count=$((error_count + 1))
                fi
                ;;
            "asm")
                if execute_basm "$input_file" "${base_file}.asm"; then
                    processed_count=$((processed_count + 1))
                else
                    error_count=$((error_count + 1))
                fi
                ;;
            "sh")
                if execute_sh "$input_file" "${base_file}.sh"; then
                    processed_count=$((processed_count + 1))
                else
                    error_count=$((error_count + 1))
                fi
                ;;
            *)
                log_error "Chain executable not found: $base_file (binary, .asm, or .sh)"
                error_count=$((error_count + 1))
                ;;
        esac
    else
        error_count=$((error_count + 1))
    fi
}

# Function to process buffered content when a tag ends
process_buffered_content() {
    local content="$CURRENT_CONTENT"
    local tag="$CURRENT_TAG"
    
    # Trim whitespace
    content=$(echo "$content" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    if [[ -n "$content" ]]; then
        case "$tag" in
            "<js-start>")
                handle_js_content "$content"
                ;;
            "<chain-start>")
                handle_chain_block "$content"
                ;;
        esac
    fi
    
    # Reset buffer
    CURRENT_CONTENT=""
    CURRENT_TAG=""
}

# Main function to process the arch_output file
main() {
    # Record start time
    START_TIME=$(get_timestamp_ms)
    
    if [[ "$SILENT_MODE" == false ]]; then
        log_info "Starting build process..."
        log_info "Reading from: $ARCH_OUTPUT"
    fi
    
    # Check if input file exists
    if [[ ! -f "$ARCH_OUTPUT" ]]; then
        log_error "Input file not found: $ARCH_OUTPUT"
        exit 1
    fi
    
    # Check if basm runner exists (as a file, not necessarily executable)
    if [[ ! -f "$BASH_RUNNER" ]]; then
        log_error "BASH runner not found: $BASH_RUNNER"
        exit 1
    fi
    
    # Create necessary directories
    mkdir -p "$JS_DIR"
    mkdir -p "$CHAIN_DIR"
    
    # Read the file line by line (much faster than reading entire file at once)
    local line
    local in_tag=0
    local chain_depth=0
    local chain_buffer=""
    local in_chain=0
    
    while IFS= read -r line; do
        # If we're inside a chain block, buffer everything
        if [[ $in_chain -eq 1 ]]; then
            chain_buffer+="$line"$'\n'
            
            # Check for chain tags in this line
            if [[ "$line" == *"<chain-start>"* ]]; then
                ((chain_depth++))
            fi
            
            if [[ "$line" == *"<chain-end>"* ]]; then
                ((chain_depth--))
                if [[ $chain_depth -eq 0 ]]; then
                    # End of chain block reached
                    handle_chain_block "$chain_buffer"
                    chain_buffer=""
                    in_chain=0
                fi
            fi
            continue
        fi
        
        # Check for chain-start tags (special handling for nested chains)
        if [[ "$line" == *"<chain-start>"* ]]; then
            if [[ $in_tag -eq 0 ]]; then
                # Start buffering chain content
                chain_buffer="$line"$'\n'
                in_chain=1
                chain_depth=1
                continue
            fi
        fi
        
        # Process regular tags with state machine
        if [[ $in_tag -eq 0 ]]; then
            # Looking for opening tags
            if [[ "$line" == *"<js-start>"* ]]; then
                CURRENT_TAG="<js-start>"
                in_tag=1
                # Remove everything before the tag
                line="${line#*<js-start>}"
            fi
        fi
        
        if [[ $in_tag -eq 1 ]]; then
            # Inside a tag, look for closing tag
            if [[ "$line" == *"<js-end>"* ]]; then
                # Add content before closing tag
                CURRENT_CONTENT+="${line%<js-end>*}"
                process_buffered_content
                
                # Continue with remaining part of line after closing tag
                remaining="${line#*<js-end>}"
                if [[ -n "$remaining" ]]; then
                    # Check if there's another opening tag in the remaining part
                    if [[ "$remaining" == *"<js-start>"* ]]; then
                        CURRENT_TAG="<js-start>"
                        in_tag=1
                        CURRENT_CONTENT="${remaining#*<js-start>}"
                    else
                        in_tag=0
                    fi
                else
                    in_tag=0
                fi
            else
                # No closing tag in this line, add entire line to content
                CURRENT_CONTENT+="$line"$'\n'
            fi
        else
            # Not in a tag, check for opening tags in current line
            if [[ "$line" == *"<js-start>"* ]]; then
                CURRENT_TAG="<js-start>"
                in_tag=1
                CURRENT_CONTENT="${line#*<js-start>}"
            fi
        fi
    done < "$ARCH_OUTPUT"
    
    # Handle any remaining buffered content
    if [[ -n "$CURRENT_CONTENT" && -n "$CURRENT_TAG" ]]; then
        process_buffered_content
    fi
    
    # Handle any incomplete chain block
    if [[ $in_chain -eq 1 ]]; then
        log_error "Unclosed chain block detected"
        error_count=$((error_count + 1))
    fi
    
    # Calculate total execution time
    local END_TIME=$(get_timestamp_ms)
    local TOTAL_DURATION=$((END_TIME - START_TIME))
    
    # Print summary with execution time
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}[INFO]${NC} Build process completed"
    echo -e "${GREEN}[INFO]${NC} Total execution time: $(format_duration $TOTAL_DURATION)"
    echo -e "${GREEN}[INFO]${NC} File creation time: $(format_duration $TOTAL_CREATION_TIME)"
    echo -e "${GREEN}[INFO]${NC} Script execution time: $(format_duration $TOTAL_EXECUTION_TIME)"
    echo -e "${GREEN}[INFO]${NC} Successfully processed: $processed_count"
    echo -e "${GREEN}[INFO]${NC} Errors encountered: $error_count"
    echo -e "${BLUE}========================================${NC}"
    
    if [[ $error_count -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [--silent]"
    echo ""
    echo "Options:"
    echo "  --silent    Execute without verbose logging, only show final summary"
    echo "  -h, --help  Show this help message"
    echo ""
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --silent)
                SILENT_MODE=true
                shift
                ;;
            -h|--help)
                show_usage
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                ;;
        esac
    done
}

# Start the main function
parse_args "$@"

if [[ -f "$ARCH_OUTPUT" ]]; then
    main
else
    log_error "File not found: $ARCH_OUTPUT"
    exit 1
fi