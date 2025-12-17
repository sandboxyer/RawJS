#!/bin/bash

# JavaScript Declaration Syntax Error Auditor
# Usage: ./declaration.sh <filename.js> [--test]

DECLARATION_SCRIPT_VERSION="2.0.1"
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
                token="$char"
                ((pos++))
                while [ $pos -lt $length ] && [ "${line:$pos:1}" != "$char" ]; do
                    if [ "${line:$pos:1}" = "\\" ]; then
                        ((pos++))
                    fi
                    ((pos++))
                done
                if [ $pos -lt $length ]; then
                    ((pos++))
                fi
                ;;
            # Identifiers and numbers
            *)
                if is_valid_identifier_start "$char"; then
                    while [ $pos -lt $length ] && is_valid_identifier_char "${line:$pos:1}"; do
                        ((pos++))
                    done
                elif [[ "$char" =~ [0-9] ]]; then
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
        while [ $next_pos -lt $length ] && [[ "${line:$next_pos:1}" =~ [0-9] ]]; do
            ((next_pos++))
        done
        
        local num_str="${line:$col:$((next_pos-col))}"
        # Check if it's octal (starts with 0 and has digits 0-7 only, not followed by 8 or 9)
        if [[ "$num_str" =~ ^0[0-9]+$ ]] && ! [[ "$num_str" =~ [89] ]]; then
            if [[ "$num_str" != "0" ]] && [[ "${num_str:1:1}" != "." ]]; then
                return 0
            fi
        fi
    fi
    return 1
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
    declare -A declared_vars  # Hash for variables per scope
    declare -A declared_functions
    declare -A declared_classes
    
    local in_function=false
    local function_name=""
    local function_params=()
    local in_class=false
    local class_name=""
    local class_has_constructor=false
    local class_extends=false
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
    
    # Track recent declarations
    local last_declaration=""
    local last_declaration_type=""
    local last_declaration_line=0
    
    # Read file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_number++))
        
        # Check for strict mode
        if check_strict_mode "$line"; then
            in_strict_mode=true
        fi
        
        # Process line character by character
        local col=0
        local line_length=${#line}
        local token=""
        local token_start=0
        
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
                            last_declaration_type="$token"
                            last_declaration_line=$line_number
                            
                            if [ "$token" = "const" ]; then
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
                            
                            # Look for variable name
                            local name_pos=$((col+token_length))
                            while [ $name_pos -lt $line_length ] && is_whitespace "${line:$name_pos:1}"; do
                                ((name_pos++))
                            done
                            
                            if [ $name_pos -lt $line_length ]; then
                                local var_name=$(get_token "$line" $name_pos)
                                
                                # Check if variable name is valid
                                if [[ "$var_name" =~ ^[0-9] ]]; then
                                    echo -e "${RED}Error at line $line_number, column $((name_pos+1)): Invalid variable name starting with number${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $name_pos "" "${RED}here${NC}"
                                    return 1
                                fi
                                
                                # Check for reserved word as variable name
                                if is_reserved_word "$var_name"; then
                                    echo -e "${RED}Error at line $line_number, column $((name_pos+1)): Cannot use reserved word '$var_name' as variable name${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $name_pos "" "${RED}here${NC}"
                                    return 1
                                fi
                                
                                # Check for mixed declarations (e.g., "let x = 5, const y = 10")
                                if [ "$last_declaration_type" != "" ]; then
                                    local check_pos=$((name_pos + ${#var_name}))
                                    while [ $check_pos -lt $line_length ] && is_whitespace "${line:$check_pos:1}"; do
                                        ((check_pos++))
                                    done
                                    
                                    if [ $check_pos -lt $line_length ] && [ "${line:$check_pos:1}" = "," ]; then
                                        # Check what comes after comma
                                        local after_comma=$((check_pos+1))
                                        while [ $after_comma -lt $line_length ] && is_whitespace "${line:$after_comma:1}"; do
                                            ((after_comma++))
                                        done
                                        
                                        if [ $after_comma -lt $line_length ]; then
                                            local next_decl=$(get_token "$line" $after_comma)
                                            if [ "$next_decl" = "let" ] || [ "$next_decl" = "const" ] || [ "$next_decl" = "var" ]; then
                                                echo -e "${RED}Error at line $line_number, column $((after_comma+1)): Mixed declarations in single statement${NC}"
                                                echo "  $line"
                                                printf "%*s^%s\n" $after_comma "" "${RED}here${NC}"
                                                return 1
                                            fi
                                        fi
                                    fi
                                fi
                                
                                # Check scope for duplicate declaration
                                local scope_key="${current_scope}_${var_name}"
                                if [ -n "${declared_vars[$scope_key]}" ]; then
                                    if [ "$token" = "let" ] || [ "$token" = "const" ]; then
                                        echo -e "${RED}Error at line $line_number, column $((name_pos+1)): Identifier '$var_name' has already been declared${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $name_pos "" "${RED}here${NC}"
                                        return 1
                                    fi
                                else
                                    declared_vars["$scope_key"]="$token:$line_number"
                                fi
                                
                                last_declaration="$var_name"
                            fi
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
                                
                                # Check for function with reserved word as name
                                if [ "$fn_name" = "let" ] || [ "$fn_name" = "const" ] || [ "$fn_name" = "async" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((name_pos+1)): Cannot use reserved word '$fn_name' as function name${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $name_pos "" "${RED}here${NC}"
                                    return 1
                                fi
                                
                                # Enter function scope
                                in_function=true
                                function_name="$fn_name"
                                if $is_generator; then
                                    in_generator=true
                                fi
                                current_scope="function:$fn_name"
                                scope_level=$((scope_level + 1))
                                
                                # Store function declaration
                                declared_functions["${current_scope}_$fn_name"]="$line_number"
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
                                
                                # Check for constructor with async or generator
                                local check_pos=$((col+token_length))
                                while [ $check_pos -lt $line_length ] && is_whitespace "${line:$check_pos:1}"; do
                                    ((check_pos++))
                                done
                                
                                if [ $check_pos -lt $line_length ]; then
                                    local next_char="${line:$check_pos:1}"
                                    if [ "$next_char" = "*" ]; then
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
                                if [ "$next_token" = "defaultExport" ] || [ "$next_token" = "default" ]; then
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
                                fi
                            fi
                            ;;
                            
                        # Arrow function errors
                        '=>')
                            if ! $in_function && ! $in_arrow_function; then
                                echo -e "${RED}Error at line $line_number, column $((col+1)): Arrow function requires parentheses for destructuring${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                return 1
                            fi
                            ;;
                            
                        # Check for arrow function without parameters
                        '=')
                            local check_arrow=$col
                            while [ $check_arrow -gt 0 ] && is_whitespace "${line:$((check_arrow-1)):1}"; do
                                ((check_arrow--))
                            done
                            
                            if [ $check_arrow -gt 0 ] && [ "${line:$((check_arrow-1)):1}" = "=" ]; then
                                # Found == or ===, not arrow function
                                :
                            elif [ $((col+1)) -lt $line_length ] && [ "${line:$((col+1)):1}" = ">" ]; then
                                # Check what's before the =
                                local before_pos=$((col-1))
                                while [ $before_pos -ge 0 ] && is_whitespace "${line:$before_pos:1}"; do
                                    ((before_pos--))
                                done
                                
                                if [ $before_pos -lt 0 ] || [ "${line:$before_pos:1}" = "(" ] || [ "${line:$before_pos:1}" = "{" ] || [ "${line:$before_pos:1}" = "[" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col+1)): Arrow function requires parameters${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        # Rest operator check
                        '...')
                            # Check for incomplete rest parameter
                            local after_rest=$((col+token_length))
                            while [ $after_rest -lt $line_length ] && is_whitespace "${line:$after_rest:1}"; do
                                ((after_rest++))
                            done
                            
                            if [ $after_rest -ge $line_length ] || [ "${line:$after_rest:1}" = ")" ] || [ "${line:$after_rest:1}" = "]" ] || [ "${line:$after_rest:1}" = "}" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col+1)): Rest parameter must have a name${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                return 1
                            fi
                            
                            # Check if rest is not last in parameter list
                            local lookahead=$((col+token_length))
                            local bracket_count=0
                            local brace_count=0
                            local paren_count=0
                            
                            # Count brackets/braces/parens to find context
                            local i=0
                            while [ $i -lt $col ]; do
                                case "${line:$i:1}" in
                                    '[') ((bracket_count++)) ;;
                                    ']') ((bracket_count--)) ;;
                                    '{') ((brace_count++)) ;;
                                    '}') ((brace_count--)) ;;
                                    '(') ((paren_count++)) ;;
                                    ')') ((paren_count--)) ;;
                                esac
                                ((i++))
                            done
                            
                            if [ $bracket_count -gt 0 ] || [ $brace_count -gt 0 ] || [ $paren_count -gt 0 ]; then
                                # Look for comma after rest
                                while [ $lookahead -lt $line_length ]; do
                                    lookahead_char="${line:$lookahead:1}"
                                    if [ "$lookahead_char" = "," ]; then
                                        echo -e "${RED}Error at line $line_number, column $((col+1)): Rest element must be last element${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                        return 1
                                    elif [ "$lookahead_char" = "]" ] || [ "$lookahead_char" = "}" ] || [ "$lookahead_char" = ")" ]; then
                                        break
                                    fi
                                    ((lookahead++))
                                done
                            fi
                            ;;
                            
                        # Check for duplicate function parameters
                        '(')
                            if $in_function && [ "$function_name" != "" ]; then
                                # Check inside parentheses for duplicate parameters
                                local param_pos=$((col+1))
                                local params=""
                                local param_depth=0
                                
                                while [ $param_pos -lt $line_length ] && [ "${line:$param_pos:1}" != ")" ]; do
                                    local param_char="${line:$param_pos:1}"
                                    if [ "$param_char" = "(" ] || [ "$param_char" = "[" ] || [ "$param_char" = "{" ]; then
                                        ((param_depth++))
                                    elif [ "$param_char" = ")" ] || [ "$param_char" = "]" ] || [ "$param_char" = "}" ]; then
                                        ((param_depth--))
                                    fi
                                    
                                    if [ $param_depth -eq 0 ] && [ "$param_char" = "," ]; then
                                        params="$params|"
                                    elif [ $param_depth -eq 0 ] && ! is_whitespace "$param_char" && [ "$param_char" != "=" ] && [ "$param_char" != "." ]; then
                                        params="$params$param_char"
                                    fi
                                    ((param_pos++))
                                done
                                
                                # Check for duplicate simple parameter names
                                local IFS='|'
                                local -A seen_params
                                for param in $params; do
                                    # Clean up parameter name
                                    param=$(echo "$param" | tr -d ' ' | tr -d '\t' | tr -d '\n' | tr -d '\r')
                                    if [ -n "$param" ] && [ "${param:0:3}" != "..." ]; then
                                        if [ -n "${seen_params[$param]}" ]; then
                                            echo -e "${RED}Error at line $line_number, column $((col+1)): Duplicate parameter name '$param'${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                            return 1
                                        fi
                                        seen_params["$param"]=1
                                    fi
                                done
                            fi
                            ;;
                            
                        # Switch and case handling
                        'switch')
                            in_switch=true
                            ;;
                            
                        'case')
                            if $in_switch; then
                                in_case=true
                            fi
                            ;;
                            
                        # Check for "this" before super() in derived class constructor
                        'this')
                            if $in_class && $class_extends && $in_function && [ "$function_name" = "constructor" ]; then
                                # Check if super() has been called
                                local check_line_num=1
                                local super_called=false
                                
                                # Simple check: look for "super" in the constructor
                                while IFS= read -r check_line || [ -n "$check_line" ]; do
                                    if [ $check_line_num -eq $line_number ]; then
                                        # Check if super appears before this in current line
                                        local this_pos=$col
                                        local super_pos=$(echo "$check_line" | grep -b -o "super" | head -1 | cut -d: -f1)
                                        if [ -n "$super_pos" ] && [ $super_pos -lt $this_pos ]; then
                                            super_called=true
                                            break
                                        fi
                                    elif [ $check_line_num -gt $line_number ]; then
                                        break
                                    fi
                                    ((check_line_num++))
                                done < "$filename"
                                
                                if ! $super_called; then
                                    echo -e "${RED}Error at line $line_number, column $((col+1)): 'this' cannot be used before super() in derived class constructor${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        # Check for super() call in derived class
                        'super')
                            if $in_class && $class_extends && $in_function && [ "$function_name" = "constructor" ]; then
                                local after_super=$((col+token_length))
                                while [ $after_super -lt $line_length ] && is_whitespace "${line:$after_super:1}"; do
                                    ((after_super++))
                                done
                                
                                if [ $after_super -lt $line_length ] && [ "${line:$after_super:1}" != "(" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((after_super+1)): Missing parentheses for super call${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $after_super "" "${RED}here${NC}"
                                    return 1
                                fi
                            fi
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
        
        # Reset import/export flags at end of statement
        local trimmed_line=$(echo "$line" | sed 's/[[:space:]]*$//')
        if [[ "$trimmed_line" == *";" ]] || [[ "$trimmed_line" == *"}" ]] || [[ "$trimmed_line" == *"{" ]]; then
            in_import=false
            in_export=false
        fi
        
    done < "$filename"
    
    # Final checks
    if $in_comment_multi; then
        echo -e "${RED}Error: Unterminated multi-line comment${NC}"
        return 1
    fi
    
    if $in_string_single || $in_string_double || $in_template; then
        echo -e "${RED}Error: Unterminated string literal${NC}"
        return 1
    fi
    
    # Check if in derived class constructor without super()
    if $in_class && $class_extends && $in_function && [ "$function_name" = "constructor" ] && ! grep -q "super(" "$filename" 2>/dev/null; then
        echo -e "${RED}Error: Derived class constructor must call super()${NC}"
        return 1
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
