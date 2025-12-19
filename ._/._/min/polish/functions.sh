#!/bin/bash

# functions.sh - Transform JavaScript function expressions to standard declarations
# Usage: bash functions.sh file.js [output.js]

# Validate input
if [ $# -lt 1 ]; then
    echo "Usage: $0 <input.js> [output.js]"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-polished.js}"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found"
    exit 1
fi

# Read file content preserving all characters
read_content() {
    # Use while read loop to handle any character including newlines
    local content=""
    while IFS= read -r line || [ -n "$line" ]; do
        content+="$line"$'\n'
    done < "$INPUT_FILE"
    echo "${content%$'\n'}"  # Remove trailing newline
}

# State tracking
inside_string=0
string_delimiter=""
inside_comment=0
comment_type=""
escape_next=0
brace_level=0
bracket_level=0
paren_level=0
last_token=""
in_object_assignment=0
in_array_assignment=0
expecting_function=0
after_equals=0
after_colon=0

# Storage for extracted functions
declare -A function_registry
declare -a function_declarations
declare -A replacement_map
current_variable_name=""
array_func_counter=1

# Reset state for new parsing
reset_state() {
    inside_string=0
    string_delimiter=""
    inside_comment=0
    comment_type=""
    escape_next=0
    brace_level=0
    bracket_level=0
    paren_level=0
    last_token=""
    in_object_assignment=0
    in_array_assignment=0
    expecting_function=0
    after_equals=0
    after_colon=0
    current_variable_name=""
}

