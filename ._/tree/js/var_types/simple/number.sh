#!/bin/bash

# number.sh - Converts JavaScript number declarations to NASM assembly code
# Now generates runtime evaluation of mathematical expressions with float support

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

# Remove trailing semicolon if present
INPUT_CONTENT="${INPUT_CONTENT%;}"

# Extract variable name and value
if [[ "$INPUT_CONTENT" =~ ^var[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
    VAR_NAME="${BASH_REMATCH[1]}"
    VAR_VALUE="${BASH_REMATCH[2]}"
    # Remove surrounding whitespace
    VAR_VALUE=$(echo "$VAR_VALUE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
else
    echo "Error: Invalid variable declaration format"
    echo "Expected format: var variableName = value"
    exit 1
fi

# Function to evaluate expression with bc
evaluate_expression() {
    local expr="$1"
    
    # Clean the expression - remove all spaces
    expr=$(echo "$expr" | tr -d '[:space:]')
    
    # Convert hex numbers to decimal for bc
    while [[ "$expr" =~ 0[xX][0-9a-fA-F]+ ]]; do
        hex_match="${BASH_REMATCH[0]}"
        hex_val="${hex_match#0x}"
        hex_val="${hex_val#0X}"
        dec_val=$((16#${hex_val}))
        expr="${expr//$hex_match/$dec_val}"
    done
    
    # Convert binary numbers to decimal for bc
    while [[ "$expr" =~ 0[bB][01]+ ]]; do
        bin_match="${BASH_REMATCH[0]}"
        bin_val="${bin_match#0b}"
        bin_val="${bin_val#0B}"
        dec_val=$((2#${bin_val}))
        expr="${expr//$bin_match/$dec_val}"
    done
    
    # Convert octal numbers to decimal for bc
    while [[ "$expr" =~ (^|[^0-9])0[0-7]+ ]]; do
        oct_match="${BASH_REMATCH[0]}"
        oct_val="${oct_match#0}"
        dec_val=$((8#${oct_val}))
        expr="${expr//$oct_match/$dec_val}"
    done
    
    # Evaluate with bc
    local result=$(echo "scale=10; $expr" | bc 2>/dev/null)
    
    if [ -z "$result" ]; then
        echo "0"
        return 1
    fi
    
    # Clean up the result
    # Remove trailing zeros after decimal point
    result=$(echo "$result" | sed -E 's/\.?0+$//')
    
    # If it's a whole number (no decimal point), it's an integer
    if [[ "$result" != *"."* ]]; then
        echo "$result"
    else
        # It's a float - keep the decimal part
        echo "$result"
    fi
    
    return 0
}

# Check if the expression contains operators
if [[ "$VAR_VALUE" =~ [-+*/%()] ]]; then
    # It's an expression - evaluate it
    RESULT=$(evaluate_expression "$VAR_VALUE")
    
    # Check if result is an integer or float
    if [[ "$RESULT" == *"."* ]]; then
        # It's a float
        ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = $VAR_VALUE"
        ASSEMBLY_DATA+=" (evaluated to: $RESULT - type: float)"
        ASSEMBLY_DATA+="\n    ${VAR_NAME}_float db '$RESULT', 0    ; float stored as string"
        ASSEMBLY_DATA+="\n    ${VAR_NAME} dq ${VAR_NAME}_float    ; pointer to float string"
        IS_FLOAT=1
    else
        # It's an integer
        ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = $VAR_VALUE"
        ASSEMBLY_DATA+=" (evaluated to: $RESULT - type: integer)"
        ASSEMBLY_DATA+="\n    ${VAR_NAME} dq $RESULT    ; numeric value"
        IS_FLOAT=0
    fi
else
    # Check if it's a hex number
    if [[ "$VAR_VALUE" =~ ^-?0[xX][0-9a-fA-F]+$ ]]; then
        local is_negative=""
        if [[ "$VAR_VALUE" =~ ^- ]]; then
            is_negative="-"
            VAR_VALUE="${VAR_VALUE#-}"
        fi
        local hex_val="${VAR_VALUE#0x}"
        hex_val="${hex_val#0X}"
        RESULT=$((16#${hex_val}))
        RESULT="${is_negative}${RESULT}"
        ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = $VAR_VALUE (type: integer)"
        ASSEMBLY_DATA+="\n    ${VAR_NAME} dq $RESULT    ; numeric value"
        IS_FLOAT=0
    
    # Check if it's a binary number
    elif [[ "$VAR_VALUE" =~ ^-?0[bB][01]+$ ]]; then
        local is_negative=""
        if [[ "$VAR_VALUE" =~ ^- ]]; then
            is_negative="-"
            VAR_VALUE="${VAR_VALUE#-}"
        fi
        local bin_val="${VAR_VALUE#0b}"
        bin_val="${bin_val#0B}"
        RESULT=$((2#${bin_val}))
        RESULT="${is_negative}${RESULT}"
        ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = $VAR_VALUE (type: integer)"
        ASSEMBLY_DATA+="\n    ${VAR_NAME} dq $RESULT    ; numeric value"
        IS_FLOAT=0
    
    # Check if it's an octal number
    elif [[ "$VAR_VALUE" =~ ^-?0[0-7]+$ ]]; then
        local is_negative=""
        if [[ "$VAR_VALUE" =~ ^- ]]; then
            is_negative="-"
            VAR_VALUE="${VAR_VALUE#-}"
        fi
        RESULT=$((8#${VAR_VALUE}))
        RESULT="${is_negative}${RESULT}"
        ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = $VAR_VALUE (type: integer)"
        ASSEMBLY_DATA+="\n    ${VAR_NAME} dq $RESULT    ; numeric value"
        IS_FLOAT=0
    
    # Check if it's a float literal
    elif [[ "$VAR_VALUE" =~ ^-?[0-9]*\.[0-9]+$ ]] || [[ "$VAR_VALUE" =~ ^-?[0-9]+[eE][-+]?[0-9]+$ ]]; then
        ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = $VAR_VALUE (type: float)"
        ASSEMBLY_DATA+="\n    ${VAR_NAME}_float db '$VAR_VALUE', 0    ; float stored as string"
        ASSEMBLY_DATA+="\n    ${VAR_NAME} dq ${VAR_NAME}_float    ; pointer to float string"
        IS_FLOAT=1
    
    # Regular integer
    else
        ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = $VAR_VALUE (type: integer)"
        ASSEMBLY_DATA+="\n    ${VAR_NAME} dq $VAR_VALUE    ; numeric value"
        IS_FLOAT=0
    fi
fi

# Create temporary file
TEMP_FILE=$(mktemp)

# Insert data into .data section
IN_DATA_SECTION=0
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
        # We're leaving data section, insert our data before leaving
        if [ "$DATA_INSERTED" -eq 0 ]; then
            echo -e "$ASSEMBLY_DATA" >> "$TEMP_FILE"
            DATA_INSERTED=1
        fi
        
        IN_DATA_SECTION=0
    fi
    
    # Write the current line
    echo "$line" >> "$TEMP_FILE"
    
done < "$OUTPUT_FILE"

# If we're still in data section at EOF, append data
if [[ "$IN_DATA_SECTION" -eq 1 ]] && [ "$DATA_INSERTED" -eq 0 ]; then
    echo -e "$ASSEMBLY_DATA" >> "$TEMP_FILE"
fi

# Replace the original file
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "Successfully added number variable declaration to $OUTPUT_FILE"
echo "Variable: $VAR_NAME = $VAR_VALUE"
if [[ "$IS_FLOAT" -eq 1 ]]; then
    echo "Type: float"
else
    echo "Type: integer"
fi
exit 0