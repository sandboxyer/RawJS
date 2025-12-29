#!/bin/bash

# integer.sh - Converts JavaScript integer declarations to NASM assembly string data structures

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

# Function to evaluate arithmetic expression in bash (for simplicity)
# This will calculate the result and store it as a string
evaluate_expression() {
    local expr="$1"
    
    # First, check if it's a simple expression with + - * / %
    if [[ "$expr" =~ ^[0-9]+([-+*/%][0-9]+)*$ ]]; then
        # Safe evaluation using arithmetic expansion
        local result=$((expr))
        echo "$result"
        return 0
    fi
    
    # Check for hex, octal, binary in expressions (more complex)
    # For simplicity in this version, we'll handle basic arithmetic only
    echo "invalid"
    return 1
}

# Function to process integer value (handles arithmetic)
process_integer_value() {
    local value="$1"
    
    # First, check if it's an arithmetic expression
    if [[ "$value" =~ ^[0-9]+([-+*/%][0-9]+)+$ ]]; then
        # Try to evaluate the arithmetic expression
        local result=$(evaluate_expression "$value")
        if [ "$result" != "invalid" ]; then
            echo "$result"
            return 0
        fi
    fi
    
    # Check if it's a simple decimal integer (positive or negative)
    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
        echo "$value"
        return 0
    fi
    
    # Check if it's a hexadecimal integer (0x or 0X prefix)
    if [[ "$value" =~ ^0[xX][0-9a-fA-F]+$ ]]; then
        value="${value#0x}"
        value="${value#0X}"
        echo $(echo "ibase=16; $(echo $value | tr '[:lower:]' '[:upper:]')" | bc)
        return 0
    fi
    
    # Check if it's an octal integer (0 prefix, but not 0x/0X)
    if [[ "$value" =~ ^0[0-7]*$ ]] && ! [[ "$value" =~ ^0[xX] ]]; then
        value="0${value}"
        echo $(echo "ibase=8; $value" | bc)
        return 0
    fi
    
    # Check if it's a binary integer (0b or 0B prefix)
    if [[ "$value" =~ ^0[bB][01]+$ ]]; then
        value="${value#0b}"
        value="${value#0B}"
        echo $(echo "ibase=2; $value" | bc)
        return 0
    fi
    
    echo "invalid"
    return 1
}

# Process the integer value (including arithmetic)
DECIMAL_VALUE=$(process_integer_value "$VAR_VALUE")

if [ "$DECIMAL_VALUE" = "invalid" ]; then
    echo "Error: '$VAR_VALUE' is not a valid integer or arithmetic expression"
    echo "Supported formats:"
    echo "  Simple integers: 123, -456, 0xFF, 0123, 0b1010"
    echo "  Arithmetic expressions: 25+25, 100-50, 10*5, 20/4, 15%4"
    echo "  Can combine: 10+20-5, 2*3+4"
    exit 1
fi

# Function to escape strings for NASM (same as string.sh)
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
        
        # ASCII characters (0-127) - single byte
        if [ $char_code -lt 128 ]; then
            result="${result}${char_code}, "
        fi
        i=$((i+1))
    done
    
    # Remove trailing comma and space, add null terminator
    result="${result%, }"
    if [ -n "$result" ]; then
        echo "${result}, 0"
    else
        echo "0"
    fi
}

# Check if DECIMAL_VALUE contains arithmetic expression marker
if [[ "$VAR_VALUE" =~ [-+*/%] ]]; then
    # It was an arithmetic expression
    echo "Note: Arithmetic expression '$VAR_VALUE' evaluated to: $DECIMAL_VALUE"
fi

# Escape the decimal string for NASM
ESCAPED_STRING=$(escape_for_nasm "$DECIMAL_VALUE")

# Generate assembly data - store as STRING (null-terminated)
ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = $VAR_VALUE"
if [[ "$VAR_VALUE" =~ [-+*/%] ]]; then
    ASSEMBLY_DATA+=" (type: integer expression - evaluated to: $DECIMAL_VALUE)"
else
    ASSEMBLY_DATA+=" (type: integer)"
fi
ASSEMBLY_DATA+="\n    ${VAR_NAME} db $ESCAPED_STRING ; integer stored as string"

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

echo "Successfully added integer variable declaration to $OUTPUT_FILE"
echo "Variable: $VAR_NAME = $VAR_VALUE"
if [[ "$VAR_VALUE" =~ [-+*/%] ]]; then
    echo "Type: integer expression (evaluated to '$DECIMAL_VALUE')"
    echo "Stored as: string '$DECIMAL_VALUE' (null-terminated)"
else
    echo "Type: integer"
    echo "Stored as: string '$DECIMAL_VALUE' (null-terminated)"
fi
exit 0