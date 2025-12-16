#!/bin/sh

# basm.sh - Universal runner for .asm, .sh, and binary files with fallback logic
# Compatible with both bash and ash
# IMPORTANT: All execution happens in the CALLER's directory, not where basm.sh is located

# Colors for output (using echo -e for bash, printf for portability)
if [ -n "$BASH_VERSION" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    NC='\033[0m' # No Color
else
    # ash doesn't support \033 escape sequences in variables the same way
    # We'll use printf directly for ash
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    MAGENTA=''
    NC=''
fi

# Function for colored output compatible with both bash and ash
print_color() {
    local color="$1"
    local message="$2"
    
    if [ -n "$BASH_VERSION" ]; then
        # Using bash with echo -e
        case "$color" in
            red) echo -e "${RED}${message}${NC}" ;;
            green) echo -e "${GREEN}${message}${NC}" ;;
            yellow) echo -e "${YELLOW}${message}${NC}" ;;
            blue) echo -e "${BLUE}${message}${NC}" ;;
            cyan) echo -e "${CYAN}${message}${NC}" ;;
            magenta) echo -e "${MAGENTA}${message}${NC}" ;;
            *) echo "$message" ;;
        esac
    else
        # Using ash with printf
        case "$color" in
            red) printf "\033[0;31m%s\033[0m\n" "$message" ;;
            green) printf "\033[0;32m%s\033[0m\n" "$message" ;;
            yellow) printf "\033[1;33m%s\033[0m\n" "$message" ;;
            blue) printf "\033[0;34m%s\033[0m\n" "$message" ;;
            cyan) printf "\033[0;36m%s\033[0m\n" "$message" ;;
            magenta) printf "\033[0;35m%s\033[0m\n" "$message" ;;
            *) printf "%s\n" "$message" ;;
        esac
    fi
}

print_color "cyan" "basm - Universal Assembly/Bash/Binary Runner"
print_color "yellow" "Run .asm, .sh, or binary files with intelligent fallback"
print_color "blue" "Note: Execution happens in CALLER's directory: $(pwd)"
echo ""

