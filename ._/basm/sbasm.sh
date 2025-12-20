#!/bin/sh

# sbasm.sh - Silent runner for .asm, .sh, and binary files with fallback logic
# Compatible with both bash and ash
# IMPORTANT: All execution happens in the CALLER's directory, not where sbasm.sh is located
# Silent version - only shows program/compilation output, no logging

# Save caller's directory
CALLER_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if input file is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <file> [args...]"
    echo "Supported file types: .asm, .sh, or any executable binary"
    exit 1
fi

INPUT_FILE="$1"
shift  # Remove the first argument (file name), leaving only args for the binary
PROGRAM_ARGS="$@"

# Determine which shell to use for .sh files based on how this script was invoked
if [ -n "$BASH_VERSION" ]; then
    RUNNER_SHELL_PATH="$(command -v bash 2>/dev/null || echo "/bin/bash")"
else
    RUNNER_SHELL_PATH="$(command -v sh 2>/dev/null || echo "/bin/sh")"
fi

# Function to detect file type with caller directory awareness
detect_file_type() {
    local filename="$1"
    
    # First check in caller directory
    if [ -f "$CALLER_DIR/$filename" ]; then
        local full_path="$CALLER_DIR/$filename"
    elif [ -f "$filename" ] && [ "$(dirname "$(realpath "$filename" 2>/dev/null || echo "$filename")")" != "$SCRIPT_DIR" ]; then
        # File exists and is not in script directory
        local full_path="$filename"
    elif [ -f "$filename" ]; then
        # File exists but might be relative to script directory
        local full_path="$filename"
    else
        echo "not_found"
        return
    fi
    
    case "$full_path" in
        *.asm) echo "asm:$full_path" ;;
        *.sh) echo "sh:$full_path" ;;
        *)
            # Check if it's executable
            if [ -x "$full_path" ]; then
                echo "binary:$full_path"
            # Check if it starts with shebang
            elif head -n 1 "$full_path" 2>/dev/null | grep -q "^#!"; then
                echo "script:$full_path"
            # Use file command to detect binary
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

# Function to find alternative file with caller directory awareness
find_alternative() {
    local original="$1"
    local current_type="$2"
    
    # Extract basename and extension
    local basename="${original%.*}"
    local extension=""
    
    if [ "$basename" != "$original" ]; then
        extension="${original##*.}"
    fi
    
    # Helper function to check if file exists
    check_file() {
        local file="$1"
        
        # Check in caller directory first
        if [ -f "$CALLER_DIR/$file" ]; then
            echo "$CALLER_DIR/$file"
            return 0
        # Check as absolute/relative path
        elif [ -f "$file" ]; then
            echo "$file"
            return 0
        # Check in script directory (last resort)
        elif [ -f "$SCRIPT_DIR/$file" ]; then
            echo "$SCRIPT_DIR/$file"
            return 0
        else
            return 1
        fi
    }
    
    # Try different file types based on current type
    case "$current_type" in
        asm|asm:*)
            # .asm -> .sh -> binary (without extension)
            local alt_file=""
            alt_file=$(check_file "${basename}.sh") || alt_file=$(check_file "$basename") || alt_file=""
            echo "$alt_file"
            ;;
        sh|sh:*)
            # .sh -> .asm -> binary (without extension)
            local alt_file=""
            alt_file=$(check_file "${basename}.asm") || alt_file=$(check_file "$basename") || alt_file=""
            echo "$alt_file"
            ;;
        binary|binary:*|unknown|unknown:*)
            # binary -> .asm -> .sh
            local alt_file=""
            alt_file=$(check_file "${basename}.asm") || alt_file=$(check_file "${basename}.sh") || alt_file=""
            echo "$alt_file"
            ;;
        not_found)
            # Original not found, try all possibilities
            if [ -n "$extension" ]; then
                # Has extension, try without extension
                local alt_file=""
                alt_file=$(check_file "${basename}.asm") || \
                alt_file=$(check_file "${basename}.sh") || \
                alt_file=$(check_file "$basename") || \
                alt_file=""
                echo "$alt_file"
            else
                # No extension, try with extensions
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

