#!/bin/bash

# simple.sh - Converts JavaScript var declarations to NASM assembly data structures
# Handles all primitive types: string, number, boolean, null, undefined, float

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_FILE="../../../build_output.asm"
INPUT_FILE="../var_input"

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

# Function to escape strings for NASM
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
        
        # Handle escape sequences
        if [ "$char" = "\\" ] && [ $((i+1)) -lt $len ]; then
            local next_char="${str:$((i+1)):1}"
            case "$next_char" in
                n)  result="${result}10, " ;;
                t)  result="${result}9, " ;;
                r)  result="${result}13, " ;;
                \\\\) result="${result}92, " ;;
                \") result="${result}34, " ;;
                \') result="${result}39, " ;;
                *)  result="${result}92, ${next_char}, " ;;
            esac
            i=$((i+2))
        else
            # ASCII characters (0-127) - single byte
            if [ $char_code -lt 128 ]; then
                result="${result}${char_code}, "
            fi
            i=$((i+1))
        fi
    done
    
    # Remove trailing comma and space, add null terminator
    result="${result%, }"
    if [ -n "$result" ]; then
        echo "${result}, 0"
    else
        echo "0"
    fi
}

# Function to determine and process primitive type
process_primitive_type() {
    local value="$1"
    
    # Trim whitespace
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Check for null
    if [ "$value" = "null" ]; then
        echo "NULL"
        return
    fi
    
    # Check for undefined
    if [ "$value" = "undefined" ]; then
        echo "UNDEFINED"
        return
    fi
    
    # Check for boolean
    if [ "$value" = "true" ] || [ "$value" = "false" ]; then
        if [ "$value" = "true" ]; then
            echo "BOOL:1"
        else
            echo "BOOL:0"
        fi
        return
    fi
    
    # Check for string (starts and ends with quotes)
    if [[ "$value" =~ ^\"([^\"]*)\"$ ]] || [[ "$value" =~ ^\'([^\']*)\'$ ]]; then
        local str_content="${BASH_REMATCH[1]}"
        local escaped=$(escape_for_nasm "$str_content")
        echo "STRING:$escaped"
        return
    fi
    
    # Check for number (integer or float)
    # Check if it's a valid number (including negative, decimal, and scientific notation)
    if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$ ]] && [[ ! "$value" =~ ^-?0[0-9]+ ]]; then
        # Check if it has a decimal point or scientific notation (treat as float)
        if [[ "$value" =~ \. ]] || [[ "$value" =~ [eE] ]]; then
            # Try to parse as float
            if [[ "$value" =~ ^-?[0-9]*\.[0-9]+$ ]] || [[ "$value" =~ ^-?[0-9]+\.?[0-9]*[eE][-+]?[0-9]+$ ]]; then
                echo "FLOAT:$value"
                return
            fi
        fi
        
        # Otherwise treat as integer
        echo "INTEGER:$value"
        return
    fi
    
    # Check for variable reference (valid JavaScript identifier)
    if [[ "$value" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "REFERENCE:$value"
        return
    fi
    
    # Default to string if no other type matches (quotes might have been stripped)
    local escaped=$(escape_for_nasm "$value")
    echo "STRING:$escaped"
}

# Function to generate assembly data for primitive type
generate_assembly_for_primitive() {
    local var_name="$1"
    local processed_value="$2"
    local type_label="$3"
    
    local assembly_data="\n    ; Variable: $var_name = $VAR_VALUE (type: $type_label)"
    
    # Determine the type and generate appropriate assembly
    case "$processed_value" in
        "NULL")
            assembly_data+="\n    ${var_name} dq 0 ; null value"
            ;;
        "UNDEFINED")
            assembly_data+="\n    ${var_name} dq 0 ; undefined value"
            ;;
        "BOOL:"*)
            local bool_value="${processed_value#BOOL:}"
            assembly_data+="\n    ${var_name} dq $bool_value ; boolean"
            ;;
        "STRING:"*)
            local string_data="${processed_value#STRING:}"
            assembly_data+="\n    ${var_name} db $string_data ; string"
            ;;
        "INTEGER:"*)
            local int_value="${processed_value#INTEGER:}"
            assembly_data+="\n    ${var_name} dq $int_value ; integer"
            ;;
        "FLOAT:"*)
            local float_value="${processed_value#FLOAT:}"
            # Store float as QWORD (8-byte double precision)
            assembly_data+="\n    ${var_name} dq __float64__($float_value) ; float"
            ;;
        "REFERENCE:"*)
            local ref_name="${processed_value#REFERENCE:}"
            assembly_data+="\n    ${var_name} dq $ref_name ; reference to $ref_name"
            ;;
        *)
            assembly_data+="\n    ${var_name} dq 0 ; unknown type"
            ;;
    esac
    
    echo -e "$assembly_data"
}

# Main execution
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: $OUTPUT_FILE not found"
    echo "Expected at: $OUTPUT_FILE"
    exit 1
fi

# Process the variable value
PROCESSED_VALUE=$(process_primitive_type "$VAR_VALUE")

# Extract type label for display
TYPE_LABEL=""
case "$PROCESSED_VALUE" in
    "NULL") TYPE_LABEL="null" ;;
    "UNDEFINED") TYPE_LABEL="undefined" ;;
    "BOOL:"*) TYPE_LABEL="boolean" ;;
    "STRING:"*) TYPE_LABEL="string" ;;
    "INTEGER:"*) TYPE_LABEL="integer" ;;
    "FLOAT:"*) TYPE_LABEL="float" ;;
    "REFERENCE:"*) TYPE_LABEL="reference" ;;
    *) TYPE_LABEL="unknown" ;;
esac

# Generate assembly data
ASSEMBLY_DATA=$(generate_assembly_for_primitive "$VAR_NAME" "$PROCESSED_VALUE" "$TYPE_LABEL")

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

echo "Successfully added variable declaration to $OUTPUT_FILE"
echo "Variable: $VAR_NAME = $VAR_VALUE"
echo "Type: $TYPE_LABEL"