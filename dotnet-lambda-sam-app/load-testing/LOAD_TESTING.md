# 🚀 Load Testing Scripts for .NET Lambda SnapStart

This directory contains comprehensive load testing scripts to measure the performance differences between various .NET Lambda optimization strategies. Available in both **PowerShell** (Windows/Cross-platform) and **zsh/bash** (macOS/Linux) versions.

## 📋 Available Scripts

### PowerShell Scripts (Windows/Cross-platform)

#### 1. `load-test.ps1` - Comprehensive Load Testing (PowerShell)

The main PowerShell script that performs thorough load testing with detailed reporting.

**Features:**
- Tests all 5 Lambda endpoints
- Configurable request counts and concurrency via parameters
- Detailed results with statistics and percentiles
- Performance comparison charts
- Comprehensive summary reports
- Colored output and progress indicators
- PowerShell 5.1+ and PowerShell Core 7+ support

**Usage:**
```powershell
cd load-testing

# Default: 1000 requests, 25 concurrent
.\load-test.ps1 -BaseUrl "<known_after_deployment>"

# Custom parameters
.\load-test.ps1 -BaseUrl "<known_after_deployment>" -TotalRequests 500 -ConcurrentUsers 15
```

#### 2. `quick-load-test.ps1` - Rapid Testing (PowerShell)

Simplified PowerShell script for quick performance checks.

**Usage:**
```powershell
cd load-testing

# Default: 100 requests, 10 concurrent
.\quick-load-test.ps1 -BaseUrl "<known_after_deployment>"

# Custom: 200 requests, 20 concurrent
.\quick-load-test.ps1 -BaseUrl "<known_after_deployment>" -Requests 200 -Concurrency 20
```

#### 3. `batch-load-test.ps1` - Multi-Scenario Testing (PowerShell)

Runs multiple test scenarios with different load levels to understand performance scaling.

**Features:**
- Multiple load scenarios (Light, Medium, Heavy, Stress)
- Comparison table across all scenarios
- Performance scaling analysis

**Usage:**
```powershell
cd load-testing
.\batch-load-test.ps1 -BaseUrl "<known_after_deployment>"
```


### macOS/Linux Scripts (hey)

