#!/bin/bash

# simple.sh - Handler for JavaScript var declarations
# Determines the type and calls the appropriate script

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

# Function to determine primitive type
determine_type() {
    local value="$1"
    # Trim whitespace
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # 1. Check for null / undefined
    if [ "$value" = "null" ]; then
        echo "null"
        return
    fi
    if [ "$value" = "undefined" ]; then
        echo "undefined"
        return
    fi
    
    # 2. Check for boolean
    if [ "$value" = "true" ] || [ "$value" = "false" ]; then
        echo "boolean"
        return
    fi
    
    # 3. If it contains any quotes, it's definitely a string
    if [[ "$value" =~ [\"\'] ]]; then
        echo "string"
        return
    fi
    
    # 4. Check for arithmetic expressions (including + as operator)
    # Remove all whitespace for pattern matching
    local clean_val=$(echo "$value" | sed 's/[[:space:]]//g')
    
    # Pattern for a valid arithmetic expression:
    # Optional leading minus, then number (integer/decimal/exponent),
    # then zero or more (operator followed by number).
    # Operators allowed: + - * / %
    if [[ "$clean_val" =~ ^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?([-+*/%][0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?)*$ ]]; then
        echo "number"
        return
    fi
    
    # 5. Check for pure numbers (hex, octal, binary, decimal, float) without operators
    # Hex: 0x... or 0X...
    if [[ "$value" =~ ^-?0[xX][0-9a-fA-F]+$ ]]; then
        echo "number"
        return
    fi
    # Octal: 0...
    if [[ "$value" =~ ^-?0[0-7]+$ ]]; then
        echo "number"
        return
    fi
    # Binary: 0b... or 0B...
    if [[ "$value" =~ ^-?0[bB][01]+$ ]]; then
        echo "number"
        return
    fi
    # Decimal integer
    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
        echo "number"
        return
    fi
    # Float / scientific notation (without operators)
    if [[ "$value" =~ ^-?[0-9]+\.[0-9]+$ ]] || 
       [[ "$value" =~ ^-?[0-9]+\.[0-9]*[eE][-+]?[0-9]+$ ]] || 
       [[ "$value" =~ ^-?[0-9]*\.[0-9]+$ ]] ||
       [[ "$value" =~ ^-?[0-9]+[eE][-+]?[0-9]+$ ]]; then
        echo "number"
        return
    fi
    
    # 6. Check for variable reference (single identifier)
    if [[ "$value" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "reference"
        return
    fi
    
    # 7. Default to string (includes concatenation like "hello" + "world" which would have been caught
    #    by quotes earlier, or expressions with mixed types that JavaScript would coerce to string)
    echo "string"
}


# Determine the type of the value
TYPE=$(determine_type "$VAR_VALUE")

echo "Variable: $VAR_NAME = $VAR_VALUE"
echo "Detected type: $TYPE"

# Check if the simple directory exists
if [ ! -d "./simple" ]; then
    echo "Error: ./simple directory not found"
    exit 1
fi

# Call the appropriate script based on type
case "$TYPE" in
    "string")
        if [ -f "./simple/string.sh" ]; then
            bash "./simple/string.sh"
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 0 ]; then
                echo "Successfully processed string variable"
                exit 0
            else
                echo "Error: string.sh failed with exit code $EXIT_CODE"
                exit $EXIT_CODE
            fi
        else
            echo "Error: string.sh not found in ./simple/"
            exit 1
        fi
        ;;
    "number")
        if [ -f "./simple/number.sh" ]; then
            bash "./simple/number.sh"
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 0 ]; then
                echo "Successfully processed number variable"
                exit 0
            else
                echo "Error: number.sh failed with exit code $EXIT_CODE"
                exit $EXIT_CODE
            fi
        else
            echo "Error: number.sh not found in ./simple/"
            exit 1
        fi
        ;;
    "boolean")
        if [ -f "./simple/boolean.sh" ]; then
            bash "./simple/boolean.sh"
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 0 ]; then
                echo "Successfully processed boolean variable"
                exit 0
            else
                echo "Error: boolean.sh failed with exit code $EXIT_CODE"
                exit $EXIT_CODE
            fi
        else
            echo "Error: boolean.sh not found in ./simple/"
            exit 1
        fi
        ;;
    "null")
        if [ -f "./simple/null.sh" ]; then
            bash "./simple/null.sh"
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 0 ]; then
                echo "Successfully processed null variable"
                exit 0
            else
                echo "Error: null.sh failed with exit code $EXIT_CODE"
                exit $EXIT_CODE
            fi
        else
            echo "Error: null.sh not found in ./simple/"
            exit 1
        fi
        ;;
    "undefined")
        if [ -f "./simple/undefined.sh" ]; then
            bash "./simple/undefined.sh"
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 0 ]; then
                echo "Successfully processed undefined variable"
                exit 0
            else
                echo "Error: undefined.sh failed with exit code $EXIT_CODE"
                exit $EXIT_CODE
            fi
        else
            echo "Error: undefined.sh not found in ./simple/"
            exit 1
        fi
        ;;
    "reference")
        if [ -f "./simple/reference.sh" ]; then
            bash "./simple/reference.sh"
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 0 ]; then
                echo "Successfully processed reference variable"
                exit 0
            else
                echo "Error: reference.sh failed with exit code $EXIT_CODE"
                exit $EXIT_CODE
            fi
        else
            echo "Error: reference.sh not found in ./simple/"
            exit 1
        fi
        ;;
    *)
        echo "Error: Unknown type '$TYPE'"
        exit 1
        ;;
esac