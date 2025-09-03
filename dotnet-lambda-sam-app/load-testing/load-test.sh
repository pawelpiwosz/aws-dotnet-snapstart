#!/bin/bash

# .NET Lambda SnapStart Load Testing Script (Linux/Bash)
# This script performs load testing on all Lambda endpoints to demonstrate performance differences
# Requirements: hey (install with: sudo apt install hey or download from https://github.com/rakyll/hey)

set -e

# Usage:
#   ./load-test.sh --baseurl https://myapi.com
#   BASE_URL=https://myapi.com ./load-test.sh
#   If neither is provided, uses default placeholder.
#
# This script uses 'hey' for load testing.

# Parse arguments for --baseurl
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

TOTAL_REQUESTS=1000
CONCURRENT_USERS=25
RESULTS_DIR="load-test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Endpoints to test
declare -A ENDPOINTS=(
    ["optimized-snapstart"]="OptimizedSnapStart (Best Performance)"
    ["optimized"]="Optimized (Good Baseline)"
    ["update-counter"]="Original Function (Basic)"
    ["non-performant-snapstart"]="NonPerformant+SnapStart (Limited)"
    ["non-performant"]="NonPerformant (Worst Case)"
)

mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}Load Test - .NET Lambda SnapStart Performance${NC}"
echo -e "${CYAN}Requests: $TOTAL_REQUESTS | Concurrency: $CONCURRENT_USERS${NC}"
echo ""

for endpoint in "${!ENDPOINTS[@]}"; do
    endpoint_name=${ENDPOINTS[$endpoint]}
    url="$BASE_URL/$endpoint"
    result_file="$RESULTS_DIR/${endpoint}_$TIMESTAMP.txt"
    echo -e "${YELLOW}Testing $endpoint_name at $url${NC}"
    hey -n "$TOTAL_REQUESTS" -c "$CONCURRENT_USERS" -m POST -T "application/json" "$url" > "$result_file" 2>&1
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Completed: $endpoint_name${NC}"
    else
        echo -e "${RED}Failed: $endpoint_name${NC}"
    fi
    echo "---"
done

echo -e "${BLUE}All tests completed. Results saved in $RESULTS_DIR${NC}"
