#!/bin/bash

# number.sh - Converts JavaScript number declarations to NASM assembly code
# Generates runtime evaluation code for expressions including floats.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
cd "$SCRIPT_DIR/simple"

OUTPUT_FILE="../../../../build_output.asm"
INPUT_FILE="../../var_input"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found"
    exit 1
fi

# Read and clean the input
INPUT_CONTENT=$(cat "$INPUT_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
INPUT_CONTENT="${INPUT_CONTENT%;}"

# Extract variable name and value
if [[ "$INPUT_CONTENT" =~ ^var[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
    VAR_NAME="${BASH_REMATCH[1]}"
    VAR_VALUE="${BASH_REMATCH[2]}"
    VAR_VALUE=$(echo "$VAR_VALUE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
else
    echo "Error: Invalid variable declaration format"
    exit 1
fi

# ----------------------------------------------------------------------
# Detect if expression contains any float (decimal point or scientific notation)
# ----------------------------------------------------------------------
contains_float() {
    [[ "$1" =~ [0-9]*\.[0-9]+ ]] || [[ "$1" =~ [0-9]+[eE][-+]?[0-9]+ ]]
}

# ----------------------------------------------------------------------
# Helper: check if expression contains operators or parentheses
# ----------------------------------------------------------------------
has_operators() {
    [[ "$1" =~ [\+\-\*/%\(\)] ]]
}

# ----------------------------------------------------------------------
# Tokenizer - handles integers AND floats
# ----------------------------------------------------------------------
tokenize() {
    local expr="$1"
    local tokens=()
    local i=0
    local len=${#expr}
    
    while [ $i -lt $len ]; do
        local c="${expr:$i:1}"
        
        # Skip whitespace
        if [[ "$c" =~ [[:space:]] ]]; then
            i=$((i+1))
            continue
        fi
        
        # Number (integer or float)
        if [[ "$c" =~ [0-9] ]] || [[ "$c" == "." ]]; then
            local num="$c"
            i=$((i+1))
            local has_dot=false
            [[ "$c" == "." ]] && has_dot=true
            
            while [ $i -lt $len ]; do
                local nc="${expr:$i:1}"
                if [[ "$nc" =~ [0-9] ]]; then
                    num="${num}${nc}"
                    i=$((i+1))
                elif [[ "$nc" == "." ]] && [ "$has_dot" = false ]; then
                    num="${num}${nc}"
                    has_dot=true
                    i=$((i+1))
                elif [[ "$nc" =~ [eE] ]]; then
                    # Scientific notation
                    num="${num}${nc}"
                    i=$((i+1))
                    if [ $i -lt $len ]; then
                        local sign="${expr:$i:1}"
                        if [[ "$sign" =~ [\+\-] ]]; then
                            num="${num}${sign}"
                            i=$((i+1))
                        fi
                    fi
                else
                    break
                fi
            done
            
            if [[ "$num" =~ \. ]] || [[ "$num" =~ [eE] ]]; then
                tokens+=("FLOAT:$num")
            else
                tokens+=("INT:$num")
            fi
            continue
        fi
        
        # Operators and parentheses
        case "$c" in
            '+'|'-'|'*'|'/'|'%'|'('|')')
                tokens+=("OP:$c")
                i=$((i+1))
                ;;
            *)
                echo "Error: Unexpected character '$c'" >&2
                exit 1
                ;;
        esac
    done
    
    printf '%s\n' "${tokens[@]}"
}

# ----------------------------------------------------------------------
# Shunting-yard algorithm - infix to postfix (RPN)
# ----------------------------------------------------------------------
precedence() {
    case "$1" in
        '+'|'-') echo 1 ;;
        '*'|'/'|'%') echo 2 ;;
        *) echo 0 ;;
    esac
}

to_rpn() {
    local tokens=("$@")
    local output=()
    local stack=()
    
    for token in "${tokens[@]}"; do
        local type="${token%%:*}"
        local val="${token#*:}"
        
        if [ "$type" = "INT" ] || [ "$type" = "FLOAT" ]; then
            output+=("$token")
        elif [ "$type" = "OP" ]; then
            case "$val" in
                '(')
                    stack+=("$token")
                    ;;
                ')')
                    while [ ${#stack[@]} -gt 0 ] && [ "${stack[-1]#*:}" != "(" ]; do
                        output+=("${stack[-1]}")
                        unset 'stack[-1]'
                    done
                    [ ${#stack[@]} -gt 0 ] && unset 'stack[-1]'
                    ;;
                *)
                    local prec=$(precedence "$val")
                    while [ ${#stack[@]} -gt 0 ]; do
                        local top="${stack[-1]}"
                        local top_op="${top#*:}"
                        [ "$top_op" = "(" ] && break
                        local top_prec=$(precedence "$top_op")
                        [ $top_prec -lt $prec ] && break
                        output+=("$top")
                        unset 'stack[-1]'
                    done
                    stack+=("$token")
                    ;;
            esac
        fi
    done
    
    while [ ${#stack[@]} -gt 0 ]; do
        output+=("${stack[-1]}")
        unset 'stack[-1]'
    done
    
    printf '%s\n' "${output[@]}"
}

# ----------------------------------------------------------------------
# Generate float constants in .data section
# ----------------------------------------------------------------------
generate_float_constants() {
    local rpn_tokens=("$@")
    local const_idx=0
    local constants=""
    
    for token in "${rpn_tokens[@]}"; do
        local type="${token%%:*}"
        local val="${token#*:}"
        
        if [ "$type" = "FLOAT" ]; then
            # Convert scientific notation to decimal for dd (single precision)
            local float_val=$(printf "%.10f" "$val" 2>/dev/null || echo "$val")
            
            # Generate unique label
            local label="${VAR_NAME}_float${const_idx}"
            constants="${constants}    ${label} dd ${float_val}    ; ${val}"$'\n'
            const_idx=$((const_idx+1))
        fi
    done
    
    echo "$constants"
}

# ----------------------------------------------------------------------
# Generate assembly code from RPN tokens (FPU version)
# ----------------------------------------------------------------------
generate_asm_fpu() {
    local rpn_tokens=("$@")
    local code=""
    local const_idx=0
    local has_float=false
    
    # First pass: check if we need FPU
    for token in "${rpn_tokens[@]}"; do
        [[ "${token%%:*}" == "FLOAT" ]] && has_float=true
    done
    
    code="${code}    ; Runtime evaluation of: $VAR_VALUE"$'\n'
    
    if [ "$has_float" = true ]; then
        code="${code}    ; Using x87 FPU for float operations"$'\n'
    fi
    
    for token in "${rpn_tokens[@]}"; do
        local type="${token%%:*}"
        local val="${token#*:}"
        
        if [ "$type" = "INT" ]; then
            if [ "$has_float" = true ]; then
                # Convert integer to float and push to FPU stack
                code="${code}    push $val"$'\n'
                code="${code}    fild qword [rsp]"$'\n'
                code="${code}    add rsp, 8"$'\n'
            else
                # Pure integer mode - use regular stack
                code="${code}    push $val"$'\n'
            fi
            
        elif [ "$type" = "FLOAT" ]; then
            # Load float constant from memory
            local label="${VAR_NAME}_float${const_idx}"
            code="${code}    fld dword [${label}]"$'\n'
            const_idx=$((const_idx+1))
            
        elif [ "$type" = "OP" ]; then
            if [ "$has_float" = true ]; then
                # FPU operations
                case "$val" in
                    '+')
                        code="${code}    faddp st1, st0"$'\n'
                        ;;
                    '-')
                        code="${code}    fsubp st1, st0"$'\n'
                        ;;
                    '*')
                        code="${code}    fmulp st1, st0"$'\n'
                        ;;
                    '/')
                        code="${code}    fdivp st1, st0"$'\n'
                        ;;
                    '%')
                        # Modulo with floats - use FPREM
                        code="${code}    fprem"$'\n'
                        code="${code}    fstp st1"$'\n'
                        ;;
                esac
            else
                # Integer operations
                case "$val" in
                    '+')
                        code="${code}    pop rbx"$'\n'
                        code="${code}    pop rax"$'\n'
                        code="${code}    add rax, rbx"$'\n'
                        code="${code}    push rax"$'\n'
                        ;;
                    '-')
                        code="${code}    pop rbx"$'\n'
                        code="${code}    pop rax"$'\n'
                        code="${code}    sub rax, rbx"$'\n'
                        code="${code}    push rax"$'\n'
                        ;;
                    '*')
                        code="${code}    pop rbx"$'\n'
                        code="${code}    pop rax"$'\n'
                        code="${code}    imul rbx"$'\n'
                        code="${code}    push rax"$'\n'
                        ;;
                    '/')
                        code="${code}    xor rdx, rdx"$'\n'
                        code="${code}    pop rbx"$'\n'
                        code="${code}    pop rax"$'\n'
                        code="${code}    idiv rbx"$'\n'
                        code="${code}    push rax"$'\n'
                        ;;
                    '%')
                        code="${code}    xor rdx, rdx"$'\n'
                        code="${code}    pop rbx"$'\n'
                        code="${code}    pop rax"$'\n'
                        code="${code}    idiv rbx"$'\n'
                        code="${code}    push rdx"$'\n'
                        ;;
                esac
            fi
        fi
    done
    
    # Store result
    if [ "$has_float" = true ]; then
        # Store FPU result to memory as float string
        code="${code}    ; Store float result"$'\n'
        code="${code}    sub rsp, 8"$'\n'
        code="${code}    fstp qword [rsp]"$'\n'
        code="${code}    pop rax"$'\n'
        code="${code}    mov [${VAR_NAME}_float_val], rax"$'\n'
        code="${code}    ; Convert float to string for printing"$'\n'
        code="${code}    ; Store pointer to float string"$'\n'
        code="${code}    mov qword [${VAR_NAME}], ${VAR_NAME}_float_str"$'\n'
    else
        code="${code}    pop rax"$'\n'
        code="${code}    mov [${VAR_NAME}], rax"$'\n'
    fi
    
    echo "$code"
}

