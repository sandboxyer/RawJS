#!/bin/bash

# log.sh - Parses console.log() statements and converts them to assembly code
# Updated to properly handle boolean literals and float variables

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_FILE="../../../build_output.asm"

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

# Function to get variable type from assembly code
get_variable_type() {
    local var_name="$1"
    
    if [ ! -f "$OUTPUT_FILE" ]; then
        echo "unknown"
        return
    fi
    
    # Look for variable declarations in the assembly
    local var_line=$(grep "^[[:space:]]*${var_name}[[:space:]]" "$OUTPUT_FILE" | head -1)
    
    if [ -z "$var_line" ]; then
        echo "unknown"
        return
    fi
    
    # Check comment for type hints
    if [[ "$var_line" =~ "type:" ]]; then
        if [[ "$var_line" =~ "type: boolean" ]]; then
            echo "boolean"
            return
        elif [[ "$var_line" =~ "type: integer" ]] || [[ "$var_line" =~ "type: expression" ]] || [[ "$var_line" =~ "type: integer expression" ]]; then
            echo "integer"
            return
        elif [[ "$var_line" =~ "type: float" ]] || [[ "$var_line" =~ "type: float expression" ]]; then
            echo "float"
            return
        elif [[ "$var_line" =~ "type: string" ]]; then
            echo "string"
            return
        elif [[ "$var_line" =~ "type: undefined" ]]; then
            echo "undefined"
            return
        fi
    fi
    
    # Check for boolean pattern in comment
    if [[ "$var_line" =~ "boolean:" ]] || [[ "$var_line" =~ "boolean" ]]; then
        echo "boolean"
        return
    fi
    
    # Check if it's a float (has _float suffix or pointer to float)
    if [[ "$var_line" =~ "_float" ]] || [[ "$var_line" =~ "pointer to float" ]]; then
        echo "float"
        return
    fi
    
    # Check the actual assembly directive
    if [[ "$var_line" =~ db.*\".*\" ]] || [[ "$var_line" =~ db.*[0-9]+.*string ]]; then
        echo "string"
    elif [[ "$var_line" =~ db.*\'.*\' ]]; then
        echo "char"
    elif [[ "$var_line" =~ dq ]]; then
        # Could be integer, boolean, or float pointer
        if [[ "$var_line" =~ dq[[:space:]]+[01][[:space:]]*$ ]] || [[ "$var_line" =~ dq[[:space:]]+[01][[:space:]]*\; ]] || [[ "$var_line" =~ "boolean" ]]; then
            echo "boolean"
        else
            echo "integer"
        fi
    else
        echo "unknown"
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
            "true"|"false"|"null"|"undefined")
                # These are handled by built-in strings
                ;;
            \'*\' | \"*\")
                # String literals (with quotes)
                local stripped="${arg:1:${#arg}-2}"
                local nasm_string=$(escape_for_nasm "$stripped")
                constants+="\n    ${LOG_LABEL}_str${i} db $nasm_string"
                ;;
            *)
                # Check if it's a number
                if [[ "$arg" =~ ^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$ ]] && [[ ! "$arg" =~ ^-?0[0-9]+ ]]; then
                    # For floats, create string representation
                    if [[ "$arg" =~ \. ]] || [[ "$arg" =~ [eE] ]]; then
                        constants+="\n    ${LOG_LABEL}_num${i} db '$arg', 0"
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
        "true")
            echo "    ; Boolean literal: true"
            echo "    mov rax, 1"
            echo "    mov rdx, TYPE_BOOLEAN"
            echo "    call print"
            ;;
        "false")
            echo "    ; Boolean literal: false"
            echo "    mov rax, 0"
            echo "    mov rdx, TYPE_BOOLEAN"
            echo "    call print"
            ;;
        "null")
            echo "    mov rax, 0"
            echo "    mov rdx, TYPE_NULL"
            echo "    call print"
            ;;
        "undefined")
            echo "    mov rax, 0"
            echo "    mov rdx, TYPE_UNDEFINED"
            echo "    call print"
            ;;
        \'*\' | \"*\")
            echo "    mov rax, ${LOG_LABEL}_str${arg_index}"
            echo "    mov rdx, TYPE_STRING"
            echo "    call print"
            ;;
        *)
            # Check if it's a number
            if [[ "$arg" =~ ^-?[0-9]+$ ]] && [[ ! "$arg" =~ ^-?0[0-9]+ ]]; then
                # Integer literal
                echo "    mov rax, $arg"
                echo "    mov rdx, TYPE_NUMBER"
                echo "    call print"
            elif [[ "$arg" =~ ^-?[0-9]*\.[0-9]+$ ]] || [[ "$arg" =~ ^-?[0-9]+[eE][-+]?[0-9]+$ ]]; then
                # Float literal
                echo "    mov rax, ${LOG_LABEL}_num${arg_index}"
                echo "    mov rdx, TYPE_FLOAT"
                echo "    call print"
            else
                # Assume it's a variable
                local var_name="$arg"
                local var_type=$(get_variable_type "$var_name")
                
                case "$var_type" in
                    "boolean")
                        echo "    ; Boolean variable: $var_name"
                        echo "    mov rax, [${var_name}]"
                        echo "    mov rdx, TYPE_BOOLEAN"
                        echo "    call print"
                        ;;
                    "integer")
                        echo "    ; Integer variable: $var_name"
                        echo "    mov rax, [${var_name}]"
                        echo "    mov rdx, TYPE_NUMBER"
                        echo "    call print"
                        ;;
                    "float")
                        echo "    ; Float variable: $var_name"
                        echo "    mov rax, [${var_name}]"
                        echo "    mov rdx, TYPE_FLOAT"
                        echo "    call print"
                        ;;
                    "string")
                        echo "    mov rax, ${var_name}"
                        echo "    mov rdx, TYPE_STRING"
                        echo "    call print"
                        ;;
                    "char")
                        echo "    ; Character variable: $var_name"
                        echo "    movzx rax, byte [${var_name}]"
                        echo "    mov rdx, TYPE_CHAR"
                        echo "    call print"
                        ;;
                    *)
                        # Try to find the variable
                        if grep -q "^[[:space:]]*${var_name}_float" "$OUTPUT_FILE"; then
                            echo "    ; Float variable (detected): $var_name"
                            echo "    mov rax, [${var_name}]"
                            echo "    mov rdx, TYPE_FLOAT"
                            echo "    call print"
                        elif grep -q "^[[:space:]]*${var_name}[[:space:]]*dq.*boolean" "$OUTPUT_FILE"; then
                            echo "    ; Boolean variable (detected): $var_name"
                            echo "    mov rax, [${var_name}]"
                            echo "    mov rdx, TYPE_BOOLEAN"
                            echo "    call print"
                        elif grep -q "^[[:space:]]*${var_name}[[:space:]]" "$OUTPUT_FILE"; then
                            # Default to treating as number if it's dq
                            if grep -q "^[[:space:]]*${var_name}[[:space:]]*dq" "$OUTPUT_FILE"; then
                                echo "    mov rax, [${var_name}]"
                                echo "    mov rdx, TYPE_NUMBER"
                                echo "    call print"
                            else
                                echo "    mov rax, ${var_name}"
                                echo "    mov rdx, TYPE_STRING"
                                echo "    call print"
                            fi
                        else
                            # Variable not found - print as undefined
                            echo "    ; Variable not found: $var_name"
                            echo "    mov rax, 0"
                            echo "    mov rdx, TYPE_UNDEFINED"
                            echo "    call print"
                        fi
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
        
        if [ -n "$STRING_CONSTANTS" ] && [ "$DATA_INSERTED" -eq 0 ]; then
            echo -e "$STRING_CONSTANTS" >> "$TEMP_FILE"
            DATA_INSERTED=1
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
    echo -e "$STRING_CONSTANTS" >> "$TEMP_FILE"
fi

# Replace the original file
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "Successfully appended console.log assembly code to $OUTPUT_FILE"
echo "Parsed statement: console.log($CONTENT)"
exit 0