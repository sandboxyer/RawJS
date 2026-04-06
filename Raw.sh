#!/bin/bash

# Raw.sh - Main build script with conditional compilation (silent mode)

# ============================================
# VERBOSITY CONTROL FOR DEV COMPILATION STEP
# ============================================
# Set to "true" to enable compilation error/output (for debugging)
# Set to "false" for complete silent operation (default for production)
# 
# When false: NO output at all from compilation step (not even errors)
# When true: Shows all compilation details including errors
# ============================================
VERBOSE_DEV="${VERBOSE_DEV:-false}"  # Default: completely silent

# ============================================
# GLOBAL EXECUTION PATH CONFIGURATION
# ============================================
# Controls where to look for files to execute
# "dev" - uses ./dev directory (default, contains compiled binaries)
# "source" - uses ./._ directory (contains source files, will be compiled on-demand)
# ============================================
EXECUTION_SOURCE="${EXECUTION_SOURCE:-dev}"  # Default: use compiled binaries from ./dev

# Colors for output (only used when VERBOSE_DEV=true)
if [ "$VERBOSE_DEV" = "true" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

# Silent logging function for dev step
dev_log() {
    if [ "$VERBOSE_DEV" = "true" ]; then
        echo -e "$@"
    fi
}

# Error logging for dev step (only shows if VERBOSE_DEV=true)
dev_error() {
    if [ "$VERBOSE_DEV" = "true" ]; then
        echo -e "$@" >&2
    fi
}

# Function: Get the appropriate basm script path
get_basm_script() {
    local mode="$1"  # normal, silent, log
    
    # Base path for basm scripts
    local basm_base="./dev/basm"
    
    case "$mode" in
        "silent")
            echo "$basm_base/sbasm.sh"
            ;;
        "log")
            echo "$basm_base/logbasm.sh"
            ;;
        "normal"|*)
            echo "$basm_base/basm.sh"
            ;;
    esac
}

# Function: Resolve file path based on EXECUTION_SOURCE
# This is for execution files (scripts, asm, binaries) NOT for the JS file
resolve_file_path() {
    local file_path="$1"
    
    # Remove leading ./ if present
    file_path="${file_path#./}"
    
    case "$EXECUTION_SOURCE" in
        "source")
            # Use ._ directory
            echo "./._/$file_path"
            ;;
        "dev"|*)
            # Use dev directory (default)
            echo "./dev/$file_path"
            ;;
    esac
}

# Function: Execute a file using basm
# Usage: execute_file <mode> <file_path> [additional_args...]
#   mode: normal, silent, log
#   file_path: path relative to dev or ._ directory
execute_file() {
    local mode="$1"
    local file_path="$2"
    shift 2
    local additional_args="$@"
    
    # Get the basm script
    local basm_script=$(get_basm_script "$mode")
    
    # Check if basm script exists
    if [ ! -f "$basm_script" ]; then
        echo -e "${RED}Error: basm script not found at $basm_script${NC}" >&2
        return 1
    fi
    
    # Make sure basm script is executable
    chmod +x "$basm_script" 2>/dev/null
    
    # Resolve the full path to the file
    local full_path=$(resolve_file_path "$file_path")
    
    # Check if file exists
    if [ ! -f "$full_path" ]; then
        echo -e "${RED}Error: File not found at $full_path${NC}" >&2
        return 1
    fi
    
    # Execute with appropriate verbosity
    # In the execute_file function, replace the execution section with:

# Execute with appropriate verbosity
case "$mode" in
    "silent")
        # Silent mode: suppress all output from basm
        if [[ "$full_path" == *.sh ]]; then
            bash "$full_path" $additional_args 2>/dev/null
        else
            "$basm_script" "$full_path" $additional_args 2>/dev/null
        fi
        ;;
    "log")
        # Log mode: show execution output but not compilation logs
        if [[ "$full_path" == *.sh ]]; then
            bash "$full_path" $additional_args
        else
            "$basm_script" "$full_path" $additional_args
        fi
        ;;
    "normal"|*)
        # Normal mode: show all output
        if [[ "$full_path" == *.sh ]]; then
            bash "$full_path" $additional_args
        else
            "$basm_script" "$full_path" $additional_args
        fi
        ;;
