#!/bin/bash

# JavaScript Function Declaration Syntax Error Scanner
# Pure Bash Implementation
# Usage: ./function.sh <filename.js> [--test]

SCANNER_VERSION="1.0.0"
TEST_DIR="function_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Reserved JavaScript keywords that cannot be function names
RESERVED_WORDS="break case catch class const continue debugger default delete do else enum export extends false finally for function if import in instanceof new null return super switch this throw true try typeof var void while with yield let static implements interface package private protected public as async await get set from of"

# Function to display usage
show_usage() {
    echo -e "${BLUE}JavaScript Function Declaration Syntax Error Scanner v${SCANNER_VERSION}${NC}"
    echo "Pure bash implementation - No Node.js required"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Scan a specific JavaScript file for function declaration errors"
    echo "  --test           Run test suite against known function error patterns"
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

# Function to check if character is valid for identifier (not first char)
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
                        '=>'|'*='|'/=')
                            token="${char}${next_char}"
                            ((pos++))
                            ;;
                    esac
                fi
                ;;
            # Strings and template literals
            "'"|'"'|'`')
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
                if is_valid_id_start "$char"; then
                    while [ $pos -lt $length ] && (is_valid_id_char "${line:$pos:1}" || [ "${line:$pos:1}" = "$" ]); do
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

