using Amazon.Lambda.Core;
using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.DocumentModel;
using System.Threading.Tasks;

[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace DotnetLambdaFunction
{
    public class Function
    {
        private readonly IAmazonDynamoDB _dynamoDbClient;
        private const string TableName = "CounterTable";

        public Function()
        {
            _dynamoDbClient = new AmazonDynamoDBClient();
        }

        public async Task FunctionHandler(ILambdaContext context)
        {
            var table = Table.LoadTable(_dynamoDbClient, TableName);
            var counterKey = "Counter";

            var counterItem = await table.GetItemAsync(counterKey);
            int currentCount = counterItem != null ? counterItem["Count"].AsInt() : 0;

            currentCount++;
            var updatedItem = new Document
            {
                ["Id"] = counterKey,
                ["Count"] = currentCount
            };

            await table.PutItemAsync(updatedItem);
        }
    }
}