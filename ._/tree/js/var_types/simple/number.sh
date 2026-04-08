#!/bin/bash

# number.sh - Converts JavaScript number declarations to NASM assembly code

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
cd "$SCRIPT_DIR/simple"

OUTPUT_FILE="../../../../build_output.asm"
INPUT_FILE="../../var_input"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found"
    exit 1
fi

INPUT_CONTENT=$(cat "$INPUT_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
INPUT_CONTENT="${INPUT_CONTENT%;}"

if [[ "$INPUT_CONTENT" =~ ^(let|var|const)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
    DECL_TYPE="${BASH_REMATCH[1]}"
    VAR_NAME="${BASH_REMATCH[2]}"
    VAR_VALUE="${BASH_REMATCH[3]}"
    VAR_VALUE=$(echo "$VAR_VALUE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
else
    echo "Error: Invalid variable declaration format"
    exit 1
fi

# Convert number formats
convert_number() {
    local num="$1"
    
    if [[ "$num" =~ ^0[xX][0-9a-fA-F]+$ ]]; then
        echo $((16#${num#0x}))
    elif [[ "$num" =~ ^0[bB][01]+$ ]]; then
        echo $((2#${num#0b}))
    elif [[ "$num" =~ ^0[0-7]+$ ]] && [[ "$num" != "0" ]]; then
        echo $((8#$num))
    else
        echo "$num"
    fi
}

# Evaluate expression properly
evaluate_expression() {
    local expr="$1"
    
    # Remove all spaces
    expr=$(echo "$expr" | tr -d ' ')
    
    # Convert hex/binary/octal to decimal
    local converted=""
    local i=0
    while [ $i -lt ${#expr} ]; do
        local char="${expr:$i:1}"
        
        if [[ "$char" =~ [0-9] ]]; then
            local num="$char"
            i=$((i+1))
            
            # Check for 0x prefix
            if [[ "$char" == "0" ]] && [ $i -lt ${#expr} ] && [[ "${expr:$i:1}" =~ [xX] ]]; then
                i=$((i+1))
                num="0x"
                while [ $i -lt ${#expr} ] && [[ "${expr:$i:1}" =~ [0-9a-fA-F] ]]; do
                    num="${num}${expr:$i:1}"
                    i=$((i+1))
                done
                converted+=$(convert_number "$num")
            # Check for 0b prefix
            elif [[ "$char" == "0" ]] && [ $i -lt ${#expr} ] && [[ "${expr:$i:1}" =~ [bB] ]]; then
                i=$((i+1))
                num="0b"
                while [ $i -lt ${#expr} ] && [[ "${expr:$i:1}" =~ [01] ]]; do
                    num="${num}${expr:$i:1}"
                    i=$((i+1))
                done
                converted+=$(convert_number "$num")
            else
                # Regular number
                while [ $i -lt ${#expr} ] && [[ "${expr:$i:1}" =~ [0-9] ]]; do
                    num="${num}${expr:$i:1}"
                    i=$((i+1))
                done
                converted+="$num"
            fi
        else
            converted+="$char"
            i=$((i+1))
        fi
    done
    
    # Use bc to evaluate with proper precedence
    # Important: bc needs spaces around operators sometimes
    local result=$(echo "$converted" | bc 2>/dev/null)
    
    if [ -z "$result" ]; then
        echo "0"
    else
        echo "$result"
    fi
}

# Check if it's a simple number or expression
if [[ "$VAR_VALUE" =~ ^-?[0-9]+$ ]]; then
    CONVERTED_VALUE="$VAR_VALUE"
    ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = $VAR_VALUE (type: integer)"
    ASSEMBLY_DATA+="\n    ${VAR_NAME} dq $CONVERTED_VALUE"
    RUNTIME_CODE=""
    
elif [[ "$VAR_VALUE" =~ ^0[xX][0-9a-fA-F]+$ ]] || [[ "$VAR_VALUE" =~ ^0[bB][01]+$ ]] || [[ "$VAR_VALUE" =~ ^0[0-7]+$ ]]; then
    CONVERTED_VALUE=$(convert_number "$VAR_VALUE")
    ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = $VAR_VALUE (type: integer)"
    ASSEMBLY_DATA+="\n    ${VAR_NAME} dq $CONVERTED_VALUE"
    RUNTIME_CODE=""
    
elif [[ "$VAR_VALUE" =~ [+\-*/%()] ]]; then
    # It's an expression
    RESULT=$(evaluate_expression "$VAR_VALUE")
    ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = $VAR_VALUE (type: integer)"
    ASSEMBLY_DATA+="\n    ${VAR_NAME} dq $RESULT"
    RUNTIME_CODE=""
    
else
    # Unknown format, try to use as-is
    ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = $VAR_VALUE (type: integer)"
    ASSEMBLY_DATA+="\n    ${VAR_NAME} dq $VAR_VALUE"
    RUNTIME_CODE=""
fi

# Insert into file
TEMP_FILE=$(mktemp)
IN_DATA_SECTION=0
DATA_INSERTED=0

while IFS= read -r line; do
    if [[ "$line" == "section .data" ]]; then
        IN_DATA_SECTION=1
        echo "$line" >> "$TEMP_FILE"
        continue
    fi
    
    if [[ "$IN_DATA_SECTION" -eq 1 ]] && [[ "$line" == section* ]]; then
        if [ "$DATA_INSERTED" -eq 0 ]; then
            echo -e "$ASSEMBLY_DATA" >> "$TEMP_FILE"
            DATA_INSERTED=1
        fi
        IN_DATA_SECTION=0
    fi
    
    echo "$line" >> "$TEMP_FILE"
done < "$OUTPUT_FILE"

if [ "$DATA_INSERTED" -eq 0 ]; then
    echo -e "$ASSEMBLY_DATA" >> "$TEMP_FILE"
fi

mv "$TEMP_FILE" "$OUTPUT_FILE"
echo "Added variable: $VAR_NAME = $VAR_VALUE"