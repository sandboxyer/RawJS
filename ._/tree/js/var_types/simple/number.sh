#!/bin/bash

# number.sh - Converts JavaScript number declarations to NASM assembly code
# Generates runtime evaluation code for expressions.

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
# Helper: check if expression contains operators or parentheses
# ----------------------------------------------------------------------
has_operators() {
    [[ "$1" =~ [\+\-\*/%\(\)] ]]
}

# ----------------------------------------------------------------------
# Tokenizer - returns array of tokens (type:value)
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
        
        # Number
        if [[ "$c" =~ [0-9] ]]; then
            local num="$c"
            i=$((i+1))
            while [ $i -lt $len ] && [[ "${expr:$i:1}" =~ [0-9] ]]; do
                num="${num}${expr:$i:1}"
                i=$((i+1))
            done
            tokens+=("NUM:$num")
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
        
        if [ "$type" = "NUM" ]; then
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
                    [ ${#stack[@]} -gt 0 ] && unset 'stack[-1]'  # Remove '('
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
# Generate assembly code from RPN tokens
# ----------------------------------------------------------------------
generate_asm() {
    local rpn_tokens=("$@")
    local code=""
    
    code="${code}    ; Runtime evaluation of: $VAR_VALUE"$'\n'
    
    for token in "${rpn_tokens[@]}"; do
        local type="${token%%:*}"
        local val="${token#*:}"
        
        if [ "$type" = "NUM" ]; then
            code="${code}    push $val"$'\n'
        elif [ "$type" = "OP" ]; then
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
    done
    
    code="${code}    pop rax"$'\n'
    code="${code}    mov [${VAR_NAME}], rax"$'\n'
    
    echo "$code"
}

# ----------------------------------------------------------------------
# Main logic
# ----------------------------------------------------------------------
DATA_SECTION=""
CODE_SECTION=""

# Handle different value types
if [[ "$VAR_VALUE" =~ ^-?0[xX][0-9a-fA-F]+$ ]] || \
   [[ "$VAR_VALUE" =~ ^-?0[bB][01]+$ ]] || \
   [[ "$VAR_VALUE" =~ ^-?0[0-7]+$ ]]; then
    # Hex/Binary/Octal literal
    DATA_SECTION="    ; Variable: $VAR_NAME = $VAR_VALUE (type: integer)"$'\n'
    DATA_SECTION="${DATA_SECTION}    ${VAR_NAME} dq $VAR_VALUE"$'\n'

elif [[ "$VAR_VALUE" =~ ^-?[0-9]*\.[0-9]+$ ]] || [[ "$VAR_VALUE" =~ ^-?[0-9]+[eE][-+]?[0-9]+$ ]]; then
    # Float literal
    RESULT=$(echo "scale=10; $VAR_VALUE" | bc 2>/dev/null | sed -E 's/\.?0+$//')
    DATA_SECTION="    ; Variable: $VAR_NAME = $VAR_VALUE (type: float)"$'\n'
    DATA_SECTION="${DATA_SECTION}    ${VAR_NAME}_float db '$RESULT', 0"$'\n'
    DATA_SECTION="${DATA_SECTION}    ${VAR_NAME} dq ${VAR_NAME}_float"$'\n'

elif has_operators "$VAR_VALUE"; then
    # Expression - evaluate at runtime
    mapfile -t tokens < <(tokenize "$VAR_VALUE")
    mapfile -t rpn_tokens < <(to_rpn "${tokens[@]}")
    CODE_SECTION=$(generate_asm "${rpn_tokens[@]}")
    DATA_SECTION="    ; Variable: $VAR_NAME (runtime evaluated from: $VAR_VALUE) (type: integer)"$'\n'
    DATA_SECTION="${DATA_SECTION}    ${VAR_NAME} dq 0"$'\n'

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

echo "Successfully added variable $VAR_NAME = $VAR_VALUE"
exit 0