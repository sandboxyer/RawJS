#!/bin/bash

# JavaScript Parameter Syntax Auditor - Pure Bash Implementation
# Usage: ./params.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="1.2.0"
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

# Function to report an error
report_error() {
    local line_number="$1"
    local column="$2"
    local message="$3"
    local line_content="$4"
    local filename="$5"
    
    echo -e "${RED}Error at line ${line_number}, column ${column}: ${message}${NC}"
    echo "  ${line_content}"
    
    # Calculate padding for arrow
    local padding=""
    for ((i=1; i<column; i++)); do
        padding+=" "
    done
    
    echo -e "${padding}^${RED}here${NC}"
    echo "$(realpath "$filename" 2>/dev/null || echo "$filename")"
    return 1
}

# Function to extract tokens from a line
extract_tokens() {
    local line="$1"
    local tokens=()
    local length=${#line}
    local pos=0
    
    while [ $pos -lt $length ]; do
        local char="${line:$pos:1}"
        
        # Skip whitespace
        if is_whitespace "$char"; then
            ((pos++))
            continue
        fi
        
        # Handle different token types
        case "$char" in
            # Single character tokens
            ';'|','|'.'|'('|')'|'{'|'}'|'['|']'|':'|'?'|'~'|'@'|'#'|'`')
                tokens+=("$char:$pos")
                ((pos++))
                ;;
            
            # Operators
            '+'|'-'|'*'|'/'|'%'|'&'|'|'|'^'|'!'|'='|'<'|'>')
                if [ $((pos+1)) -lt $length ]; then
                    local next_char="${line:$((pos+1)):1}"
                    case "${char}${next_char}" in
                        '++'|'--'|'**'|'<<'|'>>'|'&&'|'||'|'=='|'!='|'<='|'>='|'+='|'-='|'*='|'/='|'%='|'&='|'|='|'^='|'??'|'?.'|'=>')
                            tokens+=("${char}${next_char}:$pos")
                            ((pos+=2))
                            continue
                            ;;
                    esac
                fi
                tokens+=("$char:$pos")
                ((pos++))
                ;;
            
            # Strings
            "'"|'"')
                local start=$pos
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
            
            # Template literals
            '`')
                local start=$pos
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
                    local next_char="${line:$((pos+1)):1}"
                    if [ "$next_char" = '/' ]; then
                        # Line comment - skip to end
                        pos=$length
                        continue
                    elif [ "$next_char" = '*' ]; then
                        # Block comment - find closing
                        ((pos+=2))
                        while [ $pos -lt $length ] && ! ([ "${line:$pos:1}" = '*' ] && [ $((pos+1)) -lt $length ] && [ "${line:$((pos+1)):1}" = '/' ]); do
                            ((pos++))
                        done
                        if [ $((pos+1)) -lt $length ]; then
                            ((pos+=2))
                        fi
                        continue
                    fi
                fi
                tokens+=("$char:$pos")
                ((pos++))
                ;;
            
            # Identifiers and numbers
            *)
                if is_valid_id_start "$char" || [[ "$char" =~ [0-9] ]]; then
                    local start=$pos
                    while [ $pos -lt $length ] && (is_valid_id_char "${line:$pos:1}" || 
                          [[ "${line:$pos:1}" =~ [0-9] ]] || 
                          [ "${line:$pos:1}" = "$" ] ||
                          [ "${line:$pos:1}" = "-" ]); do
                        ((pos++))
                    done
                    local token="${line:$start:$((pos-start))}"
                    tokens+=("$token:$start")
                else
                    # Unknown character
                    tokens+=("$char:$pos")
                    ((pos++))
                fi
                ;;
        esac
    done
    
    # Return tokens as string
    printf "%s\n" "${tokens[@]}"
}

