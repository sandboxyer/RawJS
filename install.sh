#!/bin/bash

# =============================================================================
# RAWJS & BASM INSTALLATION SCRIPT
# =============================================================================

# PROJECT INFO
RAWJS_NAME="rawjs-runtime"
RAWJS_DESCRIPTION="RawJS JavaScript Runtime Environment"
BASM_NAME="basm-tool"
BASM_DESCRIPTION="Universal Assembly/Bash/Binary Runner with fallback logic"

# INSTALLATION PATHS
INSTALL_DIR="/usr/local/etc/rawjs-runtime"
BIN_DIR="/usr/local/bin"

# SOURCE PATHS
REPO_DIR=$(pwd)
RAWJS_SOURCE_DIR="$REPO_DIR"  # Main level for Raw.sh
BASM_SOURCE_DIR="$REPO_DIR/._/basm"  # BASM in ._/basm

# LOGGING
LOG_FILE="/var/log/rawjs-install.log"
LOG_MODE=false
BACKUP_DIR="/usr/local/etc/rawjs-runtime_old_$(date +%s)"

# =============================================================================
# FUNCTION DEFINITIONS
# =============================================================================

show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo "Install RawJS Runtime and BASM - JavaScript Runtime + Universal Runner"
  echo
  echo "Options:"
  echo "  -h, --help       Show this help"
  echo "  -log             Enable installation logging"
  echo
  echo "This will install:"
  echo "  • RawJS runtime to $INSTALL_DIR"
  echo "  • BASM tools to $INSTALL_DIR/._basm"
  echo "  • Global 'raw' command (RawJS JavaScript runtime)"
  echo "  • Global 'basm' command (Universal file runner)"
  echo
  echo "RAWJS COMMAND:"
  echo "  • Run from the caller's current directory"
  echo "  • Execute Raw.sh with provided arguments"
  echo "  • JavaScript runtime environment"
  echo
  echo "BASM COMMAND:"
  echo "  • Run from the caller's current directory"
  echo "  • Execute basm.sh with provided arguments"
  echo "  • Intelligently handle .asm, .sh, and binary files with fallback logic"
  echo
  echo "File type detection and fallback order (BASM):"
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
  local description="$3"

  mkdir -p "$dest_dir"
  log_message "Copying $description files to $dest_dir..."

  if [[ "$LOG_MODE" == true ]]; then
    rsync -a --info=progress2 --exclude=".git" "$src_dir/" "$dest_dir" 2>&1 | tee -a "$LOG_FILE" &
  else
    rsync -a --info=progress2 --exclude=".git" "$src_dir/" "$dest_dir" > /dev/null 2>&1 &
  fi

  show_progress "Copying $description files" $!
  return $?
}

create_raw_wrapper() {
  local install_dir="$1"
  local wrapper_path="$install_dir/wrappers/raw"
  
  log_message "Creating RawJS wrapper..."
  
  mkdir -p "$(dirname "$wrapper_path")"
  
  # Create wrapper that runs from caller's directory with proper path handling
  cat > "$wrapper_path" << 'WRAPPER_EOF'
#!/bin/bash

# Get the caller's current working directory
CALLER_DIR="$(pwd)"
INSTALL_DIR="/usr/local/etc/rawjs-runtime"

# Process arguments to convert relative paths to absolute paths
args=()
for arg in "$@"; do
  # Check if argument is a file that exists (or might exist) in the caller's directory
  if [[ -f "$CALLER_DIR/$arg" ]] || [[ "$arg" != -* && ! "$arg" =~ ^/ ]]; then
    # Convert to absolute path if it's not a flag and not already absolute
    args+=("$CALLER_DIR/$arg")
  else
    # Pass through flags and absolute paths unchanged
    args+=("$arg")
  fi
done

# Navigate to the caller's directory to maintain context
cd "$CALLER_DIR" || {
  echo "Error: Cannot navigate to directory: $CALLER_DIR" >&2
  exit 1
}

# Execute Raw.sh from the installation directory with processed arguments
exec bash "$INSTALL_DIR/Raw.sh" "${args[@]}"
WRAPPER_EOF
  
  chmod +x "$wrapper_path"
  
  # Create symlink in bin directory
  local dest_path="$BIN_DIR/raw"
  [[ -L "$dest_path" ]] && rm -f "$dest_path"
  ln -sf "$wrapper_path" "$dest_path"
  
  log_message "Created 'raw' command symlink"
}

