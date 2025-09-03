#!/bin/bash

# Quick Load Test Script (Linux/Bash)
# Simplified version for rapid testing using hey
# Requirements: hey (install with: sudo apt install hey or download from https://github.com/rakyll/hey)

set -e

# Usage:
#   ./quick-load-test.sh --baseurl https://myapi.com [requests] [concurrency]
#   BASE_URL=https://myapi.com ./quick-load-test.sh [requests] [concurrency]
#   If neither is provided, uses default placeholder.

BASE_URL_ARG=""
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --baseurl)
            shift
            BASE_URL_ARG="$1"
            ;;
        *)
            POSITIONAL+=("$1")
            ;;
    esac
    shift
done
set -- "${POSITIONAL[@]}"


if [[ -n "$BASE_URL_ARG" ]]; then
    BASE_URL="$BASE_URL_ARG"
elif [[ -n "$BASE_URL" ]]; then
    BASE_URL="$BASE_URL"
else
    echo -e "${YELLOW}Error: Base URL must be provided with --baseurl <url> or BASE_URL env variable.${NC}"
    exit 1
fi

REQUESTS=${1:-100}
CONCURRENCY=${2:-10}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Endpoints in performance order
ENDPOINTS=(
    "optimized-snapstart:OptimizedSnapStart"
    "optimized:Optimized"
    "update-counter:Original"
    "non-performant-snapstart:NonPerf+SnapStart"
    "non-performant:NonPerformant"
)

echo -e "${BLUE}Quick Load Test - .NET Lambda SnapStart Performance${NC}"
echo -e "${CYAN}Requests: $REQUESTS | Concurrency: $CONCURRENCY${NC}"
echo ""

for endpoint_info in "${ENDPOINTS[@]}"; do
    IFS=":" read -r endpoint endpoint_label <<< "$endpoint_info"
    url="$BASE_URL/$endpoint"
    echo -e "${YELLOW}Testing $endpoint_label at $url${NC}"
    result=$(hey -n "$REQUESTS" -c "$CONCURRENCY" -m POST -T "application/json" "$url" 2>/dev/null | \
        grep -E "Requests/sec:|Average:|Non-2xx|50%|95%" || true)
    echo -e "$result"
    echo "---"
done

echo -e "${GREEN}✓ Quick load testing complete!${NC}"
