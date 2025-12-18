#!/bin/bash

# JavaScript Regular Expression Syntax Auditor - Improved Pure Bash Implementation
# Usage: ./regex.sh <filename.js> [--test]

AUDIT_SCRIPT_VERSION="2.0.1"
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
    
    # Check for duplicate flags
    for ((i=0; i<${#flags}; i++)); do
        local flag="${flags:$i:1}"
        
        # Check if flag is valid
        case "$flag" in
            g|i|m|s|u|y)
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
    
    # Check for invalid combinations
    if [[ "$flags" == *s* ]] && [[ "$flags" == *u* ]]; then
        # Check if dotall flag 's' is used with unicode flag 'u'
        # In JavaScript, 's' and 'u' can be used together
        # No action needed for this combination
        :
    fi
    
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
        # Operators and punctuators that can precede regex literals
        '('|'['|'{'|','|';'|':'|'?'|'!'|'&'|'|'|'^'|'~'|'='|'<'|'>'|'+'|'-'|'*'|'/'|'%'|'@'|'.')
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
            
            # Keywords that can be followed by regex literal
            case "$token" in
                "return"|"case"|"throw"|"typeof"|"instanceof"|"void"|"delete"|"in"|"of"|"await"|"yield"|"else"|"do")
                    return 0
                    ;;
                "if"|"while"|"for"|"with"|"switch")
                    return 0
                    ;;
                *)
                    # Check if previous token is an operator
                    if [ $j -ge 0 ]; then
                        local before_token="${line:$j:1}"
                        case "$before_token" in
                            '('|'['|'{'|','|';'|':'|'?'|'!'|'&'|'|'|'^'|'~'|'='|'<'|'>'|'+'|'-'|'*'|'/'|'%'|'@'|'.')
                                return 0
                                ;;
                        esac
                    fi
                    return 1
                    ;;
            esac
            ;;
        # Quotation marks and backticks indicate string/template, not regex
        '"'|"'"|'`')
            return 1
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
                local in_quantifier=false
                
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
                        '{')
                            if ! $in_char_class; then
                                in_quantifier=true
                            fi
                            pattern="${pattern}$char"
                            ;;
                        '}')
                            if ! $in_char_class; then
                                in_quantifier=false
                            fi
                            pattern="${pattern}$char"
                            ;;
                        '/')
                            if $in_char_class || $in_quantifier; then
                                # Slash inside character class or quantifier is part of pattern
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
                                regexes+=("literal:$pattern:$flags:$line_number:$regex_start")
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
                    regexes+=("literal:$pattern:::$line_number:$regex_start:unterminated")
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