create_basm_wrapper() {
  local install_dir="$1"
  local wrapper_path="$install_dir/wrappers/basm"
  
  log_message "Creating BASM wrapper..."
  
  mkdir -p "$(dirname "$wrapper_path")"
  
  # Create wrapper that runs from caller's directory
  cat > "$wrapper_path" << 'WRAPPER_EOF'
#!/bin/bash

# Get the caller's current working directory
CALLER_DIR="$(pwd)"
INSTALL_DIR="/usr/local/etc/rawjs-runtime"

# Navigate to the caller's directory to work with their files
cd "$CALLER_DIR" || {
  echo "Error: Cannot navigate to directory: $CALLER_DIR" >&2
  exit 1
}

# Execute basm.sh from the BASM installation subdirectory with all arguments
exec bash "$INSTALL_DIR/._basm/basm.sh" "$@"
WRAPPER_EOF
  
  chmod +x "$wrapper_path"
  
  # Create symlink in bin directory
  local dest_path="$BIN_DIR/basm"
  [[ -L "$dest_path" ]] && rm -f "$dest_path"
  ln -sf "$wrapper_path" "$dest_path"
  
  log_message "Created 'basm' command symlink"
}

verify_rawjs_structure() {
  local install_dir="$1"
  
  log_message "Verifying RawJS installation structure..."
  
  # Check essential files
  local required_files=(
    "$install_dir/Raw.sh"
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
  
  # Check for JavaScript files
  local js_files=(
    "$install_dir/output.js"
    "$install_dir/test.js"
  )
  
  for file in "${js_files[@]}"; do
    if [[ -f "$file" ]]; then
      echo "✓ Found JavaScript file: $(basename "$file")"
    else
      echo "  Note: JavaScript file not found: $(basename "$file")"
    fi
  done
  
  return 0
}

verify_basm_structure() {
  local install_dir="$1"
  
  log_message "Verifying BASM installation structure..."
  
  # Check essential files
  local required_files=(
    "$install_dir/._basm/basm.sh"
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
  
  # Check architecture binaries (NASM binaries for .asm support)
  local arch_dirs=(
    "$install_dir/._basm/arm-linux"
    "$install_dir/._basm/i386-linux" 
    "$install_dir/._basm/x86_64-linux"
  )
  
  local has_any_arch=false
  for arch_dir in "${arch_dirs[@]}"; do
    if [[ -d "$arch_dir" ]]; then
      echo "✓ Found NASM architecture: $(basename "$arch_dir")"
      has_any_arch=true
      
      # Check for nasm binary
      local nasm_binary="$arch_dir/nasm-$(basename "$arch_dir")-linux"
      if [[ -f "$nasm_binary" ]]; then
        echo "  ✓ NASM binary found"
        chmod +x "$nasm_binary" 2>/dev/null || true
      else
        echo "  ⚠ NASM binary not found (but directory exists)"
      fi
    else
      echo "  Note: NASM architecture directory not found: $(basename "$arch_dir")"
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
  
  # Remove symlinks
  local raw_symlink="$BIN_DIR/raw"
  if [[ -L "$raw_symlink" ]]; then
    rm -f "$raw_symlink"
    log_message "Removed symlink: $raw_symlink"
  fi
  
  local basm_symlink="$BIN_DIR/basm"
  if [[ -L "$basm_symlink" ]]; then
    rm -f "$basm_symlink"
    log_message "Removed symlink: $basm_symlink"
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

log_message "Starting RawJS and BASM installation..."

# Check if Raw.sh exists at main level
if [[ ! -f "$RAWJS_SOURCE_DIR/Raw.sh" ]]; then
  echo "Error: Raw.sh not found at: $RAWJS_SOURCE_DIR/Raw.sh" >&2
  echo "Make sure you're running this script from the correct directory." >&2
  echo "Current directory: $REPO_DIR" >&2
  echo "Expected to find: Raw.sh" >&2
  echo "Files in current directory:" >&2
  ls -la "$REPO_DIR/" | grep -E "\.sh$" >&2 || echo "  (no .sh files found)" >&2
  exit 1
fi

# Check if BASM source directory exists
if [[ ! -d "$BASM_SOURCE_DIR" ]]; then
  echo "Warning: BASM directory not found at: $BASM_SOURCE_DIR" >&2
  echo "BASM will not be installed, but RawJS will continue." >&2
  INSTALL_BASM=false
else
  INSTALL_BASM=true
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

# Copy RawJS files from main directory
copy_files "$RAWJS_SOURCE_DIR" "$INSTALL_DIR" "RawJS"

# Verify RawJS installation structure
if ! verify_rawjs_structure "$INSTALL_DIR"; then
  echo "Error: RawJS installation verification failed"
  exit 1
fi

# Copy BASM files if they exist
if [[ "$INSTALL_BASM" == true ]]; then
  log_message "Installing BASM tools..."
  mkdir -p "$INSTALL_DIR/._basm"
  copy_files "$BASM_SOURCE_DIR" "$INSTALL_DIR/._basm" "BASM"
  
  # Verify BASM installation structure
  if ! verify_basm_structure "$INSTALL_DIR"; then
    echo "Warning: BASM installation verification failed"
    echo "BASM will not be fully functional"
  fi
else
  log_message "Skipping BASM installation (source not found)"
fi

# Create the raw command wrapper
create_raw_wrapper "$INSTALL_DIR"

# Create the basm command wrapper if BASM was installed
if [[ "$INSTALL_BASM" == true ]]; then
  create_basm_wrapper "$INSTALL_DIR"
fi

# Cleanup backup if it exists
cleanup

log_message "RawJS and BASM installation completed!"

echo
echo "=========================================="
echo "RAWJS & BASM INSTALLATION SUCCESSFUL"
echo "=========================================="
echo
echo "Installation directory: $INSTALL_DIR"
echo "Command symlinks:"
echo "  • $BIN_DIR/raw (RawJS JavaScript Runtime)"
if [[ "$INSTALL_BASM" == true ]]; then
  echo "  • $BIN_DIR/basm (BASM Universal Runner)"
fi
echo
echo "RAWJS COMMAND:"
echo "  • JavaScript runtime environment"
echo "  • Execute JavaScript files and scripts"
echo
echo "BASM COMMAND:"
echo "  • Universal runner for .asm, .sh, and binary files"
echo "  • Intelligent fallback logic"
echo "  • Architecture detection for .asm compilation"
echo
echo "Usage examples:"
echo "  raw script.js                    # Run JavaScript file"
echo "  raw --eval \"console.log('Hi')\"   # Evaluate JavaScript code"
echo "  raw                              # Start REPL"
echo
if [[ "$INSTALL_BASM" == true ]]; then
  echo "  basm hello.asm                    # Compile and run .asm file"
  echo "  basm script.sh arg1 arg2          # Run shell script"
  echo "  basm mybinary arg1 arg2           # Run binary executable"
  echo "  basm program                      # Auto-detect program.asm/program.sh/program"
  echo
  echo "BASM Fallback logic (when file not found):"
  echo "  1. file.asm → file.sh → file"
  echo "  2. file.sh → file.asm → file"
  echo "  3. file → file.asm → file.sh"
fi
echo
echo "To uninstall, run this script again and choose option 2."
echo "=========================================="