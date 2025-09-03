# .NET Lambda SnapStart Performance Demonstration

[![Deploy Status](https://img.shields.io/badge/Deploy-Success-green)]
[![.NET](https://img.shields.io/badge/.NET-8.0-blue)]
[![AWS Lambda](https://img.shields.io/badge/AWS-Lambda-orange)]
[![SnapStart](https://img.shields.io/badge/AWS-SnapStart-yellow)]

A comprehensive demonstration project showcasing .NET Lambda performance optimization techniques and AWS Lambda SnapStart benefits. This project creates 5 different Lambda functions with varying optimization strategies to demonstrate cold start performance differences.

## 🎯 Project Overview

This project demonstrates how different optimization approaches affect .NET Lambda cold start performance:

1. **Original Function** - Basic optimized Lambda
2. **NonPerformant** - Worst-case scenario with dynamic compilation  
3. **Optimized** - Best practices without SnapStart
4. **NonPerformant + SnapStart** - SnapStart with bottlenecks
5. **Optimized + SnapStart** - Maximum performance with SnapStart

## 🏗️ Architecture

```text
API Gateway → 5 Lambda Functions → DynamoDB
├── /update-counter          → DotnetLambdaFunction (Original)
├── /non-performant         → NonPerformantLambda  
├── /optimized              → OptimizedLambda
├── /non-performant-snapstart → NonPerformantSnapStartLambda
└── /optimized-snapstart    → OptimizedSnapStartLambda
```

## 📁 Project Structure

```text
dotnet-lambda-sam-app/
├── src/
│   ├── DotnetLambdaFunction/           # Original function
│   ├── NonPerformantLambda/            # Dynamic compilation demo
│   ├── OptimizedLambda/                # Optimization best practices
│   ├── NonPerformantSnapStartLambda/   # SnapStart with bottlenecks
│   └── OptimizedSnapStartLambda/       # Maximum performance
├── load-testing/                       # Load testing scripts
│   ├── load-test.ps1                   # Comprehensive load testing (PowerShell)
│   ├── quick-load-test.ps1             # Rapid testing (PowerShell)
│   ├── batch-load-test.ps1             # Multi-scenario testing (PowerShell)
│   ├── load-test.zsh                   # Comprehensive load testing (macOS)
│   ├── quick-load-test.zsh             # Rapid testing (macOS)
│   ├── batch-load-test.zsh             # Multi-scenario testing (macOS)
│   ├── load-test.config                # Configuration file
│   └── LOAD_TESTING.md                 # Load testing guide
├── template.yml                        # SAM Infrastructure
├── PERFORMANCE_TESTING.md              # Detailed testing guide
└── DEPLOYMENT_STATUS.md                # Live endpoints
```

## 🚀 Quick Start

### Prerequisites

- .NET 8.0 SDK
- AWS CLI configured
- AWS SAM CLI
- PowerShell (Windows) or bash

### 1. Clone and Build

```bash
git clone https://github.com/pawelpiwosz/aws-dotnet-snapstart.git
cd aws-dotnet-snapstart/dotnet-lambda-sam-app
sam build
```

### 2. Deploy

```bash
sam deploy --guided
```

### 3. Test Performance

Use the endpoints from deployment output:

```bash
# Test each endpoint and measure cold start times
curl -X POST https://your-api-gateway-url/Prod/optimized-snapstart
curl -X POST https://your-api-gateway-url/Prod/non-performant
# ... (see PERFORMANCE_TESTING.md for detailed tests)
```

## 📊 Expected Performance Results

| Function | Cold Start Time | Optimization Level | SnapStart |
|----------|----------------|-------------------|-----------|
| NonPerformant | ~5-8 seconds | None | ❌ |
| Original | ~2-3 seconds | Basic | ❌ |
| Optimized | ~1-2 seconds | High | ❌ |
| NonPerformant + SnapStart | ~3-4 seconds | None | ✅ |
| **Optimized + SnapStart** | **~0.5-1 second** | **Maximum** | ✅ |

## 🔬 Key Learning Points

### Performance Optimization Techniques

1. **Static Client Initialization** - Initialize AWS clients once, not per request
2. **ReadyToRun Compilation** - Pre-JIT compilation for faster startup
3. **Minimal Dependencies** - Reduce assembly loading overhead
4. **SnapStart Configuration** - Proper alias setup and static constructors

### Anti-Patterns Demonstrated

1. **Dynamic Compilation** - Using `System.Reflection.Emit` at runtime
2. **Per-Request Client Creation** - Recreating AWS clients for each request
3. **Heavy Computation in Constructor** - Blocking SnapStart benefits
4. **Excessive Reflection** - Runtime type inspection overhead

## 📚 Documentation

- **[PERFORMANCE_TESTING.md](PERFORMANCE_TESTING.md)** - Comprehensive testing guide with specific scenarios
- **[DEPLOYMENT_STATUS.md](DEPLOYMENT_STATUS.md)** - Live endpoint URLs and status  
- **[load-testing/LOAD_TESTING.md](load-testing/LOAD_TESTING.md)** - Load testing scripts for macOS with Apache Bench
- **Individual Function READMEs** - Detailed explanation of each optimization approach

## 🛠️ Development

### Adding New Functions

1. Create new function in `src/NewFunction/`
2. Add function definition to `template.yml`
3. Update endpoints in documentation
4. Run `sam build && sam deploy`

### Local Testing

```bash
# Start local API Gateway
sam local start-api

# Test individual functions
sam local invoke OptimizedSnapStartLambda
```

## 🎓 Educational Value

This project is perfect for:

- **Learning .NET Lambda optimization** - Real working examples
- **Understanding SnapStart benefits** - Side-by-side comparisons  
- **Performance testing methodology** - Structured approach to cold start analysis
- **AWS SAM best practices** - Infrastructure as Code with multiple functions

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add new optimization techniques or test scenarios
4. Submit a pull request

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

This project demonstrates real-world .NET Lambda optimization patterns and serves as a practical guide for improving serverless application performance.
