using System;
using System.Collections.Generic;
using System.Net;
using System.Text.Json;
using System.Threading.Tasks;
using System.Reflection.Emit;
using System.Reflection;
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

namespace NonPerformantSnapStartLambda;

public class FunctionHandler
{
    private readonly IAmazonDynamoDB _dynamoDbClient;
    private readonly IAmazonS3 _s3Client;
    private readonly IAmazonSQS _sqsClient;
    private readonly IAmazonSecretsManager _secretsClient;
    private readonly IAmazonCloudWatch _cloudWatchClient;
    private const string TableName = "CounterTable";

    public FunctionHandler()
    {
        Logger.LogInformation("NonPerformantSnapStartLambda - Initializing with SnapStart but still using instance clients (suboptimal pattern)");
        
        // Initialize multiple AWS service clients during SnapStart initialization
        // NOTE: This is suboptimal for SnapStart - should use static clients instead
        _dynamoDbClient = new AmazonDynamoDBClient();
        _s3Client = new AmazonS3Client();
        _sqsClient = new AmazonSQSClient();
        _secretsClient = new AmazonSecretsManagerClient();
        _cloudWatchClient = new AmazonCloudWatchClient();
        
        // Perform some initialization work that will be captured by SnapStart
        InitializeDuringSnapStart();
        
        Logger.LogInformation("NonPerformantSnapStartLambda - Initialization completed with SnapStart but suboptimal patterns");
    }

    private void InitializeDuringSnapStart()
    {
        try
        {
            // Pre-warm services during SnapStart (this will be snapshot)
            _ = _dynamoDbClient.Config.RegionEndpoint;
            _ = _s3Client.Config.RegionEndpoint;
            _ = _sqsClient.Config.RegionEndpoint;
            
            Logger.LogInformation("SnapStart initialization completed for NonPerformant Lambda");
        }
        catch (Exception ex)
        {
            Logger.LogError($"Error during SnapStart initialization: {ex.Message}");
        }
    }

