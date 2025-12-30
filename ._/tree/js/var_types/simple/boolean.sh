#!/bin/bash

# boolean.sh - Converts JavaScript boolean declarations to NASM assembly data structures

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

# Normalize boolean value (handle case-insensitive)
NORMALIZED_VALUE=$(echo "$VAR_VALUE" | tr '[:upper:]' '[:lower:]')

# Validate and convert boolean value
case "$NORMALIZED_VALUE" in
    "true" | "false")
        # Valid boolean value
        ;;
    *)
        echo "Error: Invalid boolean value '$VAR_VALUE'"
        echo "Boolean values must be 'true' or 'false'"
        exit 1
        ;;
esac

# Convert boolean to assembly representation
# Using: true = 1, false = 0
BOOLEAN_NUMERIC=0
BOOLEAN_DISPLAY="false"
if [ "$NORMALIZED_VALUE" = "true" ]; then
    BOOLEAN_NUMERIC=1
    BOOLEAN_DISPLAY="true"
fi

# Generate assembly data
# Use dq (8 bytes) for boolean variables with proper comment
ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = $BOOLEAN_DISPLAY (type: boolean)"
ASSEMBLY_DATA+="\n    ${VAR_NAME} dq $BOOLEAN_NUMERIC    ; boolean: 0=false, 1=true"

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

echo "Successfully added boolean variable declaration to $OUTPUT_FILE"
echo "Variable: $VAR_NAME = $BOOLEAN_DISPLAY"
echo "Type: boolean (stored as: $BOOLEAN_NUMERIC)"
exit 0