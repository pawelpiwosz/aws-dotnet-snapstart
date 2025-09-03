# .NET Lambda SnapStart Load Testing Script (PowerShell)
# This script performs load testing on all Lambda endpoints to demonstrate performance differences
# Requirements: PowerShell 5.1+ or PowerShell Core 7+

param(
    [int]$TotalRequests = 1000,
    [int]$ConcurrentUsers = 25,
    [string]$BaseUrl = "<known_after_deployment>",
    [string]$ResultsDir = "load-test-results"
)

# Configuration
$ErrorActionPreference = "Stop"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Function definitions
$Endpoints = @{
    "optimized-snapstart" = "OptimizedSnapStart (Best Performance)"
    "optimized" = "Optimized (Good Baseline)"
    "update-counter" = "Original Function (Basic)"
    "non-performant-snapstart" = "NonPerformant+SnapStart (Limited)"
    "non-performant" = "NonPerformant (Worst Case)"
}

# Create results directory
New-Item -Path $ResultsDir -ItemType Directory -Force | Out-Null

function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Header {
    Write-ColoredOutput "================================================================" -Color Magenta
    Write-ColoredOutput "                 .NET Lambda Load Testing                     " -Color Magenta
    Write-ColoredOutput "                    SnapStart Performance                     " -Color Magenta
    Write-ColoredOutput "================================================================" -Color Magenta
    Write-Host ""
    Write-ColoredOutput "Configuration:" -Color Cyan
    Write-ColoredOutput "  - Base URL: $BaseUrl" -Color Yellow
    Write-ColoredOutput "  - Total Requests: $TotalRequests" -Color Yellow
    Write-ColoredOutput "  - Concurrent Users: $ConcurrentUsers" -Color Yellow
    Write-ColoredOutput "  - Results Directory: $ResultsDir" -Color Yellow
    Write-Host ""
}

function Test-Prerequisites {
    Write-ColoredOutput "Checking prerequisites..." -Color Blue
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-ColoredOutput "Error: PowerShell 5.1 or higher is required" -Color Red
        exit 1
    }
    
    Write-ColoredOutput "[SUCCESS] Prerequisites check passed" -Color Green
    Write-Host ""
}

function Test-Connectivity {
    Write-ColoredOutput "Testing endpoint connectivity..." -Color Blue
    
    foreach ($endpoint in $Endpoints.Keys) {
        $url = "$BaseUrl/$endpoint"
        Write-Host "  Testing $endpoint... " -NoNewline
        
        try {
            $response = Invoke-WebRequest -Uri $url -Method POST -TimeoutSec 30 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-ColoredOutput "[OK]" -Color Green
            }
            else {
                Write-ColoredOutput "[ERROR] Status: $($response.StatusCode)" -Color Red
                throw "Unexpected status code"
            }
        }
        catch {
            Write-ColoredOutput "[ERROR] Failed" -Color Red
            Write-ColoredOutput "Error: Cannot reach $url" -Color Red
            Write-ColoredOutput "Please check if the API Gateway is deployed and accessible" -Color Yellow
            exit 1
        }
    }
    
    Write-ColoredOutput "[SUCCESS] All endpoints are reachable" -Color Green
    Write-Host ""
}

function Start-WarmUp {
    Write-ColoredOutput "Warming up endpoints (3 requests each)..." -Color Blue
    
    foreach ($endpoint in $Endpoints.Keys) {
        $url = "$BaseUrl/$endpoint"
        Write-Host "  Warming up $endpoint... " -NoNewline
        
        for ($i = 1; $i -le 3; $i++) {
            try {
                Invoke-WebRequest -Uri $url -Method POST -TimeoutSec 30 | Out-Null
                Start-Sleep -Seconds 1
            }
            catch {
                # Ignore warm-up errors
            }
        }
        
        Write-ColoredOutput "[OK]" -Color Green
    }
    
    Write-ColoredOutput "[SUCCESS] Warm-up completed" -Color Green
    Write-Host ""
}

