#!/bin/bash

# JavaScript Object Literal Error Auditor - Pure Bash Implementation
# Usage: ./object.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="1.0.0"
TEST_DIR="object_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display usage
show_usage() {
    echo -e "${BLUE}JavaScript Object Literal Error Auditor v${AUDIT_SCRIPT_VERSION}${NC}"
    echo "Pure bash implementation - No Node.js required"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Audit a specific JavaScript file for object literal errors"
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
            # Operators
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
            # Strings
            "'"|'"'|'`')
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
            # Identifiers and numbers
            *)
                # Check for spread/rest operator
                if [ "$char" = "." ] && [ $((pos+2)) -lt $length ]; then
                    if [ "${line:$((pos+1)):1}" = "." ] && [ "${line:$((pos+2)):1}" = "." ]; then
                        token="..."
                        ((pos+=3))
                    else
                        token="$char"
                        ((pos++))
                    fi
                elif [[ "$char" =~ [a-zA-Z_$] ]]; then
                    while [ $pos -lt $length ] && [[ "${line:$pos:1}" =~ [a-zA-Z0-9_$] ]]; do
                        ((pos++))
                    done
                elif [[ "$char" =~ [0-9] ]]; then
                    while [ $pos -lt $length ] && ([[ "${line:$pos:1}" =~ [0-9] ]] || 
                           [ "${line:$pos:1}" = "." ] || 
                           [ "${line:$pos:1}" = "e" ] || 
                           [ "${line:$pos:1}" = "E" ] ||
                           [ "${line:$pos:1}" = "x" ] ||
                           [ "${line:$pos:1}" = "X" ] ||
                           [ "${line:$pos:1}" = "o" ] ||
                           [ "${line:$pos:1}" = "O" ] ||
                           [ "${line:$pos:1}" = "b" ] ||
                           [ "${line:$pos:1}" = "B" ]); do
                        ((pos++))
                    done
                else
                    token="$char"
                    ((pos++))
                fi
                ;;
        esac
        
        token="${line:$start:$((pos-start))}"
    fi
    
    echo "$token"
}

# Function to check if token is a number
is_number() {
    local token="$1"
    [[ "$token" =~ ^[0-9]+$ ]] || 
    [[ "$token" =~ ^[0-9]+\.[0-9]*$ ]] || 
    [[ "$token" =~ ^\.[0-9]+$ ]] ||
    [[ "$token" =~ ^0[xX][0-9a-fA-F]+$ ]] ||
    [[ "$token" =~ ^0[oO][0-7]+$ ]] ||
    [[ "$token" =~ ^0[bB][01]+$ ]] ||
    [[ "$token" =~ ^[0-9]+[eE][+-]?[0-9]+$ ]]
}

# Function to check if token is a valid identifier
is_identifier() {
    local token="$1"
    [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]
}

