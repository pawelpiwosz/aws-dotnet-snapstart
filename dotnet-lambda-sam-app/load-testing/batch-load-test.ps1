# Batch Load Testing Script - PowerShell version
# Runs multiple test scenarios with different concurrency levels
# This helps understand how performance scales with load

param(
    [string]$BaseUrl = "<known_after_deployment>",
    [string]$ResultsDir = "batch-test-results"
)

$ErrorActionPreference = "Stop"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Test scenarios: requests:concurrency:description
$TestScenarios = @(
    @{ Requests = 100; Concurrency = 5; Description = "Light Load" },
    @{ Requests = 500; Concurrency = 10; Description = "Medium Load" },
    @{ Requests = 1000; Concurrency = 25; Description = "Heavy Load" },
    @{ Requests = 1500; Concurrency = 50; Description = "Stress Test" }
)

# Endpoints to test (in performance order)
$Endpoints = @(
    @{ Name = "OptimizedSnapStart"; Path = "optimized-snapstart" },
    @{ Name = "Optimized"; Path = "optimized" },
    @{ Name = "Original"; Path = "update-counter" },
    @{ Name = "NonPerf+SnapStart"; Path = "non-performant-snapstart" },
    @{ Name = "NonPerformant"; Path = "non-performant" }
)

New-Item -Path $ResultsDir -ItemType Directory -Force | Out-Null

function Write-ColoredOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Write-Header {
    Write-ColoredOutput "================================================================" -Color Magenta
    Write-ColoredOutput "              Batch Load Testing - Multiple Scenarios         " -Color Magenta
    Write-ColoredOutput "                .NET Lambda SnapStart Performance             " -Color Magenta
    Write-ColoredOutput "================================================================" -Color Magenta
    Write-Host ""
    Write-ColoredOutput "Test Scenarios:" -Color Cyan
    foreach ($scenario in $TestScenarios) {
        Write-ColoredOutput "  - $($scenario.Description): $($scenario.Requests) requests, $($scenario.Concurrency) concurrent" -Color Yellow
    }
    Write-Host ""
}

