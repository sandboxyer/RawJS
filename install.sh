#!/bin/bash

# =============================================================================
# BASM INSTALLATION SCRIPT
# =============================================================================

# PROJECT INFO
PROJECT_NAME="basm-tool"
PROJECT_DESCRIPTION="Universal Assembly/Bash/Binary Runner with fallback logic"

# INSTALLATION PATHS
INSTALL_DIR="/usr/local/etc/$PROJECT_NAME"
BIN_DIR="/usr/local/bin"

# SOURCE PATHS
REPO_DIR=$(pwd)
MAIN_SOURCE_DIR="$REPO_DIR/._/basm"  # Changed to ._/basm

# LOGGING
LOG_FILE="/var/log/${PROJECT_NAME}-install.log"
LOG_MODE=false
BACKUP_DIR="/usr/local/etc/${PROJECT_NAME}_old_$(date +%s)"

# =============================================================================
# FUNCTION DEFINITIONS
# =============================================================================

show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo "Install $PROJECT_NAME - $PROJECT_DESCRIPTION"
  echo
  echo "Options:"
  echo "  -h, --help       Show this help"
  echo "  -log             Enable installation logging"
  echo
  echo "This will install:"
  echo "  • BASM directory to $INSTALL_DIR"
  echo "  • Global 'basm' command"
  echo
  echo "The 'basm' command will:"
  echo "  • Run from the caller's current directory"
  echo "  • Execute basm.sh with provided arguments"
  echo "  • Intelligently handle .asm, .sh, and binary files with fallback logic"
  echo
  echo "File type detection and fallback order:"
  echo "  1. .asm files → compile and run with NASM"
  echo "  2. .sh files → execute with bash/sh"
  echo "  3. Binary files → execute directly"
  echo "  4. Fallback: file.asm → file.sh → file"
  exit 0
}

log_message() {
  local message="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  if [[ "$LOG_MODE" == true ]]; then
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
  else
    echo "[$timestamp] $message"
  fi
}

show_progress() {
  local message="$1"
  local pid="$2"
  
  while kill -0 $pid 2>/dev/null; do
    echo -ne "$message (press 'x' to skip)\r"
    read -t 1 -n 1 -s input || true
    if [[ $input == "x" ]]; then
      echo -e "\nSkipping step..."
      kill $pid 2>/dev/null
      break
    fi
  done
  wait $pid 2>/dev/null
  echo -e "\n$message completed."
}

copy_files() {
  local src_dir="$1"
  local dest_dir="$2"

  mkdir -p "$dest_dir"
  log_message "Copying files to $dest_dir..."

  if [[ "$LOG_MODE" == true ]]; then
    rsync -a --info=progress2 --exclude=".git" "$src_dir/" "$dest_dir" 2>&1 | tee -a "$LOG_FILE" &
  else
    rsync -a --info=progress2 --exclude=".git" "$src_dir/" "$dest_dir" > /dev/null 2>&1 &
  fi

  show_progress "Copying files" $!
  return $?
}

create_basm_wrapper() {
  local install_dir="$1"
  local wrapper_path="$install_dir/wrappers/basm"
  
  log_message "Creating basm wrapper..."
  
  mkdir -p "$(dirname "$wrapper_path")"
  
  # Create wrapper that runs from caller's directory
  cat > "$wrapper_path" << 'WRAPPER_EOF'
#!/bin/bash

# Get the caller's current working directory
CALLER_DIR="$(pwd)"
INSTALL_DIR="/usr/local/etc/basm-tool"

# Navigate to the caller's directory to work with their files
cd "$CALLER_DIR" || {
  echo "Error: Cannot navigate to directory: $CALLER_DIR" >&2
  exit 1
}

# Execute basm.sh from the installation directory with all arguments
exec bash "$INSTALL_DIR/basm.sh" "$@"
WRAPPER_EOF
  
  chmod +x "$wrapper_path"
  
  # Create symlink in bin directory
  local dest_path="$BIN_DIR/basm"
  [[ -L "$dest_path" ]] && rm -f "$dest_path"
  ln -sf "$wrapper_path" "$dest_path"
  
  log_message "Created 'basm' command symlink"
}

verify_basm_structure() {
  local install_dir="$1"
  
  log_message "Verifying BASM installation structure..."
  
  # Check essential files
  local required_files=(
    "$install_dir/basm.sh"
  )
  
  local optional_files=(
    "$install_dir/output.js"
    "$install_dir/test.js"
  )
  
  for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
      echo "✓ Found required file: $(basename "$file")"
      chmod +x "$file" 2>/dev/null || true
    else
      echo "✗ Error: Missing required file: $(basename "$file")"
      return 1
    fi
  done
  
  for file in "${optional_files[@]}"; do
    if [[ -f "$file" ]]; then
      echo "✓ Found optional file: $(basename "$file")"
    else
      echo "  Note: Optional file not found: $(basename "$file")"
    fi
  done
  
  # Check architecture binaries (NASM binaries for .asm support)
  local arch_dirs=(
    "arm-linux"
    "i386-linux" 
    "x86_64-linux"
  )
  
  local has_any_arch=false
  for arch_dir in "${arch_dirs[@]}"; do
    if [[ -d "$install_dir/$arch_dir" ]]; then
      echo "✓ Found NASM architecture: $arch_dir"
      has_any_arch=true
      
      # Check for nasm binary
      local nasm_binary="$install_dir/$arch_dir/nasm-$arch_dir-linux"
      if [[ -f "$nasm_binary" ]]; then
        echo "  ✓ NASM binary found"
        chmod +x "$nasm_binary" 2>/dev/null || true
      else
        echo "  ⚠ NASM binary not found (but directory exists)"
      fi
    else
      echo "  Note: NASM architecture directory not found: $arch_dir"
    fi
  done
  
  if [[ "$has_any_arch" == false ]]; then
    echo "⚠ Warning: No NASM architecture directories found"
    echo "  .asm file compilation will not be available"
  fi
  
  # Check for ld (linker)
  if command -v ld >/dev/null 2>&1; then
    echo "✓ System linker (ld) found"
  else
    echo "⚠ Warning: System linker (ld) not found"
    echo "  .asm file linking will fail"
  fi
  
  return 0
}