# ----------------------------------------------------------------------
# Main logic
# ----------------------------------------------------------------------
DATA_SECTION=""
CODE_SECTION=""
IS_FLOAT=false

# Handle different value types
if [[ "$VAR_VALUE" =~ ^-?0[xX][0-9a-fA-F]+$ ]] || \
   [[ "$VAR_VALUE" =~ ^-?0[bB][01]+$ ]] || \
   [[ "$VAR_VALUE" =~ ^-?0[0-7]+$ ]]; then
    # Hex/Binary/Octal literal - integer
    DATA_SECTION="    ; Variable: $VAR_NAME = $VAR_VALUE (type: integer)"$'\n'
    DATA_SECTION="${DATA_SECTION}    ${VAR_NAME} dq $VAR_VALUE"$'\n'

elif [[ "$VAR_VALUE" =~ ^-?[0-9]*\.[0-9]+$ ]] || [[ "$VAR_VALUE" =~ ^-?[0-9]+[eE][-+]?[0-9]+$ ]]; then
    # Simple float literal - NO EXPRESSION
    IS_FLOAT=true
    FLOAT_VAL=$(printf "%.10f" "$VAR_VALUE" 2>/dev/null | sed 's/\.0*$//' || echo "$VAR_VALUE")
    
    DATA_SECTION="    ; Variable: $VAR_NAME = $VAR_VALUE (type: float)"$'\n'
    DATA_SECTION="${DATA_SECTION}    ${VAR_NAME}_float_val dq 0    ; Storage for float value"$'\n'
    DATA_SECTION="${DATA_SECTION}    ${VAR_NAME}_float dd $FLOAT_VAL    ; The actual float constant"$'\n'
    DATA_SECTION="${DATA_SECTION}    ${VAR_NAME}_float_str db '$FLOAT_VAL', 0    ; String representation"$'\n'
    DATA_SECTION="${DATA_SECTION}    ${VAR_NAME} dq ${VAR_NAME}_float_str    ; Pointer for printing"$'\n'
    
    CODE_SECTION="    ; Initialize float value"$'\n'
    CODE_SECTION="${CODE_SECTION}    fld dword [${VAR_NAME}_float]"$'\n'
    CODE_SECTION="${CODE_SECTION}    fstp qword [${VAR_NAME}_float_val]"$'\n'

