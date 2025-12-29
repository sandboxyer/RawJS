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
    
    # Check for null
    if [ "$value" = "null" ]; then
        echo "null"
        return
    fi
    
    # Check for undefined
    if [ "$value" = "undefined" ]; then
        echo "undefined"
        return
    fi
    
    # Check for boolean
    if [ "$value" = "true" ] || [ "$value" = "false" ]; then
        echo "boolean"
        return
    fi
    
    # Check for string (starts and ends with quotes OR contains concatenation)
    if [[ "$value" =~ ^\"([^\"]*)\"$ ]] || \
       [[ "$value" =~ ^\'([^\']*)\'$ ]] || \
       [[ "$value" =~ .*[\"\'].*[\"\'] ]] || \
       [[ "$value" =~ .*[\+\"\'][[:space:]]*[\"\'] ]] || \
       [[ "$value" =~ [\+\"\'][[:space:]]*[a-zA-Z0-9_]*[[:space:]]*[\"\'] ]]; then
        echo "string"
        return
    fi
    
    # Check for number (integer or float)
    if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$ ]] && [[ ! "$value" =~ ^-?0[0-9]+ ]]; then
        # Check if it has a decimal point or scientific notation
        if [[ "$value" =~ \. ]] || [[ "$value" =~ [eE] ]]; then
            if [[ "$value" =~ ^-?[0-9]*\.[0-9]+$ ]] || [[ "$value" =~ ^-?[0-9]+\.?[0-9]*[eE][-+]?[0-9]+$ ]]; then
                echo "float"
                return
            fi
        fi
        
        echo "number"
        return
    fi
    
    # Check for variable reference
    if [[ "$value" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "reference"
        return
    fi
    
    # Default to string for any complex expression
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
    "number"|"integer")
        if [ -f "./simple/integer.sh" ]; then
            bash "./simple/integer.sh"
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 0 ]; then
                echo "Successfully processed number variable"
                exit 0
            else
                echo "Error: integer.sh failed with exit code $EXIT_CODE"
                exit $EXIT_CODE
            fi
        else
            echo "Error: integer.sh not found in ./simple/"
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
    "float")
        if [ -f "./simple/float.sh" ]; then
            bash "./simple/float.sh"
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 0 ]; then
                echo "Successfully processed float variable"
                exit 0
            else
                echo "Error: float.sh failed with exit code $EXIT_CODE"
                exit $EXIT_CODE
            fi
        else
            echo "Error: float.sh not found in ./simple/"
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