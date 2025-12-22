#!/bin/bash

# build.sh - Processes ../arch_output file with tag-based content execution
# Added execution time tracking with --silent option

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

# Function to check if .asm file exists OR binary exists
check_asm_exists() {
    local asm_file="$1"
    
    # Check for .asm file
    if [[ -f "$asm_file" ]]; then
        echo "asm"
        return 0
    # Check for binary (without .asm extension)
    elif [[ -f "${asm_file%.asm}" ]]; then
        echo "binary"
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

# Function to handle JavaScript-like content
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
        local asm_file="${JS_DIR}${declaration_type}.asm"
        local binary_file="${JS_DIR}${declaration_type}"
        
        if create_temp_file "$input_file" "$content"; then
            local file_type
            file_type=$(check_asm_exists "$asm_file")
            if [[ -n "$file_type" ]]; then
                if [[ "$file_type" == "asm" ]]; then
                    # Execute .asm file with basm.sh
                    if execute_basm "$input_file" "$asm_file"; then
                        processed_count=$((processed_count + 1))
                    else
                        error_count=$((error_count + 1))
                    fi
                elif [[ "$file_type" == "binary" ]]; then
                    # Execute binary directly
                    if execute_binary "$input_file" "$binary_file"; then
                        processed_count=$((processed_count + 1))
                    else
                        error_count=$((error_count + 1))
                    fi
                fi
            else
                log_error "ASM file or binary not found: $asm_file or $binary_file"
                error_count=$((error_count + 1))
            fi
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
        local asm_file="${dir_path}${file_name}.asm"
        local binary_file="${dir_path}${file_name}"
        
        if [[ "$SILENT_MODE" == false ]]; then
            log_info "Checking for ASM file or binary: $asm_file or $binary_file"
        fi
        
        local file_type
        file_type=$(check_asm_exists "$asm_file")
        if [[ -n "$file_type" ]]; then
            if create_temp_file "$input_file" "$content"; then
                if [[ "$file_type" == "asm" ]]; then
                    # Execute .asm file with basm.sh
                    if execute_basm "$input_file" "$asm_file"; then
                        processed_count=$((processed_count + 1))
                        return
                    else
                        error_count=$((error_count + 1))
                        return
                    fi
                elif [[ "$file_type" == "binary" ]]; then
                    # Execute binary directly
                    if execute_binary "$input_file" "$binary_file"; then
                        processed_count=$((processed_count + 1))
                        return
                    else
                        error_count=$((error_count + 1))
                        return
                    fi
                fi
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
    local asm_file="${JS_DIR}call.asm"
    local binary_file="${JS_DIR}call"
    
    if create_temp_file "$input_file" "$content"; then
        local file_type
        file_type=$(check_asm_exists "$asm_file")
        if [[ -n "$file_type" ]]; then
            if [[ "$file_type" == "asm" ]]; then
                # Execute .asm file with basm.sh
                if execute_basm "$input_file" "$asm_file"; then
                    processed_count=$((processed_count + 1))
                else
                    error_count=$((error_count + 1))
                fi
            elif [[ "$file_type" == "binary" ]]; then
                # Execute binary directly
                if execute_binary "$input_file" "$binary_file"; then
                    processed_count=$((processed_count + 1))
                else
                    error_count=$((error_count + 1))
                fi
            fi
        else
            log_error "Fallback ASM file or binary not found: $asm_file or $binary_file"
            error_count=$((error_count + 1))
        fi
    else
        error_count=$((error_count + 1))
    fi
}

# Function to handle chain blocks
handle_chain_block() {
    local content="$1"
    
    if [[ "$SILENT_MODE" == false ]]; then
        log_info "Processing chain block (length: ${#content})"
    fi
    
    # Create chain input file with _input suffix
    local input_file="${CHAIN_DIR}chain_input"
    local asm_file="${CHAIN_DIR}chain.asm"
    local binary_file="${CHAIN_DIR}chain"
    
    if create_temp_file "$input_file" "$content"; then
        local file_type
        file_type=$(check_asm_exists "$asm_file")
        if [[ -n "$file_type" ]]; then
            if [[ "$file_type" == "asm" ]]; then
                # Execute .asm file with basm.sh
                if execute_basm "$input_file" "$asm_file"; then
                    processed_count=$((processed_count + 1))
                else
                    error_count=$((error_count + 1))
                fi
            elif [[ "$file_type" == "binary" ]]; then
                # Execute binary directly
                if execute_binary "$input_file" "$binary_file"; then
                    processed_count=$((processed_count + 1))
                else
                    error_count=$((error_count + 1))
                fi
            fi
        else
            log_error "Chain ASM file or binary not found: $asm_file or $binary_file"
            error_count=$((error_count + 1))
        fi
    else
        error_count=$((error_count + 1))
    fi
}