elif has_operators "$VAR_VALUE"; then
    # Expression - evaluate at runtime
    mapfile -t tokens < <(tokenize "$VAR_VALUE")
    mapfile -t rpn_tokens < <(to_rpn "${tokens[@]}")
    
    # Check if expression contains floats
    if contains_float "$VAR_VALUE"; then
        IS_FLOAT=true
        FLOAT_CONSTANTS=$(generate_float_constants "${rpn_tokens[@]}")
        
        DATA_SECTION="    ; Variable: $VAR_NAME (runtime float expression: $VAR_VALUE) (type: float)"$'\n'
        DATA_SECTION="${DATA_SECTION}${FLOAT_CONSTANTS}"
        DATA_SECTION="${DATA_SECTION}    ${VAR_NAME}_float_val dq 0    ; Storage for float result"$'\n'
        DATA_SECTION="${DATA_SECTION}    ${VAR_NAME}_float_str db 32 dup(0)    ; Buffer for float->string"$'\n'
        DATA_SECTION="${DATA_SECTION}    ${VAR_NAME} dq ${VAR_NAME}_float_str    ; Pointer for printing"$'\n'
        
        CODE_SECTION=$(generate_asm_fpu "${rpn_tokens[@]}")
    else
        # Pure integer expression
        DATA_SECTION="    ; Variable: $VAR_NAME (runtime evaluated from: $VAR_VALUE) (type: integer)"$'\n'
        DATA_SECTION="${DATA_SECTION}    ${VAR_NAME} dq 0"$'\n'
        CODE_SECTION=$(generate_asm_fpu "${rpn_tokens[@]}")
    fi