# Main parameter syntax checking function
check_param_syntax() {
    local filename="$1"
    local line_number=0
    local in_function_decl=false
    local in_arrow_params=false
    local in_method_decl=false
    local in_constructor_decl=false
    local in_generator_decl=false
    local in_async_decl=false
    local in_getter_setter=false
    local getter_setter_type=""
    local in_class=false
    local in_object_literal=false
    local brace_count=0
    local paren_count=0
    local bracket_count=0
    local in_param_list=false
    local param_list_start=0
    local expecting_param=false
    local expecting_comma=false
    local has_rest_param=false
    local param_count=0
    local param_names=()
    local in_strict_mode=false
    
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_number++))
        
        # Check for strict mode
        if [[ "$line" =~ ^[[:space:]]*\"use[[:space:]]+strict\" ]]; then
            in_strict_mode=true
        fi
        
        # Extract tokens from line
        local tokens
        tokens=$(extract_tokens "$line")
        
        # Process tokens
        local token_idx=0
        while IFS= read -r token_info; do
            [ -z "$token_info" ] && continue
            
            local token="${token_info%:*}"
            local token_pos="${token_info#*:}"
            
            # Update context based on braces
            if [ "$token" = "{" ]; then
                ((brace_count++))
                if $in_class && [ $brace_count -eq 1 ]; then
                    in_class=true
                fi
            elif [ "$token" = "}" ]; then
                ((brace_count--))
                if [ $brace_count -eq 0 ]; then
                    in_class=false
                    in_object_literal=false
                fi
            elif [ "$token" = "[" ]; then
                ((bracket_count++))
            elif [ "$token" = "]" ]; then
                ((bracket_count--))
            
            # Update context based on parentheses
            elif [ "$token" = "(" ]; then
                ((paren_count++))
                
                # Check if this starts a parameter list
                if ($in_function_decl || $in_method_decl || $in_constructor_decl || 
                    $in_generator_decl || $in_async_decl || $in_getter_setter) && 
                   [ $paren_count -eq 1 ]; then
                    in_param_list=true
                    param_list_start=$line_number
                    expecting_param=true
                    expecting_comma=false
                    has_rest_param=false
                    param_count=0
                    param_names=()
                fi
                
            elif [ "$token" = ")" ]; then
                ((paren_count--))
                
                # Check if this ends a parameter list
                if $in_param_list && [ $paren_count -eq 0 ]; then
                    in_param_list=false
                    
                    # Validate getter/setter parameters
                    if $in_getter_setter; then
                        if [ "$getter_setter_type" = "get" ] && [ $param_count -ne 0 ]; then
                            report_error "$param_list_start" "$((token_pos+1))" \
                                "Getter must not have parameters" "$line" "$filename"
                            return 1
                        elif [ "$getter_setter_type" = "set" ] && [ $param_count -ne 1 ]; then
                            report_error "$param_list_start" "$((token_pos+1))" \
                                "Setter must have exactly one parameter" "$line" "$filename"
                            return 1
                        fi
                    fi
                fi
            
            # Handle keywords that change context
            elif [ "$token" = "function" ]; then
                if ! $in_class && ! $in_object_literal && ! $in_getter_setter; then
                    in_function_decl=true
                    in_async_decl=false
                fi
            
            elif [ "$token" = "async" ]; then
                in_async_decl=true
            
            elif [ "$token" = "class" ]; then
                in_class=true
            
            elif [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                # Check for getter/setter in object/class context
                if [ "$token" = "get" ] || [ "$token" = "set" ]; then
                    # Look ahead to see if this is actually a getter/setter
                    local next_idx=$((token_idx + 1))
                    local next_token_info=$(echo "$tokens" | sed -n "${next_idx}p")
                    if [ -n "$next_token_info" ]; then
                        local next_token="${next_token_info%:*}"
                        local next_pos="${next_token_info#*:}"
                        
                        # Check if next token is identifier and followed by '('
                        if [[ "$next_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                            # Check if after identifier there's '('
                            local after_idx=$((token_idx + 2))
                            local after_token_info=$(echo "$tokens" | sed -n "${after_idx}p")
                            if [ -n "$after_token_info" ]; then
                                local after_token="${after_token_info%:*}"
                                if [ "$after_token" = "(" ]; then
                                    in_getter_setter=true
                                    getter_setter_type="$token"
                                    in_method_decl=false
                                fi
                            fi
                        fi
                    fi
                # Check for constructor
                elif [ "$token" = "constructor" ] && $in_class; then
                    in_constructor_decl=true
                    in_method_decl=false
                fi
            fi
            
            # Check for method declarations in class
            if $in_class && [ $brace_count -eq 1 ] && 
               [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && 
               ! $in_constructor_decl && ! $in_getter_setter; then
                # Check if next token is '('
                local next_idx=$((token_idx + 1))
                local next_token_info=$(echo "$tokens" | sed -n "${next_idx}p")
                if [ -n "$next_token_info" ]; then
                    local next_token="${next_token_info%:*}"
                    if [ "$next_token" = "(" ]; then
                        in_method_decl=true
                    fi
                fi
            fi
            
            # Handle arrow functions
            if [ "$token" = "=>" ]; then
                if ! $in_arrow_params && $in_param_list; then
                    in_arrow_params=true
                fi
            fi
            
            # Inside parameter list checks
            if $in_param_list; then
                case "$token" in
                    # Check for unexpected semicolon
                    ';')
                        report_error "$line_number" "$((token_pos+1))" \
                            "Unexpected semicolon in parameter list" "$line" "$filename"
                        return 1
                        ;;
                    
                    # Check for comma errors
                    ',')
                        if $expecting_comma || [ $param_count -eq 0 ]; then
                            report_error "$line_number" "$((token_pos+1))" \
                                "Unexpected comma in parameter list" "$line" "$filename"
                            return 1
                        fi
                        expecting_param=true
                        expecting_comma=false
                        ;;
                    
                    # Check for rest parameters
                    '...')
                        if $has_rest_param; then
                            report_error "$line_number" "$((token_pos+1))" \
                                "Multiple rest parameters not allowed" "$line" "$filename"
                            return 1
                        fi
                        if ! $expecting_param; then
                            report_error "$line_number" "$((token_pos+1))" \
                                "Rest parameter must come after regular parameters" "$line" "$filename"
                            return 1
                        fi
                        has_rest_param=true
                        expecting_param=false
                        ;;
                    
                    # Check for default value assignment
                    '=')
                        if ! $expecting_param || $expecting_comma; then
                            report_error "$line_number" "$((token_pos+1))" \
                                "Unexpected assignment in parameter list" "$line" "$filename"
                            return 1
                        fi
                        ;;
                    
                    # Check for valid parameter names
                    *)
                        if $expecting_param && [ "$token" != ")" ] && [ "$token" != "," ] && 
                           [ "$token" != "=" ] && [ "$token" != "..." ] && 
                           [ "$token" != "{" ] && [ "$token" != "[" ]; then
                            
                            # Check for invalid parameter names
                            if [[ "$token" =~ ^[0-9] ]]; then
                                report_error "$line_number" "$((token_pos+1))" \
                                    "Parameter name cannot start with a number" "$line" "$filename"
                                return 1
                            elif [[ "$token" =~ - ]]; then
                                report_error "$line_number" "$((token_pos+1))" \
                                    "Parameter name contains invalid character '-'" "$line" "$filename"
                                return 1
                            elif ! [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                report_error "$line_number" "$((token_pos+1))" \
                                    "Invalid parameter name '$token'" "$line" "$filename"
                                return 1
                            fi
                            
                            # Check for reserved words
                            if is_reserved_word "$token"; then
                                report_error "$line_number" "$((token_pos+1))" \
                                    "Reserved word '$token' cannot be used as parameter name" "$line" "$filename"
                                return 1
                            fi
                            
                            # Check for strict mode restrictions
                            if $in_strict_mode; then
                                for reserved in $STRICT_RESERVED_PARAMS; do
                                    if [ "$token" = "$reserved" ]; then
                                        report_error "$line_number" "$((token_pos+1))" \
                                            "Parameter name '$token' not allowed in strict mode" "$line" "$filename"
                                        return 1
                                    fi
                                done
                            fi
                            
                            # Check for duplicate parameters
                            for existing_param in "${param_names[@]}"; do
                                if [ "$token" = "$existing_param" ]; then
                                    if $in_strict_mode || $in_arrow_params; then
                                        report_error "$line_number" "$((token_pos+1))" \
                                            "Duplicate parameter name '$token'" "$line" "$filename"
                                        return 1
                                    fi
                                fi
                            done
                            
                            # Add parameter to list
                            param_names+=("$token")
                            param_count=$((param_count + 1))
                            expecting_param=false
                            expecting_comma=true
                        fi
                        ;;
                esac
            fi
            
            # Check for missing parentheses after function name
            if ($in_function_decl || $in_method_decl || $in_constructor_decl || 
                $in_generator_decl || $in_async_decl) && 
               [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && [ "$token" != "function" ] && 
               [ "$token" != "async" ] && [ "$token" != "get" ] && [ "$token" != "set" ] && 
               [ "$token" != "constructor" ]; then
                
                # Look ahead for '('
                local found_paren=false
                local lookahead_idx=$((token_idx + 1))
                while IFS= read -r lookahead_info; do
                    [ -z "$lookahead_info" ] && break
                    local lookahead_token="${lookahead_info%:*}"
                    
                    if [ "$lookahead_token" = "(" ]; then
                        found_paren=true
                        break
                    elif [ "$lookahead_token" = "{" ] || [ "$lookahead_token" = ";" ] || 
                         [ "$lookahead_token" = "=" ] || [ "$lookahead_token" = "=>" ]; then
                        break
                    fi
                    
                    lookahead_idx=$((lookahead_idx + 1))
                done < <(echo "$tokens" | tail -n +$((lookahead_idx + 1)))
                
                if ! $found_paren; then
                    report_error "$line_number" "$((token_pos+1))" \
                        "Missing parentheses after function name" "$line" "$filename"
                    return 1
                fi
            fi
            
            # Reset function states when we hit a brace
            if [ "$token" = "{" ] && ($in_function_decl || $in_method_decl || 
                $in_constructor_decl || $in_generator_decl || $in_async_decl || 
                $in_getter_setter || $in_arrow_params); then
                in_function_decl=false
                in_method_decl=false
                in_constructor_decl=false
                in_generator_decl=false
                in_async_decl=false
                in_getter_setter=false
                in_arrow_params=false
                getter_setter_type=""
            fi
            
            token_idx=$((token_idx + 1))
            
        done < <(echo "$tokens")
    done < "$filename"
    
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
            # Check if this test is expected to fail
            if [[ "$filename" =~ ^(27|28|42|43|44|45|46)_ ]]; then
                echo -e "${GREEN}  ✓ Correctly passed (valid syntax)${NC}"
                ((passed_tests++))
            else
                echo -e "${RED}  ✗ Expected to fail but passed${NC}"
                ((failed_tests++))
            fi
        else
            # Check if this test is expected to fail
            if [[ "$filename" =~ ^(27|28|42|43|44|45|46)_ ]]; then
                echo -e "${RED}  ✗ Expected to pass but failed${NC}"
                ((failed_tests++))
            else
                echo -e "${GREEN}  ✓ Correctly detected error${NC}"
                ((passed_tests++))
            fi
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
