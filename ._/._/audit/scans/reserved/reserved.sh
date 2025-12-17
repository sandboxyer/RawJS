#!/bin/bash

# JavaScript Reserved Word Usage Auditor - Pure Bash Implementation
# Usage: ./reserved.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="4.0.0"
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
STRICT_RESERVED="implements interface let package private protected public static yield eval arguments"
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

# Function to check if character is valid for variable name
is_valid_var_char() {
    local char="$1"
    case "$char" in
        [a-zA-Z0-9_$]) return 0 ;;
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
            "'"|'"')
                local quote_char="$char"
                token="$char"
                ((pos++))
                # Skip to end of string
                while [ $pos -lt $length ] && ! ([ "${line:$pos:1}" = "$quote_char" ] && [ "${line:$((pos-1)):1}" != "\\" ]); do
                    ((pos++))
                done
                if [ $pos -lt $length ]; then
                    ((pos++))
                fi
                ;;
            '`')
                token="$char"
                ((pos++))
                # Skip to end of template literal
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
            # Identifiers and numbers
            *)
                if is_valid_var_start "$char"; then
                    while [ $pos -lt $length ] && is_valid_var_char "${line:$pos:1}"; do
                        ((pos++))
                    done
                elif [[ "$char" =~ [0-9] ]]; then
                    while [ $pos -lt $length ] && ([[ "${line:$pos:1}" =~ [0-9] ]] || [ "${line:$pos:1}" = "." ] || [ "${line:$pos:1}" = "e" ] || [ "${line:$pos:1}" = "E" ] || [ "${line:$pos:1}" = "x" ] || [ "${line:$pos:1}" = "X" ] || [ "${line:$pos:1}" = "b" ] || [ "${line:$pos:1}" = "B" ] || [ "${line:$pos:1}" = "o" ] || [ "${line:$pos:1}" = "O" ]); do
                        ((pos++))
                    done
                fi
                ;;
        esac
        
        token="${line:$start:$((pos-start))}"
    fi
    
    echo "$token"
}

