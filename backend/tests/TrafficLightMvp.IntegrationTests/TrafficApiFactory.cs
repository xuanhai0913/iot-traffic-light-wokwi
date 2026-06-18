using System.Collections.Concurrent;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace TrafficLightMvp.IntegrationTests;

public sealed class TrafficApiFactory : WebApplicationFactory<Program>
{
    private readonly string testDirectory = Path.Combine(
        Path.GetTempPath(),
        "traffic-light-mvp-tests",
        Guid.NewGuid().ToString("N"));

    public string DatabasePath => Path.Combine(testDirectory, "traffic-test.db");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        Directory.CreateDirectory(testDirectory);

        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, configuration) =>
        {
            configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["TrafficDatabase:Path"] = DatabasePath,
                ["TrafficDatabase:SchemaPath"] = Path.Combine(AppContext.BaseDirectory, "schema.sql")
            });
        });
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<MqttBridgeOptions>();
            services.AddSingleton(new MqttBridgeOptions(
                Enabled: false,
                Host: "test-broker.invalid",
                Port: 1883,
                ClientId: "traffic-integration-tests",
                TopicPrefix: "traffic/integration-tests",
                Username: null,
                Password: null));

            services.RemoveAll<ITrafficCommandPublisher>();
            services.AddSingleton<RecordingCommandPublisher>();
            services.AddSingleton<ITrafficCommandPublisher>(
                provider => provider.GetRequiredService<RecordingCommandPublisher>());
        });
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);

        if (disposing && Directory.Exists(testDirectory))
        {
            for (var attempt = 0; attempt < 5; attempt++)
            {
                try
                {
                    Directory.Delete(testDirectory, recursive: true);
                    return;
                }
                catch (IOException) when (attempt < 4)
                {
                    GC.Collect();
                    GC.WaitForPendingFinalizers();
                    Thread.Sleep(100);
                }
                catch (UnauthorizedAccessException) when (attempt < 4)
                {
                    GC.Collect();
                    GC.WaitForPendingFinalizers();
                    Thread.Sleep(100);
                }
                catch (IOException)
                {
                    return;
                }
                catch (UnauthorizedAccessException)
                {
                    return;
                }
            }
        }
    }
}

public sealed class RecordingCommandPublisher : ITrafficCommandPublisher
{
    private readonly ConcurrentQueue<MqttCommandMessage> commands = new();

    public IReadOnlyCollection<MqttCommandMessage> Commands => commands.ToArray();

    public Exception? ExceptionToThrow { get; set; }

    public Task<MqttPublishResult> PublishCommandAsync(
        MqttCommandMessage command,
        CancellationToken cancellationToken = default)
    {
        commands.Enqueue(command);

        if (ExceptionToThrow is not null)
        {
            return Task.FromException<MqttPublishResult>(ExceptionToThrow);
        }

        return Task.FromResult(MqttPublishResult.Success(
            $"traffic/integration-tests/intersections/{command.IntersectionId}/commands",
            $"{{\"commandId\":{command.CommandId}}}"));
    }
}
