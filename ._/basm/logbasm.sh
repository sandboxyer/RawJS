#!/bin/sh

# logbasm.sh - Runner that shows ONLY the actual program/script output
# For .asm: shows ONLY the binary output (no compilation/linking messages)
# For .sh: shows ONLY the script output
# Compatible with both bash and ash

# Save caller's directory
CALLER_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if input file is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <file> [args...]" >&2
    exit 1
fi

INPUT_FILE="$1"
shift
PROGRAM_ARGS="$@"

# Determine which shell to use for .sh files
if [ -n "$BASH_VERSION" ]; then
    RUNNER_SHELL_PATH="$(command -v bash 2>/dev/null || echo "/bin/bash")"
else
    RUNNER_SHELL_PATH="$(command -v sh 2>/dev/null || echo "/bin/sh")"
fi

# Function to detect file type
detect_file_type() {
    local filename="$1"
    
    if [ -f "$CALLER_DIR/$filename" ]; then
        local full_path="$CALLER_DIR/$filename"
    elif [ -f "$filename" ]; then
        local full_path="$filename"
    elif [ -f "$SCRIPT_DIR/$filename" ]; then
        local full_path="$SCRIPT_DIR/$filename"
    else
        echo "not_found"
        return
    fi
    
    case "$full_path" in
        *.asm) echo "asm:$full_path" ;;
        *.sh) echo "sh:$full_path" ;;
        *)
            if [ -x "$full_path" ]; then
                echo "binary:$full_path"
            elif head -n 1 "$full_path" 2>/dev/null | grep -q "^#!"; then
                echo "script:$full_path"
            elif command -v file >/dev/null 2>&1; then
                if file "$full_path" 2>/dev/null | grep -q -e "ELF" -e "executable" -e "Mach-O" -e "shared object"; then
                    echo "binary:$full_path"
                else
                    echo "unknown:$full_path"
                fi
            else
                echo "unknown:$full_path"
            fi
            ;;
    esac
}

# Function to find alternative file
find_alternative() {
    local original="$1"
    local current_type="$2"
    
    local basename="${original%.*}"
    local extension=""
    
    if [ "$basename" != "$original" ]; then
        extension="${original##*.}"
    fi
    
    check_file() {
        local file="$1"
        
        if [ -f "$CALLER_DIR/$file" ]; then
            echo "$CALLER_DIR/$file"
            return 0
        elif [ -f "$file" ]; then
            echo "$file"
            return 0
        elif [ -f "$SCRIPT_DIR/$file" ]; then
            echo "$SCRIPT_DIR/$file"
            return 0
        else
            return 1
        fi
    }
    
    case "$current_type" in
        asm|asm:*)
            local alt_file=""
            alt_file=$(check_file "${basename}.sh") || alt_file=$(check_file "$basename") || alt_file=""
            echo "$alt_file"
            ;;
        sh|sh:*)
            local alt_file=""
            alt_file=$(check_file "${basename}.asm") || alt_file=$(check_file "$basename") || alt_file=""
            echo "$alt_file"
            ;;
        binary|binary:*|unknown|unknown:*)
            local alt_file=""
            alt_file=$(check_file "${basename}.asm") || alt_file=$(check_file "${basename}.sh") || alt_file=""
            echo "$alt_file"
            ;;
        not_found)
            if [ -n "$extension" ]; then
                local alt_file=""
                alt_file=$(check_file "${basename}.asm") || \
                alt_file=$(check_file "${basename}.sh") || \
                alt_file=$(check_file "$basename") || \
                alt_file=""
                echo "$alt_file"
            else
                local alt_file=""
                alt_file=$(check_file "${original}.asm") || \
                alt_file=$(check_file "${original}.sh") || \
                alt_file=$(check_file "$original") || \
                alt_file=""
                echo "$alt_file"
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to run .asm file - shows ONLY binary output (no compilation messages)
run_asm() {
    local asm_file="$1"
    local args="$2"
    
    UNAME_M="$(uname -m)"
    
    case "$UNAME_M" in
        x86_64|amd64)
            ARCH="x86_64"
            FORMAT="elf64"
            ;;
        i386|i486|i586|i686)
            ARCH="i386"
            FORMAT="elf32"
            ;;
        arm|armv7l|armv8l)
            ARCH="arm"
            FORMAT="elf32"
            ;;
        aarch64|arm64)
            ARCH="arm"
            FORMAT="elf64"
            ;;
        *)
            return 1
            ;;
    esac
    
    NASM_BINARY="${SCRIPT_DIR}/${ARCH}-linux/nasm-${ARCH}-linux"
    
    if [ ! -f "$NASM_BINARY" ]; then
        return 1
    fi
    
    chmod +x "$NASM_BINARY" 2>/dev/null
    
    BASENAME="$(basename "$asm_file" .asm)"
    OUTPUT_DIR="$CALLER_DIR/.logbasm_tmp_$$"
    OBJECT_FILE="$OUTPUT_DIR/${BASENAME}.o"
    BINARY_FILE="$OUTPUT_DIR/${BASENAME}"
    
    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
    
    # Compile silently - suppress all output
    "$NASM_BINARY" -f "$FORMAT" "$asm_file" -o "$OBJECT_FILE" 2>/dev/null
    if [ $? -ne 0 ]; then
        rm -rf "$OUTPUT_DIR"
        return 1
    fi
    
    # Link silently - suppress all output
    ld "$OBJECT_FILE" -o "$BINARY_FILE" 2>/dev/null
    if [ $? -ne 0 ]; then
        rm -rf "$OUTPUT_DIR"
        return 1
    fi
    
    chmod +x "$BINARY_FILE" 2>/dev/null
    rm -f "$OBJECT_FILE"
    
    # Run the binary - THIS OUTPUT IS SHOWN (the real program log)
    (cd "$CALLER_DIR" && "$BINARY_FILE" $args)
    PROGRAM_EXIT=$?
    
    rm -rf "$OUTPUT_DIR"
    
    return $PROGRAM_EXIT
}

