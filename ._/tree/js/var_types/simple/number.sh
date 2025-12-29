#!/bin/bash

# number.sh - Converts JavaScript number declarations to NASM assembly string data structures
# Handles integers, floats, hex, octal, binary, and arithmetic expressions

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

# Function to evaluate arithmetic expression using awk (more robust)
evaluate_expression() {
    local expr="$1"
    
    # Clean the expression - remove all spaces
    expr=$(echo "$expr" | tr -d '[:space:]')
    
    # Check if expression is empty
    if [ -z "$expr" ]; then
        echo "invalid"
        return 1
    fi
    
    # First, handle all non-decimal number formats by converting them to decimal
    # This handles hex, octal, and binary in the expression
    
    # Replace hex numbers (0xNNN or 0XNNN)
    while [[ "$expr" =~ (^|[^0-9a-zA-Z_])-?0[xX][0-9a-fA-F]+($|[^0-9a-fA-F]) ]]; do
        hex_match="${BASH_REMATCH[0]}"
        # Extract just the hex number
        if [[ "$hex_match" =~ (-?)0[xX]([0-9a-fA-F]+) ]]; then
            prefix="${BASH_REMATCH[1]}"
            hex_num="${BASH_REMATCH[2]}"
            # Convert hex to decimal
            dec_num=$(echo "ibase=16; $(echo $hex_num | tr '[:lower:]' '[:upper:]')" | bc 2>/dev/null)
            if [ $? -ne 0 ]; then
                echo "invalid"
                return 1
            fi
            # Replace in expression
            expr="${expr//$hex_match/${prefix}${dec_num}}"
        fi
    done
    
    # Replace octal numbers (0NNN but not followed by x)
    while [[ "$expr" =~ (^|[^0-9a-zA-Z_])-?0[0-7]+($|[^0-9]) ]]; do
        oct_match="${BASH_REMATCH[0]}"
        # Extract just the octal number
        if [[ "$oct_match" =~ (-?)0([0-7]+) ]]; then
            prefix="${BASH_REMATCH[1]}"
            oct_num="${BASH_REMATCH[2]}"
            # Convert octal to decimal
            dec_num=$(echo "ibase=8; $oct_num" | bc 2>/dev/null)
            if [ $? -ne 0 ]; then
                echo "invalid"
                return 1
            fi
            # Replace in expression
            expr="${expr//$oct_match/${prefix}${dec_num}}"
        fi
    done
    
    # Replace binary numbers (0bNNN or 0BNNN)
    while [[ "$expr" =~ (^|[^0-9a-zA-Z_])-?0[bB][01]+($|[^0-1]) ]]; do
        bin_match="${BASH_REMATCH[0]}"
        # Extract just the binary number
        if [[ "$bin_match" =~ (-?)0[bB]([01]+) ]]; then
            prefix="${BASH_REMATCH[1]}"
            bin_num="${BASH_REMATCH[2]}"
            # Convert binary to decimal
            dec_num=$(echo "ibase=2; $bin_num" | bc 2>/dev/null)
            if [ $? -ne 0 ]; then
                echo "invalid"
                return 1
            fi
            # Replace in expression
            expr="${expr//$bin_match/${prefix}${dec_num}}"
        fi
    done
    
    # Now evaluate the expression (all numbers should be decimal now)
    # Use awk for floating point arithmetic
    local result=$(awk "BEGIN {printf \"%.10f\", $expr}" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$result" ]; then
        # Clean up the result - remove trailing zeros and unnecessary decimal point
        result=$(echo "$result" | sed -E 's/\.?0+$//;s/^\./0\./')
        
        # If it ends with . (e.g., "50."), remove the dot
        [[ "$result" =~ \.0*$ ]] && result="${result%%.*}"
        
        echo "$result"
        return 0
    else
        echo "invalid"
        return 1
    fi
}

# Function to process number value (handles all numeric formats and arithmetic)
process_number_value() {
    local value="$1"
    
    # Clean the value
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Check if it's an arithmetic expression
    if [[ "$value" =~ [-+*/%] ]]; then
        # Try to evaluate the arithmetic expression
        local result=$(evaluate_expression "$value")
        if [ "$result" != "invalid" ]; then
            echo "$result"
            return 0
        fi
    fi
    
    # Check if it's a simple number (no operators)
    # Handle hex, octal, binary conversions
    if [[ "$value" =~ ^-?0[xX][0-9a-fA-F]+$ ]]; then
        # Hexadecimal
        local is_negative=""
        if [[ "$value" =~ ^- ]]; then
            is_negative="-"
            value="${value#-}"
        fi
        value="${value#0x}"
        value="${value#0X}"
        local result=$(echo "ibase=16; $(echo $value | tr '[:lower:]' '[:upper:]')" | bc 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "${is_negative}${result}"
            return 0
        fi
    elif [[ "$value" =~ ^-?0[0-7]+$ ]] && ! [[ "$value" =~ ^-?0[xX] ]]; then
        # Octal
        local is_negative=""
        if [[ "$value" =~ ^- ]]; then
            is_negative="-"
            value="${value#-}"
        fi
        local result=$(echo "ibase=8; $value" | bc 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "${is_negative}${result}"
            return 0
        fi
    elif [[ "$value" =~ ^-?0[bB][01]+$ ]]; then
        # Binary
        local is_negative=""
        if [[ "$value" =~ ^- ]]; then
            is_negative="-"
            value="${value#-}"
        fi
        value="${value#0b}"
        value="${value#0B}"
        local result=$(echo "ibase=2; $value" | bc 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "${is_negative}${result}"
            return 0
        fi
    elif [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$ ]]; then
        # Decimal (integer, float, or scientific notation)
        # Handle scientific notation
        if [[ "$value" =~ [eE] ]]; then
            # Use awk to handle scientific notation
            local result=$(awk "BEGIN {printf \"%.10f\", $value}" 2>/dev/null)
            if [ $? -eq 0 ]; then
                # Clean up
                result=$(echo "$result" | sed -E 's/\.?0+$//;s/^\./0\./')
                [[ "$result" =~ \.0*$ ]] && result="${result%%.*}"
                echo "$result"
                return 0
            fi
        else
            # Simple decimal number
            echo "$value"
            return 0
        fi
    fi
    
    echo "invalid"
    return 1
}

# Process the number value (including arithmetic and all numeric formats)
DECIMAL_VALUE=$(process_number_value "$VAR_VALUE")

if [ "$DECIMAL_VALUE" = "invalid" ]; then
    echo "Error: '$VAR_VALUE' is not a valid number or arithmetic expression"
    echo "Supported numeric formats:"
    echo "  Integers: 123, -456"
    echo "  Floats: 3.14, -0.5, .25"
    echo "  Scientific notation: 1e2, 1.5e-3"
    echo "  Hexadecimal: 0xFF, 0x1A3"
    echo "  Octal: 0123, 0777"
    echo "  Binary: 0b1010, 0b1101"
    echo "  Arithmetic expressions: 25+25, 100-50, 10*5, 20/4, 15%4, 3.14*2"
    echo "  Can combine: 10+20-5, 2*3+4, 0xFF + 0x10"
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

# Check if VAR_VALUE contains arithmetic expression marker
if [[ "$VAR_VALUE" =~ [-+*/%] ]]; then
    # It was an arithmetic expression
    echo "Note: Arithmetic expression '$VAR_VALUE' evaluated to: $DECIMAL_VALUE"
fi

# Escape the decimal string for NASM
ESCAPED_STRING=$(escape_for_nasm "$DECIMAL_VALUE")

# Generate assembly data - store as STRING (null-terminated)
ASSEMBLY_DATA="\n    ; Variable: $VAR_NAME = $VAR_VALUE"
if [[ "$VAR_VALUE" =~ [-+*/%] ]]; then
    ASSEMBLY_DATA+=" (type: numeric expression - evaluated to: $DECIMAL_VALUE)"
else
    ASSEMBLY_DATA+=" (type: number)"
fi
ASSEMBLY_DATA+="\n    ${VAR_NAME} db $ESCAPED_STRING ; number stored as string"

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
if [[ "$VAR_VALUE" =~ [-+*/%] ]]; then
    echo "Type: numeric expression (evaluated to '$DECIMAL_VALUE')"
    echo "Stored as: string '$DECIMAL_VALUE' (null-terminated)"
else
    echo "Type: number"
    echo "Stored as: string '$DECIMAL_VALUE' (null-terminated)"
fi
exit 0