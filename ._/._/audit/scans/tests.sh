#!/bin/bash

# Store current directory
CURRENT_DIR=$(pwd)

# Function to find main script in a directory
find_main_script() {
    local dir="$1"
    
    # Check if directory exists
    if [ ! -d "$dir" ]; then
        return 1
    fi
    
    # Look for .sh files in the directory
    for file in "$dir"/*.sh; do
        # Skip tests.sh if it exists
        if [[ "$file" == *"tests.sh" ]]; then
            continue
        fi
        
        # Check if file exists and contains "Test Summary:"
        if [ -f "$file" ] && grep -q "Test Summary:" "$file"; then
            echo "$file"
            return 0
        fi
    done
    
    # Alternative: if no file contains "Test Summary:", take any .sh that's not tests.sh
    for file in "$dir"/*.sh; do
        if [ -f "$file" ] && [[ "$file" != *"tests.sh" ]]; then
            echo "$file"
            return 0
        fi
    done
    
    return 1
}

# Function to extract and display test summary
extract_test_summary() {
    local output="$1"
    local main_file="$2"
    
    # Extract everything from "Test Summary:" to the end
    local summary=$(echo "$output" | grep -A 10 "Test Summary:")
    
    if [ -n "$summary" ]; then
        echo "=== $(basename "$main_file") ==="
        echo "$summary"
        echo ""
    else
        echo "=== $(basename "$main_file") ==="
        echo "No Test Summary found in output"
        echo ""
    fi
}

# Main execution
echo "Starting test execution for all directories..."
echo "=============================================="
echo ""

# Loop through all directories in current level
for dir in */; do
    # Remove trailing slash
    dir=${dir%/}
    
    # Skip if not a directory
    if [ ! -d "$dir" ]; then
        continue
    fi
    
    echo "Processing directory: $dir"
    
    # Find main script in this directory
    main_script=$(find_main_script "$dir")
    
    if [ -z "$main_script" ]; then
        echo "  No main script found in $dir"
        echo ""
        continue
    fi
    
    echo "  Found main script: $(basename "$main_script")"
    
    # Change to directory
    cd "$dir" || continue
    
    # Execute the script with --test flag and capture output
    echo "  Executing tests..."
    output=$(bash "$(basename "$main_script")" --test 2>&1)
    
    # Extract and display test summary
    extract_test_summary "$output" "$main_script"
    
    # Return to original directory
    cd "$CURRENT_DIR"
done

echo "=============================================="
echo "All test executions completed!"
