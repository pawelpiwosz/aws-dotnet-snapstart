#!/bin/zsh

# .NET Lambda SnapStart Load Testing Script
# This script performs load testing on all Lambda endpoints to demonstrate performance differences
# Requirements: Apache Bench (ab) - install with: brew install httpd

set -e

# Configuration
BASE_URL="<known_after_deployment>"
TOTAL_REQUESTS=1000
CONCURRENT_USERS=25
RESULTS_DIR="load-test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function definitions
declare -A ENDPOINTS=(
    ["optimized-snapstart"]="OptimizedSnapStart (Best Performance)"
    ["optimized"]="Optimized (Good Baseline)"
    ["update-counter"]="Original Function (Basic)"
    ["non-performant-snapstart"]="NonPerformant+SnapStart (Limited)"
    ["non-performant"]="NonPerformant (Worst Case)"
)

# Create results directory
mkdir -p "$RESULTS_DIR"

print_header() {
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                 .NET Lambda Load Testing                     ║${NC}"
    echo -e "${MAGENTA}║                    SnapStart Performance                     ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Configuration:${NC}"
    echo -e "  • Base URL: ${YELLOW}$BASE_URL${NC}"
    echo -e "  • Total Requests: ${YELLOW}$TOTAL_REQUESTS${NC}"
    echo -e "  • Concurrent Users: ${YELLOW}$CONCURRENT_USERS${NC}"
    echo -e "  • Results Directory: ${YELLOW}$RESULTS_DIR${NC}"
    echo ""
}

check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    
    # Check if ab is installed
    if ! command -v ab &> /dev/null; then
        echo -e "${RED}Error: Apache Bench (ab) is not installed${NC}"
        echo -e "${YELLOW}Install with: brew install httpd${NC}"
        exit 1
    fi
    
    # Check if curl is available for initial connectivity test
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: curl is not installed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Prerequisites check passed${NC}"
    echo ""
}

test_connectivity() {
    echo -e "${BLUE}Testing endpoint connectivity...${NC}"
    
    for endpoint in "${(@k)ENDPOINTS}"; do
        url="$BASE_URL/$endpoint"
        echo -n "  Testing $endpoint... "
        
        if curl -X POST -s -f --max-time 30 "$url" > /dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗ Failed${NC}"
            echo -e "${RED}Error: Cannot reach $url${NC}"
            echo -e "${YELLOW}Please check if the API Gateway is deployed and accessible${NC}"
            exit 1
        fi
    done
    
    echo -e "${GREEN}✓ All endpoints are reachable${NC}"
    echo ""
}

warm_up_endpoints() {
    echo -e "${BLUE}Warming up endpoints (3 requests each)...${NC}"
    
    for endpoint in "${(@k)ENDPOINTS}"; do
        url="$BASE_URL/$endpoint"
        echo -n "  Warming up $endpoint... "
        
        for i in {1..3}; do
            curl -X POST -s --max-time 30 "$url" > /dev/null || true
            sleep 1
        done
        
        echo -e "${GREEN}✓${NC}"
    done
    
    echo -e "${GREEN}✓ Warm-up completed${NC}"
    echo ""
}

run_load_test() {
    local endpoint="$1"
    local description="$2"
    local url="$BASE_URL/$endpoint"
    local output_file="$RESULTS_DIR/${endpoint}_${TIMESTAMP}.txt"
    
    echo -e "${YELLOW}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│ Testing: $description${NC}"
    echo -e "${YELLOW}│ Endpoint: /$endpoint${NC}"
    echo -e "${YELLOW}│ URL: $url${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────────────────────────────┘${NC}"
    
    echo -e "${CYAN}Starting load test...${NC}"
    echo "Load Test Results for: $description" > "$output_file"
    echo "Endpoint: $endpoint" >> "$output_file"
    echo "URL: $url" >> "$output_file"
    echo "Timestamp: $(date)" >> "$output_file"
    echo "Requests: $TOTAL_REQUESTS" >> "$output_file"
    echo "Concurrency: $CONCURRENT_USERS" >> "$output_file"
    echo "----------------------------------------" >> "$output_file"
    echo "" >> "$output_file"
    
    # Run Apache Bench with POST method
    ab -n "$TOTAL_REQUESTS" -c "$CONCURRENT_USERS" -p /dev/null -T "application/json" "$url" | tee -a "$output_file"
    
    # Extract key metrics
    local mean_time=$(grep "Time per request:" "$output_file" | head -1 | awk '{print $4}')
    local requests_per_second=$(grep "Requests per second:" "$output_file" | awk '{print $4}')
    local failed_requests=$(grep "Failed requests:" "$output_file" | awk '{print $3}')
    
    echo ""
    echo -e "${GREEN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│ Results Summary for: $description${NC}"
    echo -e "${GREEN}│ Mean Response Time: ${YELLOW}${mean_time:-N/A} ms${GREEN}${NC}"
    echo -e "${GREEN}│ Requests/Second: ${YELLOW}${requests_per_second:-N/A}${GREEN}${NC}"
    echo -e "${GREEN}│ Failed Requests: ${YELLOW}${failed_requests:-N/A}${GREEN}${NC}"
    echo -e "${GREEN}│ Results saved to: ${YELLOW}$output_file${GREEN}${NC}"
    echo -e "${GREEN}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    
    # Add summary to results file
    echo "" >> "$output_file"
    echo "SUMMARY:" >> "$output_file"
    echo "Mean Response Time: ${mean_time:-N/A} ms" >> "$output_file"
    echo "Requests per Second: ${requests_per_second:-N/A}" >> "$output_file"
    echo "Failed Requests: ${failed_requests:-N/A}" >> "$output_file"
    
    # Wait between tests to allow for cleanup
    echo -e "${CYAN}Waiting 30 seconds before next test...${NC}"
    sleep 30
}

