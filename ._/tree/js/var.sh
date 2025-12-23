#!/bin/bash

# var.sh - Parses variable declarations and converts them to assembly data definitions
# Only handles var declarations (ignores let and const)
# Located 2 levels deeper than build_output.asm

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_FILE="../../build_output.asm"

if [ ! -f "var_input" ]; then
    echo "Error: var_input file not found in $(pwd)"
    exit 1
fi

# Read and clean the input
VAR_STATEMENT=$(cat var_input)

# Remove all newlines and extra spaces
VAR_STATEMENT=$(echo "$VAR_STATEMENT" | tr -d '\n' | tr -s ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Remove trailing semicolon if present
VAR_STATEMENT="${VAR_STATEMENT%;}"

# Check if there are multiple declarations separated by semicolons
# If yes, only process the first one and warn the user
if [[ "$VAR_STATEMENT" =~ \; ]]; then
    echo "Warning: Multiple declarations detected. Processing only the first declaration."
    VAR_STATEMENT="${VAR_STATEMENT%%;*}"
    echo "Processing: $VAR_STATEMENT"
fi

# Function to check if a string is a number (integer or float)
is_number() {
    local str="$1"
    # Check for integer or float (including negative numbers and scientific notation)
    if [[ "$str" =~ ^-?[0-9]+$ ]] || 
       [[ "$str" =~ ^-?[0-9]*\.?[0-9]+$ ]] ||
       [[ "$str" =~ ^-?[0-9]+\.?[0-9]*[eE][+-]?[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a string is a boolean
is_boolean() {
    local str="$1"
    if [[ "$str" == "true" || "$str" == "false" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to escape strings for NASM
escape_for_nasm() {
    local str="$1"
    
    # If empty string, return 0
    if [ -z "$str" ]; then
        echo "0"
        return
    fi
    
    local result=""
    local i=0
    local len=${#str}
    
    while [ $i -lt $len ]; do
        local char="${str:$i:1}"
        
        if [ "$char" = "\\" ] && [ $((i+1)) -lt $len ]; then
            local next_char="${str:$((i+1)):1}"
            case "$next_char" in
                n)  result="${result}', 10, '" ;;
                t)  result="${result}', 9, '" ;;
                r)  result="${result}', 13, '" ;;
                \\\\) result="${result}', 92, '" ;;
                \") result="${result}', 34, '" ;;
                \') result="${result}', 39, '" ;;
                *)  result="${result}${char}${next_char}" ;;
            esac
            i=$((i+2))
        else
            if [ "$char" = "'" ]; then
                result="${result}''"
            else
                result="${result}${char}"
            fi
            i=$((i+1))
        fi
    done
    
    # Clean up
    if [[ "$result" == "', "* ]] && [[ "$result" == *", '" ]]; then
        result="${result:3}"
        result="${result%\", \"}"
        echo "'${result}', 0"
    elif [[ "$result" == "', "* ]]; then
        result="${result:3}"
        echo "'${result}', 0"
    elif [[ "$result" == *", '" ]]; then
        result="${result%\", \"}"
        echo "'${result}', 0"
    else
        echo "'${result}', 0"
    fi
}

# Function to check if variable already exists
variable_exists() {
    local var_name="$1"
    if [ -f "$OUTPUT_FILE" ]; then
        # Check if variable exists in data section
        if grep -q "^[[:space:]]*${var_name}[[:space:]]\+" "$OUTPUT_FILE" || 
           grep -q "^[[:space:]]*${var_name}_str[[:space:]]\+" "$OUTPUT_FILE" ||
           grep -q "^[[:space:]]*${var_name}_size[[:space:]]\+" "$OUTPUT_FILE"; then
            return 0
        fi
    fi
    return 1
}

# Parse variable declaration
# Only handles var declarations (ignores let and const)
VAR_NAME=""
VAR_VALUE=""

# Extract variable name and value for var declarations
if [[ "$VAR_STATEMENT" =~ ^var[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)([[:space:]]*=[[:space:]]*(.*))? ]]; then
    # var declaration
    VAR_NAME="${BASH_REMATCH[1]}"
    VAR_VALUE="${BASH_REMATCH[3]}"
    
    # Handle declarations without assignment (e.g., "var x;")
    if [ -z "$VAR_VALUE" ]; then
        VAR_VALUE="undefined"
    fi
else
    echo "Error: Not a valid var declaration: $VAR_STATEMENT"
    echo "Only var declarations are supported:"
    echo "  var name = value"
    echo "  var name;"
    exit 1
fi

# Clean up VAR_VALUE - remove trailing spaces
VAR_VALUE=$(echo "$VAR_VALUE" | sed 's/[[:space:]]*$//')

# Check if variable already exists
if variable_exists "$VAR_NAME"; then
    echo "Error: Variable '$VAR_NAME' already exists. Cannot redeclare."
    exit 1
fi

# Determine variable type and generate appropriate assembly
generate_var_declaration() {
    local name="$1"
    local value="$2"
    
    # Trim value
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Check for special values first
    if [[ "$value" == "undefined" ]]; then
        echo "    ; Variable: $name = undefined"
        echo "    $name dq 0"
        return
    elif [[ "$value" == "null" ]]; then
        echo "    ; Variable: $name = null"
        echo "    $name dq 0"
        return
    elif is_boolean "$value"; then
        echo "    ; Variable: $name = $value"
        if [[ "$value" == "true" ]]; then
            echo "    $name dq 1"
        else
            echo "    $name dq 0"
        fi
        return
    fi
    
    # Check for string literals (quoted)
    if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]] || [[ "$value" =~ ^\`(.*)\`$ ]]; then
        local string_content="${BASH_REMATCH[1]}"
        local nasm_string=$(escape_for_nasm "$string_content")
        echo "    ; Variable: $name = string"
        echo "    ${name}_str db $nasm_string"
        echo "    $name dq ${name}_str"
        return
    fi
    
    # Check for numbers
    if is_number "$value"; then
        echo "    ; Variable: $name = $value"
        
        # Check if it's a float (has decimal point or scientific notation)
        if [[ "$value" =~ \. ]] || [[ "$value" =~ [eE] ]]; then
            # For floats, we'll store as integer representation
            local int_value=$(echo "$value" | awk '{printf "%d", $1}')
            echo "    $name dq $int_value"
        else
            # Integer
            echo "    $name dq $value"
        fi
        return
    fi
    
    # Check for array literals (store as simple array marker for now)
    if [[ "$value" =~ ^\[.*\]$ ]]; then
        echo "    ; Variable: $name = array (simplified)"
        # Create a simple array marker
        echo "    $name dq 0xABCD  ; Array marker"
        return
    fi
    
    # Check for object literals (store as simple object marker for now)
    if [[ "$value" =~ ^\{.*\}$ ]]; then
        echo "    ; Variable: $name = object (simplified)"
        # Create a simple object marker
        echo "    $name dq 0x1234  ; Object marker"
        return
    fi
    
    # If we get here, we don't know what type it is
    echo "    ; Variable: $name = unknown type (storing as 0)"
    echo "    $name dq 0"
}

# Main execution
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: $OUTPUT_FILE not found"
    exit 1
fi

# Generate the variable declaration
VAR_DECLARATION=$(generate_var_declaration "$VAR_NAME" "$VAR_VALUE")

# Create temporary file
TEMP_FILE=$(mktemp)

# First, remove any existing declaration of this variable
if variable_exists "$VAR_NAME"; then
    echo "Removing existing declaration of $VAR_NAME..."
    # Create a cleaned version without the old declaration
    grep -v "^[[:space:]]*${VAR_NAME}[[:space:]]" "$OUTPUT_FILE" | \
    grep -v "^[[:space:]]*${VAR_NAME}_str[[:space:]]" | \
    grep -v "^[[:space:]]*${VAR_NAME}_size[[:space:]]" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$OUTPUT_FILE"
    TEMP_FILE=$(mktemp)
fi

# Read the original file and insert variable in data section
IN_DATA_SECTION=0
VAR_INSERTED=0

while IFS= read -r line; do
    # Check if we're entering the data section
    if [[ "$line" == "section .data" ]]; then
        IN_DATA_SECTION=1
        echo "$line" >> "$TEMP_FILE"
        continue
    fi
    
    # Check if we're leaving the data section
    if [[ "$IN_DATA_SECTION" -eq 1 ]] && [[ "$line" == "section ."* ]]; then
        # We're leaving data section, insert our variable before leaving
        if [ "$VAR_INSERTED" -eq 0 ]; then
            echo "" >> "$TEMP_FILE"
            echo "    ; === Generated by var.sh ===" >> "$TEMP_FILE"
            echo "$VAR_DECLARATION" >> "$TEMP_FILE"
            VAR_INSERTED=1
        fi
        IN_DATA_SECTION=0
    fi
    
    # Write the current line
    echo "$line" >> "$TEMP_FILE"
    
done < "$OUTPUT_FILE"

# If we never found data section or variable wasn't inserted, append at end
if [ "$VAR_INSERTED" -eq 0 ]; then
    # Check if there's a data section at all
    if grep -q "section .data" "$TEMP_FILE"; then
        # Insert at end of data section
        sed -i '/section .data/,/^section \|^$/ {
            /^section \|^$/ {
                i\
    ; === Generated by var.sh ===
                i\
'"$VAR_DECLARATION"'
            }
        }' "$TEMP_FILE"
    else
        # No data section, add one
        echo "" >> "$TEMP_FILE"
        echo "section .data" >> "$TEMP_FILE"
        echo "    ; === Generated by var.sh ===" >> "$TEMP_FILE"
        echo "$VAR_DECLARATION" >> "$TEMP_FILE"
    fi
fi

# Replace the original file
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "Successfully appended variable declaration to $OUTPUT_FILE"
echo "Variable: $VAR_NAME = $VAR_VALUE"