#!/usr/bin/env bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ $# -ne 1 ]; then
    echo -e "${RED}Usage: $0 <file.js>${NC}"
    exit 1
fi

JS_FILE="$1"
RAW_SCRIPT="../../../Raw.sh"

# Function to strip ANSI color codes
strip_colors() {
    sed 's/\x1b\[[0-9;]*m//g' | sed 's/\x1b\[[0-9;]*[A-Za-z]//g'
}

# Function to normalize output (strip colors, remove carriage returns, trim spaces)
normalize() {
    strip_colors | sed 's/\r$//' | sed 's/[[:space:]]*$//' | grep -v '^$'
}

echo -e "${BLUE}Running Node.js...${NC}"
NODE_OUTPUT=$(node "$JS_FILE" 2>&1 | normalize)

echo -e "${BLUE}Running Raw.sh...${NC}"
RAW_OUTPUT=$(bash "$RAW_SCRIPT" "$JS_FILE" 2>&1 | normalize)

# Compare normalized outputs
if diff -bBw <(echo "$NODE_OUTPUT") <(echo "$RAW_OUTPUT") >/dev/null 2>&1; then
    echo -e "\n${GREEN}✓ EQUAL - Outputs match perfectly${NC}"
    echo -e "${GREEN}  (ANSI color codes were ignored in comparison)${NC}"
    exit 0
else
    echo -e "\n${RED}✗ DIFFERENCES DETECTED${NC}"
    
    # Calculate line-by-line similarity
    NODE_LINES=$(echo "$NODE_OUTPUT" | wc -l)
    RAW_LINES=$(echo "$RAW_OUTPUT" | wc -l)
    
    # Count matching lines
    MATCH=0
    MAX_LINES=$NODE_LINES
    if [ $RAW_LINES -gt $MAX_LINES ]; then
        MAX_LINES=$RAW_LINES
    fi
    
    # Create arrays for comparison
    mapfile -t node_arr <<< "$NODE_OUTPUT"
    mapfile -t raw_arr <<< "$RAW_OUTPUT"
    
    for i in $(seq 0 $((${#node_arr[@]} - 1))); do
        if [ "${node_arr[$i]}" = "${raw_arr[$i]}" ]; then
            MATCH=$((MATCH + 1))
        fi
    done
    
    SIMILARITY=$((MATCH * 100 / MAX_LINES))
    
    echo -e "${YELLOW}Similarity: ${SIMILARITY}%${NC}"
    echo -e "${YELLOW}Matching lines: ${MATCH}/${MAX_LINES}${NC}\n"
    
    # Show differences
    echo -e "${BLUE}=== Differences (content only, colors ignored) ===${NC}"
    diff -y --suppress-common-lines -W 60 \
        <(echo "$NODE_OUTPUT") \
        <(echo "$RAW_OUTPUT") | head -20
    
    # Show which lines differ
    echo -e "\n${BLUE}=== Line-by-line comparison ===${NC}"
    for i in $(seq 0 $((${#node_arr[@]} - 1))); do
        if [ "${node_arr[$i]}" != "${raw_arr[$i]}" ]; then
            echo -e "${RED}Line $((i+1)) differs:${NC}"
            echo -e "  Node.js: ${node_arr[$i]}"
            echo -e "  Raw.sh:  ${raw_arr[$i]}"
        fi
    done
    
    exit 1
fi