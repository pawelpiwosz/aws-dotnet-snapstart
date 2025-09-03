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

namespace OptimizedLambda;

public class FunctionHandler
{
    private static readonly IAmazonDynamoDB _dynamoDbClient = new AmazonDynamoDBClient();
    private static readonly IAmazonS3 _s3Client = new AmazonS3Client();
    private static readonly IAmazonSQS _sqsClient = new AmazonSQSClient();
    private static readonly IAmazonSecretsManager _secretsClient = new AmazonSecretsManagerClient();
    private static readonly IAmazonCloudWatch _cloudWatchClient = new AmazonCloudWatchClient();
    
    private const string TableName = "CounterTable";
    
    // Pre-computed values to avoid runtime computation
    private static readonly DateTime _startTime = DateTime.UtcNow;
    private static readonly int _precomputedValue = ComputeStaticValue();

    // Static constructor for one-time initialization
    static FunctionHandler()
    {
        Logger.LogInformation("OptimizedLambda - Static initialization starting");
        
        // Initialize clients once
        _ = _dynamoDbClient;
        _ = _s3Client;
        _ = _sqsClient;
        _ = _secretsClient;
        _ = _cloudWatchClient;
        
        Logger.LogInformation("OptimizedLambda - Static initialization completed");
    }

    public FunctionHandler()
    {
        Logger.LogInformation("OptimizedLambda - FunctionHandler initialized");
    }

