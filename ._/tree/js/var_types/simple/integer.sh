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

# Function to validate and convert integer to decimal string
process_integer() {
    local value="$1"
    
    # Check if it's a decimal integer (positive or negative)
    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
        # Already decimal, just return as string
        echo "$value"
        return 0
    fi
    
    # Check if it's a hexadecimal integer (0x or 0X prefix)
    if [[ "$value" =~ ^0[xX][0-9a-fA-F]+$ ]]; then
        # Remove 0x or 0X prefix and convert to decimal
        value="${value#0x}"
        value="${value#0X}"
        # Convert hex to decimal (uppercase for bc)
        echo $(echo "ibase=16; $(echo $value | tr '[:lower:]' '[:upper:]')" | bc)
        return 0
    fi
    
    # Check if it's an octal integer (0 prefix, but not 0x/0X)
    if [[ "$value" =~ ^0[0-7]*$ ]] && ! [[ "$value" =~ ^0[xX] ]]; then
        # Remove leading 0 (octal prefix) and convert to decimal
        value="0${value}"
        echo $(echo "ibase=8; $value" | bc)
        return 0
    fi
    
    # Check if it's a binary integer (0b or 0B prefix)
    if [[ "$value" =~ ^0[bB][01]+$ ]]; then
        # Remove 0b or 0B prefix and convert to decimal
        value="${value#0b}"
        value="${value#0B}"
        # Convert binary to decimal
        echo $(echo "ibase=2; $value" | bc)
        return 0
    fi
    
    echo "invalid"
    return 1
}

# Process the integer
DECIMAL_STRING=$(process_integer "$VAR_VALUE")

if [ "$DECIMAL_STRING" = "invalid" ]; then
    echo "Error: '$VAR_VALUE' is not a valid integer"
    echo "Supported formats:"
    echo "  Decimal: 123, -456"
    echo "  Hexadecimal: 0x1A, 0XFF"
    echo "  Octal: 0123, 0777"
    echo "  Binary: 0b1010, 0B1100"
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

# Escape the decimal string for NASM
ESCAPED_STRING=$(escape_for_nasm "$DECIMAL_STRING")

# Generate assembly data
ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = $VAR_VALUE (type: integer)"
ASSEMBLY_DATA+="\n    ${VAR_NAME} db $ESCAPED_STRING ; integer as string"

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
echo "Variable: $VAR_NAME = $VAR_VALUE (stored as: '$DECIMAL_STRING')"
echo "Type: integer (stored as null-terminated string)"
exit 0
