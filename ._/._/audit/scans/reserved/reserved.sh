#!/bin/bash

# JavaScript Reserved Word Usage Auditor - Pure Bash Implementation
# Usage: ./reserved.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="1.0.0"
TEST_DIR="reserved_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Complete list of JavaScript reserved words
RESERVED_WORDS="break case catch class const continue debugger default delete do else enum export extends false finally for function if import in instanceof new null return super switch this throw true try typeof var void while with yield let static implements interface package private protected public as async await get set from of target meta"
STRICT_RESERVED="implements interface let package private protected public static yield"
CONTEXTUAL_RESERVED="await get set"
ES3_FUTURE_RESERVED="abstract boolean byte char double final float goto int long native short synchronized throws transient volatile"
ES5_FUTURE_RESERVED="class enum extends super const export import"

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
    for word in $RESERVED_WORDS $STRICT_RESERVED $CONTEXTUAL_RESERVED $ES3_FUTURE_RESERVED $ES5_FUTURE_RESERVED; do
        if [ "$token" = "$word" ]; then
            return 0
        fi
    done
    return 1
}

# Function to check if token is a strict mode reserved word
is_strict_reserved() {
    local token="$1"
    for word in $STRICT_RESERVED; do
        if [ "$token" = "$word" ]; then
            return 0
        fi
    done
    return 1
}

# Function to check if token is a contextual reserved word
is_contextual_reserved() {
    local token="$1"
    for word in $CONTEXTUAL_RESERVED; do
        if [ "$token" = "$word" ]; then
            return 0
        fi
    done
    return 1
}

