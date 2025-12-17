#!/bin/bash

# JavaScript Declaration Syntax Error Auditor
# Usage: ./declaration.sh <filename.js> [--test]

DECLARATION_SCRIPT_VERSION="6.1.0"
TEST_DIR="declaration_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# JavaScript reserved words
RESERVED_WORDS="break case catch class const continue debugger default delete do else enum export extends false finally for function if import in instanceof new null return super switch this throw true try typeof var void while with yield let static implements interface package private protected public as async await get set from of"

# Function to display usage
show_usage() {
    echo -e "${BLUE}JavaScript Declaration Syntax Error Auditor v${DECLARATION_SCRIPT_VERSION}${NC}"
    echo "Pure bash implementation - No Node.js required"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Audit a JavaScript file for declaration syntax errors"
    echo "  --test           Run test suite against known declaration error patterns"
    echo "  --help, -h       Show this help message"
}

# Function to check if character is whitespace
is_whitespace() {
    local char="$1"
    case "$char" in
        ' '|$'\t'|$'\n'|$'\r') return 0 ;;
        *) return 1 ;;
    esac
}

# Function to check if character can start an identifier
is_valid_identifier_start() {
    local char="$1"
    case "$char" in
        [a-zA-Z_$]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to check if character is valid in identifier
is_valid_identifier_char() {
    local char="$1"
    case "$char" in
        [a-zA-Z0-9_$]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to check if token is a reserved word
is_reserved_word() {
    local token="$1"
    for word in $RESERVED_WORDS; do
        if [ "$token" = "$word" ]; then
            return 0
        fi
    done
    return 1
}

# Function to check if token is a number
is_number() {
    local token="$1"
    [[ "$token" =~ ^[0-9]+$ ]] || [[ "$token" =~ ^[0-9]+\.[0-9]*$ ]] || [[ "$token" =~ ^\.[0-9]+$ ]]
}

# Function to get next token from line
get_token() {
    local line="$1"
    local pos="$2"
    local length=${#line}
    local token=""
    
    # Skip whitespace
    while [ $pos -lt $length ] && is_whitespace "${line:$pos:1}"; do
        ((pos++))
    done
    
    local start=$pos
    
    if [ $pos -lt $length ]; then
        local char="${line:$pos:1}"
        
        # Handle different token types
        case "$char" in
            # Single character tokens
            ';'|','|'.'|'('|')'|'{'|'}'|'['|']'|':'|'?'|'~'|'@'|'#'|'`'|'=')
                token="$char"
                ((pos++))
                ;;
            # Operators
            '+'|'-'|'*'|'/'|'%'|'&'|'|'|'^'|'!'|'<'|'>')
                token="$char"
                ((pos++))
                # Check for second character
                if [ $pos -lt $length ]; then
                    local next_char="${line:$pos:1}"
                    case "${char}${next_char}" in
                        '++'|'--'|'**'|'<<'|'>>'|'&&'|'||'|'=='|'!='|'<='|'>='|'+='|'-='|'*='|'/='|'%='|'&='|'|='|'^='|'??'|'?.')
                            token="${char}${next_char}"
                            ((pos++))
                            ;;
                        '=>')
                            token="${char}${next_char}"
                            ((pos++))
                            ;;
                    esac
                fi
                ;;
            # Strings
            "'"|'"'|'`')
                local quote_char="$char"
                token="$char"
                ((pos++))
                local escaped=false
                while [ $pos -lt $length ]; do
                    local current_char="${line:$pos:1}"
                    if $escaped; then
                        escaped=false
                    elif [ "$current_char" = "\\" ]; then
                        escaped=true
                    elif [ "$current_char" = "$quote_char" ]; then
                        ((pos++))
                        break
                    fi
                    ((pos++))
                done
                ;;
            # Identifiers and numbers
            *)
                if is_valid_identifier_start "$char"; then
                    while [ $pos -lt $length ] && is_valid_identifier_char "${line:$pos:1}"; do
                        ((pos++))
                    done
                elif [[ "$char" =~ [0-9] ]]; then
                    ((pos++))
                    while [ $pos -lt $length ] && ([[ "${line:$pos:1}" =~ [0-9] ]] || [ "${line:$pos:1}" = "." ] || [ "${line:$pos:1}" = "e" ] || [ "${line:$pos:1}" = "E" ]); do
                        ((pos++))
                    done
                fi
                ;;
        esac
        
        token="${line:$start:$((pos-start))}"
    fi
    
    echo "$token"
}

# Function to check for "use strict" directive
check_strict_mode() {
    local line="$1"
    # Remove leading whitespace and check
    local trimmed_line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    if [ "$trimmed_line" = '"use strict"' ] || [ "$trimmed_line" = "'use strict'" ]; then
        return 0
    fi
    return 1
}

