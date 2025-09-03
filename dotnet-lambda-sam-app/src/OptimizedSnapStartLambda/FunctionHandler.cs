using System;
using System.Collections.Generic;
using System.Net;
using System.Text.Json;
using System.Threading.Tasks;
using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.DocumentModel;
using Amazon.S3;
using Amazon.SQS;
using Amazon.SecretsManager;
using Amazon.CloudWatch;
using Amazon.Lambda.Core;
using Amazon.Lambda.APIGatewayEvents;
using AWS.Lambda.Powertools.Logging;
using AWS.Lambda.Powertools.Metrics;
using AWS.Lambda.Powertools.Tracing;

namespace OptimizedSnapStartLambda;

public class FunctionHandler
{
    // Static clients for better SnapStart performance
    private static readonly IAmazonDynamoDB _dynamoDbClient;
    private static readonly IAmazonS3 _s3Client;
    private static readonly IAmazonSQS _sqsClient;
    private static readonly IAmazonSecretsManager _secretsClient;
    private static readonly IAmazonCloudWatch _cloudWatchClient;
    
    private const string TableName = "CounterTable";
    
    // Pre-computed values for optimal performance
    private static readonly DateTime _startTime;
    private static readonly int _precomputedValue;
    private static readonly string _precomputedTimestamp;

    // Static constructor for SnapStart optimization
    static FunctionHandler()
    {
        // Initialize all clients during SnapStart
        _dynamoDbClient = new AmazonDynamoDBClient();
        _s3Client = new AmazonS3Client();
        _sqsClient = new AmazonSQSClient();
        _secretsClient = new AmazonSecretsManagerClient();
        _cloudWatchClient = new AmazonCloudWatchClient();
        
        _startTime = DateTime.UtcNow;
        _precomputedValue = ComputeOptimalValueStatic();
        _precomputedTimestamp = DateTime.UtcNow.ToString("O");
        
        // Warm up JIT compilation during SnapStart
        _ = JsonSerializer.Serialize(new { warmup = true });
    }

    public FunctionHandler()
    {
        // Constructor runs after static initialization is complete
        // PowerTools is now properly initialized and can be used safely
        Logger.LogInformation("OptimizedSnapStartLambda - FunctionHandler initialized, using pre-warmed resources");
    }