# Function to check if token is a future reserved word
is_future_reserved() {
    local token="$1"
    for word in $ES3_FUTURE_RESERVED $ES5_FUTURE_RESERVED; do
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

# Function to check for reserved word usage errors
check_reserved_word_usage() {
    local filename="$1"
    local line_number=0
    local in_comment_single=false
    local in_comment_multi=false
    local in_string_single=false
    local in_string_double=false
    local in_template=false
    local in_regex=false
    local strict_mode=false
    local in_function=false
    local in_async_function=false
    local in_generator=false
    local in_class=false
    local in_import_export=false
    local in_object_property=false
    local in_computed_property=false
    local last_token=""
    local last_non_ws_token=""
    local last_non_ws_token2=""  # Two tokens back
    
    # Read file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_number++))
        local col=0
        local line_length=${#line}
        
        # Check for strict mode directive (simplified check)
        if [[ "$line" =~ [[:space:]]*\"use[[:space:]]+strict\"[[:space:]]*\; ]] || 
           [[ "$line" =~ [[:space:]]*\'use[[:space:]]+strict\'[[:space:]]*\; ]] ||
           [[ "$line" =~ [[:space:]]*\"use[[:space:]]+strict\" ]] || 
           [[ "$line" =~ [[:space:]]*\'use[[:space:]]+strict\' ]]; then
            strict_mode=true
        fi
        
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
                    fi
                fi
            fi
            
            # Inside multi-line comment
            if $in_comment_multi && [ "$char" = '*' ] && [ "$next_char" = '/' ]; then
                in_comment_multi=false
                ((col++))
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
                    
                    # Update last two tokens
                    if [ "$last_non_ws_token" != "" ]; then
                        last_non_ws_token2="$last_non_ws_token"
                    fi
                    
                    # Track context based on tokens
                    case "$token" in
                        'function')
                            in_function=true
                            in_object_property=false
                            ;;
                        'async')
                            if [ "$last_non_ws_token" = "" ] || [ "$last_non_ws_token" = ";" ] || \
                               [ "$last_non_ws_token" = "{" ] || [ "$last_non_ws_token" = "}" ] || \
                               [ "$last_non_ws_token" = "(" ] || [ "$last_non_ws_token" = ")" ] || \
                               [ "$last_non_ws_token" = ":" ] || [ "$last_non_ws_token" = "," ]; then
                                # async function declaration
                                in_async_function=true
                            fi
                            ;;
                        '*')
                            if [ "$last_non_ws_token" = "function" ] || [ "$last_non_ws_token" = "async" ]; then
                                in_generator=true
                            fi
                            ;;
                        'class')
                            in_class=true
                            ;;
                        'import'|'export')
                            in_import_export=true
                            ;;
                        '{')
                            if [ "$last_non_ws_token" = "class" ] || [ "$last_non_ws_token" = "interface" ]; then
                                in_class=true
                            elif [[ "$last_non_ws_token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && [ "$last_non_ws_token" != "if" ] && \
                                 [ "$last_non_ws_token" != "while" ] && [ "$last_non_ws_token" != "for" ] && \
                                 [ "$last_non_ws_token" != "switch" ] && [ "$last_non_ws_token" != "try" ] && \
                                 [ "$last_non_ws_token" != "catch" ] && [ "$last_non_ws_token" != "finally" ]; then
                                # Could be object literal or function body
                                if [ "$last_non_ws_token2" != "function" ] && [ "$last_non_ws_token2" != "async" ] && \
                                   [ "$last_non_ws_token2" != "=>" ]; then
                                    in_object_property=true
                                fi
                            fi
                            in_computed_property=false
                            ;;
                        '[')
                            if $in_object_property && [ "$last_non_ws_token" != "{" ]; then
                                in_computed_property=true
                            fi
                            ;;
                        ']')
                            in_computed_property=false
                            ;;
                        '}')
                            if $in_class; then
                                in_class=false
                            fi
                            if $in_object_property; then
                                in_object_property=false
                            fi
                            in_computed_property=false
                            ;;
                        '('|')')
                            # Reset import/export context after parentheses
                            if [ "$last_non_ws_token" = "import" ] || [ "$last_non_ws_token" = "export" ]; then
                                in_import_export=false
                            fi
                            ;;
                        ';')
                            in_import_export=false
                            in_object_property=false
                            in_computed_property=false
                            ;;
                        'as')
                            if $in_import_export; then
                                # After 'as' in import/export, next token should be identifier
                                # Reserved words are allowed here (they get renamed)
                                :
                            fi
                            ;;
                    esac
                    
                    # Check for reserved word usage errors
                    if is_reserved_word "$token"; then
                        # Check specific reserved word contexts
                        case "$token" in
                            # Strict mode reserved words
                            'implements'|'interface'|'package'|'private'|'protected'|'public'|'static')
                                if $strict_mode && [ "$last_non_ws_token" = "const" ] || \
                                   [ "$last_non_ws_token" = "let" ] || [ "$last_non_ws_token" = "var" ] || \
                                   [ "$last_non_ws_token" = "class" ] || [ "$last_non_ws_token" = "function" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): '$token' is reserved in strict mode${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                ;;
                                
                            # Contextual reserved words
                            'await')
                                if [ "$last_non_ws_token" = "const" ] || [ "$last_non_ws_token" = "let" ] || \
                                   [ "$last_non_ws_token" = "var" ] || [ "$last_non_ws_token" = "function" ]; then
                                    if ! $in_async_function && ! $strict_mode; then
                                        # Check if we're at top-level of a module
                                        if ! $in_function && ! $in_class && [ "$last_non_ws_token" != "async" ]; then
                                            # Could be top-level await (ES2022+ in modules)
                                            # We'll be conservative and flag it
                                            echo -e "${YELLOW}Warning at line $line_number, column $((col-token_length+2)): 'await' used as identifier outside async context${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $((col-token_length+1)) "" "${YELLOW}here${NC}"
                                        fi
                                    elif ! $in_async_function; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'await' used as identifier outside async context${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                fi
                                ;;
                                
                            'yield')
                                if [ "$last_non_ws_token" = "const" ] || [ "$last_non_ws_token" = "let" ] || \
                                   [ "$last_non_ws_token" = "var" ] || [ "$last_non_ws_token" = "function" ]; then
                                    if ! $in_generator && $strict_mode; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'yield' used as identifier outside generator${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                fi
                                ;;
                                
                            # Future reserved words (ES3/ES5)
                            'abstract'|'boolean'|'byte'|'char'|'double'|'final'|'float'|'goto'|'int'|'long'|'native'|'short'|'synchronized'|'throws'|'transient'|'volatile')
                                if $strict_mode && [ "$last_non_ws_token" = "const" ] || \
                                   [ "$last_non_ws_token" = "let" ] || [ "$last_non_ws_token" = "var" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): '$token' is reserved in strict mode${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                ;;
                                
                            # Regular reserved words as identifiers
                            'class'|'const'|'function'|'let'|'var'|'if'|'else'|'while'|'for'|'switch'|'case'|'default'|'break'|'continue'|'return'|'throw'|'try'|'catch'|'finally'|'do'|'in'|'of'|'instanceof'|'typeof'|'void'|'delete'|'new'|'this'|'super'|'with'|'debugger'|'export'|'import'|'as'|'from'|'get'|'set'|'static'|'extends'|'enum'|'null'|'true'|'false'|'async'|'await'|'yield')
                                # Check if reserved word is being used as an identifier
                                if [ "$last_non_ws_token" = "const" ] || [ "$last_non_ws_token" = "let" ] || \
                                   [ "$last_non_ws_token" = "var" ] || [ "$last_non_ws_token" = "class" ] || \
                                   [ "$last_non_ws_token" = "function" ] || [ "$last_non_ws_token" = "async" ]; then
                                    # Exception: 'async' before 'function' is valid
                                    if [ "$token" = "async" ] && [ "$next_char" = " " ] && [[ "${line:$((col+1))}" =~ [[:space:]]*function ]]; then
                                        # Valid async function declaration
                                        :
                                    # Exception: In object properties, reserved words are allowed
                                    elif $in_object_property && ! $in_computed_property; then
                                        # Valid as object property name
                                        :
                                    # Exception: In class definitions as method names
                                    elif $in_class && [ "$last_non_ws_token" != "class" ]; then
                                        # Valid as class method name
                                        :
                                    # Exception: Function parameters
                                    elif [ "$last_non_ws_token" = "(" ] || [ "$last_non_ws_token" = "," ]; then
                                        # Function parameters can be reserved words (bad practice but valid)
                                        :
                                    # Exception: Import/export rename with 'as'
                                    elif $in_import_export && [ "$last_non_ws_token2" = "as" ]; then
                                        # Valid: import { x as class } from 'module'
                                        :
                                    else
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): '$token' is a reserved word and cannot be used as an identifier${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                # Check for class names that are reserved words
                                elif [ "$last_non_ws_token" = "class" ] && [ "$token" != "extends" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): '$token' cannot be used as a class name${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                # Check for computed property with reserved word
                                elif $in_computed_property && [ "$last_non_ws_token" = "[" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): '$token' cannot be used directly in computed property${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                ;;
                                
                            # Special case: 'default' in export
                            'default')
                                if $in_import_export && [ "$last_non_ws_token" = "export" ]; then
                                    # export default is valid
                                    :
                                elif [ "$last_non_ws_token" = "const" ] || [ "$last_non_ws_token" = "let" ] || \
                                     [ "$last_non_ws_token" = "var" ] || [ "$last_non_ws_token" = "class" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'default' is reserved and cannot be used as an identifier${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                ;;
                                
                            # Special case: 'arguments' and 'eval' in strict mode
                            'arguments'|'eval')
                                if $strict_mode && [ "$last_non_ws_token" = "const" ] || \
                                   [ "$last_non_ws_token" = "let" ] || [ "$last_non_ws_token" = "var" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): '$token' is reserved in strict mode${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                ;;
                        esac
                    fi
                    
                    # Update last non-whitespace token
                    if [ "$token" != "" ]; then
                        last_non_ws_token="$token"
                    fi
                    
                    # Special handling for import/export context
                    if [ "$token" = "import" ] || [ "$token" = "export" ]; then
                        in_import_export=true
                    elif [ "$token" = ";" ] || [ "$token" = "{" ] || [ "$token" = "}" ]; then
                        in_import_export=false
                    fi
                    
                    # Check for import/export with reserved words without rename
                    if $in_import_export && is_reserved_word "$token" && \
                       [ "$last_non_ws_token" = "{" ] || [ "$last_non_ws_token" = "," ]; then
                        # Look ahead for 'as' keyword
                        local lookahead_col=$((col+1))
                        local found_as=false
                        local found_identifier=false
                        
                        while [ $lookahead_col -lt $line_length ]; do
                            local next_tok=$(get_token "$line" $lookahead_col)
                            if [ "$next_tok" = "as" ]; then
                                found_as=true
                                break
                            elif [ "$next_tok" = "}" ] || [ "$next_tok" = "," ] || [ "$next_tok" = ";" ] || \
                                 [ "$next_tok" = "from" ]; then
                                break
                            elif [[ "$next_tok" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && [ "$next_tok" != "as" ]; then
                                found_identifier=true
                                break
                            fi
                            ((lookahead_col++))
                        done
                        
                        if ! $found_as && ! $found_identifier && [ "$token" != "default" ]; then
                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Reserved word '$token' in import/export must be renamed with 'as'${NC}"
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
        
    done < "$filename"
    
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
