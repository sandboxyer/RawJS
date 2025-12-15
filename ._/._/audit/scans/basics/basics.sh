#!/bin/bash

# JavaScript Token Error Auditor - Pure Bash Implementation
# Usage: ./basics.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="2.0.0"
TEST_DIR="basics_tests"

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
    echo -e "${BLUE}JavaScript Token Error Auditor v${AUDIT_SCRIPT_VERSION}${NC}"
    echo "Pure bash implementation - No Node.js required"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Audit a specific JavaScript file for token errors"
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
    return $((pos-start))
}

# Function to check for token errors in JavaScript code
check_js_syntax() {
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
                            ')'|']'|'++'|'--'|'identifier'|'number'|'string')
                                is_regex=false
                                ;;
                            '}')
                                # Could be object literal or block
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
                    
                    # Check for specific token errors
                    case "$token" in
                        # Check for invalid variable declarations
                        'const'|'let'|'var')
                            if [ "$last_non_ws_token" != "" ] && [ "$last_non_ws_token" != ";" ] && \
                               [ "$last_non_ws_token" != "{" ] && [ "$last_non_ws_token" != "}" ] && \
                               [ "$last_non_ws_token" != "(" ] && [ "$last_non_ws_token" != ")" ] && \
                               [ "$last_non_ws_token" != ":" ] && [ "$last_non_ws_token" != "," ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected '$token'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for lonely semicolon (semicolon without preceding expression)
                        ';')
                            if [ "$last_non_ws_token" = "" ] || \
                               [ "$last_non_ws_token" = ";" ] || \
                               [ "$last_non_ws_token" = "{" ] || \
                               [ "$last_non_ws_token" = "}" ] || \
                               [ "$last_non_ws_token" = ":" ] && [ "$expecting_expression" = true ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected semicolon${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            expecting_expression=false
                            expecting_operator=false
                            ;;
                            
                        # Check for double commas or comma in wrong place
                        ',')
                            if [ "$last_non_ws_token" = "" ] || \
                               [ "$last_non_ws_token" = "," ] || \
                               [ "$last_non_ws_token" = "{" ] || \
                               [ "$last_non_ws_token" = "[" ] || \
                               [ "$last_non_ws_token" = "(" ] || \
                               [ "$last_non_ws_token" = ";" ] || \
                               [ "$last_non_ws_token" = ":" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected comma${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            expecting_expression=true
                            expecting_operator=false
                            ;;
                            
                        # Check for invalid spread operator usage
                        '...')
                            if [ "$last_non_ws_token" != "" ] && [ "$last_non_ws_token" != "{" ] && \
                               [ "$last_non_ws_token" != "[" ] && [ "$last_non_ws_token" != "," ] && \
                               [ "$last_non_ws_token" != "(" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid spread operator${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for invalid operators
                        '++'|'--')
                            # Check if these are used as prefix/postfix correctly
                            if [ "$last_non_ws_token" != "" ] && [ "$last_non_ws_token" != ";" ] && \
                               [ "$last_non_ws_token" != "{" ] && [ "$last_non_ws_token" != "}" ] && \
                               [ "$last_non_ws_token" != "(" ] && [ "$last_non_ws_token" != ")" ] && \
                               [ "$last_non_ws_token" != "[" ] && [ "$last_non_ws_token" != "]" ] && \
                               [ "$last_non_ws_token" != "," ] && [ "$last_non_ws_token" != "=" ] && \
                               [ "$last_non_ws_token" != "+" ] && [ "$last_non_ws_token" != "-" ] && \
                               [ "$last_non_ws_token" != "*" ] && [ "$last_non_ws_token" != "/" ] && \
                               [ "$last_non_ws_token" != "%" ]; then
                                # Check if it's being used incorrectly (e.g., "5 ++")
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid use of '$token'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for incomplete exponent operator
                        '**')
                            if [ "$last_non_ws_token" = "" ] || [ "$expecting_operator" = true ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid exponent operator${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            expecting_expression=true
                            ;;
                            
                        # Check for lonely dots
                        '.')
                            if [ "$last_non_ws_token" = "" ] || \
                               [ "$last_non_ws_token" = "." ] || \
                               [ "$last_non_ws_token" = ";" ] || \
                               [ "$last_non_ws_token" = "{" ] || \
                               [ "$last_non_ws_token" = "}" ] || \
                               [ "$last_non_ws_token" = "(" ] || \
                               [ "$last_non_ws_token" = ")" ] || \
                               [ "$last_non_ws_token" = "[" ] || \
                               [ "$last_non_ws_token" = "]" ] || \
                               [ "$last_non_ws_token" = "," ] || \
                               [ "$last_non_ws_token" = ":" ] || \
                               [ "$last_non_ws_token" = "?" ] || \
                               [ "$last_non_ws_token" = "=>" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected dot${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for invalid optional chaining
                        '?.')
                            if [ "$last_non_ws_token" = "" ] || \
                               [ "$last_non_ws_token" = ";" ] || \
                               [ "$last_non_ws_token" = "{" ] || \
                               [ "$last_non_ws_token" = "}" ] || \
                               [ "$last_non_ws_token" = "(" ] || \
                               [ "$last_non_ws_token" = ")" ] || \
                               [ "$last_non_ws_token" = "[" ] || \
                               [ "$last_non_ws_token" = "]" ] || \
                               [ "$last_non_ws_token" = "," ] || \
                               [ "$last_non_ws_token" = ":" ] || \
                               [ "$last_non_ws_token" = "?" ] || \
                               [ "$last_non_ws_token" = "=>" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid optional chaining${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for reserved words as identifiers in wrong context
                        *)
                            # Check if token starts with a number
                            if [[ "$token" =~ ^[0-9] ]] && \
                               [ "$last_non_ws_token" = "const" ] || \
                               [ "$last_non_ws_token" = "let" ] || \
                               [ "$last_non_ws_token" = "var" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid variable name starting with number${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check for invalid characters in identifiers
                            if [[ "$token" =~ [@.#\-] ]] && \
                               [ "$last_non_ws_token" = "const" ] || \
                               [ "$last_non_ws_token" = "let" ] || \
                               [ "$last_non_ws_token" = "var" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid character in variable name${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check for reserved words as variable names
                            if is_reserved_word "$token" && \
                               [ "$last_non_ws_token" = "const" ] || \
                               [ "$last_non_ws_token" = "let" ] || \
                               [ "$last_non_ws_token" = "var" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Reserved word cannot be used as variable name${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                    esac
                    
                    # Update last non-whitespace token
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
    
    # Run our syntax checker
    if check_js_syntax "$filename"; then
        echo -e "${GREEN}✓ No syntax errors found${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running JavaScript Token Error Test Suite${NC}"
    echo "========================================"
    
    # Check if test directory exists
    if [ ! -d "$TEST_DIR" ]; then
        echo -e "${YELLOW}Test directory '$TEST_DIR' not found.${NC}"
        echo -e "${YELLOW}Please create test files in '$TEST_DIR/' directory first.${NC}"
        return 1
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