# Save caller's directory - THIS IS THE CRITICAL CHANGE
CALLER_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if input file is provided
if [ $# -lt 1 ]; then
    print_color "red" "Usage: $0 <file> [args...]"
    print_color "yellow" "Supported file types: .asm, .sh, or any executable binary"
    print_color "yellow" "Examples:"
    echo "  $0 hello.asm"
    echo "  $0 script.sh arg1 arg2"
    echo "  $0 myprogram arg1 arg2"
    echo "  $0 file.asm arg1 arg2  # Will fallback to file.sh if .asm not found"
    echo "  $0 program arg1 arg2   # Will fallback to program.asm, then program.sh"
    exit 1
fi

INPUT_FILE="$1"
shift  # Remove the first argument (file name), leaving only args for the binary
PROGRAM_ARGS="$@"

# Determine which shell to use for .sh files based on how this script was invoked
if [ -n "$BASH_VERSION" ]; then
    RUNNER_SHELL="bash"
    RUNNER_SHELL_PATH="$(command -v bash 2>/dev/null || echo "/bin/bash")"
else
    RUNNER_SHELL="sh"
    RUNNER_SHELL_PATH="$(command -v sh 2>/dev/null || echo "/bin/sh")"
fi

print_color "blue" "Using $RUNNER_SHELL for .sh file execution"
print_color "blue" "Caller directory: $CALLER_DIR"
print_color "blue" "Script directory: $SCRIPT_DIR"

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
    
    # Try different locations in order of precedence:
    # 1. In caller directory with same name
    # 2. In caller directory with different extensions
    # 3. In script directory
    # 4. In PATH
    
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

# Function to run .asm file
run_asm() {
    local asm_file="$1"
    local args="$2"
    
    print_color "blue" "Running Assembly file: $asm_file"
    print_color "blue" "Execution directory: $CALLER_DIR"
    
    # Determine current architecture
    ARCH=""
    FORMAT=""
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
            print_color "red" "Unsupported architecture: $UNAME_M"
            return 1
            ;;
    esac
    
    print_color "green" "Detected architecture: $ARCH (using $FORMAT format)"
    
    # Set up NASM binary path - relative to SCRIPT directory
    NASM_BINARY="${SCRIPT_DIR}/${ARCH}-linux/nasm-${ARCH}-linux"
    
    # Check if NASM binary exists
    if [ ! -f "$NASM_BINARY" ]; then
        print_color "red" "NASM binary not found at: $NASM_BINARY"
        print_color "yellow" "Expected path: $NASM_BINARY"
        print_color "yellow" "Available architectures:"
        for dir in "${SCRIPT_DIR}"/*-linux; do
            if [ -d "$dir" ]; then
                arch_name="$(basename "$dir")"
                echo "  - $arch_name"
            fi
        done
        return 1
    fi
    
    print_color "green" "Using NASM binary: $NASM_BINARY"
    
    # Make NASM binary executable
    chmod +x "$NASM_BINARY" 2>/dev/null || print_color "yellow" "Note: Could not modify NASM permissions"
    
    # Extract base name for output files - use caller directory for output
    BASENAME="$(basename "$asm_file" .asm)"
    OUTPUT_DIR="$CALLER_DIR/.basm_tmp_$$"
    OBJECT_FILE="$OUTPUT_DIR/${BASENAME}.o"
    BINARY_FILE="$OUTPUT_DIR/${BASENAME}"
    
    # Clean up previous build and create output directory in caller's directory
    print_color "blue" "Preparing build environment in: $OUTPUT_DIR"
    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
    
    # Step 1: Compile with NASM
    print_color "blue" "Step 1: Compiling $asm_file..."
    print_color "yellow" "Command: $NASM_BINARY -f $FORMAT \"$asm_file\" -o \"$OBJECT_FILE\""
    
    "$NASM_BINARY" -f "$FORMAT" "$asm_file" -o "$OBJECT_FILE"
    NASM_EXIT=$?
    
    if [ $NASM_EXIT -ne 0 ]; then
        print_color "red" "✗ Compilation failed!"
        print_color "yellow" "Exit code: $NASM_EXIT"
        rm -rf "$OUTPUT_DIR"
        return 1
    fi
    
    print_color "green" "✓ Compilation successful"
    
    # Step 2: Link with LD
    print_color "blue" "Step 2: Linking object file..."
    print_color "yellow" "Command: ld \"$OBJECT_FILE\" -o \"$BINARY_FILE\""
    
    # Capture ld output
    LD_OUTPUT="$(ld "$OBJECT_FILE" -o "$BINARY_FILE" 2>&1)"
    LD_EXIT=$?
    
    if [ $LD_EXIT -ne 0 ]; then
        print_color "red" "✗ Linking failed!"
        print_color "yellow" "Exit code: $LD_EXIT"
        print_color "yellow" "Linking output:"
        echo "$LD_OUTPUT"
        rm -rf "$OUTPUT_DIR"
        return 1
    fi
    
    print_color "green" "✓ Linking successful"
    
    # Make binary executable
    chmod +x "$BINARY_FILE" 2>/dev/null || print_color "yellow" "Note: Could not make binary executable"
    
    # Step 3: Clean up object file
    rm -f "$OBJECT_FILE"
    print_color "green" "✓ Cleaned up intermediate files"
    
    # Step 4: Run the binary in caller's directory
    print_color "blue" "Step 3: Running $BASENAME..."
    print_color "yellow" "Binary: $BINARY_FILE"
    print_color "yellow" "Running in directory: $CALLER_DIR"
    
    if [ -n "$args" ]; then
        print_color "yellow" "Arguments: $args"
    fi
    
    print_color "blue" "========== PROGRAM OUTPUT =========="
    
    # Run the binary in caller's directory with any provided arguments
    (cd "$CALLER_DIR" && "$BINARY_FILE" $args)
    PROGRAM_EXIT=$?
    
    print_color "blue" "===================================="
    print_color "yellow" "Program exited with code: $PROGRAM_EXIT"
    
    # Optional: Clean up binary after execution
    print_color "blue" "Cleaning up temporary files..."
    rm -rf "$OUTPUT_DIR"
    print_color "green" "✓ Cleanup complete"
    
    return $PROGRAM_EXIT
}

# Function to run .sh file
run_sh() {
    local sh_file="$1"
    local args="$2"
    
    print_color "blue" "Running shell script: $sh_file"
    print_color "yellow" "Using shell: $RUNNER_SHELL"
    print_color "blue" "Execution directory: $CALLER_DIR"
    
    if [ -n "$args" ]; then
        print_color "yellow" "Arguments: $args"
    fi
    
    print_color "blue" "========== SCRIPT OUTPUT =========="
    
    # Run the shell script in caller's directory
    (cd "$CALLER_DIR" && "$RUNNER_SHELL_PATH" "$sh_file" $args)
    SCRIPT_EXIT=$?
    
    print_color "blue" "==================================="
    print_color "yellow" "Script exited with code: $SCRIPT_EXIT"
    
    return $SCRIPT_EXIT
}

# Function to run binary file
run_binary() {
    local binary_file="$1"
    local args="$2"
    
    print_color "blue" "Running binary: $binary_file"
    print_color "blue" "Execution directory: $CALLER_DIR"
    
    if [ -n "$args" ]; then
        print_color "yellow" "Arguments: $args"
    fi
    
    print_color "blue" "========== PROGRAM OUTPUT =========="
    
    # Run the binary in caller's directory
    (cd "$CALLER_DIR" && "$binary_file" $args)
    BINARY_EXIT=$?
    
    print_color "blue" "===================================="
    print_color "yellow" "Program exited with code: $BINARY_EXIT"
    
    return $BINARY_EXIT
}

# Function to run script file
run_script() {
    local script_file="$1"
    local args="$2"
    
    print_color "blue" "Running script: $script_file"
    print_color "blue" "Execution directory: $CALLER_DIR"
    
    if [ -n "$args" ]; then
        print_color "yellow" "Arguments: $args"
    fi
    
    print_color "blue" "========== SCRIPT OUTPUT =========="
    
    # Run the script in caller's directory
    (cd "$CALLER_DIR" && "$script_file" $args)
    SCRIPT_EXIT=$?
    
    print_color "blue" "==================================="
    print_color "yellow" "Script exited with code: $SCRIPT_EXIT"
    
    return $SCRIPT_EXIT
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
                print_color "green" "Found Assembly file: $full_path"
                run_asm "$full_path" "$PROGRAM_ARGS"
                return $?
                ;;
            sh)
                print_color "green" "Found shell script: $full_path"
                run_sh "$full_path" "$PROGRAM_ARGS"
                return $?
                ;;
            binary)
                print_color "green" "Found binary file: $full_path"
                run_binary "$full_path" "$PROGRAM_ARGS"
                return $?
                ;;
            script)
                print_color "green" "Found script file: $full_path"
                run_script "$full_path" "$PROGRAM_ARGS"
                return $?
                ;;
            not_found)
                if [ $fallback_count -eq 0 ]; then
                    print_color "yellow" "File '$current_file' not found, attempting fallback..."
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
                    print_color "yellow" "Fallback to: $alternative_file"
                    current_file="$alternative_file"
                    continue
                else
                    print_color "red" "Error: File '$original_file' not found and no fallback available!"
                    print_color "yellow" "Searched in:"
                    print_color "yellow" "  1. Caller directory: $CALLER_DIR"
                    print_color "yellow" "  2. Script directory: $SCRIPT_DIR"
                    print_color "yellow" "  3. Current directory"
                    
                    # Show what was tried
                    print_color "yellow" "Tried file paths:"
                    print_color "yellow" "  1. $original_file"
                    
                    if [ -n "$alternative_file" ] && [ "$alternative_file" != "$original_file" ]; then
                        print_color "yellow" "  2. $alternative_file"
                    fi
                    
                    exit 1
                fi
                ;;
            unknown)
                print_color "yellow" "Unknown file type for: $full_path"
                print_color "yellow" "Attempting to execute anyway..."
                
                print_color "blue" "========== OUTPUT =========="
                
                # Try to execute in caller's directory
                (cd "$CALLER_DIR" && "$full_path" $PROGRAM_ARGS 2>/dev/null)
                EXIT_CODE=$?
                
                if [ $EXIT_CODE -eq 126 ] || [ $EXIT_CODE -eq 127 ]; then
                    print_color "red" "Execution failed (exit code: $EXIT_CODE)"
                    print_color "yellow" "Trying fallback..."
                    
                    # Find alternative
                    local alternative_file=$(find_alternative "$current_file" "unknown")
                    if [ -n "$alternative_file" ] && [ "$alternative_file" != "$current_file" ]; then
                        print_color "yellow" "Fallback to: $alternative_file"
                        current_file="$alternative_file"
                        continue
                    else
                        print_color "red" "No fallback available. Cannot execute: $full_path"
                        exit 1
                    fi
                else
                    print_color "blue" "==================================="
                    print_color "yellow" "Program exited with code: $EXIT_CODE"
                    return $EXIT_CODE
                fi
                ;;
        esac
    done
}

# Run main function
main
