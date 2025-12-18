#!/bin/bash

# JavaScript Template Literal Error Auditor - Pure Bash Implementation
# Usage: ./template.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="1.0.0"
TEST_DIR="template_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Reserved JavaScript keywords that can't be in expressions
RESERVED_WORDS_IN_EXPR="break case catch class const continue debugger default delete do else enum export extends finally for function if import in instanceof new return super switch this throw try typeof var void while with yield let static implements interface package private protected public as async await get set of"

# Function to display usage
show_usage() {
    echo -e "${BLUE}JavaScript Template Literal Error Auditor v${AUDIT_SCRIPT_VERSION}${NC}"
    echo "Pure bash implementation - No Node.js required"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Audit a specific JavaScript file for template literal errors"
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

# Function to check if character can start a variable name
is_valid_var_start() {
    local char="$1"
    case "$char" in
        [a-zA-Z_$]) return 0 ;;
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

# Function to check if token is a reserved word
is_reserved_word() {
    local token="$1"
    for word in $RESERVED_WORDS_IN_EXPR; do
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
            ';'|','|'.'|'('|')'|'{'|'}'|'['|']'|':'|'?'|'~'|'@'|'#')
                token="$char"
                ((pos++))
                ;;
            # Backtick - special handling for templates
            '`')
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
            # Strings and chars
            "'"|'"')
                token="$char"
                ((pos++))
                # Skip to end of string (simplified)
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

# Function to validate template literal expression
validate_template_expression() {
    local expr="$1"
    local line_num="$2"
    local col_num="$3"
    
    # Check for empty expression
    if [ -z "$expr" ]; then
        echo -e "${RED}Error at line $line_num, column $col_num: Empty template expression${NC}"
        return 1
    fi
    
    # Check for reserved words that can't start expressions
    local first_word=$(echo "$expr" | grep -o '^[a-zA-Z_$][a-zA-Z0-9_$]*' || echo "")
    if [ -n "$first_word" ] && is_reserved_word "$first_word"; then
        echo -e "${RED}Error at line $line_num, column $col_num: Invalid expression starting with reserved word '$first_word'${NC}"
        return 1
    fi
    
    # Check for statement keywords in expression
    if [[ "$expr" =~ [[:space:]]*(break|continue|debugger|do|for|if|return|switch|throw|try|while|with)[[:space:]] ]]; then
        echo -e "${RED}Error at line $line_num, column $col_num: Statement keyword '$BASH_REMATCH' in template expression${NC}"
        return 1
    fi
    
    # Check for declaration keywords
    if [[ "$expr" =~ [[:space:]]*(const|let|var|function|class)[[:space:]] ]]; then
        echo -e "${RED}Error at line $line_num, column $col_num: Declaration keyword '$BASH_REMATCH' in template expression${NC}"
        return 1
    fi
    
    # Check for import/export in expression
    if [[ "$expr" =~ [[:space:]]*(import|export)[[:space:]] ]]; then
        echo -e "${RED}Error at line $line_num, column $col_num: Module keyword '$BASH_REMATCH' in template expression${NC}"
        return 1
    fi
    
    return 0
}

