#!/bin/bash

# JavaScript Array Literal Syntax Auditor - Pure Bash Implementation
# Usage: ./arrays.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="1.0.0"
TEST_DIR="arrays_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display usage
show_usage() {
    echo -e "${BLUE}JavaScript Array Literal Syntax Auditor v${AUDIT_SCRIPT_VERSION}${NC}"
    echo "Pure bash implementation - No Node.js required"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Audit a specific JavaScript file for array literal errors"
    echo "  --test           Run test suite against known array error patterns"
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

# Function to check if character is valid for variable name
is_valid_var_char() {
    local char="$1"
    case "$char" in
        [a-zA-Z0-9_$]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to check if character is a digit
is_digit() {
    local char="$1"
    case "$char" in
        [0-9]) return 0 ;;
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
            # Numbers
            [0-9])
                token="$char"
                ((pos++))
                while [ $pos -lt $length ]; do
                    local next_char="${line:$pos:1}"
                    if [[ "$next_char" =~ [0-9] ]] || [ "$next_char" = "." ] || \
                       [ "$next_char" = "e" ] || [ "$next_char" = "E" ] || \
                       [ "$next_char" = "x" ] || [ "$next_char" = "X" ] || \
                       [ "$next_char" = "o" ] || [ "$next_char" = "O" ] || \
                       [ "$next_char" = "b" ] || [ "$next_char" = "B" ] || \
                       [ "$next_char" = "+" ] || [ "$next_char" = "-" ]; then
                        token="${token}${next_char}"
                        ((pos++))
                    else
                        break
                    fi
                done
                ;;
            # Spread operator
            '.')
                token="$char"
                ((pos++))
                # Check for spread operator
                if [ $pos -lt $length ] && [ "${line:$pos:1}" = "." ]; then
                    token=".."
                    ((pos++))
                    if [ $pos -lt $length ] && [ "${line:$pos:1}" = "." ]; then
                        token="..."
                        ((pos++))
                    fi
                fi
                ;;
            # Identifiers
            *)
                if is_valid_var_start "$char"; then
                    while [ $pos -lt $length ] && is_valid_var_char "${line:$pos:1}"; do
                        ((pos++))
                    done
                fi
                ;;
        esac
        
        token="${line:$start:$((pos-start))}"
    fi
    
    echo "$token"
}