# Update parsing state
update_state() {
    local char="$1"
    
    # Handle escape sequences in strings
    if [ "$escape_next" -eq 1 ]; then
        escape_next=0
        return
    fi
    
    # Check for escape character
    if [ "$inside_string" -eq 1 ] && [ "$char" = '\' ]; then
        escape_next=1
        return
    fi
    
    # Handle comments
    if [ "$inside_string" -eq 0 ]; then
        if [ "$inside_comment" -eq 0 ]; then
            if [ "$char" = '/' ] && [ "${last_token: -1}" = '/' ]; then
                inside_comment=1
                comment_type="line"
                last_token=""
                return
            elif [ "$char" = '*' ] && [ "${last_token: -1}" = '/' ]; then
                inside_comment=1
                comment_type="block"
                last_token=""
                return
            fi
        else
            if [ "$comment_type" = "line" ] && [ "$char" = $'\n' ]; then
                inside_comment=0
            elif [ "$comment_type" = "block" ] && [ "$char" = '/' ] && [ "${last_token: -1}" = '*' ]; then
                inside_comment=0
                last_token=""
                return
            fi
        fi
    fi
    
    # Handle strings
    if [ "$inside_comment" -eq 0 ]; then
        if [ "$inside_string" -eq 0 ] && [[ "$char" =~ ['"`'] ]]; then
            inside_string=1
            string_delimiter="$char"
        elif [ "$inside_string" -eq 1 ] && [ "$char" = "$string_delimiter" ]; then
            inside_string=0
            string_delimiter=""
        fi
    fi
    
    # Track brackets only when not in string or comment
    if [ "$inside_string" -eq 0 ] && [ "$inside_comment" -eq 0 ]; then
        case "$char" in
            '{')
                brace_level=$((brace_level + 1))
                if [ $after_equals -eq 1 ] || [ $after_colon -eq 1 ]; then
                    in_object_assignment=1
                fi
                ;;
            '}')
                brace_level=$((brace_level - 1))
                if [ $brace_level -eq 0 ]; then
                    in_object_assignment=0
                fi
                ;;
            '[')
                bracket_level=$((bracket_level + 1))
                if [ $after_equals -eq 1 ] || [ $after_colon -eq 1 ]; then
                    in_array_assignment=1
                fi
                ;;
            ']')
                bracket_level=$((bracket_level - 1))
                if [ $bracket_level -eq 0 ]; then
                    in_array_assignment=0
                fi
                ;;
            '(')
                paren_level=$((paren_level + 1))
                ;;
            ')')
                paren_level=$((paren_level - 1))
                ;;
            '=')
                after_equals=1
                after_colon=0
                ;;
            ':')
                if [ $in_object_assignment -eq 1 ]; then
                    after_colon=1
                fi
                after_equals=0
                ;;
            ',')
                after_equals=0
                after_colon=0
                ;;
            ';')
                after_equals=0
                after_colon=0
                in_object_assignment=0
                in_array_assignment=0
                current_variable_name=""
                ;;
        esac
    fi
    
    last_token+="$char"
    if [ ${#last_token} -gt 20 ]; then
        last_token="${last_token: -20}"
    fi
}

# Extract function name from variable declaration
extract_variable_name() {
    local buffer="$1"
    local pos="$2"
    
    # Look backward for variable declaration pattern
    local temp=""
    local i=$pos
    local paren_count=0
    
    while [ $i -gt 0 ]; do
        i=$((i - 1))
        local char="${buffer:$i:1}"
        
        if [ "$char" = ')' ]; then
            paren_count=$((paren_count + 1))
        elif [ "$char" = '(' ]; then
            if [ $paren_count -eq 0 ]; then
                break
            fi
            paren_count=$((paren_count - 1))
        elif [ $paren_count -eq 0 ]; then
            if [[ "$char" =~ [[:space:]] ]]; then
                continue
            elif [ "$char" = '=' ]; then
                # Found assignment, now extract variable name
                i=$((i - 1))
                while [ $i -gt 0 ]; do
                    char="${buffer:$i:1}"
                    if [[ "$char" =~ [[:space:]] ]]; then
                        i=$((i - 1))
                        continue
                    elif [[ "$char" =~ [[:alnum:]_] ]]; then
                        temp="$char$temp"
                        i=$((i - 1))
                    else
                        break
                    fi
                done
                echo "$temp"
                return
            fi
        fi
    done
    
    echo ""
}

# Extract property name from object context
extract_property_name() {
    local buffer="$1"
    local pos="$2"
    
    local temp=""
    local i=$pos
    
    # Look backward for property name before colon
    while [ $i -gt 0 ]; do
        i=$((i - 1))
        local char="${buffer:$i:1}"
        
        if [ "$char" = ':' ]; then
            # Found colon, extract property name
            i=$((i - 1))
            while [ $i -gt 0 ]; do
                char="${buffer:$i:1}"
                if [[ "$char" =~ [[:space:]] ]] || [ "$char" = ',' ] || [ "$char" = '{' ]; then
                    break
                elif [[ "$char" =~ [[:alnum:]_] ]]; then
                    temp="$char$temp"
                    i=$((i - 1))
                else
                    break
                fi
            done
            echo "$temp"
            return
        fi
    done
    
    echo ""
}

# Extract parameters from arrow function
extract_parameters() {
    local buffer="$1"
    local start_pos="$2"
    
    local params=""
    local i=$((start_pos - 1))
    local paren_count=1  # We're starting after the '>' of '=>'
    
    # Look backward for parameters
    while [ $i -gt 0 ]; do
        local char="${buffer:$i:1}"
        
        if [ "$char" = ')' ]; then
            paren_count=$((paren_count + 1))
        elif [ "$char" = '(' ]; then
            paren_count=$((paren_count - 1))
            if [ $paren_count -eq 0 ]; then
                # Extract everything between the parentheses
                local j=$((i + 1))
                while [ "${buffer:$j:1}" != ')' ]; do
                    params="${buffer:$j:1}$params"
                    j=$((j + 1))
                done
                echo "$params"
                return
            fi
        fi
        
        i=$((i - 1))
    done
    
    # If we didn't find parentheses, it's a single parameter without parens
    # Extract the parameter
    params=""
    i=$start_pos
    while [ $i -gt 0 ]; do
        i=$((i - 1))
        local char="${buffer:$i:1}"
        
        if [[ "$char" =~ [[:space:]] ]] || [ "$char" = '=' ] || [ "$char" = ',' ] || [ "$char" = '{' ] || [ "$char" = '[' ] || [ "$char" = '(' ] || [ "$char" = ':' ]; then
            break
        elif [[ "$char" =~ [[:alnum:]_] ]]; then
            params="$char$params"
        fi
    done
    
    echo "$params"
}

# Extract function body
extract_body() {
    local buffer="$1"
    local arrow_pos="$2"
    
    local i=$((arrow_pos + 2))  # Skip '=>'
    local body=""
    local brace_count=0
    local in_string_body=0
    local string_delimiter_body=""
    local escape_next_body=0
    
    # Skip whitespace after '=>'
    while [ $i -lt ${#buffer} ] && [[ "${buffer:$i:1}" =~ [[:space:]] ]]; do
        i=$((i + 1))
    done
    
    local start_pos=$i
    
    if [ $i -lt ${#buffer} ] && [ "${buffer:$i:1}" = '{' ]; then
        # Multi-line body with braces
        brace_count=1
        i=$((i + 1))
        
        while [ $i -lt ${#buffer} ] && [ $brace_count -gt 0 ]; do
            local char="${buffer:$i:1}"
            
            # Handle strings within body
            if [ $escape_next_body -eq 1 ]; then
                escape_next_body=0
            elif [ "$char" = '\' ]; then
                escape_next_body=1
            elif [ $in_string_body -eq 0 ] && [[ "$char" =~ ['"`'] ]]; then
                in_string_body=1
                string_delimiter_body="$char"
            elif [ $in_string_body -eq 1 ] && [ "$char" = "$string_delimiter_body" ]; then
                in_string_body=0
                string_delimiter_body=""
            fi
            
            if [ $in_string_body -eq 0 ]; then
                if [ "$char" = '{' ]; then
                    brace_count=$((brace_count + 1))
                elif [ "$char" = '}' ]; then
                    brace_count=$((brace_count - 1))
                fi
            fi
            
            i=$((i + 1))
        done
        
        body="${buffer:$start_pos:$((i - start_pos))}"
    else
        # Single expression body
        local paren_count_body=0
        local bracket_count_body=0
        
        while [ $i -lt ${#buffer} ]; do
            local char="${buffer:$i:1}"
            
            # Handle strings
            if [ $escape_next_body -eq 1 ]; then
                escape_next_body=0
            elif [ "$char" = '\' ]; then
                escape_next_body=1
            elif [ $in_string_body -eq 0 ] && [[ "$char" =~ ['"`'] ]]; then
                in_string_body=1
                string_delimiter_body="$char"
            elif [ $in_string_body -eq 1 ] && [ "$char" = "$string_delimiter_body" ]; then
                in_string_body=0
                string_delimiter_body=""
            fi
            
            if [ $in_string_body -eq 0 ]; then
                if [ "$char" = '(' ]; then
                    paren_count_body=$((paren_count_body + 1))
                elif [ "$char" = ')' ]; then
                    if [ $paren_count_body -eq 0 ]; then
                        break
                    fi
                    paren_count_body=$((paren_count_body - 1))
                elif [ "$char" = '[' ]; then
                    bracket_count_body=$((bracket_count_body + 1))
                elif [ "$char" = ']' ]; then
                    bracket_count_body=$((bracket_count_body - 1))
                elif [ "$char" = ',' ] || [ "$char" = ';' ] || [ "$char" = '}' ] || [ "$char" = ']' ]; then
                    if [ $paren_count_body -eq 0 ] && [ $bracket_count_body -eq 0 ]; then
                        break
                    fi
                fi
            fi
            
            i=$((i + 1))
        done
        
        body="{return ${buffer:$start_pos:$((i - start_pos))}}"
    fi
    
    echo "$body"
}

# Generate unique function name
generate_unique_name() {
    local base_name="$1"
    local type="$2"
    
    if [ -z "$base_name" ] || [[ ! "$base_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        if [ "$type" = "array" ]; then
            base_name="arrayFunc$array_func_counter"
            array_func_counter=$((array_func_counter + 1))
        else
            base_name="func_$(date +%s%N)_${RANDOM}"
        fi
    fi
    
    # Ensure uniqueness
    local original_name="$base_name"
    local counter=1
    
    while [ -n "${function_registry[$base_name]}" ]; do
        base_name="${original_name}_${counter}"
        counter=$((counter + 1))
    done
    
    function_registry["$base_name"]=1
    echo "$base_name"
}

# Process JavaScript content
process_javascript() {
    local js_content="$1"
    local processed=""
    local buffer=""
    local result=""
    
    # First pass: Identify all arrow functions and extract them
    reset_state
    local i=0
    local content_length=${#js_content}
    
    while [ $i -lt $content_length ]; do
        local char="${js_content:$i:1}"
        local prev_state_string="$inside_string"
        local prev_state_comment="$inside_comment"
        
        update_state "$char"
        
        # Look for arrow functions when not in string or comment
        if [ "$inside_string" -eq 0 ] && [ "$inside_comment" -eq 0 ] && \
           [ $i -gt 0 ] && [ "${js_content:$i:1}" = '>' ] && [ "${js_content:$((i-1)):1}" = '=' ]; then
           
            local arrow_pos=$i
            local func_name=""
            local func_type=""
            
            # Determine function context and extract name
            if [ $after_equals -eq 1 ] && [ -n "$current_variable_name" ]; then
                # Variable assignment
                func_name="$current_variable_name"
                func_type="variable"
            elif [ $in_object_assignment -eq 1 ] && [ $after_colon -eq 1 ]; then
                # Object property
                func_name=$(extract_property_name "$js_content" $arrow_pos)
                func_type="property"
            elif [ $in_array_assignment -eq 1 ]; then
                # Array element
                func_type="array"
            else
                # Check if it's a variable assignment we missed
                func_name=$(extract_variable_name "$js_content" $arrow_pos)
                if [ -n "$func_name" ]; then
                    func_type="variable"
                else
                    # Could be other contexts like default parameters, skip for now
                    i=$((i + 1))
                    continue
                fi
            fi
            
            if [ -n "$func_type" ]; then
                # Extract function details
                local params=$(extract_parameters "$js_content" $arrow_pos)
                local body=$(extract_body "$js_content" $arrow_pos)
                
                # Generate function name if needed
                if [ -z "$func_name" ]; then
                    func_name=$(generate_unique_name "" "$func_type")
                else
                    func_name=$(generate_unique_name "$func_name" "$func_type")
                fi
                
                # Create function declaration
                local declaration="function $func_name($params)$body"
                function_declarations+=("$declaration")
                
                # Store replacement info
                # Find the start of this function expression
                local start_pos=$arrow_pos
                local paren_count=0
                local bracket_count=0
                local in_string_replace=0
                local string_delimiter_replace=""
                
                # Look backward to find start of expression
                while [ $start_pos -gt 0 ]; do
                    start_pos=$((start_pos - 1))
                    local check_char="${js_content:$start_pos:1}"
                    
                    # Handle strings
                    if [ "$check_char" = '\' ]; then
                        continue
                    elif [ $in_string_replace -eq 0 ] && [[ "$check_char" =~ ['"`'] ]]; then
                        in_string_replace=1
                        string_delimiter_replace="$check_char"
                    elif [ $in_string_replace -eq 1 ] && [ "$check_char" = "$string_delimiter_replace" ]; then
                        in_string_replace=0
                        string_delimiter_replace=""
                    fi
                    
                    if [ $in_string_replace -eq 0 ]; then
                        if [ "$check_char" = ')' ]; then
                            paren_count=$((paren_count + 1))
                        elif [ "$check_char" = '(' ]; then
                            if [ $paren_count -eq 0 ]; then
                                # Check what's before this
                                local before_pos=$((start_pos - 1))
                                local found_start=0
                                
                                while [ $before_pos -gt 0 ]; do
                                    local before_char="${js_content:$before_pos:1}"
                                    if [[ "$before_char" =~ [[:space:]] ]]; then
                                        before_pos=$((before_pos - 1))
                                        continue
                                    elif [ "$before_char" = '=' ] || [ "$before_char" = ':' ] || \
                                         [ "$before_char" = ',' ] || [ "$before_char" = '[' ] || \
                                         [ "$before_char" = '{' ] || [ "$before_char" = '(' ]; then
                                        start_pos=$((before_pos + 1))
                                        found_start=1
                                        break
                                    else
                                        break
                                    fi
                                done
                                
                                if [ $found_start -eq 0 ]; then
                                    start_pos=$((start_pos - 1))
                                fi
                                break
                            else
                                paren_count=$((paren_count - 1))
                            fi
                        elif [ "$check_char" = ']' ]; then
                            bracket_count=$((bracket_count + 1))
                        elif [ "$check_char" = '[' ]; then
                            bracket_count=$((bracket_count - 1))
                        elif [ $paren_count -eq 0 ] && [ $bracket_count -eq 0 ]; then
                            if [ "$check_char" = '=' ] || [ "$check_char" = ':' ] || \
                               [ "$check_char" = ',' ] || [ "$check_char" = '[' ] || \
                               [ "$check_char" = '{' ]; then
                                start_pos=$((start_pos + 1))
                                break
                            elif [[ "$check_char" =~ [[:alnum:]_] ]]; then
                                # Part of a variable name or property
                                continue
                            fi
                        fi
                    fi
                done
                
                # Find the end of this function expression
                local end_pos=$arrow_pos
                local brace_count=0
                local in_string_end=0
                local string_delimiter_end=""
                
                # Skip '=>'
                end_pos=$((end_pos + 2))
                
                # Skip whitespace
                while [ $end_pos -lt $content_length ] && \
                      [[ "${js_content:$end_pos:1}" =~ [[:space:]] ]]; do
                    end_pos=$((end_pos + 1))
                done
                
                if [ $end_pos -lt $content_length ] && [ "${js_content:$end_pos:1}" = '{' ]; then
                    # Multi-line body
                    brace_count=1
                    end_pos=$((end_pos + 1))
                    
                    while [ $end_pos -lt $content_length ] && [ $brace_count -gt 0 ]; do
                        local end_char="${js_content:$end_pos:1}"
                        
                        if [ "$end_char" = '\' ]; then
                            end_pos=$((end_pos + 1))
                        elif [ $in_string_end -eq 0 ] && [[ "$end_char" =~ ['"`'] ]]; then
                            in_string_end=1
                            string_delimiter_end="$end_char"
                        elif [ $in_string_end -eq 1 ] && [ "$end_char" = "$string_delimiter_end" ]; then
                            in_string_end=0
                            string_delimiter_end=""
                        fi
                        
                        if [ $in_string_end -eq 0 ]; then
                            if [ "$end_char" = '{' ]; then
                                brace_count=$((brace_count + 1))
                            elif [ "$end_char" = '}' ]; then
                                brace_count=$((brace_count - 1))
                            fi
                        fi
                        
                        end_pos=$((end_pos + 1))
                    done
                else
                    # Single expression body
                    local paren_count_end=0
                    local bracket_count_end=0
                    
                    while [ $end_pos -lt $content_length ]; do
                        local end_char="${js_content:$end_pos:1}"
                        
                        if [ "$end_char" = '\' ]; then
                            end_pos=$((end_pos + 1))
                        elif [ $in_string_end -eq 0 ] && [[ "$end_char" =~ ['"`'] ]]; then
                            in_string_end=1
                            string_delimiter_end="$end_char"
                        elif [ $in_string_end -eq 1 ] && [ "$end_char" = "$string_delimiter_end" ]; then
                            in_string_end=0
                            string_delimiter_end=""
                        fi
                        
                        if [ $in_string_end -eq 0 ]; then
                            if [ "$end_char" = '(' ]; then
                                paren_count_end=$((paren_count_end + 1))
                            elif [ "$end_char" = ')' ]; then
                                if [ $paren_count_end -eq 0 ]; then
                                    break
                                fi
                                paren_count_end=$((paren_count_end - 1))
                            elif [ "$end_char" = '[' ]; then
                                bracket_count_end=$((bracket_count_end + 1))
                            elif [ "$end_char" = ']' ]; then
                                bracket_count_end=$((bracket_count_end - 1))
                            elif [ "$end_char" = ',' ] || [ "$end_char" = ';' ] || \
                                 [ "$end_char" = '}' ] || [ "$end_char" = ']' ]; then
                                if [ $paren_count_end -eq 0 ] && [ $bracket_count_end -eq 0 ]; then
                                    break
                                fi
                            fi
                        fi
                        
                        end_pos=$((end_pos + 1))
                    done
                fi
                
                # Store the replacement
                local original_expr="${js_content:$start_pos:$((end_pos - start_pos))}"
                replacement_map["$start_pos:$end_pos"]="$func_name"
                replacement_map["original:$start_pos:$end_pos"]="$original_expr"
            fi
        fi
        
        # Track variable names for assignments
        if [ "$inside_string" -eq 0 ] && [ "$inside_comment" -eq 0 ]; then
            if [ "$char" = '=' ] && \
               [[ "${js_content:$((i-3)):3}" =~ ^(let|var)$ ]] || \
               [[ "${js_content:$((i-5)):5}" =~ ^(const)$ ]]; then
                # Extract variable name before '='
                local name_pos=$((i - 1))
                while [ $name_pos -gt 0 ] && [[ "${js_content:$name_pos:1}" =~ [[:space:]] ]]; do
                    name_pos=$((name_pos - 1))
                done
                
                current_variable_name=""
                while [ $name_pos -gt 0 ] && [[ "${js_content:$name_pos:1}" =~ [[:alnum:]_] ]]; do
                    current_variable_name="${js_content:$name_pos:1}$current_variable_name"
                    name_pos=$((name_pos - 1))
                done
            fi
        fi
        
        i=$((i + 1))
    done
    
    # Second pass: Build the result with replacements
    if [ ${#function_declarations[@]} -eq 0 ]; then
        echo "$js_content"
        return
    fi
    
    # Start with function declarations
    result=""
    for declaration in "${function_declarations[@]}"; do
        result+="$declaration;"
    done
    
    # Add the modified original code
    local last_pos=0
    local sorted_keys=$(echo "${!replacement_map[@]}" | tr ' ' '\n' | grep -E '^[0-9]+:[0-9]+$' | sort -t: -k1n)
    
    for key in $sorted_keys; do
        IFS=':' read -ra pos <<< "$key"
        local start_pos="${pos[0]}"
        local end_pos="${pos[1]}"
        local func_name="${replacement_map[$key]}"
        
        # Add code before this replacement
        result+="${js_content:$last_pos:$((start_pos - last_pos))}"
        
        # Add the function reference
        result+="$func_name"
        
        last_pos=$end_pos
    done
    
    # Add remaining code after last replacement
    if [ $last_pos -lt ${#js_content} ]; then
        result+="${js_content:$last_pos}"
    fi
    
    echo "$result"
}

# Main function
main() {
    local js_content=$(read_content)
    local transformed=$(process_javascript "$js_content")
    echo "$transformed" > "$OUTPUT_FILE"
    echo "Transformation complete. Output saved to $OUTPUT_FILE"
}

# Execute main function
main "$@"