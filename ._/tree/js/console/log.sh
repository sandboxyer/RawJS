#!/bin/bash

# log.sh - Parses console.log() statements and converts them to assembly code
# Usage: ./log.sh (run from directory containing log_input file)

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Target assembly file
OUTPUT_FILE="../../../build_output.asm"

# Check if log_input file exists
if [ ! -f "log_input" ]; then
    echo "Error: log_input file not found in $(pwd)"
    exit 1
fi

# Read the console.log statement
LOG_STATEMENT=$(cat log_input | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Extract the content inside console.log()
# Remove "console.log(" from start and ");" from end
CONTENT="${LOG_STATEMENT#console.log(}"
CONTENT="${CONTENT%);}"

# Generate a unique label for this log statement
LOG_LABEL="log_$(date +%s%N | md5sum | cut -c1-8)"

# Function to convert escape sequences to NASM format
escape_for_nasm() {
    local str="$1"
    
    # Convert escape sequences to their character values
    local result=""
    local i=0
    local len=${#str}
    
    while [ $i -lt $len ]; do
        local char="${str:$i:1}"
        
        if [ "$char" = "\\" ] && [ $((i+1)) -lt $len ]; then
            local next_char="${str:$((i+1)):1}"
            case "$next_char" in
                n)  result="${result}', 10, '" ;;
                t)  result="${result}', 9, '" ;;
                r)  result="${result}', 13, '" ;;
                \\\\) result="${result}', 92, '" ;;
                \") result="${result}', 34, '" ;;
                \') result="${result}', 39, '" ;;
                *)  result="${result}${char}${next_char}" ;;
            esac
            i=$((i+2))
        else
            # Escape single quotes for NASM
            if [ "$char" = "'" ]; then
                result="${result}''"
            else
                result="${result}${char}"
            fi
            i=$((i+1))
        fi
    done
    
    # Clean up the result - handle edge cases
    if [ -z "$result" ]; then
        echo "0"
    elif [[ "$result" == "', "* ]] && [[ "$result" == *", '" ]]; then
        # Result starts and ends with quote-comma pattern
        result="${result:3}"
        result="${result%\", \"}"
        echo "'${result}', 0"
    elif [[ "$result" == "', "* ]]; then
        # Result starts with quote-comma pattern
        result="${result:3}"
        echo "'${result}', 0"
    elif [[ "$result" == *", '" ]]; then
        # Result ends with comma-quote pattern
        result="${result%\", \"}"
        echo "'${result}', 0"
    else
        echo "'${result}', 0"
    fi
}