# Function to check for array literal syntax errors
check_array_syntax() {
    local filename="$1"
    local line_number=0
    local in_comment_single=false
    local in_comment_multi=false
    local in_string_single=false
    local in_string_double=false
    local in_template=false
    local in_regex=false
    local in_array_literal=false
    local array_depth=0
    local expecting_element=false
    local expecting_comma_or_close=false
    local last_non_ws_token=""
    local array_start_line=0
    local array_start_col=0
    local last_token_was_comma=false
    local last_token_was_spread=false
    local in_expression=false
    local paren_count=0
    local brace_count=0
    local bracket_count=0
    
    # Reserved words that cannot be array elements
    local statement_keywords="break case catch class const continue debugger default delete do else export extends finally for function if import in instanceof new return super switch this throw try typeof var void while with yield let static"
    
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
                    
                    # Track bracket counts
                    case "$token" in
                        '[') ((bracket_count++)) ;;
                        ']') ((bracket_count--)) ;;
                        '(') ((paren_count++)) ;;
                        ')') ((paren_count--)) ;;
                        '{') ((brace_count++)) ;;
                        '}') ((brace_count--)) ;;
                    esac
                    
                    # Check array-specific errors
                    if [ "$token" = "[" ]; then
                        # Check for lonely opening bracket
                        if [ "$last_non_ws_token" = "" ] || \
                           [ "$last_non_ws_token" = ";" ] || \
                           [ "$last_non_ws_token" = "{" ] || \
                           [ "$last_non_ws_token" = "}" ] || \
                           [ "$last_non_ws_token" = "(" ] || \
                           [ "$last_non_ws_token" = ")" ] || \
                           [ "$last_non_ws_token" = "[" ] || \
                           [ "$last_non_ws_token" = "]" ] || \
                           [ "$last_non_ws_token" = "," ] || \
                           [ "$last_non_ws_token" = "=" ] || \
                           [ "$last_non_ws_token" = ":" ] || \
                           [ "$last_non_ws_token" = "?" ] || \
                           [ "$last_non_ws_token" = "=>" ] || \
                           [ "$last_non_ws_token" = "..." ]; then
                            # Valid array start
                            if ! $in_array_literal; then
                                in_array_literal=true
                                array_depth=1
                                array_start_line=$line_number
                                array_start_col=$col
                                expecting_element=true
                                expecting_comma_or_close=false
                                last_token_was_comma=false
                                last_token_was_spread=false
                            else
                                # Nested array
                                ((array_depth++))
                                expecting_element=true
                                expecting_comma_or_close=false
                                last_token_was_comma=false
                            fi
                        else
                            # Could be property access, not array literal
                            # We'll handle this as a bracket access, not array literal
                            :
                        fi
                    elif [ "$token" = "]" ]; then
                        if $in_array_literal && [ $array_depth -eq 1 ]; then
                            # Check for invalid elements before closing
                            if $expecting_element && ! $last_token_was_comma && [ "$last_non_ws_token" != "[" ]; then
                                # Check specific invalid cases
                                case "$last_non_ws_token" in
                                    '+'|'-'|'*'|'/'|'%'|'&'|'|'|'^'|'!'|'='|'<'|'>'| \
                                    '++'|'--'|'**'|'&&'|'||'|'=='|'!='|'<='|'>='| \
                                    '+='|'-='|'*='|'/='|'%='|'&='|'|='|'^='|'??'|'?.')
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Incomplete expression before array close${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                        ;;
                                    '...')
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Spread operator without expression${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                        ;;
                                    'new'|'typeof'|'void'|'delete'|'in'|'instanceof')
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Operator without operand${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                        ;;
                                esac
                            fi
                            
                            # Closing array
                            in_array_literal=false
                            array_depth=0
                            expecting_element=false
                            expecting_comma_or_close=false
                            last_token_was_comma=false
                            last_token_was_spread=false
                        elif $in_array_literal && [ $array_depth -gt 1 ]; then
                            # Closing nested array
                            ((array_depth--))
                            expecting_comma_or_close=true
                            last_token_was_comma=false
                        fi
                    elif $in_array_literal; then
                        # We're inside an array literal, check for errors
                        case "$token" in
                            ',')
                                # Check for invalid comma placement
                                if ! $expecting_comma_or_close && ! $last_token_was_comma && [ "$last_non_ws_token" != "[" ]; then
                                    # Valid comma after element
                                    expecting_element=true
                                    expecting_comma_or_close=false
                                    last_token_was_comma=true
                                    last_token_was_spread=false
                                elif [ "$last_non_ws_token" = "[" ] || $last_token_was_comma; then
                                    # Empty slot (hole) - valid in JavaScript
                                    expecting_element=true
                                    expecting_comma_or_close=false
                                    last_token_was_comma=true
                                    last_token_was_spread=false
                                else
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected comma in array${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                ;;
                            
                            ';')
                                # Semicolon in array is always invalid
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Semicolon in array literal${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                                ;;
                            
                            ':')
                                # Colon in array (except in object literals) is invalid
                                if [ "$last_non_ws_token" != "?" ] && ! [[ "$last_non_ws_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected colon in array${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                ;;
                            
                            '...')
                                # Spread operator
                                if ! $expecting_element || $last_token_was_comma || [ "$last_non_ws_token" = "[" ] || [ "$last_non_ws_token" = "," ]; then
                                    last_token_was_spread=true
                                    expecting_element=true  # Expect expression after spread
                                    expecting_comma_or_close=false
                                    last_token_was_comma=false
                                else
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected spread operator${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                ;;
                            
                            '.'|'..')
                                # Single or double dot (not spread)
                                if $last_token_was_spread || [ "$last_non_ws_token" = "..." ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Incomplete spread operator${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                elif [ "$token" = "." ]; then
                                    # Could be decimal point or property access
                                    # Check if it's a lonely dot
                                    if [ "$last_non_ws_token" = "" ] || \
                                       [ "$last_non_ws_token" = "[" ] || \
                                       [ "$last_non_ws_token" = "," ] || \
                                       ! [[ "$last_non_ws_token" =~ ^[0-9]+$ ]]; then
                                        # Check what follows
                                        local lookahead_col=$((col+1))
                                        local found_digit=false
                                        while [ $lookahead_col -lt $line_length ] && is_whitespace "${line:$lookahead_col:1}"; do
                                            ((lookahead_col++))
                                        done
                                        if [ $lookahead_col -lt $line_length ] && is_digit "${line:$lookahead_col:1}"; then
                                            # It's a decimal point, ok
                                            :
                                        else
                                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Lonely dot in array${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                            echo "$(realpath "$filename")"
                                            return 1
                                        fi
                                    fi
                                fi
                                ;;
                            
                            # Check for statement keywords as array elements
                            'break'|'continue'|'return'|'throw'|'debugger'|'import'|'export'| \
                            'if'|'else'|'for'|'while'|'do'|'switch'|'case'|'default'|'try'|'catch'|'finally')
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Statement keyword '$token' cannot be array element${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                                ;;
                            
                            'function')
                                # Function keyword needs to be followed by name or paren
                                # We'll do a lookahead check
                                local lookahead_col=$((col+1))
                                local found_valid=false
                                while [ $lookahead_col -lt $line_length ]; do
                                    local next_tok=$(get_token "$line" $lookahead_col)
                                    if [ "$next_tok" = "(" ] || [[ "$next_tok" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                        found_valid=true
                                        break
                                    elif [ "$next_tok" = "]" ] || [ "$next_tok" = "," ] || [ "$next_tok" = ";" ]; then
                                        break
                                    fi
                                    ((lookahead_col++))
                                done
                                if ! $found_valid; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid function declaration in array${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                ;;
                            
                            '=>')
                                # Arrow function without parameters
                                if [ "$last_non_ws_token" != ")" ] && [ "$last_non_ws_token" != "]" ] && \
                                   ! [[ "$last_non_ws_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid arrow function in array${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                ;;
                            
                            # Check for operators that need operands
                            '+'|'-'|'*'|'/'|'%'|'&'|'|'|'^'|'!'|'='|'<'|'>'| \
                            '++'|'--'|'**'|'&&'|'||'|'=='|'!='|'<='|'>='| \
                            '+='|'-='|'*='|'/='|'%='|'&='|'|='|'^='|'??'|'?.')
                                # Check if operator is at end of array
                                if $expecting_element && [ "$last_non_ws_token" = "[" ] || $last_token_was_comma; then
                                    # Unary plus/minus or typeof/void at start is ok
                                    if [ "$token" = "+" ] || [ "$token" = "-" ] || \
                                       [ "$token" = "!" ] || [ "$token" = "~" ] || \
                                       [ "$token" = "typeof" ] || [ "$token" = "void" ] || \
                                       [ "$token" = "delete" ]; then
                                        # Valid unary operator
                                        expecting_element=false
                                        expecting_comma_or_close=true
                                        last_token_was_comma=false
                                    else
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Binary operator '$token' without left operand${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                elif $expecting_comma_or_close && [ "$last_non_ws_token" != "[" ] && ! $last_token_was_comma; then
                                    # Could be part of expression, check what follows
                                    local lookahead_col=$((col+1))
                                    local found_operand=false
                                    while [ $lookahead_col -lt $line_length ]; do
                                        local next_tok=$(get_token "$line" $lookahead_col)
                                        if [ "$next_tok" = "]" ] || [ "$next_tok" = "," ]; then
                                            break
                                        elif [ -n "$next_tok" ] && [ "$next_tok" != "" ]; then
                                            found_operand=true
                                            break
                                        fi
                                        ((lookahead_col++))
                                    done
                                    if ! $found_operand; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Operator '$token' without right operand${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                fi
                                ;;
                            
                            # Check for incomplete numbers
                            *)
                                # Check for invalid number formats
                                if [[ "$token" =~ ^[0-9] ]]; then
                                    # Check for invalid number endings
                                    if [[ "$token" =~ \.$ ]] || \
                                       [[ "$token" =~ ^0[xX]$ ]] || \
                                       [[ "$token" =~ ^0[oO]$ ]] || \
                                       [[ "$token" =~ ^0[bB]$ ]] || \
                                       [[ "$token" =~ e$ ]] || \
                                       [[ "$token" =~ E$ ]] || \
                                       [[ "$token" =~ [eE][+-]$ ]]; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid number format '$token'${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                fi
                                
                                # Check for label syntax
                                if [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && [ "$next_char" = ":" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Label syntax not allowed in array${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                ;;
                        esac
                        
                        # Update state based on token (if not handled above)
                        if [ "$token" != "," ] && [ "$token" != ";" ] && [ "$token" != "[" ] && [ "$token" != "]" ]; then
                            if $expecting_element || ! $expecting_comma_or_close; then
                                expecting_element=false
                                expecting_comma_or_close=true
                                last_token_was_comma=false
                                last_token_was_spread=false
                            fi
                        fi
                    fi
                    
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
        
        # Check for unterminated array at end of line
        if $in_array_literal && [ $col -ge $line_length ]; then
            # Look ahead in next lines for closing bracket
            # For now, we'll just note it might be multi-line
            :
        fi
        
    done < "$filename"
    
    # Check for unterminated array
    if $in_array_literal; then
        echo -e "${RED}Error: Unterminated array literal starting at line $array_start_line, column $((array_start_col+1))${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    # Check for unterminated strings/comments
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

# Function to audit a single JavaScript file for array errors
audit_js_file() {
    local filename="$1"
    
    if [ ! -f "$filename" ]; then
        echo -e "${RED}Error: File '$filename' not found${NC}"
        return 1
    fi
    
    if [[ ! "$filename" =~ \.js$ ]]; then
        echo -e "${YELLOW}Warning: File '$filename' doesn't have .js extension${NC}"
    fi
    
    echo -e "${CYAN}Auditing arrays in:${NC} ${filename}"
    echo "========================================"
    
    # Check file size
    local file_size=$(wc -c < "$filename")
    if [ $file_size -eq 0 ]; then
        echo -e "${GREEN}✓ Empty file - no array errors${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    fi
    
    # Run our array syntax checker
    if check_array_syntax "$filename"; then
        echo -e "${GREEN}✓ No array literal syntax errors found${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running JavaScript Array Literal Error Test Suite${NC}"
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
            echo -e "${GREEN}  ✓ Correctly detected array error${NC}"
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
