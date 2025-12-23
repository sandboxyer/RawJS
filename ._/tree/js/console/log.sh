#!/bin/bash

# log.sh - Parses console.log() statements and converts them to assembly code
# Enhanced version with support for all basic types

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_FILE="../../../build_output.asm"

if [ ! -f "log_input" ]; then
    echo "Error: log_input file not found in $(pwd)"
    exit 1
fi

LOG_STATEMENT=$(cat log_input | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Extract the content inside console.log()
CONTENT="${LOG_STATEMENT#console.log(}"
CONTENT="${CONTENT%);}"

# Generate a unique label
LOG_LABEL="log_$(date +%s%N | md5sum | cut -c1-8)"

# Function to escape strings for NASM
escape_for_nasm() {
    local str="$1"
    
    # If empty string, return 0
    if [ -z "$str" ]; then
        echo "0"
        return
    fi
    
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
            if [ "$char" = "'" ]; then
                result="${result}''"
            else
                result="${result}${char}"
            fi
            i=$((i+1))
        fi
    done
    
    # Clean up
    if [[ "$result" == "', "* ]] && [[ "$result" == *", '" ]]; then
        result="${result:3}"
        result="${result%\", \"}"
        echo "'${result}', 0"
    elif [[ "$result" == "', "* ]]; then
        result="${result:3}"
        echo "'${result}', 0"
    elif [[ "$result" == *", '" ]]; then
        result="${result%\", \"}"
        echo "'${result}', 0"
    else
        echo "'${result}', 0"
    fi
}

# Function to check if a string is a number (integer or float)
is_number() {
    local str="$1"
    # Check for integer or float (including negative numbers)
    if [[ "$str" =~ ^-?[0-9]+$ ]] || [[ "$str" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to generate string constants
generate_string_constants() {
    local args="$1"
    
    if [ -z "$args" ]; then
        return
    fi
    
    # Parse arguments
    IFS=',' read -ra ARGS <<< "$args"
    
    for i in "${!ARGS[@]}"; do
        local arg=$(echo "${ARGS[$i]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Check what type of argument this is
        case "$arg" in
            # Boolean values
            "true")
                echo "    ${LOG_LABEL}_bool${i} db 'true', 0"
                ;;
            "false")
                echo "    ${LOG_LABEL}_bool${i} db 'false', 0"
                ;;
            # Null
            "null")
                echo "    ${LOG_LABEL}_null${i} db 'null', 0"
                ;;
            # Undefined
            "undefined")
                echo "    ${LOG_LABEL}_undef${i} db 'undefined', 0"
                ;;
            # String literals
            \'*\' | \"*\" | \`*\`)
                # Remove surrounding quotes for processing
                local stripped="${arg:1:${#arg}-2}"
                local nasm_string=$(escape_for_nasm "$stripped")
                echo "    ${LOG_LABEL}_str${i} db $nasm_string"
                ;;
            # Numbers (integers and floats)
            *)
                if is_number "$arg"; then
                    # For integers, we don't need a string constant
                    # For floats, we need to create a string representation
                    if [[ "$arg" =~ \. ]]; then
                        echo "    ${LOG_LABEL}_float${i} db '$arg', 0"
                    fi
                else
                    # Assume it's a variable or expression
                    # Check if it's a simple variable name
                    if [[ "$arg" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                        # It's a variable, no string constant needed
                        :
                    else
                        # It's an expression, evaluate it
                        local result=$(echo "$arg" | bc 2>/dev/null || echo "0")
                        if [[ "$result" =~ \. ]]; then
                            echo "    ${LOG_LABEL}_expr${i} db '$result', 0"
                        fi
                    fi
                fi
                ;;
        esac
    done
}

# Function to generate assembly code for a single argument
generate_assembly_for_arg() {
    local arg="$1"
    local arg_index="$2"
    local trimmed_arg=$(echo "$arg" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    case "$trimmed_arg" in
        # Boolean values
        "true")
            echo "    mov rsi, ${LOG_LABEL}_bool${arg_index}"
            echo "    call print_str"
            ;;
        "false")
            echo "    mov rsi, ${LOG_LABEL}_bool${arg_index}"
            echo "    call print_str"
            ;;
        # Null
        "null")
            echo "    mov rsi, ${LOG_LABEL}_null${arg_index}"
            echo "    call print_str"
            ;;
        # Undefined
        "undefined")
            echo "    mov rsi, ${LOG_LABEL}_undef${arg_index}"
            echo "    call print_str"
            ;;
        # String literals
        \'*\' | \"*\" | \`*\`)
            echo "    mov rsi, ${LOG_LABEL}_str${arg_index}"
            echo "    call print_str"
            ;;
        # Numbers
        *)
            if is_number "$trimmed_arg"; then
                # Check if it's a float
                if [[ "$trimmed_arg" =~ \. ]]; then
                    # Float - print as string
                    echo "    mov rsi, ${LOG_LABEL}_float${arg_index}"
                    echo "    call print_str"
                else
                    # Integer - print as number
                    echo "    mov rax, $trimmed_arg"
                    echo "    call print_num"
                fi
            else
                # Check if it's a mathematical expression
                if [[ "$trimmed_arg" =~ [+*/-] ]] && [[ ! "$trimmed_arg" =~ ['"\`'] ]]; then
                    # Evaluate the expression
                    local result=$(echo "$trimmed_arg" | bc 2>/dev/null || echo "0")
                    # Check if result is float
                    if [[ "$result" =~ \. ]]; then
                        echo "    mov rsi, ${LOG_LABEL}_expr${arg_index}"
                        echo "    call print_str"
                    else
                        echo "    mov rax, $result"
                        echo "    call print_num"
                    fi
                else
                    # Assume it's a variable
                    # Remove any surrounding quotes that might have been missed
                    local var_name=$(echo "$trimmed_arg" | sed "s/^['\"]//;s/['\"]\$//")
                    
                    # Check if it's a valid variable name
                    if [[ "$var_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                        echo "    mov rax, [$var_name]"
                        echo "    call print_num"
                    else
                        # If not a valid variable name, try to treat as number
                        if [[ "$var_name" =~ ^[0-9]+$ ]]; then
                            echo "    mov rax, $var_name"
                            echo "    call print_num"
                        else
                            # Default to 0
                            echo "    mov rax, 0"
                            echo "    call print_num"
                        fi
                    fi
                fi
            fi
            ;;
    esac
}

# Function to generate the console.log assembly code
generate_console_log_code() {
    echo "; === Generated console.log ==="
    
    if [ -z "$CONTENT" ]; then
        # Empty console.log()
        echo "; Empty console.log"
        generate_newline
        return
    fi
    
    # Check if there are multiple arguments
    if [[ "$CONTENT" == *","* ]]; then
        # Multiple arguments
        IFS=',' read -ra ARGS <<< "$CONTENT"
        
        for i in "${!ARGS[@]}"; do
            generate_assembly_for_arg "${ARGS[$i]}" "$i"
        done
    else
        # Single argument
        generate_assembly_for_arg "$CONTENT" "0"
    fi
    
    # Add newline after each console.log
    generate_newline
}

# Function to generate print newline code
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

# Main execution
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: $OUTPUT_FILE not found"
    exit 1
fi

# Generate the data section content
STRING_CONSTANTS=$(generate_string_constants "$CONTENT")

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