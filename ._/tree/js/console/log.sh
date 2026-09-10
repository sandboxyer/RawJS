#!/bin/bash

# log.sh - Parses console.log() statements and generates assembly print calls
# FIXED: Paren-aware argument parsing (nested commas are no longer split)
# FIXED: Full recursive support for nested function calls as arguments
# FIXED: Proper UTF-8 support using hexdump

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_FILE="../../../build_output.asm"
INPUT_FILE="log_input"
META_DIR="$SCRIPT_DIR/../../function_meta"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found"
    exit 1
fi

LOG_STMT=$(cat "$INPUT_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
LOG_STMT="${LOG_STMT%;}"

if [[ "$LOG_STMT" =~ console\.log\((.*)\) ]]; then
    CONTENT="${BASH_REMATCH[1]}"
else
    echo "Error: Invalid console.log format"
    exit 1
fi

LOG_ID="log_$(date +%s%N 2>/dev/null || date +%s)_$(od -An -N4 -tu4 /dev/urandom 2>/dev/null | tr -d ' ' || echo $$)"

STRING_CONSTANTS=""
TEMP_DATA=""
PRINT_CODE=""

escape_string() {
    local str="$1"
    
    if [ -z "$str" ]; then
        echo "0"
        return
    fi
    
    local processed=""
    local i=0
    while [ $i -lt ${#str} ]; do
        local c="${str:$i:1}"
        if [ "$c" = '\' ] && [ $((i+1)) -lt ${#str} ]; then
            local n="${str:$((i+1)):1}"
            case "$n" in
                n)  processed+=$'\n'; i=$((i+2)); continue ;;
                t)  processed+=$'\t'; i=$((i+2)); continue ;;
                r)  processed+=$'\r'; i=$((i+2)); continue ;;
                \\) processed+='\\'; i=$((i+2)); continue ;;
                \") processed+='"'; i=$((i+2)); continue ;;
                \') processed+="'"; i=$((i+2)); continue ;;
            esac
        fi
        processed+="$c"
        i=$((i+1))
    done
    
    local bytes=$(printf "%s" "$processed" | hexdump -v -e '1/1 "%d, "')
    bytes="${bytes%, }"
    
    if [ -n "$bytes" ]; then
        echo "${bytes}, 0"
    else
        echo "0"
    fi
}