# Function to run .sh file - shows ONLY script output
run_sh() {
    local sh_file="$1"
    local args="$2"
    
    # Run script - output is shown directly
    (cd "$CALLER_DIR" && "$RUNNER_SHELL_PATH" "$sh_file" $args)
    return $?
}

# Function to run binary file - shows ONLY binary output
run_binary() {
    local binary_file="$1"
    local args="$2"
    
    # Run binary - output is shown directly
    (cd "$CALLER_DIR" && "$binary_file" $args)
    return $?
}

# Function to run script file - shows ONLY script output
run_script() {
    local script_file="$1"
    local args="$2"
    
    # Run script - output is shown directly
    (cd "$CALLER_DIR" && "$script_file" $args)
    return $?
}

# Main execution logic
main() {
    local original_file="$INPUT_FILE"
    local current_file="$original_file"
    local file_type_info=""
    local fallback_count=0
    
    while true; do
        file_type_info=$(detect_file_type "$current_file")
        file_type="${file_type_info%%:*}"
        full_path="${file_type_info#*:}"
        
        case "$file_type" in
            asm)
                run_asm "$full_path" "$PROGRAM_ARGS"
                return $?
                ;;
            sh)
                run_sh "$full_path" "$PROGRAM_ARGS"
                return $?
                ;;
            binary)
                run_binary "$full_path" "$PROGRAM_ARGS"
                return $?
                ;;
            script)
                run_script "$full_path" "$PROGRAM_ARGS"
                return $?
                ;;
            not_found)
                if [ $fallback_count -eq 0 ]; then
                    fallback_count=1
                fi
                
                local alternative_file
                if [ "$current_file" = "$original_file" ]; then
                    alternative_file=$(find_alternative "$current_file" "not_found")
                else
                    alternative_file=$(find_alternative "$current_file" "$file_type")
                fi
                
                if [ -n "$alternative_file" ] && [ "$alternative_file" != "$current_file" ]; then
                    current_file="$alternative_file"
                    continue
                else
                    echo "Error: File '$original_file' not found" >&2
                    exit 1
                fi
                ;;
            unknown)
                # Try to execute
                (cd "$CALLER_DIR" && "$full_path" $PROGRAM_ARGS)
                EXIT_CODE=$?
                
                if [ $EXIT_CODE -eq 126 ] || [ $EXIT_CODE -eq 127 ]; then
                    local alternative_file=$(find_alternative "$current_file" "unknown")
                    if [ -n "$alternative_file" ] && [ "$alternative_file" != "$current_file" ]; then
                        current_file="$alternative_file"
                        continue
                    else
                        echo "Cannot execute: $full_path" >&2
                        exit 1
                    fi
                else
                    return $EXIT_CODE
                fi
                ;;
        esac
    done
}

main