# Function to check for template literal errors
check_template_syntax() {
    local filename="$1"
    local line_number=0
    local in_comment_single=false
    local in_comment_multi=false
    local in_string_single=false
    local in_string_double=false
    local in_template=false
    local in_template_expression=false
    local template_depth=0
    local expression_depth=0
    local expression_start_col=0
    local expression_line=0
    local last_token=""
    local last_non_ws_token=""
    local in_tagged_template=false
    local expecting_tag=false
    local brace_count=0
    local bracket_count=0
    local paren_count=0
    
    # Track backtick positions for better error messages
    local template_start_line=0
    local template_start_col=0
    local last_backtick_line=0
    local last_backtick_col=0
    
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
            
            # Handle comments
            if ! $in_comment_single && ! $in_comment_multi && ! $in_string_single && ! $in_string_double && ! $in_template; then
                if [ "$char" = '/' ] && [ "$next_char" = '/' ]; then
                    in_comment_single=true
                    ((col++))
                elif [ "$char" = '/' ] && [ "$next_char" = '*' ]; then
                    in_comment_multi=true
                    ((col++))
                fi
            fi
            
            # Inside multi-line comment
            if $in_comment_multi && [ "$char" = '*' ] && [ "$next_char" = '/' ]; then
                in_comment_multi=false
                ((col++))
            fi
            
            # Check for string/template contexts
            if ! $in_comment_single && ! $in_comment_multi; then
                # Check for string start/end
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
                    if ! $in_template; then
                        # Starting a template literal
                        in_template=true
                        template_depth=1
                        template_start_line=$line_number
                        template_start_col=$col
                        last_backtick_line=$line_number
                        last_backtick_col=$col
                        
                        # Check if this is a tagged template
                        if [ -n "$last_non_ws_token" ] && [[ "$last_non_ws_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                            in_tagged_template=true
                        else
                            in_tagged_template=false
                        fi
                    else
                        # Ending a template literal
                        if ! $in_template_expression; then
                            in_template=false
                            template_depth=0
                            last_backtick_line=$line_number
                            last_backtick_col=$col
                        else
                            # Backtick inside expression - error
                            echo -e "${RED}Error at line $line_number, column $((col+1)): Unexpected backtick inside template expression${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $col "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                    fi
                fi
            fi
            
            # Handle template expression parsing
            if $in_template && ! $in_template_expression; then
                # Check for ${ expression start
                if [ "$char" = '$' ] && [ "$next_char" = '{' ]; then
                    in_template_expression=true
                    expression_depth=1
                    expression_start_col=$col
                    expression_line=$line_number
                    ((col++)) # Skip the {
                fi
            elif $in_template_expression; then
                # Track braces inside expression
                if [ "$char" = '{' ]; then
                    ((expression_depth++))
                elif [ "$char" = '}' ]; then
                    ((expression_depth--))
                    if [ $expression_depth -eq 0 ]; then
                        # End of expression
                        local expression_text="${line:$((expression_start_col+2)):$((col-expression_start_col-2))}"
                        if ! validate_template_expression "$expression_text" "$expression_line" "$((expression_start_col+1))"; then
                            echo "  $line"
                            printf "%*s^%s\n" $expression_start_col "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                        in_template_expression=false
                    fi
                fi
            fi
            
            # Get token for syntax checking (when not in string/comment/template-expr)
            if ! $in_string_single && ! $in_string_double && ! $in_comment_single && ! $in_comment_multi && \
               (! $in_template || ($in_template && ! $in_template_expression)); then
                # Get current token
                local token
                token_length=0
                token=$(get_token "$line" $col)
                token_length=${#token}
                
                if [ -n "$token" ] && [ "$token_length" -gt 0 ]; then
                    # Update column position
                    ((col += token_length - 1))
                    
                    # Check for specific template-related errors
                    case "$token" in
                        # Check for invalid tagged templates
                        '`')
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
                               [ "$last_non_ws_token" = "=>" ] || \
                               [ "$last_non_ws_token" = "." ] || \
                               [[ "$last_non_ws_token" =~ ^[0-9]+$ ]] || \
                               [[ "$last_non_ws_token" =~ ^[0-9]+\.[0-9]*$ ]]; then
                                # Invalid context for template start
                                if [[ "$last_non_ws_token" =~ ^[0-9] ]]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Number cannot be used as template tag${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        # Check for invalid expression operators in templates
                        '++'|'--')
                            # These have special rules in templates
                            if $in_template && ! $in_template_expression && [ "$last_non_ws_token" = "$" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid operator in template literal${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for lonely $ in templates (not followed by {)
                        '$')
                            if $in_template && ! $in_template_expression && [ "$next_char" != "{" ]; then
                                # Check if this is meant to be an escaped $
                                local check_col=$((col+1))
                                local found_brace=false
                                while [ $check_col -lt $line_length ]; do
                                    if [ "${line:$check_col:1}" = "{" ]; then
                                        found_brace=true
                                        break
                                    elif ! is_whitespace "${line:$check_col:1}"; then
                                        break
                                    fi
                                    ((check_col++))
                                done
                                if ! $found_brace; then
                                    echo -e "${RED}Error at line $line_number, column $((col+1)): Lone $ in template literal (should be \${ or part of text)${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        # Check for { without $ in templates
                        '{')
                            if $in_template && ! $in_template_expression && [ "$last_non_ws_token" != "$" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col+1)): { in template literal without preceding ${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for } without matching { in templates
                        '}')
                            if $in_template && ! $in_template_expression; then
                                echo -e "${RED}Error at line $line_number, column $((col+1)): Unexpected } in template literal${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for invalid escape sequences in templates
                        '\\')
                            if $in_template && ! $in_template_expression; then
                                # Check what follows the backslash
                                if [ $((col+1)) -lt $line_length ]; then
                                    local escape_char="${line:$((col+1)):1}"
                                    case "$escape_char" in
                                        '`'|'$'|'\\')
                                            # Valid escapes
                                            ;;
                                        'u')
                                            # Check for valid Unicode escape
                                            if [ $((col+2)) -lt $line_length ] && [ $((col+3)) -lt $line_length ] && \
                                               [ $((col+4)) -lt $line_length ] && [ $((col+5)) -lt $line_length ]; then
                                                local hex1="${line:$((col+2)):1}"
                                                local hex2="${line:$((col+3)):1}"
                                                local hex3="${line:$((col+4)):1}"
                                                local hex4="${line:$((col+5)):1}"
                                                if ! [[ "$hex1$hex2$hex3$hex4" =~ ^[0-9a-fA-F]{4}$ ]]; then
                                                    echo -e "${RED}Error at line $line_number, column $((col+1)): Invalid Unicode escape${NC}"
                                                    echo "  $line"
                                                    printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                                    echo "$(realpath "$filename")"
                                                    return 1
                                                fi
                                            else
                                                echo -e "${RED}Error at line $line_number, column $((col+1)): Incomplete Unicode escape${NC}"
                                                echo "  $line"
                                                printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                                echo "$(realpath "$filename")"
                                                return 1
                                            fi
                                            ;;
                                        'x')
                                            # Check for valid hex escape
                                            if [ $((col+2)) -lt $line_length ] && [ $((col+3)) -lt $line_length ]; then
                                                local hex1="${line:$((col+2)):1}"
                                                local hex2="${line:$((col+3)):1}"
                                                if ! [[ "$hex1$hex2" =~ ^[0-9a-fA-F]{2}$ ]]; then
                                                    echo -e "${RED}Error at line $line_number, column $((col+1)): Invalid hex escape${NC}"
                                                    echo "  $line"
                                                    printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                                    echo "$(realpath "$filename")"
                                                    return 1
                                                fi
                                            else
                                                echo -e "${RED}Error at line $line_number, column $((col+1)): Incomplete hex escape${NC}"
                                                echo "  $line"
                                                printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                                echo "$(realpath "$filename")"
                                                return 1
                                            fi
                                            ;;
                                        [0-7])
                                            # Octal escape (deprecated but still valid)
                                            ;;
                                        'n'|'r'|'t'|'b'|'f'|'v'|"'")
                                            # Valid escape sequences
                                            ;;
                                        *)
                                            # Invalid escape
                                            echo -e "${RED}Error at line $line_number, column $((col+1)): Invalid escape sequence \\${escape_char}${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $col "" "${RED}here${NC}"
                                            echo "$(realpath "$filename")"
                                            return 1
                                            ;;
                                    esac
                                fi
                            fi
                            ;;
                            
                        # Check for String.raw misuse
                        'String.raw')
                            # Check if followed by template literal
                            local lookahead_col=$((col+token_length))
                            local found_template=false
                            while [ $lookahead_col -lt $line_length ]; do
                                if is_whitespace "${line:$lookahead_col:1}"; then
                                    ((lookahead_col++))
                                    continue
                                fi
                                if [ "${line:$lookahead_col:1}" = '`' ]; then
                                    found_template=true
                                fi
                                break
                            done
                            if ! $found_template; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): String.raw must be followed by template literal${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for template as property key
                        '`')
                            if [ "$last_non_ws_token" = ":" ] || \
                               ([ "$last_non_ws_token" = "" ] && [[ "$line" =~ ^[[:space:]]*\` ]]); then
                                # Could be a template as property key (invalid)
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Template literal cannot be used as property key${NC}"
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
        
        # Check for unterminated template expression at line end
        if $in_template_expression; then
            # Look for closing } on next lines or error
            # We'll handle this in the main loop
            :
        fi
        
    done < "$filename"
    
    # Post-file validation checks
    if $in_template; then
        echo -e "${RED}Error: Unterminated template literal starting at line $template_start_line, column $((template_start_col+1))${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    if $in_template_expression; then
        echo -e "${RED}Error: Unterminated template expression starting at line $expression_line, column $((expression_start_col+1))${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    # Check for string/template/comment termination
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
    if $in_comment_multi; then
        echo -e "${RED}Error: Unterminated multi-line comment${NC}"
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

# Function to audit a single JavaScript file for template errors
audit_js_file() {
    local filename="$1"
    
    if [ ! -f "$filename" ]; then
        echo -e "${RED}Error: File '$filename' not found${NC}"
        return 1
    fi
    
    if [[ ! "$filename" =~ \.js$ ]]; then
        echo -e "${YELLOW}Warning: File '$filename' doesn't have .js extension${NC}"
    fi
    
    echo -e "${CYAN}Auditing template literals in:${NC} ${filename}"
    echo "========================================"
    
    # Check file size
    local file_size=$(wc -c < "$filename")
    if [ $file_size -eq 0 ]; then
        echo -e "${GREEN}✓ Empty file - no errors${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    fi
    
    # Run our template syntax checker
    if check_template_syntax "$filename"; then
        echo -e "${GREEN}✓ No template literal errors found${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running JavaScript Template Literal Error Test Suite${NC}"
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
