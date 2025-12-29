#!/bin/bash

# log.sh - Parses console.log() statements and converts them to assembly code
# Updated for the new print function that detects types

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_FILE="../../../build_output.asm"
TYPE_REGISTRY="var_types.txt"

if [ ! -f "log_input" ]; then
    echo "Error: log_input file not found in $(pwd)"
    exit 1
fi

LOG_STATEMENT=$(cat log_input | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Remove trailing semicolon if present
LOG_STATEMENT="${LOG_STATEMENT%;}"

# Extract the content inside console.log()
if [[ "$LOG_STATEMENT" =~ console\.log\((.*)\) ]]; then
    CONTENT="${BASH_REMATCH[1]}"
else
    echo "Error: Invalid console.log statement format"
    exit 1
fi

# Generate a unique label
LOG_LABEL="log_$(date +%s%N | md5sum | cut -c1-8)"

# Function to get variable type from registry
get_variable_type() {
    local var_name="$1"
    
    if [ ! -f "$TYPE_REGISTRY" ]; then
        echo "unknown"
        return
    fi
    
    # Get the most recent entry for this variable
    local type_info=$(grep "^$var_name:" "$TYPE_REGISTRY" | tail -1)
    
    if [ -z "$type_info" ]; then
        echo "unknown"
    else
        echo "$type_info" | cut -d: -f2
    fi
}

# Function to get variable value from registry
get_variable_value() {
    local var_name="$1"
    
    if [ ! -f "$TYPE_REGISTRY" ]; then
        echo ""
        return
    fi
    
    local type_info=$(grep "^$var_name:" "$TYPE_REGISTRY" | tail -1)
    
    if [ -z "$type_info" ]; then
        echo ""
    else
        # Get everything after the second colon
        echo "$type_info" | cut -d: -f3-
    fi
}

# Function to escape strings for NASM
escape_for_nasm() {
    local str="$1"
    
    if [ -z "$str" ]; then
        echo "0"
        return
    fi
    
    local result=""
    local i=0
    local len=${#str}
    
    while [ $i -lt $len ]; do
        local char="${str:$i:1}"
        local char_code=$(printf "%d" "'$char")
        
        if [ "$char" = "\\" ] && [ $((i+1)) -lt $len ]; then
            local next_char="${str:$((i+1)):1}"
            case "$next_char" in
                n)  result="${result}10, " ;;
                t)  result="${result}9, " ;;
                r)  result="${result}13, " ;;
                \\\\) result="${result}92, " ;;
                \") result="${result}34, " ;;
                \') result="${result}39, " ;;
                *)  result="${result}92, ${next_char}, " ;;
            esac
            i=$((i+2))
        else
            if [ $char_code -lt 128 ]; then
                result="${result}${char_code}, "
            fi
            i=$((i+1))
        fi
    done
    
    result="${result%, }"
    if [ -n "$result" ]; then
        echo "${result}, 0"
    else
        echo "0"
    fi
}