# Function to extract complete chain block including outer tags
extract_chain_block() {
    local content="$1"
    local start_pos="$2"
    
    local depth=1
    local pos=$((start_pos + 13))  # Skip past the opening <chain-start>
    local content_length=${#content}
    local block_start=$start_pos
    
    while [[ $pos -lt $content_length ]]; do
        # Check for <chain-start>
        if [[ "${content:$pos:13}" == "<chain-start>" ]]; then
            depth=$((depth + 1))
            pos=$((pos + 13))
        # Check for <chain-end>
        elif [[ "${content:$pos:11}" == "<chain-end>" ]]; then
            depth=$((depth - 1))
            if [[ $depth -eq 0 ]]; then
                # Found the matching closing tag
                local block_end=$((pos + 11))
                # Extract the complete block including outer tags
                echo "${content:block_start:$((block_end - block_start))}"
                return 0
            fi
            pos=$((pos + 11))
        else
            pos=$((pos + 1))
        fi
    done
    
    echo ""
    return 1
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
    
    # Read the entire file content
    local file_content
    file_content=$(cat "$ARCH_OUTPUT")
    local content_length=${#file_content}
    local pos=0
    
    if [[ "$SILENT_MODE" == false ]]; then
        log_info "Processing ${content_length} characters of input"
    fi
    
    # Process the file
    while [[ $pos -lt $content_length ]]; do
        # Look for the next opening tag from current position
        local next_js=${file_content:$pos}
        local js_index=$(echo "$next_js" | grep -b -o "<js-start>" | head -1 | cut -d: -f1 2>/dev/null || echo "")
        
        local next_chain=${file_content:$pos}
        local chain_index=$(echo "$next_chain" | grep -b -o "<chain-start>" | head -1 | cut -d: -f1 2>/dev/null || echo "")
        
        # Convert to absolute positions
        local js_pos=-1
        local chain_pos=-1
        
        if [[ -n "$js_index" && "$js_index" =~ ^[0-9]+$ ]]; then
            js_pos=$((pos + js_index))
        fi
        
        if [[ -n "$chain_index" && "$chain_index" =~ ^[0-9]+$ ]]; then
            chain_pos=$((pos + chain_index))
        fi
        
        # Determine which tag comes first
        if [[ $js_pos -ge 0 && ( $chain_pos -lt 0 || $js_pos -lt $chain_pos ) ]]; then
            # Process JS tag
            pos=$js_pos
            
            # Find matching js-end
            local remaining="${file_content:$pos}"
            local js_end_index=$(echo "$remaining" | grep -b -o "<js-end>" | head -1 | cut -d: -f1 2>/dev/null || echo "")
            
            if [[ -z "$js_end_index" ]]; then
                log_error "Unclosed <js-start> tag at position $pos"
                error_count=$((error_count + 1))
                break
            fi
            
            local js_end_pos=$((pos + js_end_index))
            local content_start=$((pos + 10))
            local content_end=$js_end_pos
            local js_content="${file_content:content_start:$((content_end - content_start))}"
            
            # Trim whitespace
            js_content=$(echo "$js_content" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            
            if [[ -n "$js_content" ]]; then
                handle_js_content "$js_content"
            fi
            
            pos=$((js_end_pos + 7))
            
        elif [[ $chain_pos -ge 0 && ( $js_pos -lt 0 || $chain_pos -lt $js_pos ) ]]; then
            # Process chain tag
            pos=$chain_pos
            
            # Extract the complete chain block
            local chain_block
            chain_block=$(extract_chain_block "$file_content" "$pos")
            
            if [[ -z "$chain_block" ]]; then
                log_error "Unclosed <chain-start> tag at position $pos"
                error_count=$((error_count + 1))
                break
            fi
            
            # Process the chain block
            handle_chain_block "$chain_block"
            
            # Move past the entire block
            pos=$((pos + ${#chain_block}))
            
        else
            # No more tags found
            break
        fi
    done
    
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