    [Logging(LogEvent = true, LoggerOutputCase = LoggerOutputCase.CamelCase)]
    [Metrics(CaptureColdStart = true, Namespace = "OptimizedSnapStartFunction")]
    [Tracing(CaptureMode = TracingCaptureMode.ResponseAndError, SegmentName = "OptimizedSnapStartHandler")]
    [LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]
    public async Task<APIGatewayProxyResponse> HandleAsync(APIGatewayProxyRequest request, ILambdaContext context)
    {
        // using var activity = Logger.BeginScope();
        Logger.AppendKey("functionName", context.FunctionName);
        Logger.AppendKey("functionVersion", context.FunctionVersion);
        Logger.AppendKey("requestId", context.AwsRequestId);
        Logger.AppendKey("lambdaType", "OptimizedSnapStartFunction");
        Logger.AppendKey("snapStartEnabled", "true");
        
        Logger.LogInformation("Processing SnapStart optimized request with pre-warmed resources");
        
        try
        {
            // Use pre-computed values - no dynamic compilation
            var staticResult = GetOptimalResult();
            
            // Optimized AWS operations using pre-warmed clients
            await OptimalAwsOperations();
            
            var counterValue = await UpdateCounterAsync();
            
            // Enhanced metrics for SnapStart
            Metrics.AddMetric("CounterValue", counterValue, MetricUnit.Count);
            Metrics.AddMetric("StaticResult", staticResult, MetricUnit.Count);
            Metrics.AddMetric("ExecutionDuration", context.RemainingTime.TotalMilliseconds, MetricUnit.Milliseconds);
            Metrics.AddMetadata("lambdaType", "OptimizedSnapStartFunction");
            Metrics.AddMetadata("snapStartEnabled", "true");
            Metrics.AddMetadata("coldStart", IsColdStart().ToString());
            Metrics.AddMetadata("preWarmedClients", "true");
            
            Logger.LogInformation("SnapStart request processed successfully", new { 
                counter = counterValue, 
                staticResult = staticResult,
                lambdaType = "OptimizedSnapStartFunction",
                snapStartEnabled = true
            });

            // Use optimized response structure
            var response = new OptimalResponseData
            {
                Counter = counterValue,
                StaticResult = staticResult,
                LambdaType = "OptimizedSnapStart",
                SnapStartEnabled = true,
                Timestamp = DateTime.UtcNow,
                PrecomputedTimestamp = _precomputedTimestamp,
                InitializationTime = _startTime
            };

            return new APIGatewayProxyResponse
            {
                StatusCode = 200,
                Headers = new Dictionary<string, string> { 
                    { "Content-Type", "application/json" },
                    { "X-Lambda-Type", "OptimizedSnapStartFunction" },
                    { "X-SnapStart-Enabled", "true" }
                },
                Body = JsonSerializer.Serialize(response)
            };
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "Error processing SnapStart optimized request");
            Metrics.AddMetric("ErrorCount", 1, MetricUnit.Count);
            
            return new APIGatewayProxyResponse
            {
                StatusCode = 500,
                Headers = new Dictionary<string, string> { { "Content-Type", "application/json" } },
                Body = JsonSerializer.Serialize(new { 
                    error = "Internal server error", 
                    lambdaType = "OptimizedSnapStartFunction",
                    snapStartEnabled = true
                })
            };
        }
    }

    private static bool IsColdStart()
    {
        var isColdStart = Environment.GetEnvironmentVariable("AWS_LAMBDA_INITIALIZATION_TYPE") == "on-demand";
        return isColdStart;
    }

    [Tracing(SegmentName = "ComputeOptimalValue")]
    private static int ComputeOptimalValue()
    {
        // Compute at class initialization time for best performance
        var result = Environment.ProcessorCount * Environment.TickCount % 1000 + 42;
        
        Metrics.AddMetadata("processorCount", Environment.ProcessorCount.ToString());
        Metrics.AddMetadata("tickCount", Environment.TickCount.ToString());
        Metrics.AddMetadata("result", result.ToString());
        Metrics.AddMetadata("phase", "StaticInitialization");
        
        return result;
    }

    // Static version without PowerTools for use during static initialization
    private static int ComputeOptimalValueStatic()
    {
        // Compute at class initialization time for best performance
        return Environment.ProcessorCount * Environment.TickCount % 1000 + 42;
    }

    [Tracing(SegmentName = "GetOptimalResult")]
    private static int GetOptimalResult()
    {
        // Use cached pre-computed values
        var timeComponent = (DateTime.UtcNow - _startTime).Milliseconds % 100;
        var result = _precomputedValue + timeComponent;
        
        Metrics.AddMetadata("baseValue", _precomputedValue.ToString());
        Metrics.AddMetadata("timeComponent", timeComponent.ToString());
        Metrics.AddMetadata("result", result.ToString());
        Metrics.AddMetadata("initializationTime", _startTime.ToString("O"));
        Metrics.AddMetadata("precomputedTimestamp", _precomputedTimestamp);
        
        return result;
    }

    [Tracing(SegmentName = "GetOptimizedHeaders")]
    private static Dictionary<string, string> GetOptimizedHeaders()
    {
        // Pre-computed headers for performance
        var headers = new Dictionary<string, string> 
        { 
            { "Content-Type", "application/json" },
            { "X-Lambda-Type", "OptimizedSnapStart" },
            { "X-Optimization", "Maximum" },
            { "X-SnapStart-Prewarmed", "true" }
        };
        
        Metrics.AddMetadata("headerCount", headers.Count.ToString());
        Metrics.AddMetadata("optimized", "true");
        Metrics.AddMetadata("precomputed", "true");
        
        return headers;
    }

    [Tracing(SegmentName = "OptimalAwsOperations")]
    private static async Task OptimalAwsOperations()
    {
        // Minimal operations using pre-warmed static clients
        // These clients are already initialized and warmed up from SnapStart
        Metrics.AddMetadata("dynamodbPrewarmed", (_dynamoDbClient != null).ToString());
        Metrics.AddMetadata("s3Prewarmed", (_s3Client != null).ToString());
        Metrics.AddMetadata("sqsPrewarmed", (_sqsClient != null).ToString());
        Metrics.AddMetadata("secretsPrewarmed", (_secretsClient != null).ToString());
        Metrics.AddMetadata("cloudWatchPrewarmed", (_cloudWatchClient != null).ToString());
        Metrics.AddMetadata("allClientsReady", "true");
        Metrics.AddMetadata("optimization", "Maximum");
        
        await Task.CompletedTask; // No unnecessary operations
    }

    [Tracing(SegmentName = "DynamoDB-SnapStartOptimalUpdateCounter")]
    private static async Task<int> UpdateCounterAsync()
    {
        Logger.LogInformation("Starting SnapStart optimized counter update operation");
        
        try
        {
            var table = Table.LoadTable(_dynamoDbClient, TableName);
            var counterKey = "OptimizedSnapStartFunction";
            
            // Get current value with detailed SnapStart tracing
            int currentCount;
            {
                var document = await table.GetItemAsync(counterKey);
                currentCount = document?.ContainsKey("Count") == true ? document["Count"].AsInt() : 0;
                
                Metrics.AddMetadata("tableName", TableName);
                Metrics.AddMetadata("key", counterKey);
                Metrics.AddMetadata("found", (document != null).ToString());
                Metrics.AddMetadata("currentValue", currentCount.ToString());
                Metrics.AddMetadata("clientType", "StaticPrewarmed");
                Metrics.AddMetadata("snapStartEnabled", "true");
                Metrics.AddMetadata("optimization", "Maximum");
            }
            
            currentCount++;

            // Put updated value with comprehensive SnapStart tracing
            {
                var updateDocument = new Document
                {
                    ["Counter"] = counterKey,
                    ["Count"] = currentCount,
                    ["LastUpdated"] = DateTime.UtcNow.ToString("O"),
                    ["FunctionType"] = "OptimizedSnapStartFunction",
                    ["SnapStartEnabled"] = true,
                    ["OptimizationLevel"] = "Maximum",
                    ["ClientType"] = "StaticPrewarmed",
                    ["InitializationTime"] = _precomputedTimestamp
                };

                await table.PutItemAsync(updateDocument);
                
                Metrics.AddMetadata("tableName", TableName);
                Metrics.AddMetadata("key", counterKey);
                Metrics.AddMetadata("newValue", currentCount.ToString());
                Metrics.AddMetadata("previousValue", (currentCount - 1).ToString());
                Metrics.AddMetadata("functionType", "OptimizedSnapStartFunction");
                Metrics.AddMetadata("snapStartEnabled", "true");
                Metrics.AddMetadata("optimizationLevel", "Maximum");
                Metrics.AddMetadata("clientType", "StaticPrewarmed");
                Metrics.AddMetadata("initializationTime", _precomputedTimestamp);
            }

            Metrics.AddMetadata("operation", "SnapStartOptimalUpdate");
            Metrics.AddMetadata("previousCount", (currentCount - 1).ToString());
            Metrics.AddMetadata("newCount", currentCount.ToString());
            Metrics.AddMetadata("optimization", "Maximum");
            Metrics.AddMetadata("snapStartEnabled", "true");
            Metrics.AddMetadata("prewarmedClients", "true");

            Logger.LogInformation("SnapStart optimized counter update completed", new { 
                previousCount = currentCount - 1, 
                newCount = currentCount,
                snapStartEnabled = true,
                optimizationLevel = "Maximum"
            });
            
            Metrics.AddMetric("DynamoDBSnapStartOperation", 1, MetricUnit.Count);
            
            return currentCount;
        }
        catch (Exception ex)
        {
            Metrics.AddMetadata("message", ex.Message);
            Metrics.AddMetadata("type", ex.GetType().Name);
            Metrics.AddMetadata("stackTrace", ex.StackTrace);
            Metrics.AddMetadata("snapStartEnabled", "true");
            Metrics.AddMetadata("optimizationLevel", "Maximum");
            
            Logger.LogError(ex, "Error updating counter in SnapStart optimized function");
            Metrics.AddMetric("DynamoDBSnapStartError", 1, MetricUnit.Count);
            throw;
        }
    }

    // Optimal response structure
    private readonly struct OptimalResponseData
    {
        public int Counter { get; init; }
        public int StaticResult { get; init; }
        public string LambdaType { get; init; }
        public DateTime Timestamp { get; init; }
        public bool SnapStartEnabled { get; init; }
        public string OptimizationLevel { get; init; }
        public string PrecomputedTimestamp { get; init; }
        public DateTime InitializationTime { get; init; }
    }
}
