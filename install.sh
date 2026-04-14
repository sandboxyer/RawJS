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
# SYSTEM DETECTION AND PACKAGE INSTALLATION
# =============================================================================

# Detect system type (ash compatible)
detect_system() {
  if [ -f /etc/alpine-release ]; then
    echo "alpine"
  elif [ -f /etc/lsb-release ]; then
    # Check for Ubuntu specifically
    if grep -qi "ubuntu" /etc/lsb-release 2>/dev/null; then
      echo "ubuntu"
    else
      echo "unknown"
    fi
  elif [ -f /etc/os-release ]; then
    # More generic detection using os-release
    if grep -qi "alpine" /etc/os-release 2>/dev/null; then
      echo "alpine"
    elif grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
      echo "ubuntu"
    else
      echo "unknown"
    fi
  else
    echo "unknown"
  fi
}

# Check if required commands are available
check_command() {
  command -v "$1" >/dev/null 2>&1
}

# Install Alpine packages if needed
install_alpine_packages() {
  local alpine_pack_dir="$BASM_SOURCE_DIR/alpine-pack"
  
  # Check what's already installed
  local need_ld=false
  local need_bash=false
  
  if ! check_command ld; then
    need_ld=true
  fi
  
  if ! check_command bash; then
    need_bash=true
  fi
  
  # If nothing needed, return
  if [ "$need_ld" = false ] && [ "$need_bash" = false ]; then
    log_message "All required Alpine packages already installed"
    return 0
  fi
  
  log_message "Installing required Alpine packages..."
  
  # Check if apk is available
  if ! check_command apk; then
    echo "Warning: apk package manager not found. Cannot install Alpine packages automatically." >&2
    return 1
  fi
  
  # Install packages from alpine-pack directory if they exist
  if [ -d "$alpine_pack_dir" ]; then
    if [ "$need_ld" = true ]; then
      ld_apk=$(find "$alpine_pack_dir" -name "*binutils*.apk" 2>/dev/null | head -n1)
      if [ -n "$ld_apk" ] && [ -f "$ld_apk" ]; then
        log_message "Installing: $(basename "$ld_apk")"
        apk add --allow-untrusted "$ld_apk" 2>&1 || {
          echo "Warning: Failed to install $(basename "$ld_apk")" >&2
        }
      fi
    fi
    
    if [ "$need_bash" = true ]; then
      bash_apk=$(find "$alpine_pack_dir" -name "*bash*.apk" 2>/dev/null | head -n1)
      if [ -n "$bash_apk" ] && [ -f "$bash_apk" ]; then
        log_message "Installing: $(basename "$bash_apk")"
        apk add --allow-untrusted "$bash_apk" 2>&1 || {
          echo "Warning: Failed to install $(basename "$bash_apk")" >&2
        }
      fi
    fi
  fi
  
  # If still missing, try to install from repositories
  if [ "$need_ld" = true ] && ! check_command ld; then
    log_message "Installing binutils from Alpine repository..."
    apk add binutils 2>&1 || echo "Warning: Failed to install binutils from repository" >&2
  fi
  
  if [ "$need_bash" = true ] && ! check_command bash; then
    log_message "Installing bash from Alpine repository..."
    apk add bash 2>&1 || echo "Warning: Failed to install bash from repository" >&2
  fi
}

# Install Ubuntu packages if needed
install_ubuntu_packages() {
  local ubuntu_pack_dir="$BASM_SOURCE_DIR/ubuntu-pack"
  
  # Check what's already installed
  local need_ld=false
  
  if ! check_command ld; then
    need_ld=true
  fi
  
  # If nothing needed, return
  if [ "$need_ld" = false ]; then
    log_message "All required Ubuntu packages already installed"
    return 0
  fi
  
  log_message "Installing required Ubuntu packages..."
  
  # Check if dpkg is available
  if ! check_command dpkg; then
    echo "Warning: dpkg package manager not found. Cannot install Ubuntu packages automatically." >&2
    return 1
  fi
  
  # Install packages from ubuntu-pack directory if they exist
  if [ -d "$ubuntu_pack_dir" ] && [ "$need_ld" = true ]; then
    # Find binutils deb package
    deb_file=$(find "$ubuntu_pack_dir" -name "*binutils*.deb" 2>/dev/null | head -n1)
    
    if [ -n "$deb_file" ] && [ -f "$deb_file" ]; then
      log_message "Installing binutils from local directory: $(basename "$deb_file")"
      dpkg -i "$deb_file" 2>&1 || {
        echo "Warning: Failed to install $(basename "$deb_file")" >&2
      }
    fi
  fi
  
  # If still missing, try to install from repositories
  if [ "$need_ld" = true ] && ! check_command ld; then
    # Check if apt-get is available
    if check_command apt-get; then
      log_message "Installing binutils from Ubuntu repository..."
      apt-get update -qq 2>&1
      apt-get install -y binutils 2>&1 || echo "Warning: Failed to install binutils from repository" >&2
    fi
  fi
}

