#!/bin/bash

# JavaScript Parameter Syntax Auditor - Pure Bash Implementation
# Usage: ./params.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="1.1.0"
TEST_DIR="params_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Reserved JavaScript keywords
RESERVED_WORDS="break case catch class const continue debugger default delete do else enum export extends false finally for function if import in instanceof new null return super switch this throw true try typeof var void while with yield let static implements interface package private protected public as async await get set from of"

# Strict mode reserved parameter names
STRICT_RESERVED_PARAMS="eval arguments"

# Function to display usage
show_usage() {
    echo -e "${BLUE}JavaScript Parameter Syntax Auditor v${AUDIT_SCRIPT_VERSION}${NC}"
    echo "Pure bash implementation - No Node.js required"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Audit a specific JavaScript file for parameter syntax errors"
    echo "  --test           Run test suite against known parameter error patterns"
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

# Function to check if character is valid for identifier
is_valid_id_char() {
    local char="$1"
    case "$char" in
        [a-zA-Z0-9_]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to check if character can start an identifier
is_valid_id_start() {
    local char="$1"
    case "$char" in
        [a-zA-Z_$]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to check if token is a valid parameter name
is_valid_param_name() {
    local token="$1"
    
    # Cannot be empty
    [ -z "$token" ] && return 1
    
    # Must start with letter, underscore, or dollar sign
    [[ ! "$token" =~ ^[a-zA-Z_$] ]] && return 1
    
    # Can only contain letters, numbers, underscore, and dollar sign
    [[ "$token" =~ [^a-zA-Z0-9_$] ]] && return 1
    
    return 0
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

# Function to get token at position
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
            ';'|','|'.'|'('|')'|'{'|'}'|'['|']'|':'|'?'|'~'|'@'|'#'|'`')
                token="$char"
                ((pos++))
                ;;
            # Operators that could be multi-character
            '+'|'-'|'*'|'/'|'%'|'&'|'|'|'^'|'!'|'='|'<'|'>')
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
            # Strings and template literals
            "'"|'"'|'`')
                token="$char"
                ((pos++))
                # Skip to end of string (simplified)
                while [ $pos -lt $length ] && [ "${line:$pos:1}" != "$char" ]; do
                    # Handle escapes
                    if [ "${line:$pos:1}" = "\\" ]; then
                        ((pos++))
                    fi
                    ((pos++))
                done
                if [ $pos -lt $length ]; then
                    ((pos++)) # Skip closing quote
                fi
                ;;
            # Identifiers and numbers
            *)
                if is_valid_id_start "$char"; then
                    while [ $pos -lt $length ] && (is_valid_id_char "${line:$pos:1}" || [ "${line:$pos:1}" = "$" ]); do
                        ((pos++))
                    done
                elif [[ "$char" =~ [0-9] ]]; then
                    while [ $pos -lt $length ] && ([[ "${line:$pos:1}" =~ [0-9] ]] || [ "${line:$pos:1}" = "." ] || [ "${line:$pos:1}" = "e" ] || [ "${line:$pos:1}" = "E" ]); do
                        ((pos++))
                    done
                elif [ "$char" = "-" ]; then
                    # Handle hyphen as potential identifier character (invalid)
                    token="$char"
                    ((pos++))
                else
                    # Unknown character
                    token="$char"
                    ((pos++))
                fi
                ;;
        esac
        
        token="${line:$start:$((pos-start))}"
    fi
    
    echo "$token"
}

