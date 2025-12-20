#!/bin/bash

# JavaScript Async Function Syntax Error Auditor - Pure Bash Implementation
# Usage: ./async.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="2.3.0"
TEST_DIR="async_tests"

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
    echo -e "${BLUE}JavaScript Async Function Syntax Error Auditor v${AUDIT_SCRIPT_VERSION}${NC}"
    echo "Pure bash implementation - No Node.js required"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Audit a specific JavaScript file for async function syntax errors"
    echo "  --test           Run test suite against known async error patterns"
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

# Function to check if token is a number
is_number() {
    local token="$1"
    [[ "$token" =~ ^[0-9]+$ ]] || [[ "$token" =~ ^[0-9]+\.[0-9]*$ ]] || [[ "$token" =~ ^\.[0-9]+$ ]]
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
            # Strings and chars
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
                if is_valid_var_start "$char"; then
                    while [ $pos -lt $length ] && (is_valid_var_char "${line:$pos:1}" || [ "${line:$pos:1}" = "$" ]); do
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

# Function to check for async function syntax errors
check_async_syntax() {
    local filename="$1"
    local line_number=0
    local in_comment_single=false
    local in_comment_multi=false
    local in_string_single=false
    local in_string_double=false
    local in_template=false
    local in_regex=false
    local brace_count=0
    local bracket_count=0
    local paren_count=0
    local last_token=""
    local last_non_ws_token=""
    local expecting_expression=false
    local expecting_operator=false
    local context_stack=()
    local in_function=false
    local in_async_function=false
    local in_async_context=false
    local in_generator=false
    local in_async_generator=false
    local in_class=false
    local in_constructor=false
    local in_getter=false
    local in_setter=false
    local in_method=false
    local in_try_block=false
    local in_catch_block=false
    local in_finally_block=false
    local in_arrow_function=false
    local in_arrow_params=false
    local arrow_has_async=false
    local in_for_loop=false
    local in_switch=false
    local case_default_seen=false
    local in_label=false
    local in_module=false
    local in_iife=false
    local in_await_expression=false
    local async_keyword_pending=false
    local star_pending=false
    local in_object_literal=false
    local object_depth=0
    
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
                        
                        # Regex can't follow certain tokens
                        case "$last_non_ws_token" in
                            ')'|']'|'++'|'--'|'identifier'|'number'|'string'|'}'|'true'|'false'|'null')
                                is_regex=false
                                ;;
                        esac
                        
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
                    
                    # Check for async-specific syntax errors
                    case "$token" in
                        # Check for lonely async keyword (Test 1)
                        'async')
                            # Check if async is used incorrectly
                            if [ "$last_non_ws_token" != "" ] && \
                               [ "$last_non_ws_token" != ";" ] && \
                               [ "$last_non_ws_token" != "{" ] && \
                               [ "$last_non_ws_token" != "}" ] && \
                               [ "$last_non_ws_token" != "(" ] && \
                               [ "$last_non_ws_token" != ")" ] && \
                               [ "$last_non_ws_token" != "[" ] && \
                               [ "$last_non_ws_token" != "]" ] && \
                               [ "$last_non_ws_token" != "," ] && \
                               [ "$last_non_ws_token" != ":" ] && \
                               [ "$last_non_ws_token" != "=" ] && \
                               [ "$last_non_ws_token" != "+" ] && \
                               [ "$last_non_ws_token" != "-" ] && \
                               [ "$last_non_ws_token" != "*" ] && \
                               [ "$last_non_ws_token" != "/" ] && \
                               [ "$last_non_ws_token" != "%" ] && \
                               [ "$last_non_ws_token" != "&&" ] && \
                               [ "$last_non_ws_token" != "||" ] && \
                               [ "$last_non_ws_token" != "??" ] && \
                               [ "$last_non_ws_token" != "export" ] && \
                               [ "$last_non_ws_token" != "return" ] && \
                               [ "$last_non_ws_token" != "yield" ] && \
                               [ "$last_non_ws_token" != "await" ] && \
                               [ "$last_non_ws_token" != "void" ] && \
                               [ "$last_non_ws_token" != "typeof" ] && \
                               [ "$last_non_ws_token" != "delete" ] && \
                               [ "$last_non_ws_token" != "!" ] && \
                               [ "$last_non_ws_token" != "~" ] && \
                               [ "$last_non_ws_token" != "?" ] && \
                               [ "$last_non_ws_token" != "?." ] && \
                               [ "$last_non_ws_token" != "=>" ]; then
                                # Check what comes after async
                                local lookahead_col=$((col+1))
                                local next_token=""
                                if [ $lookahead_col -lt $line_length ]; then
                                    next_token=$(get_token "$line" $lookahead_col)
                                fi
                                
                                # Check for specific error patterns
                                if [ "$next_token" = ";" ] || [ "$next_token" = "" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Async keyword without function declaration${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                
                                # Check for async const/let/var (Test 3, 4)
                                if [ "$next_token" = "const" ] || [ "$next_token" = "let" ] || [ "$next_token" = "var" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Async keyword cannot be used with variable declaration${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            
                            # Check for double async (Test 7)
                            if [ "$last_non_ws_token" = "async" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Duplicate async keyword${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Set async context for arrow functions
                            if $in_arrow_params; then
                                arrow_has_async=true
                            fi
                            ;;
                            
                        # Check for function keyword after async
                        'function')
                            # Check for wrong order: function async (Test 6)
                            if [ "$last_non_ws_token" = "async" ]; then
                                # This is valid: async function
                                in_async_function=true
                                in_async_context=true
                            elif [ "$last_non_ws_token" = "async" ] && [ "$last_token" = "async" ]; then
                                # Double async already handled above
                                :
                            else
                                # Regular function, not async
                                in_async_function=false
                            fi
                            
                            # Check for async function without name (Test 2)
                            if [ "$last_non_ws_token" = "async" ]; then
                                # Look ahead for function name or star
                                local lookahead_col=$((col+1))
                                local found_name_or_star=false
                                local found_star=false
                                while [ $lookahead_col -lt $line_length ]; do
                                    local next_tok=$(get_token "$line" $lookahead_col)
                                    if [ -z "$next_tok" ]; then
                                        break
                                    fi
                                    if [ "$next_tok" = "*" ]; then
                                        found_star=true
                                        found_name_or_star=true
                                        break
                                    fi
                                    if [[ "$next_tok" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                        found_name_or_star=true
                                        break
                                    fi
                                    if [ "$next_tok" = "(" ]; then
                                        # Function without name (function expression)
                                        found_name_or_star=true
                                        break
                                    fi
                                    if [ "$next_tok" = ";" ] || [ "$next_tok" = "{" ]; then
                                        break
                                    fi
                                    ((lookahead_col++))
                                done
                                
                                if ! $found_name_or_star; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Async function declaration missing name${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                
                                if $found_star; then
                                    in_async_generator=true
                                fi
                            fi
                            ;;
                            
                        # Check for await keyword errors
                        'await')
                            # Check for await without expression (Test 16, 17)
                            local lookahead_col=$((col+1))
                            local next_token=""
                            if [ $lookahead_col -lt $line_length ]; then
                                next_token=$(get_token "$line" $lookahead_col)
                            fi
                            
                            if [ "$next_token" = ";" ] || [ -z "$next_token" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Await keyword without expression${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check for await outside async context (Test 9-15)
                            if ! $in_async_context && ! $in_async_function && ! $in_async_generator; then
                                # Check if we're in module context (top-level await allowed in ES modules)
                                local in_module_context=false
                                
                                # Simple check for module indicators
                                if [[ "$line" =~ ^import\ .*from ]] || \
                                   [[ "$line" =~ ^export\ .* ]] || \
                                   [ "$last_non_ws_token" = "import" ] || \
                                   [ "$last_non_ws_token" = "export" ]; then
                                    in_module_context=true
                                fi
                                
                                if ! $in_module_context; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Await is only valid in async functions or ES modules${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            
                            # Check for await in constructor (Test 12)
                            if $in_constructor; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Await cannot be used in class constructor${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check for await in getter/setter (Test 13, 14)
                            if $in_getter || $in_setter; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Await cannot be used in getter/setter${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check for double await (Test 18)
                            if [ "$last_non_ws_token" = "await" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Multiple await keywords${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            in_await_expression=true
                            ;;
                            
                        # Check for arrow function issues
                        '=>')
                            # Check for arrow without async in params when await is used
                            if $in_arrow_params && ! $arrow_has_async && $in_await_expression; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Arrow function with await must be async${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Reset arrow context
                            in_arrow_params=false
                            arrow_has_async=false
                            in_arrow_function=true
                            ;;
                            
                        # Check for class-related errors
                        'class')
                            in_class=true
                            in_constructor=false
                            ;;
                            
                        'constructor')
                            if $in_class; then
                                in_constructor=true
                                # Check for async constructor (Test 27)
                                if [ "$last_non_ws_token" = "async" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Class constructor cannot be async${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        'get')
                            if $in_class || $in_object_literal; then
                                in_getter=true
                                # Check for async getter (Test 25)
                                if [ "$last_non_ws_token" = "async" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Getter cannot be async${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        'set')
                            if $in_class || $in_object_literal; then
                                in_setter=true
                                # Check for async setter (Test 26)
                                if [ "$last_non_ws_token" = "async" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Setter cannot be async${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        # Check for generator star
                        '*')
                            # Check for async generator issues
                            if [ "$last_non_ws_token" = "async" ]; then
                                # async * is valid
                                in_async_generator=true
                                star_pending=true
                            elif [ "$last_non_ws_token" = "function" ] && [ "$last_token" = "async" ]; then
                                # async function * is valid
                                in_async_generator=true
                                star_pending=true
                            elif $star_pending; then
                                # Already handled
                                star_pending=false
                            fi
                            
                            # Check for * in wrong place (Test 29)
                            if [ "$last_non_ws_token" = "async" ] && [ "$next_char" = "function" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid async generator syntax${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for yield in async generator
                        'yield')
                            # Check for yield in non-generator async function
                            if $in_async_function && ! $in_async_generator; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Yield cannot be used in async function (use async generator)${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check for await yield (Test 33)
                            if [ "$last_non_ws_token" = "await" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Await cannot be followed by yield${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for parentheses issues
                        '(')
                            # Check for async arrow function parameter issues
                            if [ "$last_non_ws_token" = "async" ] && ! $in_function && ! $in_class; then
                                in_arrow_params=true
                                arrow_has_async=true
                            fi
                            
                            # Check for async IIFE issues (Test 34, 35)
                            if [ "$last_non_ws_token" = "async" ] && [ "$last_token" = "async" ]; then
                                # async function() - need to check if this is valid
                                local look_back=1
                                local prev_token=""
                                while [ $look_back -le 5 ] && [ $((col-look_back)) -ge 0 ]; do
                                    local temp_pos=$((col-look_back))
                                    if [ $temp_pos -ge 0 ]; then
                                        prev_token=$(get_token "$line" $temp_pos)
                                        if [ -n "$prev_token" ]; then
                                            break
                                        fi
                                    fi
                                    ((look_back++))
                                done
                                
                                if [ "$prev_token" != "function" ] && [ "$prev_token" != "(" ] && [ "$prev_token" != "=" ] && [ "$prev_token" != ":" ] && [ "$prev_token" != "," ] && [ "$prev_token" != ";" ] && [ "$prev_token" != "{" ] && [ "$prev_token" != "}" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Async keyword must precede function declaration or expression${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        # Check for semicolon issues
                        ';')
                            # Check for async at start of statement (Test 1)
                            if [ "$last_non_ws_token" = "async" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Async keyword without function declaration${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Reset contexts
                            in_await_expression=false
                            async_keyword_pending=false
                            star_pending=false
                            in_arrow_params=false
                            arrow_has_async=false
                            ;;
                            
                        # Check for object literal issues
                        '{')
                            if [ "$last_non_ws_token" = "=" ] || \
                               [ "$last_non_ws_token" = ":" ] || \
                               [ "$last_non_ws_token" = "," ] || \
                               [ "$last_non_ws_token" = "(" ] || \
                               [ "$last_non_ws_token" = "=>" ]; then
                                ((object_depth++))
                                in_object_literal=true
                            fi
                            
                            # Reset method flags
                            in_getter=false
                            in_setter=false
                            in_method=false
                            ;;
                            
                        '}')
                            if $in_object_literal; then
                                ((object_depth--))
                                if [ $object_depth -eq 0 ]; then
                                    in_object_literal=false
                                fi
                            fi
                            
                            # Reset class context if leaving class body
                            if $in_class && [ $brace_count -eq 0 ]; then
                                in_class=false
                                in_constructor=false
                            fi
                            
                            # Reset function contexts
                            if $in_async_function && [ $brace_count -eq 0 ]; then
                                in_async_function=false
                                in_async_context=false
                                in_async_generator=false
                            fi
                            
                            if $in_arrow_function && [ $brace_count -eq 0 ]; then
                                in_arrow_function=false
                            fi
                            ;;
                            
                        # Check for try-catch-finally issues
                        'try')
                            in_try_block=true
                            ;;
                            
                        'catch')
                            in_catch_block=true
                            # Check for await in catch parameters (Test 41, 42)
                            if [ "$last_non_ws_token" = "async" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Async keyword cannot precede catch${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        'finally')
                            in_finally_block=true
                            ;;
                            
                        # Check for for loop issues
                        'for')
                            in_for_loop=true
                            # Check for async in for loop initializer (Test 47)
                            if [ "$last_non_ws_token" = "async" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Async keyword cannot be used in for loop initializer${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for switch issues
                        'switch')
                            in_switch=true
                            # Check for async switch expression (Test 48)
                            if [ "$last_non_ws_token" = "async" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Async keyword cannot be used as switch expression${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for void issues
                        'void')
                            # Check for void async (Test 49)
                            if [ "$next_char" = "async" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Void cannot be used with async keyword${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for template literal issues
                        '`')
                            # Note: Template literals are handled in string context
                            ;;
                            
                        # Default case for other tokens
                        *)
                            # Check if token looks like an identifier
                            if [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                # Check for invalid async usage after identifier
                                if [ "$last_non_ws_token" = "async" ] && \
                                   [ "$token" != "function" ] && \
                                   [ "$token" != "*" ] && \
                                   ! $in_arrow_params && \
                                   ! $in_object_literal; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Async keyword must be followed by function declaration or expression${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                    esac
                    
                    # Update last non-whitespace token
                    if [ "$token" != "" ]; then
                        last_non_ws_token="$token"
                        last_token="$token"
                    fi
                    
                    # Update bracket counts
                    case "$token" in
                        '{') ((brace_count++)) ;;
                        '}') 
                            ((brace_count--))
                            # Reset try-catch-finally contexts
                            if $in_try_block && [ $brace_count -eq 0 ]; then
                                in_try_block=false
                            fi
                            if $in_catch_block && [ $brace_count -eq 0 ]; then
                                in_catch_block=false
                            fi
                            if $in_finally_block && [ $brace_count -eq 0 ]; then
                                in_finally_block=false
                            fi
                            if $in_for_loop && [ $brace_count -eq 0 ]; then
                                in_for_loop=false
                            fi
                            if $in_switch && [ $brace_count -eq 0 ]; then
                                in_switch=false
                            fi
                            ;;
                        '[') ((bracket_count++)) ;;
                        ']') ((bracket_count--)) ;;
                        '(') ((paren_count++)) ;;
                        ')') 
                            ((paren_count--))
                            # Reset arrow params context
                            if $in_arrow_params && [ $paren_count -eq 0 ]; then
                                in_arrow_params=false
                            fi
                            ;;
                    esac
                    
                    # Special checks after token processing
                    
                    # Check for async with await in arrow function params (Test 19)
                    if $in_arrow_params && [ "$token" = "await" ]; then
                        if ! $arrow_has_async; then
                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Await cannot be used in arrow function parameters${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                    fi
                    
                    # Check for missing arrow after async params (Test 20)
                    if $in_arrow_params && ! $arrow_has_async && [ "$token" = "await" ]; then
                        # Look ahead for arrow
                        local lookahead_col=$((col+1))
                        local found_arrow=false
                        while [ $lookahead_col -lt $line_length ]; do
                            local next_tok=$(get_token "$line" $lookahead_col)
                            if [ "$next_tok" = "=>" ]; then
                                found_arrow=true
                                break
                            fi
                            if [ "$next_tok" = ";" ] || [ "$next_tok" = "{" ] || [ "$next_tok" = "}" ]; then
                                break
                            fi
                            ((lookahead_col++))
                        done
                        
                        if ! $found_arrow; then
                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Arrow function missing '=>'${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                    fi
                    
                    # Check for await in default parameters (Test 38, 39)
                    if [ "$token" = "=" ] && [ "$last_non_ws_token" = "await" ]; then
                        # Check if we're in function parameters
                        local in_params=false
                        local temp_paren=$paren_count
                        local temp_col=$col
                        
                        # Look back for function or arrow start
                        while [ $temp_col -ge 0 ]; do
                            local prev_char="${line:$temp_col:1}"
                            if [ "$prev_char" = "(" ]; then
                                ((temp_paren--))
                                if [ $temp_paren -eq 0 ]; then
                                    # Check what's before the paren
                                    local before_paren=""
                                    for ((i=temp_col-1; i>=0; i--)); do
                                        local char_before="${line:$i:1}"
                                        if [[ "$char_before" =~ [a-zA-Z_$] ]]; then
                                            before_paren="$char_before$before_paren"
                                        elif [ -n "$before_paren" ]; then
                                            break
                                        fi
                                    done
                                    
                                    if [ "$before_paren" = "function" ] || \
                                       [ "$before_paren" = "async" ] || \
                                       [[ "$before_paren" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                        in_params=true
                                    fi
                                    break
                                fi
                            fi
                            ((temp_col--))
                        done
                        
                        if $in_params; then
                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Await cannot be used in default parameters${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                    fi
                    
                    # Check for await in rest parameters (Test 40)
                    if [ "$token" = "..." ] && [ "$next_char" = "await" ]; then
                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Await cannot be used in rest parameters${NC}"
                        echo "  $line"
                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                        echo "$(realpath "$filename")"
                        return 1
                    fi
                    
                    # Check for yield await issue (Test 32)
                    if [ "$token" = "await" ] && [ "$last_non_ws_token" = "yield" ]; then
                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Yield cannot be followed by await${NC}"
                        echo "  $line"
                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                        echo "$(realpath "$filename")"
                        return 1
                    fi
                    
                fi
            fi
            
            ((col++))
        done
        
        # Reset for new line
        if $in_comment_single; then
            in_comment_single=false
        fi
        
        # Reset line-specific contexts
        in_await_expression=false
        
    done < "$filename"
    
    # Final checks at end of file
    
    # Check for unterminated async contexts
    if $in_async_function && [ $brace_count -gt 0 ]; then
        echo -e "${RED}Error: Unterminated async function${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    if $in_arrow_params; then
        echo -e "${RED}Error: Unterminated arrow function parameters${NC}"
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

# Function to audit a single JavaScript file
audit_js_file() {
    local filename="$1"
    
    if [ ! -f "$filename" ]; then
        echo -e "${RED}Error: File '$filename' not found${NC}"
        return 1
    fi
    
    if [[ ! "$filename" =~ \.js$ ]]; then
        echo -e "${YELLOW}Warning: File '$filename' doesn't have .js extension${NC}"
    fi
    
    echo -e "${CYAN}Auditing:${NC} ${filename}"
    echo "========================================"
    
    # Check file size
    local file_size=$(wc -c < "$filename")
    if [ $file_size -eq 0 ]; then
        echo -e "${GREEN}✓ Empty file - no errors${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    fi
    
    # Run our async syntax checker
    if check_async_syntax "$filename"; then
        echo -e "${GREEN}✓ No async syntax errors found${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running JavaScript Async Function Syntax Error Test Suite${NC}"
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
            echo -e "${GREEN}  ✓ Correctly detected async syntax error${NC}"
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
