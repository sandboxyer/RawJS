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
LyoqCiAqIExFVkVMIDA6IFNVUEVSIFNJTVBMRSBTVEFSVEVSIFRFU1RTCiAqLwoKY29uc29sZS5s
b2coIj09PSBTVEFSVElORyBTVVBFUiBTSU1QTEUgVEVTVFMgPT09Iik7CgovLyBKdXN0IHByaW50
IHRoaW5ncwpjb25zb2xlLmxvZygiSGVsbG8hIik7CmNvbnNvbGUubG9nKCJNeSBuYW1lIGlzIENv
bXB1dGVyIik7CmNvbnNvbGUubG9nKCJJIGNhbiBkbyBtYXRoOiIpOwoKLy8gQmFzaWMgbWF0aAps
ZXQgeCA9IDU7CmxldCB5ID0gMzsKY29uc29sZS5sb2coeCArICIgKyAiICsgeSArICIgPSAiICsg
KHggKyB5KSk7CmNvbnNvbGUubG9nKHggKyAiIC0gIiArIHkgKyAiID0gIiArICh4IC0geSkpOwpj
b25zb2xlLmxvZyh4ICsgIiAqICIgKyB5ICsgIiA9ICIgKyAoeCAqIHkpKTsKCi8vIFllcyBvciBu
byBxdWVzdGlvbnMKY29uc29sZS5sb2coIlxuWWVzIG9yIE5vIFF1ZXN0aW9uczoiKTsKY29uc29s
ZS5sb2coIklzIDUgYmlnZ2VyIHRoYW4gMz8gIiArICg1ID4gMykpOwpjb25zb2xlLmxvZygiSXMg
MiBlcXVhbCB0byAyPyAiICsgKDIgPT09IDIpKTsKCi8vIExpc3Qgb2YgdGhpbmdzCmNvbnNvbGUu
bG9nKCJcbk15IGZhdm9yaXRlIGNvbG9yczoiKTsKbGV0IGNvbG9ycyA9IFsicmVkIiwgImJsdWUi
LCAiZ3JlZW4iXTsKZm9yIChsZXQgaSA9IDA7IGkgPCBjb2xvcnMubGVuZ3RoOyBpKyspIHsKICAg
IGNvbnNvbGUubG9nKCIgIC0gIiArIGNvbG9yc1tpXSk7Cn0KCi8vIFNpbXBsZSBwZXJzb24gaW5m
bwpjb25zb2xlLmxvZygiXG5BYm91dCBtZToiKTsKbGV0IG1lID0gewogICAgbmFtZTogIlRlc3Qg
VXNlciIsCiAgICBhZ2U6IDIwLAogICAgbGlrZXNQaXp6YTogdHJ1ZQp9Owpjb25zb2xlLmxvZygi
TmFtZTogIiArIG1lLm5hbWUpOwpjb25zb2xlLmxvZygiQWdlOiAiICsgbWUuYWdlKTsKY29uc29s
ZS5sb2coIkxpa2VzIHBpenphOiAiICsgbWUubGlrZXNQaXp6YSk7CgovLyBTaW1wbGUgZnVuY3Rp
b24KY29uc29sZS5sb2coIlxuU2ltcGxlIGZ1bmN0aW9uIHRlc3Q6Iik7CmZ1bmN0aW9uIHNheUhp
KG5hbWUpIHsKICAgIHJldHVybiAiSGksICIgKyBuYW1lICsgIiEiOwp9CmNvbnNvbGUubG9nKHNh
eUhpKCJGcmllbmQiKSk7CgovLyBFbmQgbWVzc2FnZQpjb25zb2xlLmxvZygiXG49PT0gVEVTVFMg
RklOSVNIRUQgPT09Iik7CmNvbnNvbGUubG9nKCJBbGwgYmFzaWMgdGhpbmdzIHdvcmshIik7Cg==