# Function to check for octal literal in strict mode
check_octal_literal() {
    local line="$1"
    local col="$2"
    local length=${#line}
    
    # Check for octal pattern starting at position
    if [ $col -lt $length ] && [ "${line:$col:1}" = "0" ]; then
        local next_pos=$((col + 1))
        while [ $next_pos -lt $length ] && [[ "${line:$next_pos:1}" =~ [0-7] ]]; do
            ((next_pos++))
        done
        
        local num_str="${line:$col:$((next_pos-col))}"
        # Check if it's octal (starts with 0 and has more digits)
        if [ ${#num_str} -gt 1 ] && [[ "$num_str" =~ ^0[0-7]+$ ]]; then
            return 0
        fi
    fi
    return 1
}

# Function to extract simple variable name from declaration
extract_var_name() {
    local line="$1"
    local start_pos="$2"
    local length=${#line}
    local name=""
    
    local pos=$start_pos
    while [ $pos -lt $length ] && is_whitespace "${line:$pos:1}"; do
        ((pos++))
    done
    
    if [ $pos -lt $length ]; then
        local char="${line:$pos:1}"
        if is_valid_identifier_start "$char"; then
            local name_start=$pos
            while [ $pos -lt $length ] && is_valid_identifier_char "${line:$pos:1}"; do
                ((pos++))
            done
            name="${line:$name_start:$((pos-name_start))}"
        fi
    fi
    
    echo "$name"
}

# Function to check for duplicate declarations in same scope
check_duplicate_declaration() {
    local scope="$1"
    local name="$2"
    local type="$3"
    local line_num="$4"
    local col="$5"
    local -n declared_ref="$6"
    
    local scope_key="${scope}_${name}"
    
    if [ -n "${declared_ref[$scope_key]}" ]; then
        if [ "$type" = "let" ] || [ "$type" = "const" ] || [ "$type" = "function" ] || [ "$type" = "class" ]; then
            echo -e "${RED}Error at line $line_num, column $((col+1)): Identifier '$name' has already been declared${NC}"
            return 1
        elif [ "$type" = "var" ] && [ "$scope" = "global" ]; then
            local existing_type="${declared_ref[$scope_key]%%:*}"
            if [ "$existing_type" = "let" ] || [ "$existing_type" = "const" ] || [ "$existing_type" = "function" ] || [ "$existing_type" = "class" ]; then
                echo -e "${RED}Error at line $line_num, column $((col+1)): Identifier '$name' has already been declared${NC}"
                return 1
            fi
        fi
    fi
    
    declared_ref["$scope_key"]="${type}:${line_num}"
    return 0
}

# Enhanced function to detect destructuring errors
check_destructuring_pattern() {
    local line="$1"
    local pos="$2"
    local line_num="$3"
    local length="${#line}"
    
    # Check for specific destructuring errors
    local remaining="${line:$pos}"
    
    # Object destructuring errors
    if [[ "$remaining" =~ ^\{\ *[a-zA-Z_$][a-zA-Z0-9_$]*\ *:\ *\} ]]; then
        echo -e "${RED}Error at line $line_num, column $((pos+1)): Invalid destructuring pattern (missing property name)${NC}"
        return 1
    fi
    
    if [[ "$remaining" =~ ^\{\ *:\ *[a-zA-Z_$][a-zA-Z0-9_$]*\ *\} ]]; then
        echo -e "${RED}Error at line $line_num, column $((pos+1)): Invalid destructuring pattern (missing key)${NC}"
        return 1
    fi
    
    if [[ "$remaining" =~ ^\{\ *[a-zA-Z_$][a-zA-Z0-9_$]*\ *=\ *\} ]]; then
        echo -e "${RED}Error at line $line_num, column $((pos+1)): Invalid destructuring pattern (missing default value)${NC}"
        return 1
    fi
    
    # Check for rest operator not last
    if [[ "$remaining" =~ \.\.\.\ *[a-zA-Z_$][a-zA-Z0-9_$]*\ *, ]]; then
        echo -e "${RED}Error at line $line_num, column $((pos+1)): Rest element must be last element${NC}"
        return 1
    fi
    
    # Array destructuring with ellipsis only
    if [[ "$remaining" =~ ^\[\ *\.\.\.\ *\] ]]; then
        echo -e "${RED}Error at line $line_num, column $((pos+1)): Invalid array destructuring pattern${NC}"
        return 1
    fi
    
    # Array destructuring with missing default
    if [[ "$remaining" =~ ^\[\ *[a-zA-Z_$][a-zA-Z0-9_$]*\ *=\ *\] ]]; then
        echo -e "${RED}Error at line $line_num, column $((pos+1)): Missing default value in array destructuring${NC}"
        return 1
    fi
    
    # Array rest not last (fixed pattern)
    if [[ "$remaining" =~ ^\[\ *[a-zA-Z_$][a-zA-Z0-9_$]*\ *,\ *\.\.\.\ *[a-zA-Z_$][a-zA-Z0-9_$]*\ *, ]]; then
        echo -e "${RED}Error at line $line_num, column $((pos+1)): Rest element must be last element in array destructuring${NC}"
        return 1
    fi
    
    return 0
}

# Enhanced function to check for duplicate function parameters
check_duplicate_params() {
    local params="$1"
    local line_num="$2"
    local col="$3"
    
    # Remove whitespace and parentheses
    params=$(echo "$params" | tr -d '()')
    
    if [ -n "$params" ]; then
        local IFS=,
        local -A param_map
        for param in $params; do
            # Clean up the parameter (remove default values, destructuring, etc.)
            local clean_param=$(echo "$param" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | cut -d'=' -f1 | sed 's/^{//' | sed 's/}$//' | sed 's/^\[//' | sed 's/\]$//' | sed 's/\.\.\.//')
            
            # Extract just the parameter name if it's a destructuring pattern
            if [[ "$clean_param" =~ : ]]; then
                clean_param=$(echo "$clean_param" | cut -d':' -f2 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            fi
            
            if [ -n "$clean_param" ] && [ -n "${param_map[$clean_param]}" ]; then
                echo -e "${RED}Error at line $line_num, column $((col+1)): Duplicate parameter name '$clean_param'${NC}"
                return 1
            fi
            [ -n "$clean_param" ] && param_map["$clean_param"]=1
        done
    fi
    return 0
}

# Function to check for function rest parameter errors
check_rest_param() {
    local params="$1"
    local line_num="$2"
    local col="$3"
    
    # Check for empty rest parameter
    if [[ "$params" == *"..."*"..."* ]] || [[ "$params" == *"..."*"=..."* ]] || [[ "$params" == *"...)"* ]]; then
        echo -e "${RED}Error at line $line_num, column $((col+1)): Invalid rest parameter${NC}"
        return 1
    fi
    
    # Check if rest parameter is not last (more accurate pattern)
    if [[ "$params" =~ \.\.\.\ *[a-zA-Z_$][a-zA-Z0-9_$]*\ *, ]]; then
        echo -e "${RED}Error at line $line_num, column $((col+1)): Rest parameter must be last parameter${NC}"
        return 1
    fi
    
    return 0
}

# Function to check arrow function parameters
check_arrow_function() {
    local line="$1"
    local arrow_pos="$2"
    local line_num="$3"
    
    # Check what's before the arrow
    local before_pos=$((arrow_pos-1))
    
    # Skip whitespace backwards
    while [ $before_pos -ge 0 ] && is_whitespace "${line:$before_pos:1}"; do
        ((before_pos--))
    done
    
    if [ $before_pos -lt 0 ]; then
        echo -e "${RED}Error at line $line_num, column $((arrow_pos+1)): Arrow function requires parameters${NC}"
        return 1
    fi
    
    local char="${line:$before_pos:1}"
    
    # Check for various valid parameter patterns
    if [ "$char" = ")" ]; then
        # Parameters in parentheses - check if empty
        local paren_count=1
        local search_pos=$((before_pos-1))
        local has_content=false
        
        while [ $search_pos -ge 0 ]; do
            local search_char="${line:$search_pos:1}"
            if [ "$search_char" = ")" ]; then
                ((paren_count++))
            elif [ "$search_char" = "(" ]; then
                ((paren_count--))
                if [ $paren_count -eq 0 ]; then
                    # Check if there's any content between parentheses
                    local content="${line:$((search_pos+1)):$((before_pos-search_pos-1))}"
                    content=$(echo "$content" | tr -d ' ' | tr -d '\t')
                    if [ -z "$content" ]; then
                        echo -e "${RED}Error at line $line_num, column $((arrow_pos+1)): Arrow function requires parameters${NC}"
                        return 1
                    fi
                    return 0
                fi
            elif ! is_whitespace "$search_char" ]; then
                has_content=true
            fi
            ((search_pos--))
        done
        
        if ! $has_content; then
            echo -e "${RED}Error at line $line_num, column $((arrow_pos+1)): Arrow function requires parameters${NC}"
            return 1
        fi
    elif is_valid_identifier_char "$char"; then
        # Single identifier parameter - check if it's actually destructuring
        local search_back=$((before_pos-1))
        while [ $search_back -ge 0 ] && is_whitespace "${line:$search_back:1}"; do
            ((search_back--))
        done
        
        if [ $search_back -ge 0 ]; then
            local back_char="${line:$search_back:1}"
            if [ "$back_char" = "{" ] || [ "$back_char" = "[" ]; then
                echo -e "${RED}Error at line $line_num, column $((arrow_pos+1)): Destructuring parameters require parentheses in arrow functions${NC}"
                return 1
            fi
        fi
        return 0
    elif [ "$char" = "}" ] || [ "$char" = "]" ]; then
        # Destructuring without parentheses - invalid
        echo -e "${RED}Error at line $line_num, column $((arrow_pos+1)): Destructuring parameters require parentheses in arrow functions${NC}"
        return 1
    elif [ "$char" = "=" ]; then
        # Arrow with no parameters
        echo -e "${RED}Error at line $line_num, column $((arrow_pos+1)): Arrow function requires parameters${NC}"
        return 1
    else
        # No valid parameter pattern found
        echo -e "${RED}Error at line $line_num, column $((arrow_pos+1)): Arrow function requires parameters${NC}"
        return 1
    fi
    
    return 0
}

# Function to check for missing default values in function parameters
check_param_default() {
    local params="$1"
    local line_num="$2"
    local col="$3"
    
    # Check for parameter with = but no value
    if [[ "$params" =~ [a-zA-Z_$][a-zA-Z0-9_$]*[[:space:]]*=[[:space:]]*[')',','] ]]; then
        echo -e "${RED}Error at line $line_num, column $((col+1)): Missing default value in parameter${NC}"
        return 1
    fi
    
    # Check for destructuring with missing default
    if [[ "$params" =~ \{[^}]*=[[:space:]]*[')',','] ]] || [[ "$params" =~ \[[^\]]*=[[:space:]]*[')',','] ]]; then
        echo -e "${RED}Error at line $line_num, column $((col+1)): Missing default value in destructuring parameter${NC}"
        return 1
    fi
    
    return 0
}

# Function to check export conflicts
check_export_conflict() {
    local line="$1"
    local line_num="$2"
    local col="$3"
    local -n exports_ref="$4"
    
    # Check for export { x } pattern
    if [[ "$line" =~ export[[:space:]]*\{[^}]*\} ]]; then
        local export_content=$(echo "$line" | sed -n 's/.*export[[:space:]]*{\([^}]*\)}.*/\1/p')
        
        # Extract variable names from export
        local IFS=','
        for item in $export_content; do
            local var_name=$(echo "$item" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | sed 's/as.*//' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            
            if [ -n "$var_name" ] && [ -n "${exports_ref[$var_name]}" ]; then
                echo -e "${RED}Error at line $line_num, column $((col+1)): Export conflict for '$var_name'${NC}"
                return 1
            fi
            [ -n "$var_name" ] && exports_ref["$var_name"]="$line_num"
        done
    fi
    
    # Check for export let/const/var declarations
    if [[ "$line" =~ export[[:space:]]+(let|const|var)[[:space:]]+ ]]; then
        # Extract variable name after export declaration
        local var_part=$(echo "$line" | sed -n 's/.*export[[:space:]]*\(let\|const\|var\)[[:space:]]*\([^=;,\[]*\).*/\2/p')
        local var_name=$(echo "$var_part" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | cut -d',' -f1 | cut -d'=' -f1)
        
        if [ -n "$var_name" ] && [ -n "${exports_ref[$var_name]}" ]; then
            echo -e "${RED}Error at line $line_num, column $((col+1)): Export conflict for '$var_name'${NC}"
            return 1
        fi
        [ -n "$var_name" ] && exports_ref["$var_name"]="$line_num"
    fi
    
    return 0
}

# Function to check for function redefinition in same scope
check_function_redefinition() {
    local line="$1"
    local line_num="$2"
    local col="$3"
    local -n declared_vars_ref="$4"
    local -n declared_funcs_ref="$5"
    local current_scope="$6"
    
    # Check for function declaration
    if [[ "$line" =~ ^[[:space:]]*function[[:space:]]+([a-zA-Z_$][a-zA-Z0-9_$]*)[[:space:]]*\( ]]; then
        local func_name=$(echo "$line" | sed -n 's/^[[:space:]]*function[[:space:]]*\([a-zA-Z_$][a-zA-Z0-9_$]*\).*/\1/p')
        
        if [ -n "$func_name" ]; then
            # Check if there's already a variable with same name in this scope
            local var_key="${current_scope}_${func_name}"
            if [ -n "${declared_vars_ref[$var_key]}" ]; then
                echo -e "${RED}Error at line $line_num, column $((col+1)): Identifier '$func_name' has already been declared as variable${NC}"
                return 1
            fi
        fi
    fi
    
    # Check for variable declaration after function
    if [[ "$line" =~ ^[[:space:]]*(var|let|const)[[:space:]]+([a-zAZ_$][a-zA-Z0-9_$]*) ]]; then
        local var_name=$(echo "$line" | sed -n 's/^[[:space:]]*\(var\|let\|const\)[[:space:]]*\([a-zA-Z_$][a-zA-Z0-9_$]*\).*/\2/p')
        
        if [ -n "$var_name" ]; then
            # Check if there's already a function with same name in this scope
            local func_key="${current_scope}_${var_name}"
            if [ -n "${declared_funcs_ref[$func_key]}" ]; then
                echo -e "${RED}Error at line $line_num, column $((col+1)): Identifier '$var_name' has already been declared as function${NC}"
                return 1
            fi
        fi
    fi
    
    return 0
}

# Function to check for duplicate parameter in function body
check_duplicate_param_var() {
    local line="$1"
    local line_num="$2"
    local col="$3"
    local func_name="$4"
    local params="$5"
    local -n declared_vars_ref="$6"
    
    # Extract variable names from line
    if [[ "$line" =~ ^[[:space:]]*(let|const|var)[[:space:]]+([a-zA-Z_$][a-zA-Z0-9_$]*) ]]; then
        local var_name=$(echo "$line" | sed -n 's/^[[:space:]]*\(let\|const\|var\)[[:space:]]*\([a-zA-Z_$][a-zA-Z0-9_$]*\).*/\2/p')
        
        if [ -n "$var_name" ]; then
            # Check if this variable name is in function parameters
            if [[ ",${params}," == *",${var_name},"* ]] || [[ "$params" == *"${var_name}"* ]]; then
                echo -e "${RED}Error at line $line_num, column $((col+1)): Identifier '$var_name' has already been declared as parameter${NC}"
                return 1
            fi
        fi
    fi
    
    return 0
}

# Function to check declaration syntax errors
check_declaration_syntax() {
    local filename="$1"
    local line_number=0
    local in_comment_single=false
    local in_comment_multi=false
    local in_string_single=false
    local in_string_double=false
    local in_template=false
    
    # Scope tracking
    local current_scope="global"
    local scope_level=0
    declare -A declared_vars
    declare -A declared_functions
    declare -A declared_classes
    declare -A exported_vars
    declare -A function_params_map
    declare -A function_params
    
    local in_function=false
    local function_name=""
    local function_params_str=""
    local in_class=false
    local class_name=""
    local class_has_constructor=false
    local class_extends=false
    local class_parent=""
    local in_async_context=false
    local in_generator=false
    local in_strict_mode=false
    local in_for_loop=false
    local in_switch=false
    local in_case=false
    local in_default=false
    local in_arrow_function=false
    local in_destructuring=false
    local in_export=false
    local in_import=false
    local in_constructor=false
    local in_function_params=false
    local current_function_params=""
    
    # Track recent declarations
    local last_declaration=""
    local last_declaration_type=""
    local last_declaration_line=0
    
    # Read entire file into array for better lookahead
    mapfile -t lines < "$filename" 2>/dev/null || while IFS= read -r line; do lines+=("$line"); done < "$filename"
    
    # Process each line
    for line_index in "${!lines[@]}"; do
        line_number=$((line_index + 1))
        local line="${lines[$line_index]}"
        
        # Check for strict mode
        if check_strict_mode "$line"; then
            in_strict_mode=true
        fi
        
        # Check for function redefinition issues BEFORE processing tokens
        if $in_function && [ -n "$function_name" ] && [ "$current_scope" = "function:$function_name" ]; then
            if ! check_function_redefinition "$line" "$line_number" 0 declared_vars declared_functions "$current_scope"; then
                echo "  $line"
                return 1
            fi
            
            # Check for duplicate parameter/variable
            if [ -n "$function_params_str" ] && [ "$function_params_str" != "()" ]; then
                if ! check_duplicate_param_var "$line" "$line_number" 0 "$function_name" "$function_params_str" declared_vars; then
                    echo "  $line"
                    return 1
                fi
            fi
        fi
        
        # Process line character by character
        local col=0
        local line_length=${#line}
        
        while [ $col -lt $line_length ]; do
            local char="${line:$col:1}"
            local next_char=""
            [ $((col+1)) -lt $line_length ] && next_char="${line:$((col+1)):1}"
            
            # Track string/comment states
            if ! $in_comment_single && ! $in_comment_multi; then
                if [ "$char" = "'" ] && ! $in_string_double && ! $in_template; then
                    in_string_single=$(! $in_string_single)
                elif [ "$char" = '"' ] && ! $in_string_single && ! $in_template; then
                    in_string_double=$(! $in_string_double)
                elif [ "$char" = '`' ] && ! $in_string_single && ! $in_string_double; then
                    in_template=$(! $in_template)
                elif [ "$char" = '/' ] && ! $in_string_single && ! $in_string_double && ! $in_template; then
                    if [ "$next_char" = '/' ]; then
                        in_comment_single=true
                        ((col++))
                    elif [ "$next_char" = '*' ]; then
                        in_comment_multi=true
                        ((col++))
                    fi
                fi
            fi
            
            # End multi-line comment
            if $in_comment_multi && [ "$char" = '*' ] && [ "$next_char" = '/' ]; then
                in_comment_multi=false
                ((col++))
            fi
            
            # Only process if not in string/comment
            if ! $in_string_single && ! $in_string_double && ! $in_template && ! $in_comment_single && ! $in_comment_multi; then
                # Check for octal literals in strict mode
                if $in_strict_mode && check_octal_literal "$line" $col; then
                    echo -e "${RED}Error at line $line_number, column $((col+1)): Octal literals are not allowed in strict mode${NC}"
                    echo "  $line"
                    printf "%*s^%s\n" $col "" "${RED}here${NC}"
                    return 1
                fi
                
                # Get token at current position
                token=$(get_token "$line" $col)
                local token_length=${#token}
                
                if [ -n "$token" ]; then
                    # Check for declaration errors
                    case "$token" in
                        # Variable declarations
                        'let'|'const'|'var')
                            local decl_type="$token"
                            local decl_line=$line_number
                            local decl_col=$col
                            
                            # Track for mixed declarations
                            if [ -n "$last_declaration" ] && [ "$last_declaration_type" = "$decl_type" ] && [ "$last_declaration_line" = "$decl_line" ]; then
                                # Check if this is a mixed declaration attempt
                                local check_pos=$((col-1))
                                while [ $check_pos -ge 0 ] && is_whitespace "${line:$check_pos:1}"; do
                                    ((check_pos--))
                                done
                                
                                if [ $check_pos -ge 0 ] && [ "${line:$check_pos:1}" = "," ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col+1)): Mixed declarations in single statement${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                    return 1
                                fi
                            fi
                            
                            if [ "$decl_type" = "const" ]; then
                                # Check for const without initializer
                                local search_pos=$((col+token_length))
                                local found_equals=false
                                local found_semicolon=false
                                local found_comma=false
                                
                                # Look ahead in the same line
                                while [ $search_pos -lt $line_length ]; do
                                    local search_char="${line:$search_pos:1}"
                                    if [ "$search_char" = "=" ]; then
                                        found_equals=true
                                        break
                                    elif [ "$search_char" = ";" ]; then
                                        found_semicolon=true
                                        break
                                    elif [ "$search_char" = "," ]; then
                                        found_comma=true
                                        break
                                    elif [ "$search_char" = "{" ] || [ "$search_char" = "(" ]; then
                                        break
                                    fi
                                    ((search_pos++))
                                done
                                
                                # If we found semicolon or comma without equals, it's an error
                                if { $found_semicolon || $found_comma; } && ! $found_equals; then
                                    echo -e "${RED}Error at line $line_number, column $((col+1)): Missing initializer in const declaration${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                    return 1
                                fi
                            fi
                            
                            # Check for mixed declarations in for loop
                            if $in_for_loop; then
                                local check_back=$((col-1))
                                local found_comma_before=false
                                while [ $check_back -ge 0 ] && is_whitespace "${line:$check_back:1}"; do
                                    ((check_back--))
                                done
                                
                                if [ $check_back -ge 0 ] && [ "${line:$check_back:1}" = "," ]; then
                                    # Check what's before the comma
                                    local before_comma=$((check_back-1))
                                    while [ $before_comma -ge 0 ] && is_whitespace "${line:$before_comma:1}"; do
                                        ((before_comma--))
                                    done
                                    
                                    if [ $before_comma -ge 0 ]; then
                                        local before_token=$(get_token "$line" $before_comma)
                                        if [ "$decl_type" = "let" ] && { [ "$before_token" = "var" ] || [ "$before_token" = "const" ]; } ||
                                           [ "$decl_type" = "const" ] && { [ "$before_token" = "var" ] || [ "$before_token" = "let" ]; } ||
                                           [ "$decl_type" = "var" ] && { [ "$before_token" = "let" ] || [ "$before_token" = "const" ]; }; then
                                            echo -e "${RED}Error at line $line_number, column $((col+1)): Mixed declarations in for loop${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                            return 1
                                        fi
                                    fi
                                fi
                            fi
                            
                            # Extract variable name(s)
                            local name_pos=$((col+token_length))
                            while [ $name_pos -lt $line_length ] && is_whitespace "${line:$name_pos:1}"; do
                                ((name_pos++))
                            done
                            
                            if [ $name_pos -lt $line_length ]; then
                                # Handle multiple variables
                                local current_pos=$name_pos
                                while [ $current_pos -lt $line_length ]; do
                                    # Extract variable name
                                    local var_name=$(extract_var_name "$line" $current_pos)
                                    if [ -z "$var_name" ]; then
                                        break
                                    fi
                                    
                                    # Check if variable name is valid
                                    if [[ "$var_name" =~ ^[0-9] ]]; then
                                        echo -e "${RED}Error at line $line_number, column $((current_pos+1)): Invalid variable name starting with number${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $current_pos "" "${RED}here${NC}"
                                        return 1
                                    fi
                                    
                                    # Check for reserved word as variable name
                                    if is_reserved_word "$var_name"; then
                                        echo -e "${RED}Error at line $line_number, column $((current_pos+1)): Cannot use reserved word '$var_name' as variable name${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $current_pos "" "${RED}here${NC}"
                                        return 1
                                    fi
                                    
                                    # Check for duplicate declaration in same scope
                                    if ! check_duplicate_declaration "$current_scope" "$var_name" "$decl_type" "$line_number" $current_pos declared_vars; then
                                        echo "  $line"
                                        printf "%*s^%s\n" $current_pos "" "${RED}here${NC}"
                                        return 1
                                    fi
                                    
                                    # Check if var is trying to redeclare let/const/function/class
                                    if [ "$decl_type" = "var" ]; then
                                        local scope_key="${current_scope}_$var_name"
                                        if [ -n "${declared_vars[$scope_key]}" ]; then
                                            local existing_type="${declared_vars[$scope_key]%%:*}"
                                            if [ "$existing_type" = "let" ] || [ "$existing_type" = "const" ] || [ "$existing_type" = "function" ] || [ "$existing_type" = "class" ]; then
                                                echo -e "${RED}Error at line $line_number, column $((current_pos+1)): Cannot redeclare block-scoped variable '$var_name'${NC}"
                                                echo "  $line"
                                                printf "%*s^%s\n" $current_pos "" "${RED}here${NC}"
                                                return 1
                                            fi
                                        fi
                                    fi
                                    
                                    # Move past the variable name
                                    current_pos=$((current_pos + ${#var_name}))
                                    
                                    # Skip whitespace
                                    while [ $current_pos -lt $line_length ] && is_whitespace "${line:$current_pos:1}"; do
                                        ((current_pos++))
                                    done
                                    
                                    # Check if there's a comma for another variable
                                    if [ $current_pos -lt $line_length ] && [ "${line:$current_pos:1}" = "," ]; then
                                        ((current_pos++))
                                        # Skip whitespace after comma
                                        while [ $current_pos -lt $line_length ] && is_whitespace "${line:$current_pos:1}"; do
                                            ((current_pos++))
                                        done
                                        
                                        # Check for mixed declarations after comma
                                        if [ $current_pos -lt $line_length ]; then
                                            local next_decl=$(get_token "$line" $current_pos)
                                            if [ "$next_decl" = "let" ] || [ "$next_decl" = "const" ] || [ "$next_decl" = "var" ]; then
                                                echo -e "${RED}Error at line $line_number, column $((current_pos+1)): Mixed declarations in single statement${NC}"
                                                echo "  $line"
                                                printf "%*s^%s\n" $current_pos "" "${RED}here${NC}"
                                                return 1
                                            fi
                                        fi
                                    else
                                        break
                                    fi
                                done
                            fi
                            
                            last_declaration="$var_name"
                            last_declaration_type="$decl_type"
                            last_declaration_line=$line_number
                            ;;
                            
                        # Function declarations
                        'function')
                            # Check for generator
                            local is_generator=false
                            local check_pos=$col
                            if [ $check_pos -gt 0 ] && [ "${line:$((check_pos-1)):1}" = "*" ]; then
                                is_generator=true
                            fi
                            
                            # Look for function name
                            local name_pos=$((col+token_length))
                            while [ $name_pos -lt $line_length ] && is_whitespace "${line:$name_pos:1}"; do
                                ((name_pos++))
                            done
                            
                            if [ $name_pos -lt $line_length ]; then
                                local fn_name=$(get_token "$line" $name_pos)
                                
                                # Check for invalid function names
                                if is_reserved_word "$fn_name"; then
                                    echo -e "${RED}Error at line $line_number, column $((name_pos+1)): Unexpected token '$fn_name'${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $name_pos "" "${RED}here${NC}"
                                    return 1
                                fi
                                
                                if [[ "$fn_name" =~ ^[0-9] ]]; then
                                    echo -e "${RED}Error at line $line_number, column $((name_pos+1)): Unexpected number${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $name_pos "" "${RED}here${NC}"
                                    return 1
                                fi
                                
                                # Look for parameters
                                local param_start=$((name_pos + ${#fn_name}))
                                while [ $param_start -lt $line_length ] && [ "${line:$param_start:1}" != "(" ]; do
                                    ((param_start++))
                                done
                                
                                if [ $param_start -lt $line_length ]; then
                                    local param_end=$param_start
                                    local paren_count=1
                                    ((param_end++))
                                    
                                    while [ $param_end -lt $line_length ] && [ $paren_count -gt 0 ]; do
                                        if [ "${line:$param_end:1}" = "(" ]; then
                                            ((paren_count++))
                                        elif [ "${line:$param_end:1}" = ")" ]; then
                                            ((paren_count--))
                                        fi
                                        ((param_end++))
                                    done
                                    
                                    if [ $paren_count -eq 0 ]; then
                                        local params="${line:$param_start:$((param_end-param_start))}"
                                        function_params_str="$params"
                                        
                                        # Check for duplicate parameters
                                        if ! check_duplicate_params "$params" "$line_number" $param_start; then
                                            echo "  $line"
                                            printf "%*s^%s\n" $param_start "" "${RED}here${NC}"
                                            return 1
                                        fi
                                        
                                        # Check for rest parameter errors
                                        if ! check_rest_param "$params" "$line_number" $param_start; then
                                            echo "  $line"
                                            printf "%*s^%s\n" $param_start "" "${RED}here${NC}"
                                            return 1
                                        fi
                                        
                                        # Check for missing default values
                                        if ! check_param_default "$params" "$line_number" $param_start; then
                                            echo "  $line"
                                            printf "%*s^%s\n" $param_start "" "${RED}here${NC}"
                                            return 1
                                        fi
                                        
                                        # Store parameters for later checking
                                        function_params_map["$fn_name"]="$params"
                                        function_params["$fn_name"]="$params"
                                    fi
                                fi
                                
                                # Enter function scope
                                in_function=true
                                function_name="$fn_name"
                                if $is_generator; then
                                    in_generator=true
                                fi
                                current_scope="function:$fn_name"
                                scope_level=$((scope_level + 1))
                                
                                # Check for duplicate function declaration in same scope
                                local scope_key="${current_scope}_$fn_name"
                                if [ -n "${declared_functions[$scope_key]}" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((name_pos+1)): Identifier '$fn_name' has already been declared${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $name_pos "" "${RED}here${NC}"
                                    return 1
                                fi
                                declared_functions["$scope_key"]="$line_number"
                            else
                                # Anonymous function
                                in_function=true
                                function_name="anonymous"
                                current_scope="function:anonymous_$line_number"
                                scope_level=$((scope_level + 1))
                            fi
                            ;;
                            
                        # Async keyword
                        'async')
                            if $in_function && [ "$current_scope" != "global" ]; then
                                in_async_context=true
                            else
                                # Check if async is used as function name
                                local next_pos=$((col+token_length))
                                while [ $next_pos -lt $line_length ] && is_whitespace "${line:$next_pos:1}"; do
                                    ((next_pos++))
                                done
                                
                                if [ $next_pos -lt $line_length ]; then
                                    local next_token=$(get_token "$line" $next_pos)
                                    if [ "$next_token" = "function" ]; then
                                        in_async_context=true
                                    else
                                        echo -e "${RED}Error at line $line_number, column $((col+1)): Unexpected token 'async'${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                        return 1
                                    fi
                                fi
                            fi
                            ;;
                            
                        # Yield outside generator
                        'yield')
                            if ! $in_generator && $in_function; then
                                echo -e "${RED}Error at line $line_number, column $((col+1)): 'yield' outside generator function${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                return 1
                            fi
                            ;;
                            
                        # Await outside async
                        'await')
                            if ! $in_async_context && $in_function; then
                                echo -e "${RED}Error at line $line_number, column $((col+1)): 'await' outside async function${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                return 1
                            fi
                            ;;
                            
                        # Class declarations
                        'class')
                            # Look for class name
                            local name_pos=$((col+token_length))
                            while [ $name_pos -lt $line_length ] && is_whitespace "${line:$name_pos:1}"; do
                                ((name_pos++))
                            done
                            
                            if [ $name_pos -lt $line_length ]; then
                                local cls_name=$(get_token "$line" $name_pos)
                                
                                # Check for missing class name
                                if [ "$cls_name" = "{" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((name_pos+1)): Unexpected token '{'${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $name_pos "" "${RED}here${NC}"
                                    return 1
                                fi
                                
                                # Check for invalid class name
                                if is_reserved_word "$cls_name"; then
                                    echo -e "${RED}Error at line $line_number, column $((name_pos+1)): Unexpected token '$cls_name'${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $name_pos "" "${RED}here${NC}"
                                    return 1
                                fi
                                
                                if [[ "$cls_name" =~ ^[0-9] ]]; then
                                    echo -e "${RED}Error at line $line_number, column $((name_pos+1)): Unexpected number${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $name_pos "" "${RED}here${NC}"
                                    return 1
                                fi
                                
                                # Check for circular inheritance
                                local check_inherit=$((name_pos + ${#cls_name}))
                                while [ $check_inherit -lt $line_length ] && is_whitespace "${line:$check_inherit:1}"; do
                                    ((check_inherit++))
                                done
                                
                                if [ $check_inherit -lt $line_length ] && [ "${line:$check_inherit:1}" != "{" ]; then
                                    local extends_token=$(get_token "$line" $check_inherit)
                                    if [ "$extends_token" = "extends" ]; then
                                        class_extends=true
                                        local parent_pos=$((check_inherit + ${#extends_token}))
                                        while [ $parent_pos -lt $line_length ] && is_whitespace "${line:$parent_pos:1}"; do
                                            ((parent_pos++))
                                        done
                                        
                                        if [ $parent_pos -lt $line_length ]; then
                                            local parent_name=$(get_token "$line" $parent_pos)
                                            if [ "$parent_name" = "$cls_name" ]; then
                                                echo -e "${RED}Error at line $line_number, column $((parent_pos+1)): Circular inheritance detected${NC}"
                                                echo "  $line"
                                                printf "%*s^%s\n" $parent_pos "" "${RED}here${NC}"
                                                return 1
                                            fi
                                            class_parent="$parent_name"
                                            
                                            # Check for invalid parent class
                                            if [[ "$parent_name" =~ ^[0-9] ]]; then
                                                echo -e "${RED}Error at line $line_number, column $((parent_pos+1)): Unexpected number${NC}"
                                                echo "  $line"
                                                printf "%*s^%s\n" $parent_pos "" "${RED}here${NC}"
                                                return 1
                                            fi
                                            
                                            if [ "$parent_name" = "{" ]; then
                                                echo -e "${RED}Error at line $line_number, column $((parent_pos+1)): Unexpected token '{'${NC}"
                                                echo "  $line"
                                                printf "%*s^%s\n" $parent_pos "" "${RED}here${NC}"
                                                return 1
                                            fi
                                        fi
                                    fi
                                fi
                                
                                in_class=true
                                class_name="$cls_name"
                                class_has_constructor=false
                                current_scope="class:$cls_name"
                                scope_level=$((scope_level + 1))
                                
                                # Check for duplicate class declaration
                                if [ -n "${declared_classes[$cls_name]}" ] && [ "$current_scope" = "global" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((name_pos+1)): Identifier '$cls_name' has already been declared${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $name_pos "" "${RED}here${NC}"
                                    return 1
                                fi
                                declared_classes["$cls_name"]="$line_number"
                            fi
                            ;;
                            
                        # Constructor in class
                        'constructor')
                            if $in_class; then
                                if $class_has_constructor; then
                                    echo -e "${RED}Error at line $line_number, column $((col+1)): A class may only have one constructor${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                    return 1
                                fi
                                class_has_constructor=true
                                in_constructor=true
                                
                                # Check for constructor with async or generator
                                local check_pos=$((col+token_length))
                                while [ $check_pos -lt $line_length ] && is_whitespace "${line:$check_pos:1}"; do
                                    ((check_pos++))
                                done
                                
                                if [ $check_pos -lt $line_length ]; then
                                    # Check for constructor*() - generator constructor
                                    if [ "${line:$check_pos:1}" = "*" ]; then
                                        echo -e "${RED}Error at line $line_number, column $((check_pos+1)): Constructor cannot be a generator${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $check_pos "" "${RED}here${NC}"
                                        return 1
                                    fi
                                    
                                    local next_token=$(get_token "$line" $check_pos)
                                    if [ "$next_token" = "async" ]; then
                                        echo -e "${RED}Error at line $line_number, column $((check_pos+1)): Constructor cannot be async${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $check_pos "" "${RED}here${NC}"
                                        return 1
                                    fi
                                fi
                            fi
                            ;;
                            
                        # This keyword in derived class constructor
                        'this')
                            if $in_constructor && $class_extends; then
                                # Check if super() has been called before this
                                local found_super=false
                                
                                # Check current line before this position
                                local check_pos=0
                                while [ $check_pos -lt $col ]; do
                                    if [ "${line:$check_pos:5}" = "super" ]; then
                                        # Check if super is followed by parentheses
                                        local super_end=$((check_pos+5))
                                        while [ $super_end -lt $line_length ] && is_whitespace "${line:$super_end:1}"; do
                                            ((super_end++))
                                        done
                                        if [ $super_end -lt $line_length ] && [ "${line:$super_end:1}" = "(" ]; then
                                            found_super=true
                                            break
                                        fi
                                    fi
                                    ((check_pos++))
                                done
                                
                                # Check previous lines
                                if ! $found_super; then
                                    for ((i=line_index-1; i>=0; i--)); do
                                        if [[ "${lines[$i]}" == *"super("* ]] || [[ "${lines[$i]}" == *"super ("* ]]; then
                                            found_super=true
                                            break
                                        fi
                                    done
                                fi
                                
                                if ! $found_super; then
                                    echo -e "${RED}Error at line $line_number, column $((col+1)): 'this' cannot be used before super() in derived class constructor${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        # Super call
                        'super')
                            if $in_constructor && $class_extends; then
                                # Check if super is called with parentheses
                                local check_pos=$((col+5))
                                while [ $check_pos -lt $line_length ] && is_whitespace "${line:$check_pos:1}"; do
                                    ((check_pos++))
                                done
                                
                                if [ $check_pos -ge $line_length ] || [ "${line:$check_pos:1}" != "(" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col+1)): Missing parentheses for super call${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        # Import/export errors
                        'import')
                            in_import=true
                            # Check for invalid import syntax
                            local next_pos=$((col+token_length))
                            while [ $next_pos -lt $line_length ] && is_whitespace "${line:$next_pos:1}"; do
                                ((next_pos++))
                            done
                            
                            if [ $next_pos -lt $line_length ]; then
                                local next_token=$(get_token "$line" $next_pos)
                                
                                if [ "$next_token" = "from" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((next_pos+1)): Unexpected identifier 'from'${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $next_pos "" "${RED}here${NC}"
                                    return 1
                                fi
                                
                                # Check for mixed default and namespace imports
                                if [ "$next_token" = "default" ] || [[ "$next_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                    local check_comma=$((next_pos + ${#next_token}))
                                    while [ $check_comma -lt $line_length ] && is_whitespace "${line:$check_comma:1}"; do
                                        ((check_comma++))
                                    done
                                    
                                    if [ $check_comma -lt $line_length ] && [ "${line:$check_comma:1}" = "," ]; then
                                        local after_comma=$((check_comma+1))
                                        while [ $after_comma -lt $line_length ] && is_whitespace "${line:$after_comma:1}"; do
                                            ((after_comma++))
                                        done
                                        
                                        if [ $after_comma -lt $line_length ]; then
                                            local after_token=$(get_token "$line" $after_comma)
                                            if [ "$after_token" = "*" ]; then
                                                echo -e "${RED}Error at line $line_number, column $((after_comma+1)): Cannot mix default and namespace imports${NC}"
                                                echo "  $line"
                                                printf "%*s^%s\n" $after_comma "" "${RED}here${NC}"
                                                return 1
                                            fi
                                        fi
                                    fi
                                fi
                            fi
                            ;;
                            
                        'export')
                            in_export=true
                            # Basic export syntax checks
                            local next_pos=$((col+token_length))
                            while [ $next_pos -lt $line_length ] && is_whitespace "${line:$next_pos:1}"; do
                                ((next_pos++))
                            done
                            
                            if [ $next_pos -lt $line_length ]; then
                                local next_token=$(get_token "$line" $next_pos)
                                
                                if [ "$next_token" = "default" ]; then
                                    local after_default=$((next_pos + ${#next_token}))
                                    while [ $after_default -lt $line_length ] && is_whitespace "${line:$after_default:1}"; do
                                        ((after_default++))
                                    done
                                    
                                    if [ $after_default -lt $line_length ]; then
                                        local after_token=$(get_token "$line" $after_default)
                                        if [ "$after_token" = "const" ] || [ "$after_token" = "let" ] || [ "$after_token" = "var" ]; then
                                            echo -e "${RED}Error at line $line_number, column $((after_default+1)): Unexpected token '$after_token'${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $after_default "" "${RED}here${NC}"
                                            return 1
                                        fi
                                    fi
                                elif is_number "$next_token"; then
                                    echo -e "${RED}Error at line $line_number, column $((next_pos+1)): Unexpected number${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $next_pos "" "${RED}here${NC}"
                                    return 1
                                elif [ "$next_token" = "{" ]; then
                                    # Handle export { x } from "module"
                                    local brace_pos=$next_pos
                                    local end_brace=$brace_pos
                                    local brace_count=1
                                    ((end_brace++))
                                    
                                    while [ $end_brace -lt $line_length ] && [ $brace_count -gt 0 ]; do
                                        if [ "${line:$end_brace:1}" = "{" ]; then
                                            ((brace_count++))
                                        elif [ "${line:$end_brace:1}" = "}" ]; then
                                            ((brace_count--))
                                        fi
                                        ((end_brace++))
                                    done
                                    
                                    if [ $brace_count -eq 0 ]; then
                                        # Check for export conflicts
                                        if ! check_export_conflict "$line" "$line_number" $brace_pos exported_vars; then
                                            echo "  $line"
                                            printf "%*s^%s\n" $brace_pos "" "${RED}here${NC}"
                                            return 1
                                        fi
                                    fi
                                else
                                    # Export of let/const/var declaration
                                    # Check for export conflicts
                                    if ! check_export_conflict "$line" "$line_number" $col exported_vars; then
                                        echo "  $line"
                                        printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                        return 1
                                    fi
                                fi
                            fi
                            ;;
                            
                        # Check for destructuring errors
                        '{')
                            # Check destructuring patterns
                            if ! check_destructuring_pattern "$line" $col $line_number; then
                                echo "  $line"
                                printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                return 1
                            fi
                            
                            local check_pos=$((col-1))
                            local is_destructuring=false
                            
                            # Check if this is likely a destructuring pattern
                            while [ $check_pos -ge 0 ] && is_whitespace "${line:$check_pos:1}"; do
                                ((check_pos--))
                            done
                            
                            if [ $check_pos -ge 0 ]; then
                                local prev_char="${line:$check_pos:1}"
                                if [ "$prev_char" = "=" ] || [ "$prev_char" = "(" ] || [ "$prev_char" = "," ] || 
                                   [ "$prev_char" = "{" ] || [ "$prev_char" = "[" ] || 
                                   [ "$prev_char" = ":" ] || [ "$prev_char" = "}" ]; then
                                    is_destructuring=true
                                    in_destructuring=true
                                fi
                            fi
                            ;;
                            
                        '[')
                            # Check destructuring patterns for arrays
                            if ! check_destructuring_pattern "$line" $col $line_number; then
                                echo "  $line"
                                printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                return 1
                            fi
                            
                            local check_pos=$((col-1))
                            local is_destructuring=false
                            
                            # Check if this is likely a destructuring pattern
                            while [ $check_pos -ge 0 ] && is_whitespace "${line:$check_pos:1}"; do
                                ((check_pos--))
                            done
                            
                            if [ $check_pos -ge 0 ]; then
                                local prev_char="${line:$check_pos:1}"
                                if [ "$prev_char" = "=" ] || [ "$prev_char" = "(" ] || [ "$prev_char" = "," ] || 
                                   [ "$prev_char" = "[" ] || [ "$prev_char" = "{" ]; then
                                    is_destructuring=true
                                    in_destructuring=true
                                fi
                            fi
                            ;;
                            
                        # Check for arrow function errors
                        '=>')
                            if ! check_arrow_function "$line" $col $line_number; then
                                echo "  $line"
                                printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                return 1
                            fi
                            in_arrow_function=true
                            ;;
                            
                        # For loop handling
                        'for')
                            in_for_loop=true
                            ;;
                            
                        # Switch handling
                        'switch')
                            in_switch=true
                            ;;
                            
                        # Check for implicit global in strict mode
                        '=')
                            if $in_strict_mode && ! $in_string_single && ! $in_string_double && ! $in_template; then
                                # Check if this is an assignment to an undeclared variable
                                local before_pos=$((col-1))
                                while [ $before_pos -ge 0 ] && is_whitespace "${line:$before_pos:1}"; do
                                    ((before_pos--))
                                done
                                
                                if [ $before_pos -ge 0 ]; then
                                    # Get the identifier before the =
                                    local ident_start=$before_pos
                                    while [ $ident_start -ge 0 ] && is_valid_identifier_char "${line:$ident_start:1}"; do
                                        ((ident_start--))
                                    done
                                    ((ident_start++))
                                    
                                    local ident="${line:$ident_start:$((before_pos-ident_start+1))}"
                                    
                                    # Check if it's a valid identifier and not a declaration
                                    if [ -n "$ident" ] && ! is_reserved_word "$ident" && [[ "$ident" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                        # Check if this identifier was declared
                                        local scope_key="${current_scope}_${ident}"
                                        if [ -z "${declared_vars[$scope_key]}" ] && [ "$current_scope" = "global" ]; then
                                            echo -e "${RED}Error at line $line_number, column $((ident_start+1)): Assignment to undeclared variable '$ident' in strict mode${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $ident_start "" "${RED}here${NC}"
                                            return 1
                                        fi
                                    fi
                                fi
                            fi
                            ;;
                            
                        # Check for function and var with same name in same scope
                        'var')
                            if $in_function && [ "$function_name" != "" ]; then
                                local name_pos=$((col+3))
                                while [ $name_pos -lt $line_length ] && is_whitespace "${line:$name_pos:1}"; do
                                    ((name_pos++))
                                done
                                
                                if [ $name_pos -lt $line_length ]; then
                                    local var_name=$(extract_var_name "$line" $name_pos)
                                    if [ "$var_name" = "$function_name" ]; then
                                        echo -e "${RED}Error at line $line_number, column $((name_pos+1)): Identifier '$var_name' has already been declared as function${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $name_pos "" "${RED}here${NC}"
                                        return 1
                                    fi
                                fi
                            fi
                            ;;
                            
                        # Check for label on declaration
                        ':')
                            local before_pos=$((col-1))
                            while [ $before_pos -ge 0 ] && is_whitespace "${line:$before_pos:1}"; do
                                ((before_pos--))
                            done
                            
                            if [ $before_pos -ge 0 ]; then
                                local label_start=$before_pos
                                while [ $label_start -ge 0 ] && is_valid_identifier_char "${line:$label_start:1}"; do
                                    ((label_start--))
                                done
                                ((label_start++))
                                
                                local label="${line:$label_start:$((before_pos-label_start+1))}"
                                
                                # Check if this label is followed by a declaration
                                local after_pos=$((col+1))
                                while [ $after_pos -lt $line_length ] && is_whitespace "${line:$after_pos:1}"; do
                                    ((after_pos++))
                                done
                                
                                if [ $after_pos -lt $line_length ]; then
                                    local next_token=$(get_token "$line" $after_pos)
                                    if [ "$next_token" = "let" ] || [ "$next_token" = "const" ] || [ "$next_token" = "var" ] || 
                                       [ "$next_token" = "function" ] || [ "$next_token" = "class" ]; then
                                        echo -e "${RED}Error at line $line_number, column $((col+1)): Label cannot be used with declaration${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                        return 1
                                    fi
                                fi
                            fi
                            ;;
                    esac
                    
                    # Update column position
                    col=$((col + token_length - 1))
                fi
            fi
            
            ((col++))
        done
        
        # End of line processing
        if $in_comment_single; then
            in_comment_single=false
        fi
        
        # Check for end of destructuring
        if $in_destructuring && [[ "$line" == *"]"* ]] || [[ "$line" == *"}"* ]]; then
            in_destructuring=false
        fi
        
        # Check for end of for loop
        if $in_for_loop && [[ "$line" == *")"* ]] && [[ "$line" != *"for"* ]]; then
            in_for_loop=false
        fi
        
        # Check for end of constructor
        if $in_constructor && [[ "$line" == *"}"* ]]; then
            in_constructor=false
        fi
        
        # Reset export/import flags at end of line
        if $in_export && [[ "$line" == *";"* ]]; then
            in_export=false
        fi
        
        if $in_import && [[ "$line" == *";"* ]]; then
            in_import=false
        fi
        
        # Reset arrow function flag
        if $in_arrow_function && [[ "$line" == *";"* ]] || [[ "$line" == *"}"* ]]; then
            in_arrow_function=false
        fi
        
        # Reset function scope if we see closing brace at function level
        if $in_function && [ "$scope_level" -gt 0 ]; then
            if [[ "$line" == *"}"* ]] && [[ "$line" != *"{"* ]]; then
                # Count braces to see if we're exiting function scope
                local brace_count=0
                for ((i=0; i<${#line}; i++)); do
                    if [ "${line:$i:1}" = "}" ]; then
                        ((brace_count++))
                    elif [ "${line:$i:1}" = "{" ]; then
                        ((brace_count--))
                    fi
                done
                
                if [ $brace_count -gt 0 ]; then
                    in_function=false
                    function_name=""
                    function_params_str=""
                    in_async_context=false
                    in_generator=false
                    scope_level=$((scope_level - 1))
                    current_scope="global"
                fi
            fi
        fi
        
        # Reset class scope if we see closing brace at class level
        if $in_class && [ "$scope_level" -gt 0 ]; then
            if [[ "$line" == *"}"* ]] && [[ "$line" != *"{"* ]]; then
                in_class=false
                class_name=""
                class_extends=false
                class_parent=""
                class_has_constructor=false
                scope_level=$((scope_level - 1))
                current_scope="global"
            fi
        fi
        
    done
    
    # Final checks
    if $in_comment_multi; then
        echo -e "${RED}Error: Unterminated multi-line comment${NC}"
        return 1
    fi
    
    if $in_string_single || $in_string_double || $in_template; then
        echo -e "${RED}Error: Unterminated string literal${NC}"
        return 1
    fi
    
    # Check if derived class constructor doesn't call super()
    if $class_extends && $in_function && [ "$function_name" = "constructor" ]; then
        local super_called=false
        for line in "${lines[@]}"; do
            if [[ "$line" == *"super("* ]] || [[ "$line" == *"super ("* ]]; then
                super_called=true
                break
            fi
        done
        
        if ! $super_called; then
            echo -e "${RED}Error: Derived class constructor must call super()${NC}"
            return 1
        fi
    fi
    
    return 0
}

# Function to audit a single JavaScript file for declaration errors
audit_declaration_file() {
    local filename="$1"
    
    if [ ! -f "$filename" ]; then
        echo -e "${RED}Error: File '$filename' not found${NC}"
        return 1
    fi
    
    if [[ ! "$filename" =~ \.js$ ]]; then
        echo -e "${YELLOW}Warning: File '$filename' doesn't have .js extension${NC}"
    fi
    
    echo -e "${CYAN}Auditing declaration syntax:${NC} ${filename}"
    echo "========================================"
    
    # Check file size
    local file_size=$(wc -c < "$filename")
    if [ $file_size -eq 0 ]; then
        echo -e "${GREEN}✓ Empty file - no declaration errors${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    fi
    
    # Run declaration syntax checker
    if check_declaration_syntax "$filename"; then
        echo -e "${GREEN}✓ No declaration syntax errors found${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_declaration_tests() {
    echo -e "${BLUE}Running JavaScript Declaration Syntax Error Test Suite${NC}"
    echo "========================================"
    
    # Check if test directory exists
    if [ ! -d "$TEST_DIR" ]; then
        echo -e "${YELLOW}Test directory '$TEST_DIR' not found.${NC}"
        echo -e "${CYAN}Creating test directory...${NC}"
        
        # Check if tests.sh exists
        if [ -f "tests.sh" ]; then
            echo -e "${CYAN}Running tests.sh to generate test files...${NC}"
            bash tests.sh
            
            if [ -d "$TEST_DIR" ]; then
                echo -e "${GREEN}Test directory successfully generated!${NC}"
            else
                echo -e "${RED}Failed to generate test directory.${NC}"
                return 1
            fi
        else
            echo -e "${RED}tests.sh not found.${NC}"
            return 1
        fi
    fi
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    echo -e "${CYAN}Test Results:${NC}"
    echo ""
    
    # Find all .js files in test directory
    for test_file in "$TEST_DIR"/*.js; do
        [ -e "$test_file" ] || continue
        ((total_tests++))
        
        local filename=$(basename "$test_file")
        echo -e "${BLUE}Test ${total_tests}: ${filename}${NC}"
        
        # Run audit on test file
        if audit_declaration_file "$test_file" 2>/dev/null; then
            # Check if this test is expected to pass or fail
            # All test files should fail except possibly some edge cases
            echo -e "${RED}  ✗ Expected to fail but passed${NC}"
            ((failed_tests++))
        else
            echo -e "${GREEN}  ✓ Correctly detected declaration error${NC}"
            ((passed_tests++))
        fi
        echo ""
    done
    
    # Summary
    echo "========================================"
    echo -e "${CYAN}Test Summary:${NC}"
    echo -e "  Total tests:  $total_tests"
    echo -e "  ${GREEN}Passed:        $passed_tests${NC}"
    echo -e "  ${RED}Failed:        $failed_tests${NC}"
    
    if [ $total_tests -eq 0 ]; then
        echo -e "${YELLOW}No test files found in '$TEST_DIR/'${NC}"
        return 1
    fi
    
    return 0
}

# Main execution
main() {
    # Check for help flag
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_usage
        exit 0
    fi
    
    # Check for test mode
    if [ "$1" = "--test" ]; then
        run_declaration_tests
        exit $?
    fi
    
    # Check if filename is provided
    if [ $# -eq 0 ]; then
        echo -e "${RED}Error: No filename provided${NC}"
        show_usage
        exit 1
    fi
    
    # Audit single file
    audit_declaration_file "$1"
    exit $?
}

# Run main function
main "$@"
