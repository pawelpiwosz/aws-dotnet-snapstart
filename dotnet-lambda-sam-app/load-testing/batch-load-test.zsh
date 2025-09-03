#!/bin/zsh

# Batch Load Testing Script
# Runs multiple test scenarios with different concurrency levels
# This helps understand how performance scales with load

set -e



# Usage:
#   ./batch-load-test.zsh --baseurl https://myapi.com
#   BASE_URL=https://myapi.com ./batch-load-test.zsh
#   If neither is provided, uses default placeholder.


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
    BASE_URL="<known_after_deployment>"
fi

RESULTS_DIR="batch-test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test scenarios: requests:concurrency
TEST_SCENARIOS=(
    "100:5:Light Load"
    "500:10:Medium Load" 
    "1000:25:Heavy Load"
    "1500:50:Stress Test"
)

# Endpoints to test (in performance order)
ENDPOINTS=(
    "optimized-snapstart:OptimizedSnapStart"
    "optimized:Optimized"
    "update-counter:Original" 
    "non-performant-snapstart:NonPerf+SnapStart"
    "non-performant:NonPerformant"
)

mkdir -p "$RESULTS_DIR"

print_header() {
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║              Batch Load Testing - Multiple Scenarios         ║${NC}"
    echo -e "${MAGENTA}║                .NET Lambda SnapStart Performance             ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Test Scenarios:${NC}"
    for scenario in "${TEST_SCENARIOS[@]}"; do
        IFS=':' read -r requests concurrency description <<< "$scenario"
        echo -e "  • ${YELLOW}$description${NC}: $requests requests, $concurrency concurrent"
    done
    echo ""
}

run_batch_test() {
    local requests="$1"
    local concurrency="$2"  
    local scenario_name="$3"
    local scenario_dir="$RESULTS_DIR/${scenario_name// /_}_${TIMESTAMP}"
    
    mkdir -p "$scenario_dir"
    
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│ Scenario: $scenario_name${NC}"
    echo -e "${BLUE}│ Requests: $requests | Concurrency: $concurrency${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
    
    local summary_file="$scenario_dir/scenario_summary.txt"
    echo "Batch Test Scenario: $scenario_name" > "$summary_file"
    echo "Requests: $requests" >> "$summary_file"
    echo "Concurrency: $concurrency" >> "$summary_file"
    echo "Timestamp: $(date)" >> "$summary_file"
    echo "========================================" >> "$summary_file"
    echo "" >> "$summary_file"
    
    for endpoint_info in "${ENDPOINTS[@]}"; do
        IFS=':' read -r endpoint name <<< "$endpoint_info"
        local url="$BASE_URL/$endpoint"
        local endpoint_file="$scenario_dir/${endpoint}.txt"
        
        echo -e "${YELLOW}  Testing $name ($endpoint)...${NC}"
        

    # Run hey test
    hey -n "$requests" -c "$concurrency" -m POST -T "application/json" "$url" > "$endpoint_file" 2>&1

    # Extract metrics from hey output
    local mean_time=$(grep "Average:" "$endpoint_file" | awk '{print $2}')
    local rps=$(grep "Requests/sec:" "$endpoint_file" | awk '{print $2}')
    local failed=$(grep "Non-2xx or 3xx responses:" "$endpoint_file" | awk '{print $5}')
    local p50=$(grep "50%" "$endpoint_file" | awk '{print $2}')
    local p95=$(grep "95%" "$endpoint_file" | awk '{print $2}')

    echo -e "    ${GREEN}Mean: ${mean_time}s | RPS: ${rps} | Failed: ${failed:-0}${NC}"

    # Add to summary
    echo "$name ($endpoint):" >> "$summary_file"
    echo "  Mean Response Time: ${mean_time} s" >> "$summary_file"
    echo "  Requests/Second: ${rps}" >> "$summary_file"
    echo "  Failed Requests: ${failed:-0}" >> "$summary_file"
    echo "  50th Percentile: ${p50} s" >> "$summary_file"
    echo "  95th Percentile: ${p95} s" >> "$summary_file"
    echo "" >> "$summary_file"
        
        sleep 5  # Brief pause between endpoints
    done
    
    echo -e "${GREEN}  ✓ Scenario completed: $scenario_name${NC}"
    echo ""
}