function Invoke-LoadTest {
    param(
        [string]$Endpoint,
        [string]$Description
    )
    
    $url = "$BaseUrl/$Endpoint"
    $outputFile = Join-Path $ResultsDir "${Endpoint}_${Timestamp}.txt"
    
    Write-ColoredOutput "=============================================================" -Color Yellow
    Write-ColoredOutput " Testing: $Description" -Color Yellow
    Write-ColoredOutput " Endpoint: /$Endpoint" -Color Yellow
    Write-ColoredOutput " URL: $url" -Color Yellow
    Write-ColoredOutput "=============================================================" -Color Yellow
    
    Write-ColoredOutput "Starting load test..." -Color Cyan
    
    # Create output file header
    @"
Load Test Results for: $Description
Endpoint: $Endpoint
URL: $url
Timestamp: $(Get-Date)
Requests: $TotalRequests
Concurrency: $ConcurrentUsers
PowerShell Version: $($PSVersionTable.PSVersion)
----------------------------------------

"@ | Out-File -FilePath $outputFile -Encoding UTF8
    
    # Run concurrent requests
    $jobs = @()
    $requestsPerJob = [Math]::Floor($TotalRequests / $ConcurrentUsers)
    $remainingRequests = $TotalRequests % $ConcurrentUsers
    
    $startTime = Get-Date
    
    for ($i = 0; $i -lt $ConcurrentUsers; $i++) {
        $jobRequests = $requestsPerJob
        if ($i -eq 0) { $jobRequests += $remainingRequests }
        
        $job = Start-Job -ScriptBlock {
            param($Url, $Requests)
            
            $results = @()
            for ($j = 0; $j -lt $Requests; $j++) {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                try {
                    $response = Invoke-WebRequest -Uri $Url -Method POST -TimeoutSec 30
                    $stopwatch.Stop()
                    $results += @{
                        Success = $true
                        Duration = $stopwatch.ElapsedMilliseconds
                        StatusCode = $response.StatusCode
                        ContentLength = $response.Content.Length
                    }
                }
                catch {
                    $stopwatch.Stop()
                    $results += @{
                        Success = $false
                        Duration = -1
                        Error = $_.Exception.Message
                    }
                }
            }
            return $results
        } -ArgumentList $url, $jobRequests
        
        $jobs += $job
    }
    
    # Wait for all jobs to complete
    Write-Host "  Running $ConcurrentUsers concurrent workers..." -ForegroundColor Cyan
    $allResults = @()
    
    foreach ($job in $jobs) {
        $jobResults = Receive-Job -Job $job -Wait
        $allResults += $jobResults
        Remove-Job -Job $job
    }
    
    $endTime = Get-Date
    $totalDuration = ($endTime - $startTime).TotalSeconds
    
    # Calculate statistics
    $successfulRequests = ($allResults | Where-Object { $_.Success -eq $true })
    $failedRequests = ($allResults | Where-Object { $_.Success -eq $false })
    
    $successCount = $successfulRequests.Count
    $failedCount = $failedRequests.Count
    $successfulDurations = $successfulRequests | ForEach-Object { $_.Duration }
    
    if ($successfulDurations.Count -gt 0) {
        $meanTime = ($successfulDurations | Measure-Object -Average).Average
        $minTime = ($successfulDurations | Measure-Object -Minimum).Minimum
        $maxTime = ($successfulDurations | Measure-Object -Maximum).Maximum
        $requestsPerSecond = [Math]::Round($successCount / $totalDuration, 2)
        
        # Calculate percentiles
        $sortedDurations = $successfulDurations | Sort-Object
        $p50 = $sortedDurations[[Math]::Floor($sortedDurations.Count * 0.5)]
        $p95 = $sortedDurations[[Math]::Floor($sortedDurations.Count * 0.95)]
        $p99 = $sortedDurations[[Math]::Floor($sortedDurations.Count * 0.99)]
    }
    else {
        $meanTime = -1
        $minTime = -1
        $maxTime = -1
        $requestsPerSecond = 0
        $p50 = -1
        $p95 = -1
        $p99 = -1
    }
    
    # Output results to file
    $results = @"

LOAD TEST RESULTS:
==================
Total Duration: $([Math]::Round($totalDuration, 2)) seconds
Successful Requests: $successCount
Failed Requests: $failedCount
Requests per Second: $requestsPerSecond
Mean Response Time: $([Math]::Round($meanTime, 2)) ms
Min Response Time: $minTime ms
Max Response Time: $maxTime ms
50th Percentile: $p50 ms
95th Percentile: $p95 ms
99th Percentile: $p99 ms

SUMMARY:
========
Mean Response Time: $([Math]::Round($meanTime, 2)) ms
Requests per Second: $requestsPerSecond
Failed Requests: $failedCount
"@
    
    Add-Content -Path $outputFile -Value $results
    
    # Display summary
    Write-Host ""
    Write-ColoredOutput "=============================================================" -Color Green
    Write-ColoredOutput " Results Summary for: $Description" -Color Green
    Write-ColoredOutput " Mean Response Time: $([Math]::Round($meanTime, 2)) ms" -Color Green
    Write-ColoredOutput " Requests/Second: $requestsPerSecond" -Color Green
    Write-ColoredOutput " Failed Requests: $failedCount" -Color Green
    Write-ColoredOutput " Results saved to: $outputFile" -Color Green
    Write-ColoredOutput "=============================================================" -Color Green
    Write-Host ""
    
    # Wait between tests
    Write-ColoredOutput "Waiting 30 seconds before next test..." -Color Cyan
    Start-Sleep -Seconds 30
}