# Function to generate string constants
generate_string_constants() {
    local args="$1"
    
    if [ -z "$args" ]; then
        return
    fi
    
    local constants=""
    
    # Parse arguments - handle quoted strings with commas inside
    local in_quotes=false
    local quote_char=""
    local current_arg=""
    local args_array=()
    
    for (( i=0; i<${#args}; i++ )); do
        local char="${args:$i:1}"
        local prev_char="${args:$((i-1)):1}" 2>/dev/null || true
        
        if [[ "$char" =~ [\"\'] ]] && [[ "$prev_char" != "\\" ]]; then
            if [ "$in_quotes" = false ]; then
                in_quotes=true
                quote_char="$char"
            elif [ "$char" = "$quote_char" ]; then
                in_quotes=false
            fi
        fi
        
        if [ "$char" = "," ] && [ "$in_quotes" = false ]; then
            args_array+=("$(echo "$current_arg" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')")
            current_arg=""
        else
            current_arg="${current_arg}${char}"
        fi
    done
    
    # Add the last argument
    if [ -n "$current_arg" ]; then
        args_array+=("$(echo "$current_arg" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')")
    fi
    
    # Generate constants for each argument
    for i in "${!args_array[@]}"; do
        local arg="${args_array[$i]}"
        
        # Check what type of argument this is
        case "$arg" in
            # Boolean values
            "true")
                constants+="\n    ${LOG_LABEL}_bool${i} db 'true', 0"
                ;;
            "false")
                constants+="\n    ${LOG_LABEL}_bool${i} db 'false', 0"
                ;;
            # Null
            "null")
                constants+="\n    ${LOG_LABEL}_null${i} db 'null', 0"
                ;;
            # Undefined
            "undefined")
                constants+="\n    ${LOG_LABEL}_undef${i} db 'undefined', 0"
                ;;
            # String literals (with quotes)
            \'*\' | \"*\")
                # Remove surrounding quotes
                local stripped="${arg:1:${#arg}-2}"
                local nasm_string=$(escape_for_nasm "$stripped")
                constants+="\n    ${LOG_LABEL}_str${i} db $nasm_string"
                ;;
            # Numbers (integers and floats)
            *)
                # Check if it's a number
                if [[ "$arg" =~ ^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$ ]] && [[ ! "$arg" =~ ^-?0[0-9]+ ]]; then
                    # For floats, create string representation
                    if [[ "$arg" =~ \. ]] || [[ "$arg" =~ [eE] ]]; then
                        constants+="\n    ${LOG_LABEL}_num${i} db '$arg', 0"
                    fi
                else
                    # Check if it's a variable
                    if [[ "$arg" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                        # Get variable type
                        local var_type=$(get_variable_type "$arg")
                        
                        case "$var_type" in
                            "float")
                                # Create a string representation of the float
                                local float_value=$(get_variable_value "$arg")
                                constants+="\n    ${LOG_LABEL}_float${i} db '$float_value', 0"
                                ;;
                        esac
                    fi
                fi
                ;;
        esac
    done
    
    echo -e "$constants"
}

# Function to generate assembly code for a single argument
generate_assembly_for_arg() {
    local arg="$1"
    local arg_index="$2"
    
    # Check what type of argument this is
    case "$arg" in
        # Boolean literals
        "true")
            echo "    mov rax, ${LOG_LABEL}_bool${arg_index}"
            echo "    mov rdx, TYPE_STRING"
            echo "    call print"
            ;;
        "false")
            echo "    mov rax, ${LOG_LABEL}_bool${arg_index}"
            echo "    mov rdx, TYPE_STRING"
            echo "    call print"
            ;;
        # Null literal
        "null")
            echo "    mov rax, ${LOG_LABEL}_null${arg_index}"
            echo "    mov rdx, TYPE_STRING"
            echo "    call print"
            ;;
        # Undefined literal
        "undefined")
            echo "    mov rax, ${LOG_LABEL}_undef${arg_index}"
            echo "    mov rdx, TYPE_STRING"
            echo "    call print"
            ;;
        # String literals
        \'*\' | \"*\")
            echo "    mov rax, ${LOG_LABEL}_str${arg_index}"
            echo "    mov rdx, TYPE_STRING"
            echo "    call print"
            ;;
        # Numbers and variables
        *)
            # Check if it's a number
            if [[ "$arg" =~ ^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$ ]] && [[ ! "$arg" =~ ^-?0[0-9]+ ]]; then
                # Check if it's a float
                if [[ "$arg" =~ \. ]] || [[ "$arg" =~ [eE] ]]; then
                    # Float - print as string
                    echo "    mov rax, ${LOG_LABEL}_num${arg_index}"
                    echo "    mov rdx, TYPE_STRING"
                    echo "    call print"
                else
                    # Integer - print as number
                    echo "    mov rax, $arg"
                    echo "    mov rdx, TYPE_NUMBER"
                    echo "    call print"
                fi
            else
                # Assume it's a variable
                local var_name="$arg"
                
                # Get variable type from registry
                local var_type=$(get_variable_type "$var_name")
                
                # Map registry types to print function types
                case "$var_type" in
                    "string")
                        echo "    mov rax, $var_name"
                        echo "    mov rdx, TYPE_STRING"
                        echo "    call print"
                        ;;
                    "integer")
                        echo "    mov rax, [$var_name]"
                        echo "    mov rdx, TYPE_NUMBER"
                        echo "    call print"
                        ;;
                    "float")
                        echo "    mov rax, ${LOG_LABEL}_float${arg_index}"
                        echo "    mov rdx, TYPE_STRING"
                        echo "    call print"
                        ;;
                    "boolean")
                        echo "    ; Boolean variable: $var_name"
                        echo "    mov rax, [$var_name]"
                        echo "    mov rdx, TYPE_BOOLEAN"
                        echo "    call print"
                        ;;
                    "null")
                        echo "    mov rax, ${LOG_LABEL}_null${arg_index}"
                        echo "    mov rdx, TYPE_STRING"
                        echo "    call print"
                        ;;
                    "undefined")
                        echo "    mov rax, ${LOG_LABEL}_undef${arg_index}"
                        echo "    mov rdx, TYPE_STRING"
                        echo "    call print"
                        ;;
                    *)
                        # Unknown type - try to print as string
                        echo "    ; Unknown type for variable: $var_name"
                        echo "    mov rax, $var_name"
                        echo "    mov rdx, TYPE_STRING"
                        echo "    call print"
                        ;;
                esac
            fi
            ;;
    esac
}

