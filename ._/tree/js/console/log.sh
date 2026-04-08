#!/bin/bash

# log.sh - Parses console.log() statements and converts them to assembly code

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_FILE="../../../build_output.asm"

if [ ! -f "log_input" ]; then
    echo "Error: log_input file not found"
    exit 1
fi

LOG_STATEMENT=$(cat log_input | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
LOG_STATEMENT="${LOG_STATEMENT%;}"

if [[ "$LOG_STATEMENT" =~ console\.log\((.*)\) ]]; then
    CONTENT="${BASH_REMATCH[1]}"
else
    echo "Error: Invalid console.log statement"
    exit 1
fi

LOG_LABEL="log_$(date +%s%N | md5sum | cut -c1-8)"

# Parse arguments (handle strings with commas inside)
parse_arguments() {
    local content="$1"
    local args=()
    local current=""
    local in_string=false
    local string_char=""
    local i=0
    
    while [ $i -lt ${#content} ]; do
        local char="${content:$i:1}"
        
        if [[ "$char" == '"' || "$char" == "'" ]] && [[ "$in_string" == false ]]; then
            in_string=true
            string_char="$char"
        elif [[ "$char" == "$string_char" ]] && [[ "$in_string" == true ]]; then
            in_string=false
            string_char=""
        fi
        
        if [[ "$char" == "," ]] && [[ "$in_string" == false ]]; then
            args+=("$(echo "$current" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')")
            current=""
        else
            current="${current}${char}"
        fi
        
        i=$((i+1))
    done
    
    if [ -n "$current" ]; then
        args+=("$(echo "$current" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')")
    fi
    
    echo "${args[@]}"
}

# Check variable type from assembly file
get_variable_type() {
    local var_name="$1"
    
    # Check for undefined variables
    if grep -q "^[[:space:]]*; Variable: ${var_name} = undefined" "$OUTPUT_FILE"; then
        echo "undefined"
        return
    fi
    
    # Check for null variables
    if grep -q "^[[:space:]]*; Variable: ${var_name} = null" "$OUTPUT_FILE"; then
        echo "null"
        return
    fi
    
    # Check for boolean variables
    if grep -q "^[[:space:]]*; Variable: ${var_name}.*boolean" "$OUTPUT_FILE"; then
        echo "boolean"
        return
    fi
    
    # Check for string variables (db directive)
    if grep -q "^[[:space:]]*${var_name}[[:space:]]\+db" "$OUTPUT_FILE"; then
        echo "string"
        return
    fi
    
    # Check for number variables (dq directive with integer comment)
    if grep -q "^[[:space:]]*; Variable: ${var_name}.*type: integer" "$OUTPUT_FILE"; then
        echo "number"
        return
    fi
    
    # Default to number for dq variables
    if grep -q "^[[:space:]]*${var_name}[[:space:]]\+dq" "$OUTPUT_FILE"; then
        echo "number"
        return
    fi
    
    echo "unknown"
}

# Generate print code for a single argument
generate_print_code() {
    local arg="$1"
    local index="$2"
    
    # Remove quotes from strings
    if [[ "$arg" =~ ^\".*\"$ || "$arg" =~ ^\'.*\'$ ]]; then
        echo "    ; String literal"
        echo "    mov rax, ${LOG_LABEL}_str${index}"
        echo "    mov rdx, TYPE_STRING"
        echo "    call print"
        return
    fi
    
    # Handle JavaScript literals
    case "$arg" in
        "true")
            echo "    ; Boolean: true"
            echo "    mov rax, true_str"
            echo "    mov rdx, TYPE_STRING"
            echo "    call print"
            ;;
        "false")
            echo "    ; Boolean: false"
            echo "    mov rax, false_str"
            echo "    mov rdx, TYPE_STRING"
            echo "    call print"
            ;;
        "null")
            echo "    ; Null literal"
            echo "    mov rax, null_str"
            echo "    mov rdx, TYPE_STRING"
            echo "    call print"
            ;;
        "undefined")
            echo "    ; Undefined literal"
            echo "    mov rax, undefined_str"
            echo "    mov rdx, TYPE_STRING"
            echo "    call print"
            ;;
        [0-9]*)
            # Number literal
            if [[ "$arg" =~ ^[0-9]+$ ]]; then
                echo "    ; Number literal: $arg"
                echo "    mov rax, $arg"
                echo "    mov rdx, TYPE_NUMBER"
                echo "    call print"
            elif [[ "$arg" =~ ^0[xX][0-9a-fA-F]+$ ]]; then
                local dec_val=$((16#${arg#0x}))
                echo "    ; Hex literal: $arg"
                echo "    mov rax, $dec_val"
                echo "    mov rdx, TYPE_NUMBER"
                echo "    call print"
            else
                # Variable name
                local var_type=$(get_variable_type "$arg")
                
                case "$var_type" in
                    "undefined")
                        echo "    ; Undefined variable: $arg"
                        echo "    mov rax, undefined_str"
                        echo "    mov rdx, TYPE_STRING"
                        echo "    call print"
                        ;;
                    "null")
                        echo "    ; Null variable: $arg"
                        echo "    mov rax, null_str"
                        echo "    mov rdx, TYPE_STRING"
                        echo "    call print"
                        ;;
                    "boolean")
                        echo "    ; Boolean variable: $arg"
                        echo "    mov rax, [${arg}]"
                        echo "    cmp rax, 0"
                        echo "    je .${LOG_LABEL}_false_${index}"
                        echo "    mov rax, true_str"
                        echo "    jmp .${LOG_LABEL}_bool_done_${index}"
                        echo ".${LOG_LABEL}_false_${index}:"
                        echo "    mov rax, false_str"
                        echo ".${LOG_LABEL}_bool_done_${index}:"
                        echo "    mov rdx, TYPE_STRING"
                        echo "    call print"
                        ;;
                    "string")
                        echo "    ; String variable: $arg"
                        echo "    mov rax, ${arg}"
                        echo "    mov rdx, TYPE_STRING"
                        echo "    call print"
                        ;;
                    "number")
                        echo "    ; Number variable: $arg"
                        echo "    mov rax, [${arg}]"
                        echo "    mov rdx, TYPE_NUMBER"
                        echo "    call print"
                        ;;
                    *)
                        echo "    ; Unknown variable: $arg (treating as number)"
                        echo "    mov rax, [${arg}]"
                        echo "    mov rdx, TYPE_NUMBER"
                        echo "    call print"
                        ;;
                esac
            fi
            ;;
        *)
            # Variable name
            local var_type=$(get_variable_type "$arg")
            
            case "$var_type" in
                "undefined")
                    echo "    ; Undefined variable: $arg"
                    echo "    mov rax, undefined_str"
                    echo "    mov rdx, TYPE_STRING"
                    echo "    call print"
                    ;;
                "null")
                    echo "    ; Null variable: $arg"
                    echo "    mov rax, null_str"
                    echo "    mov rdx, TYPE_STRING"
                    echo "    call print"
                    ;;
                "boolean")
                    echo "    ; Boolean variable: $arg"
                    echo "    mov rax, [${arg}]"
                    echo "    cmp rax, 0"
                    echo "    je .${LOG_LABEL}_false_${index}"
                    echo "    mov rax, true_str"
                    echo "    jmp .${LOG_LABEL}_bool_done_${index}"
                    echo ".${LOG_LABEL}_false_${index}:"
                    echo "    mov rax, false_str"
                    echo ".${LOG_LABEL}_bool_done_${index}:"
                    echo "    mov rdx, TYPE_STRING"
                    echo "    call print"
                    ;;
                "string")
                    echo "    ; String variable: $arg"
                    echo "    mov rax, ${arg}"
                    echo "    mov rdx, TYPE_STRING"
                    echo "    call print"
                    ;;
                "number")
                    echo "    ; Number variable: $arg"
                    echo "    mov rax, [${arg}]"
                    echo "    mov rdx, TYPE_NUMBER"
                    echo "    call print"
                    ;;
                *)
                    echo "    ; Unknown variable: $arg (treating as number)"
                    echo "    mov rax, [${arg}]"
                    echo "    mov rdx, TYPE_NUMBER"
                    echo "    call print"
                    ;;
            esac
            ;;
    esac
}

