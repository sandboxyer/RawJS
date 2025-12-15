#!/bin/bash

# JavaScript Statement Structure Error Auditor
# Pure Bash Implementation
# Usage: ./statement.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="1.1.0"
TEST_DIR="statement_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display usage
show_usage() {
    echo -e "${BLUE}JavaScript Statement Structure Error Auditor v${AUDIT_SCRIPT_VERSION}${NC}"
    echo "Pure bash implementation - No Node.js required"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Audit a specific JavaScript file for statement structure errors"
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

# Function to check if token is a number literal
is_number() {
    local token="$1"
    [[ "$token" =~ ^[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$ ]]
}

# Function to check if token is a string literal
is_string() {
    local token="$1"
    [[ "$token" =~ ^[\'\"\`] ]]
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
                local quote="$char"
                token="$char"
                ((pos++))
                # Skip to end of string
                while [ $pos -lt $length ]; do
                    if [ "${line:$pos:1}" = "\\" ]; then
                        ((pos++)) # Skip escape character
                    elif [ "${line:$pos:1}" = "$quote" ]; then
                        ((pos++))
                        break
                    fi
                    ((pos++))
                done
                ;;
            # Identifiers and numbers
            *)
                if is_valid_var_start "$char"; then
                    while [ $pos -lt $length ] && (is_valid_var_char "${line:$pos:1}" || [ "${line:$pos:1}" = "$" ]); do
                        ((pos++))
                    done
                elif [[ "$char" =~ [0-9] ]]; then
                    token="$char"
                    ((pos++))
                    while [ $pos -lt $length ] && ([[ "${line:$pos:1}" =~ [0-9] ]] || [ "${line:$pos:1}" = "." ] || [ "${line:$pos:1}" = "e" ] || [ "${line:$pos:1}" = "E" ]); do
                        token="${token}${line:$pos:1}"
                        ((pos++))
                    done
                fi
                ;;
        esac
        
        token="${line:$start:$((pos-start))}"
    fi
    
    echo "$token"
}

# Function to peek at next token
peek_token() {
    local line="$1"
    local pos="$2"
    local length=${#line}
    local saved_pos=$pos
    
    # Skip whitespace
    while [ $pos -lt $length ] && is_whitespace "${line:$pos:1}"; do
        ((pos++))
    done
    
    if [ $pos -lt $length ]; then
        local char="${line:$pos:1}"
        local token=""
        
        case "$char" in
            ';'|','|'.'|'('|')'|'{'|'}'|'['|']'|':'|'?'|'~'|'@'|'#'|'`')
                token="$char"
                ;;
            '+'|'-'|'*'|'/'|'%'|'&'|'|'|'^'|'!'|'='|'<'|'>')
                token="$char"
                if [ $((pos+1)) -lt $length ]; then
                    local next_char="${line:$((pos+1)):1}"
                    case "${char}${next_char}" in
                        '++'|'--'|'**'|'<<'|'>>'|'&&'|'||'|'=='|'!='|'<='|'>='|'+='|'-='|'*='|'/='|'%='|'&='|'|='|'^='|'??'|'?.')
                            token="${char}${next_char}"
                            ;;
                        '=>')
                            token="${char}${next_char}"
                            ;;
                    esac
                fi
                ;;
            "'"|'"'|'`')
                token="$char"
                ;;
            *)
                if is_valid_var_start "$char"; then
                    token="$char"
                elif [[ "$char" =~ [0-9] ]]; then
                    token="$char"
                fi
                ;;
        esac
        
        echo "$token"
    fi
}

