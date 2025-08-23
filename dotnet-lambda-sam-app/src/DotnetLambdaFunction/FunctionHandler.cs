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
    }

    [Logging(LogEvent = true)]
    [Metrics(CaptureColdStart = true)]
    [Tracing(CaptureMode = TracingCaptureMode.ResponseAndError)]
    [LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]
    public async Task<APIGatewayProxyResponse> HandleAsync(APIGatewayProxyRequest request, ILambdaContext context)
    {
        Logger.LogInformation("Processing counter update request.");
        var counterValue = await UpdateCounterAsync();
        Metrics.AddMetric("CounterValue", counterValue, MetricUnit.Count);
        Logger.LogInformation($"Counter updated to: {counterValue}");

        return new APIGatewayProxyResponse
        {
            StatusCode = 200,
            Headers = new Dictionary<string, string> { { "Content-Type", "application/json" } },
            Body = $"{{\"counter\":{counterValue}}}"
        };
    }

    [Tracing(SegmentName = "UpdateCounter")]
    private async Task<int> UpdateCounterAsync()
    {
        var table = Table.LoadTable(_dynamoDbClient, TableName);
        var counterKey = "Counter";
        var document = await table.GetItemAsync(counterKey);
        var currentCount = document != null ? document["Count"].AsInt() : 0;
        currentCount++;

        await table.PutItemAsync(new Document
        {
            ["Counter"] = counterKey,
            ["Count"] = currentCount
        });

        Logger.LogInformation($"Counter updated to: {currentCount}");
        return currentCount;
    }
}