# Install system-specific packages (first-time installation only)
install_system_packages() {
  local system_type="$1"
  
  log_message "Detected system: $system_type"
  
  case "$system_type" in
    alpine)
      install_alpine_packages
      ;;
    ubuntu)
      install_ubuntu_packages
      ;;
    *)
      log_message "Unknown system type. Skipping automatic package installation."
      log_message "Please ensure 'ld' (linker) is installed manually."
      if ! check_command ld; then
        echo "Warning: 'ld' (linker) not found. BASM .asm compilation may not work." >&2
      fi
      ;;
  esac
  
  # Final verification
  if check_command ld; then
    log_message "✓ Linker (ld) is available"
  else
    log_message "⚠ Warning: Linker (ld) is not available"
  fi
  
  if check_command bash; then
    log_message "✓ Bash is available"
  else
    log_message "⚠ Warning: Bash is not available (required for BASM)"
  fi
}

# =============================================================================
# FUNCTION DEFINITIONS (ORIGINAL - PRESERVED WITH ASH COMPATIBILITY)
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
  
  if [ "$LOG_MODE" = true ]; then
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
  else
    echo "[$timestamp] $message"
  fi
}

# ASH-COMPATIBLE PROGRESS FUNCTION (without read -t)
show_progress() {
  local message="$1"
  local pid="$2"
  local spinner="|/-\\"
  local i=0
  
  # Just show a simple message that we're working
  echo "$message (in progress...)"
  
  # Wait for the process to complete
  wait $pid 2>/dev/null
  
  echo "$message completed."
}

copy_files() {
  local src_dir="$1"
  local dest_dir="$2"
  local description="$3"

  mkdir -p "$dest_dir"
  log_message "Copying $description files to $dest_dir..."

  if [ "$LOG_MODE" = true ]; then
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
  # EXACT ORIGINAL LOGIC - PRESERVED COMPLETELY
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
  [ -L "$dest_path" ] && rm -f "$dest_path"
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
  [ -L "$dest_path" ] && rm -f "$dest_path"
  ln -sf "$wrapper_path" "$dest_path"
  
  log_message "Created 'basm' command symlink"
}

verify_rawjs_structure() {
  local install_dir="$1"
  
  log_message "Verifying RawJS installation structure..."
  
  # Check essential files
  if [ -f "$install_dir/Raw.sh" ]; then
    echo "✓ Found required file: Raw.sh"
    chmod +x "$install_dir/Raw.sh" 2>/dev/null || true
  else
    echo "✗ Error: Missing required file: Raw.sh"
    return 1
  fi
  
  # Check for JavaScript files
  if [ -f "$install_dir/output.js" ]; then
    echo "✓ Found JavaScript file: output.js"
  else
    echo "  Note: JavaScript file not found: output.js"
  fi
  
  if [ -f "$install_dir/test.js" ]; then
    echo "✓ Found JavaScript file: test.js"
  else
    echo "  Note: JavaScript file not found: test.js"
  fi
  
  return 0
}

