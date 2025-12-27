#!/bin/bash

# simple.sh - Converts JavaScript var declarations to NASM assembly data structures
# Enhanced version with type tracking for proper console.log support

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_FILE="../../../build_output.asm"
INPUT_FILE="../var_input"
TYPE_REGISTRY="var_types.txt"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found"
    exit 1
fi

# Read and clean the input
INPUT_CONTENT=$(cat "$INPUT_FILE" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Extract variable name and value
if [[ "$INPUT_CONTENT" =~ ^var[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
    VAR_NAME="${BASH_REMATCH[1]}"
    VAR_VALUE="${BASH_REMATCH[2]}"
    # Remove trailing semicolon if present
    VAR_VALUE="${VAR_VALUE%;}"
else
    echo "Error: Invalid variable declaration format"
    echo "Expected format: var variableName = value"
    exit 1
fi

# Function to escape strings for NASM
# Function to escape strings for NASM with UTF-8 support
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
            # Handle UTF-8 characters (non-ASCII)
            local char_code=$(printf "%d" "'$char")
            
            # ASCII characters (0-127) - single byte
            if [ $char_code -lt 128 ]; then
                result="${result}${char_code}, "
            else
                # UTF-8 multi-byte character - get proper byte sequence
                # Use printf to get hex representation
                local hex_bytes=$(printf "$char" | od -t x1 -An | tr -d ' \n' | sed 's/\(..\)/0x\1, /g')
                # Remove trailing comma and space, add proper formatting
                hex_bytes="${hex_bytes%, }"
                result="${result}${hex_bytes}, "
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
    if [[ "$value" =~ ^\"([^\"]*)\"$ ]]; then
        local str_content="${BASH_REMATCH[1]}"
        local escaped=$(escape_for_nasm "$str_content")
        echo "STRING:$escaped"
        return
    fi
    
    # Check for string with single quotes
    if [[ "$value" =~ ^\'([^\']*)\'$ ]]; then
        local str_content="${BASH_REMATCH[1]}"
        local escaped=$(escape_for_nasm "$str_content")
        echo "STRING:$escaped"
        return
    fi
    
    # Check for number (integer or float)
    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
        echo "INTEGER:$value"
        return
    fi
    
    if [[ "$value" =~ ^-?[0-9]*\.[0-9]+$ ]] || [[ "$value" =~ ^-?[0-9]+\.[0-9]*$ ]]; then
        # Check if it can be represented as integer (no decimal part)
        if [[ "$value" =~ ^-?[0-9]+\.0*$ ]] || [[ "$value" =~ ^-?0*\.0*$ ]]; then
            local int_part=$(echo "$value" | sed 's/\..*$//')
            echo "INTEGER:${int_part:-0}"
        else
            echo "FLOAT:$value"
        fi
        return
    fi
    
    # Check for scientific notation
    if [[ "$value" =~ ^-?[0-9]*\.?[0-9]+[eE][-+]?[0-9]+$ ]]; then
        echo "FLOAT:$value"
        return
    fi
    
    # Check for variable reference (valid JavaScript identifier)
    if [[ "$value" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "REFERENCE:$value"
        return
    fi
    
    # Default to undefined for unrecognized types
    echo "UNDEFINED"
}

# Function to generate assembly data for primitive type
generate_assembly_for_primitive() {
    local var_name="$1"
    local processed_value="$2"
    local type_label="$3"
    
    local assembly_data=""
    
    # Add comment for the variable
    assembly_data="    ; Variable: $var_name (type: $type_label)\n"
    
    # Determine the type and generate appropriate assembly
    case "$processed_value" in
        "NULL")
            assembly_data+="    ${var_name} dq 0 ; type: null\n"
            ;;
        "UNDEFINED")
            assembly_data+="    ${var_name} dq 0 ; type: undefined\n"
            ;;
        "BOOL:"*)
            local bool_value="${processed_value#BOOL:}"
            assembly_data+="    ${var_name} dq $bool_value ; type: boolean\n"
            ;;
        "STRING:"*)
            local string_data="${processed_value#STRING:}"
            assembly_data+="    ${var_name} db $string_data ; type: string\n"
            ;;
        "INTEGER:"*)
            local int_value="${processed_value#INTEGER:}"
            assembly_data+="    ${var_name} dq $int_value ; type: integer\n"
            ;;
        "FLOAT:"*)
            local float_value="${processed_value#FLOAT:}"
            # Store float as QWORD (8-byte double precision)
            assembly_data+="    ${var_name} dq __float64__($float_value) ; type: float\n"
            ;;
        "REFERENCE:"*)
            local ref_name="${processed_value#REFERENCE:}"
            assembly_data+="    ${var_name} dq ${ref_name} ; type: reference to $ref_name\n"
            ;;
        *)
            assembly_data+="    ${var_name} dq 0 ; type: unknown\n"
            ;;
    esac
    
    echo -e "$assembly_data"
}

# Function to register variable type
register_variable_type() {
    local var_name="$1"
    local var_type="$2"
    local value="$3"
    
    # Create or append to type registry
    echo "$var_name:$var_type:$value" >> "$SCRIPT_DIR/$TYPE_REGISTRY"
}

# Main execution
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: $OUTPUT_FILE not found"
    echo "Expected at: $OUTPUT_FILE"
    exit 1
fi

# Process the variable value
PROCESSED_VALUE=$(process_primitive_type "$VAR_VALUE")

# Extract type label for registration
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

# Register the variable type
register_variable_type "$VAR_NAME" "$TYPE_LABEL" "$VAR_VALUE"

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
    if [[ "$IN_DATA_SECTION" -eq 1 ]] && [[ "$line" == "section ."* ]]; then
        # We're leaving data section, insert our data before leaving
        if [ "$DATA_INSERTED" -eq 0 ]; then
            echo "" >> "$TEMP_FILE"
            echo "    ; === Generated by simple.sh ===" >> "$TEMP_FILE"
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
    echo "" >> "$TEMP_FILE"
    echo "    ; === Generated by simple.sh ===" >> "$TEMP_FILE"
    echo -e "$ASSEMBLY_DATA" >> "$TEMP_FILE"
fi

# Replace the original file
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "Successfully added variable declaration to $OUTPUT_FILE"
echo "Variable: $VAR_NAME"
echo "Value: $VAR_VALUE"
echo "Type: $TYPE_LABEL"
echo "Registered in: $SCRIPT_DIR/$TYPE_REGISTRY"