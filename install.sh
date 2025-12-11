#!/bin/bash

# =============================================================================
# NASM INSTALLATION SCRIPT
# =============================================================================

# PROJECT INFO
PROJECT_NAME="nasm-tool"
PROJECT_DESCRIPTION="NASM assembler with bundled binaries"

# INSTALLATION PATHS
INSTALL_DIR="/usr/local/etc/$PROJECT_NAME"
BIN_DIR="/usr/local/bin"

# SOURCE PATHS
REPO_DIR=$(pwd)
MAIN_SOURCE_DIR="$REPO_DIR/._/nasm"  # Fixed path to match your directory structure

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
  echo "  • NASM directory to $INSTALL_DIR"
  echo "  • Global 'nasm' command"
  echo
  echo "The 'nasm' command will:"
  echo "  • Run from the caller's current directory"
  echo "  • Execute nasm.sh with provided arguments"
  echo "  • Pass .asm files and other arguments to the assembler"
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

create_nasm_wrapper() {
  local install_dir="$1"
  local wrapper_path="$install_dir/wrappers/nasm"
  
  log_message "Creating nasm wrapper..."
  
  mkdir -p "$(dirname "$wrapper_path")"
  
  # Create wrapper that runs from caller's directory
  cat > "$wrapper_path" << 'WRAPPER_EOF'
#!/bin/bash

# Get the caller's current working directory
CALLER_DIR="$(pwd)"
INSTALL_DIR="/usr/local/etc/nasm-tool"

# Navigate to the caller's directory to work with their files
cd "$CALLER_DIR" || {
  echo "Error: Cannot navigate to directory: $CALLER_DIR" >&2
  exit 1
}

# Execute nasm.sh from the installation directory with all arguments
exec bash "$INSTALL_DIR/nasm.sh" "$@"
WRAPPER_EOF
  
  chmod +x "$wrapper_path"
  
  # Create symlink in bin directory
  local dest_path="$BIN_DIR/nasm"
  [[ -L "$dest_path" ]] && rm -f "$dest_path"
  ln -sf "$wrapper_path" "$dest_path"
  
  log_message "Created 'nasm' command symlink"
}

verify_nasm_structure() {
  local install_dir="$1"
  
  log_message "Verifying NASM installation structure..."
  
  # Check essential files
  local required_files=(
    "$install_dir/nasm.sh"
    "$install_dir/output.js"
    "$install_dir/test.js"
  )
  
  for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      echo "Warning: Missing file: $(basename "$file")"
    fi
  done
  
  # Check architecture binaries
  local arch_dirs=(
    "arm-linux"
    "i386-linux" 
    "x86_64-linux"
  )
  
  for arch_dir in "${arch_dirs[@]}"; do
    if [[ -d "$install_dir/$arch_dir" ]]; then
      echo "✓ Found architecture: $arch_dir"
    else
      echo "Warning: Missing architecture directory: $arch_dir"
    fi
  done
  
  # Make nasm.sh executable
  chmod +x "$install_dir/nasm.sh" 2>/dev/null || true
}

remove_installation() {
  log_message "Removing existing installation..."
  
  # Remove symlink
  local symlink_path="$BIN_DIR/nasm"
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
  echo "Error: NASM directory not found at: $MAIN_SOURCE_DIR" >&2
  echo "Make sure you're running this script from the correct directory." >&2
  echo "Current directory: $REPO_DIR" >&2
  echo "Expected to find: $MAIN_SOURCE_DIR" >&2
  echo "Available directories in current path:" >&2
  ls -la "$REPO_DIR" 2>/dev/null | grep -E "(_|nasm)" >&2 || echo "  (none)" >&2
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

# Copy NASM files
copy_files "$MAIN_SOURCE_DIR" "$INSTALL_DIR"

# Verify installation structure
verify_nasm_structure "$INSTALL_DIR"

# Create the nasm command wrapper
create_nasm_wrapper "$INSTALL_DIR"

# Cleanup backup if it exists
cleanup

log_message "$PROJECT_NAME installation completed!"

echo
echo "=========================================="
echo "INSTALLATION SUCCESSFUL"
echo "=========================================="
echo
echo "Installation directory: $INSTALL_DIR"
echo "Command symlink: $BIN_DIR/nasm"
echo
echo "The 'nasm' command is now available globally."
echo
echo "Usage examples:"
echo "  nasm -f elf64 myfile.asm"
echo "  nasm -f bin -o boot.bin boot.asm"
echo "  nasm -h (for help)"
echo
echo "The command will:"
echo "  • Run from your current working directory"
echo "  • Execute the NASM assembler with your arguments"
echo "  • Process .asm files in your current directory"
echo
echo "To uninstall, run this script again and choose option 2."
echo "=========================================="