#!/bin/zsh

# Quick Load Test Script - Simplified version for rapid testing
# Usage: ./quick-load-test.zsh [requests] [concurrency]

set -e

# Default configuration
BASE_URL="<known_after_deployment>"
REQUESTS=${1:-100}    # Default 100 requests if not specified
CONCURRENCY=${2:-10}  # Default 10 concurrent if not specified

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Endpoints in performance order (best to worst expected)
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
    IFS=':' read -r endpoint name <<< "$endpoint_info"
    url="$BASE_URL/$endpoint"
    
    echo -e "${YELLOW}Testing $name ($endpoint)...${NC}"
    
    # Run quick test and extract key metrics
    result=$(ab -n "$REQUESTS" -c "$CONCURRENCY" -p /dev/null -T "application/json" "$url" 2>/dev/null | \
             grep -E "(Requests per second|Time per request:|Failed requests)")
    
    echo "$result" | sed 's/^/  /'
    echo ""
    
    # Brief pause between tests
    sleep 5
done

echo -e "${GREEN}✓ Quick load testing complete!${NC}"