generate_comparison_report() {
    local report_file="$RESULTS_DIR/batch_comparison_${TIMESTAMP}.txt"
    
    echo -e "${BLUE}Generating batch comparison report...${NC}"
    
    echo "Batch Load Testing Comparison Report" > "$report_file"
    echo "Generated: $(date)" >> "$report_file"
    echo "======================================" >> "$report_file"
    echo "" >> "$report_file"
    
    # Create comparison table
    printf "%-20s" "Scenario/Endpoint" >> "$report_file"
    for endpoint_info in "${ENDPOINTS[@]}"; do
        IFS=':' read -r endpoint name <<< "$endpoint_info"
        printf " | %-15s" "${name:0:15}" >> "$report_file"
    done
    echo "" >> "$report_file"
    
    # Add separator line
    printf "%-20s" "--------------------" >> "$report_file" 
    for endpoint_info in "${ENDPOINTS[@]}"; do
        printf " | %-15s" "---------------" >> "$report_file"
    done
    echo "" >> "$report_file"
    
    # Add data rows
    for scenario in "${TEST_SCENARIOS[@]}"; do
        IFS=':' read -r requests concurrency description <<< "$scenario"
        local scenario_dir="$RESULTS_DIR/${description// /_}_${TIMESTAMP}"
        
        printf "%-20s" "${description:0:20}" >> "$report_file"
        
        for endpoint_info in "${ENDPOINTS[@]}"; do
            IFS=':' read -r endpoint name <<< "$endpoint_info"
            local endpoint_file="$scenario_dir/${endpoint}.txt"
            
            if [[ -f "$endpoint_file" ]]; then
                local mean_time=$(grep "Time per request:" "$endpoint_file" | head -1 | awk '{print $4}')
                printf " | %-15s" "${mean_time}ms" >> "$report_file"
            else
                printf " | %-15s" "N/A" >> "$report_file"
            fi
        done
        echo "" >> "$report_file"
    done
    
    echo "" >> "$report_file"
    echo "Notes:" >> "$report_file"
    echo "- All times in milliseconds (mean response time)" >> "$report_file"
    echo "- Lower numbers indicate better performance" >> "$report_file"
    
    echo -e "${GREEN}✓ Comparison report generated: $report_file${NC}"
}

main() {
    print_header
    
    # Check prerequisites
    if ! command -v ab &> /dev/null; then
        echo -e "${RED}Error: Apache Bench (ab) not found. Install with: brew install httpd${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Starting batch load testing...${NC}"
    echo ""
    
    # Run all test scenarios
    for scenario in "${TEST_SCENARIOS[@]}"; do
        IFS=':' read -r requests concurrency description <<< "$scenario"
        run_batch_test "$requests" "$concurrency" "$description"
        
        # Wait between scenarios for system recovery
        if [[ "$scenario" != "${TEST_SCENARIOS[-1]}" ]]; then
            echo -e "${CYAN}Waiting 60 seconds before next scenario...${NC}"
            sleep 60
        fi
    done
    
    generate_comparison_report
    
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                Batch Load Testing Complete!                  ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}All results saved in: ${YELLOW}$RESULTS_DIR/${NC}"
    echo -e "${CYAN}View comparison report:${NC}"
    echo -e "  ${YELLOW}cat $RESULTS_DIR/batch_comparison_${TIMESTAMP}.txt${NC}"
    echo ""
    echo -e "${GREEN}Batch testing completed successfully! 🎯${NC}"
}

# Handle interruption gracefully
trap 'echo -e "\n${RED}Batch testing interrupted${NC}"; exit 1' INT TERM

main "$@"