# Function to check statement structure errors
check_statement_errors() {
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
    
    # Context tracking
    local in_function=false
    local function_name=""
    local in_loop=false
    local loop_type="" # "for", "while", "do", "for-in", "for-of"
    local in_switch=false
    local in_case=false
    local in_default=false
    local in_class=false
    local class_name=""
    local extends_class=false
    local in_async_context=false
    local in_generator=false
    local in_try_block=false
    local in_catch_block=false
    local in_finally_block=false
    local in_object_literal=false
    local in_array_literal=false
    local in_destructuring=false
    local destructuring_type="" # "object", "array", "params"
    
    # State tracking
    local last_token=""
    local last_non_ws_token=""
    local expecting_identifier=false
    local expecting_expression=false
    local expecting_operator=false
    local expecting_colon=false
    local expecting_comma=false
    local expecting_semicolon=false
    local expecting_equals=false
    
    # Declaration tracking
    local declared_variables=()
    local in_declaration=false
    local declaration_type="" # "let", "const", "var", "function", "class"
    local in_import_export=false
    local import_export_type=""
    
    # Enhanced tracking for new error types
    local last_assignment_lhs=""
    local in_assignment=false
    local import_has_from=false
    local import_has_specifier=false
    local export_has_value=false
    local destructuring_has_value=false
    local after_colon_in_object=false
    
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
                    
                    # Check for statement structure errors
                    case "$token" in
                        # Declaration errors
                        'let'|'const'|'var')
                            in_declaration=true
                            declaration_type="$token"
                            expecting_identifier=true
                            
                            # Check for invalid previous token
                            if [ "$last_non_ws_token" != "" ] && [ "$last_non_ws_token" != ";" ] && \
                               [ "$last_non_ws_token" != "{" ] && [ "$last_non_ws_token" != "}" ] && \
                               [ "$last_non_ws_token" != "(" ] && [ "$last_non_ws_token" != ")" ] && \
                               [ "$last_non_ws_token" != "," ] && [ "$last_non_ws_token" != ":" ] && \
                               [ "$last_non_ws_token" != "export" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected '$token'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Function declaration errors
                        'function')
                            if [ "$last_non_ws_token" != "" ] && [ "$last_non_ws_token" != ";" ] && \
                               [ "$last_non_ws_token" != "{" ] && [ "$last_non_ws_token" != "}" ] && \
                               [ "$last_non_ws_token" != "(" ] && [ "$last_non_ws_token" != ")" ] && \
                               [ "$last_non_ws_token" != "," ] && [ "$last_non_ws_token" != ":" ] && \
                               [ "$last_non_ws_token" != "export" ] && [ "$last_non_ws_token" != "async" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected 'function'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check if next token is identifier or (
                            local lookahead_col=$((col+1))
                            local next_token=$(peek_token "$line" $lookahead_col)
                            
                            if [ "$next_token" = "(" ] && [ "$last_non_ws_token" != "async" ]; then
                                # Anonymous function
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Function statement requires a name${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            in_declaration=true
                            declaration_type="function"
                            expecting_identifier=true
                            ;;
                            
                        # Class declaration errors
                        'class')
                            if [ "$last_non_ws_token" != "" ] && [ "$last_non_ws_token" != ";" ] && \
                               [ "$last_non_ws_token" != "{" ] && [ "$last_non_ws_token" != "}" ] && \
                               [ "$last_non_ws_token" != "(" ] && [ "$last_non_ws_token" != ")" ] && \
                               [ "$last_non_ws_token" != "," ] && [ "$last_non_ws_token" != ":" ] && \
                               [ "$last_non_ws_token" != "export" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected 'class'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            in_class=true
                            in_declaration=true
                            declaration_type="class"
                            expecting_identifier=true
                            ;;
                            
                        # Check for missing identifier after declaration
                        '=')
                            if $expecting_identifier && [ "$last_non_ws_token" = "$declaration_type" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing identifier in $declaration_type declaration${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # NEW: Check for invalid left-hand side in assignment
                            if ! $in_declaration && [ "$last_non_ws_token" != "" ]; then
                                # Check if last token is a valid LHS
                                if is_number "$last_non_ws_token" || is_string "$last_non_ws_token" || \
                                   [ "$last_non_ws_token" = ")" ] || [ "$last_non_ws_token" = "]" ] || \
                                   [ "$last_non_ws_token" = "++" ] || [ "$last_non_ws_token" = "--" ] || \
                                   [ "$last_non_ws_token" = "+" ] || [ "$last_non_ws_token" = "-" ] || \
                                   [ "$last_non_ws_token" = "*" ] || [ "$last_non_ws_token" = "/" ] || \
                                   [ "$last_non_ws_token" = "%" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid left-hand side in assignment${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            
                            if $in_declaration && [ "$declaration_type" = "const" ] && [ "$last_non_ws_token" != "=" ]; then
                                # Check if const has initializer
                                local found_equals=false
                                local lookahead_col=$col
                                while [ $lookahead_col -lt $line_length ]; do
                                    local next_tok=$(get_token "$line" $lookahead_col)
                                    if [ "$next_tok" = "=" ]; then
                                        found_equals=true
                                        break
                                    elif [ "$next_tok" = ";" ]; then
                                        break
                                    fi
                                    ((lookahead_col++))
                                done
                                
                                if ! $found_equals; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing initializer in const declaration${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            
                            expecting_expression=true
                            expecting_operator=false
                            in_assignment=true
                            ;;
                            
                        # Check for empty parentheses in control structures
                        '(')
                            if [ "$last_non_ws_token" = "if" ] || [ "$last_non_ws_token" = "while" ] || \
                               [ "$last_non_ws_token" = "for" ] || [ "$last_non_ws_token" = "switch" ] || \
                               [ "$last_non_ws_token" = "catch" ]; then
                                # Check if parentheses are empty
                                local lookahead_col=$((col+1))
                                local found_content=false
                                local depth=1
                                
                                while [ $lookahead_col -lt $line_length ]; do
                                    local next_char="${line:$lookahead_col:1}"
                                    if [ "$next_char" = '(' ]; then
                                        ((depth++))
                                    elif [ "$next_char" = ')' ]; then
                                        ((depth--))
                                        if [ $depth -eq 0 ]; then
                                            break
                                        fi
                                    elif ! is_whitespace "$next_char"; then
                                        found_content=true
                                    fi
                                    ((lookahead_col++))
                                done
                                
                                if ! $found_content && [ "$last_non_ws_token" != "catch" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Empty parentheses in ${last_non_ws_token} statement${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        # Check for invalid break/continue
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
                            
                        # Check for invalid return
                        'return')
                            if ! $in_function; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'return' outside function${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for invalid throw
                        'throw')
                            # Check if throw is followed by something
                            local lookahead_col=$((col+1))
                            local found_expression=false
                            
                            while [ $lookahead_col -lt $line_length ]; do
                                local next_tok=$(peek_token "$line" $lookahead_col)
                                if [ "$next_tok" = ";" ] || [ "$next_tok" = "" ]; then
                                    break
                                elif [ "$next_tok" != "" ] && ! is_whitespace "${line:$lookahead_col:1}"; then
                                    found_expression=true
                                    break
                                fi
                                ((lookahead_col++))
                            done
                            
                            if ! $found_expression; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'throw' without expression${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for try-catch-finally errors
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
                            expecting_semicolon=false
                            ;;
                            
                        'catch')
                            if ! $in_try_block && ! $in_catch_block; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'catch' without 'try'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check for catch parameter
                            local lookahead_col=$((col+1))
                            local found_param=false
                            
                            while [ $lookahead_col -lt $line_length ]; do
                                local next_tok=$(peek_token "$line" $lookahead_col)
                                if [ "$next_tok" = "(" ]; then
                                    # Check if there's something between parentheses
                                    local param_lookahead=$((lookahead_col+1))
                                    while [ $param_lookahead -lt $line_length ]; do
                                        local param_char="${line:$param_lookahead:1}"
                                        if [ "$param_char" = ")" ]; then
                                            break
                                        elif ! is_whitespace "$param_char" && [ "$param_char" != "" ]; then
                                            found_param=true
                                            break
                                        fi
                                        ((param_lookahead++))
                                    done
                                    break
                                elif [ "$next_tok" = "{" ]; then
                                    # No parameter (valid in modern JS)
                                    found_param=true
                                    break
                                fi
                                ((lookahead_col++))
                            done
                            
                            if ! $found_param; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'catch' without parameter${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            in_catch_block=true
                            in_try_block=false
                            ;;
                            
                        'finally')
                            if ! $in_try_block && ! $in_catch_block; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'finally' without 'try'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            if $in_finally_block; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Multiple 'finally' blocks${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            in_finally_block=true
                            in_try_block=false
                            in_catch_block=false
                            ;;
                            
                        # Check for import/export errors
                        'import'|'export')
                            in_import_export=true
                            import_export_type="$token"
                            import_has_from=false
                            import_has_specifier=false
                            export_has_value=false
                            
                            if [ "$token" = "export" ]; then
                                # NEW: Check for export with literal value
                                local lookahead_col=$((col+1))
                                while [ $lookahead_col -lt $line_length ]; do
                                    local next_tok=$(peek_token "$line" $lookahead_col)
                                    if [ "$next_tok" = ";" ]; then
                                        # Export without value
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Export declaration requires a value${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    elif [ "$next_tok" != "" ] && ! is_whitespace "${line:$lookahead_col:1}"; then
                                        break
                                    fi
                                    ((lookahead_col++))
                                done
                            fi
                            ;;
                            
                        'from')
                            if $in_import_export && [ "$import_export_type" = "import" ]; then
                                import_has_from=true
                                # Check if from is properly used
                                local lookahead_col=$((col+1))
                                local found_string=false
                                
                                while [ $lookahead_col -lt $line_length ]; do
                                    local next_tok=$(get_token "$line" $lookahead_col)
                                    if [ "${next_tok:0:1}" = "'" ] || [ "${next_tok:0:1}" = '"' ]; then
                                        found_string=true
                                        import_has_specifier=true
                                        break
                                    elif [ "$next_tok" = ";" ]; then
                                        break
                                    fi
                                    ((lookahead_col++))
                                done
                                
                                if ! $found_string; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'from' without module specifier${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        # Check for arrow function errors
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
                            
                        # Check for invalid rest/spread
                        '...')
                            # Check if rest parameter is last
                            if $in_destructuring && [ "$destructuring_type" = "array" ] && \
                               [ "$last_non_ws_token" != "[" ] && [ "$last_non_ws_token" != "," ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Rest element must be last element${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for duplicate case labels
                        'case')
                            if $in_switch; then
                                # Simple duplicate check (would need more complex tracking for full accuracy)
                                # Check for case expression
                                local lookahead_col=$((col+1))
                                local found_colon=false
                                
                                while [ $lookahead_col -lt $line_length ]; do
                                    local next_tok=$(peek_token "$line" $lookahead_col)
                                    if [ "$next_tok" = ":" ]; then
                                        found_colon=true
                                        break
                                    elif [ "$next_tok" = ";" ] || [ "$next_tok" = "{" ]; then
                                        break
                                    fi
                                    ((lookahead_col++))
                                done
                                
                                if ! $found_colon; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing colon after 'case'${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        # Check for super errors
                        'super')
                            if $in_class && [ "$last_non_ws_token" = "constructor" ]; then
                                # Check if super is called in derived class
                                local lookahead_col=$((col+1))
                                local found_call=false
                                
                                while [ $lookahead_col -lt $line_length ]; do
                                    local next_tok=$(peek_token "$line" $lookahead_col)
                                    if [ "$next_tok" = "(" ]; then
                                        found_call=true
                                        break
                                    elif [ "$next_tok" = ";" ] || [ "$next_tok" = "{" ]; then
                                        break
                                    fi
                                    ((lookahead_col++))
                                done
                                
                                if ! $found_call && $extends_class; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Must call super constructor in derived class${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        # Check for extends
                        'extends')
                            if $in_class && [ "$last_non_ws_token" = "$class_name" ]; then
                                extends_class=true
                                expecting_expression=true
                            else
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected 'extends'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Check for invalid semicolon placements
                        ';')
                            # Check for empty declaration
                            if $in_declaration && [ "$last_non_ws_token" = "$declaration_type" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing identifier in $declaration_type declaration${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # NEW: Check for const without initializer (Test 2)
                            if $in_declaration && [ "$declaration_type" = "const" ] && \
                               [[ "$last_non_ws_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing initializer in const declaration${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # NEW: Check for import missing 'from' (Test 28)
                            if $in_import_export && [ "$import_export_type" = "import" ] && ! $import_has_from; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Import declaration requires 'from' clause${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # NEW: Check for export without value (Test 30)
                            if $in_import_export && [ "$import_export_type" = "export" ] && ! $export_has_value; then
                                # Check what was exported
                                local lookback_col=$((col-token_length))
                                local export_token=""
                                while [ $lookback_col -ge 0 ]; do
                                    local prev_tok=$(get_token "$line" $lookback_col)
                                    if [ "$prev_tok" = "export" ]; then
                                        # Check next token after export
                                        local after_export_col=$((lookback_col+${#prev_tok}))
                                        local after_export=$(peek_token "$line" $after_export_col)
                                        if is_number "$after_export" || is_string "$after_export"; then
                                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Cannot export literal value${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                            echo "$(realpath "$filename")"
                                            return 1
                                        fi
                                        break
                                    fi
                                    ((lookback_col--))
                                done
                            fi
                            
                            # Reset declaration state
                            in_declaration=false
                            declaration_type=""
                            expecting_identifier=false
                            
                            # Reset import/export state
                            in_import_export=false
                            import_export_type=""
                            import_has_from=false
                            import_has_specifier=false
                            export_has_value=false
                            in_assignment=false
                            ;;
                            
                        # Check for invalid commas
                        ',')
                            # Check for empty parameter in function
                            if $in_function && [ "$paren_count" -gt 0 ] && [ "$last_non_ws_token" = "(" ] || [ "$last_non_ws_token" = "," ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected comma in parameter list${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check for empty array element
                            if $in_array_literal && [ "$last_non_ws_token" = "[" ] || [ "$last_non_ws_token" = "," ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected comma in array literal${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # NEW: Check for missing value in object destructuring after colon (Test 38)
                            if $after_colon_in_object; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing value in object destructuring${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            after_colon_in_object=false
                            ;;
                            
                        # Handle colon in object literals
                        ':')
                            if $in_object_literal || $in_destructuring; then
                                # Mark that we expect a value after colon
                                after_colon_in_object=true
                                destructuring_has_value=false
                            fi
                            ;;
                            
                        # Handle identifiers
                        *)
                            # Check for identifier after declaration
                            if $expecting_identifier && [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                expecting_identifier=false
                                
                                # Track variable declarations for duplicate checking
                                if [ "$declaration_type" = "let" ] || [ "$declaration_type" = "const" ] || [ "$declaration_type" = "var" ]; then
                                    # Simple duplicate check (in reality would need scope tracking)
                                    for var in "${declared_variables[@]}"; do
                                        if [ "$var" = "$token" ]; then
                                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Identifier '$token' has already been declared${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                            echo "$(realpath "$filename")"
                                            return 1
                                        fi
                                    done
                                    declared_variables+=("$token")
                                elif [ "$declaration_type" = "function" ]; then
                                    function_name="$token"
                                    in_function=true
                                elif [ "$declaration_type" = "class" ]; then
                                    class_name="$token"
                                fi
                            fi
                            
                            # NEW: Check for export let without identifier (Test 31)
                            if $in_import_export && [ "$import_export_type" = "export" ] && \
                               [ "$last_non_ws_token" = "let" ] && [ "$token" = ";" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing identifier in export declaration${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # NEW: Mark that we have a value after colon in object destructuring
                            if $after_colon_in_object && [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] || is_number "$token" || is_string "$token"; then
                                after_colon_in_object=false
                                destructuring_has_value=true
                            fi
                            
                            # Check for duplicate parameter names (simplified)
                            if $in_function && [ "$paren_count" -gt 0 ] && [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                # This would need more complex tracking
                                :
                            fi
                            ;;
                    esac
                    
                    # Update last non-whitespace token
                    if [ "$token" != "" ]; then
                        last_non_ws_token="$token"
                    fi
                    
                    # Update context based on tokens
                    case "$token" in
                        '{')
                            ((brace_count++))
                            if [ "$last_non_ws_token" = "function" ] || \
                               [ "$last_non_ws_token" = "=>" ] || \
                               [ "$last_non_ws_token" = "class" ] || \
                               [[ "$last_non_ws_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && \
                               [ "$last_non_ws_token" != "if" ] && [ "$last_non_ws_token" != "while" ] && \
                               [ "$last_non_ws_token" != "for" ] && [ "$last_non_ws_token" != "switch" ] && \
                               [ "$last_non_ws_token" != "try" ] && [ "$last_non_ws_token" != "catch" ] && \
                               [ "$last_non_ws_token" != "finally" ]; then
                                if [ "$last_non_ws_token" = "class" ]; then
                                    in_class=true
                                else
                                    in_function=true
                                fi
                            elif [ "$last_non_ws_token" = "try" ]; then
                                in_try_block=false
                            elif $in_try_block; then
                                in_try_block=false
                            elif [ "$last_non_ws_token" = "else" ] || [ "$last_non_ws_token" = "do" ]; then
                                # Valid block starters
                                :
                            elif [ "$last_non_ws_token" = "catch" ] || [ "$last_non_ws_token" = "finally" ]; then
                                in_catch_block=false
                                in_finally_block=false
                            elif [ "$brace_count" -eq 1 ] && [ "$last_non_ws_token" != "=" ] && \
                                 [ "$last_non_ws_token" != ":" ] && [ "$last_non_ws_token" != "=>" ]; then
                                in_object_literal=true
                            fi
                            ;;
                            
                        '}')
                            ((brace_count--))
                            # NEW: Check for missing value in object destructuring before closing brace (Test 38)
                            if $after_colon_in_object; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing value in object destructuring${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            after_colon_in_object=false
                            
                            if [ $brace_count -eq 0 ]; then
                                # Reset contexts when exiting blocks
                                if $in_function; then
                                    in_function=false
                                    function_name=""
                                fi
                                if $in_class; then
                                    in_class=false
                                    class_name=""
                                    extends_class=false
                                fi
                                if $in_loop; then
                                    in_loop=false
                                    loop_type=""
                                fi
                                if $in_switch; then
                                    in_switch=false
                                fi
                                in_object_literal=false
                            fi
                            ;;
                            
                        '[')
                            ((bracket_count++))
                            if [ $bracket_count -eq 1 ] && [ "$last_non_ws_token" != "." ] && \
                               [ "$last_non_ws_token" != "?." ] && [ "${last_non_ws_token: -1}" != "?" ]; then
                                in_array_literal=true
                            fi
                            ;;
                            
                        ']')
                            ((bracket_count--))
                            if [ $bracket_count -eq 0 ]; then
                                in_array_literal=false
                            fi
                            ;;
                            
                        '(')
                            ((paren_count++))
                            # Check for destructuring pattern
                            if [ "$last_non_ws_token" = "function" ] || [ "$last_non_ws_token" = "$function_name" ]; then
                                in_destructuring=true
                                destructuring_type="params"
                            fi
                            ;;
                            
                        ')')
                            ((paren_count--))
                            if [ $paren_count -eq 0 ]; then
                                in_destructuring=false
                                destructuring_type=""
                            fi
                            ;;
                            
                        'while'|'for'|'do')
                            in_loop=true
                            loop_type="$token"
                            ;;
                            
                        'switch')
                            in_switch=true
                            ;;
                            
                        'async')
                            if [ "$last_non_ws_token" = "" ] || [ "$last_non_ws_token" = ";" ] || \
                               [ "$last_non_ws_token" = "{" ] || [ "$last_non_ws_token" = "}" ] || \
                               [ "$last_non_ws_token" = "(" ] || [ "$last_non_ws_token" = ")" ] || \
                               [ "$last_non_ws_token" = ":" ] || [ "$last_non_ws_token" = "," ] || \
                               [ "$last_non_ws_token" = "export" ]; then
                                in_async_context=true
                            fi
                            ;;
                            
                        '=')
                            # Check for destructuring
                            if [ "$last_non_ws_token" = "]" ] || [ "$last_non_ws_token" = "}" ]; then
                                in_destructuring=true
                                if [ "$last_non_ws_token" = "]" ]; then
                                    destructuring_type="array"
                                else
                                    destructuring_type="object"
                                fi
                            fi
                            ;;
                    esac
                    
                    # Reset expecting flags based on token
                    case "$token" in
                        '='|'+='|'-='|'*='|'/='|'%='|'&='|'|='|'^='|'<<='|'>>='|'>>>='|'**='|'&&='|'||='|'??=')
                            expecting_expression=true
                            expecting_operator=false
                            ;;
                        '+'|'-'|'*'|'/'|'%'|'&'|'|'|'^'|'!'|'~'|'<<'|'>>'|'>>>'|'**'|'&&'|'||'|'??'|'?.')
                            expecting_expression=true
                            expecting_operator=false
                            ;;
                        ';')
                            expecting_expression=false
                            expecting_operator=false
                            expecting_identifier=false
                            expecting_colon=false
                            expecting_comma=false
                            expecting_semicolon=false
                            expecting_equals=false
                            ;;
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
    
    # Check for incomplete try block
    if $in_try_block; then
        echo -e "${RED}Error: 'try' block without catch or finally${NC}"
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
    if check_statement_errors "$filename"; then
        echo -e "${GREEN}✓ No statement structure errors found${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running JavaScript Statement Structure Error Test Suite${NC}"
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
