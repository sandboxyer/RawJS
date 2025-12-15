#!/bin/bash

# JavaScript Token Error Auditor - Pure Bash Implementation
# Usage: ./basics.sh <filename.js> [--test]

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

# Function to check if character is valid for variable name
is_valid_var_char() {
    local char="$1"
    case "$char" in
        [a-zA-Z0-9_$]) return 0 ;;
        *) return 1 ;;
    esac
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
    local last_char=""
    
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
            local prev_char=""
            [ $col -gt 0 ] && prev_char="${line:$((col-1)):1}"
            
            # Check for string/comment/regex contexts
            if ! $in_comment_single && ! $in_comment_multi; then
                # Check for string/template literal start
                if [ "$char" = "'" ] && ! $in_string_double && ! $in_template; then
                    if $in_string_single; then
                        in_string_single=false
                    else
                        in_string_single=true
                    fi
                elif [ "$char" = '"' ] && ! $in_string_single && ! $in_template; then
                    if $in_string_double; then
                        in_string_double=false
                    else
                        in_string_double=true
                    fi
                elif [ "$char" = '`' ] && ! $in_string_single && ! $in_string_double; then
                    if $in_template; then
                        in_template=false
                    else
                        in_template=true
                    fi
                elif [ "$char" = '/' ] && ! $in_string_single && ! $in_string_double && ! $in_template && ! $in_regex; then
                    # Could be division, comment, or regex
                    if [ "$next_char" = '/' ]; then
                        in_comment_single=true
                        ((col++))
                    elif [ "$next_char" = '*' ]; then
                        in_comment_multi=true
                        ((col++))
                    elif [ -z "$last_char" ] || \
                         [ "$last_char" = "=" ] || \
                         [ "$last_char" = "+" ] || \
                         [ "$last_char" = "-" ] || \
                         [ "$last_char" = "*" ] || \
                         [ "$last_char" = "/" ] || \
                         [ "$last_char" = "%" ] || \
                         [ "$last_char" = "&" ] || \
                         [ "$last_char" = "|" ] || \
                         [ "$last_char" = "^" ] || \
                         [ "$last_char" = "~" ] || \
                         [ "$last_char" = "!" ] || \
                         [ "$last_char" = "?" ] || \
                         [ "$last_char" = ":" ] || \
                         [ "$last_char" = "," ] || \
                         [ "$last_char" = "(" ] || \
                         [ "$last_char" = "[" ]; then
                        in_regex=true
                    fi
                elif [ "$char" = '*' ] && $in_comment_multi && [ "$next_char" = '/' ]; then
                    in_comment_multi=false
                    ((col++))
                fi
            else
                # Inside comments
                if $in_comment_single; then
                    # Single line comment - skip to end of line
                    break
                elif $in_comment_multi && [ "$char" = '*' ] && [ "$next_char" = '/' ]; then
                    in_comment_multi=false
                    ((col++))
                fi
            fi
            
            # Only check syntax if not inside string/comment/regex
            if ! $in_string_single && ! $in_string_double && ! $in_template && ! $in_comment_single && ! $in_comment_multi && ! $in_regex; then
                # Check for unterminated constructs
                case "$char" in
                    '{') ((brace_count++)) ;;
                    '}') ((brace_count--)) ;;
                    '[') ((bracket_count++)) ;;
                    ']') ((bracket_count--)) ;;
                    '(') ((paren_count++)) ;;
                    ')') ((paren_count--)) ;;
                esac
                
                # Check for specific token errors
                # Check for lonely semicolon
                if [ "$char" = ";" ]; then
                    local is_lonely=true
                    
                    # Check if previous character is whitespace, semicolon, or brace
                    if [ $col -gt 0 ]; then
                        local before_char="${line:$((col-1)):1}"
                        if [ "$before_char" = ";" ] || [ "$before_char" = "{" ] || [ "$before_char" = "}" ]; then
                            is_lonely=true
                        elif is_whitespace "$before_char"; then
                            # Check what's before the whitespace
                            local i=$((col-2))
                            while [ $i -ge 0 ] && is_whitespace "${line:$i:1}"; do
                                ((i--))
                            done
                            if [ $i -ge 0 ]; then
                                local non_ws_char="${line:$i:1}"
                                if [ "$non_ws_char" = ";" ] || [ "$non_ws_char" = "{" ] || [ "$non_ws_char" = "}" ]; then
                                    is_lonely=true
                                else
                                    is_lonely=false
                                fi
                            fi
                        else
                            is_lonely=false
                        fi
                    fi
                    
                    if $is_lonely; then
                        echo -e "${RED}Error at line $line_number, column $((col+1)): Unexpected semicolon${NC}"
                        echo "  $line"
                        printf "%*s^%s\n" $col "" "${RED}here${NC}"
                        return 1
                    fi
                fi
                
                # Check for double commas
                if [ "$char" = "," ]; then
                    if [ "$last_char" = "," ] || [ "$last_char" = "{" ] || [ "$last_char" = "[" ]; then
                        echo -e "${RED}Error at line $line_number, column $((col+1)): Unexpected comma${NC}"
                        echo "  $line"
                        printf "%*s^%s\n" $col "" "${RED}here${NC}"
                        return 1
                    fi
                fi
                
                # Check for invalid variable names starting with numbers
                if [[ "$char" =~ [0-9] ]] && [ $col -eq 0 ] || [ $col -gt 0 ] && is_whitespace "$prev_char"; then
                    # Check if this is a number followed by letters (invalid variable)
                    local temp_col=$col
                    local token=""
                    while [ $temp_col -lt $line_length ] && is_valid_var_char "${line:$temp_col:1}"; do
                        token="${token}${line:$temp_col:1}"
                        ((temp_col++))
                    done
                    
                    # Check if token starts with number and has letters after
                    if [[ "$token" =~ ^[0-9]+[a-zA-Z_$] ]]; then
                        echo -e "${RED}Error at line $line_number, column $((col+1)): Invalid variable name starting with number${NC}"
                        echo "  $line"
                        printf "%*s^%s\n" $col "" "${RED}starts here${NC}"
                        return 1
                    fi
                fi
                
                # Update last_char
                last_char="$char"
            fi
            
            ((col++))
        done
        
        # Reset for new line
        if $in_comment_single; then
            in_comment_single=false
        fi
        last_char=""
        
    done < "$filename"
    
    # Check for unterminated constructs
    if $in_string_single; then
        echo -e "${RED}Error: Unterminated single-quoted string${NC}"
        return 1
    fi
    if $in_string_double; then
        echo -e "${RED}Error: Unterminated double-quoted string${NC}"
        return 1
    fi
    if $in_template; then
        echo -e "${RED}Error: Unterminated template literal${NC}"
        return 1
    fi
    if $in_comment_multi; then
        echo -e "${RED}Error: Unterminated multi-line comment${NC}"
        return 1
    fi
    if $in_regex; then
        echo -e "${RED}Error: Unterminated regular expression${NC}"
        return 1
    fi
    
    # Check bracket/brace/paren counts
    if [ $brace_count -gt 0 ]; then
        echo -e "${RED}Error: Unclosed { (missing } )${NC}"
        return 1
    elif [ $brace_count -lt 0 ]; then
        echo -e "${RED}Error: Unexpected } (extra closing brace)${NC}"
        return 1
    fi
    
    if [ $bracket_count -gt 0 ]; then
        echo -e "${RED}Error: Unclosed [ (missing ] )${NC}"
        return 1
    elif [ $bracket_count -lt 0 ]; then
        echo -e "${RED}Error: Unexpected ] (extra closing bracket)${NC}"
        return 1
    fi
    
    if [ $paren_count -gt 0 ]; then
        echo -e "${RED}Error: Unclosed ( (missing ) )${NC}"
        return 1
    elif [ $paren_count -lt 0 ]; then
        echo -e "${RED}Error: Unexpected ) (extra closing parenthesis)${NC}"
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
