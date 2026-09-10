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
# Compatible with both GNU base64 (--decode) and BusyBox base64 (-d)
tail -n +"${DATA_START_LINE}" "$0" | base64 -d > "$OUTPUT_FILE" 2>/dev/null || \
tail -n +"${DATA_START_LINE}" "$0" | base64 --decode > "$OUTPUT_FILE"

# Verify extraction
if [ $? -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
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
Ly8gTXVsdGlwbGUgcGFyYW1ldGVycyB3aXRoIGFyaXRobWV0aWMgb3BlcmF0aW9ucwpmdW5jdGlv
biBjYWxjdWxhdGUodmFsdWUgPSAzLCBtdWx0aXBsaWVyID0gMiwgc3VidHJhY3RvciA9IDEsIGFk
ZGVyID0gMCkgewogIGxldCByZXN1bHQgPSB2YWx1ZSAqIG11bHRpcGxpZXIgLSBzdWJ0cmFjdG9y
ICsgYWRkZXIKICByZXR1cm4gcmVzdWx0Cn0KCmZ1bmN0aW9uIGRvdWJsZUl0KG51bSA9IDQsIGV4
dHJhID0gMCwgZmFjdG9yID0gMSkgewogIGxldCBvdXRjb21lID0gKG51bSArIG51bSArIGV4dHJh
KSAqIGZhY3RvcgogIHJldHVybiBvdXRjb21lCn0KCmZ1bmN0aW9uIG11bHRpcGx5QW5kQWRkKGJh
c2UgPSA1LCB0aW1lcyA9IDMsIGFkZCA9IDIsIHN1YnRyYWN0ID0gMSkgewogIGxldCB0b3RhbCA9
IGJhc2UgKiB0aW1lcyArIGFkZCAtIHN1YnRyYWN0CiAgcmV0dXJuIHRvdGFsCn0KCmZ1bmN0aW9u
IGNvbWJpbmUoYSA9IDEsIGIgPSAyLCBjID0gMywgZCA9IDQpIHsKICBsZXQgc3VtID0gYSArIGIg
KyBjICsgZAogIHJldHVybiBzdW0KfQoKLy8gRGVlcGx5IG5lc3RlZCBjYWxscyB3aXRoIG11bHRp
cGxlIGFyZ3VtZW50cwpjb25zb2xlLmxvZyhjYWxjdWxhdGUoMTAsIDMsIDIsIDUpKQpsZXQgcmVz
dWx0ID0gY2FsY3VsYXRlKDgsIDQsIDIsIDEpCmNvbnNvbGUubG9nKHJlc3VsdCkKCi8vIE5lc3Rl
ZCBjYWxscyAyIGxldmVscyBkZWVwCmNvbnNvbGUubG9nKGRvdWJsZUl0KGNhbGN1bGF0ZSgyLCA1
LCAxLCAzKSwgNCwgMikpCmNvbnNvbGUubG9nKG11bHRpcGx5QW5kQWRkKGRvdWJsZUl0KDYsIDIs
IDMpLCBjYWxjdWxhdGUoNCwgMywgMiwgMSksIDUsIDIpKQoKLy8gTmVzdGVkIGNhbGxzIDMgbGV2
ZWxzIGRlZXAKY29uc29sZS5sb2coY2FsY3VsYXRlKGRvdWJsZUl0KGNhbGN1bGF0ZSgzLCA0LCAx
LCAyKSwgMywgMiksIG11bHRpcGx5QW5kQWRkKDIsIDMsIDQsIDEpLCA1LCAzKSkKY29uc29sZS5s
b2coZG91YmxlSXQobXVsdGlwbHlBbmRBZGQoY2FsY3VsYXRlKDUsIDIsIDEsIDQpLCBkb3VibGVJ
dCgzLCAxLCAyKSwgNiwgMiksIGNhbGN1bGF0ZSgyLCAzLCAxLCAyKSwgMykpCgovLyBOZXN0ZWQg
Y2FsbHMgNCBsZXZlbHMgZGVlcApjb25zb2xlLmxvZyhjb21iaW5lKAogIGNhbGN1bGF0ZSg3LCAz
LCAyLCAxKSwKICBkb3VibGVJdChjYWxjdWxhdGUoNCwgMiwgMSwgMyksIDUsIDIpLAogIG11bHRp
cGx5QW5kQWRkKGRvdWJsZUl0KDIsIDMsIDIpLCBjYWxjdWxhdGUoMywgMiwgMSwgNCksIDgsIDMp
LAogIGNhbGN1bGF0ZShkb3VibGVJdChtdWx0aXBseUFuZEFkZCgyLCAzLCAxLCAyKSwgNCwgMyks
IDUsIDIsIDYpCikpCgovLyBFeHRyZW1lbHkgZGVlcCBuZXN0aW5nIC0gNSBsZXZlbHMKY29uc29s
ZS5sb2coY2FsY3VsYXRlKAogIGRvdWJsZUl0KAogICAgbXVsdGlwbHlBbmRBZGQoCiAgICAgIGNh
bGN1bGF0ZSgKICAgICAgICBkb3VibGVJdCgyLCAxLCAzKSwKICAgICAgICA0LCAyLCAxCiAgICAg
ICksCiAgICAgIGNvbWJpbmUoMSwgMiwgMywgNCksCiAgICAgIDcsIDIKICAgICksCiAgICBjYWxj
dWxhdGUoMywgMiwgMSwgNSksCiAgICAyCiAgKSwKICBkb3VibGVJdCg0LCAyLCAxKSwKICAzLCAx
CikpCg==