# Function to check for function declaration errors
check_function_syntax() {
    local filename="$1"
    local line_number=0
    local in_comment_single=false
    local in_comment_multi=false
    local in_string_single=false
    local in_string_double=false
    local in_template=false
    local in_regex=false
    
    # Function-specific tracking
    local in_function_declaration=false
    local function_name=""
    local expecting_function_name=false
    local expecting_params=false
    local expecting_brace=false
    local paren_depth=0
    local brace_depth=0
    local bracket_depth=0
    local param_count=0
    local last_token=""
    local last_non_ws_token=""
    local in_async_context=false
    local in_generator_context=false
    local in_class_context=false
    local in_object_context=false
    local in_method_context=false
    local in_getter_setter=false
    local has_rest_param=false
    local in_default_param=false
    local in_destructuring_param=false
    local in_arrow_function=false
    local function_start_line=0
    local function_start_col=0
    local in_constructor=false
    
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
                        # Simplified regex detection
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
                    
                    # Check for function-related tokens
                    case "$token" in
                        # Function declaration start
                        'function')
                            # Check if function is in valid position
                            if $in_class_context && [ "$last_non_ws_token" != "" ] && [ "$last_non_ws_token" != ";" ] && \
                               [ "$last_non_ws_token" != "{" ] && [ "$last_non_ws_token" != "}" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected 'function' in class${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            if $in_object_context && [ "$last_non_ws_token" = "{" ] || [ "$last_non_ws_token" = "," ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected 'function' in object literal${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check for async function* (invalid)
                            if $in_async_context && $in_generator_context; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Cannot combine async and generator in declaration${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            in_function_declaration=true
                            expecting_function_name=true
                            expecting_params=false
                            expecting_brace=false
                            function_start_line=$line_number
                            function_start_col=$((col-token_length+2))
                            in_arrow_function=false
                            ;;
                            
                        # Async keyword
                        'async')
                            if ! $in_function_declaration && [ "$last_non_ws_token" != "function" ] && \
                               [ "$last_non_ws_token" != "=" ] && [ "$last_non_ws_token" != ":" ] && \
                               [ "$last_non_ws_token" != "," ] && [ "$last_non_ws_token" != "(" ] && \
                               [ "$last_non_ws_token" != "{" ] && [ "$last_non_ws_token" != ";" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected 'async'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            in_async_context=true
                            ;;
                            
                        # Generator asterisk
                        '*')
                            if $in_function_declaration && [ "$last_non_ws_token" = "function" ]; then
                                in_generator_context=true
                            elif [ "$last_non_ws_token" = "async" ] || [ "$last_non_ws_token" = "function" ]; then
                                in_generator_context=true
                            elif [ "$last_non_ws_token" = "yield" ]; then
                                # yield* is valid
                                :
                            elif $expecting_function_name && ! $in_generator_context; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid asterisk position${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Function name validation
                        *)
                            if $expecting_function_name && ! $in_arrow_function; then
                                # Check for missing function name
                                if [ "$token" = "(" ]; then
                                    echo -e "${RED}Error at line $function_start_line, column $function_start_col: Missing function name${NC}"
                                    echo "  Function declaration requires a name"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                
                                # Check for invalid function names
                                if [[ "$token" =~ ^[0-9] ]]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Function name cannot start with number${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                
                                if [[ "$token" =~ [-@.#] ]]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Invalid character in function name${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                
                                if is_reserved_word "$token"; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Reserved word cannot be used as function name${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                
                                # Valid function name found
                                function_name="$token"
                                expecting_function_name=false
                                expecting_params=true
                            fi
                            ;;
                            
                        # Parentheses handling for parameters
                        '(')
                            ((paren_depth++))
                            
                            if $expecting_params && $in_function_declaration; then
                                expecting_params=false
                                in_default_param=false
                                in_destructuring_param=false
                                param_count=0
                                has_rest_param=false
                            fi
                            ;;
                            
                        ')')
                            ((paren_depth--))
                            
                            if $in_function_declaration && [ $paren_depth -eq 0 ]; then
                                expecting_brace=true
                                
                                # Check for incomplete rest parameter
                                if [ "$last_non_ws_token" = "..." ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Incomplete rest parameter${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                
                                # Check for trailing comma in parameters (not allowed in non-arrow functions)
                                if [ "$last_non_ws_token" = "," ] && ! $in_arrow_function; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Trailing comma in function parameters${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                            
                        # Parameter list errors
                        ',')
                            if $in_function_declaration && [ $paren_depth -eq 1 ]; then
                                # Check for double commas
                                if [ "$last_non_ws_token" = "," ] || [ "$last_non_ws_token" = "(" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected comma in parameter list${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                
                                # Check for rest parameter not last
                                if $has_rest_param; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Rest parameter must be last${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                
                                ((param_count++))
                                in_default_param=false
                                in_destructuring_param=false
                            fi
                            ;;
                            
                        # Rest parameter
                        '...')
                            if $in_function_declaration && [ $paren_depth -eq 1 ]; then
                                if $has_rest_param; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Multiple rest parameters not allowed${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                has_rest_param=true
                            fi
                            ;;
                            
                        # Default parameter errors
                        '=')
                            if $in_function_declaration && [ $paren_depth -eq 1 ]; then
                                if $has_rest_param; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Rest parameter cannot have default value${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                in_default_param=true
                            fi
                            ;;
                            
                        # Arrow function
                        '=>')
                            if $in_function_declaration; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Arrow function syntax not allowed in declaration${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            in_arrow_function=true
                            ;;
                            
                        # Function body braces
                        '{')
                            ((brace_depth++))
                            
                            if $expecting_brace && $in_function_declaration; then
                                expecting_brace=false
                                # Function body started
                            elif $in_function_declaration && ! $expecting_brace; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Missing parentheses before function body${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check for class/object context
                            if [ "$last_non_ws_token" = "class" ]; then
                                in_class_context=true
                            elif [ "$last_non_ws_token" = "{" ] || [ "$last_non_ws_token" = "," ] || [ "$last_non_ws_token" = ":" ]; then
                                in_object_context=true
                            fi
                            ;;
                            
                        '}')
                            ((brace_depth--))
                            
                            if $in_function_declaration && [ $brace_depth -eq 0 ]; then
                                in_function_declaration=false
                                in_async_context=false
                                in_generator_context=false
                                function_name=""
                            fi
                            
                            if $in_class_context && [ $brace_depth -eq 0 ]; then
                                in_class_context=false
                            fi
                            
                            if $in_object_context && [ $brace_depth -eq 0 ]; then
                                in_object_context=false
                            fi
                            ;;
                            
                        # Semicolon in wrong place
                        ';')
                            if $expecting_function_name || $expecting_params || $expecting_brace; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected semicolon in function declaration${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check for function declaration without body
                            if $in_function_declaration && [ $brace_depth -eq 0 ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Function declaration without body${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        # Class keyword
                        'class')
                            in_class_context=true
                            ;;
                            
                        # Constructor in class
                        'constructor')
                            if $in_class_context && [ $brace_depth -eq 1 ]; then
                                in_constructor=true
                                in_function_declaration=true
                                expecting_params=true
                            fi
                            ;;
                            
                        # Getter/Setter
                        'get'|'set')
                            if $in_object_context || $in_class_context; then
                                in_getter_setter=true
                                in_function_declaration=true
                                expecting_function_name=true
                            fi
                            ;;
                    esac
                    
                    # Check for yield outside generator
                    if [ "$token" = "yield" ] && $in_function_declaration && ! $in_generator_context; then
                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'yield' outside generator function${NC}"
                        echo "  $line"
                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                        echo "$(realpath "$filename")"
                        return 1
                    fi
                    
                    # Check for await outside async
                    if [ "$token" = "await" ] && $in_function_declaration && ! $in_async_context; then
                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'await' outside async function${NC}"
                        echo "  $line"
                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                        echo "$(realpath "$filename")"
                        return 1
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
        
    done < "$filename"
    
    # Check for unterminated function declaration
    if $in_function_declaration; then
        if $expecting_brace; then
            echo -e "${RED}Error: Function '$function_name' missing body${NC}"
            echo "$(realpath "$filename")"
            return 1
        elif $expecting_params; then
            echo -e "${RED}Error: Function '$function_name' missing parentheses${NC}"
            echo "$(realpath "$filename")"
            return 1
        elif $expecting_function_name; then
            echo -e "${RED}Error: Unterminated function declaration${NC}"
            echo "$(realpath "$filename")"
            return 1
        elif [ $brace_depth -gt 0 ]; then
            echo -e "${RED}Error: Function '$function_name' missing closing brace${NC}"
            echo "$(realpath "$filename")"
            return 1
        fi
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
    if [ $brace_depth -gt 0 ]; then
        echo -e "${RED}Error: Unclosed { (missing } )${NC}"
        echo "$(realpath "$filename")"
        return 1
    elif [ $brace_depth -lt 0 ]; then
        echo -e "${RED}Error: Unexpected } (extra closing brace)${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    if [ $bracket_depth -gt 0 ]; then
        echo -e "${RED}Error: Unclosed [ (missing ] )${NC}"
        echo "$(realpath "$filename")"
        return 1
    elif [ $bracket_depth -lt 0 ]; then
        echo -e "${RED}Error: Unexpected ] (extra closing bracket)${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    if [ $paren_depth -gt 0 ]; then
        echo -e "${RED}Error: Unclosed ( (missing ) )${NC}"
        echo "$(realpath "$filename")"
        return 1
    elif [ $paren_depth -lt 0 ]; then
        echo -e "${RED}Error: Unexpected ) (extra closing parenthesis)${NC}"
        echo "$(realpath "$filename")"
        return 1
    fi
    
    return 0
}

# Function to scan a single JavaScript file
scan_js_file() {
    local filename="$1"
    
    if [ ! -f "$filename" ]; then
        echo -e "${RED}Error: File '$filename' not found${NC}"
        return 1
    fi
    
    if [[ ! "$filename" =~ \.js$ ]]; then
        echo -e "${YELLOW}Warning: File '$filename' doesn't have .js extension${NC}"
    fi
    
    echo -e "${CYAN}Scanning:${NC} ${filename}"
    echo "========================================"
    
    # Check file size
    local file_size=$(wc -c < "$filename")
    if [ $file_size -eq 0 ]; then
        echo -e "${GREEN}✓ Empty file - no function errors${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    fi
    
    # Run our function syntax checker
    if check_function_syntax "$filename"; then
        echo -e "${GREEN}✓ No function declaration errors found${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running JavaScript Function Declaration Error Test Suite${NC}"
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
        
        # Run scan on test file
        if scan_js_file "$test_file" 2>/dev/null; then
            echo -e "${RED}  ✗ Expected to fail but passed${NC}"
            ((failed_tests++))
        else
            echo -e "${GREEN}  ✓ Correctly detected function error${NC}"
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
    
    # Scan single file
    scan_js_file "$1"
    exit $?
}

# Run main function
main "$@"
