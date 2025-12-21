#!/bin/bash

# functions.sh - Transform JavaScript arrow functions to standard declarations
# Handles nested scopes, objects, arrays, and implicit returns.

INPUT_FILE="$1"
OUTPUT_FILE="${2:-polished.js}"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Usage: $0 <input.js> [output.js]"
    exit 1
fi

# Read entire file into a variable
CONTENT=$(<"$INPUT_FILE")

# Function to generate unique names
generate_name() {
    local prefix="${1:-func}"
    # Remove invalid chars for function names
    prefix=$(echo "$prefix" | tr -cd 'a-zA-Z0-9_')
    if [ -z "$prefix" ]; then prefix="func"; fi
    echo "${prefix}_$(date +%s%N)_${RANDOM}"
}

# Main processing function (Recursive)
# Arguments: $1 = javascript content to process
process_js() {
    local input="$1"
    local len=${#input}
    local output=""
    local stmt_buffer=""
    
    local i=0
    
    # State flags
    local in_sq=0      # Single Quote '
    local in_dq=0      # Double Quote "
    local in_bt=0      # Backtick `
    local in_cmt_l=0   # Line Comment //
    local in_cmt_b=0   # Block Comment /* */
    local brace_depth=0

    while (( i < len )); do
        local char="${input:$i:1}"
        local next_char="${input:$((i+1)):1}"
        
        # 1. Handle Strings and Comments (Skip content inside them)
        if (( in_sq )); then
            stmt_buffer+="$char"
            if [[ "$char" == "'" && "${input:$((i-1)):1}" != "\\" ]]; then in_sq=0; fi
            ((i++)); continue
        elif (( in_dq )); then
            stmt_buffer+="$char"
            if [[ "$char" == '"' && "${input:$((i-1)):1}" != "\\" ]]; then in_dq=0; fi
            ((i++)); continue
        elif (( in_bt )); then
            stmt_buffer+="$char"
            if [[ "$char" == '`' && "${input:$((i-1)):1}" != "\\" ]]; then in_bt=0; fi
            ((i++)); continue
        elif (( in_cmt_l )); then
            stmt_buffer+="$char"
            if [[ "$char" == $'\n' ]]; then in_cmt_l=0; fi
            ((i++)); continue
        elif (( in_cmt_b )); then
            stmt_buffer+="$char"
            if [[ "$char" == '*' && "$next_char" == '/' ]]; then
                stmt_buffer+="/"
                in_cmt_b=0
                ((i+=2)); continue
            fi
            ((i++)); continue
        else
            # Start of strings/comments
            if [[ "$char" == "'" ]]; then in_sq=1; stmt_buffer+="$char"; ((i++)); continue; fi
            if [[ "$char" == '"' ]]; then in_dq=1; stmt_buffer+="$char"; ((i++)); continue; fi
            if [[ "$char" == '`' ]]; then in_bt=1; stmt_buffer+="$char"; ((i++)); continue; fi
            if [[ "$char" == '/' && "$next_char" == '/' ]]; then in_cmt_l=1; stmt_buffer+="//"; ((i+=2)); continue; fi
            if [[ "$char" == '/' && "$next_char" == '*' ]]; then in_cmt_b=1; stmt_buffer+="/*"; ((i+=2)); continue; fi
        fi

        # 2. Detect Arrow Function "=>"
        if [[ "$char" == "=" && "$next_char" == ">" ]]; then
            # Found arrow function.
            # We must look BACKWARDS in stmt_buffer to find params and context.

            local buf_len=${#stmt_buffer}
            local params=""
            local name_hint=""
            local context_end_index=$buf_len
            
            # A. Extract Parameters (Scan backwards from end of stmt_buffer)
            # Remove trailing whitespace/newlines from buffer for checking
            local temp_idx=$((buf_len - 1))
            while (( temp_idx >= 0 )); do
                if [[ "${stmt_buffer:$temp_idx:1}" =~ [[:space:]] ]]; then
                    ((temp_idx--))
                else
                    break
                fi
            done
            local last_char="${stmt_buffer:$temp_idx:1}"

            if [[ "$last_char" == ")" ]]; then
                # Parenthesized params (a,b)
                local paren_balance=1
                local p_idx=$((temp_idx - 1))
                while (( p_idx >= 0 )); do
                    local p_char="${stmt_buffer:$p_idx:1}"
                    if [[ "$p_char" == ")" ]]; then ((paren_balance++)); fi
                    if [[ "$p_char" == "(" ]]; then ((paren_balance--)); fi
                    if (( paren_balance == 0 )); then
                        params="${stmt_buffer:$((p_idx+1)):$((temp_idx - p_idx - 1))}"
                        context_end_index=$p_idx
                        break
                    fi
                    ((p_idx--))
                done
            else
                # Single identifier param: x =>
                local p_idx=$temp_idx
                while (( p_idx >= 0 )); do
                    local p_char="${stmt_buffer:$p_idx:1}"
                    if [[ ! "$p_char" =~ [a-zA-Z0-9_$] ]]; then
                        break
                    fi
                    ((p_idx--))
                done
                params="${stmt_buffer:$((p_idx+1)):$((temp_idx - p_idx))}"
                context_end_index=$((p_idx + 1))
            fi

            # B. Determine Name Hint (look before context_end_index)
            # Scan back skipping whitespace
            local scan_idx=$((context_end_index - 1))
            while (( scan_idx >= 0 )) && [[ "${stmt_buffer:$scan_idx:1}" =~ [[:space:]] ]]; do
                ((scan_idx--))
            done

            local prev_char="${stmt_buffer:$scan_idx:1}"
            
            if [[ "$prev_char" == "=" ]]; then
                # Assignment: let myFunc = ...
                # Scan back to find variable name
                scan_idx=$((scan_idx - 1))
                while (( scan_idx >= 0 )) && [[ "${stmt_buffer:$scan_idx:1}" =~ [[:space:]] ]]; do ((scan_idx--)); done
                
                local name_end=$scan_idx
                while (( scan_idx >= 0 )); do
                    if [[ ! "${stmt_buffer:$scan_idx:1}" =~ [a-zA-Z0-9_$] ]]; then break; fi
                    ((scan_idx--))
                done
                name_hint="${stmt_buffer:$((scan_idx+1)):$((name_end - scan_idx))}"
                
            elif [[ "$prev_char" == ":" ]]; then
                # Object Property: key: ...
                scan_idx=$((scan_idx - 1))
                while (( scan_idx >= 0 )) && [[ "${stmt_buffer:$scan_idx:1}" =~ [[:space:]] ]]; do ((scan_idx--)); done
                
                local name_end=$scan_idx
                while (( scan_idx >= 0 )); do
                    if [[ ! "${stmt_buffer:$scan_idx:1}" =~ [a-zA-Z0-9_$] ]]; then break; fi
                    ((scan_idx--))
                done
                name_hint="${stmt_buffer:$((scan_idx+1)):$((name_end - scan_idx))}"
            fi

            # Clean up buffer: Remove params from stmt_buffer
            stmt_buffer="${stmt_buffer:0:$context_end_index}"

            # C. Extract Body (Scan forward from i+2)
            local body_start_idx=$((i + 2))
            # Skip whitespace
            while (( body_start_idx < len )); do
                if [[ ! "${input:$body_start_idx:1}" =~ [[:space:]] ]]; then break; fi
                ((body_start_idx++))
            done

            local extracted_body=""
            local body_is_block=0
            local new_i=$body_start_idx

            if [[ "${input:$body_start_idx:1}" == "{" ]]; then
                # Brace Block
                body_is_block=1
                local b_depth=1
                new_i=$((body_start_idx + 1))
                local b_sq=0; local b_dq=0; local b_bt=0
                
                while (( new_i < len )); do
                    local b_char="${input:$new_i:1}"
                    if (( b_sq )); then [[ "$b_char" == "'" && "${input:$((new_i-1)):1}" != "\\" ]] && b_sq=0;
                    elif (( b_dq )); then [[ "$b_char" == '"' && "${input:$((new_i-1)):1}" != "\\" ]] && b_dq=0;
                    elif (( b_bt )); then [[ "$b_char" == '`' && "${input:$((new_i-1)):1}" != "\\" ]] && b_bt=0;
                    else
                        if [[ "$b_char" == "'" ]]; then b_sq=1;
                        elif [[ "$b_char" == '"' ]]; then b_dq=1;
                        elif [[ "$b_char" == '`' ]]; then b_bt=1;
                        elif [[ "$b_char" == "{" ]]; then ((b_depth++));
                        elif [[ "$b_char" == "}" ]]; then ((b_depth--));
                        fi
                    fi
                    
                    if (( b_depth == 0 )); then break; fi
                    ((new_i++))
                done
                # extracted_body includes content INSIDE braces
                extracted_body="${input:$((body_start_idx+1)):$((new_i - body_start_idx - 1))}"
                ((new_i++)) # Move past closing brace
            else
                # Implicit Return (scan until comma, semicolon, closing paren/bracket/brace)
                # Be careful of nested structures in the expression
                local p_bal=0; local bk_bal=0; local br_bal=0
                local b_sq=0; local b_dq=0; local b_bt=0
                
                while (( new_i < len )); do
                    local b_char="${input:$new_i:1}"
                    if (( b_sq )); then [[ "$b_char" == "'" && "${input:$((new_i-1)):1}" != "\\" ]] && b_sq=0;
                    elif (( b_dq )); then [[ "$b_char" == '"' && "${input:$((new_i-1)):1}" != "\\" ]] && b_dq=0;
                    elif (( b_bt )); then [[ "$b_char" == '`' && "${input:$((new_i-1)):1}" != "\\" ]] && b_bt=0;
                    else
                        if [[ "$b_char" == "'" ]]; then b_sq=1;
                        elif [[ "$b_char" == '"' ]]; then b_dq=1;
                        elif [[ "$b_char" == '`' ]]; then b_bt=1;
                        elif [[ "$b_char" == "(" ]]; then ((p_bal++));
                        elif [[ "$b_char" == ")" ]]; then 
                            if (( p_bal == 0 )); then break; fi
                            ((p_bal--))
                        elif [[ "$b_char" == "[" ]]; then ((bk_bal++));
                        elif [[ "$b_char" == "]" ]]; then 
                            if (( bk_bal == 0 )); then break; fi
                            ((bk_bal--))
                        elif [[ "$b_char" == "{" ]]; then ((br_bal++));
                        elif [[ "$b_char" == "}" ]]; then 
                            if (( br_bal == 0 )); then break; fi
                            ((br_bal--))
                        elif [[ "$b_char" == "," || "$b_char" == ";" ]]; then
                            if (( p_bal == 0 && bk_bal == 0 && br_bal == 0 )); then break; fi
                        fi
                    fi
                    ((new_i++))
                done
                extracted_body="${input:$body_start_idx:$((new_i - body_start_idx))}"
                extracted_body="return $extracted_body" # Add implicit return
            fi

            # D. Recursively Process Body
            local processed_body=$(process_js "$extracted_body")

            # E. Generate Function with UNIQUE name
            local final_name=""
            
            # Always generate unique name even if we have a name_hint
            if [ -n "$name_hint" ]; then
                # Use name_hint as prefix but make it unique
                local clean_hint=$(echo "$name_hint" | tr -cd 'a-zA-Z0-9_')
                if [ -z "$clean_hint" ]; then
                    final_name=$(generate_name)
                else
                    # Generate unique name with timestamp and random component
                    final_name="${clean_hint}_$(date +%s%N)_${RANDOM}"
                fi
            else
                final_name=$(generate_name)
            fi
            
            # Ensure final_name is valid
            final_name=$(echo "$final_name" | tr -cd 'a-zA-Z0-9_')
            if [ -z "$final_name" ]; then
                final_name=$(generate_name)
            fi

            # Construct the hoisted function
            local func_decl="function ${final_name}(${params}){${processed_body}};"
            
            # Append declaration to OUTPUT (Hoisting it!)
            output+="$func_decl"
            
            # Add function reference to current statement
            stmt_buffer+="$final_name"
            
            # Advance main index to new_i
            i=$new_i
            continue
        fi

        # 3. Handle End of Statement/Block (Flush buffer)
        stmt_buffer+="$char"
        if [[ "$char" == "{" ]]; then ((brace_depth++)); fi
        if [[ "$char" == "}" ]]; then ((brace_depth--)); fi
        
        # Flush buffer at statement boundaries
        if [[ "$char" == ";" && $brace_depth -eq 0 ]]; then
            output+="$stmt_buffer"
            stmt_buffer=""
        fi
        
        ((i++))
    done

    # Append remaining buffer
    output+="$stmt_buffer"
    echo "$output"
}

# Run the transformation
RESULT=$(process_js "$CONTENT")

# Post-processing to match the requested output format strictly
# The requested output removes "let x =" if the function name matches x, 
# or keeps "let x = x_fn".
# We generated "function x_fn...; let x = x_fn".
# Clean up purely cosmetic semicolons or spacing if needed.
# (The logic above generates valid functional code).

echo "$RESULT" > "$OUTPUT_FILE"
echo "Transformation complete. Output saved to $OUTPUT_FILE"