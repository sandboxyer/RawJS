#!/bin/bash

# var.sh - Converts JavaScript var declarations to NASM assembly data structures
# Handles primitive types and nested arrays/objects (no functions)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_FILE="../../build_output.asm"

if [ ! -f "var_input" ]; then
    echo "Error: var_input file not found in $(pwd)"
    exit 1
fi

# Read and clean the input
INPUT_CONTENT=$(cat var_input | sed 's/<js-start>//g; s/<js-end>//g' | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Extract variable name and value
if [[ "$INPUT_CONTENT" =~ ^var[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
    VAR_NAME="${BASH_REMATCH[1]}"
    VAR_VALUE="${BASH_REMATCH[2]}"
    # Remove trailing semicolon if present
    VAR_VALUE="${VAR_VALUE%;}"
else
    echo "Error: Invalid variable declaration format"
    exit 1
fi

# Function to generate unique labels
generate_label() {
    local prefix="$1"
    echo "${prefix}_$(date +%s%N | md5sum | cut -c1-8)"
}

# Function to check if string is a number
is_number() {
    local str="$1"
    if [[ "$str" =~ ^-?[0-9]+$ ]] || [[ "$str" =~ ^-?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$ ]]; then
        return 0
    else
        return 1
    fi
}

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

# Function to parse JSON-like value (simplified for JavaScript)
parse_value() {
    local value="$1"
    local label_prefix="$2"
    local depth="$3"
    
    # Trim whitespace
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Check for null
    if [ "$value" = "null" ]; then
        echo "TYPE_NULL"
        return
    fi
    
    # Check for undefined
    if [ "$value" = "undefined" ]; then
        echo "TYPE_UNDEFINED"
        return
    fi
    
    # Check for boolean
    if [ "$value" = "true" ] || [ "$value" = "false" ]; then
        if [ "$value" = "true" ]; then
            echo "TYPE_BOOL:1"
        else
            echo "TYPE_BOOL:0"
        fi
        return
    fi
    
    # Check for number
    if is_number "$value"; then
        echo "TYPE_NUMBER:$value"
        return
    fi
    
    # Check for string (starts and ends with quotes)
    if [[ "$value" =~ ^\"([^\"]*)\"$ ]] || [[ "$value" =~ ^\'([^\']*)\'$ ]] || [[ "$value" =~ ^\`([^\`]*)\`$ ]]; then
        local str_content="${BASH_REMATCH[1]}"
        local escaped=$(escape_for_nasm "$str_content")
        echo "TYPE_STRING:$escaped"
        return
    fi
    
    # Check for array
    if [[ "$value" =~ ^\[(.*)\]$ ]]; then
        local array_content="${BASH_REMATCH[1]}"
        local array_label=$(generate_label "${label_prefix}_arr")
        
        # Parse array elements
        local elements=()
        local current=""
        local bracket_depth=0
        local brace_depth=0
        local in_string=false
        local string_char=""
        
        for (( i=0; i<${#array_content}; i++ )); do
            local char="${array_content:$i:1}"
            local prev_char=""
            [ $i -gt 0 ] && prev_char="${array_content:$((i-1)):1}"
            
            if [ "$in_string" = false ]; then
                case "$char" in
                    "[") ((bracket_depth++)) ;;
                    "]") ((bracket_depth--)) ;;
                    "{") ((brace_depth++)) ;;
                    "}") ((brace_depth--)) ;;
                    '"' | "'" | "\`")
                        in_string=true
                        string_char="$char"
                        ;;
                esac
                
                if [ "$char" = "," ] && [ $bracket_depth -eq 0 ] && [ $brace_depth -eq 0 ]; then
                    elements+=("$current")
                    current=""
                else
                    current="${current}${char}"
                fi
            else
                current="${current}${char}"
                if [ "$char" = "$string_char" ] && [ "$prev_char" != "\\" ]; then
                    in_string=false
                fi
            fi
        done
        
        # Add the last element if not empty
        if [ -n "$current" ]; then
            elements+=("$current")
        fi
        
        # Generate assembly for array
        local array_asm=""
        local element_labels=()
        
        for idx in "${!elements[@]}"; do
            local element="${elements[$idx]}"
            local element_label="${array_label}_elem${idx}"
            local parsed=$(parse_value "$element" "$element_label" $((depth + 1)))
            element_labels+=("$element_label:$parsed")
        done
        
        # Store array structure
        echo "TYPE_ARRAY:${#elements[@]}:${array_label}"
        for elem_label in "${element_labels[@]}"; do
            echo "ARRAY_ELEMENT:$elem_label"
        done
        return
    fi
    
    # Check for object
    if [[ "$value" =~ ^\{(.*)\}$ ]]; then
        local object_content="${BASH_REMATCH[1]}"
        local object_label=$(generate_label "${label_prefix}_obj")
        
        # Parse object properties
        local properties=()
        local current=""
        local bracket_depth=0
        local brace_depth=0
        local in_string=false
        local string_char=""
        
        for (( i=0; i<${#object_content}; i++ )); do
            local char="${object_content:$i:1}"
            local prev_char=""
            [ $i -gt 0 ] && prev_char="${object_content:$((i-1)):1}"
            
            if [ "$in_string" = false ]; then
                case "$char" in
                    "[") ((bracket_depth++)) ;;
                    "]") ((bracket_depth--)) ;;
                    "{") ((brace_depth++)) ;;
                    "}") ((brace_depth--)) ;;
                    '"' | "'" | "\`")
                        in_string=true
                        string_char="$char"
                        ;;
                esac
                
                if [ "$char" = "," ] && [ $bracket_depth -eq 0 ] && [ $brace_depth -eq 0 ]; then
                    properties+=("$current")
                    current=""
                else
                    current="${current}${char}"
                fi
            else
                current="${current}${char}"
                if [ "$char" = "$string_char" ] && [ "$prev_char" != "\\" ]; then
                    in_string=false
                fi
            fi
        done
        
        # Add the last property if not empty
        if [ -n "$current" ]; then
            properties+=("$current")
        fi
        
        # Generate assembly for object
        local property_labels=()
        
        for prop in "${properties[@]}"; do
            # Split key and value
            if [[ "$prop" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*(.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local val="${BASH_REMATCH[2]}"
                local prop_label="${object_label}_prop_${key}"
                local parsed=$(parse_value "$val" "$prop_label" $((depth + 1)))
                property_labels+=("$key:$prop_label:$parsed")
            elif [[ "$prop" =~ ^[[:space:]]*\"([^\"]*)\"[[:space:]]*:[[:space:]]*(.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local val="${BASH_REMATCH[2]}"
                local prop_label="${object_label}_prop_${key}"
                local parsed=$(parse_value "$val" "$prop_label" $((depth + 1)))
                property_labels+=("$key:$prop_label:$parsed")
            fi
        done
        
        # Store object structure
        echo "TYPE_OBJECT:${#properties[@]}:${object_label}"
        for prop_label in "${property_labels[@]}"; do
            echo "OBJECT_PROPERTY:$prop_label"
        done
        return
    fi
    
    # Assume it's a reference to another variable
    if [[ "$value" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "TYPE_REFERENCE:$value"
        return
    fi
    
    # Default to undefined
    echo "TYPE_UNDEFINED"
}

# Function to generate assembly data structures
generate_assembly_data() {
    local parsed_output="$1"
    local var_name="$2"
    
    # Split by newlines
    IFS=$'\n' read -d '' -ra lines <<< "$parsed_output"
    
    local data_section=""
    local current_array_label=""
    local current_object_label=""
    local array_elements=()
    local object_properties=()
    
    for line in "${lines[@]}"; do
        if [[ "$line" == TYPE_ARRAY:* ]]; then
            # Array definition
            IFS=':' read -ra parts <<< "$line"
            local size="${parts[1]}"
            current_array_label="${parts[2]}"
            
            data_section+="    ; Array: $current_array_label (size: $size)\n"
            data_section+="    ${current_array_label}_size dq $size\n"
            data_section+="    ${current_array_label}_data:\n"
            
        elif [[ "$line" == ARRAY_ELEMENT:* ]]; then
            # Array element
            local element_info="${line#ARRAY_ELEMENT:}"
            IFS=':' read -ra elem_parts <<< "$element_info"
            local elem_label="${elem_parts[0]}"
            local elem_type="${elem_parts[1]}"
            
            array_elements+=("$elem_label:$elem_type")
            
        elif [[ "$line" == TYPE_OBJECT:* ]]; then
            # Object definition
            IFS=':' read -ra parts <<< "$line"
            local size="${parts[1]}"
            current_object_label="${parts[2]}"
            
            data_section+="    ; Object: $current_object_label (properties: $size)\n"
            data_section+="    ${current_object_label}_size dq $size\n"
            data_section+="    ${current_object_label}_data:\n"
            
        elif [[ "$line" == OBJECT_PROPERTY:* ]]; then
            # Object property
            local prop_info="${line#OBJECT_PROPERTY:}"
            object_properties+=("$prop_info")
            
        elif [[ "$line" == TYPE_STRING:* ]]; then
            # String type
            local string_value="${line#TYPE_STRING:}"
            data_section+="    db $string_value\n"
            
        elif [[ "$line" == TYPE_NUMBER:* ]]; then
            # Number type
            local number_value="${line#TYPE_NUMBER:}"
            if [[ "$number_value" =~ \. ]]; then
                # Float (store as string for now)
                data_section+="    dq __float64__($number_value)\n"
            else
                # Integer
                data_section+="    dq $number_value\n"
            fi
            
        elif [[ "$line" == TYPE_BOOL:* ]]; then
            # Boolean type
            local bool_value="${line#TYPE_BOOL:}"
            data_section+="    dq $bool_value\n"
            
        elif [[ "$line" == TYPE_NULL ]] || [[ "$line" == TYPE_UNDEFINED ]]; then
            # Null or undefined
            data_section+="    dq 0\n"
        fi
    done
    
    # Generate array elements
    if [ ${#array_elements[@]} -gt 0 ]; then
        for elem in "${array_elements[@]}"; do
            IFS=':' read -ra parts <<< "$elem"
            local elem_label="${parts[0]}"
            local elem_type="${parts[1]}"
            
            if [[ "$elem_type" == TYPE_STRING:* ]]; then
                local str_val="${elem_type#TYPE_STRING:}"
                data_section+="    ${elem_label} db $str_val\n"
            elif [[ "$elem_type" == TYPE_NUMBER:* ]]; then
                local num_val="${elem_type#TYPE_NUMBER:}"
                data_section+="    ${elem_label} dq $num_val\n"
            elif [[ "$elem_type" == TYPE_BOOL:* ]]; then
                local bool_val="${elem_type#TYPE_BOOL:}"
                data_section+="    ${elem_label} dq $bool_val\n"
            elif [[ "$elem_type" == TYPE_NULL ]] || [[ "$elem_type" == TYPE_UNDEFINED ]]; then
                data_section+="    ${elem_label} dq 0\n"
            fi
        done
    fi
    
    # Generate object properties
    if [ ${#object_properties[@]} -gt 0 ]; then
        for prop in "${object_properties[@]}"; do
            IFS=':' read -ra parts <<< "$prop"
            local key="${parts[0]}"
            local prop_label="${parts[1]}"
            local prop_type="${parts[2]}"
            
            # Store key as string
            local key_escaped=$(escape_for_nasm "$key")
            data_section+="    ${prop_label}_key db $key_escaped\n"
            
            # Store value based on type
            if [[ "$prop_type" == TYPE_STRING:* ]]; then
                local str_val="${prop_type#TYPE_STRING:}"
                data_section+="    ${prop_label}_value db $str_val\n"
                data_section+="    ${prop_label}_type dq 1 ; string type\n"
            elif [[ "$prop_type" == TYPE_NUMBER:* ]]; then
                local num_val="${prop_type#TYPE_NUMBER:}"
                data_section+="    ${prop_label}_value dq $num_val\n"
                data_section+="    ${prop_label}_type dq 2 ; number type\n"
            elif [[ "$prop_type" == TYPE_BOOL:* ]]; then
                local bool_val="${prop_type#TYPE_BOOL:}"
                data_section+="    ${prop_label}_value dq $bool_val\n"
                data_section+="    ${prop_label}_type dq 3 ; bool type\n"
            elif [[ "$prop_type" == TYPE_NULL ]]; then
                data_section+="    ${prop_label}_value dq 0\n"
                data_section+="    ${prop_label}_type dq 4 ; null type\n"
            elif [[ "$prop_type" == TYPE_UNDEFINED ]]; then
                data_section+="    ${prop_label}_value dq 0\n"
                data_section+="    ${prop_label}_type dq 5 ; undefined type\n"
            fi
        done
    fi
    
    # Add the variable reference
    data_section+="\n    ; Variable: $var_name\n"
    data_section+="    $var_name dq 0 ; placeholder for variable reference\n"
    
    echo -e "$data_section"
}

# Main execution
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: $OUTPUT_FILE not found"
    exit 1
fi

# Parse the variable value
PARSED_VALUE=$(parse_value "$VAR_VALUE" "$VAR_NAME" 0)

# Generate assembly data
ASSEMBLY_DATA=$(generate_assembly_data "$PARSED_VALUE" "$VAR_NAME")

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
            echo "    ; === Generated by var.sh ===" >> "$TEMP_FILE"
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
    echo "    ; === Generated by var.sh ===" >> "$TEMP_FILE"
    echo -e "$ASSEMBLY_DATA" >> "$TEMP_FILE"
fi

# Replace the original file
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "Successfully added variable declaration to $OUTPUT_FILE"
echo "Variable: $VAR_NAME"
echo "Value: $VAR_VALUE"