# Function to extract RegExp constructor calls
extract_regexp_constructors() {
    local line="$1"
    local line_number="$2"
    local regexes=()
    
    local line_len=${#line}
    local pos=0
    
    # Look for "new RegExp" or "RegExp(" patterns
    while [ $pos -lt $line_len ]; do
        # Check for "RegExp"
        if [ $((line_len - pos)) -ge 6 ] && [ "${line:$pos:6}" = "RegExp" ]; then
            local regex_start=$pos
            
            # Move past "RegExp"
            ((pos += 6))
            
            # Skip whitespace
            while [ $pos -lt $line_len ] && is_whitespace "${line:$pos:1}"; do
                ((pos++))
            done
            
            # Check for opening parenthesis
            if [ $pos -lt $line_len ] && [ "${line:$pos:1}" = '(' ]; then
                ((pos++))
                
                # Skip whitespace
                while [ $pos -lt $line_len ] && is_whitespace "${line:$pos:1}"; do
                    ((pos++))
                done
                
                # Extract pattern
                local pattern=""
                local flags=""
                local in_string=false
                local string_delim=""
                local escape_next=false
                
                # Parse pattern argument
                if [ $pos -lt $line_len ]; then
                    local char="${line:$pos:1}"
                    
                    # Check for string delimiters
                    if [ "$char" = '"' ] || [ "$char" = "'" ]; then
                        string_delim="$char"
                        in_string=true
                        ((pos++))
                        
                        while [ $pos -lt $line_len ] && ( $in_string || ! [ "${line:$pos:1}" = ',' ] ); do
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
                                "$string_delim")
                                    if ! $escape_next; then
                                        in_string=false
                                        ((pos++))
                                        break
                                    else
                                        pattern="${pattern}$char"
                                        escape_next=false
                                    fi
                                    ;;
                                *)
                                    pattern="${pattern}$char"
                                    ;;
                            esac
                            ((pos++))
                        done
                        
                        # Skip whitespace
                        while [ $pos -lt $line_len ] && is_whitespace "${line:$pos:1}"; do
                            ((pos++))
                        done
                        
                        # Check for flags argument
                        if [ $pos -lt $line_len ] && [ "${line:$pos:1}" = ',' ]; then
                            ((pos++))
                            
                            # Skip whitespace
                            while [ $pos -lt $line_len ] && is_whitespace "${line:$pos:1}"; do
                                ((pos++))
                            done
                            
                            # Parse flags argument
                            if [ $pos -lt $line_len ]; then
                                char="${line:$pos:1}"
                                
                                if [ "$char" = '"' ] || [ "$char" = "'" ]; then
                                    string_delim="$char"
                                    in_string=true
                                    ((pos++))
                                    
                                    while [ $pos -lt $line_len ] && $in_string; do
                                        char="${line:$pos:1}"
                                        
                                        if $escape_next; then
                                            flags="${flags}\\$char"
                                            escape_next=false
                                            ((pos++))
                                            continue
                                        fi
                                        
                                        case "$char" in
                                            '\\')
                                                escape_next=true
                                                flags="${flags}$char"
                                                ;;
                                            "$string_delim")
                                                if ! $escape_next; then
                                                    in_string=false
                                                else
                                                    flags="${flags}$char"
                                                    escape_next=false
                                                fi
                                                ;;
                                            *)
                                                flags="${flags}$char"
                                                ;;
                                        esac
                                        ((pos++))
                                    done
                                fi
                            fi
                        fi
                        
                        # Store the regex constructor
                        if [ -n "$pattern" ]; then
                            regexes+=("constructor:$pattern:$flags:$line_number:$regex_start")
                        fi
                    fi
                fi
            fi
        else
            ((pos++))
        fi
    done
    
    printf "%s\n" "${regexes[@]}"
}