# Parse comma-separated argument string with quote and paren awareness
parse_args() {
    local args_str="$1"
    local args=()
    local current=""
    local in_quote=false
    local quote_char=""
    local paren_depth=0
    local i=0
    
    if [[ -z "${args_str// }" ]]; then
        return
    fi
    
    while [ $i -lt ${#args_str} ]; do
        local c="${args_str:$i:1}"
        
        if [[ "$c" =~ [\"\'] ]]; then
            if [ "$in_quote" = false ]; then
                in_quote=true
                quote_char="$c"
            elif [ "$c" = "$quote_char" ]; then
                in_quote=false
                quote_char=""
            fi
        fi
        
        if [ "$in_quote" = false ]; then
            if [ "$c" = '(' ]; then
                paren_depth=$((paren_depth + 1))
            elif [ "$c" = ')' ]; then
                paren_depth=$((paren_depth - 1))
            fi
        fi
        
        if [ "$c" = ',' ] && [ "$in_quote" = false ] && [ $paren_depth -eq 0 ]; then
            args+=("$(echo "$current" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')")
            current=""
        else
            current="${current}${c}"
        fi
        i=$((i+1))
    done
    
    [ -n "$current" ] && args+=("$(echo "$current" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')")
    
    printf '%s\n' "${args[@]}"
}

# Generate code computing expr into [dest] and [dest]_type, using temps prefixed by `prefix`.
generate_value_into() {
    local expr="$1"
    local prefix="$2"
    local dest="$3"
    
    if [ -z "$expr" ]; then
        PRINT_CODE+="    mov qword [${dest}], 0"$'\n'
        PRINT_CODE+="    mov qword [${dest}_type], TYPE_UNDEFINED"$'\n'
        return
    fi
    
    # String literal
    if [[ "$expr" =~ ^\".*\"$ ]] || [[ "$expr" =~ ^\'.*\'$ ]]; then
        local stripped="${expr:1:${#expr}-2}"
        local escaped=$(escape_string "$stripped")
        STRING_CONSTANTS+="    ${prefix}_str db ${escaped}"$'\n'
        PRINT_CODE+="    mov rsi, ${prefix}_str"$'\n'
        PRINT_CODE+="    call allocate_string"$'\n'
        PRINT_CODE+="    mov [${dest}], rax"$'\n'
        PRINT_CODE+="    mov qword [${dest}_type], TYPE_STRING"$'\n'
        return
    fi
    
    # Integer literal
    if [[ "$expr" =~ ^-?[0-9]+$ ]]; then
        PRINT_CODE+="    mov qword [${dest}], ${expr}"$'\n'
        PRINT_CODE+="    mov qword [${dest}_type], TYPE_NUMBER"$'\n'
        return
    fi
    
    # Float literal
    if [[ "$expr" =~ ^-?[0-9]*\.[0-9]+$ ]]; then
        local escaped=$(escape_string "$expr")
        STRING_CONSTANTS+="    ${prefix}_str db ${escaped}"$'\n'
        PRINT_CODE+="    mov rsi, ${prefix}_str"$'\n'
        PRINT_CODE+="    call allocate_string"$'\n'
        PRINT_CODE+="    mov [${dest}], rax"$'\n'
        PRINT_CODE+="    mov qword [${dest}_type], TYPE_FLOAT"$'\n'
        return
    fi
    
    # Boolean
    if [ "$expr" = "true" ] || [ "$expr" = "false" ]; then
        if [ "$expr" = "true" ]; then
            PRINT_CODE+="    mov qword [${dest}], 1"$'\n'
        else
            PRINT_CODE+="    mov qword [${dest}], 0"$'\n'
        fi
        PRINT_CODE+="    mov qword [${dest}_type], TYPE_BOOLEAN"$'\n'
        return
    fi
    
    # null / undefined
    if [ "$expr" = "null" ]; then
        PRINT_CODE+="    mov qword [${dest}], 0"$'\n'
        PRINT_CODE+="    mov qword [${dest}_type], TYPE_NULL"$'\n'
        return
    fi
    if [ "$expr" = "undefined" ]; then
        PRINT_CODE+="    mov qword [${dest}], 0"$'\n'
        PRINT_CODE+="    mov qword [${dest}_type], TYPE_UNDEFINED"$'\n'
        return
    fi
    
    # Simple variable identifier
    if [[ "$expr" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        PRINT_CODE+="    mov rax, [${expr}]"$'\n'
        PRINT_CODE+="    mov [${dest}], rax"$'\n'
        PRINT_CODE+="    mov rax, [${expr}_type]"$'\n'
        PRINT_CODE+="    mov [${dest}_type], rax"$'\n'
        return
    fi
    
    # Nested function call -> recurse
    if [[ "$expr" =~ ^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(.*\)$ ]]; then
        generate_function_call "$expr" "$prefix"
        PRINT_CODE+="    mov rax, [${prefix}_result]"$'\n'
        PRINT_CODE+="    mov [${dest}], rax"$'\n'
        PRINT_CODE+="    mov rax, [${prefix}_result_type]"$'\n'
        PRINT_CODE+="    mov [${dest}_type], rax"$'\n'
        return
    fi
    
    # Fallback
    PRINT_CODE+="    mov qword [${dest}], 0"$'\n'
    PRINT_CODE+="    mov qword [${dest}_type], TYPE_UNDEFINED"$'\n'
}

# Generate code for a function call, storing return value in [prefix_result]/[prefix_result_type]
generate_function_call() {
    local call_expr="$1"
    local prefix="$2"
    
    local func_name=""
    local args_str=""
    
    if [[ "$call_expr" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\((.*)\)$ ]]; then
        func_name="${BASH_REMATCH[1]}"
        args_str="${BASH_REMATCH[2]}"
    else
        echo "Error: Invalid function call format: $call_expr" >&2
        return 1
    fi
    
    local meta_file="$META_DIR/${func_name}.meta"
    if [ ! -f "$meta_file" ]; then
        echo "Error: No metadata for function $func_name (expected at $meta_file)" >&2
        return 1
    fi
    
    local -a param_names=()
    local -a param_defaults=()
    local -a param_types=()
    
    while IFS= read -r line; do
        if [[ "$line" == param=* ]]; then
            local param_info="${line#param=}"
            local pname pdefault ptype
            IFS='|' read -r pname pdefault ptype <<< "$param_info"
            param_names+=("$pname")
            param_defaults+=("$pdefault")
            param_types+=("$ptype")
        fi
    done < "$meta_file"
    
    local -a call_args=()
    if [ -n "${args_str// }" ]; then
        mapfile -t call_args < <(parse_args "$args_str")
    fi
    
    local i
    for ((i=0; i<${#param_names[@]}; i++)); do
        local pname="${param_names[$i]}"
        local pdefault="${param_defaults[$i]}"
        local ptype="${param_types[$i]}"
        local scoped="${func_name}_${pname}"
        
        if [ $i -lt ${#call_args[@]} ]; then
            local arg="${call_args[$i]}"
            generate_value_into "$arg" "${prefix}_p${i}" "$scoped"
        else
            if [ -n "$pdefault" ]; then
                case "$ptype" in
                    number)
                        PRINT_CODE+="    mov qword [${scoped}], ${pdefault}"$'\n'
                        PRINT_CODE+="    mov qword [${scoped}_type], TYPE_NUMBER"$'\n'
                        ;;
                    string)
                        local escaped=$(escape_string "$pdefault")
                        STRING_CONSTANTS+="    ${prefix}_p${i}_def db ${escaped}"$'\n'
                        PRINT_CODE+="    mov rsi, ${prefix}_p${i}_def"$'\n'
                        PRINT_CODE+="    call allocate_string"$'\n'
                        PRINT_CODE+="    mov [${scoped}], rax"$'\n'
                        PRINT_CODE+="    mov qword [${scoped}_type], TYPE_STRING"$'\n'
                        ;;
                    float)
                        local escaped=$(escape_string "$pdefault")
                        STRING_CONSTANTS+="    ${prefix}_p${i}_def db ${escaped}"$'\n'
                        PRINT_CODE+="    mov rsi, ${prefix}_p${i}_def"$'\n'
                        PRINT_CODE+="    call allocate_string"$'\n'
                        PRINT_CODE+="    mov [${scoped}], rax"$'\n'
                        PRINT_CODE+="    mov qword [${scoped}_type], TYPE_FLOAT"$'\n'
                        ;;
                    *)
                        PRINT_CODE+="    mov qword [${scoped}], 0"$'\n'
                        PRINT_CODE+="    mov qword [${scoped}_type], TYPE_UNDEFINED"$'\n'
                        ;;
                esac
            else
                PRINT_CODE+="    mov qword [${scoped}], 0"$'\n'
                PRINT_CODE+="    mov qword [${scoped}_type], TYPE_UNDEFINED"$'\n'
            fi
        fi
    done
    
    TEMP_DATA+="    ${prefix}_result dq 0"$'\n'
    TEMP_DATA+="    ${prefix}_result_type dq TYPE_UNDEFINED"$'\n'
    PRINT_CODE+="    call ${func_name}"$'\n'
    PRINT_CODE+="    mov [${prefix}_result], rax"$'\n'
    PRINT_CODE+="    mov [${prefix}_result_type], rdx"$'\n'
}

mapfile -t ARGS < <(parse_args "$CONTENT")

if [ ${#ARGS[@]} -eq 0 ]; then
    PRINT_CODE+="    mov rax, newline"$'\n'
    PRINT_CODE+="    mov rdx, TYPE_STRING"$'\n'
    PRINT_CODE+="    call print"$'\n'
else
    for i in "${!ARGS[@]}"; do
        arg="${ARGS[$i]}"
        
        # A: nested function call
        if [[ "$arg" =~ ^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(.*\)$ ]]; then
            prefix="${LOG_ID}_arg${i}"
            generate_function_call "$arg" "$prefix"
            PRINT_CODE+="    mov rax, [${prefix}_result]"$'\n'
            PRINT_CODE+="    mov rdx, [${prefix}_result_type]"$'\n'
            PRINT_CODE+="    call print"$'\n'
        
        # B: string literal
        elif [[ "$arg" =~ ^\".*\"$ ]] || [[ "$arg" =~ ^\'.*\'$ ]]; then
            stripped="${arg:1:${#arg}-2}"
            escaped=$(escape_string "$stripped")
            STRING_CONSTANTS+="    ${LOG_ID}_str${i} db ${escaped}"$'\n'
            PRINT_CODE+="    mov rax, ${LOG_ID}_str${i}"$'\n'
            PRINT_CODE+="    mov rdx, TYPE_STRING"$'\n'
            PRINT_CODE+="    call print"$'\n'
        
        # C: integer literal
        elif [[ "$arg" =~ ^-?[0-9]+$ ]]; then
            PRINT_CODE+="    mov rax, ${arg}"$'\n'
            PRINT_CODE+="    mov rdx, TYPE_NUMBER"$'\n'
            PRINT_CODE+="    call print"$'\n'
        
        # D: float literal
        elif [[ "$arg" =~ ^-?[0-9]*\.[0-9]+$ ]]; then
            escaped=$(escape_string "$arg")
            STRING_CONSTANTS+="    ${LOG_ID}_float${i} db ${escaped}"$'\n'
            PRINT_CODE+="    mov rax, ${LOG_ID}_float${i}"$'\n'
            PRINT_CODE+="    mov rdx, TYPE_FLOAT"$'\n'
            PRINT_CODE+="    call print"$'\n'
        
        # E: boolean
        elif [ "$arg" = "true" ]; then
            PRINT_CODE+="    mov rax, 1"$'\n'
            PRINT_CODE+="    mov rdx, TYPE_BOOLEAN"$'\n'
            PRINT_CODE+="    call print"$'\n'
        elif [ "$arg" = "false" ]; then
            PRINT_CODE+="    mov rax, 0"$'\n'
            PRINT_CODE+="    mov rdx, TYPE_BOOLEAN"$'\n'
            PRINT_CODE+="    call print"$'\n'
        
        # F: null / undefined
        elif [ "$arg" = "null" ]; then
            PRINT_CODE+="    mov rax, 0"$'\n'
            PRINT_CODE+="    mov rdx, TYPE_NULL"$'\n'
            PRINT_CODE+="    call print"$'\n'
        elif [ "$arg" = "undefined" ]; then
            PRINT_CODE+="    mov rax, 0"$'\n'
            PRINT_CODE+="    mov rdx, TYPE_UNDEFINED"$'\n'
            PRINT_CODE+="    call print"$'\n'
        
        # G: simple variable
        elif [[ "$arg" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            PRINT_CODE+="    ; Print variable '${arg}'"$'\n'
            PRINT_CODE+="    mov rax, [${arg}]"$'\n'
            PRINT_CODE+="    mov rdx, [${arg}_type]"$'\n'
            PRINT_CODE+="    call print"$'\n'
        
        # H: fallback
        else
            PRINT_CODE+="    ; Unhandled argument: ${arg}"$'\n'
            PRINT_CODE+="    mov rax, undefined_str"$'\n'
            PRINT_CODE+="    mov rdx, TYPE_STRING"$'\n'
            PRINT_CODE+="    call print"$'\n'
        fi
        
        if [ $i -lt $((${#ARGS[@]} - 1)) ]; then
            PRINT_CODE+="    mov rax, space"$'\n'
            PRINT_CODE+="    mov rdx, TYPE_STRING"$'\n'
            PRINT_CODE+="    call print"$'\n'
        fi
    done
    
    PRINT_CODE+="    mov rax, newline"$'\n'
    PRINT_CODE+="    mov rdx, TYPE_STRING"$'\n'
    PRINT_CODE+="    call print"$'\n'
fi

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: $OUTPUT_FILE not found"
    exit 1
fi

DATA_INSERT="${STRING_CONSTANTS}${TEMP_DATA}"

TEMP_FILE=$(mktemp)
IN_DATA=0
IN_START=0
DATA_DONE=0
CODE_DONE=0

while IFS= read -r line; do
    if [[ "$line" == "section .data" ]]; then
        IN_DATA=1
    elif [[ "$line" == section* ]] && [ "$IN_DATA" -eq 1 ]; then
        if [ "$DATA_DONE" -eq 0 ] && [ -n "$DATA_INSERT" ]; then
            printf '%s' "$DATA_INSERT" >> "$TEMP_FILE"
            DATA_DONE=1
        fi
        IN_DATA=0
    fi
    
    if [[ "$line" == "_start:" ]]; then
        IN_START=1
    fi
    
    if [ "$IN_START" -eq 1 ] && [ "$CODE_DONE" -eq 0 ] && \
       [[ "$line" =~ ^[[:space:]]*mov[[:space:]]+rax,[[:space:]]*60$ ]]; then
        printf '%s' "$PRINT_CODE" >> "$TEMP_FILE"
        CODE_DONE=1
    fi
    
    echo "$line" >> "$TEMP_FILE"
done < "$OUTPUT_FILE"

if [ "$IN_DATA" -eq 1 ] && [ "$DATA_DONE" -eq 0 ] && [ -n "$DATA_INSERT" ]; then
    printf '%s' "$DATA_INSERT" >> "$TEMP_FILE"
fi

if [ "$CODE_DONE" -eq 0 ] && [ -n "$PRINT_CODE" ]; then
    printf '%s' "$PRINT_CODE" >> "$TEMP_FILE"
fi

mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "Successfully appended console.log($CONTENT)"
exit 0
