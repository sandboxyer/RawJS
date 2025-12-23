#!/bin/bash

# const.sh - Convert const declarations to let declarations in minified JavaScript

show_help() {
    echo "Usage: $0 [input.js] [OPT-output.js]"
    echo "Convert const declarations to let declarations in minified JavaScript"
    echo ""
    echo "Arguments:"
    echo "  input.js         Input JavaScript file (minified)"
    echo "  OPT-output.js    Optional output file (default: const_output.js)"
    echo ""
    echo "Examples:"
    echo "  $0 script.js                     # Output to const_output.js"
    echo "  $0 script.js converted.js        # Output to converted.js"
    exit 0
}

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

# Check if input file is provided
if [[ $# -eq 0 ]]; then
    echo "Error: No input file specified"
    echo ""
    show_help
fi

# Input file
INPUT_FILE="$1"

# Check if input file exists
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file '$INPUT_FILE' not found"
    exit 1
fi

# Output file (default or specified)
if [[ $# -ge 2 ]]; then
    OUTPUT_FILE="$2"
else
    OUTPUT_FILE="const_output.js"
fi

# Check if output file already exists (ask for confirmation)
if [[ -f "$OUTPUT_FILE" && "$OUTPUT_FILE" != "$INPUT_FILE" ]]; then
    read -p "Output file '$OUTPUT_FILE' already exists. Overwrite? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

# Check if trying to overwrite input file
if [[ "$OUTPUT_FILE" == "$INPUT_FILE" ]]; then
    read -p "Warning: Output file is the same as input file. This will overwrite the original. Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

# Read the entire file content
content=$(<"$INPUT_FILE")
output=""

# Initialize variables
i=0
len=${#content}
in_string=false
string_char=""
escape_next=false
in_template_string=false
in_single_comment=false
in_multi_comment=false

# Process character by character
while (( i < len )); do
    char="${content:i:1}"
    next_char="${content:i+1:1}"
    prev_char=""
    (( i > 0 )) && prev_char="${content:i-1:1}"
    
    # Handle escape sequences
    if $escape_next; then
        output+="$char"
        escape_next=false
        ((i++))
        continue
    fi
    
    # Handle comments
    if ! $in_string && ! $in_template_string; then
        # Check for single line comment
        if [[ "$char" == "/" && "$next_char" == "/" ]]; then
            in_single_comment=true
            output+="$char"
            ((i++))
            continue
        fi
        
        # Check for multi-line comment start
        if [[ "$char" == "/" && "$next_char" == "*" ]]; then
            in_multi_comment=true
            output+="$char"
            ((i++))
            continue
        fi
        
        # Check for multi-line comment end
        if $in_multi_comment && [[ "$char" == "*" && "$next_char" == "/" ]]; then
            in_multi_comment=false
            output+="$char"
            ((i++))
            continue
        fi
        
        # Handle comment content
        if $in_single_comment || $in_multi_comment; then
            if $in_single_comment && [[ "$char" == $'\n' ]]; then
                in_single_comment=false
            fi
            output+="$char"
            ((i++))
            continue
        fi
    fi
    
    # Handle string and template literal boundaries
    if [[ "$char" == "\\" ]]; then
        escape_next=true
        output+="$char"
        ((i++))
        continue
    fi
    
    if [[ "$char" == "'" || "$char" == '"' ]]; then
        if ! $in_template_string && ! $in_string; then
            in_string=true
            string_char="$char"
        elif $in_string && [[ "$char" == "$string_char" ]]; then
            in_string=false
            string_char=""
        fi
        output+="$char"
        ((i++))
        continue
    fi
    
    if [[ "$char" == "\`" ]]; then
        if ! $in_string; then
            if $in_template_string; then
                in_template_string=false
            else
                in_template_string=true
            fi
        fi
        output+="$char"
        ((i++))
        continue
    fi
    
    # If we're inside a string or template literal, just copy character
    if $in_string || $in_template_string; then
        output+="$char"
        ((i++))
        continue
    fi
    
    # Look for 'const' keyword (not inside strings or comments)
    if [[ "$char" == "c" && $((i+4)) -le $len ]]; then
        potential_const="${content:i:5}"
        if [[ "$potential_const" == "const" ]]; then
            # Check if it's a valid identifier boundary before 'const'
            valid_before=true
            if (( i > 0 )); then
                prev_char="${content:i-1:1}"
                # Check if previous character is part of a valid identifier
                if [[ "$prev_char" =~ [a-zA-Z0-9_$] ]]; then
                    valid_before=false
                fi
            fi
            
            # Check if it's followed by whitespace and then an identifier
            valid_after=false
            if (( i+5 < len )); then
                after_const="${content:i+5}"
                # Skip whitespace after const
                skip=0
                while [[ "${after_const:skip:1}" =~ [[:space:]] ]] && (( skip < ${#after_const} )); do
                    ((skip++))
                done
                
                # Check if next character is valid for identifier start
                if (( skip < ${#after_const} )); then
                    next_after="${after_const:skip:1}"
                    if [[ "$next_after" =~ [a-zA-Z_$] ]]; then
                        valid_after=true
                    fi
                fi
            fi
            
            # Also check if it's part of a larger word like 'constant' (should not match)
            if (( i+5 < len )); then
                char_after_const="${content:i+5:1}"
                if [[ "$char_after_const" =~ [a-zA-Z0-9_$] ]]; then
                    valid_before=false
                fi
            fi
            
            # If valid const declaration, replace with 'let'
            if $valid_before && $valid_after; then
                output+="let"
                ((i+=5))
                continue
            fi
        fi
    fi
    
    # Default: copy character
    output+="$char"
    ((i++))
done

# Write output to file
echo -n "$output" > "$OUTPUT_FILE"

echo "Conversion complete!"
echo "Input:  $INPUT_FILE"
echo "Output: $OUTPUT_FILE"
echo ""
echo "Note: This script attempts to safely convert 'const' declarations to 'let'"
echo "      while preserving 'const' within strings, comments, and other contexts."
echo "      Always review the output before using in production."