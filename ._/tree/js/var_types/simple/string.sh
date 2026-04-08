#!/bin/bash

# string.sh - Converts JavaScript string declarations to NASM assembly code

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
if [[ "$INPUT_CONTENT" =~ ^(let|var|const)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
    DECL_TYPE="${BASH_REMATCH[1]}"
    VAR_NAME="${BASH_REMATCH[2]}"
    VAR_VALUE="${BASH_REMATCH[3]}"
    # Remove surrounding whitespace and quotes
    VAR_VALUE=$(echo "$VAR_VALUE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    VAR_VALUE="${VAR_VALUE//\"/}"
    VAR_VALUE="${VAR_VALUE//\'/}"
else
    echo "Error: Invalid variable declaration format"
    exit 1
fi

# Escape string for NASM
escape_string() {
    local str="$1"
    local result=""
    local i=0
    local len=${#str}
    
    while [ $i -lt $len ]; do
        local char="${str:$i:1}"
        case "$char" in
            $'\n') result="${result}', 10, '" ;;
            $'\r') result="${result}', 13, '" ;;
            $'\t') result="${result}', 9, '" ;;
            "'") result="${result}', 39, '" ;;
            *) result="${result}${char}" ;;
        esac
        i=$((i+1))
    done
    
    # Clean up the format
    result=$(echo "$result" | sed "s/^', //" | sed "s/, '$//")
    if [[ "$result" =~ ^[[:space:]]*$ ]]; then
        echo "db 0"
    else
        echo "db '$result', 0"
    fi
}

# Generate the string declaration
STRING_DEF=$(escape_string "$VAR_VALUE")
ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = \"$VAR_VALUE\" (type: string)"
ASSEMBLY_DATA+="\n    ${VAR_NAME} $STRING_DEF"

# Create temporary file
TEMP_FILE=$(mktemp)

# Insert data into .data section
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

if [[ "$IN_DATA_SECTION" -eq 1 ]] && [ "$DATA_INSERTED" -eq 0 ]; then
    echo -e "$ASSEMBLY_DATA" >> "$TEMP_FILE"
fi

mv "$TEMP_FILE" "$OUTPUT_FILE"
echo "Successfully added string variable: $VAR_NAME"