All zsh scripts now use [`hey`](https://github.com/rakyll/hey) for load testing. Install it with:
```bash
brew install hey
```

#### 1. `load-test.zsh` - Comprehensive Load Testing (macOS/Linux)

The main script that performs thorough load testing with detailed reporting using hey.

**Features:**
- Tests all 5 Lambda endpoints
- Configurable request counts and concurrency
- Detailed results with statistics
- Performance comparison charts
- Comprehensive summary reports
- Colored output and progress indicators

**Usage:**
```bash
cd load-testing
chmod +x load-test.zsh
./load-test.zsh --baseurl https://your-api-url
```

#### 2. `quick-load-test.zsh` - Rapid Testing (macOS/Linux)

Simplified script for quick performance checks using hey.

**Usage:**
```bash
cd load-testing
chmod +x quick-load-test.zsh

# Default: 100 requests, 10 concurrent
./quick-load-test.zsh --baseurl https://your-api-url

# Custom: 200 requests, 20 concurrent  
./quick-load-test.zsh --baseurl https://your-api-url 200 20
```

#### 3. `batch-load-test.zsh` - Multi-Scenario Testing (macOS/Linux)

Runs multiple test scenarios with different load levels to understand performance scaling using hey.

**Features:**
- Multiple load scenarios (Light, Medium, Heavy, Stress)
- Comparison table across all scenarios
- Performance scaling analysis

**Usage:**
```bash
cd load-testing
chmod +x batch-load-test.zsh
./batch-load-test.zsh --baseurl https://your-api-url
```

### Configuration Files

#### 4. `load-test.config` - Configuration File
Customize test parameters without modifying scripts (used by zsh scripts).

## 📦 Prerequisites

### For PowerShell Scripts (Windows/Cross-platform)
```powershell
# Check PowerShell version (requires 5.1+ or PowerShell Core 7+)
$PSVersionTable.PSVersion

# PowerShell scripts use built-in Invoke-WebRequest - no additional installation needed
```

### For macOS/Linux Scripts (Apache Bench)
```bash
# Install Apache Bench on macOS
brew install httpd

# Verify installation
ab -V
# Should show Apache Bench version information
```

## 🎯 Default Test Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| Total Requests | 1000 | Requests per endpoint |
| Concurrent Users | 25 | Simultaneous connections |
| Test Method | POST | HTTP method used |
| Content Type | application/json | Request content type |

## 📊 Test Scenarios

### Standard Load Test (`load-test.zsh`)

- **Light Load**: 1000 requests, 25 concurrent
- **Comprehensive reporting** with detailed metrics
- **Performance charts** and summaries

### Quick Test (`quick-load-test.zsh`)

- **Rapid Testing**: 100 requests, 10 concurrent (default)
- **Customizable** via command line parameters
- **Essential metrics** only

### Batch Testing (`batch-load-test.zsh`)

- **Light Load**: 100 requests, 5 concurrent
- **Medium Load**: 500 requests, 10 concurrent  
- **Heavy Load**: 1000 requests, 25 concurrent
- **Stress Test**: 1500 requests, 50 concurrent

## 📈 Expected Performance Results

Based on optimization levels, you should observe:

| Endpoint | Expected Performance | Load Handling |
|----------|---------------------|---------------|
| **optimized-snapstart** | ~500-1000ms | Excellent |
| **optimized** | ~1000-2000ms | Good |
| **update-counter** | ~2000-3000ms | Fair |
| **non-performant-snapstart** | ~3000-4000ms | Poor |
| **non-performant** | ~5000-8000ms | Very Poor |

## 📁 Output Files

All test results are saved in timestamped directories:

```text
load-test-results/
├── optimized-snapstart_20250903_142530.txt
├── optimized_20250903_142530.txt
├── update-counter_20250903_142530.txt
├── non-performant-snapstart_20250903_142530.txt
├── non-performant_20250903_142530.txt
├── load_test_summary_20250903_142530.txt
└── performance_comparison_20250903_142530.txt

batch-test-results/
├── Light_Load_20250903_143000/
├── Medium_Load_20250903_143000/
├── Heavy_Load_20250903_143000/
├── Stress_Test_20250903_143000/
└── batch_comparison_20250903_143000.txt
```

## 🔍 Interpreting Results

### Key Metrics to Watch

1. **Time per request (mean)** - Average response time
2. **Requests per second** - Throughput capacity  
3. **Failed requests** - Error rate under load
4. **Connection times** - Network performance
5. **Percentage served within X ms** - Latency distribution

### Performance Analysis

**Good Performance Indicators:**

- ✅ Low mean response time (< 1000ms)
- ✅ High requests per second (> 10 RPS)
- ✅ Zero or minimal failed requests (< 1%)
- ✅ Consistent performance across percentiles

**Performance Issues:**

- ❌ High mean response time (> 3000ms)  
- ❌ Low throughput (< 5 RPS)
- ❌ High failure rate (> 5%)
- ❌ Large variance between 50th and 95th percentiles

## 🛠 Customization

### Modify Test Parameters

Edit `load-test.config` or modify script variables:

```bash
# Example: Heavy load testing
TOTAL_REQUESTS=2000
CONCURRENT_USERS=50

# Example: Light load testing
TOTAL_REQUESTS=100  
CONCURRENT_USERS=5
```

### Custom Endpoints

Update the `ENDPOINTS` array in scripts to test specific functions:

```bash
ENDPOINTS=(
    "optimized-snapstart:Best Performance"
    "non-performant:Worst Performance"
)
```

## 📊 Sample Usage Workflow

### PowerShell (Windows/Cross-platform)

#### 1. Quick Health Check

```powershell
cd load-testing
# Test all endpoints with light load
.\quick-load-test.ps1 -BaseUrl "<known_after_deployment>" -Requests 50 -Concurrency 5
```

#### 2. Comprehensive Analysis

```powershell  
cd load-testing
# Full load testing with detailed reports
.\load-test.ps1 -BaseUrl "<known_after_deployment>"
```

#### 3. Scaling Analysis

```powershell
cd load-testing
# Multi-scenario testing to understand scaling
.\batch-load-test.ps1 -BaseUrl "<known_after_deployment>"
```

#### 4. Review Results

```powershell
# View latest summary
Get-ChildItem load-test-results\ | Sort-Object LastWriteTime
Get-Content load-test-results\load_test_summary_*.txt
```

### macOS/Linux (Apache Bench)

#### 1. Quick Health Check

```bash
cd load-testing
# Test all endpoints with light load
./quick-load-test.zsh 50 5
```

#### 2. Comprehensive Analysis

```bash  
cd load-testing
# Full load testing with detailed reports
./load-test.zsh
```

#### 3. Scaling Analysis

```bash
cd load-testing
# Multi-scenario testing to understand scaling
./batch-load-test.zsh
```

#### 4. Review Results

```bash
# View latest summary
ls -la load-test-results/
cat load-test-results/load_test_summary_*.txt
```

## 🚨 Important Notes

### AWS Lambda Considerations

- **Cold Starts**: First requests after idle periods will be slower
- **Concurrent Execution Limits**: AWS Lambda has account-level limits
- **Timeout Settings**: Lambda functions have maximum execution time limits
- **Regional Performance**: Test from the same region as deployment

### Load Testing Best Practices

- **Start Small**: Begin with light loads and increase gradually
- **Monitor AWS Costs**: Load testing generates billable requests
- **Warm-up Period**: Consider running warm-up requests before testing
- **Rate Limiting**: Respect API Gateway throttling limits

### Troubleshooting

**Common Issues:**

- **ab: command not found** - Install Apache Bench with `brew install httpd`
- **Connection refused** - Check if API Gateway endpoints are accessible
- **High failure rates** - May indicate Lambda concurrency limits or timeouts
- **Inconsistent results** - Network conditions or AWS load can affect results

## 🎯 Success Criteria

Your load testing should demonstrate:

- ✅ **OptimizedSnapStart** handles load better than other functions
- ✅ **Optimization techniques** show measurable improvements
- ✅ **SnapStart benefits** are visible under load conditions  
- ✅ **Performance scales** predictably with concurrency
- ✅ **Error rates** remain low (< 1%) under normal load

Use these scripts to validate your Lambda optimization strategies and understand real-world performance characteristics! 🚀
