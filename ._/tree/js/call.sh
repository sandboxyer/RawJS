#!/bin/bash

# call.sh - Handles generic function calls and appends them to build_output.asm
# FIXED: Simplified variable handling, uses dynamic allocation for strings

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_FILE="../../build_output.asm"
INPUT_FILE="call_input"
META_DIR="../function_meta"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found"
    exit 1
fi

CALL_STMT=$(cat "$INPUT_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
CALL_STMT=$(echo "$CALL_STMT" | sed 's/;.*$//')

ASSIGNMENT_MODE=0
VAR_NAME=""
if [[ "$CALL_STMT" =~ ^[[:space:]]*(var|let|const)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
    ASSIGNMENT_MODE=1
    VAR_NAME="${BASH_REMATCH[2]}"
    CALL_STMT="${BASH_REMATCH[3]}"
    CALL_STMT=$(echo "$CALL_STMT" | sed 's/;.*$//')
    CALL_STMT=$(echo "$CALL_STMT" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
fi

if [[ "$CALL_STMT" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\((.*)\)$ ]]; then
    FUNC_NAME="${BASH_REMATCH[1]}"
    ARGS="${BASH_REMATCH[2]}"
else
    echo "Error: Invalid function call format: $CALL_STMT"
    exit 1
fi

CALL_ID="call_$(date +%s%N 2>/dev/null || date +%s)_$$"

parse_args() {
    local args=()
    local current=""
    local in_quote=false
    local quote_char=""
    local paren_depth=0
    local i=0
    
    if [[ -z "${ARGS// }" ]]; then
        return
    fi
    
    while [ $i -lt ${#ARGS} ]; do
        local c="${ARGS:$i:1}"
        
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

process_nested_call() {
    local nested_call="$1"
    local prefix="$2"
    local nested_func_name=""
    local nested_args_str=""
    local nested_args_array=()
    
    if [[ "$nested_call" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\((.*)\)$ ]]; then
        nested_func_name="${BASH_REMATCH[1]}"
        nested_args_str="${BASH_REMATCH[2]}"
    else
        echo "Error: Invalid nested call format: $nested_call"
        return 1
    fi
    
    local old_ARGS="$ARGS"
    ARGS="$nested_args_str"
    mapfile -t nested_args_array < <(parse_args)
    ARGS="$old_ARGS"
    
    local nested_meta_file="$META_DIR/${nested_func_name}.meta"
    if [ ! -f "$nested_meta_file" ]; then
        echo "Error: No metadata for nested function $nested_func_name"
        return 1
    fi
    
    declare -a nested_param_names
    declare -a nested_param_defaults
    declare -a nested_param_types
    
    while IFS= read -r line; do
        if [[ "$line" == param=* ]]; then
            param_info="${line#param=}"
            IFS='|' read -r pname pdefault ptype <<< "$param_info"
            nested_param_names+=("$pname")
            nested_param_defaults+=("$pdefault")
            nested_param_types+=("$ptype")
        fi
    done < "$nested_meta_file"
    
    NESTED_DATA_DECLS+="    ${prefix}_result dq 0"$'\n'
    NESTED_DATA_DECLS+="    ${prefix}_result_type dq TYPE_UNDEFINED"$'\n'
    
    local nested_code=""
    for ((j=0; j<${#nested_param_names[@]}; j++)); do
        local npname="${nested_param_names[$j]}"
        local npdefault="${nested_param_defaults[$j]}"
        local nptype="${nested_param_types[$j]}"
        local nscoped="${nested_func_name}_${npname}"
        
        if [ $j -lt ${#nested_args_array[@]} ]; then
            local narg="${nested_args_array[$j]}"
            
            if [[ "$narg" =~ ^\".*\"$ ]] || [[ "$narg" =~ ^\'.*\'$ ]]; then
                local nstripped="${narg:1:${#narg}-2}"
                local nstripped_esc=$(echo "$nstripped" | sed "s/'/''/g")
                local ntemp_str_label="${prefix}_nested${j}_str"
                STRING_CONSTANTS+="    ${ntemp_str_label} db '${nstripped_esc}', 0"$'\n'
                nested_code+="    mov rsi, ${ntemp_str_label}"$'\n'
                nested_code+="    call allocate_string"$'\n'
                nested_code+="    mov [${nscoped}], rax"$'\n'
                nested_code+="    mov qword [${nscoped}_type], TYPE_STRING"$'\n'
                
            elif [[ "$narg" =~ ^-?[0-9]+$ ]]; then
                nested_code+="    mov qword [${nscoped}], ${narg}"$'\n'
                nested_code+="    mov qword [${nscoped}_type], TYPE_NUMBER"$'\n'
                
            elif [[ "$narg" =~ ^-?[0-9]*\.[0-9]+$ ]]; then
                local nfloat_label="${prefix}_nested${j}_float"
                STRING_CONSTANTS+="    ${nfloat_label} db '${narg}', 0"$'\n'
                nested_code+="    mov rsi, ${nfloat_label}"$'\n'
                nested_code+="    call allocate_string"$'\n'
                nested_code+="    mov [${nscoped}], rax"$'\n'
                nested_code+="    mov qword [${nscoped}_type], TYPE_FLOAT"$'\n'
                
            elif [[ "$narg" == "true" || "$narg" == "false" ]]; then
                if [ "$narg" == "true" ]; then
                    nested_code+="    mov qword [${nscoped}], 1"$'\n'
                else
                    nested_code+="    mov qword [${nscoped}], 0"$'\n'
                fi
                nested_code+="    mov qword [${nscoped}_type], TYPE_BOOLEAN"$'\n'
                
            elif [[ "$narg" == "null" ]]; then
                nested_code+="    mov qword [${nscoped}], 0"$'\n'
                nested_code+="    mov qword [${nscoped}_type], TYPE_NULL"$'\n'
            elif [[ "$narg" == "undefined" ]]; then
                nested_code+="    mov qword [${nscoped}], 0"$'\n'
                nested_code+="    mov qword [${nscoped}_type], TYPE_UNDEFINED"$'\n'
            else
                nested_code+="    mov rax, [${narg}]"$'\n'
                nested_code+="    mov [${nscoped}], rax"$'\n'
                nested_code+="    mov rax, [${narg}_type]"$'\n'
                nested_code+="    mov [${nscoped}_type], rax"$'\n'
            fi
        else
            if [ -n "$npdefault" ]; then
                case "$nptype" in
                    "number")
                        nested_code+="    mov qword [${nscoped}], ${npdefault}"$'\n'
                        nested_code+="    mov qword [${nscoped}_type], TYPE_NUMBER"$'\n'
                        ;;
                    "string")
                        local ndefault_esc=$(echo "$npdefault" | sed "s/'/''/g")
                        local ntemp_default_label="${prefix}_nested${j}_default_str"
                        STRING_CONSTANTS+="    ${ntemp_default_label} db '${ndefault_esc}', 0"$'\n'
                        nested_code+="    mov rsi, ${ntemp_default_label}"$'\n'
                        nested_code+="    call allocate_string"$'\n'
                        nested_code+="    mov [${nscoped}], rax"$'\n'
                        nested_code+="    mov qword [${nscoped}_type], TYPE_STRING"$'\n'
                        ;;
                    "float")
                        local nfloat_label="${prefix}_nested${j}_default_float"
                        STRING_CONSTANTS+="    ${nfloat_label} db '${npdefault}', 0"$'\n'
                        nested_code+="    mov rsi, ${nfloat_label}"$'\n'
                        nested_code+="    call allocate_string"$'\n'
                        nested_code+="    mov [${nscoped}], rax"$'\n'
                        nested_code+="    mov qword [${nscoped}_type], TYPE_FLOAT"$'\n'
                        ;;
                    *)
                        nested_code+="    mov qword [${nscoped}], 0"$'\n'
                        nested_code+="    mov qword [${nscoped}_type], TYPE_UNDEFINED"$'\n'
                        ;;
                esac
            else
                nested_code+="    mov qword [${nscoped}], 0"$'\n'
                nested_code+="    mov qword [${nscoped}_type], TYPE_UNDEFINED"$'\n'
            fi
        fi
    done
    
    nested_code+="    call ${nested_func_name}"$'\n'
    nested_code+="    mov [${prefix}_result], rax"$'\n'
    nested_code+="    mov [${prefix}_result_type], rdx"$'\n'
    
    CALL_CODE+="$nested_code"
}

mapfile -t ARGS_ARRAY < <(parse_args)

META_FILE="$META_DIR/${FUNC_NAME}.meta"
STRING_CONSTANTS=""
CALL_CODE=""
NESTED_DATA_DECLS=""

if [ -f "$META_FILE" ]; then
    declare -a param_names
    declare -a param_defaults
    declare -a param_types
    
    while IFS= read -r line; do
        if [[ "$line" == param=* ]]; then
            param_info="${line#param=}"
            IFS='|' read -r pname pdefault ptype <<< "$param_info"
            param_names+=("$pname")
            param_defaults+=("$pdefault")
            param_types+=("$ptype")
        fi
    done < "$META_FILE"
    
    CALL_CODE="    ; Function call with parameters: ${FUNC_NAME}(${ARGS})"$'\n'
    
    for ((i=0; i<${#param_names[@]}; i++)); do
        param_name="${param_names[$i]}"
        param_default="${param_defaults[$i]}"
        param_type="${param_types[$i]}"
        scoped_param_name="${FUNC_NAME}_${param_name}"
        
        if [ $i -lt ${#ARGS_ARRAY[@]} ]; then
            arg="${ARGS_ARRAY[$i]}"
            
            if [[ "$arg" =~ ^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(.*\)$ ]]; then
                CALL_CODE+="    ; Nested function call as argument: $arg"$'\n'
                temp_prefix="${CALL_ID}_nested${i}"
                process_nested_call "$arg" "$temp_prefix"
                CALL_CODE+="    mov rax, [${temp_prefix}_result]"$'\n'
                CALL_CODE+="    mov [${scoped_param_name}], rax"$'\n'
                CALL_CODE+="    mov rax, [${temp_prefix}_result_type]"$'\n'
                CALL_CODE+="    mov [${scoped_param_name}_type], rax"$'\n'
                
            elif [[ "$arg" =~ ^\".*\"$ ]] || [[ "$arg" =~ ^\'.*\'$ ]]; then
                stripped="${arg:1:${#arg}-2}"
                stripped_esc=$(echo "$stripped" | sed "s/'/''/g")
                temp_str_label="${CALL_ID}_param${i}_temp_str"
                STRING_CONSTANTS+="    ${temp_str_label} db '${stripped_esc}', 0"$'\n'
                CALL_CODE+="    mov rsi, ${temp_str_label}"$'\n'
                CALL_CODE+="    call allocate_string"$'\n'
                CALL_CODE+="    mov [${scoped_param_name}], rax"$'\n'
                CALL_CODE+="    mov qword [${scoped_param_name}_type], TYPE_STRING"$'\n'
                
            elif [[ "$arg" =~ ^-?[0-9]+$ ]]; then
                CALL_CODE+="    mov qword [${scoped_param_name}], ${arg}"$'\n'
                CALL_CODE+="    mov qword [${scoped_param_name}_type], TYPE_NUMBER"$'\n'
                
            elif [[ "$arg" =~ ^-?[0-9]*\.[0-9]+$ ]]; then
                temp_float_label="${CALL_ID}_param${i}_float_str"
                STRING_CONSTANTS+="    ${temp_float_label} db '${arg}', 0"$'\n'
                CALL_CODE+="    mov rsi, ${temp_float_label}"$'\n'
                CALL_CODE+="    call allocate_string"$'\n'
                CALL_CODE+="    mov [${scoped_param_name}], rax"$'\n'
                CALL_CODE+="    mov qword [${scoped_param_name}_type], TYPE_FLOAT"$'\n'
                
            elif [[ "$arg" == "true" ]] || [[ "$arg" == "false" ]]; then
                if [ "$arg" == "true" ]; then
                    CALL_CODE+="    mov qword [${scoped_param_name}], 1"$'\n'
                else
                    CALL_CODE+="    mov qword [${scoped_param_name}], 0"$'\n'
                fi
                CALL_CODE+="    mov qword [${scoped_param_name}_type], TYPE_BOOLEAN"$'\n'
                
            elif [[ "$arg" == "null" ]]; then
                CALL_CODE+="    mov qword [${scoped_param_name}], 0"$'\n'
                CALL_CODE+="    mov qword [${scoped_param_name}_type], TYPE_NULL"$'\n'
            elif [[ "$arg" == "undefined" ]]; then
                CALL_CODE+="    mov qword [${scoped_param_name}], 0"$'\n'
                CALL_CODE+="    mov qword [${scoped_param_name}_type], TYPE_UNDEFINED"$'\n'
                
            else
                CALL_CODE+="    ; Copy variable ${arg} to ${scoped_param_name}"$'\n'
                CALL_CODE+="    mov rax, [${arg}]"$'\n'
                CALL_CODE+="    mov [${scoped_param_name}], rax"$'\n'
                CALL_CODE+="    mov rax, [${arg}_type]"$'\n'
                CALL_CODE+="    mov [${scoped_param_name}_type], rax"$'\n'
            fi
        else
            if [ -n "$param_default" ]; then
                case "$param_type" in
                    "number")
                        CALL_CODE+="    mov qword [${scoped_param_name}], ${param_default}"$'\n'
                        CALL_CODE+="    mov qword [${scoped_param_name}_type], TYPE_NUMBER"$'\n'
                        ;;
                    "string")
                        default_esc=$(echo "$param_default" | sed "s/'/''/g")
                        temp_default_label="${CALL_ID}_param${i}_default_str"
                        STRING_CONSTANTS+="    ${temp_default_label} db '${default_esc}', 0"$'\n'
                        CALL_CODE+="    mov rsi, ${temp_default_label}"$'\n'
                        CALL_CODE+="    call allocate_string"$'\n'
                        CALL_CODE+="    mov [${scoped_param_name}], rax"$'\n'
                        CALL_CODE+="    mov qword [${scoped_param_name}_type], TYPE_STRING"$'\n'
                        ;;
                    "float")
                        temp_float_label="${CALL_ID}_param${i}_default_float"
                        STRING_CONSTANTS+="    ${temp_float_label} db '${param_default}', 0"$'\n'
                        CALL_CODE+="    mov rsi, ${temp_float_label}"$'\n'
                        CALL_CODE+="    call allocate_string"$'\n'
                        CALL_CODE+="    mov [${scoped_param_name}], rax"$'\n'
                        CALL_CODE+="    mov qword [${scoped_param_name}_type], TYPE_FLOAT"$'\n'
                        ;;
                    *)
                        CALL_CODE+="    mov qword [${scoped_param_name}], 0"$'\n'
                        CALL_CODE+="    mov qword [${scoped_param_name}_type], TYPE_UNDEFINED"$'\n'
                        ;;
                esac
            else
                CALL_CODE+="    mov qword [${scoped_param_name}], 0"$'\n'
                CALL_CODE+="    mov qword [${scoped_param_name}_type], TYPE_UNDEFINED"$'\n'
            fi
        fi
    done
    
    CALL_CODE+="    call ${FUNC_NAME}"$'\n'
    
    if [ "$ASSIGNMENT_MODE" -eq 1 ]; then
        CALL_CODE+="    ; Store return value from function"$'\n'
        CALL_CODE+="    mov [${VAR_NAME}], rax"$'\n'
        CALL_CODE+="    mov [${VAR_NAME}_type], rdx"$'\n'
    fi
    
else
    CALL_CODE="    ; Function call: ${FUNC_NAME}(${ARGS})"$'\n'
    
    if [ ${#ARGS_ARRAY[@]} -gt 0 ]; then
        for ((i=${#ARGS_ARRAY[@]}-1; i>=0; i--)); do
            arg="${ARGS_ARRAY[$i]}"
            if [[ "$arg" =~ ^\".*\"$ ]]; then
                stripped="${arg:1:${#arg}-2}"
                STRING_CONSTANTS+="    ${CALL_ID}_str${i} db '${stripped}', 0"$'\n'
                CALL_CODE+="    mov rax, ${CALL_ID}_str${i}"$'\n'
                CALL_CODE+="    push rax"$'\n'
            elif [[ "$arg" =~ ^-?[0-9]+$ ]]; then
                CALL_CODE+="    mov rax, $arg"$'\n'
                CALL_CODE+="    push rax"$'\n'
            else
                CALL_CODE+="    mov rax, [${arg}]"$'\n'
                CALL_CODE+="    push rax"$'\n'
            fi
        done
    fi
    
    CALL_CODE+="    call ${FUNC_NAME}"$'\n'
    
    if [ ${#ARGS_ARRAY[@]} -gt 0 ]; then
        CALL_CODE+="    add rsp, $((8 * ${#ARGS_ARRAY[@]}))"$'\n'
    fi
fi

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: $OUTPUT_FILE not found"
    exit 1
fi

DATA_INSERT=""
if [ -n "$STRING_CONSTANTS" ]; then
    DATA_INSERT="$STRING_CONSTANTS"
fi
if [ -n "$NESTED_DATA_DECLS" ]; then
    DATA_INSERT+="${NESTED_DATA_DECLS}"
fi
if [ "$ASSIGNMENT_MODE" -eq 1 ]; then
    VAR_DECLARATIONS="    ${VAR_NAME} dq 0"$'\n'
    VAR_DECLARATIONS+="    ${VAR_NAME}_type dq TYPE_UNDEFINED"$'\n'
    DATA_INSERT+="${VAR_DECLARATIONS}"
fi

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
            echo "$DATA_INSERT" >> "$TEMP_FILE"
            DATA_DONE=1
        fi
        IN_DATA=0
    fi
    
    if [[ "$line" == "_start:" ]]; then
        IN_START=1
    fi
    
    if [ "$IN_START" -eq 1 ] && [ "$CODE_DONE" -eq 0 ] && \
       [[ "$line" =~ ^[[:space:]]*mov[[:space:]]+rax,[[:space:]]*60$ ]]; then
        echo "$CALL_CODE" >> "$TEMP_FILE"
        CODE_DONE=1
    fi
    
    echo "$line" >> "$TEMP_FILE"
done < "$OUTPUT_FILE"

if [ "$IN_DATA" -eq 1 ] && [ "$DATA_DONE" -eq 0 ] && [ -n "$DATA_INSERT" ]; then
    echo "$DATA_INSERT" >> "$TEMP_FILE"
fi

if [ "$CODE_DONE" -eq 0 ] && [ -n "$CALL_CODE" ]; then
    echo "$CALL_CODE" >> "$TEMP_FILE"
fi

mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "Successfully appended function call: ${FUNC_NAME}(${ARGS})"
exit 0
