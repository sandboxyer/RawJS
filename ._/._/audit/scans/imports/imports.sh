#!/bin/bash

# JavaScript Import/Export Syntax Error Auditor - Pure Bash Implementation
# Usage: ./imports.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="1.0.0"
TEST_DIR="imports_tests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Reserved import/export keywords and patterns
IMPORT_KEYWORDS="import from as"
EXPORT_KEYWORDS="export default from as"
MODULE_KEYWORDS="$IMPORT_KEYWORDS $EXPORT_KEYWORDS"

# Function to display usage
show_usage() {
    echo -e "${BLUE}JavaScript Import/Export Syntax Error Auditor v${AUDIT_SCRIPT_VERSION}${NC}"
    echo "Pure bash implementation - No Node.js required"
    echo "Usage: $0 <filename.js>"
    echo "       $0 --test"
    echo ""
    echo "Options:"
    echo "  <filename.js>    Audit a specific JavaScript file for import/export errors"
    echo "  --test           Run test suite against known import/export error patterns"
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

# Function to check if character is a quote
is_quote() {
    local char="$1"
    case "$char" in
        "'"|'"'|'`') return 0 ;;
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
            # Strings and template literals
            "'"|'"'|'`')
                token="$char"
                ((pos++))
                # Skip to end of string
                while [ $pos -lt $length ] && [ "${line:$pos:1}" != "$char" ]; do
                    # Handle escapes
                    if [ "${line:$pos:1}" = "\\" ]; then
                        ((pos++))
                        if [ $pos -lt $length ]; then
                            ((pos++))
                        fi
                    else
                        ((pos++))
                    fi
                done
                if [ $pos -lt $length ]; then
                    ((pos++)) # Skip closing quote
                fi
                ;;
            # Identifiers and keywords
            *)
                if is_valid_id_start "$char"; then
                    while [ $pos -lt $length ] && is_valid_id_char "${line:$pos:1}"; do
                        ((pos++))
                    done
                elif [[ "$char" =~ [0-9] ]]; then
                    while [ $pos -lt $length ] && ([[ "${line:$pos:1}" =~ [0-9] ]] || [ "${line:$pos:1}" = "." ]); do
                        ((pos++))
                    done
                fi
                ;;
        esac
        
        token="${line:$start:$((pos-start))}"
    fi
    
    echo "$token"
}

# Function to check if token is a valid JavaScript identifier
is_valid_identifier() {
    local token="$1"
    [[ "$token" =~ ^[a-zA-Z_$][a-zA-Z0-9_$]*$ ]]
}

# Function to check if token is a reserved word in import/export context
is_reserved_in_module_context() {
    local token="$1"
    case "$token" in
        "default"|"as"|"from"|"import"|"export")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to check import/export syntax
