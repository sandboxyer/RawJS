#!/bin/bash

# JavaScript Destructuring Syntax Error Auditor
# Usage: ./destructuring.sh <filename.js> [--test]

DESTRUCT_SCRIPT_VERSION="1.0.0"
TEST_DIR="destructuring_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Reserved JavaScript keywords
RESERVED_WORDS="break case catch class const continue debugger default delete do else enum export extends false finally for function if import in instanceof new null return super switch this throw true try typeof var void while with yield let static implements interface package private protected public as async await get set from of"

# Function to display usage
show_usage() {
    echo -e "${BLUE}JavaScript Destructuring Syntax Error Auditor v${DESTRUCT_SCRIPT_VERSION}${NC}"
    echo "Detects destructuring-specific syntax errors"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Audit a specific JavaScript file for destructuring errors"
    echo "  --test           Run test suite against known destructuring error patterns"
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

# Function to check if character is valid for variable name (not first char)
is_valid_var_char() {
    local char="$1"
    case "$char" in
        [a-zA-Z0-9_]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to check if character can start a variable name
is_valid_var_start() {
    local char="$1"
    case "$char" in
        [a-zA-Z_$]) return 0 ;;
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

# Function to check if character is valid for destructuring pattern
is_pattern_char() {
    local char="$1"
    case "$char" in
        [a-zA-Z0-9_$:,=.[\]{}]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to get token at position (destructuring-aware)
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
            # Destructuring-specific patterns
            '{'|'}'|'['|']'|':'|','|'='|'.'|'('|')')
                token="$char"
                ((pos++))
                ;;
            # Rest/spread operator
            '.')
                if [ $((pos+2)) -lt $length ] && [ "${line:$pos:3}" = "..." ]; then
                    token="..."
                    ((pos+=3))
                else
                    token="$char"
                    ((pos++))
                fi
                ;;
            # Strings and template literals
            "'"|'"')
                token="$char"
                ((pos++))
                # Skip to end of string
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
            '`')
                token="$char"
                ((pos++))
                while [ $pos -lt $length ] && [ "${line:$pos:1}" != '`' ]; do
                    if [ "${line:$pos:1}" = "\\" ]; then
                        ((pos++))
                    fi
                    ((pos++))
                done
                if [ $pos -lt $length ]; then
                    ((pos++))
                fi
                ;;
            # Comments
            '/')
                if [ $((pos+1)) -lt $length ]; then
                    if [ "${line:$((pos+1)):1}" = "/" ]; then
                        # Line comment - skip to end of line
                        pos=$length
                    elif [ "${line:$((pos+1)):1}" = "*" ]; then
                        # Block comment
                        ((pos+=2))
                        while [ $pos -lt $length ] && ! ([ "${line:$pos:1}" = "*" ] && [ "${line:$((pos+1)):1}" = "/" ]); do
                            ((pos++))
                        done
                        ((pos+=2))
                    else
                        token="$char"
                        ((pos++))
                    fi
                else
                    token="$char"
                    ((pos++))
                fi
                ;;
            # Identifiers
            *)
                if is_valid_var_start "$char"; then
                    while [ $pos -lt $length ] && (is_valid_var_char "${line:$pos:1}" || [ "${line:$pos:1}" = "$" ]); do
                        ((pos++))
                    done
                elif [[ "$char" =~ [0-9] ]]; then
                    while [ $pos -lt $length ] && [[ "${line:$pos:1}" =~ [0-9] ]]; do
                        ((pos++))
                    done
                elif [ "$char" = "[" ]; then
                    # Computed property
                    token="["
                    ((pos++))
                    return 0
                fi
                ;;
        esac
        
        token="${line:$start:$((pos-start))}"
    fi
    
    echo "$token"
}