# Function to run .asm file - SILENT VERSION (only shows compilation errors and program output)
run_asm() {
    local asm_file="$1"
    local args="$2"
    
    # Determine current architecture
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
            echo "Unsupported architecture: $UNAME_M" >&2
            return 1
            ;;
    esac
    
    # Set up NASM binary path - relative to SCRIPT directory
    NASM_BINARY="${SCRIPT_DIR}/${ARCH}-linux/nasm-${ARCH}-linux"
    
    # Check if NASM binary exists
    if [ ! -f "$NASM_BINARY" ]; then
        echo "NASM binary not found for architecture: $ARCH" >&2
        return 1
    fi
    
    # Make NASM binary executable
    chmod +x "$NASM_BINARY" 2>/dev/null
    
    # Extract base name for output files - use caller directory for output
    BASENAME="$(basename "$asm_file" .asm)"
    OUTPUT_DIR="$CALLER_DIR/.sbasm_tmp_$$"
    OBJECT_FILE="$OUTPUT_DIR/${BASENAME}.o"
    BINARY_FILE="$OUTPUT_DIR/${BASENAME}"
    
    # Clean up previous build and create output directory in caller's directory
    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
    
    # Step 1: Compile with NASM (show errors if any)
    "$NASM_BINARY" -f "$FORMAT" "$asm_file" -o "$OBJECT_FILE" 2>&1
    NASM_EXIT=$?
    
    if [ $NASM_EXIT -ne 0 ]; then
        # Clean up and exit with error
        rm -rf "$OUTPUT_DIR"
        return 1
    fi
    
    # Step 2: Link with LD (show errors if any)
    LD_OUTPUT="$(ld "$OBJECT_FILE" -o "$BINARY_FILE" 2>&1)"
    LD_EXIT=$?
    
    if [ $LD_EXIT -ne 0 ]; then
        echo "$LD_OUTPUT" >&2
        rm -rf "$OUTPUT_DIR"
        return 1
    fi
    
    # Make binary executable
    chmod +x "$BINARY_FILE" 2>/dev/null
    
    # Step 3: Clean up object file
    rm -f "$OBJECT_FILE"
    
    # Step 4: Run the binary in caller's directory
    (cd "$CALLER_DIR" && "$BINARY_FILE" $args)
    PROGRAM_EXIT=$?
    
    # Clean up binary after execution
    rm -rf "$OUTPUT_DIR"
    
    return $PROGRAM_EXIT
}

# Function to run .sh file - SILENT VERSION
run_sh() {
    local sh_file="$1"
    local args="$2"
    
    # Run the shell script in caller's directory
    (cd "$CALLER_DIR" && "$RUNNER_SHELL_PATH" "$sh_file" $args)
    return $?
}

# Function to run binary file - SILENT VERSION
run_binary() {
    local binary_file="$1"
    local args="$2"
    
    # Run the binary in caller's directory
    (cd "$CALLER_DIR" && "$binary_file" $args)
    return $?
}

# Function to run script file - SILENT VERSION
run_script() {
    local script_file="$1"
    local args="$2"
    
    # Run the script in caller's directory
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
        # Detect file type
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
                
                # Find alternative file
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
                    echo "Error: File '$original_file' not found and no fallback available!" >&2
                    exit 1
                fi
                ;;
            unknown)
                # Try to execute in caller's directory
                (cd "$CALLER_DIR" && "$full_path" $PROGRAM_ARGS 2>/dev/null)
                EXIT_CODE=$?
                
                if [ $EXIT_CODE -eq 126 ] || [ $EXIT_CODE -eq 127 ]; then
                    # Find alternative
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

# Run main function
main