function Invoke-BatchTest {
    param(
        [int]$Requests,
        [int]$Concurrency,
        [string]$ScenarioName
    )
    
    $scenarioDir = Join-Path $ResultsDir "$($ScenarioName.Replace(' ', '_'))_$Timestamp"
    New-Item -Path $scenarioDir -ItemType Directory -Force | Out-Null
    
    Write-ColoredOutput "┌─────────────────────────────────────────────────────────────┐" -Color Blue
    Write-ColoredOutput "│ Scenario: $ScenarioName" -Color Blue
    Write-ColoredOutput "│ Requests: $Requests | Concurrency: $Concurrency" -Color Blue
    Write-ColoredOutput "└─────────────────────────────────────────────────────────────┘" -Color Blue
    
    $summaryFile = Join-Path $scenarioDir "scenario_summary.txt"
    @"
Batch Test Scenario: $ScenarioName
Requests: $Requests
Concurrency: $Concurrency
Timestamp: $(Get-Date)
PowerShell Version: $($PSVersionTable.PSVersion)
========================================

"@ | Out-File -FilePath $summaryFile -Encoding UTF8
    
    foreach ($endpoint in $Endpoints) {
        $url = "$BaseUrl/$($endpoint.Path)"
        $endpointFile = Join-Path $scenarioDir "$($endpoint.Path).txt"
        
        Write-ColoredOutput "  Testing $($endpoint.Name) ($($endpoint.Path))..." -Color Yellow
        
        # Run load test
        $jobs = @()
        $requestsPerJob = [Math]::Floor($Requests / $Concurrency)
        $remainingRequests = $Requests % $Concurrency
        
        $startTime = Get-Date
        
        for ($i = 0; $i -lt $Concurrency; $i++) {
            $jobRequests = $requestsPerJob
            if ($i -eq 0) { $jobRequests += $remainingRequests }
            
            $job = Start-Job -ScriptBlock {
                param($Url, $JobRequests)
                
                $results = @()
                for ($j = 0; $j -lt $JobRequests; $j++) {
                    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    try {
                        $response = Invoke-WebRequest -Uri $Url -Method POST -TimeoutSec 30
                        $stopwatch.Stop()
                        $results += @{
                            Success = $true
                            Duration = $stopwatch.ElapsedMilliseconds
                            StatusCode = $response.StatusCode
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
        
        # Wait for completion
        $allResults = @()
        foreach ($job in $jobs) {
            $jobResults = Receive-Job -Job $job -Wait
            $allResults += $jobResults
            Remove-Job -Job $job
        }
        
        $endTime = Get-Date
        $totalDuration = ($endTime - $startTime).TotalSeconds
        
        # Calculate metrics
        $successfulRequests = $allResults | Where-Object { $_.Success -eq $true }
        $failedRequests = $allResults | Where-Object { $_.Success -eq $false }
        
        $successCount = $successfulRequests.Count
        $failedCount = $failedRequests.Count
        
        if ($successCount -gt 0) {
            $durations = $successfulRequests | ForEach-Object { $_.Duration }
            $meanTime = ($durations | Measure-Object -Average).Average
            $requestsPerSecond = [Math]::Round($successCount / $totalDuration, 2)
            
            # Calculate percentiles
            $sortedDurations = $durations | Sort-Object
            $p50 = $sortedDurations[[Math]::Floor($sortedDurations.Count * 0.5)]
            $p95 = $sortedDurations[[Math]::Floor($sortedDurations.Count * 0.95)]
        }
        else {
            $meanTime = -1
            $requestsPerSecond = 0
            $p50 = -1
            $p95 = -1
        }
        
        Write-ColoredOutput "    Mean: $([Math]::Round($meanTime, 2))ms | RPS: $requestsPerSecond | Failed: $failedCount" -Color Green
        
        # Save detailed results
        @"
Load Test Results for: $($endpoint.Name)
Endpoint: $($endpoint.Path)
URL: $url
Scenario: $ScenarioName
Requests: $Requests
Concurrency: $Concurrency
Timestamp: $(Get-Date)
----------------------------------------

Total Duration: $([Math]::Round($totalDuration, 2)) seconds
Successful Requests: $successCount
Failed Requests: $failedCount
Requests per Second: $requestsPerSecond
Mean Response Time: $([Math]::Round($meanTime, 2)) ms
50th Percentile: $p50 ms
95th Percentile: $p95 ms
"@ | Out-File -FilePath $endpointFile -Encoding UTF8
        
        # Add to summary
        Add-Content -Path $summaryFile -Value @"
$($endpoint.Name) ($($endpoint.Path)):
  Mean Response Time: $([Math]::Round($meanTime, 2)) ms
  Requests/Second: $requestsPerSecond
  Failed Requests: $failedCount
  50th Percentile: $p50 ms
  95th Percentile: $p95 ms

"@
        
        Start-Sleep -Seconds 5  # Brief pause between endpoints
    }
    
    Write-ColoredOutput "  [SUCCESS] Scenario completed: $ScenarioName" -Color Green
    Write-Host ""
}

function New-ComparisonReport {
    $reportFile = Join-Path $ResultsDir "batch_comparison_$Timestamp.txt"
    
    Write-ColoredOutput "Generating batch comparison report..." -Color Blue
    
    $report = @"
Batch Load Testing Comparison Report
Generated: $(Get-Date)
PowerShell Version: $($PSVersionTable.PSVersion)
======================================

"@
    
    # Create comparison table header
    $header = "Scenario/Endpoint".PadRight(20)
    foreach ($endpoint in $Endpoints) {
        $header += " | " + $endpoint.Name.PadRight(15)
    }
    $report += $header + "`n"
    
    # Add separator line
    $separator = "-" * 20
    foreach ($endpoint in $Endpoints) {
        $separator += " | " + ("-" * 15)
    }
    $report += $separator + "`n"
    
    # Add data rows
    foreach ($scenario in $TestScenarios) {
        $scenarioDir = Join-Path $ResultsDir "$($scenario.Description.Replace(' ', '_'))_$Timestamp"
        
        $row = $scenario.Description.PadRight(20)
        
        foreach ($endpoint in $Endpoints) {
            $endpointFile = Join-Path $scenarioDir "$($endpoint.Path).txt"
            
            if (Test-Path $endpointFile) {
                $content = Get-Content $endpointFile -Raw
                if ($content -match "Mean Response Time: ([\d.]+) ms") {
                    $meanTime = $matches[1]
                    $row += " | " + "${meanTime}ms".PadRight(15)
                } else {
                    $row += " | " + "N/A".PadRight(15)
                }
            } else {
                $row += " | " + "N/A".PadRight(15)
            }
        }
        $report += $row + "`n"
    }
    
    $report += @"

Notes:
- All times in milliseconds (mean response time)
- Lower numbers indicate better performance
"@
    
    $report | Out-File -FilePath $reportFile -Encoding UTF8
    Write-ColoredOutput "[SUCCESS] Comparison report generated: $reportFile" -Color Green
}

function Main {
    Write-Header
    
    if ($BaseUrl -eq "<known_after_deployment>") {
        Write-ColoredOutput "Warning: Please replace <known_after_deployment> with your actual API Gateway URL" -Color Red
        Write-ColoredOutput "Usage: .\batch-load-test.ps1 -BaseUrl 'https://your-api-gateway-url.amazonaws.com/Prod'" -Color Yellow
        return
    }
    
    Write-ColoredOutput "Starting batch load testing..." -Color Cyan
    Write-Host ""
    
    # Run all test scenarios
    for ($i = 0; $i -lt $TestScenarios.Count; $i++) {
        $scenario = $TestScenarios[$i]
        Invoke-BatchTest -Requests $scenario.Requests -Concurrency $scenario.Concurrency -ScenarioName $scenario.Description
        
        # Wait between scenarios for system recovery
        if ($i -lt ($TestScenarios.Count - 1)) {
            Write-ColoredOutput "Waiting 60 seconds before next scenario..." -Color Cyan
            Start-Sleep -Seconds 60
        }
    }
    
    New-ComparisonReport
    
    Write-ColoredOutput "================================================================" -Color Magenta
    Write-ColoredOutput "                Batch Load Testing Complete!                  " -Color Magenta
    Write-ColoredOutput "================================================================" -Color Magenta
    Write-Host ""
    Write-ColoredOutput "All results saved in: $ResultsDir" -Color Green
    Write-ColoredOutput "View comparison report:" -Color Cyan
    Write-ColoredOutput "  Get-Content $ResultsDir\batch_comparison_$Timestamp.txt" -Color Yellow
    Write-Host ""
    Write-ColoredOutput "Batch testing completed successfully!" -Color Green
}

# Handle interruption gracefully
trap {
    Write-ColoredOutput "`nBatch testing interrupted" -Color Red
    exit 1
}

Main
