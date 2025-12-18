#!/bin/bash

# JavaScript Regular Expression Syntax Auditor - Pure Bash Implementation
# Usage: ./regex.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="1.1.1"
TEST_DIR="regex_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Valid regex flags
VALID_FLAGS="g i m s u y"

# Function to display usage
show_usage() {
    echo -e "${BLUE}JavaScript Regular Expression Syntax Auditor v${AUDIT_SCRIPT_VERSION}${NC}"
    echo "Pure bash implementation - No Node.js required"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Audit a specific JavaScript file for regex syntax errors"
    echo "  --test           Run test suite against known regex error patterns"
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

# Function to check if character is alphanumeric or underscore
is_alnum_or_underscore() {
    local char="$1"
    case "$char" in
        [a-zA-Z0-9_]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to validate regex flags
validate_flags() {
    local flags="$1"
    local -A seen_flags
    
    # Check each flag
    for ((i=0; i<${#flags}; i++)); do
        local flag="${flags:$i:1}"
        
        # Check if flag is valid
        case "$flag" in
            g|i|m|s|u|y)
                # Check for duplicates
                if [ "${seen_flags[$flag]}" = "1" ]; then
                    echo "duplicate"
                    return 1
                fi
                seen_flags[$flag]=1
                ;;
            *)
                echo "invalid"
                return 1
                ;;
        esac
    done
    
    echo "valid"
    return 0
}

# Function to check if a position in line could be a regex literal
could_be_regex_literal() {
    local line="$1"
    local pos="$2"
    local line_len=${#line}
    
    # If at start of line or after whitespace, could be regex
    if [ $pos -eq 0 ]; then
        return 0
    fi
    
    # Look backward for context
    local i=$((pos-1))
    while [ $i -ge 0 ] && is_whitespace "${line:$i:1}"; do
        ((i--))
    done
    
    if [ $i -lt 0 ]; then
        return 0
    fi
    
    local prev_char="${line:$i:1}"
    
    # Check what precedes the potential regex
    case "$prev_char" in
        # These can be followed by regex literal
        '('|'['|'{'|','|';'|':'|'?'|'!'|'&'|'|'|'^'|'~'|'='|'<'|'>'|'+'|'-'|'*'|'/'|'%'|'@')
            return 0
            ;;
        # These are likely part of identifier
        [a-zA-Z0-9_])
            # Check if it's a keyword that can precede regex
            local j=$i
            local token=""
            while [ $j -ge 0 ] && is_alnum_or_underscore "${line:$j:1}"; do
                token="${line:$j:1}$token"
                ((j--))
            done
            
            case "$token" in
                "return"|"case"|"throw"|"typeof"|"instanceof"|"void"|"delete"|"in"|"of"|"await"|"yield")
                    return 0
                    ;;
                "if"|"while"|"for"|"with")
                    return 0
                    ;;
                *)
                    # Check if previous token is an operator
                    if [ $j -ge 0 ]; then
                        local before_token="${line:$j:1}"
                        case "$before_token" in
                            '('|'['|'{'|','|';'|':'|'?'|'!'|'&'|'|'|'^'|'~'|'='|'<'|'>'|'+'|'-'|'*'|'/'|'%'|'@')
                                return 0
                                ;;
                        esac
                    fi
                    return 1
                    ;;
            esac
            ;;
        # Default to not being regex
        *)
            return 1
            ;;
    esac
}

