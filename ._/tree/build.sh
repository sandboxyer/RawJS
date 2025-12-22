#!/bin/bash

# build.sh - Processes ../arch_output file with tag-based content execution

# Set strict mode for better error handling
set -euo pipefail

# Configuration
ARCH_OUTPUT="../arch_output"
BASH_RUNNER="../basm/basm.sh"
JS_DIR="js/"
CHAIN_DIR="chain/"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize counters
processed_count=0
error_count=0

# Function to log messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
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

# Function to check if .asm file exists
check_asm_exists() {
    local asm_file="$1"
    
    if [[ -f "$asm_file" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to create temporary content file
create_temp_file() {
    local file_path="$1"
    local content="$2"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$file_path")"
    
    # Write content to file
    echo -n "$content" > "$file_path"
    
    if [[ $? -eq 0 ]]; then
        log_info "Created file: $file_path"
        return 0
    else
        log_error "Failed to create file: $file_path"
        return 1
    fi
}

# Function to execute basm.sh and wait for completion
execute_basm() {
    local asm_file="$1"
    
    if [[ ! -f "$asm_file" ]]; then
        log_error "ASM file not found: $asm_file"
        return 1
    fi
    
    log_info "Executing: bash $BASH_RUNNER $asm_file"
    
    # Execute with bash command and wait for completion
    if bash "$BASH_RUNNER" "$asm_file"; then
        log_info "Execution completed successfully"
        return 0
    else
        local exit_code=$?
        log_error "Execution failed with exit code: $exit_code"
        return $exit_code
    fi
}

# Function to handle JavaScript-like content
handle_js_content() {
    local content="$1"
    
    log_info "Processing JS content: ${content:0:50}..."
    
    # Step 1: Check for declarations
    local declaration_type
    declaration_type=$(is_declaration "$content")
    
    if [[ -n "$declaration_type" ]]; then
        # Declaration detected
        log_info "Processing declaration: $declaration_type"
        
        # Create declaration file
        local decl_file="${JS_DIR}${declaration_type}"
        local asm_file="${decl_file}.asm"
        
        if create_temp_file "$decl_file" "$content"; then
            if check_asm_exists "$asm_file"; then
                if execute_basm "$asm_file"; then
                    processed_count=$((processed_count + 1))
                else
                    error_count=$((error_count + 1))
                fi
            else
                log_error "ASM file not found: $asm_file"
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
        
        local target_file="${dir_path}${file_name}"
        local asm_file="${target_file}.asm"
        
        log_info "Checking for ASM file: $asm_file"
        
        if check_asm_exists "$asm_file"; then
            if create_temp_file "$target_file" "$content"; then
                if execute_basm "$asm_file"; then
                    processed_count=$((processed_count + 1))
                    return
                else
                    error_count=$((error_count + 1))
                    return
                fi
            else
                error_count=$((error_count + 1))
                return
            fi
        fi
    fi
    
    # Step 3: Fallback
    log_warn "No specific handler found, using fallback"
    local fallback_file="${JS_DIR}call"
    local fallback_asm="${fallback_file}.asm"
    
    if create_temp_file "$fallback_file" "$content"; then
        if check_asm_exists "$fallback_asm"; then
            if execute_basm "$fallback_asm"; then
                processed_count=$((processed_count + 1))
            else
                error_count=$((error_count + 1))
            fi
        else
            log_error "Fallback ASM file not found: $fallback_asm"
            error_count=$((error_count + 1))
        fi
    else
        error_count=$((error_count + 1))
    fi
}

# Function to handle chain blocks
handle_chain_block() {
    local content="$1"
    
    log_info "Processing chain block (length: ${#content})"
    
    local chain_file="${CHAIN_DIR}chain"
    local asm_file="${chain_file}.asm"
    
    if create_temp_file "$chain_file" "$content"; then
        if check_asm_exists "$asm_file"; then
            if execute_basm "$asm_file"; then
                processed_count=$((processed_count + 1))
            else
                error_count=$((error_count + 1))
            fi
        else
            log_error "Chain ASM file not found: $asm_file"
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
    log_info "Starting build process..."
    log_info "Reading from: $ARCH_OUTPUT"
    
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
    
    log_info "Processing ${content_length} characters of input"
    
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
    
    # Print summary
    echo ""
    log_info "Build process completed"
    log_info "Successfully processed: $processed_count"
    log_info "Errors encountered: $error_count"
    
    if [[ $error_count -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Alternative line-by-line processing for simpler cases
process_file_simple() {
    local in_chain=false
    local chain_depth=0
    local chain_content=""
    local chain_start_line=0
    
    local line_number=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_number=$((line_number + 1))
        
        if [[ $in_chain == true ]]; then
            chain_content+="$line"$'\n'
            
            # Count chain-start tags in this line
            while [[ "$line" =~ "<chain-start>" ]]; do
                chain_depth=$((chain_depth + 1))
                line="${line#*<chain-start>}"
            done
            
            # Count chain-end tags in this line
            while [[ "$line" =~ "<chain-end>" ]]; do
                chain_depth=$((chain_depth - 1))
                if [[ $chain_depth -eq 0 ]]; then
                    # Found matching chain-end
                    log_info "Found complete chain block (started at line $chain_start_line)"
                    handle_chain_block "$chain_content"
                    in_chain=false
                    chain_content=""
                    break
                fi
                line="${line#*<chain-end>}"
            done
            
            continue
        fi
        
        # Check for chain-start on its own line
        if [[ "$line" =~ "<chain-start>" ]]; then
            in_chain=true
            chain_depth=1
            chain_start_line=$line_number
            chain_content="$line"$'\n'
        # Check for single-line JS tags
        elif [[ "$line" =~ "<js-start>" ]] && [[ "$line" =~ "<js-end>" ]]; then
            local content="${line#*<js-start>}"
            content="${content%<js-end>*}"
            content=$(echo "$content" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            
            if [[ -n "$content" ]]; then
                handle_js_content "$content"
            fi
        fi
    done < "$ARCH_OUTPUT"
    
    if [[ $in_chain == true ]]; then
        log_error "Unclosed chain block started at line $chain_start_line"
        error_count=$((error_count + 1))
    fi
}

# Try the main function
if [[ -f "$ARCH_OUTPUT" ]]; then
    main
else
    log_error "File not found: $ARCH_OUTPUT"
    exit 1
fi