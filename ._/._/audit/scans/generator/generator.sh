#!/bin/bash

# JavaScript Generator Function Syntax Error Auditor
# Usage: ./generator.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="1.0.0"
TEST_DIR="generator_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display usage
show_usage() {
    echo -e "${BLUE}JavaScript Generator Syntax Error Auditor v${AUDIT_SCRIPT_VERSION}${NC}"
    echo "Pure bash implementation - No Node.js required"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Audit a specific JavaScript file for generator errors"
    echo "  --test           Run test suite against known generator error patterns"
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

# Function to check if character is valid for variable name
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
                        '*=')
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

# Function to check for generator syntax errors
check_generator_syntax() {
    local filename="$1"
    local line_number=0
    local in_comment_single=false
    local in_comment_multi=false
    local in_string_single=false
    local in_string_double=false
    local in_template=false
    local in_regex=false
    
    # Generator-specific state
    local in_generator=false
    local in_async_generator=false
    local in_normal_function=false
    local in_arrow_function=false
    local in_class=false
    local in_method=false
    local in_object_literal=false
    local in_yield_context=false
    local yield_star_context=false
    local expecting_yield_expression=false
    local expecting_yield_star_expression=false
    local last_token=""
    local last_non_ws_token=""
    local function_depth=0
    local generator_depth=0
    local brace_count=0
    local paren_count=0
    
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
                    
                    # Check for generator-related errors
                    case "$token" in
                        # Check for function declarations
                        'function')
                            if [ "$last_non_ws_token" = "async" ]; then
                                # async function - check if it's a generator
                                local lookahead_col=$((col+1))
                                local found_asterisk=false
                                # Look for asterisk
                                while [ $lookahead_col -lt $line_length ]; do
                                    if is_whitespace "${line:$lookahead_col:1}"; then
                                        ((lookahead_col++))
                                        continue
                                    fi
                                    if [ "${line:$lookahead_col:1}" = "*" ]; then
                                        found_asterisk=true
                                        break
                                    fi
                                    break
                                done
                                if ! $found_asterisk; then
                                    in_normal_function=true
                                    in_async_generator=false
                                fi
                            else
                                in_normal_function=true
                                in_generator=false
                            fi
                            ;;
                            
                        # Check for asterisk in wrong position
                        '*')
                            # Check if asterisk is part of function* or yield*
                            if [ "$last_non_ws_token" = "function" ]; then
                                # Valid: function* generator
                                in_generator=true
                                in_normal_function=false
                            elif [ "$last_non_ws_token" = "async" ]; then
                                # Check for async function*
                                local lookahead=$((col+1))
                                local found_function=false
                                while [ $lookahead -lt $line_length ]; do
                                    if is_whitespace "${line:$lookahead:1}"; then
                                        ((lookahead++))
                                        continue
                                    fi
                                    # Check for "function" token
                                    local next_token=$(get_token "$line" $lookahead)
                                    if [ "$next_token" = "function" ]; then
                                        found_function=true
                                    fi
                                    break
                                done
                                if ! $found_function; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Asterisk without 'function' keyword${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            elif [ "$last_non_ws_token" = "yield" ]; then
                                # Valid: yield*
                                yield_star_context=true
                                expecting_yield_star_expression=true
                            else
                                # Check for invalid asterisk position
                                if $in_normal_function && ! $in_generator; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing asterisk in generator function declaration${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        # Check for yield errors
                        'yield')
                            # Check if yield is used outside generator
                            if ! $in_generator && ! $in_async_generator; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'yield' expression outside generator function${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check if yield is used as identifier
                            if [ "$last_non_ws_token" = "let" ] || [ "$last_non_ws_token" = "const" ] || [ "$last_non_ws_token" = "var" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'yield' cannot be used as identifier in generator${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            expecting_yield_expression=true
                            ;;
                            
                        # Check for yield* errors
                        'yield*')
                            if ! $in_generator && ! $in_async_generator; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'yield*' outside generator function${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            expecting_yield_star_expression=true
                            ;;
                            
                        # Check for return/throw as identifiers in generator
                        'return'|'throw')
                            if $in_generator && ([ "$last_non_ws_token" = "let" ] || [ "$last_non_ws_token" = "const" ] || [ "$last_non_ws_token" = "var" ]); then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): '$token' cannot be used as identifier in generator${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for async generator errors
                        'async')
                            # Check next token to see if it's a generator
                            local lookahead_col=$((col+1))
                            local found_asterisk=false
                            while [ $lookahead_col -lt $line_length ]; do
                                if is_whitespace "${line:$lookahead_col:1}"; then
                                    ((lookahead_col++))
                                    continue
                                fi
                                if [ "${line:$lookahead_col:1}" = "*" ]; then
                                    found_asterisk=true
                                fi
                                break
                            done
                            
                            if ! $found_asterisk && [ "$next_char" != "*" ]; then
                                # async without asterisk - could be normal async function
                                :
                            fi
                            ;;
                            
                        # Check for class context
                        'class')
                            in_class=true
                            in_object_literal=false
                            ;;
                            
                        # Check for object literal context
                        '{')
                            if [ "$last_non_ws_token" = "=" ] || [ "$last_non_ws_token" = ":" ] || [ "$last_non_ws_token" = "," ]; then
                                in_object_literal=true
                            fi
                            in_method=false
                            ((brace_count++))
                            ;;
                            
                        '}')
                            ((brace_count--))
                            if [ $brace_count -eq 0 ]; then
                                in_object_literal=false
                                in_class=false
                            fi
                            ;;
                            
                        # Check for method context
                        ':'|',')
                            if $in_object_literal; then
                                in_method=false
                            fi
                            ;;
                            
                        # Check for arrow functions
                        '=>')
                            in_arrow_function=true
                            # Arrow functions cannot be generators
                            if $in_generator; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Arrow functions cannot be generators${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for semicolon after yield without expression
                        ';')
                            if $expecting_yield_expression && [ "$last_non_ws_token" = "yield" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing expression after 'yield'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            if $expecting_yield_star_expression && [ "$last_non_ws_token" = "yield*" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing expression after 'yield*'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            expecting_yield_expression=false
                            expecting_yield_star_expression=false
                            ;;
                            
                        # Check for new with generator
                        'new')
                            # Look ahead to see if this is trying to instantiate a generator
                            local lookahead_col=$((col+1))
                            local generator_name=""
                            while [ $lookahead_col -lt $line_length ]; do
                                if is_whitespace "${line:$lookahead_col:1}"; then
                                    ((lookahead_col++))
                                    continue
                                fi
                                generator_name=$(get_token "$line" $lookahead_col)
                                break
                            done
                            
                            # Check if we've seen this as a generator function
                            if [[ "$generator_name" == *"*"* ]] || [[ "$generator_name" == *"generator"* ]]; then
                                echo -e "${YELLOW}Warning at line $line_number: Possibly trying to instantiate a generator function${NC}"
                            fi
                            ;;
                            
                        # Check for invalid yield in parameter defaults
                        '(')
                            ((paren_count++))
                            # Check if we're in function parameters
                            if [ "$last_non_ws_token" = "function" ] || [ "$last_non_ws_token" = "function*" ] || \
                               ([ "$last_non_ws_token" = "async" ] && [ "${line:$((col-6)):6}" = "async" ]); then
                                # Inside function parameters - check for yield in defaults
                                local param_lookahead=$((col+1))
                                local in_default=false
                                local seen_yield=false
                                
                                while [ $param_lookahead -lt $line_length ] && [ "${line:$param_lookahead:1}" != ")" ]; do
                                    local param_char="${line:$param_lookahead:1}"
                                    local param_token=$(get_token "$line" $param_lookahead)
                                    
                                    if [ "$param_token" = "=" ]; then
                                        in_default=true
                                    elif [ "$param_token" = "yield" ] && $in_default; then
                                        seen_yield=true
                                        # Check if it's in a generator
                                        if $in_generator && [ "$last_non_ws_token" = "function*" ]; then
                                            # This is actually valid in ES2015+
                                            :
                                        else
                                            echo -e "${RED}Error at line $line_number: 'yield' in non-generator function parameter default${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $param_lookahead "" "${RED}here${NC}"
                                            echo "$(realpath "$filename")"
                                            return 1
                                        fi
                                    fi
                                    
                                    if [ -n "$param_token" ] && [ "$param_token" != " " ]; then
                                        ((param_lookahead += ${#param_token} - 1))
                                    fi
                                    ((param_lookahead++))
                                done
                            fi
                            ;;
                            
                        ')')
                            ((paren_count--))
                            ;;
                            
                        # Check for template literal after yield
                        '`')
                            if [ "$last_non_ws_token" = "yield" ] && ! $expecting_yield_expression; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid yield with template literal${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                    esac
                    
                    # Check for generator method syntax errors
                    if $in_object_literal || $in_class; then
                        case "$token" in
                            # Check for method definitions
                            '*')
                                # In object/class, asterisk should come before method name
                                if [ "$last_non_ws_token" != "" ] && [ "$last_non_ws_token" != "async" ] && \
                                   [ "$last_non_ws_token" != "static" ] && [ "$last_non_ws_token" != "get" ] && \
                                   [ "$last_non_ws_token" != "set" ]; then
                                    # Check if asterisk is after identifier (invalid)
                                    if [[ "$last_non_ws_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid asterisk position in method definition${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                fi
                                ;;
                                
                            # Check for computed property names with generators
                            '[')
                                if [ "$last_non_ws_token" = "*" ] || [ "$last_non_ws_token" = "async" ]; then
                                    # Computed generator method name
                                    # Check for closing bracket and parentheses
                                    local computed_lookahead=$((col+1))
                                    local bracket_depth=1
                                    while [ $computed_lookahead -lt $line_length ] && [ $bracket_depth -gt 0 ]; do
                                        local comp_char="${line:$computed_lookahead:1}"
                                        if [ "$comp_char" = "[" ]; then
                                            ((bracket_depth++))
                                        elif [ "$comp_char" = "]" ]; then
                                            ((bracket_depth--))
                                        fi
                                        ((computed_lookahead++))
                                    done
                                    
                                    # After closing bracket, should have parentheses
                                    if [ $computed_lookahead -lt $line_length ]; then
                                        local after_bracket=$(get_token "$line" $computed_lookahead)
                                        if [ "$after_bracket" != "(" ] && [ "$after_bracket" != ")" ]; then
                                            echo -e "${RED}Error at line $line_number: Generator method missing parentheses${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $computed_lookahead "" "${RED}here${NC}"
                                            echo "$(realpath "$filename")"
                                            return 1
                                        fi
                                    fi
                                fi
                                ;;
                        esac
                    fi
                    
                    # Update last non-whitespace token
                    if [ "$token" != "" ]; then
                        last_non_ws_token="$token"
                    fi
                    
                    # Reset yield expectation when we see an expression
                    if $expecting_yield_expression && [ "$token" != "yield" ] && [ "$token" != "yield*" ] && \
                       [ "$token" != ";" ] && [ "$token" != "," ] && [ "$token" != ")" ] && \
                       [ "$token" != "}" ] && [ "$token" != "]" ]; then
                        expecting_yield_expression=false
                    fi
                    
                    if $expecting_yield_star_expression && [ "$token" != "yield" ] && [ "$token" != "yield*" ] && \
                       [ "$token" != ";" ] && [ "$token" != "," ] && [ "$token" != ")" ] && \
                       [ "$token" != "}" ] && [ "$token" != "]" ]; then
                        expecting_yield_star_expression=false
                    fi
                    
                    # Check for yield in arrow function inside generator
                    if $in_generator && $in_arrow_function && [ "$token" = "yield" ]; then
                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'yield' not allowed in arrow function inside generator${NC}"
                        echo "  $line"
                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                        echo "$(realpath "$filename")"
                        return 1
                    fi
                    
                    # Check for invalid yield* usage
                    if [ "$token" = "yield*" ]; then
                        # Look ahead for expression
                        local lookahead_col=$((col+1))
                        local found_expr=false
                        while [ $lookahead_col -lt $line_length ]; do
                            if is_whitespace "${line:$lookahead_col:1}"; then
                                ((lookahead_col++))
                                continue
                            fi
                            local next_token=$(get_token "$line" $lookahead_col)
                            if [ -n "$next_token" ] && [ "$next_token" != ";" ] && [ "$next_token" != "," ] && \
                               [ "$next_token" != ")" ] && [ "$next_token" != "}" ] && [ "$next_token" != "]" ]; then
                                found_expr=true
                                break
                            fi
                            break
                        done
                        
                        if ! $found_expr; then
                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing expression after 'yield*'${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                    fi
                    
                    # Check for yield precedence issues
                    if [ "$last_non_ws_token" = "yield" ] && [ "$token" = "yield" ]; then
                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid consecutive 'yield' expressions${NC}"
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
        
        # Check for unterminated yield expectation at end of line
        if $expecting_yield_expression && [ "$last_non_ws_token" = "yield" ]; then
            echo -e "${RED}Error at line $line_number: Incomplete 'yield' expression at end of line${NC}"
            echo "  $line"
            echo "$(realpath "$filename")"
            return 1
        fi
        
        if $expecting_yield_star_expression && [ "$last_non_ws_token" = "yield*" ]; then
            echo -e "${RED}Error at line $line_number: Incomplete 'yield*' expression at end of line${NC}"
            echo "  $line"
            echo "$(realpath "$filename")"
            return 1
        fi
        
    done < "$filename"
    
    # Final checks
    if $in_generator && ! $in_async_generator && [ "$last_non_ws_token" != "}" ]; then
        # Check if generator has yield statements (warning, not error)
        :
    fi
    
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
    
    # Check bracket/brace counts
    if [ $brace_count -gt 0 ]; then
        echo -e "${RED}Error: Unclosed { (missing } )${NC}"
        echo "$(realpath "$filename")"
        return 1
    elif [ $brace_count -lt 0 ]; then
        echo -e "${RED}Error: Unexpected } (extra closing brace)${NC}"
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
    
    echo -e "${CYAN}Auditing generator syntax in:${NC} ${filename}"
    echo "========================================"
    
    # Check file size
    local file_size=$(wc -c < "$filename")
    if [ $file_size -eq 0 ]; then
        echo -e "${GREEN}✓ Empty file - no generator errors${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    fi
    
    # Run our generator syntax checker
    if check_generator_syntax "$filename"; then
        echo -e "${GREEN}✓ No generator syntax errors found${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running Generator Function Syntax Error Test Suite${NC}"
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
