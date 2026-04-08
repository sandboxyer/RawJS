#!/bin/bash

# undefined.sh - Handles undefined variable declarations

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

if [[ "$INPUT_CONTENT" =~ ^(let|var|const)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*undefined$ ]]; then
    VAR_NAME="${BASH_REMATCH[2]}"
    
    ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = undefined (type: undefined)"
    ASSEMBLY_DATA+="\n    ${VAR_NAME} dq 0    ; undefined value"
    
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
    echo "Added undefined variable: $VAR_NAME"
fi