verify_basm_structure() {
  local install_dir="$1"
  
  log_message "Verifying BASM installation structure..."
  
  # Check essential files
  if [ -f "$install_dir/._basm/basm.sh" ]; then
    echo "✓ Found required file: basm.sh"
    chmod +x "$install_dir/._basm/basm.sh" 2>/dev/null || true
  else
    echo "✗ Error: Missing required file: basm.sh"
    return 1
  fi
  
  # Check architecture binaries (NASM binaries for .asm support)
  local has_any_arch=false
  
  if [ -d "$install_dir/._basm/arm-linux" ]; then
    echo "✓ Found NASM architecture: arm-linux"
    has_any_arch=true
    
    # Check for nasm binary
    if [ -f "$install_dir/._basm/arm-linux/nasm-arm-linux-linux" ]; then
      echo "  ✓ NASM binary found"
      chmod +x "$install_dir/._basm/arm-linux/nasm-arm-linux-linux" 2>/dev/null || true
    else
      echo "  ⚠ NASM binary not found (but directory exists)"
    fi
  else
    echo "  Note: NASM architecture directory not found: arm-linux"
  fi
  
  if [ -d "$install_dir/._basm/i386-linux" ]; then
    echo "✓ Found NASM architecture: i386-linux"
    has_any_arch=true
    
    if [ -f "$install_dir/._basm/i386-linux/nasm-i386-linux-linux" ]; then
      echo "  ✓ NASM binary found"
      chmod +x "$install_dir/._basm/i386-linux/nasm-i386-linux-linux" 2>/dev/null || true
    else
      echo "  ⚠ NASM binary not found (but directory exists)"
    fi
  else
    echo "  Note: NASM architecture directory not found: i386-linux"
  fi
  
  if [ -d "$install_dir/._basm/x86_64-linux" ]; then
    echo "✓ Found NASM architecture: x86_64-linux"
    has_any_arch=true
    
    if [ -f "$install_dir/._basm/x86_64-linux/nasm-x86_64-linux-linux" ]; then
      echo "  ✓ NASM binary found"
      chmod +x "$install_dir/._basm/x86_64-linux/nasm-x86_64-linux-linux" 2>/dev/null || true
    else
      echo "  ⚠ NASM binary not found (but directory exists)"
    fi
  else
    echo "  Note: NASM architecture directory not found: x86_64-linux"
  fi
  
  if [ "$has_any_arch" = false ]; then
    echo "⚠ Warning: No NASM architecture directories found"
    echo "  .asm file compilation will not be available"
  fi
  
  # Check for ld (linker)
  if check_command ld; then
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
  if [ -L "$BIN_DIR/raw" ]; then
    rm -f "$BIN_DIR/raw"
    log_message "Removed symlink: $BIN_DIR/raw"
  fi
  
  if [ -L "$BIN_DIR/basm" ]; then
    rm -f "$BIN_DIR/basm"
    log_message "Removed symlink: $BIN_DIR/basm"
  fi
  
  # Remove installation directory
  if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    log_message "Removed installation directory: $INSTALL_DIR"
  fi
}

cleanup() {
  # Remove backup directory if it exists
  if [ -d "$BACKUP_DIR" ]; then
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
if [ ! -f "$RAWJS_SOURCE_DIR/Raw.sh" ]; then
  echo "Error: Raw.sh not found at: $RAWJS_SOURCE_DIR/Raw.sh" >&2
  echo "Make sure you're running this script from the correct directory." >&2
  echo "Current directory: $REPO_DIR" >&2
  echo "Expected to find: Raw.sh" >&2
  echo "Files in current directory:" >&2
  ls -la "$REPO_DIR/" | grep -E "\.sh$" >&2 || echo "  (no .sh files found)" >&2
  exit 1
fi

# Check if BASM source directory exists
if [ ! -d "$BASM_SOURCE_DIR" ]; then
  echo "Warning: BASM directory not found at: $BASM_SOURCE_DIR" >&2
  echo "BASM will not be installed, but RawJS will continue." >&2
  INSTALL_BASM=false
else
  INSTALL_BASM=true
fi

# Detect if this is a first-time installation
IS_FIRST_INSTALL=false
if [ ! -d "$INSTALL_DIR" ]; then
  IS_FIRST_INSTALL=true
fi

# Handle existing installation
if [ -d "$INSTALL_DIR" ]; then
  log_message "Existing installation found at: $INSTALL_DIR"
  echo "Choose an option:"
  echo "  1 = Update"
  echo "  2 = Remove"
  echo "  3 = Exit"
  printf "Enter your choice [1-3]: "
  read choice
  
  case "$choice" in
    1) 
      # Completely remove existing installation
      log_message "Removing existing installation for clean update..."
      remove_installation
      log_message "Clean removal completed. Proceeding with fresh installation..."
      IS_FIRST_INSTALL=true
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

# Install system packages on first-time installation
if [ "$IS_FIRST_INSTALL" = true ] && [ "$INSTALL_BASM" = true ]; then
  SYSTEM_TYPE=$(detect_system)
  install_system_packages "$SYSTEM_TYPE"
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
if [ "$INSTALL_BASM" = true ]; then
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
if [ "$INSTALL_BASM" = true ]; then
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
if [ "$INSTALL_BASM" = true ]; then
  echo "  • $BIN_DIR/basm (BASM Universal Runner)"
fi
echo
echo "RAWJS COMMAND:"
echo "  • JavaScript runtime environment"
echo "  • Execute JavaScript files and scripts"
echo
if [ "$INSTALL_BASM" = true ]; then
  echo "BASM COMMAND:"
  echo "  • Universal runner for .asm, .sh, and binary files"
  echo "  • Intelligent fallback logic"
  echo "  • Architecture detection for .asm compilation"
fi
echo
echo "Usage examples:"
echo "  raw script.js                    # Run JavaScript file"
echo "  raw --eval \"console.log('Hi')\"   # Evaluate JavaScript code"
echo "  raw                              # Start REPL"
echo
if [ "$INSTALL_BASM" = true ]; then
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