    [Logging(LogEvent = true, LoggerOutputCase = LoggerOutputCase.CamelCase)]
    [Metrics(CaptureColdStart = true, Namespace = "OptimizedFunction")]
    [Tracing(CaptureMode = TracingCaptureMode.ResponseAndError, SegmentName = "OptimizedFunctionHandler")]
    [LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]
    public async Task<APIGatewayProxyResponse> HandleAsync(APIGatewayProxyRequest request, ILambdaContext context)
    {
        // using var activity = Logger.BeginScope();
        Logger.AppendKey("functionName", context.FunctionName);
        Logger.AppendKey("functionVersion", context.FunctionVersion);
        Logger.AppendKey("requestId", context.AwsRequestId);
        Logger.AppendKey("lambdaType", "OptimizedFunction");
        
        Logger.LogInformation("Processing optimized lambda request with pre-compiled code");
        
        try
        {
            // Use pre-computed values instead of dynamic generation
            var staticResult = GetPrecomputedResult();
            
            // Optimized AWS operations
            await OptimizedAwsOperations();
            
            var counterValue = await UpdateCounterAsync();
            
            // Enhanced metrics
            Metrics.AddMetric("CounterValue", counterValue, MetricUnit.Count);
            Metrics.AddMetric("StaticResult", staticResult, MetricUnit.Count);
            Metrics.AddMetric("ExecutionDuration", context.RemainingTime.TotalMilliseconds, MetricUnit.Milliseconds);
            Metrics.AddMetadata("lambdaType", "OptimizedFunction");
            Metrics.AddMetadata("coldStart", IsColdStart().ToString());
            Metrics.AddMetadata("staticClientsUsed", "true");
            
            Logger.LogInformation("Request processed successfully", new { 
                counter = counterValue, 
                staticResult = staticResult,
                lambdaType = "OptimizedFunction"
            });

            // Use struct for better performance
            var response = new ResponseData
            {
                Counter = counterValue,
                StaticResult = staticResult,
                LambdaType = "OptimizedFunction",
                Timestamp = DateTime.UtcNow
            };

            return new APIGatewayProxyResponse
            {
                StatusCode = 200,
                Headers = new Dictionary<string, string> { 
                    { "Content-Type", "application/json" },
                    { "X-Lambda-Type", "OptimizedFunction" }
                },
                Body = JsonSerializer.Serialize(response)
            };
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "Error processing optimized request");
            Metrics.AddMetric("ErrorCount", 1, MetricUnit.Count);
            
            return new APIGatewayProxyResponse
            {
                StatusCode = 500,
                Headers = new Dictionary<string, string> { { "Content-Type", "application/json" } },
                Body = JsonSerializer.Serialize(new { error = "Internal server error", lambdaType = "OptimizedFunction" })
            };
        }
    }

    private static bool IsColdStart()
    {
        var isColdStart = Environment.GetEnvironmentVariable("AWS_LAMBDA_INITIALIZATION_TYPE") == "on-demand";
        return isColdStart;
    }

    private static int ComputeStaticValue()
    {
        // Compute at compile time / class load time
        return Environment.ProcessorCount * 42;
    }

    [Tracing(SegmentName = "GetPrecomputedResult")]
    private int GetPrecomputedResult()
    {
        return _precomputedValue;
    }

    [Tracing(SegmentName = "PerformOptimizedCalculation")]
    private int PerformOptimizedCalculation()
    {
        // Use pre-computed values instead of dynamic code generation
        var timeComponent = (DateTime.UtcNow - _startTime).Milliseconds % 100;
        var result = _precomputedValue + timeComponent;
        
        Metrics.AddMetadata("baseValue", _precomputedValue);
        Metrics.AddMetadata("timeComponent", timeComponent);
        Metrics.AddMetadata("result", result);
        Metrics.AddMetadata("initializationTime", _startTime);
        
        return result;
    }

    [Tracing(SegmentName = "OptimizedAwsOperations")]
    private async Task OptimizedAwsOperations()
    {
        // Validate static clients are initialized (minimal overhead)
        Metrics.AddMetadata("dynamodbInitialized", _dynamoDbClient != null);
        Metrics.AddMetadata("s3Initialized", _s3Client != null);
        Metrics.AddMetadata("sqsInitialized", _sqsClient != null);
        Metrics.AddMetadata("secretsInitialized", _secretsClient != null);
        Metrics.AddMetadata("cloudWatchInitialized", _cloudWatchClient != null);
        
        await Task.CompletedTask; // No unnecessary API calls
    }

    [Tracing(SegmentName = "DynamoDB-OptimizedUpdateCounter")]
    private async Task<int> UpdateCounterAsync()
    {
        Logger.LogInformation("Starting optimized counter update operation");
        
        try
        {
            var table = Table.LoadTable(_dynamoDbClient, TableName);
            var counterKey = "OptimizedFunction";
            
            // Get current value
            var document = await table.GetItemAsync(counterKey);
            int currentCount = document?.ContainsKey("Count") == true ? document["Count"].AsInt() : 0;
            
            Metrics.AddMetadata("tableName", TableName);
            Metrics.AddMetadata("key", counterKey);
            Metrics.AddMetadata("found", document != null);
            Metrics.AddMetadata("currentValue", currentCount);
            Metrics.AddMetadata("clientType", "Static");
            Metrics.AddMetadata("optimization", "StaticClients");
            
            currentCount++;

            // Put updated value
            var updateDocument = new Document
            {
                ["Counter"] = counterKey,
                ["Count"] = currentCount,
                ["LastUpdated"] = DateTime.UtcNow.ToString("O"),
                ["FunctionType"] = "OptimizedFunction",
                ["OptimizationType"] = "StaticClients"
            };

            await table.PutItemAsync(updateDocument);
            
            Metrics.AddMetadata("newValue", currentCount);
            Metrics.AddMetadata("previousValue", currentCount - 1);
            Metrics.AddMetadata("functionType", "OptimizedFunction");
            Metrics.AddMetadata("optimizationType", "StaticClients");

            Logger.LogInformation("Optimized counter update completed", new { 
                previousCount = currentCount - 1, 
                newCount = currentCount,
                optimizationType = "StaticClients"
            });
            
            Metrics.AddMetric("DynamoDBOptimizedOperation", 1, MetricUnit.Count);
            
            return currentCount;
        }
        catch (Exception ex)
        {
            Metrics.AddMetadata("error", new {
                message = ex.Message,
                type = ex.GetType().Name,
                optimizationType = "StaticClients"
            });
            
            Logger.LogError("Error updating counter in optimized function: {Message}", ex.Message);
            Metrics.AddMetric("DynamoDBOptimizedError", 1, MetricUnit.Count);
            throw;
        }
    }

    // Using struct for better performance
    private struct ResponseData
    {
        public int Counter { get; set; }
        public int StaticResult { get; set; }
        public string LambdaType { get; set; }
        public DateTime Timestamp { get; set; }
    }
}