# Improved function to extract regex literals from line
extract_regex_literals() {
    local line="$1"
    local line_number="$2"
    local regexes=()
    
    local line_len=${#line}
    local pos=0
    
    while [ $pos -lt $line_len ]; do
        local char="${line:$pos:1}"
        
        # Look for forward slash
        if [ "$char" = '/' ]; then
            # Check if this could be a regex literal
            if could_be_regex_literal "$line" $pos; then
                local regex_start=$pos
                local pattern=""
                local escape_next=false
                local in_char_class=false
                local regex_valid=true
                
                # Skip the opening slash
                ((pos++))
                
                # Parse until closing slash or end of line
                while [ $pos -lt $line_len ] && $regex_valid; do
                    char="${line:$pos:1}"
                    
                    if $escape_next; then
                        pattern="${pattern}\\$char"
                        escape_next=false
                        ((pos++))
                        continue
                    fi
                    
                    case "$char" in
                        '\\')
                            escape_next=true
                            pattern="${pattern}$char"
                            ;;
                        '[')
                            in_char_class=true
                            pattern="${pattern}$char"
                            ;;
                        ']')
                            in_char_class=false
                            pattern="${pattern}$char"
                            ;;
                        '/')
                            if $in_char_class; then
                                # Slash inside character class is part of pattern
                                pattern="${pattern}$char"
                            else
                                # Found closing slash
                                ((pos++))
                                
                                # Extract flags
                                local flags=""
                                while [ $pos -lt $line_len ]; do
                                    char="${line:$pos:1}"
                                    case "$char" in
                                        [a-zA-Z])
                                            flags="${flags}$char"
                                            ((pos++))
                                            ;;
                                        *)
                                            break
                                            ;;
                                    esac
                                done
                                
                                # Store the regex
                                regexes+=("$pattern:$flags:$line_number:$regex_start")
                                regex_valid=false
                                continue
                            fi
                            ;;
                        *)
                            pattern="${pattern}$char"
                            ;;
                    esac
                    
                    ((pos++))
                done
                
                # If we reached end of line without finding closing slash
                if $regex_valid && [ $pos -ge $line_len ]; then
                    # Unterminated regex literal
                    regexes+=("$pattern:::$line_number:$regex_start:unterminated")
                fi
            else
                # Not a regex literal, continue
                ((pos++))
            fi
        else
            ((pos++))
        fi
    done
    
    printf "%s\n" "${regexes[@]}"
}

