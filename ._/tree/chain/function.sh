#!/bin/bash
# function.sh – Converts current build_output.asm into a named function
# Usage: ./function.sh [--call]
# Reads function definition from arch_output file.
# Appends the function to the parent build_output.asm
# Enhanced: Proper variable scoping, string handling, and metadata generation
# FIX: Pre-declare ALL parameters (even without defaults) before Raw.sh
# FIX: apply_renames is context-aware and rewrites bracketed operands,
#      leading data labels, and bare `orig_str` / `orig_float_val` /
#      `orig_defined_flag` tokens used in code (e.g. `mov rdi, quotient_str`).
# FIX: apply_renames now safely short-circuits when there are NO real
#      identifiers to rename (previously it invoked `sed -E` with an empty
#      script, producing a usage error and failing empty-body functions).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOCAL_FILE="./build_output.asm"
PARENT_FILE="../../build_output.asm"
INPUT_FILE="arch_output"
RUN_OUTPUT_FILE="run_output"
RAW_SCRIPT="../../../Raw.sh"
WITH_CALL=0

for arg in "$@"; do
    case "$arg" in
        --call) WITH_CALL=1 ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found"
    exit 1
fi

if [ ! -f "$PARENT_FILE" ]; then
    echo "Error: $PARENT_FILE not found"
    exit 1
fi

if [ ! -f "$RAW_SCRIPT" ]; then
    echo "Error: $RAW_SCRIPT not found"
    exit 1
fi

# ----------------------------------------------------------------------
# STEP 0: Parse function definition from arch_output BEFORE Raw.sh
# ----------------------------------------------------------------------
echo "Step 0: Parsing function definition..."

FUNC_LINE=$(grep -o 'function[[:space:]]*[^(]*([^)]*)' "$INPUT_FILE" | head -1)
if [ -z "$FUNC_LINE" ]; then
    echo "Error: No function definition found in $INPUT_FILE"
    exit 1
fi

FUNC_NAME=$(echo "$FUNC_LINE" | sed 's/function[[:space:]]*\([^(]*\)(.*/\1/' | tr -d '[:space:]')
if [ -z "$FUNC_NAME" ]; then
    echo "Error: Could not parse function name"
    exit 1
fi

PARAMS_STR=$(echo "$FUNC_LINE" | sed 's/.*(\(.*\)).*/\1/')
IFS=',' read -ra PARAMS <<< "$PARAMS_STR"

declare -a PNAMES
declare -a PDEFAULTS
declare -a PTYPES