else
    # Simple integer
    DATA_SECTION="    ; Variable: $VAR_NAME = $VAR_VALUE (type: integer)"$'\n'
    DATA_SECTION="${DATA_SECTION}    ${VAR_NAME} dq $VAR_VALUE"$'\n'
fi

# ----------------------------------------------------------------------
# Insert into build_output.asm
# ----------------------------------------------------------------------
TEMP_FILE=$(mktemp)
IN_DATA=0
IN_START=0
DATA_DONE=0
CODE_DONE=0

while IFS= read -r line; do
    # Track sections
    if [[ "$line" == "section .data" ]]; then
        IN_DATA=1
    elif [[ "$line" == section* ]] && [ "$IN_DATA" -eq 1 ]; then
        if [ "$DATA_DONE" -eq 0 ] && [ -n "$DATA_SECTION" ]; then
            echo "$DATA_SECTION" >> "$TEMP_FILE"
            DATA_DONE=1
        fi
        IN_DATA=0
    fi
    
    if [[ "$line" == "_start:" ]]; then
        IN_START=1
    fi
    
    # Insert runtime code before exit syscall
    if [ "$IN_START" -eq 1 ] && [ "$CODE_DONE" -eq 0 ] && \
       [[ "$line" =~ ^[[:space:]]*mov[[:space:]]+rax,[[:space:]]*60 ]] && \
       [ -n "$CODE_SECTION" ]; then
        echo "$CODE_SECTION" >> "$TEMP_FILE"
        CODE_DONE=1
    fi
    
    echo "$line" >> "$TEMP_FILE"
done < "$OUTPUT_FILE"

# Handle edge cases
if [ "$IN_DATA" -eq 1 ] && [ "$DATA_DONE" -eq 0 ] && [ -n "$DATA_SECTION" ]; then
    echo "$DATA_SECTION" >> "$TEMP_FILE"
fi

if [ "$CODE_DONE" -eq 0 ] && [ -n "$CODE_SECTION" ]; then
    echo "$CODE_SECTION" >> "$TEMP_FILE"
fi

mv "$TEMP_FILE" "$OUTPUT_FILE"

if [ "$IS_FLOAT" = true ]; then
    echo "Successfully added float variable $VAR_NAME = $VAR_VALUE"
else
    echo "Successfully added integer variable $VAR_NAME = $VAR_VALUE"
fi
exit 0