# Function to parse RegExp constructor arguments (simplified)
parse_constructor_args() {
    local args="$1"
    local pattern=""
    local flags=""
    
    # Very simple parsing - just extract content between quotes
    # This is a simplified version for basic cases
    if [[ "$args" =~ \"([^\"]*)\" ]]; then
        pattern="${BASH_REMATCH[1]}"
        # Try to get flags after comma
        if [[ "$args" =~ \"[^\"]*\"[[:space:]]*,[[:space:]]*\"([^\"]*)\" ]]; then
            flags="${BASH_REMATCH[1]}"
        elif [[ "$args" =~ \"[^\"]*\"[[:space:]]*,[[:space:]]*\'([^\']*)\' ]]; then
            flags="${BASH_REMATCH[1]}"
        fi
    elif [[ "$args" =~ \'([^\']*)\' ]]; then
        pattern="${BASH_REMATCH[1]}"
        # Try to get flags after comma
        if [[ "$args" =~ \'[^\']*\'[[:space:]]*,[[:space:]]*\"([^\"]*)\" ]]; then
            flags="${BASH_REMATCH[1]}"
        elif [[ "$args" =~ \'[^\']*\'[[:space:]]*,[[:space:]]*\'([^\']*)\' ]]; then
            flags="${BASH_REMATCH[1]}"
        fi
    fi
    
    echo "$pattern:$flags"
}

# Function to validate regex pattern syntax
validate_regex_pattern() {
    local pattern="$1"
    
    # Quick sanity checks
    if [ -z "$pattern" ]; then
        echo "empty_pattern"
        return 1
    fi
    
    # Check for unescaped forward slash in pattern (only for regex literals)
    # This would be caught during parsing, but check here too
    if [[ "$pattern" == */* ]]; then
        # Check if slash is inside character class
        local temp_pattern="$pattern"
        local in_char_class=0
        local escape_next=0
        
        for ((i=0; i<${#temp_pattern}; i++)); do
            local char="${temp_pattern:$i:1}"
            
            if [ $escape_next -eq 1 ]; then
                escape_next=0
                continue
            fi
            
            case "$char" in
                '\\')
                    escape_next=1
                    ;;
                '[')
                    in_char_class=1
                    ;;
                ']')
                    in_char_class=0
                    ;;
                '/')
                    if [ $in_char_class -eq 0 ]; then
                        echo "unescaped_slash"
                        return 1
                    fi
                    ;;
            esac
        done
    fi
    
    # Check for common regex syntax errors
    local len=${#pattern}
    local in_char_class=0
    local in_escape=0
    local paren_count=0
    local last_char=""
    
    for ((i=0; i<len; i++)); do
        local char="${pattern:$i:1}"
        
        if [ $in_escape -eq 1 ]; then
            in_escape=0
            last_char="$char"
            continue
        fi
        
        case "$char" in
            '\\')
                in_escape=1
                ;;
            '[')
                if [ $in_char_class -eq 0 ]; then
                    in_char_class=1
                    # Check for empty character class
                    if [ $i -lt $((len-1)) ] && [ "${pattern:$((i+1)):1}" = ']' ]; then
                        echo "empty_character_class"
                        return 1
                    fi
                else
                    # Nested character class
                    echo "nested_character_class"
                    return 1
                fi
                ;;
            ']')
                if [ $in_char_class -eq 1 ]; then
                    in_char_class=0
                else
                    # Unmatched closing bracket
                    echo "unmatched_closing_bracket"
                    return 1
                fi
                ;;
            '(')
                ((paren_count++))
                ;;
            ')')
                if [ $paren_count -gt 0 ]; then
                    ((paren_count--))
                else
                    # Unmatched closing paren
                    echo "unmatched_closing_paren"
                    return 1
                fi
                ;;
            '{')
                # Check if quantifier has something to quantify
                if [ -z "$last_char" ] || \
                   [ "$last_char" = '(' ] || [ "$last_char" = '[' ] || \
                   [ "$last_char" = '|' ] || [ "$last_char" = '^' ] || \
                   [ "$last_char" = '$' ]; then
                    echo "nothing_to_repeat"
                    return 1
                fi
                ;;
            '}'|'?'|'*'|'+')
                # Check quantifiers (except '}' which is handled above)
                if [ "$char" != '}' ] && [ $in_char_class -eq 0 ]; then
                    if [ -z "$last_char" ] || \
                       [ "$last_char" = '(' ] || [ "$last_char" = '[' ] || \
                       [ "$last_char" = '|' ] || [ "$last_char" = '^' ] || \
                       [ "$last_char" = '$' ]; then
                        echo "nothing_to_repeat"
                        return 1
                    fi
                fi
                ;;
            '.')
                # Dot is valid anywhere
                ;;
            '|')
                # Check for empty alternative
                if [ $in_char_class -eq 0 ] && \
                   ([ -z "$last_char" ] || [ "$last_char" = '(' ] || [ "$last_char" = '[' ] || [ "$last_char" = '|' ]); then
                    echo "empty_alternative"
                    return 1
                fi
                ;;
        esac
        
        if [ "$char" != '\\' ]; then
            last_char="$char"
        fi
    done
    
    # Check for unclosed constructs
    if [ $in_char_class -eq 1 ]; then
        echo "unclosed_character_class"
        return 1
    fi
    
    if [ $paren_count -gt 0 ]; then
        echo "unclosed_group"
        return 1
    fi
    
    if [ $in_escape -eq 1 ]; then
        echo "dangling_backslash"
        return 1
    fi
    
    echo "valid"
    return 0
}

# Main function to check regex errors in JavaScript code
check_regex_syntax() {
    local filename="$1"
    local line_number=0
    local errors_found=0
    
    # Read file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_number++))
        
        # Extract regex literals from line
        local regex_literals
        regex_literals=$(extract_regex_literals "$line" "$line_number")
        
        # Check each regex literal
        while IFS= read -r regex_info; do
            if [ -n "$regex_info" ]; then
                IFS=':' read -r pattern flags regex_line regex_start extra <<< "$regex_info"
                
                # Check for unterminated regex
                if [ "$extra" = "unterminated" ]; then
                    echo -e "${RED}Regex Error at line $regex_line, column $((regex_start+1)):${NC}"
                    echo "  $line"
                    
                    # Print error indicator
                    local indicator=""
                    for ((i=0; i<regex_start; i++)); do
                        indicator="${indicator} "
                    done
                    echo -e "${indicator}${RED}^${NC}"
                    
                    echo -e "  ${YELLOW}Unterminated regex literal${NC}"
                    echo "$(realpath "$filename")"
                    ((errors_found++))
                    continue
                fi
                
                # Validate flags
                local flag_result
                flag_result=$(validate_flags "$flags")
                
                if [ "$flag_result" != "valid" ]; then
                    echo -e "${RED}Regex Error at line $regex_line, column $((regex_start+1)):${NC}"
                    echo "  $line"
                    
                    # Print error indicator
                    local indicator=""
                    for ((i=0; i<regex_start; i++)); do
                        indicator="${indicator} "
                    done
                    echo -e "${indicator}${RED}^${NC}"
                    
                    case "$flag_result" in
                        "invalid")
                            echo -e "  ${YELLOW}Invalid regex flag in '$flags'${NC}"
                            ;;
                        "duplicate")
                            echo -e "  ${YELLOW}Duplicate regex flag in '$flags'${NC}"
                            ;;
                    esac
                    echo "$(realpath "$filename")"
                    ((errors_found++))
                fi
                
                # Validate pattern syntax
                local pattern_result
                pattern_result=$(validate_regex_pattern "$pattern")
                
                if [ "$pattern_result" != "valid" ]; then
                    echo -e "${RED}Regex Error at line $regex_line, column $((regex_start+1)):${NC}"
                    echo "  $line"
                    
                    # Print error indicator
                    local indicator=""
                    for ((i=0; i<regex_start; i++)); do
                        indicator="${indicator} "
                    done
                    echo -e "${indicator}${RED}^${NC}"
                    
                    case "$pattern_result" in
                        "empty_pattern")
                            echo -e "  ${YELLOW}Empty regex pattern${NC}"
                            ;;
                        "empty_character_class")
                            echo -e "  ${YELLOW}Empty character class${NC}"
                            ;;
                        "nested_character_class")
                            echo -e "  ${YELLOW}Nested character class${NC}"
                            ;;
                        "unmatched_closing_bracket")
                            echo -e "  ${YELLOW}Unmatched closing bracket${NC}"
                            ;;
                        "unmatched_closing_paren")
                            echo -e "  ${YELLOW}Unmatched closing parenthesis${NC}"
                            ;;
                        "nothing_to_repeat")
                            echo -e "  ${YELLOW}Quantifier without preceding element${NC}"
                            ;;
                        "empty_alternative")
                            echo -e "  ${YELLOW}Empty alternative in pattern${NC}"
                            ;;
                        "unclosed_character_class")
                            echo -e "  ${YELLOW}Unclosed character class${NC}"
                            ;;
                        "unclosed_group")
                            echo -e "  ${YELLOW}Unclosed group${NC}"
                            ;;
                        "dangling_backslash")
                            echo -e "  ${YELLOW}Dangling backslash at end of pattern${NC}"
                            ;;
                        "unescaped_slash")
                            echo -e "  ${YELLOW}Unescaped forward slash in pattern${NC}"
                            ;;
                        *)
                            echo -e "  ${YELLOW}Pattern syntax error: $pattern_result${NC}"
                            ;;
                    esac
                    echo "$(realpath "$filename")"
                    ((errors_found++))
                fi
            fi
        done <<< "$regex_literals"
        
    done < "$filename"
    
    return $errors_found
}

# Function to audit a single JavaScript file for regex errors
audit_js_file() {
    local filename="$1"
    
    if [ ! -f "$filename" ]; then
        echo -e "${RED}Error: File '$filename' not found${NC}"
        return 1
    fi
    
    if [[ ! "$filename" =~ \.js$ ]]; then
        echo -e "${YELLOW}Warning: File '$filename' doesn't have .js extension${NC}"
    fi
    
    echo -e "${CYAN}Auditing regex syntax in:${NC} ${filename}"
    echo "========================================"
    
    # Check file size
    local file_size=$(wc -c < "$filename")
    if [ $file_size -eq 0 ]; then
        echo -e "${GREEN}✓ Empty file - no regex errors${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    fi
    
    # Run our regex syntax checker
    local error_count
    if check_regex_syntax "$filename"; then
        error_count=$?
        if [ $error_count -eq 0 ]; then
            echo -e "${GREEN}✓ No regex syntax errors found${NC}"
            echo -e "${GREEN}PASS${NC}"
            return 0
        else
            echo -e "${RED}✗ Found $error_count regex syntax error(s)${NC}"
            echo -e "${RED}FAIL${NC}"
            return 1
        fi
    else
        error_count=$?
        echo -e "${RED}✗ Found $error_count regex syntax error(s)${NC}"
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running Regular Expression Syntax Test Suite${NC}"
    echo "========================================"
    
    # Check if test directory exists
    if [ ! -d "$TEST_DIR" ]; then
        echo -e "${YELLOW}Test directory '$TEST_DIR' not found.${NC}"
        echo -e "${CYAN}Please run tests.sh first to generate test files.${NC}"
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
        
        # Skip valid test files for now
        if [[ "$filename" == valid_* ]]; then
            echo -e "${BLUE}Test ${total_tests}: ${filename} (should pass)${NC}"
            if audit_js_file "$test_file" 2>/dev/null; then
                echo -e "${GREEN}  ✓ Correctly passed valid regex${NC}"
                ((passed_tests++))
            else
                echo -e "${RED}  ✗ Incorrectly flagged valid regex as error${NC}"
                ((failed_tests++))
            fi
        else
            echo -e "${BLUE}Test ${total_tests}: ${filename} (should fail)${NC}"
            if audit_js_file "$test_file" 2>/dev/null; then
                echo -e "${RED}  ✗ Expected to detect error but passed${NC}"
                ((failed_tests++))
            else
                echo -e "${GREEN}  ✓ Correctly detected regex error${NC}"
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
        echo -e "${YELLOW}Consider running 'bash tests.sh' manually to generate test files.${NC}"
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