    [Logging(LogEvent = true, LoggerOutputCase = LoggerOutputCase.CamelCase)]
    [Metrics(CaptureColdStart = true, Namespace = "NonPerformantSnapStartFunction")]
    [Tracing(CaptureMode = TracingCaptureMode.ResponseAndError, SegmentName = "NonPerformantSnapStartHandler")]
    [LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]
    public async Task<APIGatewayProxyResponse> HandleAsync(APIGatewayProxyRequest request, ILambdaContext context)
    {
        // using var activity = Logger.BeginScope();
        Logger.AppendKey("functionName", context.FunctionName);
        Logger.AppendKey("functionVersion", context.FunctionVersion);
        Logger.AppendKey("requestId", context.AwsRequestId);
        Logger.AppendKey("lambdaType", "NonPerformantSnapStartFunction");
        Logger.AppendKey("snapStartEnabled", "true");
        Logger.AppendKey("performanceProfile", "Suboptimal-SnapStart");
        
        Logger.LogInformation("Processing SnapStart enabled but suboptimal lambda request");
        
        try
        {
            var startTime = DateTime.UtcNow;
            
            // Still perform dynamic code generation (JIT will happen after SnapStart)
            var dynamicResult = GenerateDynamicCode();
            
            // Use multiple AWS services
            await SimulateMultipleAwsOperations();
            
            var counterValue = await UpdateCounterAsync();
            
            var processingTime = (DateTime.UtcNow - startTime).TotalMilliseconds;
            
            // Enhanced metrics
            Metrics.AddMetric("CounterValue", counterValue, MetricUnit.Count);
            Metrics.AddMetric("DynamicResult", dynamicResult, MetricUnit.Count);
            Metrics.AddMetric("ProcessingTime", processingTime, MetricUnit.Milliseconds);
            Metrics.AddMetric("ExecutionDuration", context.RemainingTime.TotalMilliseconds, MetricUnit.Milliseconds);
            Metrics.AddMetadata("lambdaType", "NonPerformantSnapStartFunction");
            Metrics.AddMetadata("snapStartEnabled", "true");
            Metrics.AddMetadata("performanceProfile", "Suboptimal-SnapStart");
            Metrics.AddMetadata("coldStart", IsColdStart().ToString());
            Metrics.AddMetadata("instanceClientsUsed", "true");
            Metrics.AddMetadata("dynamicCodeGeneration", "true");
            
            Logger.LogInformation("Suboptimal SnapStart request completed", new { 
                counter = counterValue, 
                dynamicResult = dynamicResult,
                processingTime = processingTime,
                lambdaType = "NonPerformantSnapStartFunction",
                snapStartEnabled = true,
                performanceProfile = "Suboptimal-SnapStart"
            });

            return new APIGatewayProxyResponse
            {
                StatusCode = 200,
                Headers = new Dictionary<string, string> { 
                    { "Content-Type", "application/json" },
                    { "X-Lambda-Type", "NonPerformantSnapStartFunction" },
                    { "X-SnapStart-Enabled", "true" },
                    { "X-Performance-Profile", "Suboptimal-SnapStart" }
                },
                Body = JsonSerializer.Serialize(new { 
                    counter = counterValue, 
                    dynamicResult = dynamicResult,
                    lambdaType = "NonPerformantSnapStart",
                    snapStartEnabled = true,
                    processingTime = processingTime,
                    timestamp = DateTime.UtcNow
                })
            };
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "Error processing suboptimal SnapStart request");
            Metrics.AddMetric("ErrorCount", 1, MetricUnit.Count);
            
            return new APIGatewayProxyResponse
            {
                StatusCode = 500,
                Headers = new Dictionary<string, string> { { "Content-Type", "application/json" } },
                Body = JsonSerializer.Serialize(new { 
                    error = "Internal server error", 
                    lambdaType = "NonPerformantSnapStartFunction",
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

    private int GenerateDynamicCode()
    {
        // This dynamic compilation will still happen at runtime even with SnapStart
        var dynamicMethod = new DynamicMethod(
            "MultiplyNumbers", 
            typeof(int), 
            new[] { typeof(int), typeof(int) },
            typeof(FunctionHandler));

        var il = dynamicMethod.GetILGenerator();
        il.Emit(OpCodes.Ldarg_0);
        il.Emit(OpCodes.Ldarg_1);
        il.Emit(OpCodes.Mul);
        il.Emit(OpCodes.Ret);

        var multiplyDelegate = (Func<int, int, int>)dynamicMethod.CreateDelegate(typeof(Func<int, int, int>));
        
        // Perform reflection-based operations
        var type = GetType();
        var methods = type.GetMethods(BindingFlags.Public | BindingFlags.Instance);
        
        return multiplyDelegate(methods.Length, DateTime.Now.Second % 10 + 1);
    }

    private async Task SimulateMultipleAwsOperations()
    {
        var tasks = new List<Task>();
        
        // These will benefit from SnapStart client initialization
        tasks.Add(Task.Run(async () => {
            try { 
                await _s3Client.ListBucketsAsync(); 
                Logger.LogInformation("S3 ListBuckets called");
            } catch { }
        }));
        
        tasks.Add(Task.Run(async () => {
            try { 
                await _sqsClient.ListQueuesAsync(new Amazon.SQS.Model.ListQueuesRequest()); 
                Logger.LogInformation("SQS ListQueues called");
            } catch { }
        }));
        
        tasks.Add(Task.Run(async () => {
            try { 
                await _cloudWatchClient.ListMetricsAsync(new Amazon.CloudWatch.Model.ListMetricsRequest()); 
                Logger.LogInformation("CloudWatch ListMetrics called");
            } catch { }
        }));

        await Task.WhenAny(Task.WhenAll(tasks), Task.Delay(1000)); // Timeout after 1 second
    }

    [Tracing(SegmentName = "UpdateCounter")]
    private async Task<int> UpdateCounterAsync()
    {
        var table = Table.LoadTable(_dynamoDbClient, TableName);
        var counterKey = "NonPerformantSnapStartCounter";
        var document = await table.GetItemAsync(counterKey);
        var currentCount = document != null ? document["Count"].AsInt() : 0;
        currentCount++;

        await table.PutItemAsync(new Document
        {
            ["Counter"] = counterKey,
            ["Count"] = currentCount,
            ["LastUpdated"] = DateTime.UtcNow.ToString("O"),
            ["LambdaType"] = "NonPerformantSnapStart",
            ["SnapStartEnabled"] = true
        });

        Logger.LogInformation($"NonPerformant SnapStart counter updated to: {currentCount}");
        return currentCount;
    }
}
