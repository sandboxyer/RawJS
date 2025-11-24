#!/bin/sh
# Multi-runtime detector script compatible with ash and bash

# Default values
FORCE_ENGINE=""
DETECT_ORDER="c nodejs python bash ash"

# Function to display usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Detects and returns the most performant available runtime"
    echo ""
    echo "Options:"
    echo "  --ash       Force use of ash"
    echo "  --bash      Force use of bash" 
    echo "  --python    Force use of python"
    echo "  --nodejs    Force use of nodejs"
    echo "  --c         Force use of C/C++ (gcc)"
    echo "  --help      Show this help message"
    echo ""
    echo "Without options, detects the best available runtime in order:"
    echo "c -> nodejs -> python -> bash -> ash"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to handle forced engine
handle_forced_engine() {
    case "$1" in
        --ash)
            echo "Running with ash..."
            exit 0
            ;;
        --bash)
            echo "Running with bash..."
            exit 0
            ;;
        --python)
            echo "Running with python..."
            exit 0
            ;;
        --nodejs)
            echo "Running with nodejs..."
            exit 0
            ;;
        --c)
            echo "Running with C/C++..."
            exit 0
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            show_usage
            exit 1
            ;;
    esac
}

# Parse command line arguments
for arg in "$@"; do
    case "$arg" in
        --ash|--bash|--python|--nodejs|--c|--help)
            handle_forced_engine "$arg"
            ;;
        *)
            echo "Error: Invalid argument '$arg'" >&2
            show_usage
            exit 1
            ;;
    esac
done

# Detect the best available runtime (in performance order)
for runtime in $DETECT_ORDER; do
    case "$runtime" in
        c)
            if command_exists "gcc" || command_exists "clang" || command_exists "cc"; then
                echo "c"
                exit 0
            fi
            ;;
        nodejs)
            if command_exists "node"; then
                echo "node"
                exit 0
            fi
            ;;
        python)
            if command_exists "python3"; then
                echo "python3"
                exit 0
            elif command_exists "python"; then
                echo "python"
                exit 0
            fi
            ;;
        bash)
            if command_exists "bash"; then
                echo "bash"
                exit 0
            fi
            ;;
        ash)
            # ash is always available since we're running with it
            echo "ash"
            exit 0
            ;;
    esac
done

# If we reach here, no runtime was found (should never happen since ash is always available)
echo "ash"
exit 0