# Function to check if token is a string literal
is_string() {
    local token="$1"
    [[ "$token" =~ ^[\"\'].*[\"\']$ ]]
}

# Main function to check object literal syntax
check_object_syntax() {
    local filename="$1"
    local line_number=0
    local in_object=false
    local object_depth=0
    local in_array=false
    local array_depth=0
    local in_string=false
    local string_char=""
    local in_template=false
    local in_comment_single=false
    local in_comment_multi=false
    local expecting_key=true
    local expecting_colon=false
    local expecting_value=false
    local expecting_comma=false
    local last_token=""
    local last_non_ws_token=""
    local in_computed_key=false
    local computed_depth=0
    local in_method=false
    local in_getter_setter=false
    local in_spread=false
    local property_stack=()
    
    # State for method parsing
    local in_method_params=false
    local method_param_depth=0
    local in_async_method=false
    local in_generator_method=false
    
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_number++))
        local col=0
        local line_length=${#line}
        
        while [ $col -lt $line_length ]; do
            local char="${line:$col:1}"
            local next_char=""
            [ $((col+1)) -lt $line_length ] && next_char="${line:$((col+1)):1}"
            
            # Handle comments and strings
            if ! $in_comment_single && ! $in_comment_multi; then
                if [ "$char" = "'" ] && ! $in_string && ! $in_template && ! $in_computed_key; then
                    in_string=true
                    string_char="'"
                elif [ "$char" = '"' ] && ! $in_string && ! $in_template && ! $in_computed_key; then
                    in_string=true
                    string_char='"'
                elif [ "$char" = '`' ] && ! $in_string && ! $in_template && ! $in_computed_key; then
                    in_template=true
                elif [ "$char" = '/' ] && ! $in_string && ! $in_template; then
                    if [ "$next_char" = '/' ]; then
                        in_comment_single=true
                        ((col++))
                    elif [ "$next_char" = '*' ]; then
                        in_comment_multi=true
                        ((col++))
                    fi
                fi
            fi
            
            # End string/template
            if $in_string && [ "$char" = "$string_char" ]; then
                # Check for escape
                local escaped=false
                local check_col=$((col-1))
                while [ $check_col -ge 0 ] && [ "${line:$check_col:1}" = "\\" ]; do
                    escaped=$(! $escaped)
                    ((check_col--))
                done
                if ! $escaped; then
                    in_string=false
                fi
            fi
            
            if $in_template && [ "$char" = '`' ]; then
                in_template=false
            fi
            
            # End comments
            if $in_comment_multi && [ "$char" = '*' ] && [ "$next_char" = '/' ]; then
                in_comment_multi=false
                ((col++))
            fi
            
            # Only process syntax if not in string/comment
            if ! $in_string && ! $in_template && ! $in_comment_single && ! $in_comment_multi; then
                # Get token
                local token
                token=$(get_token "$line" $col)
                local token_length=${#token}
                
                if [ -n "$token" ]; then
                    ((col += token_length - 1))
                    
                    # Debug: Uncomment to see token parsing
                    # echo "Line $line_number, Col $col: Token='$token', in_object=$in_object, expecting_key=$expecting_key"
                    
                    # Handle object context
                    if [ "$token" = "{" ]; then
                        if ! $in_computed_key; then
                            if $in_object; then
                                ((object_depth++))
                            else
                                in_object=true
                                object_depth=1
                                expecting_key=true
                                expecting_comma=false
                                in_spread=false
                            fi
                        else
                            ((computed_depth++))
                        fi
                    elif [ "$token" = "}" ]; then
                        if ! $in_computed_key; then
                            if $in_object; then
                                ((object_depth--))
                                if [ $object_depth -eq 0 ]; then
                                    in_object=false
                                    expecting_key=false
                                    expecting_colon=false
                                    expecting_value=false
                                    expecting_comma=false
                                    in_method=false
                                    in_getter_setter=false
                                    in_async_method=false
                                    in_generator_method=false
                                fi
                            fi
                        else
                            ((computed_depth--))
                            if [ $computed_depth -eq 0 ]; then
                                in_computed_key=false
                            fi
                        fi
                    elif [ "$token" = "[" ]; then
                        if $in_object && $expecting_key && ! $in_computed_key && ! $in_method && ! $in_getter_setter; then
                            in_computed_key=true
                            computed_depth=1
                        elif $in_computed_key; then
                            ((computed_depth++))
                        fi
                    elif [ "$token" = "]" ]; then
                        if $in_computed_key; then
                            ((computed_depth--))
                            if [ $computed_depth -eq 0 ]; then
                                in_computed_key=false
                                expecting_colon=true
                                expecting_key=false
                            fi
                        fi
                    
                    # Inside object literal checks
                    elif $in_object; then
                        case "$token" in
                            # Check for leading comma
                            ',')
                                if $expecting_key && ! $in_spread; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected comma (leading comma)${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    return 1
                                fi
                                if $expecting_colon || $expecting_value; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected comma (missing value)${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    return 1
                                fi
                                expecting_comma=false
                                expecting_key=true
                                expecting_colon=false
                                expecting_value=false
                                in_spread=false
                                in_method=false
                                in_getter_setter=false
                                in_async_method=false
                                in_generator_method=false
                                ;;
                                
                            # Check for colon errors
                            ':')
                                if ! $expecting_colon; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected colon${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    return 1
                                fi
                                expecting_colon=false
                                expecting_value=true
                                ;;
                                
                            # Check for double colon
                            '::')
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected double colon${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                return 1
                                ;;
                                
                            # Check for spread operator
                            '...')
                                if ! $expecting_key && ! $expecting_value; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid spread operator position${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    return 1
                                fi
                                in_spread=true
                                expecting_value=true
                                expecting_key=false
                                ;;
                                
                            # Check getter/setter keywords
                            'get'|'set')
                                if $expecting_key; then
                                    in_getter_setter=true
                                    expecting_colon=false
                                    expecting_value=false
                                else
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): '$token' in wrong position${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    return 1
                                fi
                                ;;
                                
                            # Check async keyword
                            'async')
                                if $expecting_key; then
                                    in_async_method=true
                                fi
                                ;;
                                
                            # Check generator star
                            '*')
                                if $expecting_key && ($in_async_method || [ "$last_non_ws_token" = "" ] || [ "$last_non_ws_token" = "," ] || [ "$last_non_ws_token" = "{" ]); then
                                    in_generator_method=true
                                elif $in_object && ! $in_computed_key; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected '*' in object literal${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    return 1
                                fi
                                ;;
                                
                            # Check for method definitions
                            '(')
                                if $in_getter_setter || $in_async_method || $in_generator_method || 
                                   ($expecting_key && (is_identifier "$last_non_ws_token" || is_string "$last_non_ws_token" || is_number "$last_non_ws_token")); then
                                    in_method=true
                                    expecting_colon=false
                                    expecting_value=false
                                fi
                                ;;
                                
                            # Check for equals sign (common mistake)
                            '=')
                                if $expecting_colon; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Expected ':' but found '='${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    return 1
                                fi
                                ;;
                                
                            # Regular property checks
                            *)
                                # If we're expecting a key
                                if $expecting_key && ! $in_spread; then
                                    # Check for invalid property names
                                    if [ "$token" = "." ] && is_number "$last_non_ws_token"; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid numeric property with trailing dot${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        return 1
                                    fi
                                    
                                    # Check for shorthand property (identifier without colon)
                                    if is_identifier "$token" && ! $in_getter_setter && ! $in_async_method && ! $in_generator_method; then
                                        # Look ahead for colon
                                        local lookahead=$((col+1))
                                        local found_colon=false
                                        while [ $lookahead -lt $line_length ]; do
                                            local next_tok=$(get_token "$line" $lookahead)
                                            if [ "$next_tok" = ":" ]; then
                                                found_colon=true
                                                break
                                            elif [ "$next_tok" = "," ] || [ "$next_tok" = "}" ] || [ "$next_tok" = "(" ]; then
                                                break
                                            fi
                                            ((lookahead++))
                                        done
                                        
                                        if ! $found_colon; then
                                            # This is a shorthand property, valid
                                            expecting_key=false
                                            expecting_comma=true
                                            expecting_colon=false
                                            expecting_value=false
                                        else
                                            expecting_colon=true
                                        fi
                                    elif is_string "$token" || is_number "$token"; then
                                        expecting_colon=true
                                    else
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid property name '${token}'${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        return 1
                                    fi
                                
                                # If we're expecting a value
                                elif $expecting_value; then
                                    # Value found, now expect comma or closing brace
                                    expecting_value=false
                                    expecting_comma=true
                                    expecting_key=false
                                    in_spread=false
                                
                                # If we get an identifier when expecting nothing
                                elif is_identifier "$token" && ! $expecting_comma && ! $expecting_key && ! $expecting_value; then
                                    if [ "$last_non_ws_token" != "," ] && [ "$last_non_ws_token" != "{" ]; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected identifier '${token}'${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        return 1
                                    fi
                                fi
                                ;;
                        esac
                    fi
                    
                    # Update last token
                    if [ -n "$token" ] && [ "$token" != " " ] && [ "$token" != $'\t' ] && [ "$token" != $'\n' ] && [ "$token" != $'\r' ]; then
                        last_non_ws_token="$token"
                    fi
                fi
            fi
            
            # End single-line comment at line end
            if $in_comment_single; then
                in_comment_single=false
            fi
            
            ((col++))
        done
        
        # Reset single-line comment
        if $in_comment_single; then
            in_comment_single=false
        fi
        
    done < "$filename"
    
    # Final checks
    if $in_object; then
        echo -e "${RED}Error: Unclosed object literal${NC}"
        return 1
    fi
    
    if $in_computed_key; then
        echo -e "${RED}Error: Unclosed computed property${NC}"
        return 1
    fi
    
    if $in_string; then
        echo -e "${RED}Error: Unclosed string literal${NC}"
        return 1
    fi
    
    if $in_template; then
        echo -e "${RED}Error: Unclosed template literal${NC}"
        return 1
    fi
    
    return 0
}

# Function to audit a single JavaScript file for object literal errors
audit_js_file() {
    local filename="$1"
    
    if [ ! -f "$filename" ]; then
        echo -e "${RED}Error: File '$filename' not found${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Auditing object literals in:${NC} ${filename}"
    echo "========================================"
    
    # Check file size
    local file_size=$(wc -c < "$filename")
    if [ $file_size -eq 0 ]; then
        echo -e "${GREEN}✓ Empty file - no errors${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    fi
    
    # Run our object literal syntax checker
    if check_object_syntax "$filename"; then
        echo -e "${GREEN}✓ No object literal syntax errors found${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running Object Literal Syntax Error Test Suite${NC}"
    echo "========================================"
    
    # Check if test directory exists, if not run tests.sh to generate it
    if [ ! -d "$TEST_DIR" ]; then
        echo -e "${YELLOW}Test directory '$TEST_DIR' not found.${NC}"
        echo -e "${CYAN}Attempting to generate test directory with tests.sh...${NC}"
        
        # Check if tests.sh exists in the current directory
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
            echo -e "${RED}tests.sh not found in current directory.${NC}"
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
