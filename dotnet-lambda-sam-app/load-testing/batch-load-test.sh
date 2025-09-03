#!/bin/bash

# Batch Load Testing Script (Linux/Bash)
# Runs multiple test scenarios with different concurrency levels using hey
# Requirements: hey (install with: sudo apt install hey or download from https://github.com/rakyll/hey)

set -e

# Usage:
#   ./batch-load-test.sh --baseurl https://myapi.com
#   BASE_URL=https://myapi.com ./batch-load-test.sh
#   If neither is provided, uses default placeholder.

BASE_URL_ARG=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --baseurl)
            shift
            BASE_URL_ARG="$1"
            ;;
    esac
    shift
done


if [[ -n "$BASE_URL_ARG" ]]; then
    BASE_URL="$BASE_URL_ARG"
elif [[ -n "$BASE_URL" ]]; then
    BASE_URL="$BASE_URL"
else
    echo -e "${YELLOW}Error: Base URL must be provided with --baseurl <url> or BASE_URL env variable.${NC}"
    exit 1
fi

RESULTS_DIR="batch-test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test scenarios: requests:concurrency:label
TEST_SCENARIOS=(
    "100:5:Light Load"
    "500:10:Medium Load"
    "1000:25:Heavy Load"
    "1500:50:Stress Test"
)

# Endpoints to test
ENDPOINTS=(
    "optimized-snapstart:OptimizedSnapStart"
    "optimized:Optimized"
    "update-counter:Original"
    "non-performant-snapstart:NonPerf+SnapStart"
    "non-performant:NonPerformant"
)

mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}Batch Load Test - .NET Lambda SnapStart Performance${NC}"
echo -e "${CYAN}Scenarios: ${#TEST_SCENARIOS[@]} | Endpoints: ${#ENDPOINTS[@]}${NC}"
echo ""

for scenario in "${TEST_SCENARIOS[@]}"; do
    IFS=":" read -r requests concurrency label <<< "$scenario"
    echo -e "${CYAN}Scenario: $label (${requests} requests, $concurrency concurrent)${NC}"
    for endpoint_info in "${ENDPOINTS[@]}"; do
        IFS=":" read -r endpoint endpoint_label <<< "$endpoint_info"
        url="$BASE_URL/$endpoint"
        endpoint_file="$RESULTS_DIR/${endpoint}_${label}_$TIMESTAMP.txt"
        echo -e "${YELLOW}Testing $endpoint_label at $url${NC}"
        hey -n "$requests" -c "$concurrency" -m POST -T "application/json" "$url" > "$endpoint_file" 2>&1
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}Completed: $endpoint_label${NC}"
        else
            echo -e "${RED}Failed: $endpoint_label${NC}"
        fi
        echo "---"
    done
    echo ""
done

echo -e "${BLUE}All batch tests completed. Results saved in $RESULTS_DIR${NC}"