for p in "${PARAMS[@]}"; do
    p=$(echo "$p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "$p" ]; then continue; fi
   
    if [[ "$p" == *=* ]]; then
        name="${p%%=*}"
        default="${p#*=}"
        name=$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        default=$(echo "$default" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
       
        if [[ "$default" =~ ^\".*\"$ ]]; then
            dtype="string"
            default="${default:1:${#default}-2}"
        elif [[ "$default" =~ ^-?[0-9]+$ ]]; then
            dtype="number"
        elif [[ "$default" =~ ^-?[0-9]*\.[0-9]+$ ]]; then
            dtype="float"
        else
            dtype="variable"
        fi
    else
        name="$p"
        default=""
        dtype="none"
    fi
   
    PNAMES+=("$name")
    PDEFAULTS+=("$default")
    PTYPES+=("$dtype")
done

echo "✓ Function name: $FUNC_NAME"
echo "✓ Parameters: ${#PNAMES[@]}"
for i in "${!PNAMES[@]}"; do
    echo "  - ${PNAMES[$i]} (default: '${PDEFAULTS[$i]}', type: ${PTYPES[$i]})"
done
echo ""

# ----------------------------------------------------------------------
# STEP 1: Create run_output
# ----------------------------------------------------------------------
echo "Step 1: Creating run_output from arch_output with parameter declarations..."

awk '
BEGIN { chain_depth = 0; skip_line = 0 }
{
    line = $0
   
    if (line ~ /<chain-start>/) {
        if (chain_depth == 0) {
            line = ""
            skip_line = 1
        }
        chain_depth++
    }
   
    if (line ~ /<chain-end>/) {
        chain_depth--
        if (chain_depth == 0) {
            line = ""
            skip_line = 1
        }
    }
   
    if (line ~ /^[[:space:]]*function[[:space:]]*[^(]*\([^)]*\)/) {
        line = ""
        skip_line = 1
    }
   
    if (!skip_line) {
        print line
    }
   
    skip_line = 0
}
' "$INPUT_FILE" > "$RUN_OUTPUT_FILE.tmp"

{
    for i in "${!PNAMES[@]}"; do
        name="${PNAMES[$i]}"
        default="${PDEFAULTS[$i]}"
        dtype="${PTYPES[$i]}"
        
        if [ "$dtype" == "none" ]; then
            echo "<js-start>    var ${name} = undefined;    <js-end>"
        elif [ "$dtype" == "string" ]; then
            escaped_default="${default//\"/\\\"}"
            echo "<js-start>    var ${name} = \"${escaped_default}\";    <js-end>"
        else
            echo "<js-start>    var ${name} = ${default};    <js-end>"
        fi
    done
    cat "$RUN_OUTPUT_FILE.tmp"
} > "$RUN_OUTPUT_FILE"

rm -f "$RUN_OUTPUT_FILE.tmp"

if [ ! -s "$RUN_OUTPUT_FILE" ]; then
    echo "Error: Failed to create run_output"
    exit 1
fi

echo "✓ run_output created successfully (with parameter declarations)"
echo ""

# ----------------------------------------------------------------------
# STEP 2: Run Raw.sh to generate function body
# ----------------------------------------------------------------------
echo "Step 2: Running Raw.sh to generate function body..."

RAW_SCRIPT_ABS="$(cd "$(dirname "$RAW_SCRIPT")" && pwd)/$(basename "$RAW_SCRIPT")"

if [ -f "$RAW_SCRIPT_ABS/.rawjs_private" ] || [ -n "$RAWJS_PRIVATE_MODE" ]; then
    ORIGINAL_RAW=""
    CURRENT_DIR="$RAW_SCRIPT_ABS"
    while [ "$CURRENT_DIR" != "/" ]; do
        CURRENT_DIR=$(dirname "$CURRENT_DIR")
        if [ -f "$CURRENT_DIR/Raw.sh" ] && [ ! -f "$CURRENT_DIR/.rawjs_private" ]; then
            ORIGINAL_RAW="$CURRENT_DIR/Raw.sh"
            break
        fi
    done
   
    if [ -n "$ORIGINAL_RAW" ]; then
        RAW_SCRIPT_ABS="$ORIGINAL_RAW"
    fi
fi

if [ -n "$RAWJS_PRIVATE_MODE" ]; then
    env -u RAWJS_PRIVATE_MODE -u RAWJS_PRIVATE_ROOT bash "$RAW_SCRIPT_ABS" --tmp --asm "$RUN_OUTPUT_FILE"
else
    bash "$RAW_SCRIPT_ABS" --tmp --asm "$RUN_OUTPUT_FILE"
fi

MAX_WAIT=30
WAIT_COUNT=0
while [ ! -f "$LOCAL_FILE" ]; do
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo "Error: Timeout waiting for build_output.asm to be created"
        exit 1
    fi
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ ! -s "$LOCAL_FILE" ]; then
    echo "Error: build_output.asm is empty"
    exit 1
fi

echo "✓ Function body generated successfully"
echo ""

# ----------------------------------------------------------------------
# STEP 3.5: Write function metadata for call generation
# ----------------------------------------------------------------------
echo "Step 3.5: Writing function metadata..."

META_DIR="../function_meta"
mkdir -p "$META_DIR"

META_FILE="$META_DIR/${FUNC_NAME}.meta"

{
    echo "function_name=$FUNC_NAME"
    for i in "${!PNAMES[@]}"; do
        echo "param=${PNAMES[$i]}|${PDEFAULTS[$i]}|${PTYPES[$i]}"
    done
} > "$META_FILE"

echo "✓ Metadata written to $META_FILE"
echo ""

# ----------------------------------------------------------------------
# STEP 5: Extract data and function body from generated build_output.asm
# ----------------------------------------------------------------------
echo "Step 5: Extracting function body..."

LOCAL_DATA=""
IN_DATA=0

while IFS= read -r line; do
    if [[ "$line" == "section .data" ]]; then
        IN_DATA=1
        continue
    elif [[ "$line" == "section .bss" ]]; then
        IN_DATA=0
        break
    fi
   
    if [ $IN_DATA -eq 1 ]; then
        if echo "$line" | grep -qE '^[[:space:]]*(;|COLOR_|TYPE_|true_str|false_str|null_str|undefined_str|hex_prefix|float_scale|float_ten|space|newline|$)'; then
            continue
        fi
        LOCAL_DATA+="$line"$'\n'
    fi
done < "$LOCAL_FILE"

FUNCTION_BODY=""
IN_FUNCTION=0
CAPTURE=0

while IFS= read -r line; do
    if [[ "$line" == "_start:" ]]; then
        IN_FUNCTION=1
        CAPTURE=1
        continue
    fi
   
    if [ $IN_FUNCTION -eq 1 ] && echo "$line" | grep -qE '^[[:space:]]*mov[[:space:]]+rax,[[:space:]]*60$'; then
        CAPTURE=0
        IN_FUNCTION=0
        continue
    fi
   
    if [ $IN_FUNCTION -eq 0 ] && echo "$line" | grep -qE '^[[:space:]]*(xor|syscall)'; then
        continue
    fi
   
    if [ $CAPTURE -eq 1 ]; then
        if echo "$line" | grep -qE '^[[:space:]]*;.*(Your code here|Example usage|mov rax, 42|mov rdx, TYPE_NUMBER|call print|mov rax, newline|mov rdx, TYPE_STRING)'; then
            continue
        fi
        FUNCTION_BODY+="$line"$'\n'
    fi
done < "$LOCAL_FILE"

FUNCTION_BODY=$(echo "$FUNCTION_BODY" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

echo "✓ Function body extracted"
echo ""

# ----------------------------------------------------------------------
# STEP 5.5: Apply variable scoping
# ----------------------------------------------------------------------
echo "Step 5.5: Applying variable scoping..."

declare -A RENAME_MAP

for pname in "${PNAMES[@]}"; do
    if [ -n "$pname" ]; then
        RENAME_MAP["$pname"]=1
    fi
done

while IFS= read -r line; do
    if [[ "$line" =~ (var|let|const)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
        var_name="${BASH_REMATCH[2]}"
        RENAME_MAP["$var_name"]=1
    fi
done < "$RUN_OUTPUT_FILE"

# Populate `idents` safely. Filter out empty entries so we never invoke
# `sed -E` with an empty script (which produces a usage error).
declare -a idents=()
if [ -n "${RENAME_MAP[*]:-}" ]; then
    while IFS= read -r _id; do
        if [ -n "$_id" ] && [[ "$_id" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            idents+=("$_id")
        fi
    done < <(printf "%s\n" "${!RENAME_MAP[@]}" | awk 'NF { print length, $0 }' | sort -rn | cut -d' ' -f2-)
fi

# ----------------------------------------------------------------------
# apply_renames
#
# Renames identifiers only where they can legitimately appear as a
# variable name in the generated assembly:
#   1. [orig]              -> [new]
#   2. [orig_suffix]       -> [new_suffix]
#   3. leading data label:  ^\s*orig\s+(db|dq|dd|dw|equ|times|resb|resq|resd|resw)
#   4. leading data label with underscore suffix:  ^\s*orig_
#   5. bare `orig_str` token in code
#   6. bare `orig_float_val` token in code
#   7. bare `orig_defined_flag` token in code
#
# This avoids over-aggressive `\borig\b` substitution which would corrupt
# NASM keywords/instructions like `times` and `add`.
#
# If there is nothing to rename, the input is returned verbatim WITHOUT
# invoking sed, so that empty-body functions like `function opa()` work.
# ----------------------------------------------------------------------
apply_renames() {
    local text="$1"

    if [ -z "$text" ]; then
        printf '%s' ""
        return 0
    fi

    # Nothing to rename: return input verbatim
    if [ ${#idents[@]} -eq 0 ]; then
        printf '%s' "$text"
        return 0
    fi

    local sed_args=()
    local orig
    for orig in "${idents[@]}"; do
        if [ -z "$orig" ]; then
            continue
        fi

        local new="${FUNC_NAME}_${orig}"

        # 1. [orig] -> [new]
        sed_args+=(-e "s/\\[${orig}\\]/[${new}]/g")

        # 2. [orig_suffix] -> [new_suffix]
        sed_args+=(-e "s/\\[${orig}_/[${new}_/g")

        # 3. Leading data label with NASM directive
        sed_args+=(-e "s/^([[:space:]]*)${orig}([[:space:]]+(db|dq|dd|dw|equ|times|resb|resq|resd|resw))/\1${new}\2/")

        # 4. Leading data label with underscore suffix
        sed_args+=(-e "s/^([[:space:]]*)${orig}(_)/\1${new}\2/")

        # 5. Bare `orig_str` token in code (not preceded by `[` or word char)
        sed_args+=(-e "s/(^|[^A-Za-z0-9_\\[])${orig}_str([^A-Za-z0-9_]|$)/\1${new}_str\2/g")

        # 6. Bare `orig_float_val` token in code
        sed_args+=(-e "s/(^|[^A-Za-z0-9_\\[])${orig}_float_val([^A-Za-z0-9_]|$)/\1${new}_float_val\2/g")

        # 7. Bare `orig_defined_flag` token in code
        sed_args+=(-e "s/(^|[^A-Za-z0-9_\\[])${orig}_defined_flag([^A-Za-z0-9_]|$)/\1${new}_defined_flag\2/g")
    done

    # Defensive: if somehow sed_args still ended up empty, return verbatim.
    if [ ${#sed_args[@]} -eq 0 ]; then
        printf '%s' "$text"
        return 0
    fi

    printf '%s' "$text" | sed -E "${sed_args[@]}"
    return 0
}

if [ ${#idents[@]} -gt 0 ]; then
    LOCAL_DATA=$(apply_renames "$LOCAL_DATA")
    FUNCTION_BODY=$(apply_renames "$FUNCTION_BODY")
    echo "✓ Renamed ${#idents[@]} local identifiers with prefix '${FUNC_NAME}_'"
else
    echo "✓ No local identifiers to rename"
fi
echo ""

# Find return statements
RETURN_EXPR=""
while IFS= read -r line; do
    if [[ "$line" == *"return"* ]]; then
        expr=$(echo "$line" | sed 's/<js-end>.*$//' | sed -n 's/.*return[[:space:]]*\([^;]*\).*/\1/p')
        expr=$(echo "$expr" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$expr" ]; then
            RETURN_EXPR="$expr"
            break
        fi
    fi
done < "$RUN_OUTPUT_FILE"

FUNCTION_CODE="${FUNC_NAME}:"$'\n'
FUNCTION_CODE+="${FUNCTION_BODY}"$'\n'

if [ -n "$RETURN_EXPR" ]; then
    echo "✓ Found return expression: $RETURN_EXPR"
    if [[ "$RETURN_EXPR" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        scoped_return="${FUNC_NAME}_${RETURN_EXPR}"
        FUNCTION_CODE+="    ; Return value: ${RETURN_EXPR}"$'\n'
        FUNCTION_CODE+="    mov rax, [${scoped_return}]"$'\n'
        FUNCTION_CODE+="    mov rdx, [${scoped_return}_type]"$'\n'
    else
        FUNCTION_CODE+="    ; Return value: ${RETURN_EXPR} (literal not supported)"$'\n'
        FUNCTION_CODE+="    xor rax, rax"$'\n'
        FUNCTION_CODE+="    mov rdx, TYPE_UNDEFINED"$'\n'
    fi
fi

FUNCTION_CODE+="    ret"$'\n'

ALL_DATA="$LOCAL_DATA"

echo "✓ Function body with scoped variables prepared"
echo ""

# ----------------------------------------------------------------------
# STEP 6: Append function to parent build_output.asm
# ----------------------------------------------------------------------
echo "Step 6: Appending function to parent build_output.asm..."

TEMP_FILE=$(mktemp)

awk -v all_data="$ALL_DATA" -v function_code="$FUNCTION_CODE" -v with_call="$WITH_CALL" '
BEGIN {
    inserted_data = 0
    inserted_function = 0
    skip_old_start = 0
}
/^section \.bss/ && !inserted_data {
    if (all_data != "") {
        print all_data
    }
    inserted_data = 1
}
/^_start:/ && !inserted_function {
    print function_code
    inserted_function = 1
    if (with_call) {
        skip_old_start = 1
        print ""
        print "_start:"
        print "    mov rax, 60"
        print "    xor rdi, rdi"
        print "    syscall"
        next
    }
}
skip_old_start && /^[[:space:]]*mov[[:space:]]+rax,[[:space:]]*60$/ {
    skip_old_start = 2
    next
}
skip_old_start == 2 && /^[[:space:]]*syscall/ {
    skip_old_start = 0
    next
}
skip_old_start {
    next
}
{ print }
END {
    if (!inserted_function) {
        print function_code
        if (with_call) {
            print ""
            print "_start:"
            print "    mov rax, 60"
            print "    xor rdi, rdi"
            print "    syscall"
        }
    }
}
' "$PARENT_FILE" > "$TEMP_FILE"

mv "$TEMP_FILE" "$PARENT_FILE"

echo "✓ Function '$FUNC_NAME' successfully created"
echo ""
echo "All steps completed successfully!"
exit 0