# Function to generate the console.log assembly code
generate_console_log_code() {
    local code=""
    
    if [ -z "$CONTENT" ]; then
        # Empty console.log() - just print newline
        echo "    ; Empty console.log"
        echo "    mov rax, newline"
        echo "    mov rdx, TYPE_STRING"
        echo "    call print"
        return
    fi
    
    # Parse arguments
    local in_quotes=false
    local quote_char=""
    local current_arg=""
    local args_array=()
    
    for (( i=0; i<${#CONTENT}; i++ )); do
        local char="${CONTENT:$i:1}"
        local prev_char="${CONTENT:$((i-1)):1}" 2>/dev/null || true
        
        if [[ "$char" =~ [\"\'] ]] && [[ "$prev_char" != "\\" ]]; then
            if [ "$in_quotes" = false ]; then
                in_quotes=true
                quote_char="$char"
            elif [ "$char" = "$quote_char" ]; then
                in_quotes=false
            fi
        fi
        
        if [ "$char" = "," ] && [ "$in_quotes" = false ]; then
            args_array+=("$(echo "$current_arg" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')")
            current_arg=""
        else
            current_arg="${current_arg}${char}"
        fi
    done
    
    # Add the last argument
    if [ -n "$current_arg" ]; then
        args_array+=("$(echo "$current_arg" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')")
    fi
    
    # Generate code for each argument
    for i in "${!args_array[@]}"; do
        generate_assembly_for_arg "${args_array[$i]}" "$i"
        
        # Add space between arguments (except last one)
        if [ $i -lt $((${#args_array[@]} - 1)) ]; then
            echo "    ; Space between arguments"
            echo "    mov rax, space"
            echo "    mov rdx, TYPE_STRING"
            echo "    call print"
        fi
    done
    
    # Add newline after each console.log
    echo "    ; Newline after console.log"
    echo "    mov rax, newline"
    echo "    mov rdx, TYPE_STRING"
    echo "    call print"
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

# Read the original file and insert at appropriate places
IN_DATA_SECTION=0
IN_START_SECTION=0
CODE_INSERTED=0
DATA_INSERTED=0
HAS_NEWLINE_CONSTANT=0
HAS_SPACE_CONSTANT=0
HAS_TYPE_CONSTANTS=0

# First check if constants exist
if grep -q "newline db 10, 0" "$OUTPUT_FILE"; then
    HAS_NEWLINE_CONSTANT=1
fi

if grep -q "space db ' ', 0" "$OUTPUT_FILE"; then
    HAS_SPACE_CONSTANT=1
fi

# Check if type constants exist
if grep -q "TYPE_STRING equ 1" "$OUTPUT_FILE"; then
    HAS_TYPE_CONSTANTS=1
fi

# Check if boolean strings exist
if grep -q "true_str db 'true', 0" "$OUTPUT_FILE"; then
    HAS_TYPE_CONSTANTS=1
fi

while IFS= read -r line; do
    # Check if we're entering the data section
    if [[ "$line" == "section .data" ]]; then
        IN_DATA_SECTION=1
        echo "$line" >> "$TEMP_FILE"
        continue
    fi
    
    # Check if we're leaving the data section
    if [[ "$IN_DATA_SECTION" -eq 1 ]] && [[ "$line" == section* ]]; then
        # We're leaving data section, insert our constants before leaving
        
        # Add type constants if needed
        if [ "$HAS_TYPE_CONSTANTS" -eq 0 ]; then
            echo "    ; Type constants for print function" >> "$TEMP_FILE"
            echo "    TYPE_STRING equ 1" >> "$TEMP_FILE"
            echo "    TYPE_NUMBER equ 2" >> "$TEMP_FILE"
            echo "    TYPE_CHAR    equ 3" >> "$TEMP_FILE"
            echo "    TYPE_BOOLEAN equ 4" >> "$TEMP_FILE"
            echo "    TYPE_NULL    equ 5" >> "$TEMP_FILE"
            echo "    TYPE_UNDEFINED equ 6" >> "$TEMP_FILE"
            echo "" >> "$TEMP_FILE"
            echo "    ; Boolean strings" >> "$TEMP_FILE"
            echo "    true_str db 'true', 0" >> "$TEMP_FILE"
            echo "    false_str db 'false', 0" >> "$TEMP_FILE"
            echo "    null_str db 'null', 0" >> "$TEMP_FILE"
            echo "    undefined_str db 'undefined', 0" >> "$TEMP_FILE"
            echo "    hex_prefix db '0x', 0" >> "$TEMP_FILE"
            HAS_TYPE_CONSTANTS=1
        fi
        
        if [ -n "$STRING_CONSTANTS" ] && [ "$DATA_INSERTED" -eq 0 ]; then
            echo -e "$STRING_CONSTANTS" >> "$TEMP_FILE"
            DATA_INSERTED=1
        fi
        
        # Add space constant if needed
        if [ "$HAS_SPACE_CONSTANT" -eq 0 ]; then
            echo "    space db ' ', 0" >> "$TEMP_FILE"
            HAS_SPACE_CONSTANT=1
        fi
        
        # Add newline constant if needed
        if [ "$HAS_NEWLINE_CONSTANT" -eq 0 ]; then
            echo "    newline db 10, 0" >> "$TEMP_FILE"
            HAS_NEWLINE_CONSTANT=1
        fi
        
        IN_DATA_SECTION=0
    fi
    
    # Check if we're entering _start section
    if [[ "$line" == "_start:" ]]; then
        IN_START_SECTION=1
    fi
    
    # Find a good place to insert console.log code (before exit)
    if [[ "$IN_START_SECTION" -eq 1 ]] && 
       [[ "$CODE_INSERTED" -eq 0 ]] && 
       [[ "$line" =~ ^[[:space:]]*mov[[:space:]]+rax,[[:space:]]*60 ]] &&
       [ -n "$CONSOLE_CODE" ]; then
        # Insert our generated code before the exit
        echo "" >> "$TEMP_FILE"
        echo "$CONSOLE_CODE" >> "$TEMP_FILE"
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
    # Add type constants first if needed
    if [ "$HAS_TYPE_CONSTANTS" -eq 0 ]; then
        echo "    ; Type constants for print function" >> "$TEMP_FILE"
        echo "    TYPE_STRING equ 1" >> "$TEMP_FILE"
        echo "    TYPE_NUMBER equ 2" >> "$TEMP_FILE"
        echo "    TYPE_CHAR    equ 3" >> "$TEMP_FILE"
        echo "    TYPE_BOOLEAN equ 4" >> "$TEMP_FILE"
        echo "    TYPE_NULL    equ 5" >> "$TEMP_FILE"
        echo "    TYPE_UNDEFINED equ 6" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        echo "    ; Boolean strings" >> "$TEMP_FILE"
        echo "    true_str db 'true', 0" >> "$TEMP_FILE"
        echo "    false_str db 'false', 0" >> "$TEMP_FILE"
        echo "    null_str db 'null', 0" >> "$TEMP_FILE"
        echo "    undefined_str db 'undefined', 0" >> "$TEMP_FILE"
        echo "    hex_prefix db '0x', 0" >> "$TEMP_FILE"
        HAS_TYPE_CONSTANTS=1
    fi
    
    echo -e "$STRING_CONSTANTS" >> "$TEMP_FILE"
    
    # Add space constant if needed
    if [ "$HAS_SPACE_CONSTANT" -eq 0 ]; then
        echo "    space db ' ', 0" >> "$TEMP_FILE"
        HAS_SPACE_CONSTANT=1
    fi
    
    # Add newline constant if needed
    if [ "$HAS_NEWLINE_CONSTANT" -eq 0 ]; then
        echo "    newline db 10, 0" >> "$TEMP_FILE"
        HAS_NEWLINE_CONSTANT=1
    fi
fi

# Replace the original file
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "Successfully appended console.log assembly code to $OUTPUT_FILE"
echo "Parsed statement: console.log($CONTENT)"