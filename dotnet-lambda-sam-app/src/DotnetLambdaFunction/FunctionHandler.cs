using System;
using System.Collections.Generic;
using System.Net;
using System.Text.Json;
using System.Threading.Tasks;
using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.DocumentModel;
using Amazon.Lambda.APIGatewayEvents;
using Amazon.Lambda.Core;
using AWS.Lambda.Powertools.Logging;
using AWS.Lambda.Powertools.Metrics;
using AWS.Lambda.Powertools.Tracing;

namespace DotnetLambdaFunction;

public class FunctionHandler
{
    private readonly IAmazonDynamoDB _dynamoDbClient;
    private const string TableName = "CounterTable";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private record CounterResponse(int Counter);
    private record ErrorResponse(string Error);

    public FunctionHandler()
    {
        _dynamoDbClient = new AmazonDynamoDBClient();
        Logger.LogInformation("BasicFunction - FunctionHandler initialized");
    }

    [Logging(LogEvent = true, LoggerOutputCase = LoggerOutputCase.CamelCase)]
    [Metrics(CaptureColdStart = true, Namespace = "BasicFunction")]
    [Tracing(CaptureMode = TracingCaptureMode.ResponseAndError, SegmentName = "BasicFunctionHandler")]
    [LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]
    public async Task<APIGatewayProxyResponse> HandleAsync(APIGatewayProxyRequest request, ILambdaContext context)
    {
        // using var activity = Logger.BeginScope(new {});
        Logger.AppendKey("functionName", context.FunctionName);
        Logger.AppendKey("functionVersion", context.FunctionVersion);
        Logger.AppendKey("requestId", context.AwsRequestId);
        Logger.AppendKey("lambdaType", "BasicFunction");
        
        Logger.LogInformation("Processing counter update request");
        
        try
        {
            var counterValue = await UpdateCounterAsync();
            
            // Add custom metrics
            Metrics.AddMetric("CounterValue", counterValue, MetricUnit.Count);
            Metrics.AddMetric("ExecutionDuration", context.RemainingTime.TotalMilliseconds, MetricUnit.Milliseconds);
            Metrics.AddMetadata("lambdaType", "BasicFunction");
            Metrics.AddMetadata("coldStart", IsColdStart().ToString());
            
            Logger.LogInformation("Counter updated successfully", new { counter = counterValue });

            return new APIGatewayProxyResponse
            {
                StatusCode = 200,
                Headers = new Dictionary<string, string> { 
                    { "Content-Type", "application/json" },
                    { "X-Lambda-Type", "BasicFunction" }
                },
                Body = JsonSerializer.Serialize(new { counter = counterValue, lambdaType = "BasicFunction" })
            };
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "Error processing request");
            Metrics.AddMetric("ErrorCount", 1, MetricUnit.Count);
            
            return new APIGatewayProxyResponse
            {
                StatusCode = 500,
                Headers = new Dictionary<string, string> { { "Content-Type", "application/json" } },
                Body = JsonSerializer.Serialize(new { error = "Internal server error" })
            };
        }
    }

    private static bool IsColdStart()
    {
        var isColdStart = Environment.GetEnvironmentVariable("AWS_LAMBDA_INITIALIZATION_TYPE") == "on-demand";
        return isColdStart;
    }

        [Tracing(SegmentName = "DynamoDB-UpdateCounter")]
    private async Task<int> UpdateCounterAsync()
    {
        Logger.LogInformation("Starting counter update operation");
        
        try
        {
            var table = Table.LoadTable(_dynamoDbClient, TableName);
            var counterKey = "BasicFunction";
            
            // Get current value
            var getItem = await table.GetItemAsync(counterKey);
            var currentCount = 0;
            
            if (getItem != null && getItem.ContainsKey("counter_value"))
            {
                currentCount = getItem["counter_value"].AsInt();
            }
            
            // Increment counter
            var newCount = currentCount + 1;
            
            // Update counter in DynamoDB
            var document = new Document
            {
                ["Counter"] = counterKey,
                ["counter_value"] = newCount,
                ["last_updated"] = DateTime.UtcNow.ToString("O"),
                ["lambda_type"] = "BasicFunction"
            };
            
            await table.PutItemAsync(document);
            
            Metrics.AddMetric("CounterUpdated", 1, MetricUnit.Count);
            Metrics.AddMetric("CounterValue", newCount, MetricUnit.Count);
            
            Logger.LogInformation("Counter update completed", new { 
                counterKey, 
                previousValue = currentCount, 
                newValue = newCount,
                lambdaType = "BasicFunction"
            });
            
            return newCount;
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "Error updating counter in DynamoDB");
            Metrics.AddMetric("CounterUpdateError", 1, MetricUnit.Count);
            throw;
        }
    }
}