# Function to decode Unicode escape sequences
decode_unicode() {
    local line="$1"
    local decoded=""
    local i=0
    local len=${#line}
    
    while [ $i -lt $len ]; do
        local char="${line:$i:1}"
        if [ "$char" = '\' ] && [ $((i+1)) -lt $len ] && [ "${line:$((i+1)):1}" = 'u' ]; then
            # Try to decode Unicode escape
            if [ $((i+5)) -lt $len ]; then
                local hex="${line:$((i+2)):4}"
                if [[ "$hex" =~ ^[0-9a-fA-F]{4}$ ]]; then
                    # Convert hex to decimal and then to character
                    local dec=$((16#$hex))
                    if [ $dec -lt 128 ]; then
                        # ASCII character
                        char=$(printf \\$(printf '%03o' $dec))
                        i=$((i+5))
                    fi
                fi
            fi
        fi
        decoded="${decoded}${char}"
        ((i++))
    done
    
    echo "$decoded"
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
    local in_arrow_function=false
    local in_parameter_list=false
    local in_method=false
    local is_module=false
    local in_export_default=false
    local in_export_named=false
    local in_import_clause=false
    local import_has_brackets=false
    local export_has_brackets=false
    local last_token=""
    local last_non_ws_token=""
    local last_non_ws_token2=""
    local last_non_ws_token3=""
    local line_indent=""
    
    # Check if file might be a module by looking for import/export at beginning
    if head -n 5 "$filename" | grep -q -E "^\s*(import|export)"; then
        is_module=true
    fi
    
    # Read file line by line
    while IFS= read -r line_raw || [ -n "$line_raw" ]; do
        ((line_number++))
        
        # Decode Unicode escape sequences
        local line=$(decode_unicode "$line_raw")
        local col=0
        local line_length=${#line}
        
        # Track line indentation for error display
        line_indent=""
        while [ $col -lt $line_length ] && is_whitespace "${line:$col:1}"; do
            line_indent="$line_indent${line:$col:1}"
            ((col++))
        done
        col=0  # Reset column for token processing
        
        # Check for strict mode directive
        if [[ "$line" =~ ^[[:space:]]*(\"use[[:space:]]+strict\"|\'use[[:space:]]+strict\') ]]; then
            strict_mode=true
        fi
        
        # Check for module type
        if [[ "$line" =~ ^[[:space:]]*(import|export|import\(|\/\/.*import|\/\/.*export) ]]; then
            is_module=true
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
                    elif [ "$last_non_ws_token" = "=" ] || [ "$last_non_ws_token" = "(" ] || 
                         [ "$last_non_ws_token" = "," ] || [ "$last_non_ws_token" = ":" ] || 
                         [ "$last_non_ws_token" = "[" ] || [ "$last_non_ws_token" = "?" ] ||
                         [ "$last_non_ws_token" = "||" ] || [ "$last_non_ws_token" = "&&" ] ||
                         [ "$last_non_ws_token" = "??" ] || [ "$last_non_ws_token" = "+" ] ||
                         [ "$last_non_ws_token" = "-" ] || [ "$last_non_ws_token" = "*" ] ||
                         [ "$last_non_ws_token" = "%" ] || [ "$last_non_ws_token" = "**" ] ||
                         [ "$last_non_ws_token" = "!" ] || [ "$last_non_ws_token" = "~" ] ||
                         [ "$last_non_ws_token" = "typeof" ] || [ "$last_non_ws_token" = "void" ] ||
                         [ "$last_non_ws_token" = "delete" ] || [ "$last_non_ws_token" = "instanceof" ] ||
                         [ "$last_non_ws_token" = "in" ] || [ "$last_non_ws_token" = "return" ] ||
                         [ "$last_non_ws_token" = "yield" ] || [ "$last_non_ws_token" = "await" ] ||
                         [ "$last_non_ws_token" = "throw" ]; then
                        # Likely regex
                        in_regex=true
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
                    
                    # Update last three tokens
                    if [ "$last_non_ws_token" != "" ]; then
                        last_non_ws_token3="$last_non_ws_token2"
                        last_non_ws_token2="$last_non_ws_token"
                    fi
                    
                    # Track context based on tokens
                    case "$token" in
                        'function')
                            in_function=true
                            in_async_function=false
                            in_generator=false
                            in_parameter_list=false
                            in_object_property=false
                            if [ "$last_non_ws_token" = "async" ]; then
                                in_async_function=true
                            fi
                            ;;
                        'async')
                            # Check if async is used as identifier
                            if [ "$last_non_ws_token" = "const" ] || [ "$last_non_ws_token" = "let" ] || \
                               [ "$last_non_ws_token" = "var" ] || [ "$last_non_ws_token" = "class" ] || \
                               [ "$last_non_ws_token" = "function" ]; then
                                # async as identifier - this is invalid
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'async' is a reserved word and cannot be used as an identifier${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                        '*')
                            if [ "$last_non_ws_token" = "function" ] || [ "$last_non_ws_token" = "async" ]; then
                                in_generator=true
                            fi
                            ;;
                        '=>')
                            in_arrow_function=true
                            in_parameter_list=false
                            ;;
                        'class')
                            in_class=true
                            in_method=false
                            ;;
                        'import')
                            in_import_export=true
                            in_import_clause=true
                            is_module=true
                            import_has_brackets=false
                            ;;
                        'export')
                            in_import_export=true
                            in_export_named=true
                            is_module=true
                            export_has_brackets=false
                            ;;
                        'default')
                            if $in_import_export && [ "$last_non_ws_token" = "export" ]; then
                                in_export_default=true
                                in_export_named=false
                            elif $in_import_export && $import_has_brackets; then
                                # 'default' inside import {} is allowed
                                :
                            elif $in_import_export && $export_has_brackets; then
                                # 'default' inside export {} is allowed
                                :
                            elif [ "$last_non_ws_token" = "=" ] && [ "$last_non_ws_token2" = "export" ]; then
                                # export default = 5; - syntax error
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'export default' cannot be followed by '='${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                        '{')
                            if [ "$last_non_ws_token" = "class" ] || [ "$last_non_ws_token" = "interface" ]; then
                                in_class=true
                                in_method=true
                            elif $in_import_export && [ "$last_non_ws_token" = "import" ]; then
                                # Import clause
                                in_import_clause=true
                                import_has_brackets=true
                            elif $in_import_export && [ "$last_non_ws_token" = "export" ]; then
                                # Export clause
                                export_has_brackets=true
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
                            in_parameter_list=false
                            ;;
                        '[')
                            if $in_object_property && [ "$last_non_ws_token" != "{" ]; then
                                in_computed_property=true
                            fi
                            ;;
                        ']')
                            in_computed_property=false
                            ;;
                        '(')
                            in_parameter_list=true
                            if [ "$last_non_ws_token" = "function" ] || [ "$last_non_ws_token" = "async" ]; then
                                in_parameter_list=true
                            fi
                            if $in_import_export && [ "$last_non_ws_token" = "import" ]; then
                                # dynamic import()
                                in_import_export=false
                            fi
                            ;;
                        ')')
                            in_parameter_list=false
                            if $in_arrow_function; then
                                in_arrow_function=false
                            fi
                            ;;
                        '}')
                            if $in_class; then
                                in_class=false
                                in_method=false
                            fi
                            if $in_function; then
                                in_function=false
                                in_async_function=false
                                in_generator=false
                            fi
                            if $in_object_property; then
                                in_object_property=false
                            fi
                            if $import_has_brackets; then
                                import_has_brackets=false
                            fi
                            if $export_has_brackets; then
                                export_has_brackets=false
                            fi
                            in_computed_property=false
                            in_parameter_list=false
                            ;;
                        ';')
                            in_import_export=false
                            in_import_clause=false
                            in_export_default=false
                            in_export_named=false
                            in_object_property=false
                            in_computed_property=false
                            in_parameter_list=false
                            if $in_arrow_function; then
                                in_arrow_function=false
                            fi
                            ;;
                        'as')
                            if $in_import_export && $in_import_clause; then
                                # After 'as' in import/export, next token should be identifier
                                # Reserved words are allowed here (they get renamed)
                                :
                            fi
                            ;;
                        'from')
                            if $in_import_export; then
                                # Reset import/export after 'from'
                                in_import_export=false
                                in_import_clause=false
                                in_export_default=false
                                in_export_named=false
                                import_has_brackets=false
                                export_has_brackets=false
                            fi
                            ;;
                    esac
                    
                    # Check for reserved word usage errors
                    if is_reserved_word "$token"; then
                        # Check specific reserved word contexts
                        case "$token" in
                            # Strict mode reserved words
                            'implements'|'interface'|'package'|'private'|'protected'|'public'|'static'|'yield'|'eval'|'arguments')
                                if $strict_mode && ([ "$last_non_ws_token" = "const" ] || \
                                   [ "$last_non_ws_token" = "let" ] || [ "$last_non_ws_token" = "var" ] || \
                                   [ "$last_non_ws_token" = "class" ] || [ "$last_non_ws_token" = "function" ]); then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): '$token' is reserved in strict mode${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                elif $strict_mode && $in_parameter_list; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): '$token' cannot be used as a parameter in strict mode${NC}"
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
                                    # 'await' as identifier
                                    if ! $in_async_function && ! $in_class && ! $in_method; then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'await' cannot be used as an identifier${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                elif ! $in_async_function && ! $is_module; then
                                    # 'await' expression outside async context and not in module
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'await' expression outside async function${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                elif ! $in_async_function && $is_module && ! $in_function; then
                                    # Top-level await in module - allowed in ES2022+
                                    # We'll still flag it as it's a recent feature
                                    echo -e "${YELLOW}Warning at line $line_number, column $((col-token_length+2)): Top-level await in module (ES2022+)${NC}"
                                fi
                                ;;
                                
                            # Future reserved words (ES3/ES5)
                            'abstract'|'boolean'|'byte'|'char'|'double'|'final'|'float'|'goto'|'int'|'long'|'native'|'short'|'synchronized'|'throws'|'transient'|'volatile')
                                if $strict_mode && ([ "$last_non_ws_token" = "const" ] || \
                                   [ "$last_non_ws_token" = "let" ] || [ "$last_non_ws_token" = "var" ]); then
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
                                    elif $in_class && $in_method && [ "$last_non_ws_token" != "class" ] && [ "$last_non_ws_token" != "static" ]; then
                                        # Valid as class method name
                                        :
                                    # Exception: Function parameters (though bad practice)
                                    elif $in_parameter_list && ([ "$last_non_ws_token" = "(" ] || [ "$last_non_ws_token" = "," ]); then
                                        # Function parameters can be reserved words in non-strict mode
                                        if $strict_mode && [ "$token" != "async" ] && [ "$token" != "get" ] && [ "$token" != "set" ]; then
                                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): '$token' cannot be used as a parameter in strict mode${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                            echo "$(realpath "$filename")"
                                            return 1
                                        fi
                                    # Exception: Import/export rename with 'as'
                                    elif $in_import_export && $in_import_clause && [ "$last_non_ws_token2" = "as" ]; then
                                        # Valid: import { x as class } from 'module'
                                        :
                                    # Exception: 'var' declarations in non-strict mode allow some reserved words
                                    elif [ "$last_non_ws_token" = "var" ] && ! $strict_mode && \
                                         ([ "$token" = "yield" ] || [ "$token" = "let" ]); then
                                        # 'var yield' and 'var let' are allowed in non-strict mode
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
                                    # Check if it's a string literal
                                    if [[ ! "$token" =~ ^[\'\"] ]] && [[ ! "$token" =~ ^[0-9] ]]; then
                                        # Check if it's a valid identifier that happens to be reserved
                                        if [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]; then
                                            echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): '$token' cannot be used in computed property${NC}"
                                            echo "  $line"
                                            printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                            echo "$(realpath "$filename")"
                                            return 1
                                        fi
                                    fi
                                # Check for export default syntax error
                                elif $in_export_default && [ "$token" = "=" ]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'export default' cannot be followed by '='${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                # Check for export with reserved word
                                elif $in_export_named && ([ "$token" = "const" ] || [ "$token" = "let" ] || [ "$token" = "var" ] || [ "$token" = "class" ] || [ "$token" = "function" ]); then
                                    # export const/let/var/class/function is valid
                                    in_export_named=false
                                # Check for import namespace with reserved word
                                elif $in_import_clause && [ "$last_non_ws_token2" = "*" ] && [ "$last_non_ws_token" = "as" ] && is_reserved_word "$token"; then
                                    # import * as class from 'module' - invalid!
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): '$token' cannot be used as import namespace${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                # Check for import/export with reserved words without rename
                                elif ($in_import_clause && $import_has_brackets) || ($in_export_named && $export_has_brackets) && \
                                     ([ "$last_non_ws_token" = "{" ] || [ "$last_non_ws_token" = "," ]) && \
                                     is_reserved_word "$token" && [ "$token" != "default" ]; then
                                    # Look ahead for 'as' keyword
                                    local lookahead_col=$((col+1))
                                    local found_as=false
                                    local found_identifier=false
                                    local found_from=false
                                    local found_comma=false
                                    local found_close=false
                                    
                                    while [ $lookahead_col -lt $line_length ]; do
                                        local next_tok=$(get_token "$line" $lookahead_col)
                                        if [ "$next_tok" = "as" ]; then
                                            found_as=true
                                            break
                                        elif [ "$next_tok" = "from" ]; then
                                            found_from=true
                                            break
                                        elif [ "$next_tok" = "}" ]; then
                                            found_close=true
                                            break
                                        elif [ "$next_tok" = "," ]; then
                                            found_comma=true
                                            break
                                        elif [[ "$next_tok" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]] && [ "$next_tok" != "as" ]; then
                                            found_identifier=true
                                            break
                                        fi
                                        ((lookahead_col++))
                                    done
                                    
                                    if ! $found_as && ($found_from || $found_close || $found_comma); then
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Reserved word '$token' in import/export must be renamed with 'as'${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
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
                        if [ "$token" = "import" ]; then
                            in_import_clause=true
                        else
                            in_export_named=true
                        fi
                    elif [ "$token" = ";" ] || [ "$token" = "}" ] || [ "$token" = "from" ]; then
                        in_import_export=false
                        in_import_clause=false
                        in_export_default=false
                        in_export_named=false
                        import_has_brackets=false
                        export_has_brackets=false
                    fi
                fi
            fi
            
            ((col++))
        done
        
        # Reset for new line
        if $in_comment_single; then
            in_comment_single=false
        fi
        
        # Reset regex flag at end of line
        in_regex=false
        
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
    if [ "$file_size" -eq 0 ]; then
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
            # Check if this test is expected to pass or fail
            case "$filename" in
                # These tests should pass (no errors expected)
                *)
                    echo -e "${GREEN}  ✓ Passed as expected${NC}"
                    ((passed_tests++))
                    ;;
            esac
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
    echo -e "  ${RED}Failed:        $((total_tests - passed_tests))${NC}"
    
    if [ "$total_tests" -eq 0 ]; then
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
