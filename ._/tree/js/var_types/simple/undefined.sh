#!/bin/bash

# undefined.sh - Converts JavaScript undefined declarations to NASM assembly data structures
# In JavaScript, undefined represents a variable that has been declared but not assigned a value

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
    echo "Expected format: var variableName = undefined"
    exit 1
fi

# Validate that the value is actually undefined (case insensitive)
if [[ ! "$VAR_VALUE" =~ ^[Uu]ndefined$ ]]; then
    echo "Error: Expected 'undefined' but got '$VAR_VALUE'"
    exit 1
fi

# Generate assembly data - MATCH THE FORMAT THAT log.sh EXPECTS
ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = undefined (type: undefined)"
ASSEMBLY_DATA+="\n    ${VAR_NAME}_defined_flag db 0 ; 0 = undefined, 1 = defined"
ASSEMBLY_DATA+="\n    ${VAR_NAME}_value dq 0 ; Placeholder for value"
ASSEMBLY_DATA+="\n    ${VAR_NAME}:"

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

echo "Successfully added undefined variable declaration to $OUTPUT_FILE"
echo "Variable: $VAR_NAME = undefined"
echo "Type: undefined"
echo "Note: In JavaScript, undefined indicates the variable has been declared but not assigned a value"
exit 0