# Generate string constants for string literals
generate_string_constants() {
    local args=($(parse_arguments "$CONTENT"))
    local constants=""
    
    for i in "${!args[@]}"; do
        local arg="${args[$i]}"
        if [[ "$arg" =~ ^\".*\"$ || "$arg" =~ ^\'.*\'$ ]]; then
            local str_value="${arg:1:${#arg}-2}"
            local escaped=$(echo -n "$str_value" | od -An -tu1 | awk '{for(i=1;i<=NF;i++) printf "%s, ", $i; printf "0"}')
            constants+="\n    ${LOG_LABEL}_str${i} db $escaped"
        fi
    done
    
    echo -e "$constants"
}

# Main execution
args=($(parse_arguments "$CONTENT"))
STRING_CONSTANTS=$(generate_string_constants)

# Generate the print code
CONSOLE_CODE="    ; console.log: $CONTENT"
for i in "${!args[@]}"; do
    CONSOLE_CODE+=$'\n'"$(generate_print_code "${args[$i]}" "$i")"
    if [ $i -lt $((${#args[@]} - 1)) ]; then
        CONSOLE_CODE+=$'\n    ; Space between args'
        CONSOLE_CODE+=$'\n    mov rax, space'
        CONSOLE_CODE+=$'\n    mov rdx, TYPE_STRING'
        CONSOLE_CODE+=$'\n    call print'
    fi
done

CONSOLE_CODE+=$'\n    ; Newline'
CONSOLE_CODE+=$'\n    mov rax, newline'
CONSOLE_CODE+=$'\n    mov rdx, TYPE_STRING'
CONSOLE_CODE+=$'\n    call print'

# Insert into output file
TEMP_FILE=$(mktemp)
IN_DATA_SECTION=0
IN_START=0
DATA_INSERTED=0
CODE_INSERTED=0

while IFS= read -r line; do
    # Handle data section
    if [[ "$line" == "section .data" ]]; then
        IN_DATA_SECTION=1
        echo "$line" >> "$TEMP_FILE"
        if [ -n "$STRING_CONSTANTS" ] && [ "$DATA_INSERTED" -eq 0 ]; then
            echo -e "$STRING_CONSTANTS" >> "$TEMP_FILE"
            DATA_INSERTED=1
        fi
        continue
    fi
    
    # Leave data section
    if [[ "$IN_DATA_SECTION" -eq 1 ]] && [[ "$line" == section* ]]; then
        if [ "$DATA_INSERTED" -eq 0 ] && [ -n "$STRING_CONSTANTS" ]; then
            echo -e "$STRING_CONSTANTS" >> "$TEMP_FILE"
            DATA_INSERTED=1
        fi
        IN_DATA_SECTION=0
    fi
    
    # Enter text section
    if [[ "$line" == "section .text" ]]; then
        IN_TEXT_SECTION=1
    fi
    
    # Enter _start
    if [[ "$line" == "_start:" ]]; then
        IN_START=1
    fi
    
    # Insert code before exit syscall
    if [[ "$IN_START" -eq 1 ]] && [[ "$CODE_INSERTED" -eq 0 ]] && [[ "$line" =~ mov[[:space:]]+rax,[[:space:]]*60 ]]; then
        echo "" >> "$TEMP_FILE"
        echo "$CONSOLE_CODE" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        CODE_INSERTED=1
    fi
    
    echo "$line" >> "$TEMP_FILE"
done < "$OUTPUT_FILE"

# If code wasn't inserted, append at end of _start
if [ "$CODE_INSERTED" -eq 0 ]; then
    # Find the line before exit and insert
    sed -i '/^[[:space:]]*mov[[:space:]]\+rax,[[:space:]]*60/i \\n'"$CONSOLE_CODE"'\n' "$TEMP_FILE" 2>/dev/null || {
        # If sed fails, just append to temp file
        echo "" >> "$TEMP_FILE"
        echo "$CONSOLE_CODE" >> "$TEMP_FILE"
    }
fi

mv "$TEMP_FILE" "$OUTPUT_FILE"
echo "Added console.log: $CONTENT"