# Function to check destructuring-specific syntax errors
check_destructuring_syntax() {
    local filename="$1"
    local line_number=0
    local in_comment_single=false
    local in_comment_multi=false
    local in_string_single=false
    local in_string_double=false
    local in_template=false
    local in_regex=false
    local in_destructuring=false
    local destructuring_depth=0
    local in_array_pattern=false
    local array_pattern_depth=0
    local in_object_pattern=false
    local object_pattern_depth=0
    local expecting_identifier=false
    local expecting_colon=false
    local expecting_comma_or_close=false
    local last_token=""
    local last_non_ws_token=""
    local in_assignment_context=false
    local in_declaration_context=false
    local declaration_type="" # "const", "let", "var"
    local in_function_param=false
    local in_arrow_param=false
    local in_for_of_loop=false
    local paren_count=0
    local bracket_count=0
    local brace_count=0
    local last_destructuring_token=""
    local has_rest_operator=false
    local rest_position=-1
    local has_seen_comma_in_pattern=false
    local has_seen_colon_in_pattern=false
    local has_seen_default_in_pattern=false
    
    # Read file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_number++))
        local col=0
        local line_length=${#line}
        
        # Process each character
        while [ $col -lt $line_length ]; do
            local char="${line:$col:1}"
            local next_char=""
            [ $((col+1)) -lt $line_length ] && next_char="${line:$((col+1)):1}"
            
            # Check for string/comment contexts
            if ! $in_comment_single && ! $in_comment_multi; then
                if [ "$char" = "'" ] && ! $in_string_double && ! $in_template && ! $in_regex; then
                    $in_string_single && in_string_single=false || in_string_single=true
                elif [ "$char" = '"' ] && ! $in_string_single && ! $in_template && ! $in_regex; then
                    $in_string_double && in_string_double=false || in_string_double=true
                elif [ "$char" = '`' ] && ! $in_string_single && ! $in_string_double && ! $in_regex; then
                    $in_template && in_template=false || in_template=true
                elif [ "$char" = '/' ] && ! $in_string_single && ! $in_string_double && ! $in_template; then
                    if [ "$next_char" = "/" ]; then
                        in_comment_single=true
                        ((col++))
                    elif [ "$next_char" = "*" ]; then
                        in_comment_multi=true
                        ((col++))
                    fi
                fi
            fi
            
            # Inside multi-line comment
            if $in_comment_multi && [ "$char" = '*' ] && [ "$next_char" = '/' ]; then
                in_comment_multi=false
                ((col++))
            fi
            
            # Only check syntax if not inside string/comment/regex
            if ! $in_string_single && ! $in_string_double && ! $in_template && ! $in_comment_single && ! $in_comment_multi && ! $in_regex; then
                # Get current token
                local token
                token=$(get_token "$line" $col)
                local token_length=${#token}
                
                if [ -n "$token" ] && [ "$token_length" -gt 0 ]; then
                    # Update column position
                    ((col += token_length - 1))
                    
                    # Check for destructuring context
                    if [ "$token" = "const" ] || [ "$token" = "let" ] || [ "$token" = "var" ]; then
                        in_declaration_context=true
                        declaration_type="$token"
                        expecting_identifier=true
                    elif [ "$token" = "=" ] && ($in_declaration_context || $in_assignment_context); then
                        # Check what's on the left side of =
                        if [ "$last_non_ws_token" = "{" ] || [ "$last_non_ws_token" = "[" ]; then
                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Empty destructuring pattern${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                    elif ([ "$token" = "{" ] || [ "$token" = "[" ]) && ($expecting_identifier || $in_assignment_context || $in_function_param || $in_arrow_param); then
                        in_destructuring=true
                        if [ "$token" = "{" ]; then
                            in_object_pattern=true
                            ((object_pattern_depth++))
                            expecting_identifier=true
                            expecting_comma_or_close=false
                            has_seen_comma_in_pattern=false
                            has_seen_colon_in_pattern=false
                            has_seen_default_in_pattern=false
                        elif [ "$token" = "[" ]; then
                            in_array_pattern=true
                            ((array_pattern_depth++))
                            expecting_identifier=true
                            expecting_comma_or_close=false
                            has_seen_comma_in_pattern=false
                        fi
                        has_rest_operator=false
                        rest_position=-1
                    elif [ "$token" = "}" ] && $in_object_pattern; then
                        ((object_pattern_depth--))
                        if [ $object_pattern_depth -eq 0 ]; then
                            in_object_pattern=false
                        fi
                        expecting_identifier=false
                        expecting_colon=false
                        expecting_comma_or_close=false
                    elif [ "$token" = "]" ] && $in_array_pattern; then
                        ((array_pattern_depth--))
                        if [ $array_pattern_depth -eq 0 ]; then
                            in_array_pattern=false
                        fi
                        expecting_identifier=false
                        expecting_comma_or_close=false
                    elif $in_destructuring; then
                        # Check destructuring-specific errors
                        case "$token" in
                            # Check for empty patterns
                            '='|'{'|'[')
                                if [ "$token" = "=" ] && [ "$last_non_ws_token" = "{" ] || [ "$last_non_ws_token" = "[" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Empty destructuring pattern${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                ;;
                                
                            # Check for double commas in object patterns
                            ',')
                                if $in_object_pattern; then
                                    if [ "$last_non_ws_token" = "," ] || [ "$last_non_ws_token" = "{" ] || [ "$last_non_ws_token" = ":" ]; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected comma in object pattern${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                    has_seen_comma_in_pattern=true
                                elif $in_array_pattern; then
                                    if [ "$last_non_ws_token" = "," ] && [ "$last_destructuring_token" != "]" ]; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Multiple consecutive commas in array pattern${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                fi
                                expecting_identifier=true
                                expecting_colon=false
                                expecting_comma_or_close=false
                                ;;
                                
                            # Check for colon errors
                            ':')
                                if $in_object_pattern; then
                                    if $expecting_colon; then
                                        expecting_colon=false
                                        expecting_identifier=true # Expect alias after colon
                                        has_seen_colon_in_pattern=true
                                    else
                                        if [ "$last_non_ws_token" = "," ] || [ "$last_non_ws_token" = "{" ] || [ "$last_non_ws_token" = ":" ]; then
                                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected colon${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                            echo "$(realpath "$filename")"
                                            return 1
                                        fi
                                    fi
                                else
                                    # Colon not allowed in array patterns
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Colon not allowed in array destructuring${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                ;;
                                
                            # Check for rest operator errors
                            '...')
                                if $in_array_pattern || $in_object_pattern; then
                                    has_rest_operator=true
                                    rest_position=$col
                                    # Rest operator must be followed by identifier
                                    expecting_identifier=true
                                    
                                    # Check if rest operator is in middle of pattern
                                    local lookahead_col=$((col+1))
                                    local found_comma_after_rest=false
                                    while [ $lookahead_col -lt $line_length ]; do
                                        local lookahead_char="${line:$lookahead_col:1}"
                                        if is_whitespace "$lookahead_char"; then
                                            ((lookahead_col++))
                                            continue
                                        fi
                                        if [ "$lookahead_char" = "," ]; then
                                            found_comma_after_rest=true
                                            break
                                        fi
                                        if [ "$lookahead_char" = "]" ] || [ "$lookahead_char" = "}" ]; then
                                            break
                                        fi
                                        ((lookahead_col++))
                                    done
                                    
                                    if $found_comma_after_rest; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Rest element must be last in destructuring pattern${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                fi
                                ;;
                                
                            # Check for default value errors
                            '=')
                                if $in_array_pattern || $in_object_pattern; then
                                    has_seen_default_in_pattern=true
                                    # Check what's before the equals
                                    if [ "$last_non_ws_token" = "," ] || [ "$last_non_ws_token" = "{" ] || [ "$last_non_ws_token" = "[" ] || [ "$last_non_ws_token" = ":" ]; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid default value assignment${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                    
                                    # Check for double equals
                                    if [ "$last_token" = "=" ]; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Double equals in default value${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                    
                                    # Check if default is after rest operator
                                    if $has_rest_operator; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Rest operator cannot have default value${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                fi
                                ;;
                                
                            # Check for invalid property names
                            *)
                                # Check if token is a number (invalid as property name in object pattern)
                                if [[ "$token" =~ ^[0-9]+$ ]] && $in_object_pattern && ! $expecting_colon; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Numbers cannot be property names in object patterns${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                
                                # Check if token is a boolean/null (invalid as property name)
                                if [ "$token" = "true" ] || [ "$token" = "false" ] || [ "$token" = "null" ]; then
                                    if $in_object_pattern && ! $expecting_colon; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Boolean/null cannot be property names in object patterns${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                fi
                                
                                # Check for string literals as aliases
                                if [[ "$token" =~ ^[\"\'].*[\"\']$ ]] && $in_object_pattern && $expecting_colon; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): String literal cannot be used as alias in object pattern${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                
                                # Check for get/set as property names
                                if ([ "$token" = "get" ] || [ "$token" = "set" ]) && $in_object_pattern && ! $expecting_colon; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'get'/'set' cannot be property names in object patterns${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                
                                # Update expecting flags based on token
                                if [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                    if $in_object_pattern; then
                                        if $expecting_identifier && ! $expecting_colon; then
                                            # This is a property name
                                            expecting_colon=true
                                            expecting_identifier=false
                                        elif $expecting_colon; then
                                            # This is an alias
                                            expecting_colon=false
                                            expecting_comma_or_close=true
                                        fi
                                    elif $in_array_pattern; then
                                        expecting_comma_or_close=true
                                    fi
                                fi
                                ;;
                        esac
                        
                        # Save last destructuring token
                        last_destructuring_token="$token"
                    fi
                    
                    # Check for specific destructuring contexts
                    case "$token" in
                        # Function parameters
                        'function')
                            in_function_param=true
                            ;;
                        '(')
                            ((paren_count++))
                            if $in_function_param || [ "$last_non_ws_token" = "=>" ]; then
                                in_function_param=true
                            fi
                            ;;
                        ')')
                            ((paren_count--))
                            if $paren_count -eq 0; then
                                in_function_param=false
                            fi
                            ;;
                        '=>')
                            in_arrow_param=false
                            ;;
                        'for')
                            in_for_of_loop=true
                            ;;
                        'of')
                            if $in_for_of_loop; then
                                # Check left side of 'of' for destructuring
                                local lookback_col=$((col-token_length-1))
                                local found_bracket_or_brace=false
                                while [ $lookback_col -ge 0 ]; do
                                    local lookback_char="${line:$lookback_col:1}"
                                    if is_whitespace "$lookback_char"; then
                                        ((lookback_col--))
                                        continue
                                    fi
                                    if [ "$lookback_char" = "]" ] || [ "$lookback_char" = "}" ]; then
                                        found_bracket_or_brace=true
                                        break
                                    fi
                                    break
                                done
                                
                                if ! $found_bracket_or_brace; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid left-hand side in for-of loop${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                        'catch')
                            # Check for multiple parameters in catch
                            local lookahead_col=$((col+1))
                            local paren_depth=0
                            local comma_count=0
                            while [ $lookahead_col -lt $line_length ]; do
                                local lookahead_char="${line:$lookahead_col:1}"
                                if [ "$lookahead_char" = "(" ]; then
                                    ((paren_depth++))
                                elif [ "$lookahead_char" = ")" ]; then
                                    ((paren_depth--))
                                    if [ $paren_depth -eq 0 ]; then
                                        break
                                    fi
                                elif [ "$lookahead_char" = "," ] && [ $paren_depth -eq 1 ]; then
                                    ((comma_count++))
                                fi
                                ((lookahead_col++))
                            done
                            
                            if [ $comma_count -gt 0 ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): catch block cannot have multiple parameters${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                        'typeof'|'void'|'delete'|'!'|'~'|'+'|'-')
                            # Check if followed by destructuring pattern
                            local lookahead_col=$((col+1))
                            local found_pattern=false
                            while [ $lookahead_col -lt $line_length ]; do
                                local lookahead_char="${line:$lookahead_col:1}"
                                if is_whitespace "$lookahead_char"; then
                                    ((lookahead_col++))
                                    continue
                                fi
                                if [ "$lookahead_char" = "{" ] || [ "$lookahead_char" = "[" ]; then
                                    found_pattern=true
                                    break
                                fi
                                break
                            done
                            
                            if $found_pattern; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Destructuring pattern cannot follow '$token' operator${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                    esac
                    
                    # Check for assignment destructuring without parentheses
                    if [ "$token" = "{" ] && ! $in_declaration_context && ! $in_function_param && ! $in_arrow_param && [ $paren_count -eq 0 ]; then
                        # Check if this is object destructuring assignment
                        local lookahead_col=$((col+1))
                        local found_equals=false
                        local found_closing_brace=false
                        local found_something=false
                        
                        while [ $lookahead_col -lt $line_length ]; do
                            local lookahead_char="${line:$lookahead_col:1}"
                            if is_whitespace "$lookahead_char"; then
                                ((lookahead_col++))
                                continue
                            fi
                            if [ "$lookahead_char" = "}" ]; then
                                found_closing_brace=true
                            elif [ "$lookahead_char" = "=" ] && $found_closing_brace; then
                                found_equals=true
                                break
                            elif [[ "$lookahead_char" =~ [a-zA-Z0-9_$] ]]; then
                                found_something=true
                            fi
                            ((lookahead_col++))
                        done
                        
                        if $found_equals && ! $found_something; then
                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Object destructuring assignment requires parentheses${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                    fi
                    
                    # Update last tokens
                    last_token="$token"
                    if [ "$token" != "" ]; then
                        last_non_ws_token="$token"
                    fi
                    
                    # Update bracket counts
                    case "$token" in
                        '{') ((brace_count++)) ;;
                        '}') ((brace_count--)) ;;
                        '[') ((bracket_count++)) ;;
                        ']') ((bracket_count--)) ;;
                        '(') ((paren_count++)) ;;
                        ')') ((paren_count--)) ;;
                    esac
                    
                fi
            fi
            
            ((col++))
        done
        
        # Reset for new line
        if $in_comment_single; then
            in_comment_single=false
        fi
        
    done < "$filename"
    
    # Check for unterminated patterns
    if $in_array_pattern; then
        echo -e "${RED}Error: Unterminated array destructuring pattern${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    if $in_object_pattern; then
        echo -e "${RED}Error: Unterminated object destructuring pattern${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    # Check bracket/brace/paren counts
    if [ $brace_count -gt 0 ]; then
        echo -e "${RED}Error: Unclosed { (missing } )${NC}"
        echo "$(realpath "$filename")"
        return 1
    elif [ $brace_count -lt 0 ]; then
        echo -e "${RED}Error: Unexpected } (extra closing brace)${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    if [ $bracket_count -gt 0 ]; then
        echo -e "${RED}Error: Unclosed [ (missing ] )${NC}"
        echo "$(realpath "$filename")"
        return 1
    elif [ $bracket_count -lt 0 ]; then
        echo -e "${RED}Error: Unexpected ] (extra closing bracket)${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    if [ $paren_count -gt 0 ]; then
        echo -e "${RED}Error: Unclosed ( (missing ) )${NC}"
        echo "$(realpath "$filename")"
        return 1
    elif [ $paren_count -lt 0 ]; then
        echo -e "${RED}Error: Unexpected ) (extra closing parenthesis)${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    return 0
}

# Function to audit a single JavaScript file for destructuring errors
audit_destructuring_file() {
    local filename="$1"
    
    if [ ! -f "$filename" ]; then
        echo -e "${RED}Error: File '$filename' not found${NC}"
        return 1
    fi
    
    if [[ ! "$filename" =~ \.js$ ]]; then
        echo -e "${YELLOW}Warning: File '$filename' doesn't have .js extension${NC}"
    fi
    
    echo -e "${CYAN}Auditing Destructuring Syntax:${NC} ${filename}"
    echo "========================================"
    
    # Check file size
    local file_size=$(wc -c < "$filename")
    if [ $file_size -eq 0 ]; then
        echo -e "${GREEN}✓ Empty file - no errors${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    fi
    
    # Run our destructuring syntax checker
    if check_destructuring_syntax "$filename"; then
        echo -e "${GREEN}✓ No destructuring syntax errors found${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running JavaScript Destructuring Syntax Error Test Suite${NC}"
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
        if audit_destructuring_file "$test_file" 2>/dev/null; then
            echo -e "${RED}  ✗ Expected to fail but passed${NC}"
            ((failed_tests++))
        else
            echo -e "${GREEN}  ✓ Correctly detected destructuring error${NC}"
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
    audit_destructuring_file "$1"
    exit $?
}

# Run main function
main "$@"