remove_installation() {
  log_message "Removing existing installation..."
  
  # Remove symlink
  local symlink_path="$BIN_DIR/basm"
  if [[ -L "$symlink_path" ]]; then
    rm -f "$symlink_path"
    log_message "Removed symlink: $symlink_path"
  fi
  
  # Remove installation directory
  if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    log_message "Removed installation directory: $INSTALL_DIR"
  fi
}

cleanup() {
  # Remove backup directory if it exists
  if [[ -d "$BACKUP_DIR" ]]; then
    rm -rf "$BACKUP_DIR" 2>/dev/null || true
  fi
}

interrupt_handler() {
  log_message "Installation interrupted. Cleaning up..."
  cleanup
  exit 1
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

trap interrupt_handler INT TERM

# Parse command line arguments
for arg in "$@"; do
  case "$arg" in
    -h|--help) show_help ;;
    -log) LOG_MODE=true; touch "$LOG_FILE" ;;
  esac
done

log_message "Starting $PROJECT_NAME installation..."

# Check if source directory exists
if [[ ! -d "$MAIN_SOURCE_DIR" ]]; then
  echo "Error: BASM directory not found at: $MAIN_SOURCE_DIR" >&2
  echo "Make sure you're running this script from the correct directory." >&2
  echo "Current directory: $REPO_DIR" >&2
  echo "Expected to find: $MAIN_SOURCE_DIR" >&2
  echo "Available directories in current path:" >&2
  ls -la "$REPO_DIR/._/" 2>/dev/null | grep -E "(basm|nasm)" >&2 || echo "  (none in ._/)" >&2
  echo "All directories in ._/:" >&2
  ls -la "$REPO_DIR/._/" 2>/dev/null || echo "  (._/ not found)" >&2
  exit 1
fi

# Handle existing installation
if [[ -d "$INSTALL_DIR" ]]; then
  log_message "Existing installation found at: $INSTALL_DIR"
  echo "Choose an option:"
  echo "  1 = Update (keep existing files)"
  echo "  2 = Remove (uninstall completely)"
  echo "  3 = Exit"
  read -p "Enter your choice [1-3]: " choice
  
  case "$choice" in
    1) 
      # Backup existing installation
      log_message "Backing up existing installation..."
      mv -f "$INSTALL_DIR" "$BACKUP_DIR"
      ;;
    2) 
      remove_installation
      echo "Uninstallation completed."
      exit 0
      ;;
    3) 
      echo "Exiting."
      exit 0
      ;;
    *) 
      echo "Invalid choice. Exiting."
      exit 1
      ;;
  esac
fi

# Create installation directory
log_message "Creating installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Copy all files from basm directory
copy_files "$MAIN_SOURCE_DIR" "$INSTALL_DIR"

# Verify installation structure
if ! verify_basm_structure "$INSTALL_DIR"; then
  echo "Warning: Some components missing, but installation will continue"
fi

# Create the basm command wrapper
create_basm_wrapper "$INSTALL_DIR"

# Cleanup backup if it exists
cleanup

log_message "$PROJECT_NAME installation completed!"

echo
echo "=========================================="
echo "BASM INSTALLATION SUCCESSFUL"
echo "=========================================="
echo
echo "Installation directory: $INSTALL_DIR"
echo "Command symlink: $BIN_DIR/basm"
echo
echo "The 'basm' command is now available globally."
echo
echo "BASM Features:"
echo "  • Universal runner for .asm, .sh, and binary files"
echo "  • Intelligent fallback logic"
echo "  • Architecture detection for .asm compilation"
echo "  • Compatible with bash and ash/sh"
echo
echo "Usage examples:"
echo "  basm hello.asm                    # Compile and run .asm file"
echo "  basm script.sh arg1 arg2          # Run shell script"
echo "  basm mybinary arg1 arg2           # Run binary executable"
echo "  basm program                      # Auto-detect program.asm/program.sh/program"
echo "  basm file.asm arg1 arg2           # Will fallback to file.sh if .asm not found"
echo
echo "Fallback logic (when file not found):"
echo "  1. file.asm → file.sh → file"
echo "  2. file.sh → file.asm → file"
echo "  3. file → file.asm → file.sh"
echo
echo "To uninstall, run this script again and choose option 2."
echo "=========================================="