# Function to validate character class ranges
validate_character_class_ranges() {
    local pattern="$1"
    local in_char_class=false
    local escape_next=false
    local class_start=0
    local last_char_in_class=""
    
    for ((i=0; i<${#pattern}; i++)); do
        local char="${pattern:$i:1}"
        
        if $escape_next; then
            escape_next=false
            if $in_char_class; then
                last_char_in_class="\\$char"
            fi
            continue
        fi
        
        case "$char" in
            '\\')
                escape_next=true
                ;;
            '[')
                if ! $in_char_class; then
                    in_char_class=true
                    last_char_in_class=""
                else
                    return 1  # Nested character class
                fi
                ;;
            ']')
                if $in_char_class; then
                    in_char_class=false
                fi
                ;;
            '-')
                if $in_char_class && [ -n "$last_char_in_class" ] && [ $i -lt $((${#pattern}-1)) ]; then
                    local next_char="${pattern:$((i+1)):1}"
                    if [ "$next_char" != ']' ]; then
                        # Check if range is valid
                        if [[ "$last_char_in_class" > "$next_char" ]]; then
                            echo "invalid_range"
                            return 1
                        fi
                        # Skip the next character since it's part of range
                        ((i++))
                        last_char_in_class=""
                    fi
                elif $in_char_class && [ $i -gt 0 ] && [ "${pattern:$((i-1)):1}" = '[' ]; then
                    # Dash at start of character class
                    last_char_in_class=""
                elif $in_char_class && [ $i -lt $((${#pattern}-1)) ] && [ "${pattern:$((i+1)):1}" = ']' ]; then
                    # Dash at end of character class
                    :
                elif $in_char_class && [ -n "$last_char_in_class" ] && [ "$last_char_in_class" = '-' ]; then
                    # Double dash in character class
                    echo "double_dash"
                    return 1
                fi
                if $in_char_class; then
                    last_char_in_class="-"
                fi
                ;;
            *)
                if $in_char_class; then
                    last_char_in_class="$char"
                fi
                ;;
        esac
    done
    
    echo "valid"
    return 0
}

# Function to validate quantifier ranges
validate_quantifier_ranges() {
    local pattern="$1"
    local in_escape=false
    local in_char_class=false
    
    for ((i=0; i<${#pattern}; i++)); do
        local char="${pattern:$i:1}"
        
        if $in_escape; then
            in_escape=false
            continue
        fi
        
        case "$char" in
            '\\')
                in_escape=true
                ;;
            '[')
                in_char_class=true
                ;;
            ']')
                in_char_class=false
                ;;
            '{')
                if ! $in_char_class; then
                    local j=$((i+1))
                    local start_num=""
                    local end_num=""
                    
                    # Parse the quantifier
                    while [ $j -lt ${#pattern} ] && [ "${pattern:$j:1}" != '}' ]; do
                        local quant_char="${pattern:$j:1}"
                        
                        if [[ "$quant_char" =~ [0-9] ]]; then
                            if [ -z "$start_num" ]; then
                                start_num="${start_num}$quant_char"
                            else
                                end_num="${end_num}$quant_char"
                            fi
                        elif [ "$quant_char" = ',' ]; then
                            if [ -n "$end_num" ]; then
                                # Already has comma, second comma is invalid
                                return 1
                            fi
                        else
                            # Invalid character in quantifier
                            return 1
                        fi
                        ((j++))
                    done
                    
                    if [ $j -ge ${#pattern} ]; then
                        return 1  # Unterminated quantifier
                    fi
                    
                    # Check if quantifier is valid
                    if [ -n "$start_num" ] && [ -n "$end_num" ]; then
                        if [ "$start_num" -gt "$end_num" ]; then
                            echo "invalid_range"
                            return 1
                        fi
                    fi
                fi
                ;;
        esac
    done
    
    echo "valid"
    return 0
}

# Function to validate Unicode escapes
validate_unicode_escapes() {
    local pattern="$1"
    local flags="$2"
    
    # Check for \u{...} escapes without 'u' flag
    if [[ "$pattern" = *\\u\{* ]] && [[ ! "$flags" =~ u ]]; then
        echo "missing_unicode_flag"
        return 1
    fi
    
    # Check for invalid Unicode code points
    if [[ "$pattern" =~ \\u\{([^}]*)\} ]]; then
        local code_point="${BASH_REMATCH[1]}"
        if ! [[ "$code_point" =~ ^[0-9A-Fa-f]+$ ]]; then
            echo "invalid_unicode_hex"
            return 1
        fi
        
        # Check if code point is too large (max 10FFFF in hex = 1114111 in decimal)
        local decimal=$((16#$code_point 2>/dev/null || echo 0))
        if [ $decimal -gt 1114111 ]; then
            echo "invalid_unicode_range"
            return 1
        fi
    fi
    
    # Check for empty Unicode escape \u{}
    if [[ "$pattern" = *\\u\{\}* ]]; then
        echo "empty_unicode_escape"
        return 1
    fi
    
    echo "valid"
    return 0
}

# Function to validate property escapes \p{...}
validate_property_escapes() {
    local pattern="$1"
    local flags="$2"
    
    # Check for \p{...} escapes without 'u' flag
    if [[ "$pattern" = *\\p\{* ]] && [[ ! "$flags" =~ u ]]; then
        echo "missing_property_escape_flag"
        return 1
    fi
    
    echo "valid"
    return 0
}

# Function to validate backreferences
validate_backreferences() {
    local pattern="$1"
    local in_escape=false
    
    for ((i=0; i<${#pattern}; i++)); do
        local char="${pattern:$i:1}"
        
        if $in_escape; then
            in_escape=false
            if [[ "$char" =~ [1-9] ]]; then
                # Check for invalid backreference \10 when there are less than 10 groups
                if [ $i -lt $((${#pattern}-1)) ] && [[ "${pattern:$((i+1)):1}" =~ [0-9] ]]; then
                    local num="${char}${pattern:$((i+1)):1}"
                    if [ "$num" = "10" ]; then
                        # \10 is only valid if there are 10 capturing groups
                        echo "potential_invalid_backreference"
                        return 1
                    fi
                fi
            elif [ "$char" = "k" ]; then
                # Named backreference \k<name>
                if [ $i -lt $((${#pattern}-1)) ] && [ "${pattern:$((i+1)):1}" = '<' ]; then
                    local j=$((i+2))
                    local name=""
                    while [ $j -lt ${#pattern} ] && [ "${pattern:$j:1}" != '>' ]; do
                        name="${name}${pattern:$j:1}"
                        ((j++))
                    done
                    
                    if [ $j -ge ${#pattern} ]; then
                        echo "unclosed_named_backreference"
                        return 1
                    fi
                fi
            fi
            continue
        fi
        
        case "$char" in
            '\\')
                in_escape=true
                ;;
        esac
    done
    
    echo "valid"
    return 0
}

# Function to validate named capture groups - FIXED VERSION
validate_named_captures() {
    local pattern="$1"
    
    # Check for named capture groups (?<name>)
    local i=0
    local len=${#pattern}
    
    while [ $i -lt $len ]; do
        # Look for (?<
        if [ $((len - i)) -ge 4 ] && 
           [ "${pattern:$i:1}" = '(' ] &&
           [ "${pattern:$((i+1)):1}" = '?' ] &&
           [ "${pattern:$((i+2)):1}" = '<' ]; then
           
            local j=$((i+3))
            local name=""
            
            # Extract the name
            while [ $j -lt $len ] && [ "${pattern:$j:1}" != '>' ]; do
                name="${name}${pattern:$j:1}"
                ((j++))
            done
            
            if [ $j -ge $len ]; then
                # No closing >
                echo "unclosed_named_capture"
                return 1
            fi
            
            # Validate the name
            if [ -z "$name" ]; then
                echo "empty_named_capture"
                return 1
            elif [[ "$name" =~ ^[0-9] ]]; then
                echo "numeric_named_capture"
                return 1
            elif [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                echo "invalid_named_capture"
                return 1
            fi
            
            # Skip past this capture group
            i=$j
        fi
        
        ((i++))
    done
    
    echo "valid"
    return 0
}

# Function to validate lookbehind assertions - FIXED VERSION
validate_lookbehind() {
    local pattern="$1"
    
    local i=0
    local len=${#pattern}
    
    while [ $i -lt $len ]; do
        # Look for (?<= or (?<!
        if [ $((len - i)) -ge 5 ] && 
           [ "${pattern:$i:1}" = '(' ] &&
           [ "${pattern:$((i+1)):1}" = '?' ]; then
           
            # Check for lookbehind
            if [ "${pattern:$((i+2)):1}" = '<' ]; then
                if [ "${pattern:$((i+3)):1}" = '=' ] || 
                   [ "${pattern:$((i+3)):1}" = '!' ]; then
                    # Valid lookbehind start
                    # Now check if it's properly closed
                    local j=$((i+4))
                    local paren_depth=1
                    
                    while [ $j -lt $len ] && [ $paren_depth -gt 0 ]; do
                        if [ "${pattern:$j:1}" = '(' ]; then
                            ((paren_depth++))
                        elif [ "${pattern:$j:1}" = ')' ]; then
                            ((paren_depth--))
                        fi
                        ((j++))
                    done
                    
                    if [ $paren_depth -gt 0 ]; then
                        echo "unclosed_lookbehind"
                        return 1
                    fi
                else
                    # (?< followed by something other than = or !
                    echo "invalid_lookbehind"
                    return 1
                fi
            fi
        fi
        
        ((i++))
    done
    
    echo "valid"
    return 0
}

# Enhanced function to validate regex pattern syntax
validate_regex_pattern() {
    local pattern="$1"
    local flags="$2"
    
    # Quick sanity checks
    if [ -z "$pattern" ]; then
        echo "empty_pattern"
        return 1
    fi
    
    # Check for common regex syntax errors
    local len=${#pattern}
    local in_char_class=0
    local in_escape=0
    local paren_count=0
    local bracket_count=0
    local last_char=""
    local last_was_quantifiable=false
    
    for ((i=0; i<len; i++)); do
        local char="${pattern:$i:1}"
        
        if [ $in_escape -eq 1 ]; then
            in_escape=0
            last_char="\\$char"
            last_was_quantifiable=true
            continue
        fi
        
        case "$char" in
            '\\')
                in_escape=1
                last_char=""
                last_was_quantifiable=false
                ;;
            '[')
                if [ $in_char_class -eq 0 ]; then
                    in_char_class=1
                    bracket_count=1
                    last_char="$char"
                    last_was_quantifiable=false
                    
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
                    last_char="$char"
                    last_was_quantifiable=true
                else
                    # Unmatched closing bracket
                    echo "unmatched_closing_bracket"
                    return 1
                fi
                ;;
            '(')
                ((paren_count++))
                last_char="$char"
                last_was_quantifiable=false
                ;;
            ')')
                if [ $paren_count -gt 0 ]; then
                    ((paren_count--))
                    last_char="$char"
                    last_was_quantifiable=true
                else
                    # Unmatched closing paren
                    echo "unmatched_closing_paren"
                    return 1
                fi
                ;;
            '{')
                # Check if quantifier has something to quantify
                if ! $last_was_quantifiable; then
                    echo "nothing_to_repeat"
                    return 1
                fi
                
                # Parse the quantifier
                local j=$((i+1))
                local quantifier=""
                while [ $j -lt $len ] && [ "${pattern:$j:1}" != '}' ]; do
                    quantifier="${quantifier}${pattern:$j:1}"
                    ((j++))
                done
                
                if [ $j -ge $len ]; then
                    echo "unclosed_quantifier"
                    return 1
                fi
                
                # Validate quantifier syntax
                if [[ ! "$quantifier" =~ ^[0-9]+(,[0-9]+)?$ ]] && [[ ! "$quantifier" =~ ^[0-9]+,$ ]]; then
                    echo "invalid_quantifier"
                    return 1
                fi
                
                # Check quantifier range
                if [[ "$quantifier" =~ ^([0-9]+),([0-9]+)$ ]]; then
                    local start="${BASH_REMATCH[1]}"
                    local end="${BASH_REMATCH[2]}"
                    if [ "$start" -gt "$end" ]; then
                        echo "invalid_quantifier_range"
                        return 1
                    fi
                fi
                
                last_char="$char"
                last_was_quantifiable=false
                ;;
            '}')
                # Should be caught in '{' handler
                echo "unmatched_brace"
                return 1
                ;;
            '?'|'*'|'+')
                # Check quantifiers
                if [ $in_char_class -eq 0 ]; then
                    if ! $last_was_quantifiable; then
                        echo "nothing_to_repeat"
                        return 1
                    fi
                fi
                last_char="$char"
                last_was_quantifiable=false
                ;;
            '|')
                # Check for empty alternative
                if [ $in_char_class -eq 0 ] && \
                   ([ -z "$last_char" ] || [ "$last_char" = '(' ] || [ "$last_char" = '[' ] || [ "$last_char" = '|' ]); then
                    echo "empty_alternative"
                    return 1
                fi
                last_char="$char"
                last_was_quantifiable=false
                ;;
            '^'|'$'|'.')
                last_char="$char"
                last_was_quantifiable=true
                ;;
            *)
                last_char="$char"
                last_was_quantifiable=true
                ;;
        esac
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
    
    # Run additional validations
    local result
    
    # Validate character class ranges
    result=$(validate_character_class_ranges "$pattern")
    if [ "$result" != "valid" ]; then
        echo "$result"
        return 1
    fi
    
    # Validate quantifier ranges
    result=$(validate_quantifier_ranges "$pattern")
    if [ "$result" != "valid" ]; then
        echo "$result"
        return 1
    fi
    
    # Validate Unicode escapes
    result=$(validate_unicode_escapes "$pattern" "$flags")
    if [ "$result" != "valid" ]; then
        echo "$result"
        return 1
    fi
    
    # Validate property escapes
    result=$(validate_property_escapes "$pattern" "$flags")
    if [ "$result" != "valid" ]; then
        echo "$result"
        return 1
    fi
    
    # Validate backreferences
    result=$(validate_backreferences "$pattern")
    if [ "$result" != "valid" ]; then
        echo "$result"
        return 1
    fi
    
    # Validate named captures
    result=$(validate_named_captures "$pattern")
    if [ "$result" != "valid" ]; then
        echo "$result"
        return 1
    fi
    
    # Validate lookbehind assertions
    result=$(validate_lookbehind "$pattern")
    if [ "$result" != "valid" ]; then
        echo "$result"
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
        
        # Extract RegExp constructors from line
        local regex_constructors
        regex_constructors=$(extract_regexp_constructors "$line" "$line_number")
        
        # Combine all regex patterns
        local all_regexes
        all_regexes=$(printf "%s\n%s" "$regex_literals" "$regex_constructors")
        
        # Check each regex
        while IFS= read -r regex_info; do
            if [ -n "$regex_info" ]; then
                IFS=':' read -r type pattern flags regex_line regex_start extra <<< "$regex_info"
                
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
                    continue
                fi
                
                # Validate pattern syntax
                local pattern_result
                pattern_result=$(validate_regex_pattern "$pattern" "$flags")
                
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
                        "invalid_range")
                            echo -e "  ${YELLOW}Invalid character class range${NC}"
                            ;;
                        "double_dash")
                            echo -e "  ${YELLOW}Double dash in character class${NC}"
                            ;;
                        "invalid_quantifier_range")
                            echo -e "  ${YELLOW}Invalid quantifier range (start > end)${NC}"
                            ;;
                        "missing_unicode_flag")
                            echo -e "  ${YELLOW}Unicode escape requires 'u' flag${NC}"
                            ;;
                        "invalid_unicode_hex")
                            echo -e "  ${YELLOW}Invalid Unicode escape sequence${NC}"
                            ;;
                        "invalid_unicode_range")
                            echo -e "  ${YELLOW}Unicode code point out of range${NC}"
                            ;;
                        "empty_unicode_escape")
                            echo -e "  ${YELLOW}Empty Unicode escape sequence${NC}"
                            ;;
                        "missing_property_escape_flag")
                            echo -e "  ${YELLOW}Property escape requires 'u' flag${NC}"
                            ;;
                        "potential_invalid_backreference")
                            echo -e "  ${YELLOW}Potentially invalid backreference${NC}"
                            ;;
                        "unclosed_named_backreference")
                            echo -e "  ${YELLOW}Unclosed named backreference${NC}"
                            ;;
                        "empty_named_capture")
                            echo -e "  ${YELLOW}Empty named capture group${NC}"
                            ;;
                        "numeric_named_capture")
                            echo -e "  ${YELLOW}Named capture group cannot start with number${NC}"
                            ;;
                        "invalid_named_capture")
                            echo -e "  ${YELLOW}Invalid named capture group name${NC}"
                            ;;
                        "invalid_lookbehind")
                            echo -e "  ${YELLOW}Invalid lookbehind assertion${NC}"
                            ;;
                        "unclosed_lookbehind")
                            echo -e "  ${YELLOW}Unclosed lookbehind assertion${NC}"
                            ;;
                        "unclosed_quantifier")
                            echo -e "  ${YELLOW}Unclosed quantifier${NC}"
                            ;;
                        "invalid_quantifier")
                            echo -e "  ${YELLOW}Invalid quantifier syntax${NC}"
                            ;;
                        "unmatched_brace")
                            echo -e "  ${YELLOW}Unmatched closing brace${NC}"
                            ;;
                        *)
                            echo -e "  ${YELLOW}Pattern syntax error: $pattern_result${NC}"
                            ;;
                    esac
                    echo "$(realpath "$filename")"
                    ((errors_found++))
                fi
            fi
        done <<< "$all_regexes"
        
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
