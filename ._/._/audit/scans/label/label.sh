#!/bin/bash

# JavaScript Label Syntax Error Auditor - Pure Bash Implementation
# Usage: ./label.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="1.0.0"
TEST_DIR="label_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Reserved JavaScript keywords (including strict mode reserved words)
RESERVED_WORDS="break case catch class const continue debugger default delete do else enum export extends false finally for function if import in instanceof new null return super switch this throw true try typeof var void while with yield let static implements interface package private protected public as async await get set from of"

# Strict mode reserved words
STRICT_RESERVED_WORDS="implements interface let package private protected public static yield"

# Function to display usage
show_usage() {
    echo -e "${BLUE}JavaScript Label Syntax Error Auditor v${AUDIT_SCRIPT_VERSION}${NC}"
    echo "Pure bash implementation - No Node.js required"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Audit a specific JavaScript file for label syntax errors"
    echo "  --test           Run test suite against known label error patterns"
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

# Function to check if character is valid for label name (not first char)
is_valid_label_char() {
    local char="$1"
    case "$char" in
        [a-zA-Z0-9_]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to check if character can start a label name
is_valid_label_start() {
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

# Function to check if token is a strict mode reserved word
is_strict_reserved_word() {
    local token="$1"
    for word in $STRICT_RESERVED_WORDS; do
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
            # Operators
            '+'|'-'|'*'|'/'|'%'|'&'|'|'|'^'|'!'|'='|'<'|'>')
                token="$char"
                ((pos++))
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
                if is_valid_label_start "$char"; then
                    while [ $pos -lt $length ] && (is_valid_label_char "${line:$pos:1}" || [ "${line:$pos:1}" = "$" ]); do
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

# Function to check for label syntax errors in JavaScript code
check_label_syntax() {
    local filename="$1"
    local line_number=0
    local in_comment_single=false
    local in_comment_multi=false
    local in_string_single=false
    local in_string_double=false
    local in_template=false
    local in_regex=false
    local in_strict_mode=false
    local last_token=""
    local last_non_ws_token=""
    local last_label=""
    local expecting_label_colon=false
    local label_declared=false
    local in_function=false
    local in_loop=false
    local in_switch=false
    local in_block=false
    local in_try_block=false
    local in_catch_block=false
    local label_stack=()  # Stack of declared labels
    local label_scopes=() # Stack of scope depths for labels
    
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
                    if [ "$next_char" = '/' ]; then
                        in_comment_single=true
                        ((col++))
                    elif [ "$next_char" = '*' ]; then
                        in_comment_multi=true
                        ((col++))
                    elif ! $in_regex; then
                        local is_regex=true
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
            
            # Check for strict mode directive
            if ! $in_string_single && ! $in_string_double && ! $in_template && \
               ! $in_comment_single && ! $in_comment_multi && ! $in_regex; then
                if [ "$char" = '"' ] || [ "$char" = "'" ]; then
                    local directive=""
                    local dir_start=$col
                    ((col++))
                    while [ $col -lt $line_length ] && [ "${line:$col:1}" != "$char" ]; do
                        directive="${directive}${line:$col:1}"
                        ((col++))
                    done
                    if [ "$directive" = "use strict" ]; then
                        in_strict_mode=true
                    fi
                fi
            fi
            
            # Only check syntax if not inside string/comment/regex
            if ! $in_string_single && ! $in_string_double && ! $in_template && \
               ! $in_comment_single && ! $in_comment_multi && ! $in_regex; then
                # Get current token
                local token
                token_length=0
                token=$(get_token "$line" $col)
                token_length=${#token}
                
                if [ -n "$token" ] && [ "$token_length" -gt 0 ]; then
                    # Update column position
                    ((col += token_length - 1))
                    
                    # Check for label declarations (identifier followed by colon)
                    if [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && [ "$next_char" = ":" ]; then
                        local label_name="$token"
                        local label_line=$line_number
                        local label_col=$((col - token_length + 2))
                        
                        # Check for invalid label names
                        if is_reserved_word "$label_name"; then
                            echo -e "${RED}Error at line $label_line, column $label_col: Reserved word '$label_name' cannot be used as label${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((label_col-1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                        
                        if $in_strict_mode && is_strict_reserved_word "$label_name"; then
                            echo -e "${RED}Error at line $label_line, column $label_col: Strict mode reserved word '$label_name' cannot be used as label${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((label_col-1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                        
                        if is_number "${label_name:0:1}"; then
                            echo -e "${RED}Error at line $label_line, column $label_col: Label cannot start with number '$label_name'${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((label_col-1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                        
                        # Check for duplicate label in same scope
                        local scope_depth=${#label_stack[@]}
                        for ((i=0; i<${#label_stack[@]}; i++)); do
                            if [ "${label_stack[$i]}" = "$label_name" ] && [ "${label_scopes[$i]}" -eq $scope_depth ]; then
                                echo -e "${RED}Error at line $label_line, column $label_col: Duplicate label '$label_name' in same scope${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((label_col-1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                        done
                        
                        # Add label to stack
                        label_stack+=("$label_name")
                        label_scopes+=($scope_depth)
                        last_label="$label_name"
                        expecting_label_colon=true
                    fi
                    
                    # Check for colon after label
                    if [ "$token" = ":" ] && $expecting_label_colon; then
                        expecting_label_colon=false
                        label_declared=true
                        
                        # Look ahead to see what follows the label
                        local lookahead_col=$((col+1))
                        local found_valid=false
                        while [ $lookahead_col -lt $line_length ]; do
                            local next_tok_char="${line:$lookahead_col:1}"
                            if is_whitespace "$next_tok_char"; then
                                ((lookahead_col++))
                                continue
                            fi
                            
                            # Get the next token after colon
                            local next_token=$(get_token "$line" $lookahead_col)
                            
                            # Check if labeled statement is valid
                            case "$next_token" in
                                'for'|'while'|'do')
                                    # Valid loop label
                                    in_loop=true
                                    found_valid=true
                                    break
                                    ;;
                                '{')
                                    # Valid block label
                                    in_block=true
                                    found_valid=true
                                    break
                                    ;;
                                ';')
                                    # Empty statement after label - INVALID
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Label '$last_label' with empty statement${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                    ;;
                                'function')
                                    if $in_strict_mode; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Cannot label function declaration in strict mode${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                    # In non-strict mode, function label might be allowed
                                    found_valid=true
                                    break
                                    ;;
                                'if'|'switch'|'try'|'with'|'debugger'|'return'|'throw'|'break'|'continue')
                                    # These cannot be labeled
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Cannot label '$next_token' statement${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                    ;;
                                'class'|'const'|'let'|'var'|'import'|'export')
                                    # These cannot be labeled
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Cannot label '$next_token' declaration${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                    ;;
                                *)
                                    # Check if it's an expression statement
                                    if [[ "$next_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] || \
                                       [[ "$next_token" =~ ^[0-9] ]] || \
                                       [ "$next_token" = "(" ] || [ "$next_token" = "[" ] || \
                                       [ "$next_token" = "{" ] || [ "$next_token" = "++" ] || \
                                       [ "$next_token" = "--" ] || [ "$next_token" = "+" ] || \
                                       [ "$next_token" = "-" ] || [ "$next_token" = "!" ] || \
                                       [ "$next_token" = "~" ] || [ "$next_token" = "typeof" ] || \
                                       [ "$next_token" = "void" ] || [ "$next_token" = "delete" ] || \
                                       [ "$next_token" = "new" ] || [ "$next_token" = "await" ] || \
                                       [ "$next_token" = "yield" ]; then
                                        # Expression statement - INVALID for labels
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Label '$last_label' on expression statement${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                    ;;
                            esac
                            
                            break
                        done
                        
                        # If nothing follows the label (end of line)
                        if ! $found_valid && [ $lookahead_col -ge $line_length ]; then
                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Label '$last_label' without statement${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                    fi
                    
                    # Check for break/continue with labels
                    if [ "$token" = "break" ] || [ "$token" = "continue" ]; then
                        # Look ahead for optional label
                        local lookahead_col=$((col+1))
                        while [ $lookahead_col -lt $line_length ] && is_whitespace "${line:$lookahead_col:1}"; do
                            ((lookahead_col++))
                        done
                        
                        if [ $lookahead_col -lt $line_length ]; then
                            local next_token=$(get_token "$line" $lookahead_col)
                            if [[ "$next_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                # This is a labeled break/continue
                                local label_name="$next_token"
                                local label_found=false
                                
                                # Search for the label in stack
                                for ((i=0; i<${#label_stack[@]}; i++)); do
                                    if [ "${label_stack[$i]}" = "$label_name" ]; then
                                        label_found=true
                                        
                                        # Check context for continue
                                        if [ "$token" = "continue" ] && ! $in_loop; then
                                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'continue' can only reference loop labels${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                            echo "$(realpath "$filename")"
                                            return 1
                                        fi
                                        
                                        break
                                    fi
                                done
                                
                                if ! $label_found; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Undefined label '$label_name'${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                        fi
                    fi
                    
                    # Check for multiple labels on same statement
                    if [ "$token" = ":" ] && [ "$last_non_ws_token" = ":" ]; then
                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Multiple labels on same statement${NC}"
                        echo "  $line"
                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                        echo "$(realpath "$filename")"
                        return 1
                    fi
                    
                    # Update context based on tokens
                    case "$token" in
                        '{')
                            # Entering a block
                            in_block=true
                            ;;
                        '}')
                            # Exiting a block
                            in_block=false
                            # Remove labels from this scope
                            local scope_depth=${#label_stack[@]}
                            for ((i=${#label_stack[@]}-1; i>=0; i--)); do
                                if [ "${label_scopes[$i]}" -eq $scope_depth ]; then
                                    unset label_stack[$i]
                                    unset label_scopes[$i]
                                fi
                            done
                            # Reindex arrays
                            label_stack=("${label_stack[@]}")
                            label_scopes=("${label_scopes[@]}")
                            ;;
                        'function')
                            in_function=true
                            ;;
                        'for'|'while'|'do')
                            in_loop=true
                            ;;
                        'switch')
                            in_switch=true
                            ;;
                        'try')
                            in_try_block=true
                            ;;
                        'catch')
                            in_catch_block=true
                            in_try_block=false
                            ;;
                        'finally')
                            in_catch_block=false
                            ;;
                    esac
                    
                    # Update last non-whitespace token
                    if [ "$token" != "" ]; then
                        last_non_ws_token="$token"
                    fi
                fi
            fi
            
            ((col++))
        done
        
        # Reset for new line
        if $in_comment_single; then
            in_comment_single=false
        fi
        
        # Check for label without statement at end of line
        if $label_declared && [ $col -ge $line_length ]; then
            # Look at next line to see if there's a statement
            # This is simplified - in reality we'd need to parse multiple lines
            echo -e "${YELLOW}Warning at line $line_number: Label '$last_label' might be missing statement${NC}"
            label_declared=false
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
    
    return 0
}

# Function to audit a single JavaScript file for label errors
audit_js_file() {
    local filename="$1"
    
    if [ ! -f "$filename" ]; then
        echo -e "${RED}Error: File '$filename' not found${NC}"
        return 1
    fi
    
    if [[ ! "$filename" =~ \.js$ ]]; then
        echo -e "${YELLOW}Warning: File '$filename' doesn't have .js extension${NC}"
    fi
    
    echo -e "${CYAN}Auditing for Label Syntax Errors:${NC} ${filename}"
    echo "========================================"
    
    # Check file size
    local file_size=$(wc -c < "$filename")
    if [ $file_size -eq 0 ]; then
        echo -e "${GREEN}✓ Empty file - no errors${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    fi
    
    # Run our label syntax checker
    if check_label_syntax "$filename"; then
        echo -e "${GREEN}✓ No label syntax errors found${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running JavaScript Label Syntax Error Test Suite${NC}"
    echo "========================================"
    
    # Check if test directory exists, if not run tests.sh to generate it
    if [ ! -d "$TEST_DIR" ]; then
        echo -e "${YELLOW}Test directory '$TEST_DIR' not found.${NC}"
        echo -e "${CYAN}Attempting to generate test directory...${NC}"
        
        # Check if tests.sh exists in the current directory
        if [ -f "tests.sh" ]; then
            echo -e "${CYAN}Running tests.sh to generate test files...${NC}"
            bash tests.sh
            
            # Check again if test directory was created
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
            echo -e "${GREEN}  ✓ Correctly detected label error${NC}"
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