function New-SummaryReport {
    $summaryFile = Join-Path $ResultsDir "load_test_summary_${Timestamp}.txt"
    
    Write-ColoredOutput "Generating comprehensive summary..." -Color Blue
    
    $summary = @"
Load Test Summary Report
Generated: $(Get-Date)
Configuration: $TotalRequests requests, $ConcurrentUsers concurrent users
PowerShell Version: $($PSVersionTable.PSVersion)
========================================

"@
    
    # Process each test result
    foreach ($endpoint in $Endpoints.Keys) {
        $resultFile = Join-Path $ResultsDir "${endpoint}_${Timestamp}.txt"
        
        if (Test-Path $resultFile) {
            $description = $Endpoints[$endpoint]
            $content = Get-Content $resultFile -Raw
            
            if ($content -match "Mean Response Time: ([\d.]+) ms") {
                $meanTime = $matches[1]
            } else { $meanTime = "N/A" }
            
            if ($content -match "Requests per Second: ([\d.]+)") {
                $rps = $matches[1]
            } else { $rps = "N/A" }
            
            if ($content -match "Failed Requests: (\d+)") {
                $failed = $matches[1]
            } else { $failed = "N/A" }
            
            $summary += @"
Endpoint: $endpoint ($description)
  Mean Response Time: $meanTime ms
  Requests/Second: $rps
  Failed Requests: $failed

"@
        }
    }
    
    $summary | Out-File -FilePath $summaryFile -Encoding UTF8
    Write-ColoredOutput "[SUCCESS] Summary report generated: $summaryFile" -Color Green
}

function New-PerformanceChart {
    $chartFile = Join-Path $ResultsDir "performance_comparison_${Timestamp}.txt"
    
    Write-ColoredOutput "Creating performance comparison chart..." -Color Blue
    
    $chart = @"
Performance Comparison Chart
============================

Endpoint Performance (Mean Response Time)
----------------------------------------
"@
    
    $testOrder = @("optimized-snapstart", "optimized", "update-counter", "non-performant-snapstart", "non-performant")
    
    foreach ($endpoint in $testOrder) {
        if ($Endpoints.ContainsKey($endpoint)) {
            $resultFile = Join-Path $ResultsDir "${endpoint}_${Timestamp}.txt"
            
            if (Test-Path $resultFile) {
                $description = $Endpoints[$endpoint]
                $content = Get-Content $resultFile -Raw
                
                if ($content -match "Mean Response Time: ([\d.]+) ms") {
                    $meanTime = [double]$matches[1]
                    $barLength = [Math]::Floor($meanTime / 10)
                    $bar = "*" * $barLength
                    $chart += "`n$($description.PadRight(25)): $bar ($meanTime ms)"
                }
            }
        }
    }
    
    $chart += @"

Legend: Each * represents ~10ms average response time
"@
    
    $chart | Out-File -FilePath $chartFile -Encoding UTF8
    Write-ColoredOutput "[SUCCESS] Performance chart created: $chartFile" -Color Green
}

# Main execution
function Main {
    Write-Header
    Test-Prerequisites
    
    if ($BaseUrl -eq "<known_after_deployment>") {
        Write-ColoredOutput "Warning: Please replace <known_after_deployment> with your actual API Gateway URL" -Color Red
        Write-ColoredOutput "Usage: .\load-test.ps1 -BaseUrl 'https://your-api-gateway-url.amazonaws.com/Prod'" -Color Yellow
        return
    }
    
    Test-Connectivity
    Start-WarmUp
    
    Write-ColoredOutput "Starting load tests for all endpoints..." -Color Magenta
    Write-Host ""
    
    # Test endpoints in order of expected performance (best to worst)
    $testOrder = @("optimized-snapstart", "optimized", "update-counter", "non-performant-snapstart", "non-performant")
    
    foreach ($endpoint in $testOrder) {
        if ($Endpoints.ContainsKey($endpoint)) {
            Invoke-LoadTest -Endpoint $endpoint -Description $Endpoints[$endpoint]
        }
    }
    
    New-SummaryReport
    New-PerformanceChart
    
    Write-ColoredOutput "================================================================" -Color Magenta
    Write-ColoredOutput "                    Load Testing Complete!                    " -Color Magenta
    Write-ColoredOutput "================================================================" -Color Magenta
    Write-Host ""
    Write-ColoredOutput "All results saved in: $ResultsDir" -Color Green
    Write-ColoredOutput "Key files:" -Color Cyan
    Write-ColoredOutput "  - Summary: $ResultsDir\load_test_summary_${Timestamp}.txt" -Color Yellow
    Write-ColoredOutput "  - Performance Chart: $ResultsDir\performance_comparison_${Timestamp}.txt" -Color Yellow
    Write-Host ""
    Write-ColoredOutput "To view results:" -Color Blue
    Write-ColoredOutput "  Get-Content $ResultsDir\load_test_summary_${Timestamp}.txt" -Color Yellow
    Write-ColoredOutput "  Get-Content $ResultsDir\performance_comparison_${Timestamp}.txt" -Color Yellow
    Write-Host ""
    Write-ColoredOutput "Load testing completed successfully!" -Color Green
}

# Handle script interruption gracefully
trap {
    Write-ColoredOutput "`nLoad testing interrupted" -Color Red
    exit 1
}

# Run the main function
Main