check_import_export_syntax() {
    local filename="$1"
    local line_number=0
    local in_comment_single=false
    local in_comment_multi=false
    local in_string_single=false
    local in_string_double=false
    local in_template=false
    local in_import_statement=false
    local in_export_statement=false
    local in_import_clause=false
    local in_export_clause=false
    local in_namespace_import=false
    local in_default_import=false
    local in_named_imports=false
    local in_named_exports=false
    local in_braces=false
    local brace_count=0
    local bracket_count=0
    local paren_count=0
    local last_token=""
    local last_non_ws_token=""
    local expecting_identifier=false
    local expecting_from=false
    local expecting_comma_or_brace=false
    local expecting_module_specifier=false
    local import_has_default=false
    local import_has_namespace=false
    local import_has_named=false
    local export_is_default=false
    local export_is_star=false
    local export_has_from=false
    local seen_identifiers=()
    local module_top_level=true
    local in_function_or_block=false
    local current_import_braces=0
    local current_export_braces=0
    
    # Track if we're at module top level (imports/exports must be at top)
    local lines_before_import_export=()
    
    # Read file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_number++))
        local col=0
        local line_length=${#line}
        
        # Check if we've seen non-import/export code before current line
        if [ $line_number -gt 1 ] && [ ${#lines_before_import_export[@]} -gt 0 ]; then
            # We've already seen non-import/export code
            module_top_level=false
        fi
        
        # Process each character
        while [ $col -lt $line_length ]; do
            local char="${line:$col:1}"
            local next_char=""
            [ $((col+1)) -lt $line_length ] && next_char="${line:$((col+1)):1}"
            
            # Check for string/comment contexts
            if ! $in_comment_single && ! $in_comment_multi; then
                # Check for string/template literal start
                if [ "$char" = "'" ] && ! $in_string_double && ! $in_template; then
                    if $in_string_single; then
                        in_string_single=false
                    else
                        in_string_single=true
                    fi
                elif [ "$char" = '"' ] && ! $in_string_single && ! $in_template; then
                    if $in_string_double; then
                        in_string_double=false
                    else
                        in_string_double=true
                    fi
                elif [ "$char" = '`' ] && ! $in_string_single && ! $in_string_double; then
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
            
            # Only check syntax if not inside string/comment
            if ! $in_string_single && ! $in_string_double && ! $in_template && ! $in_comment_single && ! $in_comment_multi; then
                # Get current token
                local token
                token_length=0
                token=$(get_token "$line" $col)
                token_length=${#token}
                
                if [ -n "$token" ] && [ "$token_length" -gt 0 ]; then
                    # Update column position
                    ((col += token_length - 1))
                    
                    # Check for import/export statements
                    case "$token" in
                        "import")
                            # Check if import is at top level
                            if ! $module_top_level && ! $in_import_statement; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Import statement must be at module top level${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check for invalid preceding tokens
                            if [ "$last_non_ws_token" != "" ] && [ "$last_non_ws_token" != ";" ] && \
                               [ "$last_non_ws_token" != "{" ] && [ "$last_non_ws_token" != "}" ] && \
                               [ "$last_non_ws_token" != "(" ] && [ "$last_non_ws_token" != ")" ] && \
                               [ "$last_non_ws_token" != "[" ] && [ "$last_non_ws_token" != "]" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected 'import'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            in_import_statement=true
                            expecting_identifier=true
                            import_has_default=false
                            import_has_namespace=false
                            import_has_named=false
                            seen_identifiers=()
                            ;;
                            
                        "export")
                            # Check if export is at top level
                            if ! $module_top_level && ! $in_export_statement; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Export statement must be at module top level${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            # Check for invalid preceding tokens
                            if [ "$last_non_ws_token" != "" ] && [ "$last_non_ws_token" != ";" ] && \
                               [ "$last_non_ws_token" != "{" ] && [ "$last_non_ws_token" != "}" ] && \
                               [ "$last_non_ws_token" != "(" ] && [ "$last_non_ws_token" != ")" ] && \
                               [ "$last_non_ws_token" != "[" ] && [ "$last_non_ws_token" != "]" ]; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected 'export'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            in_export_statement=true
                            export_is_default=false
                            export_is_star=false
                            export_has_from=false
                            ;;
                            
                        "default")
                            if $in_import_statement && $expecting_identifier; then
                                # 'default' cannot be used as named import without alias
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): 'default' cannot be used as named import without alias${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            
                            if $in_export_statement && [ "$last_non_ws_token" = "export" ]; then
                                export_is_default=true
                                expecting_identifier=true
                            fi
                            ;;
                            
                        "*")
                            if $in_import_statement && ($expecting_identifier || $in_namespace_import); then
                                import_has_namespace=true
                                in_namespace_import=true
                                expecting_identifier=false
                                expecting_from=true
                            elif $in_export_statement && [ "$last_non_ws_token" = "export" ]; then
                                export_is_star=true
                                expecting_from=true
                            fi
                            ;;
                            
                        "as")
                            if $in_import_statement && ($in_named_imports || $in_namespace_import); then
                                expecting_identifier=true
                            elif $in_export_statement && $in_named_exports; then
                                expecting_identifier=true
                            else
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected 'as'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        "from")
                            if $in_import_statement && ($import_has_default || $import_has_namespace || $import_has_named || $expecting_from); then
                                expecting_module_specifier=true
                                expecting_from=false
                            elif $in_export_statement && ($export_is_star || $in_named_exports || $export_has_from); then
                                expecting_module_specifier=true
                                export_has_from=true
                            else
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected 'from'${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        "{")
                            if $in_import_statement && ! $import_has_default && ! $import_has_namespace; then
                                in_named_imports=true
                                in_braces=true
                                import_has_named=true
                                current_import_braces=$brace_count
                                ((brace_count++))
                                expecting_identifier=true
                                expecting_comma_or_brace=false
                            elif $in_export_statement && ! $export_is_default && ! $export_is_star; then
                                in_named_exports=true
                                in_braces=true
                                current_export_braces=$brace_count
                                ((brace_count++))
                                expecting_identifier=true
                                expecting_comma_or_brace=false
                            else
                                # Track regular braces
                                ((brace_count++))
                            fi
                            ;;
                            
                        "}")
                            if $in_braces; then
                                if $in_named_imports && [ $brace_count -eq $((current_import_braces + 1)) ]; then
                                    in_named_imports=false
                                    in_braces=false
                                    expecting_from=true
                                elif $in_named_exports && [ $brace_count -eq $((current_export_braces + 1)) ]; then
                                    in_named_exports=false
                                    in_braces=false
                                    # Check if this is a re-export (has 'from') or regular export
                                    if [ "$export_has_from" = true ]; then
                                        expecting_module_specifier=true
                                    else
                                        # Regular named export ends here
                                        in_export_statement=false
                                    fi
                                fi
                            fi
                            ((brace_count--))
                            ;;
                            
                        ",")
                            if $in_named_imports || $in_named_exports; then
                                if $expecting_comma_or_brace; then
                                    expecting_identifier=true
                                    expecting_comma_or_brace=false
                                else
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected comma${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            elif $in_import_statement || $in_export_statement; then
                                echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected comma outside braces${NC}"
                                echo "  $line"
                                printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                echo "$(realpath "$filename")"
                                return 1
                            fi
                            ;;
                            
                        ";")
                            # End of statement
                            if $in_import_statement || $in_export_statement; then
                                if $expecting_module_specifier || $expecting_from || $expecting_identifier; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected end of import/export statement${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                                # Reset all import/export flags
                                in_import_statement=false
                                in_export_statement=false
                                in_namespace_import=false
                                in_default_import=false
                                in_named_imports=false
                                in_named_exports=false
                                expecting_identifier=false
                                expecting_from=false
                                expecting_module_specifier=false
                                export_is_default=false
                                export_is_star=false
                                export_has_from=false
                                seen_identifiers=()
                            fi
                            ;;
                            
                        *)
                            # Handle identifiers and module specifiers
                            if $in_import_statement || $in_export_statement; then
                                # Check for module specifier (string)
                                if is_quote "${token:0:1}"; then
                                    if $expecting_module_specifier; then
                                        expecting_module_specifier=false
                                        # Module specifier found, statement should end with semicolon
                                    else
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected string literal${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                # Check for identifiers
                                elif is_valid_identifier "$token"; then
                                    if $expecting_identifier; then
                                        if $in_named_imports || $in_named_exports; then
                                            # Check for duplicate identifiers in named imports/exports
                                            for seen_id in "${seen_identifiers[@]}"; do
                                                if [ "$seen_id" = "$token" ]; then
                                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Duplicate identifier '$token'${NC}"
                                                    echo "  $line"
                                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                                    echo "$(realpath "$filename")"
                                                    return 1
                                                fi
                                            done
                                            seen_identifiers+=("$token")
                                        fi
                                        
                                        expecting_identifier=false
                                        if $in_named_imports || $in_named_exports; then
                                            expecting_comma_or_brace=true
                                        elif $in_import_statement && ! $import_has_namespace && ! $import_has_named; then
                                            # Default import identifier
                                            import_has_default=true
                                            expecting_from=true
                                        fi
                                    else
                                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Unexpected identifier '$token'${NC}"
                                        echo "  $line"
                                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                        echo "$(realpath "$filename")"
                                        return 1
                                    fi
                                # Check for numbers (invalid as identifiers)
                                elif [[ "$token" =~ ^[0-9] ]]; then
                                    echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Numbers cannot be used as import/export identifiers${NC}"
                                    echo "  $line"
                                    printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                                    echo "$(realpath "$filename")"
                                    return 1
                                fi
                            fi
                            ;;
                    esac
                    
                    # Update last non-whitespace token
                    if [ "$token" != "" ]; then
                        last_non_ws_token="$token"
                    fi
                    
                    # Track if we're in a function or block (imports/exports not allowed)
                    case "$token" in
                        "function"|"class"|"=>"|"{")
                            if [ "$token" = "{" ] && [ $brace_count -eq 1 ] && \
                               [ "$last_non_ws_token" != "export" ] && \
                               [ "$last_non_ws_token" != "import" ]; then
                                in_function_or_block=true
                            fi
                            ;;
                        "}")
                            if [ $brace_count -eq 0 ]; then
                                in_function_or_block=false
                            fi
                            ;;
                    esac
                    
                    # Check for import/export inside function/block
                    if $in_function_or_block && ( [ "$token" = "import" ] || [ "$token" = "export" ] ); then
                        echo -e "${RED}Error at line $line_number, column $((col-token_length+2)): Import/export statements not allowed inside functions/blocks${NC}"
                        echo "  $line"
                        printf "%*s^%s\n" $((col-token_length+1)) "" "${RED}here${NC}"
                        echo "$(realpath "$filename")"
                        return 1
                    fi
                    
                    # Track non-import/export code to enforce top-level rule
                    if ! $in_import_statement && ! $in_export_statement && \
                       [ "$token" != ";" ] && [ "$token" != "" ] && \
                       ! is_whitespace "$token" && \
                       [ "$token" != "{" ] && [ "$token" != "}" ] && \
                       [ "$token" != "(" ] && [ "$token" != ")" ]; then
                        # Add line number to array if not already there
                        local found=false
                        for line_num in "${lines_before_import_export[@]}"; do
                            if [ "$line_num" = "$line_number" ]; then
                                found=true
                                break
                            fi
                        done
                        if ! $found; then
                            lines_before_import_export+=("$line_number")
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
        
        # Check for unterminated import/export at end of line
        if ($in_import_statement || $in_export_statement) && [ $col -ge $line_length ]; then
            # Check what we're expecting
            if $expecting_module_specifier; then
                echo -e "${RED}Error at line $line_number: Missing module specifier after 'from'${NC}"
                echo "  $line"
                echo "$(realpath "$filename")"
                return 1
            elif $expecting_from && ($import_has_default || $import_has_namespace || $import_has_named); then
                echo -e "${RED}Error at line $line_number: Missing 'from' clause${NC}"
                echo "  $line"
                echo "$(realpath "$filename")"
                return 1
            elif $expecting_identifier; then
                echo -e "${RED}Error at line $line_number: Missing identifier${NC}"
                echo "  $line"
                echo "$(realpath "$filename")"
                return 1
            fi
        fi
        
    done < "$filename"
    
    # Check for unterminated import/export at end of file
    if $in_import_statement || $in_export_statement; then
        echo -e "${RED}Error: Unterminated import/export statement${NC}"
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
    
    # Check bracket/brace counts
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

