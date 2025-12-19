#!/bin/bash

# JavaScript Label Syntax Error Auditor - Pure Bash Implementation
# Usage: ./label.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="3.0.0"
TEST_DIR="label_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Reserved JavaScript keywords (including strict mode reserved words)
RESERVED_WORDS="break case catch class const continue debugger default delete do else enum export extends false finally for function if import in instanceof new null return super switch this throw true try typeof var void while with yield let static implements interface package private protected public as async await get set from of eval arguments"

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
        ' '|$'\t'|$'\n'|$'\r') return  ;;
        *) return 1 ;;
    esac
}

# Function to check if character is valid for label name
is_valid_label_char() {
    local char="$1"
    case "$char" in
        [a-zA-Z0-9_$]) return  ;;
        *) return 1 ;;
    esac
}

# Function to check if character can start a label name
is_valid_label_start() {
    local char="$1"
    case "$char" in
        [a-zA-Z_$]) return  ;;
        *) return 1 ;;
    esac
}

# Function to check if token is a reserved word
is_reserved_word() {
    local token="$1"
    for word in $RESERVED_WORDS; do
        if [ "$token" = "$word" ]; then
            return 
        fi
    done
    return 1
}

# Function to check if token is a strict mode reserved word
is_strict_reserved_word() {
    local token="$1"
    for word in $STRICT_RESERVED_WORDS; do
        if [ "$token" = "$word" ]; then
            return 
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
                    while [ $pos -lt $length ] && is_valid_label_char "${line:$pos:1}"; do
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

# Function to strip comments from a line
strip_comments() {
    local line="$1"
    local result=""
    local in_string=""
    local char
    
    for ((i=0; i<${#line}; i++)); do
        char="${line:i:1}"
        
        if [ -z "$in_string" ]; then
            if [ "$char" = "'" ] || [ "$char" = '"' ] || [ "$char" = '`' ]; then
                in_string="$char"
                result="${result}${char}"
            elif [ "$char" = "/" ] && [ $((i+1)) -lt ${#line} ]; then
                local next_char="${line:$((i+1)):1}"
                if [ "$next_char" = "/" ]; then
                    # Line comment found
                    break
                elif [ "$next_char" = "*" ]; then
                    # Start of block comment - skip ahead
                    ((i++))
                    while [ $((i+1)) -lt ${#line} ] && ! [[ "${line:i:2}" = "*/" ]]; do
                        ((i++))
                    done
                    ((i++))
                else
                    result="${result}${char}"
                fi
            else
                result="${result}${char}"
            fi
        else
            result="${result}${char}"
            if [ "$char" = "$in_string" ] && [ $i -gt 0 ] && [ "${line:$((i-1)):1}" != "\\" ]; then
                in_string=""
            fi
        fi
    done
    
    echo "$result"
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
    local in_do_while=false
    local label_stack=()  # Stack of declared labels
    local label_scopes=() # Stack of scope depths for labels
    local label_types=()  # Stack of label types (loop, block, etc.)
    local brace_depth=0
    local paren_depth=0
    local bracket_depth=0
    local current_scope_depth=0
    local errors_found=0
    local in_case=false
    local in_default=false
    
    # Read file line by line
    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        ((line_number++))
        
        # Strip comments for analysis
        local line=$(strip_comments "$raw_line")
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
                        # Check if this is a regex
                        local prev_token="$last_non_ws_token"
                        local is_regex=false
                        
                        # Heuristic: if previous token looks like it could be followed by regex
                        if [ -z "$prev_token" ] || \
                           [ "$prev_token" = "=" ] || [ "$prev_token" = ":" ] || \
                           [ "$prev_token" = "(" ] || [ "$prev_token" = "," ] || \
                           [ "$prev_token" = "[" ] || [ "$prev_token" = "!" ] || \
                           [ "$prev_token" = "~" ] || [ "$prev_token" = "typeof" ] || \
                           [ "$prev_token" = "void" ] || [ "$prev_token" = "delete" ] || \
                           [ "$prev_token" = "instanceof" ] || [ "$prev_token" = "in" ] || \
                           [ "$prev_token" = "?" ] || [ "$prev_token" = "||" ] || \
                           [ "$prev_token" = "&&" ] || [ "$prev_token" = "??" ] || \
                           [ "$prev_token" = "return" ] || [ "$prev_token" = "throw" ] || \
                           [ "$prev_token" = "yield" ] || [ "$prev_token" = "await" ]; then
                            is_regex=true
                        fi
                        
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
                    local quote_char="$char"
                    ((col++))
                    while [ $col -lt $line_length ] && [ "${line:$col:1}" != "$quote_char" ]; do
                        directive="${directive}${line:$col:1}"
                        ((col++))
                    done
                    if [ "$directive" = "use strict" ]; then
                        in_strict_mode=true
                    fi
                    # Restore col position for normal parsing
                    col=$dir_start
                fi
            fi
            
            # Only check syntax if not inside string/comment/regex
            if ! $in_string_single && ! $in_string_double && ! $in_template && \
               ! $in_comment_single && ! $in_comment_multi && ! $in_regex; then
                # Update depth tracking
                case "$char" in
                    '{') 
                        ((brace_depth++))
                        ((current_scope_depth++))
                        ;;
                    '}') 
                        ((brace_depth--))
                        # Remove labels from this scope when exiting
                        for ((i=${#label_stack[@]}-1; i>=0; i--)); do
                            if [ "${label_scopes[$i]}" -eq $current_scope_depth ]; then
                                unset label_stack[$i]
                                unset label_scopes[$i]
                                unset label_types[$i]
                            fi
                        done
                        # Reindex arrays
                        label_stack=("${label_stack[@]}")
                        label_scopes=("${label_scopes[@]}")
                        label_types=("${label_types[@]}")
                        ((current_scope_depth--))
                        ;;
                    '(') ((paren_depth++)) ;;
                    ')') ((paren_depth--)) ;;
                    '[') ((bracket_depth++)) ;;
                    ']') ((bracket_depth--)) ;;
                esac
                
                # Get current token
                local token
                token=$(get_token "$line" $col)
                local token_length=${#token}
                
                if [ -n "$token" ] && [ "$token_length" -gt 0 ]; then
                    # Update column position
                    ((col += token_length - 1))
                    
                    # Check for label declarations (identifier followed by colon)
                    if [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && [ $((col+1)) -lt $line_length ] && [ "${line:$((col+1)):1}" = ":" ]; then
                        local label_name="$token"
                        local label_line=$line_number
                        local label_col=$((col - token_length + 2))
                        
                        # Check for invalid label characters
                        if [[ "$label_name" =~ [^a-zA-Z0-9_$] ]]; then
                            echo -e "${RED}Error at line $label_line, column $label_col: Invalid character in label name '$label_name'${NC}"
                            echo "  $raw_line"
                            printf "%*s^%s\n" $((label_col-1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            errors_found=1
                        fi
                        
                        # Check for reserved words
                        if is_reserved_word "$label_name"; then
                            echo -e "${RED}Error at line $label_line, column $label_col: Reserved word '$label_name' cannot be used as label${NC}"
                            echo "  $raw_line"
                            printf "%*s^%s\n" $((label_col-1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            errors_found=1
                        fi
                        
                        if $in_strict_mode && is_strict_reserved_word "$label_name"; then
                            echo -e "${RED}Error at line $label_line, column $label_col: Strict mode reserved word '$label_name' cannot be used as label${NC}"
                            echo "  $raw_line"
                            printf "%*s^%s\n" $((label_col-1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            errors_found=1
                        fi
                        
                        # Check for numeric labels
                        if [[ "$label_name" =~ ^[0-9] ]]; then
                            echo -e "${RED}Error at line $label_line, column $label_col: Label cannot start with number '$label_name'${NC}"
                            echo "  $raw_line"
                            printf "%*s^%s\n" $((label_col-1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            errors_found=1
                        fi
                        
                        # Check for duplicate label in same scope
                        for ((i=0; i<${#label_stack[@]}; i++)); do
                            if [ "${label_stack[$i]}" = "$label_name" ] && [ "${label_scopes[$i]}" -eq $current_scope_depth ]; then
                                echo -e "${RED}Error at line $label_line, column $label_col: Duplicate label '$label_name' in same scope${NC}"
                                echo "  $raw_line"
                                printf "%*s^%s\n" $((label_col-1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                errors_found=1
                                break
                            fi
                        done
                        
                        # Only add to stack if no errors found for this label
                        if [ $errors_found -eq 0 ]; then
                            label_stack+=("$label_name")
                            label_scopes+=($current_scope_depth)
                            label_types+=("unknown")
                            last_label="$label_name"
                            expecting_label_colon=true
                        fi
                    fi
                    
                    # Check for colon after label
                    if [ "$token" = ":" ] && $expecting_label_colon; then
                        expecting_label_colon=false
                        
                        # Look ahead to see what follows the label
                        local lookahead_col=$((col+1))
                        local found_valid=false
                        local next_token=""
                        
                        # Skip whitespace
                        while [ $lookahead_col -lt $line_length ] && is_whitespace "${line:$lookahead_col:1}"; do
                            ((lookahead_col++))
                        done
                        
                        # Get the next token after colon
                        next_token=$(get_token "$line" $lookahead_col)
                        
                        # Check if we're at end of line (no statement after colon)
                        if [ -z "$next_token" ] || [ "$next_token" = ";" ]; then
                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Label '$last_label' with empty statement${NC}"
                            echo "  $raw_line"
                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            errors_found=1
                        else
                            # Check if labeled statement is valid
                            case "$next_token" in
                                'for'|'while'|'do')
                                    # Valid loop label
                                    found_valid=true
                                    # Update label type
                                    for ((i=0; i<${#label_stack[@]}; i++)); do
                                        if [ "${label_stack[$i]}" = "$last_label" ]; then
                                            label_types[$i]="loop"
                                            break
                                        fi
                                    done
                                    ;;
                                '{')
                                    # Valid block label
                                    found_valid=true
                                    # Update label type
                                    for ((i=0; i<${#label_stack[@]}; i++)); do
                                        if [ "${label_stack[$i]}" = "$last_label" ]; then
                                            label_types[$i]="block"
                                            break
                                        fi
                                    done
                                    ;;
                                'function')
                                    # Function declarations cannot be labeled (even in non-strict mode)
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Cannot label function declaration${NC}"
                                    echo "  $raw_line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    errors_found=1
                                    ;;
                                'class'|'const'|'let'|'var'|'import'|'export'|'debugger'|'return'|'throw'|'break'|'continue')
                                    # These cannot be labeled
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Cannot label '$next_token' statement${NC}"
                                    echo "  $raw_line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    errors_found=1
                                    ;;
                                'if'|'switch'|'try'|'with'|'else'|'catch'|'finally')
                                    # These cannot be labeled
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Cannot label '$next_token' statement${NC}"
                                    echo "  $raw_line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    errors_found=1
                                    ;;
                                *)
                                    # Check if it looks like an expression statement
                                    if [[ "$next_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] || \
                                       [[ "$next_token" =~ ^[0-9] ]] || \
                                       [ "$next_token" = "(" ] || [ "$next_token" = "[" ] || \
                                       [ "$next_token" = "++" ] || [ "$next_token" = "--" ] || \
                                       [ "$next_token" = "+" ] || [ "$next_token" = "-" ] || \
                                       [ "$next_token" = "!" ] || [ "$next_token" = "~" ] || \
                                       [ "$next_token" = "typeof" ] || [ "$next_token" = "void" ] || \
                                       [ "$next_token" = "delete" ] || [ "$next_token" = "new" ] || \
                                       [ "$next_token" = "await" ] || [ "$next_token" = "yield" ] || \
                                       [ "$next_token" = "this" ] || [ "$next_token" = "super" ] || \
                                       [ "$next_token" = "true" ] || [ "$next_token" = "false" ] || \
                                       [ "$next_token" = "null" ] || [ "$next_token" = "undefined" ]; then
                                        # Expression statement - INVALID for labels
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Label '$last_label' on expression statement${NC}"
                                        echo "  $raw_line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        errors_found=1
                                    fi
                                    ;;
                            esac
                        fi
                    fi
                    
                    # Check for colon in invalid position (after for/while/do without being a label)
                    if [ "$token" = ":" ] && ! $expecting_label_colon && \
                       ([ "$last_non_ws_token" = "for" ] || [ "$last_non_ws_token" = "while" ] || [ "$last_non_ws_token" = "do" ]); then
                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Colon cannot follow '$last_non_ws_token' statement${NC}"
                        echo "  $raw_line"
                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                        echo "$(realpath "$filename")"
                        errors_found=1
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
                                local label_type=""
                                local label_index=-1
                                
                                # Search for the label in stack
                                for ((i=0; i<${#label_stack[@]}; i++)); do
                                    if [ "${label_stack[$i]}" = "$label_name" ]; then
                                        label_found=true
                                        label_type="${label_types[$i]}"
                                        label_index=$i
                                        break
                                    fi
                                done
                                
                                if $label_found; then
                                    # Check context for continue - must reference a loop label
                                    if [ "$token" = "continue" ] && [ "$label_type" != "loop" ]; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'continue' can only reference loop labels${NC}"
                                        echo "  $raw_line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        errors_found=1
                                    fi
                                else
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Undefined label '$label_name'${NC}"
                                    echo "  $raw_line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    errors_found=1
                                fi
                            fi
                        fi
                    fi
                    
                    # Update context based on tokens
                    case "$token" in
                        '{')
                            in_block=true
                            # Check if this is an object literal vs block
                            if [ "$last_non_ws_token" = "=" ] || [ "$last_non_ws_token" = ":" ] || \
                               [ "$last_non_ws_token" = "," ] || [ "$last_non_ws_token" = "(" ] || \
                               [ "$last_non_ws_token" = "[" ] || [ "$last_non_ws_token" = "{" ] || \
                               [ "$last_non_ws_token" = "return" ] || [ "$last_non_ws_token" = "yield" ] || \
                               [ "$last_non_ws_token" = "=>" ]; then
                                # This is likely an object literal, not a block
                                in_block=false
                            fi
                            ;;
                        '}')
                            # Exiting a block or object literal
                            in_block=false
                            in_case=false
                            in_default=false
                            ;;
                        'function')
                            in_function=true
                            ;;
                        'for'|'while')
                            in_loop=true
                            in_do_while=false
                            ;;
                        'do')
                            in_loop=true
                            in_do_while=true
                            ;;
                        'switch')
                            in_switch=true
                            in_loop=false
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
                        'case')
                            in_case=true
                            ;;
                        'default')
                            in_default=true
                            ;;
                        ';')
                            # Check if we're ending a do-while loop
                            if $in_do_while && [ "$last_non_ws_token" = ")" ]; then
                                in_loop=false
                                in_do_while=false
                            fi
                            # Reset case/default context
                            in_case=false
                            in_default=false
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
        
    done < "$filename"
    
    # Check for unterminated constructs
    if $in_string_single; then
        echo -e "${RED}Error: Unterminated single-quoted string${NC}"
        echo "$(realpath "$filename")"
        errors_found=1
    fi
    if $in_string_double; then
        echo -e "${RED}Error: Unterminated double-quoted string${NC}"
        echo "$(realpath "$filename")"
        errors_found=1
    fi
    if $in_template; then
        echo -e "${RED}Error: Unterminated template literal${NC}"
        echo "$(realpath "$filename")"
        errors_found=1
    fi
    if $in_comment_multi; then
        echo -e "${RED}Error: Unterminated multi-line comment${NC}"
        echo "$(realpath "$filename")"
        errors_found=1
    fi
    if $in_regex; then
        echo -e "${RED}Error: Unterminated regular expression${NC}"
        echo "$(realpath "$filename")"
        errors_found=1
    fi
    
    # Check for unclosed braces/parens/brackets
    if [ $brace_depth -ne 0 ]; then
        echo -e "${RED}Error: Unbalanced braces${NC}"
        echo "$(realpath "$filename")"
        errors_found=1
    fi
    if [ $paren_depth -ne 0 ]; then
        echo -e "${RED}Error: Unbalanced parentheses${NC}"
        echo "$(realpath "$filename")"
        errors_found=1
    fi
    if [ $bracket_depth -ne 0 ]; then
        echo -e "${RED}Error: Unbalanced brackets${NC}"
        echo "$(realpath "$filename")"
        errors_found=1
    fi
    
    return $errors_found
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