# Function to generate NASM string from content
generate_nasm_string() {
    local content="$1"
    
    # Remove surrounding quotes if present
    if [[ "$content" =~ ^\'.*\'$ ]]; then
        content="${content:1:${#content}-2}"
    elif [[ "$content" =~ ^\".*\"$ ]]; then
        content="${content:1:${#content}-2}"
    elif [[ "$content" =~ ^\`.*\`$ ]]; then
        content="${content:1:${#content}-2}"
    fi
    
    # If content is empty, just return null terminator
    if [ -z "$content" ]; then
        echo "0"
        return
    fi
    
    # Escape for NASM
    local nasm_string=$(escape_for_nasm "$content")
    echo "$nasm_string"
}

# Function to parse and generate assembly for a single argument
generate_assembly_for_arg() {
    local arg="$1"
    local arg_index="$2"
    local trimmed_arg=$(echo "$arg" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Check if it's a string (single quotes, double quotes, or backticks)
    if [[ "$trimmed_arg" =~ ^\'.*\'$ ]] || [[ "$trimmed_arg" =~ ^\".*\"$ ]] || [[ "$trimmed_arg" =~ ^\`.*\`$ ]]; then
        # It's a string literal
        echo "    mov rsi, ${LOG_LABEL}_str${arg_index}"
        echo "    call print_str"
        
    # Check if it's a template literal with ${}
    elif [[ "$trimmed_arg" =~ ^\`.*\$\{.*\}.*\`$ ]]; then
        # Template literal - we'll handle simple cases only
        echo "    mov rsi, ${LOG_LABEL}_tmpl${arg_index}"
        echo "    call print_str"
        
    # Check if it's a mathematical expression (contains +, -, *, /)
    elif [[ "$trimmed_arg" =~ [+*/-] ]] && [[ ! "$trimmed_arg" =~ ['"\`'] ]]; then
        # Mathematical expression - evaluate it
        local result=$(echo "$trimmed_arg" | bc 2>/dev/null || echo "0")
        echo "    mov rax, $result"
        echo "    call print_num"
        
    else
        # Assume it's a variable name
        local var_name=$(echo "$trimmed_arg" | sed "s/^['\"]//;s/['\"]\$//")
        
        # Check if it's actually a string literal that wasn't caught above
        if [[ "$var_name" == "$trimmed_arg" ]] && [[ ! "$var_name" =~ ^[0-9]+$ ]]; then
            # It's a variable reference
            echo "    mov rax, [$var_name]"
            echo "    call print_num"
        else
            # It's probably a number or simple value
            echo "    mov rax, $var_name"
            echo "    call print_num"
        fi
    fi
}

# Function to generate string constants for arguments
generate_string_constants() {
    if [[ "$CONTENT" == *","* ]]; then
        # Multiple arguments
        IFS=',' read -ra ARGS <<< "$CONTENT"
        
        for i in "${!ARGS[@]}"; do
            local trimmed_arg=$(echo "${ARGS[$i]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Only generate constants for string literals
            if [[ "$trimmed_arg" =~ ^\'.*\'$ ]] || [[ "$trimmed_arg" =~ ^\".*\"$ ]] || [[ "$trimmed_arg" =~ ^\`.*\`$ ]]; then
                local nasm_string=$(generate_nasm_string "$trimmed_arg")
                echo "    ${LOG_LABEL}_str$i db $nasm_string"
            elif [[ "$trimmed_arg" =~ ^\`.*\$\{.*\}.*\`$ ]]; then
                local string_content="${trimmed_arg:1:${#trimmed_arg}-2}"
                string_content=$(echo "$string_content" | sed 's/\${[^}]*}//g')
                local nasm_string=$(generate_nasm_string "'$string_content'")
                echo "    ${LOG_LABEL}_tmpl$i db $nasm_string"
            fi
        done
    else
        # Single argument
        if [[ "$CONTENT" =~ ^\'.*\'$ ]] || [[ "$CONTENT" =~ ^\".*\"$ ]] || [[ "$CONTENT" =~ ^\`.*\`$ ]]; then
            local nasm_string=$(generate_nasm_string "$CONTENT")
            echo "    ${LOG_LABEL}_str db $nasm_string"
        elif [[ "$CONTENT" =~ ^\`.*\$\{.*\}.*\`$ ]]; then
            local string_content="${CONTENT:1:${#CONTENT}-2}"
            string_content=$(echo "$string_content" | sed 's/\${[^}]*}//g')
            local nasm_string=$(generate_nasm_string "'$string_content'")
            echo "    ${LOG_LABEL}_tmpl db $nasm_string"
        fi
    fi
}

# Function to generate the print newline code
generate_newline() {
    cat << 'EOF'
    ; Print newline after console.log
    mov rsi, newline
    call print_str
EOF
}

# Function to check and add newline constant
ensure_newline_constant() {
    if ! grep -q "newline db 10, 0" "$OUTPUT_FILE"; then
        echo ""
        echo "    ; Newline constant for console.log"
        echo "    newline db 10, 0"
    fi
}

# Parse the console.log content and generate assembly code
generate_console_log_code() {
    echo "; === Generated console.log ==="
    
    if [[ "$CONTENT" == *","* ]]; then
        # Multiple arguments
        IFS=',' read -ra ARGS <<< "$CONTENT"
        
        for i in "${!ARGS[@]}"; do
            generate_assembly_for_arg "${ARGS[$i]}" "$i"
        done
    else
        # Single argument
        generate_assembly_for_arg "$CONTENT" ""
    fi
    
    # Add newline after each console.log
    generate_newline
}

# Main execution
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: $OUTPUT_FILE not found"
    exit 1
fi

# Generate the data section content
STRING_CONSTANTS=$(generate_string_constants)

# Generate the code section content
CONSOLE_CODE=$(generate_console_log_code)

# Create temporary file
TEMP_FILE=$(mktemp)

# Check if newline constant exists
HAS_NEWLINE_CONSTANT=$(grep -c "newline db 10, 0" "$OUTPUT_FILE")

# Read the original file and insert at appropriate places
IN_DATA_SECTION=0
IN_START_SECTION=0
CODE_INSERTED=0
DATA_INSERTED=0

while IFS= read -r line; do
    # Check if we're entering the data section
    if [[ "$line" == "section .data" ]]; then
        IN_DATA_SECTION=1
        echo "$line" >> "$TEMP_FILE"
        continue
    fi
    
    # Check if we're leaving the data section
    if [[ "$IN_DATA_SECTION" -eq 1 ]] && [[ "$line" == "section ."* ]]; then
        # We're leaving data section, insert our constants before leaving
        if [ -n "$STRING_CONSTANTS" ] && [ "$DATA_INSERTED" -eq 0 ]; then
            echo "" >> "$TEMP_FILE"
            echo "    ; === Generated by log.sh ===" >> "$TEMP_FILE"
            echo "$STRING_CONSTANTS" >> "$TEMP_FILE"
            DATA_INSERTED=1
        fi
        
        # Add newline constant if needed
        if [ "$HAS_NEWLINE_CONSTANT" -eq 0 ]; then
            echo "" >> "$TEMP_FILE"
            echo "    ; Newline constant for console.log" >> "$TEMP_FILE"
            echo "    newline db 10, 0" >> "$TEMP_FILE"
            HAS_NEWLINE_CONSTANT=1
        fi
        
        IN_DATA_SECTION=0
    fi
    
    # Check if we're entering _start section
    if [[ "$line" == "_start:" ]]; then
        IN_START_SECTION=1
    fi
    
    # Find a good place to insert console.log code
    # Look for lines that look like exit code
    if [[ "$IN_START_SECTION" -eq 1 ]] && 
       [[ "$CODE_INSERTED" -eq 0 ]] && 
       [[ "$line" =~ ^[[:space:]]*mov[[:space:]]+rax,[[:space:]]*60 ]] &&
       [ -n "$CONSOLE_CODE" ]; then
        # Insert our generated code before the exit
        echo "" >> "$TEMP_FILE"
        echo "$CONSOLE_CODE" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        CODE_INSERTED=1
    fi
    
    # Write the current line
    echo "$line" >> "$TEMP_FILE"
    
done < "$OUTPUT_FILE"

# If we never found the exit syscall, append at the end
if [[ "$CODE_INSERTED" -eq 0 ]] && [ -n "$CONSOLE_CODE" ]; then
    echo "" >> "$TEMP_FILE"
    echo "$CONSOLE_CODE" >> "$TEMP_FILE"
fi

# If we're still in data section at EOF, append constants
if [[ "$IN_DATA_SECTION" -eq 1 ]] && [ -n "$STRING_CONSTANTS" ] && [ "$DATA_INSERTED" -eq 0 ]; then
    echo "" >> "$TEMP_FILE"
    echo "    ; === Generated by log.sh ===" >> "$TEMP_FILE"
    echo "$STRING_CONSTANTS" >> "$TEMP_FILE"
    
    # Add newline constant if needed
    if [ "$HAS_NEWLINE_CONSTANT" -eq 0 ]; then
        echo "" >> "$TEMP_FILE"
        echo "    ; Newline constant for console.log" >> "$TEMP_FILE"
        echo "    newline db 10, 0" >> "$TEMP_FILE"
    fi
fi

# Replace the original file
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "Successfully appended console.log assembly code to $OUTPUT_FILE"
echo "Parsed statement: $LOG_STATEMENT"