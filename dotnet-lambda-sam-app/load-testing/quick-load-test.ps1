# Quick Load Test Script - PowerShell version for rapid testing
# Usage: .\quick-load-test.ps1 [-Requests <int>] [-Concurrency <int>] [-BaseUrl <string>]

param(
    [int]$Requests = 100,     # Default 100 requests if not specified
    [int]$Concurrency = 10,   # Default 10 concurrent if not specified
    [string]$BaseUrl = "<known_after_deployment>"
)

$ErrorActionPreference = "Stop"

# Endpoints in performance order (best to worst expected)
$Endpoints = @(
    @{ Name = "OptimizedSnapStart"; Path = "optimized-snapstart" },
    @{ Name = "Optimized"; Path = "optimized" },
    @{ Name = "Original"; Path = "update-counter" },
    @{ Name = "NonPerf+SnapStart"; Path = "non-performant-snapstart" },
    @{ Name = "NonPerformant"; Path = "non-performant" }
)

function Write-ColoredOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColoredOutput "Quick Load Test - .NET Lambda SnapStart Performance" -Color Blue
Write-ColoredOutput "Requests: $Requests | Concurrency: $Concurrency" -Color Cyan

if ($BaseUrl -eq "<known_after_deployment>") {
    Write-ColoredOutput "Warning: Please replace <known_after_deployment> with your actual API Gateway URL" -Color Red
    Write-ColoredOutput "Usage: .\quick-load-test.ps1 -BaseUrl 'https://your-api-gateway-url.amazonaws.com/Prod'" -Color Yellow
    exit 1
}

Write-Host ""

foreach ($endpoint in $Endpoints) {
    $url = "$BaseUrl/$($endpoint.Path)"
    
    Write-ColoredOutput "Testing $($endpoint.Name) ($($endpoint.Path))..." -Color Yellow
    
    # Run quick test
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
    
    # Wait for completion and collect results
    $allResults = @()
    foreach ($job in $jobs) {
        $jobResults = Receive-Job -Job $job -Wait
        $allResults += $jobResults
        Remove-Job -Job $job
    }
    
    $endTime = Get-Date
    $totalDuration = ($endTime - $startTime).TotalSeconds
    
    # Calculate statistics
    $successfulRequests = $allResults | Where-Object { $_.Success -eq $true }
    $failedRequests = $allResults | Where-Object { $_.Success -eq $false }
    
    $successCount = $successfulRequests.Count
    $failedCount = $failedRequests.Count
    
    if ($successCount -gt 0) {
        $durations = $successfulRequests | ForEach-Object { $_.Duration }
        $meanTime = ($durations | Measure-Object -Average).Average
        $requestsPerSecond = [Math]::Round($successCount / $totalDuration, 2)
        
        Write-Host "  Requests per second: $requestsPerSecond"
        Write-Host "  Time per request (mean): $([Math]::Round($meanTime, 2)) ms"
        Write-Host "  Failed requests: $failedCount"
    }
    else {
        Write-Host "  All requests failed!"
    }
    
    Write-Host ""
    
    # Brief pause between tests
    Start-Sleep -Seconds 5
}

Write-ColoredOutput "[SUCCESS] Quick load testing complete!" -Color Green