# Function to check for missing commas between parameters
check_missing_comma() {
    local line="$1"
    local pos="$2"
    local length=${#line}
    
    # Skip current token
    local current_token=$(get_token "$line" $pos)
    local current_length=${#current_token}
    ((pos += current_length))
    
    # Skip whitespace
    while [ $pos -lt $length ] && is_whitespace "${line:$pos:1}"; do
        ((pos++))
    done
    
    if [ $pos -lt $length ]; then
        local next_char="${line:$pos:1}"
        if is_valid_id_start "$next_char" || [ "$next_char" = "{" ] || [ "$next_char" = "[" ] || [ "$next_char" = "." ] || [[ "$next_char" =~ [0-9] ]]; then
            # Found identifier/pattern without comma
            return 0
        fi
    fi
    
    return 1
}

# Function to check for destructuring pattern errors
check_destructure_pattern() {
    local line="$1"
    local start_pos="$2"
    local length=${#line}
    local pos=$start_pos
    local brace_count=0
    local bracket_count=0
    local in_pattern=false
    
    while [ $pos -lt $length ]; do
        local char="${line:$pos:1}"
        
        if [ "$char" = "{" ]; then
            ((brace_count++))
            in_pattern=true
        elif [ "$char" = "}" ]; then
            ((brace_count--))
        elif [ "$char" = "[" ]; then
            ((bracket_count++))
            in_pattern=true
        elif [ "$char" = "]" ]; then
            ((bracket_count--))
        elif [ "$char" = ")" ]; then
            if [ $brace_count -eq 0 ] && [ $bracket_count -eq 0 ]; then
                # End of parameter list
                break
            fi
        elif [ "$char" = "," ] && [ $brace_count -eq 0 ] && [ $bracket_count -eq 0 ]; then
            # End of parameter
            break
        elif $in_pattern && [ "$char" = "=" ] && [ $brace_count -eq 0 ] && [ $bracket_count -eq 0 ]; then
            # Default value assignment
            break
        fi
        
        # Check for missing comma in object destructuring
        if [ $brace_count -eq 1 ] && [ "$char" = " " ]; then
            local next_pos=$((pos+1))
            while [ $next_pos -lt $length ] && is_whitespace "${line:$next_pos:1}"; do
                ((next_pos++))
            done
            if [ $next_pos -lt $length ]; then
                local next_char="${line:$next_pos:1}"
                if is_valid_id_start "$next_char" || [ "$next_char" = "[" ] || [ "$next_char" = "." ]; then
                    # Missing comma between properties
                    echo "Missing comma in object destructuring"
                    return 1
                fi
            fi
        fi
        
        # Check for missing colon in object destructuring
        if [ $brace_count -eq 1 ] && [ "$char" = ":" ]; then
            local next_pos=$((pos+1))
            while [ $next_pos -lt $length ] && is_whitespace "${line:$next_pos:1}"; do
                ((next_pos++))
            done
            if [ $next_pos -lt $length ]; then
                local next_char="${line:$next_pos:1}"
                if [ "$next_char" = "}" ] || [ "$next_char" = "," ]; then
                    # Missing property name after colon
                    echo "Missing property name after colon"
                    return 1
                fi
            fi
        fi
        
        # Check for empty rest in object destructuring
        if [ $brace_count -eq 1 ] && [ "$char" = "." ]; then
            if [ $((pos+2)) -lt $length ] && [ "${line:$pos:3}" = "..." ]; then
                local next_pos=$((pos+3))
                while [ $next_pos -lt $length ] && is_whitespace "${line:$next_pos:1}"; do
                    ((next_pos++))
                done
                if [ $next_pos -lt $length ] && [ "${line:$next_pos:1}" = "}" ]; then
                    # Empty rest in object destructuring
                    echo "Empty rest in object destructuring"
                    return 1
                fi
            fi
        fi
        
        ((pos++))
    done
    
    return 0
}

# Function to check for parameter syntax errors in JavaScript code
check_param_syntax() {
    local filename="$1"
    local line_number=0
    local in_comment_single=false
    local in_comment_multi=false
    local in_string_single=false
    local in_string_double=false
    local in_template=false
    local in_regex=false
    
    # Parameter parsing state
    local in_function_decl=false
    local in_arrow_params=false
    local in_method_decl=false
    local in_constructor_decl=false
    local in_generator_decl=false
    local in_async_decl=false
    local in_getter_setter=false
    local getter_setter_type="" # "get" or "set"
    
    # Parameter list state
    local in_param_list=false
    local paren_depth=0
    local param_list_start_line=0
    local param_list_start_col=0
    local expecting_param=false
    local expecting_comma=false
    local param_count=0
    local last_param_name=""
    local param_names=()
    local has_rest_param=false
    local has_default_param=false
    local in_default_expr=false
    local default_expr_depth=0
    local in_destructuring=false
    local destructure_depth=0
    local in_object_destructure=false
    local in_array_destructure=false
    local destructure_start_line=0
    local destructure_start_col=0
    
    # Context tracking
    local in_strict_mode=false
    local in_class=false
    local brace_count=0
    local current_function_type="" # "function", "arrow", "method", "constructor", "generator", "async"
    
    # Read file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_number++))
        local col=0
        local line_length=${#line}
        
        # Check for strict mode directive
        if [[ "$line" =~ ^[' ''\t']*\"use\ +strict\" ]]; then
            in_strict_mode=true
        fi
        
        # Process each character
        while [ $col -lt $line_length ]; do
            local char="${line:$col:1}"
            local next_char=""
            [ $((col+1)) -lt $line_length ] && next_char="${line:$((col+1)):1}"
            
            # Check for string/comment/regex contexts
            if ! $in_comment_single && ! $in_comment_multi; then
                # Check for string/template literal start
                if [ "$char" = "'" ] && ! $in_string_double && ! $in_template && ! $in_regex; then
                    if $in_string_single; then
                        in_string_single=false
                    else
                        in_string_single=true
                    fi
                elif [ "$char" = '"' ] && ! $in_string_single && ! $in_template && ! $in_regex; then
                    if $in_string_double; then
                        in_string_double=false
                    else
                        in_string_double=true
                    fi
                elif [ "$char" = '`' ] && ! $in_string_single && ! $in_string_double && ! $in_regex; then
                    if $in_template; then
                        in_template=false
                    else
                        in_template=true
                    fi
                elif [ "$char" = '/' ] && ! $in_string_single && ! $in_string_double && ! $in_template; then
                    # Could be division, comment, or regex
                    if [ "$next_char" = '/' ]; then
                        in_comment_single=true
                        ((col++))
                    elif [ "$next_char" = '*' ]; then
                        in_comment_multi=true
                        ((col++))
                    elif ! $in_regex; then
                        # Check if this could be a regex
                        local is_regex=true
                        
                        # Look back to see what precedes this
                        if [ $col -gt 0 ]; then
                            local prev_char="${line:$((col-1)):1}"
                            case "$prev_char" in
                                ')'|']'|'}'|'a'|'b'|'c'|'d'|'e'|'f'|'g'|'h'|'i'|'j'|'k'|'l'|'m'|'n'|'o'|'p'|'q'|'r'|'s'|'t'|'u'|'v'|'w'|'x'|'y'|'z'|'A'|'B'|'C'|'D'|'E'|'F'|'G'|'H'|'I'|'J'|'K'|'L'|'M'|'N'|'O'|'P'|'Q'|'R'|'S'|'T'|'U'|'V'|'W'|'X'|'Y'|'Z'|'_'|'$'|'0'|'1'|'2'|'3'|'4'|'5'|'6'|'7'|'8'|'9')
                                    is_regex=false
                                    ;;
                            esac
                        fi
                        
                        if $is_regex; then
                            in_regex=true
                        fi
                    fi
                fi
            fi
            
            # Inside multi-line comment
            if $in_comment_multi && [ "$char" = '*' ] && [ "$next_char" = '/' ]; then
                in_comment_multi=false
                ((col++))
            fi
            
            # Inside regex - look for closing slash
            if $in_regex && [ "$char" = '/' ]; then
                # Check if slash isn't escaped
                local is_escaped=false
                local check_col=$((col-1))
                while [ $check_col -ge 0 ] && [ "${line:$check_col:1}" = "\\" ]; do
                    is_escaped=$(! $is_escaped)
                    ((check_col--))
                done
                if ! $is_escaped; then
                    in_regex=false
                fi
            fi
            
            # Only check syntax if not inside string/comment/regex
            if ! $in_string_single && ! $in_string_double && ! $in_template && ! $in_comment_single && ! $in_comment_multi && ! $in_regex; then
                # Get current token
                local token
                token_length=0
                token=$(get_token "$line" $col)
                token_length=${#token}
                
                if [ -n "$token" ] && [ "$token_length" -gt 0 ]; then
                    # Update column position
                    ((col += token_length - 1))
                    
                    # Check for function declarations
                    if [ "$token" = "function" ] && ! $in_function_decl && ! $in_method_decl && ! $in_constructor_decl; then
                        in_function_decl=true
                        current_function_type="function"
                        # Check for generator
                        if [ $col -lt $line_length ] && [ "${line:$col:1}" = "*" ]; then
                            in_generator_decl=true
                            current_function_type="generator"
                        fi
                    fi
                    
                    # Check for async keyword
                    if [ "$token" = "async" ] && ! $in_async_decl && ! $in_function_decl && ! $in_method_decl && ! $in_constructor_decl; then
                        in_async_decl=true
                        current_function_type="async"
                    fi
                    
                    # Check for class keyword
                    if [ "$token" = "class" ]; then
                        in_class=true
                    fi
                    
                    # Check for get/set in object/class context
                    if [ "$token" = "get" ] || [ "$token" = "set" ]; then
                        # Check if this is actually a getter/setter (followed by identifier and parentheses)
                        local lookahead_col=$((col+1))
                        local found_id=false
                        local found_paren=false
                        
                        # Skip whitespace
                        while [ $lookahead_col -lt $line_length ] && is_whitespace "${line:$lookahead_col:1}"; do
                            ((lookahead_col++))
                        done
                        
                        # Check for identifier
                        if [ $lookahead_col -lt $line_length ] && is_valid_id_start "${line:$lookahead_col:1}"; then
                            found_id=true
                            # Get the identifier
                            local id_token=$(get_token "$line" $lookahead_col)
                            ((lookahead_col += ${#id_token}))
                            
                            # Skip whitespace after identifier
                            while [ $lookahead_col -lt $line_length ] && is_whitespace "${line:$lookahead_col:1}"; do
                                ((lookahead_col++))
                            done
                            
                            # Check for '('
                            if [ $lookahead_col -lt $line_length ] && [ "${line:$lookahead_col:1}" = "(" ]; then
                                found_paren=true
                            fi
                        fi
                        
                        if $found_id && $found_paren; then
                            in_getter_setter=true
                            getter_setter_type="$token"
                        fi
                    fi
                    
                    # Check for constructor in class
                    if [ "$token" = "constructor" ] && $in_class; then
                        in_constructor_decl=true
                        current_function_type="constructor"
                    fi
                    
                    # Check for method declarations in class
                    if $in_class && ! $in_function_decl && ! $in_constructor_decl && ! $in_getter_setter && \
                       [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && [ $col -lt $line_length ] && [ "${line:$col:1}" = "(" ]; then
                        in_method_decl=true
                        current_function_type="method"
                    fi
                    
                    # Check for arrow functions
                    if [ "$token" = "=>" ] && ! $in_arrow_params; then
                        # Arrow function detected, we should be in parameter list
                        if $in_param_list; then
                            in_arrow_params=true
                            current_function_type="arrow"
                        else
                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Arrow function requires parentheses for parameter list${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                    fi
                    
                    # Handle parentheses for parameter lists
                    if [ "$token" = "(" ]; then
                        ((paren_depth++))
                        
                        # Check if this is the start of a parameter list
                        if ($in_function_decl || $in_method_decl || $in_constructor_decl || $in_generator_decl || $in_async_decl || $in_getter_setter) && [ $paren_depth -eq 1 ]; then
                            in_param_list=true
                            param_list_start_line=$line_number
                            param_list_start_col=$col
                            expecting_param=true
                            expecting_comma=false
                            param_count=0
                            param_names=()
                            has_rest_param=false
                            has_default_param=false
                            in_default_expr=false
                            default_expr_depth=0
                            in_destructuring=false
                            destructure_depth=0
                            in_object_destructure=false
                            in_array_destructure=false
                        fi
                    fi
                    
                    if [ "$token" = ")" ]; then
                        ((paren_depth--))
                        
                        # Check if we're exiting a parameter list
                        if $in_param_list && [ $paren_depth -eq 0 ]; then
                            # Validate parameter list ending
                            if $expecting_param && [ $param_count -eq 0 ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected end of parameter list${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check for getter/setter parameter requirements
                            if $in_getter_setter; then
                                if [ "$getter_setter_type" = "get" ] && [ $param_count -gt 0 ]; then
                                    echo -e "${RED}Error at line $param_list_start_line, column $((param_list_start_col+1)): Getter must not have any formal parameters${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                if [ "$getter_setter_type" = "set" ] && [ $param_count -ne 1 ]; then
                                    echo -e "${RED}Error at line $param_list_start_line, column $((param_list_start_col+1)): Setter must have exactly one parameter${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            
                            in_param_list=false
                            expecting_param=false
                            expecting_comma=false
                        fi
                    fi
                    
                    # Inside parameter list checks
                    if $in_param_list; then
                        case "$token" in
                            # Check for unexpected semicolon in parameter list
                            ';')
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected semicolon in parameter list${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                                ;;
                            
                            # Check for comma errors
                            ',')
                                if $expecting_comma || [ $param_count -eq 0 ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected comma in parameter list${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                expecting_param=true
                                expecting_comma=false
                                has_default_param=false
                                ;;
                            
                            # Check for rest parameter syntax
                            '...')
                                if $has_rest_param; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Multiple rest parameters not allowed${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                if ! $expecting_param; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Rest parameter must come after regular parameters${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                has_rest_param=true
                                expecting_param=false
                                ;;
                            
                            # Check for default parameter assignment
                            '=')
                                if $expecting_comma || ! $expecting_param; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected assignment in parameter list${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                in_default_expr=true
                                default_expr_depth=$paren_depth
                                has_default_param=true
                                ;;
                            
                            # Check for destructuring patterns
                            '{')
                                if $expecting_param; then
                                    in_destructuring=true
                                    in_object_destructure=true
                                    destructure_depth=$paren_depth
                                    destructure_start_line=$line_number
                                    destructure_start_col=$col
                                    
                                    # Check destructuring pattern for errors
                                    local destructure_error=$(check_destructure_pattern "$line" $col)
                                    if [ -n "$destructure_error" ]; then
                                        echo -e "${RED}Error at line $line_number, column $((col+1)): $destructure_error${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                fi
                                ;;
                            
                            '[')
                                if $expecting_param; then
                                    in_destructuring=true
                                    in_array_destructure=true
                                    destructure_depth=$paren_depth
                                    destructure_start_line=$line_number
                                    destructure_start_col=$col
                                fi
                                ;;
                            
                            # Check for closing destructuring patterns
                            '}')
                                if $in_destructuring && $in_object_destructure && [ $paren_depth -eq $destructure_depth ]; then
                                    in_destructuring=false
                                    in_object_destructure=false
                                    expecting_param=false
                                    expecting_comma=true
                                    ((param_count++))
                                fi
                                ;;
                            
                            ']')
                                if $in_destructuring && $in_array_destructure && [ $paren_depth -eq $destructure_depth ]; then
                                    in_destructuring=false
                                    in_array_destructure=false
                                    expecting_param=false
                                    expecting_comma=true
                                    ((param_count++))
                                fi
                                ;;
                            
                            # Check for colon in object destructuring
                            ':')
                                if $in_destructuring && $in_object_destructure; then
                                    # This is valid in object destructuring
                                    :
                                elif $in_param_list && ! $in_destructuring; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected colon in parameter list${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                ;;
                            
                            # Handle identifiers (parameter names)
                            *)
                                if $expecting_param && ! $in_default_expr; then
                                    # Check for invalid parameter names with hyphen
                                    if [[ "$token" =~ - ]]; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Parameter name '$token' contains invalid character '-'${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                    
                                    # Check for invalid parameter names starting with number
                                    if [[ "$token" =~ ^[0-9] ]]; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Parameter name cannot start with a number${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                    
                                    # Check if it's a valid identifier
                                    if is_valid_param_name "$token"; then
                                        # Check for reserved words as parameters
                                        if is_reserved_word "$token"; then
                                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Reserved word '$token' cannot be used as parameter name${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                            echo "$(realpath "$filename")"
                                            return 1
                                        fi
                                        
                                        # Check for strict mode restrictions
                                        if $in_strict_mode; then
                                            for reserved in $STRICT_RESERVED_PARAMS; do
                                                if [ "$token" = "$reserved" ]; then
                                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Parameter name '$token' not allowed in strict mode${NC}"
                                                    echo "  $line"
                                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                                    echo "$(realpath "$filename")"
                                                    return 1
                                                fi
                                            done
                                        fi
                                        
                                        # Check for duplicate parameter names
                                        for existing_param in "${param_names[@]}"; do
                                            if [ "$token" = "$existing_param" ]; then
                                                if $in_strict_mode || $in_arrow_params; then
                                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Duplicate parameter name '$token'${NC}"
                                                    echo "  $line"
                                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                                    echo "$(realpath "$filename")"
                                                    return 1
                                                fi
                                            fi
                                        done
                                        
                                        # Add parameter to list
                                        param_names+=("$token")
                                        last_param_name="$token"
                                        expecting_param=false
                                        expecting_comma=true
                                        ((param_count++))
                                        
                                        # Check for missing comma between parameters
                                        if check_missing_comma "$line" $col; then
                                            echo -e "${RED}Error at line $line_number, column $((col+1)): Missing comma between parameters${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $((col+1)) "" "${RED}here${NC}"
                                            echo "$(realpath "$filename")"
                                            return 1
                                        fi
                                    elif [ "$token" != "=" ] && [ "$token" != "..." ] && [ "$token" != "{" ] && [ "$token" != "[" ]; then
                                        # Not a valid parameter name or special token
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid parameter name '$token'${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                elif $in_default_expr && [ $paren_depth -eq $default_expr_depth ]; then
                                    # We might be ending a default expression
                                    if [ "$token" = "," ] || [ "$token" = ")" ]; then
                                        in_default_expr=false
                                    fi
                                fi
                                ;;
                        esac
                    fi
                    
                    # Check for function body start
                    if [ "$token" = "{" ] && ($in_function_decl || $in_method_decl || $in_constructor_decl || $in_generator_decl || $in_async_decl || $in_getter_setter || $in_arrow_params); then
                        # Reset function declaration states
                        in_function_decl=false
                        in_method_decl=false
                        in_constructor_decl=false
                        in_generator_decl=false
                        in_async_decl=false
                        in_getter_setter=false
                        in_arrow_params=false
                        current_function_type=""
                    fi
                    
                    # Check for missing parentheses after function name
                    if ($in_function_decl || $in_method_decl || $in_constructor_decl || $in_generator_decl || $in_async_decl) && \
                       [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && [ "$last_param_name" = "" ] && [ "$token" != "function" ]; then
                        # Function name found, next should be '('
                        local lookahead_col=$((col+1))
                        local found_paren=false
                        while [ $lookahead_col -lt $line_length ]; do
                            local next_tok_char="${line:$lookahead_col:1}"
                            if is_whitespace "$next_tok_char"; then
                                ((lookahead_col++))
                                continue
                            fi
                            if [ "$next_tok_char" = "(" ]; then
                                found_paren=true
                                break
                            elif [ "$next_tok_char" = "{" ] || [ "$next_tok_char" = ";" ]; then
                                break
                            fi
                            ((lookahead_col++))
                        done
                        if ! $found_paren; then
                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing parentheses after function name${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                    fi
                    
                    # Update last parameter name for tracking
                    if [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && $in_param_list && ! $in_default_expr; then
                        last_param_name="$token"
                    fi
                fi
            fi
            
            ((col++))
        done
        
        # Reset for new line
        if $in_comment_single; then
            in_comment_single=false
        fi
        
        # Check if we're still in a parameter list at end of line
        if $in_param_list && $expecting_param && [ $param_count -eq 0 ]; then
            echo -e "${RED}Error at line $line_number: Unterminated parameter list${NC}"
            echo "$(realpath "$filename")"
            return 1
        fi
        
    done < "$filename"
    
    # Check for unterminated constructs
    if $in_string_single; then
        echo -e "${RED}Error: Unterminated single-quoted string${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    if $in_string_double; then
        echo -e "${RED}Error: Unterminated double-quoted string${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    if $in_template; then
        echo -e "${RED}Error: Unterminated template literal${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    if $in_comment_multi; then
        echo -e "${RED}Error: Unterminated multi-line comment${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    if $in_regex; then
        echo -e "${RED}Error: Unterminated regular expression${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    # Check for unterminated parameter list
    if $in_param_list; then
        echo -e "${RED}Error: Unterminated parameter list${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    return 0
}

# Function to audit a single JavaScript file for parameter syntax errors
audit_js_file() {
    local filename="$1"
    
    if [ ! -f "$filename" ]; then
        echo -e "${RED}Error: File '$filename' not found${NC}"
        return 1
    fi
    
    if [[ ! "$filename" =~ \.js$ ]]; then
        echo -e "${YELLOW}Warning: File '$filename' doesn't have .js extension${NC}"
    fi
    
    echo -e "${CYAN}Auditing parameter syntax:${NC} ${filename}"
    echo "========================================"
    
    # Check file size
    local file_size=$(wc -c < "$filename")
    if [ $file_size -eq 0 ]; then
        echo -e "${GREEN}✓ Empty file - no errors${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    fi
    
    # Run our parameter syntax checker
    if check_param_syntax "$filename"; then
        echo -e "${GREEN}✓ No parameter syntax errors found${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running JavaScript Parameter Syntax Error Test Suite${NC}"
    echo "========================================"
    
    # Check if test directory exists, if not run tests.sh to generate it
    if [ ! -d "$TEST_DIR" ]; then
        echo -e "${YELLOW}Test directory '$TEST_DIR' not found.${NC}"
        echo -e "${CYAN}Attempting to generate test directory with tests.sh...${NC}"
        
        # Check if tests.sh exists in the current directory
        if [ -f "tests.sh" ]; then
            echo -e "${CYAN}Running tests.sh to generate test files...${NC}"
            bash tests.sh
            
            # Check again if test directory was created
            if [ -d "$TEST_DIR" ]; then
                echo -e "${GREEN}Test directory successfully generated!${NC}"
            else
                echo -e "${RED}Failed to generate test directory. Please create test files manually.${NC}"
                echo -e "${YELLOW}Expected directory: '$TEST_DIR/'${NC}"
                return 1
            fi
        else
            echo -e "${RED}tests.sh not found in current directory.${NC}"
            echo -e "${YELLOW}Please ensure tests.sh exists in $(pwd)${NC}"
            echo -e "${YELLOW}or create test files manually in '$TEST_DIR/' directory.${NC}"
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
        if audit_js_file "$test_file" 2>/dev/null; then
            echo -e "${RED}  ✗ Expected to fail but passed${NC}"
            ((failed_tests++))
        else
            echo -e "${GREEN}  ✓ Correctly detected error${NC}"
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
        echo -e "${YELLOW}Consider running 'bash tests.sh' manually to regenerate test files.${NC}"
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
        run_tests
        exit $?
    fi
    
    # Check if filename is provided
    if [ $# -eq 0 ]; then
        echo -e "${RED}Error: No filename provided${NC}"
        show_usage
        exit 1
    fi
    
    # Audit single file
    audit_js_file "$1"
    exit $?
}

# Run main function
main "$@"
