#!/bin/bash

# JavaScript Token Error Auditor - Pure Bash Implementation
# Usage: ./basics.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="2.3.0"
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
    local context_stack=()  # Track context: "function", "loop", "switch", "async", "generator"
    local in_function=false
    local in_loop=false
    local in_switch=false
    local in_async_context=false
    local in_generator=false
    local in_try_block=false
    local case_default_seen=false
    local in_delete_context=false
    local in_new_context=false
    local label_pending=false
    local in_optional_chain=false
    
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
                               [ "$last_non_ws_token" != ":" ] && [ "$last_non_ws_token" != "," ] && \
                               [ "$last_non_ws_token" != "export" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected '$token'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check control flow keywords
                        'if'|'while'|'for'|'switch'|'catch')
                            if [ "$last_non_ws_token" != "" ] && [ "$last_non_ws_token" != ";" ] && \
                               [ "$last_non_ws_token" != "{" ] && [ "$last_non_ws_token" != "}" ] && \
                               [ "$last_non_ws_token" != ")" ] && [ "$last_non_ws_token" != "else" ] && \
                               [ "$last_non_ws_token" != "try" ] && [ "$last_non_ws_token" != "finally" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected '$token'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            if [ "$token" = "if" ] || [ "$token" = "while" ] || [ "$token" = "for" ] || [ "$token" = "switch" ]; then
                                expecting_expression=true
                            fi
                            ;;
                            
                        # Check for lonely semicolon (semicolon without preceding expression)
                        ';')
                            # Check for new without constructor - FIXED: Test 49
                            if $in_new_context; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'new' operator without constructor${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
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
                            in_delete_context=false
                            in_new_context=false
                            in_optional_chain=false
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
                            in_optional_chain=false
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
                               [ "$last_non_ws_token" != "%" ] && [ "$last_non_ws_token" != "?" ] && \
                               [ "$last_non_ws_token" != ":" ] && [ "$last_non_ws_token" != "&&" ] && \
                               [ "$last_non_ws_token" != "||" ] && [ "$last_non_ws_token" != "??" ]; then
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
                            # Special case: check for lonely dot after delete or new
                            if $in_delete_context && [ "$last_non_ws_token" = "delete" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Delete operator with trailing dot${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # General lonely dot check
                            if [ "$last_non_ws_token" = "" ] || \
                               [ "$last_non_ws_token" = "." ] || \
                               [ "$last_non_ws_token" = ";" ] || \
                               [ "$last_non_ws_token" = "{" ] || \
                               [ "$last_non_ws_token" = "}" ] || \
                               [ "$last_non_ws_token" = "(" ] || \
                               [ "$last_non_ws_token" != "]" ] && [ "$last_non_ws_token" != ")" ] && \
                               [ "$last_non_ws_token" != "identifier" ] && [ "$last_non_ws_token" != "]" ] && \
                               ! [[ "$last_non_ws_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && \
                               [ "$last_non_ws_token" != "?" ] && [ "$last_non_ws_token" != "?." ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected dot${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check if dot is followed by valid identifier
                            local lookahead_col=$((col+1))
                            local next_token=""
                            while [ $lookahead_col -lt $line_length ] && is_whitespace "${line:$lookahead_col:1}"; do
                                ((lookahead_col++))
                            done
                            
                            if [ $lookahead_col -lt $line_length ]; then
                                next_token=$(get_token "$line" $lookahead_col)
                                if [ "$next_token" = ";" ] || [ "$next_token" = "" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Property access without property name${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            else
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Property access without property name${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for invalid optional chaining - FIXED: Tests 33, 34
                        '?'|'?.')
                            # Track that we're in optional chain context
                            in_optional_chain=true
                            
                            # Check for '?' without following . [ ( 
                            if [ "$token" = "?" ]; then
                                # Look ahead to see what follows
                                local lookahead_col=$((col+1))
                                local found_valid=false
                                local found_dot=false
                                local found_bracket_or_paren=false
                                while [ $lookahead_col -lt $line_length ]; do
                                    local next_tok_char="${line:$lookahead_col:1}"
                                    # Skip whitespace
                                    if is_whitespace "$next_tok_char"; then
                                        ((lookahead_col++))
                                        continue
                                    fi
                                    # Check for dot after ?
                                    if [ "$next_tok_char" = "." ]; then
                                        found_dot=true
                                        break
                                    fi
                                    # Check for [ or ( after ? (which is invalid without dot)
                                    if [ "$next_tok_char" = "[" ] || [ "$next_tok_char" = "(" ]; then
                                        found_bracket_or_paren=true
                                        break
                                    fi
                                    # Other characters break the check
                                    break
                                done
                                
                                # If found [ or ( without dot, it's an error
                                if $found_bracket_or_paren && ! $found_dot; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Optional chaining requires dot before bracket or paren${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                
                                # Also check if ? is followed by nothing (end of line)
                                if [ $lookahead_col -ge $line_length ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid optional chaining${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            
                            # Check for '?.' at start or after invalid tokens
                            if [ "$token" = "?." ] && \
                               [ "$last_non_ws_token" = "" ] || \
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
                            
                        # Check for empty brackets
                        '[')
                            # Check if this is empty brackets like obj[]
                            local lookahead_col=$((col+1))
                            local next_token=""
                            if [ $lookahead_col -lt $line_length ]; then
                                next_token=$(get_token "$line" $lookahead_col)
                            fi
                            if [ "$next_token" = "]" ] && [ "$last_non_ws_token" != "?" ] && [ "${last_non_ws_token: -1}" != "?" ] && ! $in_optional_chain; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Empty brackets${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for break/continue outside loop/switch
                        'break'|'continue')
                            if ! $in_loop && ! $in_switch && [ "$token" = "break" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'break' outside loop or switch${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            if ! $in_loop && [ "$token" = "continue" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'continue' outside loop${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for return outside function
                        'return')
                            if ! $in_function; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'return' outside function${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for await outside async context
                        'await')
                            if ! $in_async_context; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'await' outside async function${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for yield outside generator
                        'yield')
                            if ! $in_generator; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'yield' outside generator${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for function keyword
                        'function')
                            if [ "$last_non_ws_token" != "" ] && [ "$last_non_ws_token" != ";" ] && \
                               [ "$last_non_ws_token" != "{" ] && [ "$last_non_ws_token" != "}" ] && \
                               [ "$last_non_ws_token" != "(" ] && [ "$last_non_ws_token" != ")" ] && \
                               [ "$last_non_ws_token" != ":" ] && [ "$last_non_ws_token" != "," ] && \
                               [ "$last_non_ws_token" != "export" ] && [ "$last_non_ws_token" != "async" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected 'function'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            expecting_expression=true  # Expect function name or parameters
                            ;;
                            
                        # Check for try without braces
                        'try')
                            if [ "$last_non_ws_token" != "" ] && [ "$last_non_ws_token" != ";" ] && \
                               [ "$last_non_ws_token" != "{" ] && [ "$last_non_ws_token" != "}" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected 'try'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            in_try_block=true
                            ;;
                            
                        # Check for new without constructor - FIXED: Test 49
                        'new')
                            if [ "$last_non_ws_token" != "" ] && [ "$last_non_ws_token" != ";" ] && \
                               [ "$last_non_ws_token" != "{" ] && [ "$last_non_ws_token" != "}" ] && \
                               [ "$last_non_ws_token" != "(" ] && [ "$last_non_ws_token" != ")" ] && \
                               [ "$last_non_ws_token" != "[" ] && [ "$last_non_ws_token" != "]" ] && \
                               [ "$last_non_ws_token" != "," ] && [ "$last_non_ws_token" != "=" ] && \
                               [ "$last_non_ws_token" != "+" ] && [ "$last_non_ws_token" != "-" ] && \
                               [ "$last_non_ws_token" != "*" ] && [ "$last_non_ws_token" != "/" ] && \
                               [ "$last_non_ws_token" != "%" ] && [ "$last_non_ws_token" != "?" ] && \
                               [ "$last_non_ws_token" != ":" ] && [ "$last_non_ws_token" != "&&" ] && \
                               [ "$last_non_ws_token" != "||" ] && [ "$last_non_ws_token" != "??" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected 'new'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            expecting_expression=true  # Expect constructor
                            in_new_context=true
                            ;;
                            
                        # Check for delete operator
                        'delete')
                            if [ "$last_non_ws_token" != "" ] && [ "$last_non_ws_token" != ";" ] && \
                               [ "$last_non_ws_token" != "{" ] && [ "$last_non_ws_token" != "}" ] && \
                               [ "$last_non_ws_token" != "(" ] && [ "$last_non_ws_token" != ")" ] && \
                               [ "$last_non_ws_token" != "[" ] && [ "$last_non_ws_token" != "]" ] && \
                               [ "$last_non_ws_token" != "," ] && [ "$last_non_ws_token" != "=" ] && \
                               [ "$last_non_ws_token" != "+" ] && [ "$last_non_ws_token" != "-" ] && \
                               [ "$last_non_ws_token" != "*" ] && [ "$last_non_ws_token" != "/" ] && \
                               [ "$last_non_ws_token" != "%" ] && [ "$last_non_ws_token" != "?" ] && \
                               [ "$last_non_ws_token" != ":" ] && [ "$last_non_ws_token" != "&&" ] && \
                               [ "$last_non_ws_token" != "||" ] && [ "$last_non_ws_token" != "??" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected 'delete'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            expecting_expression=true  # Expect property access
                            in_delete_context=true
                            ;;
                            
                        # Check for arrow function error
                        '=>')
                            if [ "$last_non_ws_token" = "" ] || [ "$last_non_ws_token" = "=" ] || \
                               [ "$last_non_ws_token" = "(" ] || [ "$last_non_ws_token" = "[" ] || \
                               [ "$last_non_ws_token" = "{" ] || [ "$last_non_ws_token" = "," ] || \
                               [ "$last_non_ws_token" = ";" ] || [ "$last_non_ws_token" = ":" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid arrow function${NC}"
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
                            
                            # Check for label without statement - FIXED: Test 41
                            if [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && [ "$next_char" = ":" ]; then
                                # Set label pending flag
                                label_pending=true
                                
                                # Look ahead to see if there's a statement after the label
                                local label_lookahead=$((col+2))
                                local found_statement=false
                                while [ $label_lookahead -lt $line_length ]; do
                                    local label_next_char="${line:$label_lookahead:1}"
                                    if ! is_whitespace "$label_next_char"; then
                                        found_statement=true
                                        label_pending=false
                                        break
                                    fi
                                    ((label_lookahead++))
                                done
                                
                                # If no statement found on same line, check next lines
                                if ! $found_statement; then
                                    # We'll check at the end of file if label_pending is still true
                                    :
                                fi
                            fi
                            
                            # Reset label_pending if we see any non-whitespace token that's not a label
                            if $label_pending && [ "$token" != ":" ] && [[ ! "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                label_pending=false
                            fi
                            ;;
                    esac
                    
                    # Update context based on tokens
                    case "$token" in
                        '{')
                            if [ "$last_non_ws_token" = "function" ] || \
                               [ "$last_non_ws_token" = "=>" ] || \
                               [[ "$last_non_ws_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && [ "$last_non_ws_token" != "if" ] && [ "$last_non_ws_token" != "while" ] && [ "$last_non_ws_token" != "for" ] && [ "$last_non_ws_token" != "switch" ] && [ "$last_non_ws_token" != "try" ] && [ "$last_non_ws_token" != "catch" ] && [ "$last_non_ws_token" != "finally" ]; then
                                in_function=true
                            elif [ "$last_non_ws_token" = "try" ]; then
                                in_try_block=false
                            elif $in_try_block; then
                                in_try_block=false
                            fi
                            # Reset switch-specific flags when entering new block
                            case_default_seen=false
                            label_pending=false
                            ;;
                        '}')
                            # Check if we're exiting a function context
                            if $in_function && [ $brace_count -eq 0 ]; then
                                in_function=false
                                in_async_context=false
                                in_generator=false
                            fi
                            if $in_loop && [ $brace_count -eq 0 ]; then
                                in_loop=false
                            fi
                            if $in_switch && [ $brace_count -eq 0 ]; then
                                in_switch=false
                                case_default_seen=false
                            fi
                            label_pending=false
                            ;;
                        'while'|'for'|'do')
                            in_loop=true
                            label_pending=false
                            ;;
                        'switch')
                            in_switch=true
                            case_default_seen=false
                            label_pending=false
                            ;;
                        'async')
                            if [ "$last_non_ws_token" = "" ] || [ "$last_non_ws_token" = ";" ] || \
                               [ "$last_non_ws_token" = "{" ] || [ "$last_non_ws_token" = "}" ] || \
                               [ "$last_non_ws_token" = "(" ] || [ "$last_non_ws_token" = ")" ] || \
                               [ "$last_non_ws_token" = ":" ] || [ "$last_non_ws_token" = "," ] || \
                               [ "$last_non_ws_token" = "export" ]; then
                                in_async_context=true
                            fi
                            label_pending=false
                            ;;
                        'function*')
                            in_generator=true
                            label_pending=false
                            ;;
                        'case'|'default')
                            if $in_switch; then
                                if [ "$token" = "default" ] && $case_default_seen; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Duplicate default in switch${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                if [ "$token" = "default" ]; then
                                    case_default_seen=true
                                fi
                            fi
                            label_pending=false
                            ;;
                        *)
                            # Reset optional chain flag for most tokens
                            if [ "$token" != "?" ] && [ "$token" != "?." ]; then
                                in_optional_chain=false
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
                    
                    # Check for missing parentheses after if/while/for/switch
                    if [ "$token" = "if" ] || [ "$token" = "while" ] || [ "$token" = "for" ] || [ "$token" = "switch" ]; then
                        # Look ahead for '('
                        local lookahead_col=$col
                        local found_paren=false
                        while [ $lookahead_col -lt $line_length ]; do
                            local next_tok=$(get_token "$line" $lookahead_col)
                            if [ "$next_tok" = "(" ]; then
                                found_paren=true
                                break
                            elif [ "$next_tok" = "{" ] || [ "$next_tok" = ";" ]; then
                                break
                            fi
                            ((lookahead_col++))
                        done
                        if ! $found_paren; then
                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing parentheses after '$token'${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                    fi
                    
                    # Check for missing colon after case/default
                    if [ "$token" = "case" ] || [ "$token" = "default" ]; then
                        # Look ahead for ':'
                        local lookahead_col=$col
                        local found_colon=false
                        while [ $lookahead_col -lt $line_length ]; do
                            local next_tok=$(get_token "$line" $lookahead_col)
                            if [ "$next_tok" = ":" ]; then
                                found_colon=true
                                break
                            elif [ "$next_tok" = ";" ] || [ "$next_tok" = "{" ] || [ "$next_tok" = "}" ]; then
                                break
                            fi
                            ((lookahead_col++))
                        done
                        if ! $found_colon; then
                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing colon after '$token'${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                    fi
                    
                    # Check for missing braces after try
                    if $in_try_block && [ "$token" = "{" ]; then
                        in_try_block=false
                    elif $in_try_block && [ "$token" != "{" ] && [ "$token" != "catch" ] && [ "$token" != "finally" ]; then
                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing braces after 'try'${NC}"
                        echo "  $line"
                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                        echo "$(realpath "$filename")"
                        return 1
                    fi
                    
                    # Check for missing parentheses after function name
                    if [ "$last_non_ws_token" = "function" ] && [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                        # Function name found, next should be '('
                        local lookahead_col=$col
                        local found_paren=false
                        while [ $lookahead_col -lt $line_length ]; do
                            local next_tok=$(get_token "$line" $lookahead_col)
                            if [ "$next_tok" = "(" ]; then
                                found_paren=true
                                break
                            elif [ "$next_tok" = "{" ] || [ "$next_tok" = ";" ]; then
                                break
                            fi
                            ((lookahead_col++))
                        done
                        if ! $found_paren; then
                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing parentheses after function name${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
                        fi
                    fi
                    
                    # Check for new without constructor - additional check
                    if $in_new_context && [ "$token" = ";" ]; then
                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'new' operator without constructor${NC}"
                        echo "  $line"
                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                        echo "$(realpath "$filename")"
                        return 1
                    fi
                    
                    # Check for delete with dot - additional check
                    if $in_delete_context && [ "$token" = "." ]; then
                        # Look ahead to see if there's a property name
                        local delete_lookahead=$((col+1))
                        local found_property=false
                        while [ $delete_lookahead -lt $line_length ]; do
                            local delete_char="${line:$delete_lookahead:1}"
                            if ! is_whitespace "$delete_char"; then
                                if [[ "$delete_char" =~ [a-zA-Z_$] ]]; then
                                    found_property=true
                                fi
                                break
                            fi
                            ((delete_lookahead++))
                        done
                        if ! $found_property; then
                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'delete' operator without property name${NC}"
                            echo "  $line"
                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                            echo "$(realpath "$filename")"
                            return 1
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
        
        # Check for new without constructor at end of line
        if $in_new_context && [ $col -ge $line_length ]; then
            echo -e "${RED}Error at line $line_number, column $((col+1)): 'new' operator without constructor${NC}"
            echo "  $line"
            printf "%*s^%s\n" $col "" "${RED}here${NC}"
            echo "$(realpath "$filename")"
            return 1
        fi
        
    done < "$filename"
    
    # Check for label without statement at end of file - FIXED: Test 41
    if $label_pending; then
        echo -e "${RED}Error at end of file: Label without statement${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
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
    
    # Check for label without statement at end of file (alternative check)
    if [[ "$last_non_ws_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && [ "${last_non_ws_token: -1}" != ":" ]; then
        # This is okay
        :
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