generate_summary() {
    local summary_file="$RESULTS_DIR/load_test_summary_${TIMESTAMP}.txt"
    
    echo -e "${BLUE}Generating comprehensive summary...${NC}"
    
    echo "Load Test Summary Report" > "$summary_file"
    echo "Generated: $(date)" >> "$summary_file"
    echo "Configuration: $TOTAL_REQUESTS requests, $CONCURRENT_USERS concurrent users" >> "$summary_file"
    echo "========================================" >> "$summary_file"
    echo "" >> "$summary_file"
    
    # Process each test result
    for endpoint in "${(@k)ENDPOINTS}"; do
        local result_file="$RESULTS_DIR/${endpoint}_${TIMESTAMP}.txt"
        
        if [[ -f "$result_file" ]]; then
            local description="${ENDPOINTS[$endpoint]}"
            local mean_time=$(grep "Mean Response Time:" "$result_file" | awk '{print $4, $5}')
            local rps=$(grep "Requests per Second:" "$result_file" | awk '{print $4}')
            local failed=$(grep "Failed Requests:" "$result_file" | awk '{print $3}')
            
            echo "Endpoint: $endpoint ($description)" >> "$summary_file"
            echo "  Mean Response Time: $mean_time" >> "$summary_file"
            echo "  Requests/Second: $rps" >> "$summary_file"
            echo "  Failed Requests: $failed" >> "$summary_file"
            echo "" >> "$summary_file"
        fi
    done
    
    echo -e "${GREEN}✓ Summary report generated: $summary_file${NC}"
}

create_performance_chart() {
    local chart_file="$RESULTS_DIR/performance_comparison_${TIMESTAMP}.txt"
    
    echo -e "${BLUE}Creating performance comparison chart...${NC}"
    
    echo "Performance Comparison Chart" > "$chart_file"
    echo "============================" >> "$chart_file"
    echo "" >> "$chart_file"
    
    # Create a simple text-based chart
    echo "Endpoint Performance (Mean Response Time)" >> "$chart_file"
    echo "----------------------------------------" >> "$chart_file"
    
    for endpoint in optimized-snapstart optimized update-counter non-performant-snapstart non-performant; do
        local result_file="$RESULTS_DIR/${endpoint}_${TIMESTAMP}.txt"
        
        if [[ -f "$result_file" ]]; then
            local description="${ENDPOINTS[$endpoint]}"
            local mean_time=$(grep "Mean Response Time:" "$result_file" | awk '{print $4}')
            
            if [[ -n "$mean_time" ]]; then
                # Create a simple bar chart with asterisks
                local bar_length=$((${mean_time%.*} / 10))  # Scale down for display
                local bar=$(printf "%*s" "$bar_length" | tr ' ' '*')
                printf "%-25s: %s (%s ms)\n" "${description:0:25}" "$bar" "$mean_time" >> "$chart_file"
            fi
        fi
    done
    
    echo "" >> "$chart_file"
    echo "Legend: Each * represents ~10ms average response time" >> "$chart_file"
    
    echo -e "${GREEN}✓ Performance chart created: $chart_file${NC}"
}

main() {
    print_header
    check_prerequisites
    test_connectivity
    warm_up_endpoints
    
    echo -e "${MAGENTA}Starting load tests for all endpoints...${NC}"
    echo ""
    
    # Test endpoints in order of expected performance (best to worst)
    local test_order=(
        "optimized-snapstart"
        "optimized" 
        "update-counter"
        "non-performant-snapstart"
        "non-performant"
    )
    
    for endpoint in "${test_order[@]}"; do
        run_load_test "$endpoint" "${ENDPOINTS[$endpoint]}"
    done
    
    generate_summary
    create_performance_chart
    
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                    Load Testing Complete!                    ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}All results saved in: ${YELLOW}$RESULTS_DIR/${NC}"
    echo -e "${CYAN}Key files:${NC}"
    echo -e "  • Summary: ${YELLOW}$RESULTS_DIR/load_test_summary_${TIMESTAMP}.txt${NC}"
    echo -e "  • Performance Chart: ${YELLOW}$RESULTS_DIR/performance_comparison_${TIMESTAMP}.txt${NC}"
    echo ""
    echo -e "${BLUE}To view results:${NC}"
    echo -e "  ${YELLOW}cat $RESULTS_DIR/load_test_summary_${TIMESTAMP}.txt${NC}"
    echo -e "  ${YELLOW}cat $RESULTS_DIR/performance_comparison_${TIMESTAMP}.txt${NC}"
    echo ""
    echo -e "${GREEN}Load testing completed successfully! 🚀${NC}"
}

# Handle script interruption gracefully
trap 'echo -e "\n${RED}Load testing interrupted${NC}"; exit 1' INT TERM

# Run the main function
main "$@"
