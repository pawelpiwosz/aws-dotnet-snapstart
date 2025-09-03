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

namespace NonPerformantLambda;

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
        Logger.LogInformation("NonPerformantLambda - Initializing multiple AWS clients (demonstrating cold start overhead)");
        
        // Initialize multiple AWS service clients (causes more cold start overhead)
        _dynamoDbClient = new AmazonDynamoDBClient();
        _s3Client = new AmazonS3Client();
        _sqsClient = new AmazonSQSClient();
        _secretsClient = new AmazonSecretsManagerClient();
        _cloudWatchClient = new AmazonCloudWatchClient();
        
        Logger.LogInformation("NonPerformantLambda - FunctionHandler initialization completed with performance penalties");
    }

    [Logging(LogEvent = true, LoggerOutputCase = LoggerOutputCase.CamelCase)]
    [Metrics(CaptureColdStart = true, Namespace = "NonPerformantFunction")]
    [Tracing(CaptureMode = TracingCaptureMode.ResponseAndError, SegmentName = "NonPerformantHandler")]
    [LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]
    public async Task<APIGatewayProxyResponse> HandleAsync(APIGatewayProxyRequest request, ILambdaContext context)
    {
        // using var activity = Logger.BeginScope(new {});
        Logger.AppendKey("functionName", context.FunctionName);
        Logger.AppendKey("functionVersion", context.FunctionVersion);
        Logger.AppendKey("requestId", context.AwsRequestId);
        Logger.AppendKey("lambdaType", "NonPerformantFunction");
        Logger.AppendKey("performanceProfile", "Intentionally-Slow");
        
        Logger.LogInformation("Processing non-performant request with dynamic compilation and multiple service initialization");
        
        try
        {
            var startTime = DateTime.UtcNow;
            
            // Perform dynamic code generation (JIT compilation overhead)
            var dynamicResult = GenerateDynamicCode();
            
            // Use multiple AWS services to increase cold start time
            await SimulateMultipleAwsOperations();
            
            var counterValue = await UpdateCounterAsync();
            
            var processingTime = (DateTime.UtcNow - startTime).TotalMilliseconds;
            
            // Enhanced metrics for performance analysis
            Metrics.AddMetric("CounterValue", counterValue, MetricUnit.Count);
            Metrics.AddMetric("DynamicResult", dynamicResult, MetricUnit.Count);
            Metrics.AddMetric("ProcessingTime", processingTime, MetricUnit.Milliseconds);
            Metrics.AddMetric("ExecutionDuration", context.RemainingTime.TotalMilliseconds, MetricUnit.Milliseconds);
            Metrics.AddMetadata("lambdaType", "NonPerformantFunction");
            Metrics.AddMetadata("performanceProfile", "Intentionally-Slow");
            Metrics.AddMetadata("coldStart", IsColdStart().ToString());
            Metrics.AddMetadata("multipleClientsUsed", "true");
            Metrics.AddMetadata("dynamicCodeGeneration", "true");
            
            Logger.LogInformation("Non-performant request completed", new { 
                counter = counterValue, 
                dynamicResult = dynamicResult,
                processingTime = processingTime,
                lambdaType = "NonPerformantFunction",
                performanceProfile = "Intentionally-Slow"
            });

            return new APIGatewayProxyResponse
            {
                StatusCode = 200,
                Headers = new Dictionary<string, string> { 
                    { "Content-Type", "application/json" },
                    { "X-Lambda-Type", "NonPerformantFunction" },
                    { "X-Performance-Profile", "Intentionally-Slow" }
                },
                Body = JsonSerializer.Serialize(new { 
                    counter = counterValue, 
                    dynamicResult = dynamicResult,
                    lambdaType = "NonPerformant",
                    processingTime = processingTime,
                    timestamp = DateTime.UtcNow
                })
            };
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "Error processing non-performant request");
            Metrics.AddMetric("ErrorCount", 1, MetricUnit.Count);
            
            return new APIGatewayProxyResponse
            {
                StatusCode = 500,
                Headers = new Dictionary<string, string> { { "Content-Type", "application/json" } },
                Body = JsonSerializer.Serialize(new { 
                    error = "Internal server error", 
                    lambdaType = "NonPerformantFunction"
                })
            };
        }
    }

    private static bool IsColdStart()
    {
        var isColdStart = Environment.GetEnvironmentVariable("AWS_LAMBDA_INITIALIZATION_TYPE") == "on-demand";
        return isColdStart;
    }

    [Tracing(SegmentName = "DynamicCodeGeneration")]
    private int GenerateDynamicCode()
    {        
        var startTime = DateTime.UtcNow;
        
        // Create dynamic method to simulate JIT compilation overhead
        var dynamicMethod = new DynamicMethod(
            "AddNumbers", 
            typeof(int), 
            new[] { typeof(int), typeof(int) },
            typeof(FunctionHandler));
            
        var ilGenerator = dynamicMethod.GetILGenerator();
        
        // Generate IL code
        ilGenerator.Emit(OpCodes.Ldarg_0);
        ilGenerator.Emit(OpCodes.Ldarg_1);
        ilGenerator.Emit(OpCodes.Add);
        ilGenerator.Emit(OpCodes.Ret);
        
        // Create delegate from dynamic method
        var addDelegate = (Func<int, int, int>)dynamicMethod.CreateDelegate(typeof(Func<int, int, int>));
        
        // Execute it multiple times to add CPU overhead
        var result = 0;
        for (int i = 0; i < 1000; i++)
        {
            result += addDelegate(i, i * 2);
        }
        
        var endTime = DateTime.UtcNow;
        var duration = endTime - startTime;
        
        Logger.LogDebug("Dynamic code generation completed", new {
            iterations = 1000,
            result = result,
            durationMs = duration.TotalMilliseconds
        });
        
        return result;
    }    [Tracing(SegmentName = "MultipleAwsOperations")]
    private async Task SimulateMultipleAwsOperations()
    {
        var startTime = DateTime.UtcNow;
        
        try
        {
            // These operations will likely fail but will initialize service clients
            await Task.Run(async () => {
                try { 
                    await _s3Client.ListBucketsAsync(); 
                } 
                catch (Exception ex) { 
                    // Ignore initialization errors
                }
                
                try { 
                    await _sqsClient.ListQueuesAsync(new Amazon.SQS.Model.ListQueuesRequest()); 
                } 
                catch (Exception ex) { 
                    // Ignore initialization errors
                }
                
                try { 
                    await _cloudWatchClient.ListMetricsAsync(new Amazon.CloudWatch.Model.ListMetricsRequest()); 
                } 
                catch (Exception ex) { 
                    // Ignore initialization errors
                }
            });
            
            var processingTime = (DateTime.UtcNow - startTime).TotalMilliseconds;
            
            Metrics.AddMetadata("processingTimeMs", processingTime);
            Metrics.AddMetadata("operationsAttempted", 3);
            Metrics.AddMetadata("performanceProfile", "Intentionally-Slow");
            Metrics.AddMetadata("clientsInitialized", new[] { "S3", "SQS", "CloudWatch" });
        }
        catch (Exception ex)
        {
            Logger.LogError("Error during client initialization: {Message}", ex.Message);
            Metrics.AddMetadata("error", new { message = ex.Message, type = ex.GetType().Name });
            // Ignore errors - we just want to trigger client initialization
        }
    }

    [Tracing(SegmentName = "UpdateCounter")]
    private async Task<int> UpdateCounterAsync()
    {
        var table = Table.LoadTable(_dynamoDbClient, TableName);
        var counterKey = "NonPerformantCounter";
        var document = await table.GetItemAsync(counterKey);
        var currentCount = document != null ? document["Count"].AsInt() : 0;
        currentCount++;

        await table.PutItemAsync(new Document
        {
            ["Counter"] = counterKey,
            ["Count"] = currentCount,
            ["LastUpdated"] = DateTime.UtcNow.ToString("O"),
            ["LambdaType"] = "NonPerformant"
        });

        Logger.LogInformation($"NonPerformant counter updated to: {currentCount}");
        return currentCount;
    }
}
