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

# Function: Your next step (add your logic here)
# You can control verbosity independently for this function
# myotherstep() {
    # You can use your own verbosity control here
    # Example: 
    # if [ "$VERBOSE_MYSTEP" = "true" ]; then
    #     echo "Executing myotherstep..."
    # fi
    
    # Or just use regular echo (will show in normal output)

    
    # Add your other step logic here
    

# }

# Main flow
main_flow() {
    # Step 1: Compile and copy only if ./dev doesn't exist (COMPLETELY SILENT)
    if [ ! -d "./dev" ]; then
        compile_and_copy
        if [ $? -ne 0 ]; then
            # Only show error if VERBOSE_DEV=true
            if [ "$VERBOSE_DEV" = "true" ]; then
                echo -e "${RED}Compilation failed! Exiting...${NC}"
            fi
            exit 1
        fi
    fi
    
    # Step 2: Run your next step (output will show normally)
    # myotherstep
}

# Execute main flow
main_flow