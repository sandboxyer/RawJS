#!/bin/bash

# JavaScript Arrow Function Syntax Error Auditor - Pure Bash Implementation
# Usage: ./arrowfunc.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="1.0.0"
TEST_DIR="basics_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display usage
show_usage() {
    echo -e "${BLUE}JavaScript Arrow Function Syntax Error Auditor v${AUDIT_SCRIPT_VERSION}${NC}"
    echo "Pure bash implementation - No Node.js required"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Audit a specific JavaScript file for arrow function errors"
    echo "  --test           Run test suite against known error patterns"
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

# Function to check for arrow function syntax errors
check_arrow_function_syntax() {
    local filename="$1"
    local line_number=0
    local in_comment_single=false
    local in_comment_multi=false
    local in_string_single=false
    local in_string_double=false
    local in_template=false
    local in_regex=false
    local last_token=""
    local last_non_ws_token=""
    local token_before_last=""
    local in_arrow_context=false
    local expecting_arrow=false
    local in_param_list=false
    local param_paren_depth=0
    local param_list_start_line=0
    local param_list_start_col=0
    local param_count=0
    local has_seen_comma_in_params=false
    local has_seen_param=false
    local in_async_context=false
    local in_default_param=false
    local in_destructuring_param=false
    local destructuring_depth=0
    local in_block_body=false
    local block_brace_depth=0
    local expecting_expression_after_arrow=false
    local arrow_line=0
    local arrow_col=0
    
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
                if [ "$char" = "'" ] && ! $in_string_double && ! $in_template && ! $in_regex; then
                    $in_string_single && in_string_single=false || in_string_single=true
                elif [ "$char" = '"' ] && ! $in_string_single && ! $in_template && ! $in_regex; then
                    $in_string_double && in_string_double=false || in_string_double=true
                elif [ "$char" = '`' ] && ! $in_string_single && ! $in_string_double && ! $in_regex; then
                    $in_template && in_template=false || in_template=true
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
            
            # Inside multi-line comment
            if $in_comment_multi && [ "$char" = '*' ] && [ "$next_char" = '/' ]; then
                in_comment_multi=false
                ((col++))
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
                    
                    # Store token history
                    token_before_last="$last_token"
                    last_token="$token"
                    
                    # Check for arrow function specific errors
                    case "$token" in
                        # Async keyword detection
                        'async')
                            if [ "$last_non_ws_token" = "" ] || [ "$last_non_ws_token" = ";" ] || \
                               [ "$last_non_ws_token" = "{" ] || [ "$last_non_ws_token" = "}" ] || \
                               [ "$last_non_ws_token" = "(" ] || [ "$last_non_ws_token" = ")" ] || \
                               [ "$last_non_ws_token" = "[" ] || [ "$last_non_ws_token" = "]" ] || \
                               [ "$last_non_ws_token" = "," ] || [ "$last_non_ws_token" = "=" ] || \
                               [ "$last_non_ws_token" = ":" ] || [ "$last_non_ws_token" = "?" ] || \
                               [ "$last_non_ws_token" = "&&" ] || [ "$last_non_ws_token" = "||" ] || \
                               [ "$last_non_ws_token" = "??" ]; then
                                in_async_context=true
                            fi
                            ;;
                            
                        # Check for arrow token errors
                        '=>')
                            arrow_line=$line_number
                            arrow_col=$((col-token_length+2))
                            
                            # Error: Arrow at start of expression
                            if [ "$last_non_ws_token" = "" ] || \
                               [ "$last_non_ws_token" = ";" ] || \
                               [ "$last_non_ws_token" = "{" ] || \
                               [ "$last_non_ws_token" = "}" ] || \
                               [ "$last_non_ws_token" = "[" ] || \
                               [ "$last_non_ws_token" = "]" ] || \
                               [ "$last_non_ws_token" = "(" ] || \
                               [ "$last_non_ws_token" = ")" ] || \
                               [ "$last_non_ws_token" = "," ] || \
                               [ "$last_non_ws_token" = "=" ] || \
                               [ "$last_non_ws_token" = ":" ] || \
                               [ "$last_non_ws_token" = "?" ] || \
                               [ "$last_non_ws_token" = "&&" ] || \
                               [ "$last_non_ws_token" = "||" ] || \
                               [ "$last_non_ws_token" = "??" ] || \
                               [ "$last_non_ws_token" = "async" ] && ! $in_async_context; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected arrow token '=>'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Error: Multiple arrows in sequence
                            if [ "$token_before_last" = "=>" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Multiple arrow tokens in sequence${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check parameter context
                            if $in_param_list && [ $param_paren_depth -gt 0 ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Arrow inside parameter list${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check for missing parentheses with zero or multiple parameters
                            if ! $in_param_list && [ "$last_non_ws_token" != ")" ]; then
                                # Check if we have multiple identifiers before arrow
                                if [[ "$last_non_ws_token" =~ , ]]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Multiple parameters require parentheses${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            
                            expecting_expression_after_arrow=true
                            in_arrow_context=true
                            in_param_list=false
                            param_paren_depth=0
                            ;;
                            
                        # Check for wrong arrow symbols
                        '->'|'=')
                            # Check if this looks like an attempt at arrow function
                            if [ "$last_non_ws_token" = ")" ] || \
                               [[ "$last_non_ws_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] || \
                               [ "$last_non_ws_token" = "]" ] || [ "$last_non_ws_token" = "}" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid arrow symbol '$token', use '=>'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check parameter list errors
                        '(')
                            if $expecting_arrow || [ "$last_non_ws_token" = "async" ] || \
                               [ "$last_non_ws_token" = "" ] || [ "$last_non_ws_token" = "=" ] || \
                               [ "$last_non_ws_token" = ":" ] || [ "$last_non_ws_token" = "," ] || \
                               [ "$last_non_ws_token" = "(" ] || [ "$last_non_ws_token" = "[" ] || \
                               [ "$last_non_ws_token" = "{" ] || [ "$last_non_ws_token" = "?" ] || \
                               [ "$last_non_ws_token" = "&&" ] || [ "$last_non_ws_token" = "||" ] || \
                               [ "$last_non_ws_token" = "??" ]; then
                                in_param_list=true
                                param_paren_depth=1
                                param_list_start_line=$line_number
                                param_list_start_col=$((col-token_length+2))
                                param_count=0
                                has_seen_comma_in_params=false
                                has_seen_param=false
                                in_destructuring_param=false
                                destructuring_depth=0
                            fi
                            ;;
                            
                        ')')
                            if $in_param_list; then
                                ((param_paren_depth--))
                                if [ $param_paren_depth -eq 0 ]; then
                                    in_param_list=false
                                    expecting_arrow=true
                                    
                                    # Check for empty parameter list with comma
                                    if $has_seen_comma_in_params && ! $has_seen_param; then
                                        echo -e "${RED}Error at line $param_list_start_line, column $param_list_start_col: Empty parameter list with comma${NC}"
                                        echo "  $(sed -n "${param_list_start_line}p" "$filename")"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                fi
                            fi
                            ;;
                            
                        # Check for parameter errors
                        ',')
                            if $in_param_list && [ $param_paren_depth -eq 1 ]; then
                                has_seen_comma_in_params=true
                                
                                # Error: Comma without preceding parameter
                                if ! $has_seen_param && [ $param_count -eq 0 ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected comma in parameter list${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                
                                # Error: Multiple consecutive commas
                                if [ "$token_before_last" = "," ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Multiple consecutive commas in parameter list${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                
                                # Reset for next parameter
                                has_seen_param=false
                                in_default_param=false
                            fi
                            ;;
                            
                        # Check for destructuring errors
                        '{'|'[')
                            if $in_param_list && [ $param_paren_depth -eq 1 ]; then
                                in_destructuring_param=true
                                ((destructuring_depth++))
                            fi
                            ;;
                            
                        '}'|']')
                            if $in_destructuring_param; then
                                ((destructuring_depth--))
                                if [ $destructuring_depth -eq 0 ]; then
                                    in_destructuring_param=false
                                    has_seen_param=true
                                    ((param_count++))
                                fi
                            fi
                            ;;
                            
                        # Check for default parameter errors
                        '=')
                            if $in_param_list && [ $param_paren_depth -eq 1 ] && ! $in_destructuring_param; then
                                in_default_param=true
                            fi
                            ;;
                            
                        # Check for identifiers in parameter list
                        *)
                            if $in_param_list && [ $param_paren_depth -eq 1 ] && ! $in_destructuring_param; then
                                # Check for duplicate parameter names (simplified)
                                if [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && ! $in_default_param; then
                                    has_seen_param=true
                                    ((param_count++))
                                fi
                                
                                # Check for yield/await in parameter default
                                if $in_default_param && { [ "$token" = "yield" ] || [ "$token" = "await" ]; }; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): '$token' not allowed in parameter default${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            
                            # Check for rest parameter errors
                            if [ "$token" = "..." ] && $in_param_list && [ $param_paren_depth -eq 1 ]; then
                                # Check if rest parameter is last
                                local lookahead_col=$((col+1))
                                local found_comma=false
                                while [ $lookahead_col -lt $line_length ]; do
                                    local next_tok=$(get_token "$line" $lookahead_col)
                                    if [ "$next_tok" = "," ]; then
                                        found_comma=true
                                        break
                                    elif [ "$next_tok" = ")" ]; then
                                        break
                                    fi
                                    ((lookahead_col++))
                                done
                                
                                if $found_comma; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Rest parameter must be last${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                    esac
                    
                    # Check for block body errors after arrow
                    if $in_arrow_context && $expecting_expression_after_arrow; then
                        case "$token" in
                            '{')
                                in_block_body=true
                                block_brace_depth=1
                                expecting_expression_after_arrow=false
                                ;;
                            ';'|','|')'|']'|'}')
                                if ! $in_block_body; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing function body after arrow${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                ;;
                        esac
                    fi
                    
                    # Check for block body issues
                    if $in_block_body; then
                        case "$token" in
                            '{') ((block_brace_depth++)) ;;
                            '}')
                                ((block_brace_depth--))
                                if [ $block_brace_depth -eq 0 ]; then
                                    in_block_body=false
                                    in_arrow_context=false
                                fi
                                ;;
                        esac
                    fi
                    
                    # Check for object literal return issues
                    if $in_arrow_context && $expecting_expression_after_arrow && [ "$token" = "{" ]; then
                        # Check if this is likely an object literal (needs parentheses)
                        local lookahead_col=$((col+1))
                        local object_literal=true
                        
                        while [ $lookahead_col -lt $line_length ]; do
                            local next_char="${line:$lookahead_col:1}"
                            if is_whitespace "$next_char"; then
                                ((lookahead_col++))
                                continue
                            fi
                            
                            # Check for property definition pattern
                            if [[ "$next_char" =~ [a-zA-Z_$] ]] || [ "$next_char" = "'" ] || [ "$next_char" = '"' ]; then
                                # Could be object literal
                                break
                            elif [ "$next_char" = "}" ]; then
                                # Empty object
                                break
                            else
                                # Not an object literal
                                object_literal=false
                                break
                            fi
                            ((lookahead_col++))
                        done
                        
                        if $object_literal && [ "$last_non_ws_token" != "(" ]; then
                            echo -e "${YELLOW}Warning at line $line_number, column $((col-token_length+2)): Object literal after arrow needs parentheses${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((col-token_length+1)) "" "${YELLOW}here${NC}"
                            echo "  Use: () => ({ ... }) instead of () => { ... }"
                        fi
                    fi
                    
                    # Check for generator attempt
                    if [ "$token" = "*" ] && [ "$last_non_ws_token" = "function" ]; then
                        # Generator function, not arrow - this is okay
                        :
                    elif [ "$token" = "*" ] && $in_arrow_context; then
                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Arrow functions cannot be generators${NC}"
                        echo "  $line"
                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                        echo "$(realpath "$filename")"
                        return 1
                    fi
                    
                    # Update last non-whitespace token
                    if [ "$token" != "" ]; then
                        last_non_ws_token="$token"
                    fi
                    
                    # Update param list depth
                    case "$token" in
                        '(') 
                            if $in_param_list; then
                                ((param_paren_depth++))
                            fi
                            ;;
                        ')') 
                            if $in_param_list && [ $param_paren_depth -gt 0 ]; then
                                ((param_paren_depth--))
                            fi
                            ;;
                    esac
                    
                    # Reset arrow context on certain tokens
                    if [ "$token" = ";" ] || [ "$token" = "}" ] || [ "$token" = "{" ]; then
                        if ! $in_block_body; then
                            in_arrow_context=false
                            expecting_arrow=false
                            expecting_expression_after_arrow=false
                            in_async_context=false
                        fi
                    fi
                fi
            fi
            
            ((col++))
        done
        
        # Reset for new line
        if $in_comment_single; then
            in_comment_single=false
        fi
        
        # Check for unterminated arrow function at end of line
        if $in_arrow_context && $expecting_expression_after_arrow && [ $col -ge $line_length ]; then
            echo -e "${RED}Error at line $line_number, column $((col+1)): Missing function body after arrow${NC}"
            echo "  $line"
            printf "%*s^%s\n" $col "" "${RED}here${NC}"
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
    
    # Check for unterminated parameter list
    if $in_param_list && [ $param_paren_depth -gt 0 ]; then
        echo -e "${RED}Error: Unterminated parameter list${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    # Check for unterminated block body
    if $in_block_body && [ $block_brace_depth -gt 0 ]; then
        echo -e "${RED}Error: Unterminated block body${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    return 0
}

# Function to audit a single JavaScript file for arrow function errors
audit_js_file() {
    local filename="$1"
    
    if [ ! -f "$filename" ]; then
        echo -e "${RED}Error: File '$filename' not found${NC}"
        return 1
    fi
    
    if [[ ! "$filename" =~ \.js$ ]]; then
        echo -e "${YELLOW}Warning: File '$filename' doesn't have .js extension${NC}"
    fi
    
    echo -e "${CYAN}Auditing arrow functions in:${NC} ${filename}"
    echo "========================================"
    
    # Check file size
    local file_size=$(wc -c < "$filename")
    if [ $file_size -eq 0 ]; then
        echo -e "${GREEN}✓ Empty file - no errors${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    fi
    
    # Run our arrow function syntax checker
    if check_arrow_function_syntax "$filename"; then
        echo -e "${GREEN}✓ No arrow function syntax errors found${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running Arrow Function Syntax Error Test Suite${NC}"
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