esac
    
    return $?
}

# Function: Execute a sequence of files
# Usage: execute_sequence <mode> <file1> [file2] [file3...]
execute_sequence() {
    local mode="$1"
    shift
    local files=("$@")
    local success_count=0
    local fail_count=0
    
    echo -e "${BLUE}Executing sequence in ${mode} mode...${NC}"
    
    for file in "${files[@]}"; do
        echo -e "${YELLOW}Executing: $file${NC}"
        
        if execute_file "$mode" "$file"; then
            echo -e "${GREEN}✓ Successfully executed: $file${NC}"
            ((success_count++))
        else
            echo -e "${RED}✗ Failed to execute: $file${NC}"
            ((fail_count++))
        fi
        echo ""
    done
    
    echo -e "${BLUE}=== Sequence Summary ===${NC}"
    echo -e "${GREEN}Successful: $success_count${NC}"
    echo -e "${RED}Failed: $fail_count${NC}"
    
    return $fail_count
}

# Function: Compile and link all .asm files and copy .sh files to /dev directory
# This only runs if ./dev directory does NOT exist
# COMPLETELY SILENT unless VERBOSE_DEV=true
compile_and_copy() {
    dev_log "${BLUE}Starting compilation and linking of .asm files...${NC}"
    dev_log "${BLUE}Also copying .sh files to /dev directory...${NC}"

    # Determine current architecture
    ARCH=""
    case "$(uname -m)" in
        "x86_64"|"amd64")
            ARCH="x86_64"
            FORMAT="elf64"
            ;;
        "i386"|"i486"|"i586"|"i686")
            ARCH="i386"
            FORMAT="elf32"
            ;;
        "arm"|"armv7l"|"armv8l"|"aarch64"|"arm64")
            ARCH="arm"
            FORMAT="elf32"
            ;;
        *)
            dev_error "${RED}Unsupported architecture: $(uname -m)${NC}"
            return 1
            ;;
    esac

    dev_log "${GREEN}Detected architecture: ${ARCH} (using ${FORMAT} format)${NC}"

    # Set up NASM binary path
    NASM_BINARY="./._/basm/${ARCH}-linux/nasm-${ARCH}-linux"

    # Check if NASM binary exists
    if [ ! -f "$NASM_BINARY" ]; then
        dev_error "${RED}NASM binary not found at: $NASM_BINARY${NC}"
        return 1
    fi

    dev_log "${GREEN}Using NASM binary: $NASM_BINARY${NC}"

    # Make NASM binary executable
    chmod +x "$NASM_BINARY" 2>/dev/null

    # Clean up old /dev directory and create brand new
    dev_log "${BLUE}Cleaning up and creating new /dev directory...${NC}"
    rm -rf "./dev" 2>/dev/null
    mkdir -p "./dev" 2>/dev/null

    # Create directory structure
    dev_log "${BLUE}Creating directory structure...${NC}"
    find "./._" -type d 2>/dev/null | while IFS= read -r dir; do
        # Skip the nasm directory and its contents
        if [[ "$dir" == "./._/nasm"* ]]; then
            continue
        fi
        
        # Create corresponding directory in /dev
        new_dir="${dir/.\/._/.\/dev}"
        mkdir -p "$new_dir" 2>/dev/null
    done

    # Find all .asm files
    dev_log "${BLUE}Finding .asm files...${NC}"
    ASM_FILES=$(find "./._" -name "*.asm" ! -path "./._/nasm/*" 2>/dev/null)
    ASM_COUNT=$(echo "$ASM_FILES" | wc -l)

    # Find all .sh files
    dev_log "${BLUE}Finding .sh files...${NC}"
    SH_FILES=$(find "./._" -name "*.sh" ! -path "./._/nasm/*" 2>/dev/null)
    SH_COUNT=$(echo "$SH_FILES" | wc -l)

    if [ "$ASM_COUNT" -eq 0 ] && [ "$SH_COUNT" -eq 0 ]; then
        dev_error "${RED}No .asm or .sh files found!${NC}"
        return 1
    fi

    dev_log "${YELLOW}Found $ASM_COUNT .asm files and $SH_COUNT .sh files to process${NC}"

    # Now compile and link all .asm files
    if [ "$ASM_COUNT" -gt 0 ]; then
        dev_log "${BLUE}\nCompiling and linking .asm files...${NC}"
    fi

    # Initialize counters
    total_asm_files=0
    compiled_files=0
    failed_files=0

    # Process .asm files
    if [ "$ASM_COUNT" -gt 0 ]; then
        while IFS= read -r asm_file; do
            ((total_asm_files++))
            
            dev_log "\n${YELLOW}[${total_asm_files}] Processing ASM: ${asm_file}${NC}"
            
            # Generate output paths
            output_file="${asm_file/.\/._/.\/dev}"
            output_file="${output_file%.asm}"  # Remove .asm extension
            object_file="${output_file}.o"
            
            # Ensure output directory exists
            mkdir -p "$(dirname "$output_file")" 2>/dev/null
            
            # Step 1: Compile with NASM (completely silent)
            dev_log "  Compiling: $NASM_BINARY -f ${FORMAT} \"${asm_file}\" -o \"${object_file}\""
            "$NASM_BINARY" -f "$FORMAT" "$asm_file" -o "$object_file" 2>/dev/null
            NASM_EXIT=$?
            
            if [ $NASM_EXIT -eq 0 ]; then
                dev_log "  ${GREEN}✓ Compilation successful${NC}"
            else
                # Only show error if VERBOSE_DEV=true
                dev_error "${RED}  ✗ Compilation failed for: ${asm_file}${NC}"
                rm -f "$object_file" 2>/dev/null
                ((failed_files++))
                continue
            fi
            
            # Step 2: Link with LD (completely silent)
            dev_log "  Linking: ld \"${object_file}\" -o \"${output_file}\""
            ld "$object_file" -o "$output_file" 2>/dev/null
            LD_EXIT=$?
            
            if [ $LD_EXIT -eq 0 ]; then
                dev_log "  ${GREEN}✓ Linking successful${NC}"
                chmod +x "$output_file" 2>/dev/null
                ((compiled_files++))
            else
                dev_error "${RED}  ✗ Linking failed for: ${asm_file}${NC}"
                ((failed_files++))
            fi
            
            # Step 3: Clean up object file
            rm -f "$object_file" 2>/dev/null
            dev_log "  ${BLUE}✓ Cleaned up object file${NC}"
            
        done < <(echo "$ASM_FILES")
    fi

    # Now copy all .sh files
    if [ "$SH_COUNT" -gt 0 ]; then
        dev_log "\n${BLUE}Copying .sh files to /dev directory...${NC}"
        
        total_sh_files=0
        copied_sh_files=0
        failed_sh_files=0
        
        while IFS= read -r sh_file; do
            ((total_sh_files++))
            
            dev_log "${YELLOW}[${total_sh_files}] Copying SH: ${sh_file}${NC}"
            
            # Generate output path
            output_file="${sh_file/.\/._/.\/dev}"
            
            # Ensure output directory exists
            mkdir -p "$(dirname "$output_file")" 2>/dev/null
            
            # Copy the .sh file (completely silent)
            dev_log "  Copying: cp \"${sh_file}\" \"${output_file}\""
            cp "$sh_file" "$output_file" 2>/dev/null
            COPY_EXIT=$?
            
            if [ $COPY_EXIT -eq 0 ]; then
                # Make it executable
                chmod +x "$output_file" 2>/dev/null
                dev_log "  ${GREEN}✓ Copy successful${NC}"
                ((copied_sh_files++))
            else
                dev_error "${RED}  ✗ Copy failed for: ${sh_file}${NC}"
                ((failed_sh_files++))
            fi
            
        done < <(echo "$SH_FILES")
    fi

    # Summary (only shown in verbose mode)
    if [ "$VERBOSE_DEV" = "true" ]; then
        echo -e "\n${BLUE}=== Compilation Summary ===${NC}"
        if [ "$ASM_COUNT" -gt 0 ]; then
            echo -e "${GREEN}Successfully compiled and linked: ${compiled_files} .asm files${NC}"
            if [ $failed_files -gt 0 ]; then
                echo -e "${RED}Failed: ${failed_files} .asm files${NC}"
            fi
            echo -e "Total .asm files processed: ${total_asm_files}"
        fi

        if [ "$SH_COUNT" -gt 0 ]; then
            echo -e "\n${BLUE}=== Copy Summary ===${NC}"
            echo -e "${GREEN}Successfully copied: ${copied_sh_files} .sh files${NC}"
            if [ $failed_sh_files -gt 0 ]; then
                echo -e "${RED}Failed: ${failed_sh_files} .sh files${NC}"
            fi
            echo -e "Total .sh files processed: ${SH_COUNT}"
        fi

        echo -e "\n${GREEN}Output directory: ./dev${NC}"

        # Display what's in /dev with tree-like structure
        echo -e "\n${BLUE}=== /dev Directory Structure ===${NC}"
        echo -e "${GREEN}Executable files created:${NC}"

        # Use a simple tree display
        list_files() {
            local indent="$1"
            local dir="$2"
            
            for item in "$dir"/*; do
                if [ -d "$item" ]; then
                    echo -e "${indent}└── $(basename "$item")/"
                    list_files "    $indent" "$item"
                elif [ -f "$item" ]; then
                    if [ -x "$item" ]; then
                        echo -e "${indent}└── ${GREEN}$(basename "$item") ✓${NC}"
                    else
                        echo -e "${indent}└── $(basename "$item")"
                    fi
                fi
            done
        }

        # Start listing from ./dev
        for item in ./dev/*; do
            if [ -d "$item" ]; then
                echo "└── $(basename "$item")/"
                list_files "    " "$item"
            elif [ -f "$item" ]; then
                if [ -x "$item" ]; then
                    echo -e "└── ${GREEN}$(basename "$item") ✓${NC}"
                else
                    echo "└── $(basename "$item")"
                fi
            fi
        done

        # Verify all files were created
        echo -e "\n${BLUE}=== Verification ===${NC}"
        if [ "$ASM_COUNT" -gt 0 ]; then
            echo -e "Expected .asm files: $ASM_COUNT"
        fi
        if [ "$SH_COUNT" -gt 0 ]; then
            echo -e "Expected .sh files: $SH_COUNT"
        fi
        echo -e "Total files created: $(find "./dev" -type f 2>/dev/null | wc -l)"

        expected_total=$((ASM_COUNT + SH_COUNT))
        actual_total=$(find "./dev" -type f 2>/dev/null | wc -l)
        if [ "$expected_total" -eq "$actual_total" ]; then
            echo -e "${GREEN}✓ All files were successfully created!${NC}"
        else
            echo -e "${YELLOW}⚠ Some files might be missing (expected: $expected_total, got: $actual_total)${NC}"
        fi

        echo -e "\n${GREEN}Build completed successfully!${NC}"
        echo -e "All binaries and shell scripts are available in the ./dev directory"
    fi
    
    return 0
}

# ============================================
# EXECUTION STEP FUNCTIONS
# ============================================

# Display usage information (minimalistic)
show_usage() {
    echo -e "${YELLOW}Usage: bash Raw.sh <path/to/file.js> [args...]${NC}"
}

# Process the JavaScript file - just store path and args for later use
# Usage: process_js_file <js_file_path> [js_args...]
process_js_file() {
    local js_file="$1"
    shift
    local js_args="$@"
    
    # Check if JS file exists (in current directory or by absolute/relative path)
    if [ ! -f "$js_file" ]; then
        echo -e "${RED}Error: JS file not found: $js_file${NC}" >&2
        return 1
    fi
    
    # Get absolute path for the JS file
    local abs_js_path=$(realpath "$js_file" 2>/dev/null || echo "$(cd "$(dirname "$js_file")" && pwd)/$(basename "$js_file")")
    
    # Store in global variables for use in execution patterns
    JS_FILE_PATH="$abs_js_path"
    JS_ARGS="$js_args"
    
    return 0
}

# ============================================
# SEQUENCE PATTERNS (Commented Examples)
# ============================================

# Pattern 1: Execute a single file in normal mode
# execute_file "normal" "path/to/your/file.sh"

# Pattern 2: Execute a single file in silent mode
# execute_file "silent" "path/to/your/file.asm"

# Pattern 3: Execute a single file in log mode
# execute_file "log" "path/to/your/binary"

# Pattern 4: Execute multiple files in sequence with same mode
# execute_sequence "normal" "file1.sh" "file2.asm" "file3"

# Pattern 5: Mixed mode execution (using different modes for different files)
# execute_file "silent" "setup.sh"
# execute_file "normal" "main.asm"
# execute_file "log" "processor"

# Pattern 6: Execute with additional arguments
# execute_file "normal" "script.sh" "--verbose" "--output=result.txt"

# Pattern 7: Change execution source temporarily
# EXECUTION_SOURCE="source" execute_file "normal" "script.sh"
# EXECUTION_SOURCE="dev" execute_file "normal" "script.sh"

# Pattern 8: Use JS file path as argument to an executable
# execute_file "normal" "processor" "$JS_FILE_PATH" "$JS_ARGS"

# Pattern 9: Conditional execution based on JS file processing
# if process_js_file "config.js" "some-arg"; then
#     execute_sequence "normal" "success.sh"
# else
#     execute_sequence "normal" "failure.sh"
# fi

# ============================================
# MAIN FLOW
# ============================================

main_flow() {
    # Store JS file path and arguments if provided
    JS_FILE=""
    JS_ARGS=""
    
    # Parse command line arguments
    if [ $# -gt 0 ]; then
        JS_FILE="$1"
        shift
        JS_ARGS="$@"
    fi
    
    # Step 1: Compile and copy only if ./dev doesn't exist
    if [ ! -d "./dev" ]; then
        compile_and_copy
        if [ $? -ne 0 ]; then
            if [ "$VERBOSE_DEV" = "true" ]; then
                echo -e "${RED}Compilation failed! Exiting...${NC}"
            fi
            exit 1
        fi
    fi
    
    # Step 2: Process the JS file if provided
    if [ -n "$JS_FILE" ]; then
        process_js_file "$JS_FILE" $JS_ARGS
        if [ $? -ne 0 ]; then
            exit 1
        fi
        
        # ============================================
        # NOW EXECUTE YOUR FILES USING THE JS PATH
        # ============================================

        OUTPUT_JS="${PWD}/output.js" 
        
        # Example: Execute a processor with the JS file as argument
        #execute_file "normal" "path/to/processor" "$JS_FILE_PATH" "$JS_ARGS"
        execute_file "log" "./._/min/min" "$JS_FILE_PATH" 
        execute_file "log" "./._/min/polish/functions.sh" "$OUTPUT_JS"
        execute_file "log" "./._/min/polish/const.sh" "$OUTPUT_JS"
        execute_file "log" "./._/min/polish/let.sh" "$OUTPUT_JS"
    else
        show_usage
        exit 1
    fi
}

# Execute main flow with all arguments
main_flow "$@"