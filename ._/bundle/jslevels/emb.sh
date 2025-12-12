#!/bin/bash

set -e

# Check if a file was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <javascript-file.js>"
    echo "Creates a self-extracting shell script that recreates the JS file"
    exit 1
fi

# Check if the file exists
input_file="$1"
if [ ! -f "$input_file" ]; then
    echo "Error: File '$input_file' does not exist"
    exit 1
fi

# Get the base filename
filename=$(basename "$input_file")

# Create the output shell script name (same name as .js but with .sh extension)
output_script="${filename%.*}.sh"

# Create the self-extracting shell script
cat > "$output_script" << 'EOF'
#!/bin/bash

# Self-extracting JavaScript file generator
# This script will recreate the original JavaScript file

set -e

# Get the original filename from the script name
SCRIPT_NAME="$(basename "$0")"
OUTPUT_FILE="${SCRIPT_NAME%.*}.js"

# Auto-overwrite if file exists (no prompt)
if [ -f "$OUTPUT_FILE" ]; then
    echo "Overwriting existing file: $OUTPUT_FILE"
fi

# Find where the embedded data starts
# Look for the base64 data after the marker
SCRIPT_END_MARKER="#===BEGIN_BASE64_DATA==="

# Get the line number of the marker
MARKER_LINE=$(grep -n "^${SCRIPT_END_MARKER}$" "$0" | cut -d: -f1)

if [ -z "$MARKER_LINE" ]; then
    echo "Error: Could not find embedded data marker" >&2
    exit 1
fi

# Extract the base64 data (starts after the marker)
DATA_START_LINE=$((MARKER_LINE + 1))

# Get all lines from the data start to end of file
# and decode from base64
tail -n +"${DATA_START_LINE}" "$0" | base64 --decode > "$OUTPUT_FILE"

# Verify extraction
if [ $? -eq 0 ]; then
    echo "Successfully created: $OUTPUT_FILE"
    echo "Size: $(wc -c < "$OUTPUT_FILE") bytes"
    
    # Make executable if it starts with shebang
    if head -n1 "$OUTPUT_FILE" | grep -q "^#!"; then
        chmod +x "$OUTPUT_FILE"
        echo "Made executable (has shebang)"
    fi
else
    echo "Error: Failed to extract JavaScript file" >&2
    exit 1
fi

exit 0

#===BEGIN_BASE64_DATA===
EOF

# Encode the file in base64 and append it
base64 "$input_file" >> "$output_script"

# Make the generated script executable
chmod +x "$output_script"

echo "Created self-extracting script: $output_script"
echo "Original file: $input_file ($(wc -c < "$input_file") bytes)"
echo ""
echo "To extract: ./$output_script"
echo "This will create/overwrite: ${filename%.*}.js"
echo ""
echo "Quick test:"
echo "  ./$output_script"
echo "  diff $input_file ${filename%.*}.js"