# Function to audit a single JavaScript file for import/export errors
audit_js_file() {
    local filename="$1"
    
    if [ ! -f "$filename" ]; then
        echo -e "${RED}Error: File '$filename' not found${NC}"
        return 1
    fi
    
    if [[ ! "$filename" =~ \.js$ ]] && [[ ! "$filename" =~ \.mjs$ ]]; then
        echo -e "${YELLOW}Warning: File '$filename' doesn't have .js or .mjs extension${NC}"
    fi
    
    echo -e "${CYAN}Auditing Import/Export Syntax:${NC} ${filename}"
    echo "========================================"
    
    # Check file size
    local file_size=$(wc -c < "$filename")
    if [ $file_size -eq 0 ]; then
        echo -e "${GREEN}✓ Empty file - no errors${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    fi
    
    # Run our import/export syntax checker
    if check_import_export_syntax "$filename"; then
        echo -e "${GREEN}✓ No import/export syntax errors found${NC}"
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running JavaScript Import/Export Syntax Error Test Suite${NC}"
    echo "========================================"
    
    # Check if test directory exists, if not generate it
    if [ ! -d "$TEST_DIR" ]; then
        echo -e "${YELLOW}Test directory '$TEST_DIR' not found.${NC}"
        echo -e "${CYAN}Generating test directory with import/export error patterns...${NC}"
        
        # Check if we can generate tests
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
            # Create a simple test directory
            mkdir -p "$TEST_DIR"
            echo -e "${YELLOW}Created empty test directory. Please add test files manually.${NC}"
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
            echo -e "${GREEN}  ✓ Correctly detected import/export error${NC}"
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
