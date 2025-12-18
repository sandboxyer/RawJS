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
MiBlcXVhbCB0byAyPyAiICsgKDIgPT09IDIpKTsKCi8vU2ltcGxlIElGCmxldCBhID0gMSAKbGV0
IGIgPSAyCmlmKGEgPT0gMSl7Y29uc29sZS5sb2coIm9pIik7Y29uc29sZS5sb2coIk9sw6EiKTtp
ZihiID09Mil7Y29uc29sZS5sb2coImRvaXMiKX19CgovLyBMaXN0IG9mIHRoaW5ncwpjb25zb2xl
LmxvZygiXG5NeSBmYXZvcml0ZSBjb2xvcnM6Iik7CmxldCBjb2xvcnMgPSBbInJlZCIsICJibHVl
IiwgImdyZWVuIl07CmZvciAobGV0IGkgPSAwOyBpIDwgY29sb3JzLmxlbmd0aDsgaSsrKSB7CiAg
ICBjb25zb2xlLmxvZygiICAtICIgKyBjb2xvcnNbaV0pOwp9CgovLyBTaW1wbGUgcGVyc29uIGlu
Zm8KY29uc29sZS5sb2coIlxuQWJvdXQgbWU6Iik7CmxldCBtZSA9IHsKICAgIG5hbWU6ICJUZXN0
IFVzZXIiLAogICAgYWdlOiAyMCwKICAgIGxpa2VzUGl6emE6IHRydWUKfTsKY29uc29sZS5sb2co
Ik5hbWU6ICIgKyBtZS5uYW1lKTsKY29uc29sZS5sb2coIkFnZTogIiArIG1lLmFnZSk7CmNvbnNv
bGUubG9nKCJMaWtlcyBwaXp6YTogIiArIG1lLmxpa2VzUGl6emEpOwoKLy8gU2ltcGxlIGZ1bmN0
aW9uCmNvbnNvbGUubG9nKCJcblNpbXBsZSBmdW5jdGlvbiB0ZXN0OiIpOwpmdW5jdGlvbiBzYXlI
aShuYW1lKSB7CiAgICByZXR1cm4gIkhpLCAiICsgbmFtZSArICIhIjsKfQpjb25zb2xlLmxvZyhz
YXlIaSgiRnJpZW5kIikpOwoKLy8gRW5kIG1lc3NhZ2UKY29uc29sZS5sb2coIlxuPT09IFRFU1RT
IEZJTklTSEVEID09PSIpOwpjb25zb2xlLmxvZygiQWxsIGJhc2ljIHRoaW5ncyB3b3JrISIpOwoK
bGV0IG9iaiA9IHsKICAgIG5hbWUgOiAnZGFuaWVsJywKICAgIHJ1biA6IChtc2cpID0+IHtjb25z
b2xlLmxvZyhtc2cpfQp9Cgpjb25zb2xlLmxvZygnanVtcCcpCgpsZXQgb2JqX3R3byA9IHsKICAg
IG5hbWUgOiAnbWlzYycsCiAgICBydW4gOiAobXNnKSA9PiB7Y29uc29sZS5sb2cobXNnKX0sCiAg
ICBvdGhlcl9ydW4gOiAodGVzdCkgPT4ge2NvbnNvbGUubG9nKHRlc3QpfQp9CgpsZXQgYXNzaWdu
ID0gKG9pKSA9PiB7Y29uc29sZS5sb2cob2kpfQoKbGV0IGFycmF5b25lID0gWyh0ZXN0KSA9PiB7
Y29uc29sZS5sb2codGVzdCl9XQoKbGV0IGFycmF5dHdvID0gW3thZ2UgOiAyMCxydW5uYWdlIDog
KHllcykgPT4ge2NvbnNvbGUubG9nKHllcyl9fV0=
