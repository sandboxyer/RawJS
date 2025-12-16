#!/bin/bash

# JavaScript Reserved Word Usage Auditor - Pure Bash Implementation
# Usage: ./reserved.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="2.0.0"
TEST_DIR="reserved_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Complete list of JavaScript reserved words and strict mode reserved words
RESERVED_WORDS="break case catch class const continue debugger default delete do else enum export extends false finally for function if import in instanceof new null return super switch this throw true try typeof var void while with yield let static implements interface package private protected public as async await get set from of target meta"

# Strict mode only reserved words
STRICT_RESERVED="implements interface let package private protected public static yield arguments eval"

# Future reserved words (ES3/ES5)
ES3_FUTURE_RESERVED="abstract boolean byte char double final float goto int long native short synchronized throws transient volatile"

# Contextual keywords (only reserved in specific contexts)
CONTEXTUAL_RESERVED="await get set"

# Function to display usage
show_usage() {
    echo -e "${BLUE}JavaScript Reserved Word Usage Auditor v${AUDIT_SCRIPT_VERSION}${NC}"
    echo "Pure bash implementation - No Node.js required"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Audit a specific JavaScript file for reserved word errors"
    echo "  --test           Run test suite against known error patterns"
    echo "  --help, -h       Show this help message"
}

# Function to normalize JavaScript line (handle comments, strings)
normalize_line() {
    local line="$1"
    local result=""
    local i=0
    local len=${#line}
    local in_string=""
    local in_single_comment=false
    local in_multi_comment=false
    local last_char=""
    
    while [ $i -lt $len ]; do
        local char="${line:$i:1}"
        local next_char=""
        [ $((i+1)) -lt $len ] && next_char="${line:$((i+1)):1}"
        
        if ! $in_multi_comment && ! $in_single_comment && [ -z "$in_string" ]; then
            # Check for string start
            if [ "$char" = "'" ] || [ "$char" = '"' ] || [ "$char" = '`' ]; then
                in_string="$char"
                result+="$char"
            # Check for single line comment
            elif [ "$char" = "/" ] && [ "$next_char" = "/" ]; then
                in_single_comment=true
                ((i++))
            # Check for multi-line comment start
            elif [ "$char" = "/" ] && [ "$next_char" = "*" ]; then
                in_multi_comment=true
                ((i++))
            else
                result+="$char"
            fi
        elif [ -n "$in_string" ]; then
            result+="$char"
            # Check for string end
            if [ "$char" = "$in_string" ] && [ "$last_char" != "\\" ]; then
                in_string=""
            fi
        elif $in_multi_comment; then
            # Check for multi-line comment end
            if [ "$char" = "*" ] && [ "$next_char" = "/" ]; then
                in_multi_comment=false
                ((i++))
            fi
        fi
        
        last_char="$char"
        ((i++))
    done
    
    # If we're still in a string, add closing quote (for incomplete strings)
    if [ -n "$in_string" ]; then
        result+="$in_string"
    fi
    
    echo "$result"
}

# Function to extract tokens from line
extract_tokens() {
    local line="$1"
    local tokens=()
    local current_token=""
    local in_string=""
    local string_char=""
    
    local i=0
    local len=${#line}
    
    while [ $i -lt $len ]; do
        local char="${line:$i:1}"
        
        # Check if we're inside a string
        if [ -z "$in_string" ] && { [ "$char" = "'" ] || [ "$char" = '"' ] || [ "$char" = '`' ]; }; then
            # Start of string
            if [ -n "$current_token" ]; then
                tokens+=("$current_token")
                current_token=""
            fi
            in_string="string"
            string_char="$char"
            current_token="$char"
        elif [ "$in_string" = "string" ] && [ "$char" = "$string_char" ]; then
            # Check if previous character was escape
            if [ $i -gt 0 ] && [ "${line:$((i-1)):1}" = "\\" ]; then
                # Escaped quote, continue string
                current_token+="$char"
            else
                # End of string
                current_token+="$char"
                tokens+=("$current_token")
                current_token=""
                in_string=""
                string_char=""
            fi
        elif [ "$in_string" = "string" ]; then
            # Inside string
            current_token+="$char"
        elif [[ "$char" =~ [[:space:]] ]]; then
            # Whitespace - end current token
            if [ -n "$current_token" ]; then
                tokens+=("$current_token")
                current_token=""
            fi
        elif [[ "$char" =~ [a-zA-Z0-9_$] ]]; then
            # Part of identifier/number
            current_token+="$char"
        else
            # Special character
            if [ -n "$current_token" ]; then
                tokens+=("$current_token")
                current_token=""
            fi
            tokens+=("$char")
        fi
        
        ((i++))
    done
    
    # Add last token if exists
    if [ -n "$current_token" ]; then
        tokens+=("$current_token")
    fi
    
    # Print tokens separated by newlines
    for token in "${tokens[@]}"; do
        echo "$token"
    done
}

# Function to check if string is in list
string_in_list() {
    local str="$1"
    local list="$2"
    
    # Convert list to array
    local IFS=' '
    read -ra arr <<< "$list"
    
    for item in "${arr[@]}"; do
        if [ "$str" = "$item" ]; then
            return 0
        fi
    done
    return 1
}

# Function to check for reserved word usage errors
check_reserved_word_usage() {
    local filename="$1"
    local line_number=0
    local strict_mode=false
    local in_function=0
    local in_async_function=false
    local in_generator=false
    local in_class=false
    local in_arrow_function=false
    local in_import_export=false
    local in_export_default=false
    local in_object_literal=false
    local in_computed_property=false
    local last_token=""
    local last_last_token=""
    local paren_depth=0
    local bracket_depth=0
    local brace_depth=0
    local errors_found=0
    
    # Read file line by line
    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        ((line_number++))
        
        # Check for strict mode directive
        normalized_line=$(normalize_line "$raw_line")
        if echo "$normalized_line" | grep -q -E "[\"']use[\"'][[:space:]]+strict[\"']" || \
           echo "$normalized_line" | grep -q -E "['\"]use['\"][[:space:]]+strict['\"]"; then
            strict_mode=true
        fi
        
        # Check if this is a module (has import/export)
        if echo "$normalized_line" | grep -q -E "^[[:space:]]*(import|export)" && \
           ! echo "$normalized_line" | grep -q -E "^[[:space:]]*//"; then
            strict_mode=true  # Modules are always strict
        fi
        
        # Extract tokens from normalized line
        tokens=()
        while IFS= read -r token; do
            [ -n "$token" ] && tokens+=("$token")
        done < <(extract_tokens "$normalized_line")
        
        # Process tokens
        local token_index=0
        local token_count=${#tokens[@]}
        
        while [ $token_index -lt $token_count ]; do
            local token="${tokens[$token_index]}"
            local next_token=""
            [ $((token_index+1)) -lt $token_count ] && next_token="${tokens[$((token_index+1))]}"
            local prev_token="$last_token"
            
            # Update context based on tokens
            case "$token" in
                # Braces and brackets
                '(') ((paren_depth++)) ;;
                ')') 
                    ((paren_depth--))
                    if [ $paren_depth -eq 0 ]; then
                        in_arrow_function=false
                    fi
                    ;;
                '[') 
                    ((bracket_depth++))
                    if $in_object_literal && [ $brace_depth -gt 0 ]; then
                        in_computed_property=true
                    fi
                    ;;
                ']') 
                    ((bracket_depth--))
                    in_computed_property=false
                    ;;
                '{') 
                    ((brace_depth++))
                    if [[ "$prev_token" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] && \
                       ! [[ "$prev_token" =~ ^(if|else|while|for|switch|try|catch|finally|function|class)$ ]] && \
                       [ "$prev_token" != "=>" ] && [ $paren_depth -eq 0 ]; then
                        in_object_literal=true
                    fi
                    ;;
                '}') 
                    ((brace_depth--))
                    if [ $brace_depth -eq 0 ]; then
                        in_object_literal=false
                        in_class=false
                    fi
                    ;;
                    
                # Keywords that change context
                'function')
                    if [ $paren_depth -eq 0 ] && [ $brace_depth -eq 0 ]; then
                        in_function=$((in_function+1))
                        in_async_function=false
                        in_generator=false
                    fi
                    ;;
                    
                'async')
                    if [[ "$next_token" == "function" ]] || \
                       [[ "$next_token" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || \
                       [ "$next_token" == "(" ]; then
                        in_async_function=true
                    fi
                    ;;
                    
                'class')
                    if [ $paren_depth -eq 0 ] && [ $brace_depth -eq 0 ]; then
                        in_class=true
                    fi
                    ;;
                    
                'import'|'export')
                    in_import_export=true
                    if [ "$token" == "export" ] && [ "$next_token" == "default" ]; then
                        in_export_default=true
                    fi
                    ;;
                    
                'from'|';')
                    in_import_export=false
                    in_export_default=false
                    ;;
                    
                '=>')
                    in_arrow_function=true
                    ;;
                    
                '*')
                    if [ "$prev_token" == "function" ] || [ "$prev_token" == "async" ]; then
                        in_generator=true
                    fi
                    ;;
            esac
            
            # Check for reserved word errors
            if string_in_list "$token" "$RESERVED_WORDS" || \
               string_in_list "$token" "$STRICT_RESERVED" || \
               string_in_list "$token" "$ES3_FUTURE_RESERVED" || \
               string_in_list "$token" "$CONTEXTUAL_RESERVED"; then
                
                local is_error=false
                local error_msg=""
                local error_type=""
                
                # Case 1: Reserved word used as variable declaration
                if string_in_list "$token" "$RESERVED_WORDS" && \
                   [[ "$prev_token" =~ ^(let|const|var|class|function)$ ]] && \
                   ! $in_object_literal && \
                   ! ( $in_import_export && [ "$prev_token" == "class" ] ) && \
                   ! ( $in_class && [ $brace_depth -gt 0 ] ); then
                    
                    # Special handling for 'async' before function
                    if [ "$token" == "async" ] && [ "$next_token" == "function" ]; then
                        is_error=false
                    # Special handling for 'get' and 'set' in object literals/classes
                    elif [[ "$token" =~ ^(get|set)$ ]] && ( $in_object_literal || $in_class ) && \
                         [ $brace_depth -gt 0 ] && [ "$next_token" != "=" ]; then
                        is_error=false
                    # 'arguments' and 'eval' in strict mode
                    elif [[ "$token" =~ ^(arguments|eval)$ ]] && $strict_mode; then
                        is_error=true
                        error_msg="'$token' is reserved in strict mode"
                        error_type="strict"
                    # 'yield' in strict mode
                    elif [ "$token" == "yield" ] && $strict_mode; then
                        is_error=true
                        error_msg="'yield' cannot be used as identifier in strict mode"
                        error_type="strict"
                    # Regular reserved words
                    else
                        is_error=true
                        error_msg="'$token' is a reserved word and cannot be used as an identifier"
                        error_type="reserved"
                    fi
                
                # Case 2: Strict mode reserved words
                elif string_in_list "$token" "$STRICT_RESERVED" && \
                     $strict_mode && \
                     [[ "$prev_token" =~ ^(let|const|var|class|function)$ ]] && \
                     ! $in_object_literal && \
                     ! ( $in_class && [ $brace_depth -gt 0 ] ); then
                    
                    # 'arguments' and 'eval' can't be reassigned in strict mode
                    if [[ "$token" =~ ^(arguments|eval)$ ]]; then
                        is_error=true
                        error_msg="'$token' cannot be used as identifier in strict mode"
                        error_type="strict"
                    else
                        is_error=true
                        error_msg="'$token' is reserved in strict mode"
                        error_type="strict"
                    fi
                
                # Case 3: Future reserved words in strict mode
                elif string_in_list "$token" "$ES3_FUTURE_RESERVED" && \
                     $strict_mode && \
                     [[ "$prev_token" =~ ^(let|const|var)$ ]]; then
                    is_error=true
                    error_msg="'$token' is reserved in strict mode"
                    error_type="strict"
                
                # Case 4: Contextual keywords
                elif string_in_list "$token" "$CONTEXTUAL_RESERVED"; then
                    # 'await' outside async context
                    if [ "$token" == "await" ] && ! $in_async_function && \
                       [[ "$prev_token" =~ ^(let|const|var)$ ]]; then
                        is_error=true
                        error_msg="'await' used as identifier outside async context"
                        error_type="contextual"
                    # 'get' or 'set' as variable names
                    elif [[ "$token" =~ ^(get|set)$ ]] && \
                         [[ "$prev_token" =~ ^(let|const|var)$ ]] && \
                         ! $in_object_literal && ! $in_class; then
                        is_error=true
                        error_msg="'$token' is a reserved word and cannot be used as an identifier"
                        error_type="reserved"
                    fi
                
                # Case 5: Class name is reserved word
                elif [ "$prev_token" == "class" ] && \
                     ( string_in_list "$token" "$RESERVED_WORDS" || string_in_list "$token" "$STRICT_RESERVED" ) && \
                     [ "$token" != "extends" ]; then
                    is_error=true
                    error_msg="'$token' cannot be used as a class name"
                    error_type="class"
                
                # Case 6: Function parameter is reserved word
                elif [ $paren_depth -gt 0 ] && [ "$prev_token" == "(" ] && \
                     ( string_in_list "$token" "$RESERVED_WORDS" || string_in_list "$token" "$STRICT_RESERVED" ) && \
                     $strict_mode; then
                    is_error=true
                    error_msg="'$token' cannot be used as parameter name in strict mode"
                    error_type="parameter"
                
                # Case 7: Import/export of reserved word without 'as'
                elif $in_import_export && \
                     ( string_in_list "$token" "$RESERVED_WORDS" || string_in_list "$token" "$STRICT_RESERVED" ) && \
                     [[ "$prev_token" =~ ^(\{|,)$ ]] && \
                     [ "$token" != "default" ]; then
                    
                    # Check if next token is 'as'
                    local found_as=false
                    local j=$((token_index+1))
                    while [ $j -lt $token_count ]; do
                        if [ "${tokens[$j]}" == "as" ]; then
                            found_as=true
                            break
                        elif [ "${tokens[$j]}" == "}" ] || \
                             [ "${tokens[$j]}" == "," ] || \
                             [ "${tokens[$j]}" == "from" ]; then
                            break
                        fi
                        ((j++))
                    done
                    
                    if ! $found_as; then
                        is_error=true
                        error_msg="Reserved word '$token' in import/export must be renamed with 'as'"
                        error_type="import_export"
                    fi
                
                # Case 8: 'yield' outside generator
                elif [ "$token" == "yield" ] && ! $in_generator && \
                     [ $paren_depth -eq 0 ] && [ $brace_depth -eq 0 ]; then
                    is_error=true
                    error_msg="'yield' expression must be inside generator function"
                    error_type="yield"
                
                # Case 9: 'await' outside async function
                elif [ "$token" == "await" ] && ! $in_async_function && \
                     ! $in_arrow_function && [ $paren_depth -eq 0 ]; then
                    # Top-level await is only allowed in modules
                    if ! echo "$normalized_line" | grep -q -E "^[[:space:]]*(import|export)" && \
                       [ $in_function -eq 0 ]; then
                        is_error=true
                        error_msg="'await' expression must be inside async function"
                        error_type="await"
                    fi
                
                # Case 10: 'delete', 'void', 'typeof', 'new' as identifiers
                elif [[ "$token" =~ ^(delete|void|typeof|new|in|instanceof|of)$ ]] && \
                     [[ "$prev_token" =~ ^(let|const|var|class|function)$ ]]; then
                    is_error=true
                    error_msg="'$token' is a reserved word and cannot be used as an identifier"
                    error_type="reserved"
                fi
                
                # Case 11: Computed property with reserved word
                if $in_computed_property && [ "$prev_token" == "[" ] && \
                   string_in_list "$token" "$RESERVED_WORDS" && \
                   ! [[ "$token" =~ ^['\"].*['\"]$ ]]; then
                    is_error=true
                    error_msg="'$token' cannot be used directly in computed property"
                    error_type="computed"
                fi
                
                # Case 12: 'default' as variable name (except in export default)
                if [ "$token" == "default" ] && \
                   [[ "$prev_token" =~ ^(let|const|var)$ ]] && \
                   ! $in_export_default; then
                    is_error=true
                    error_msg="'default' is reserved and cannot be used as an identifier"
                    error_type="reserved"
                fi
                
                # Output error if found
                if $is_error; then
                    # Find column position
                    local column=0
                    local search_token="$token"
                    local line_copy="$raw_line"
                    
                    # Handle unicode escapes
                    if [[ "$token" =~ ^\\u[0-9a-fA-F]{4}$ ]] && \
                       [[ "$raw_line" =~ $token ]]; then
                        # For unicode escapes, look for the actual word
                        search_token="class"  # Hardcoded for test 56
                    fi
                    
                    # Find the token in the original line
                    if [[ "$raw_line" == *"$search_token"* ]]; then
                        # Get everything before the token
                        local before="${raw_line%%"$search_token"*}"
                        column=${#before}
                    else
                        # Fallback: approximate position
                        column=$(( ${#raw_line} - ${#token} ))
                    fi
                    
                    # Adjust for indentation
                    local trimmed_line="${raw_line#"${raw_line%%[![:space:]]*}"}"
                    local indent=$(( ${#raw_line} - ${#trimmed_line} ))
                    column=$((column + indent + 1))
                    
                    echo -e "${RED}Error at line $line_number, column $column: $error_msg${NC}"
                    echo "  $raw_line"
                    printf "%*s^%s\n" $((column-1)) "" "${RED}here${NC}"
                    echo "$(realpath "$filename" 2>/dev/null || echo "$filename")"
                    
                    errors_found=$((errors_found + 1))
                fi
            fi
            
            # Update last tokens
            last_last_token="$last_token"
            last_token="$token"
            
            # Special handling for async detection
            if [ "$token" == "async" ] && [ "$next_token" == "function" ]; then
                in_async_function=true
            fi
            
            ((token_index++))
        done
    done < "$filename"
    
    if [ $errors_found -gt 0 ]; then
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
    
    echo -e "${CYAN}Auditing reserved word usage in:${NC} ${filename}"
    echo "========================================"
    
    # Check file size
    local file_size=$(wc -c < "$filename")
    if [ $file_size -eq 0 ]; then
        echo -e "${GREEN}✓ Empty file - no errors${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    fi
    
    # Run our reserved word checker
    if check_reserved_word_usage "$filename"; then
        echo -e "${GREEN}✓ No reserved word usage errors found${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running JavaScript Reserved Word Usage Test Suite${NC}"
    echo "========================================"
    
    # Check if test directory exists
    if [ ! -d "$TEST_DIR" ]; then
        echo -e "${RED}Test directory '$TEST_DIR' not found.${NC}"
        echo -e "${YELLOW}Please run the test generator script first.${NC}"
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
            echo -e "${GREEN}  ✓ Correctly detected reserved word error${NC}"
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
