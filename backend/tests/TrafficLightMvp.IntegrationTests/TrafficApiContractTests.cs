using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace TrafficLightMvp.IntegrationTests;

public sealed class TrafficApiContractTests
{
    [Fact]
    public async Task Dashboard_and_status_match_the_Flutter_contract()
    {
        using var factory = new TrafficApiFactory();
        using var client = factory.CreateClient();

        using var dashboardResponse = await client.GetAsync("/api/intersections/1/dashboard");
        Assert.Equal(HttpStatusCode.OK, dashboardResponse.StatusCode);

        using var dashboardJson = await JsonDocument.ParseAsync(
            await dashboardResponse.Content.ReadAsStreamAsync());
        var dashboard = dashboardJson.RootElement.GetProperty("data");

        var status = dashboard.GetProperty("status");
        Assert.Equal("AUTO", status.GetProperty("modeCode").GetString());
        Assert.True(status.GetProperty("remainingSeconds").GetInt32() >= 1);
        Assert.False(string.IsNullOrWhiteSpace(status.GetProperty("phaseCode").GetString()));
        Assert.Equal(4, status.GetProperty("signals").GetArrayLength());

        var approaches = dashboard.GetProperty("approaches");
        Assert.Equal(4, approaches.GetArrayLength());
        var firstApproach = approaches[0];
        Assert.True(firstApproach.TryGetProperty("display_order", out _));
        Assert.True(firstApproach.TryGetProperty("is_active", out _));
        Assert.True(firstApproach.TryGetProperty("signal_code", out _));

        var phasePlans = dashboard.GetProperty("phasePlans");
        Assert.NotEqual(0, phasePlans.GetArrayLength());
        Assert.True(phasePlans[0].GetProperty("steps")[0].TryGetProperty("duration_seconds", out _));

        Assert.True(dashboard.GetProperty("commands").ValueKind == JsonValueKind.Array);
        Assert.True(dashboard.GetProperty("logs").ValueKind == JsonValueKind.Array);
        Assert.True(dashboard.GetProperty("modes").ValueKind == JsonValueKind.Array);
        Assert.True(dashboard.GetProperty("deviceStatuses").ValueKind == JsonValueKind.Array);

        using var statusResponse = await client.GetAsync("/api/intersections/1/status");
        Assert.Equal(HttpStatusCode.OK, statusResponse.StatusCode);
        var statusPayload = await statusResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("AUTO", statusPayload.GetProperty("data").GetProperty("modeCode").GetString());
    }

    [Fact]
    public async Task Command_returns_the_Flutter_shape_and_persists_MQTT_publish_state()
    {
        using var factory = new TrafficApiFactory();
        using var client = factory.CreateClient();

        using var response = await client.PostAsJsonAsync("/api/intersections/1/commands", new
        {
            command = "SET_NIGHT",
            modeCode = "NIGHT",
            source = "flutter",
            createdBy = "operator"
        });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<JsonElement>();
        var data = payload.GetProperty("data");
        Assert.Equal("SET_NIGHT", data.GetProperty("command").GetString());
        Assert.Equal("success", data.GetProperty("status").GetString());
        Assert.Equal("NIGHT", data.GetProperty("trafficStatus").GetProperty("modeCode").GetString());

        using var historyResponse = await client.GetAsync("/api/intersections/1/commands?limit=1");
        var historyPayload = await historyResponse.Content.ReadFromJsonAsync<JsonElement>();
        var command = historyPayload.GetProperty("data")[0];
        Assert.Equal("SET_NIGHT", command.GetProperty("command").GetString());
        Assert.Equal("flutter", command.GetProperty("source").GetString());
        Assert.Equal("published", command.GetProperty("device_status").GetString());
        Assert.False(string.IsNullOrWhiteSpace(command.GetProperty("mqtt_topic").GetString()));

        var publisher = factory.Services.GetRequiredService<RecordingCommandPublisher>();
        var published = Assert.Single(publisher.Commands);
        Assert.True(published.CommandId > 0);
        Assert.Equal(1, published.IntersectionId);
    }

    [Fact]
    public async Task Unsupported_command_is_rejected_without_changing_the_current_mode()
    {
        using var factory = new TrafficApiFactory();
        using var client = factory.CreateClient();

        using var response = await client.PostAsJsonAsync("/api/intersections/1/commands", new
        {
            command = "SET_UNSUPPORTED",
            source = "flutter"
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var errorPayload = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(
            "Unsupported command",
            errorPayload.GetProperty("error").GetProperty("message").GetString());

        var statusPayload = await client.GetFromJsonAsync<JsonElement>("/api/intersections/1/status");
        Assert.Equal("AUTO", statusPayload.GetProperty("data").GetProperty("modeCode").GetString());

        var historyPayload = await client.GetFromJsonAsync<JsonElement>(
            "/api/intersections/1/commands?limit=1");
        var rejected = historyPayload.GetProperty("data")[0];
        Assert.Equal("rejected", rejected.GetProperty("status").GetString());
        Assert.Equal("not_sent", rejected.GetProperty("device_status").GetString());
    }

    [Fact]
    public async Task Publisher_exception_is_recorded_as_failed_without_breaking_the_API_contract()
    {
        using var factory = new TrafficApiFactory();
        using var client = factory.CreateClient();
        factory.Services.GetRequiredService<RecordingCommandPublisher>().ExceptionToThrow =
            new TimeoutException("broker timeout");

        using var response = await client.PostAsJsonAsync("/api/intersections/1/commands", new
        {
            command = "SET_PRIORITY_NS",
            source = "flutter"
        });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        var historyPayload = await client.GetFromJsonAsync<JsonElement>(
            "/api/intersections/1/commands?limit=1");
        var command = historyPayload.GetProperty("data")[0];
        Assert.Equal("publish_failed", command.GetProperty("device_status").GetString());
        Assert.Equal("broker timeout", command.GetProperty("device_message").GetString());
    }

    [Fact]
    public async Task Approach_update_is_reflected_in_dashboard_and_status()
    {
        using var factory = new TrafficApiFactory();
        using var client = factory.CreateClient();

        var dashboard = await client.GetFromJsonAsync<JsonElement>(
            "/api/intersections/1/dashboard");
        var approach = dashboard.GetProperty("data").GetProperty("approaches")[0];
        var approachId = approach.GetProperty("id").GetInt32();

        using var response = await client.PutAsJsonAsync($"/api/approaches/{approachId}", new
        {
            name = approach.GetProperty("name").GetString(),
            displayOrder = approach.GetProperty("display_order").GetInt32(),
            isActive = false
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var updatePayload = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(0, updatePayload.GetProperty("data").GetProperty("is_active").GetInt32());

        var refreshedDashboard = await client.GetFromJsonAsync<JsonElement>(
            "/api/intersections/1/dashboard");
        var updatedApproach = refreshedDashboard.GetProperty("data")
            .GetProperty("approaches")
            .EnumerateArray()
            .Single(item => item.GetProperty("id").GetInt32() == approachId);
        Assert.Equal(0, updatedApproach.GetProperty("is_active").GetInt32());

        var status = await client.GetFromJsonAsync<JsonElement>("/api/intersections/1/status");
        Assert.Equal(3, status.GetProperty("data").GetProperty("signals").GetArrayLength());
    }

    [Fact]
    public async Task Phase_plan_durations_can_be_updated_and_a_new_plan_activated()
    {
        using var factory = new TrafficApiFactory();
        using var client = factory.CreateClient();

        var initialPlans = await client.GetFromJsonAsync<JsonElement>(
            "/api/intersections/1/phase-plans");
        var initialPlanId = initialPlans.GetProperty("data")[0].GetProperty("id").GetInt32();

        using var updateResponse = await client.PutAsJsonAsync(
            $"/api/phase-plans/{initialPlanId}",
            new { greenSeconds = 12, yellowSeconds = 4 });
        Assert.Equal(HttpStatusCode.OK, updateResponse.StatusCode);

        var updatePayload = await updateResponse.Content.ReadFromJsonAsync<JsonElement>();
        var updatedPlan = updatePayload.GetProperty("data")
            .EnumerateArray()
            .Single(plan => plan.GetProperty("id").GetInt32() == initialPlanId);
        Assert.All(
            updatedPlan.GetProperty("steps").EnumerateArray()
                .Where(step => step.GetProperty("code").GetString()!.EndsWith("_GREEN")),
            step => Assert.Equal(12, step.GetProperty("duration_seconds").GetInt32()));
        Assert.All(
            updatedPlan.GetProperty("steps").EnumerateArray()
                .Where(step => step.GetProperty("code").GetString()!.EndsWith("_YELLOW")),
            step => Assert.Equal(4, step.GetProperty("duration_seconds").GetInt32()));

        using var createResponse = await client.PostAsJsonAsync(
            "/api/intersections/1/phase-plans",
            new { name = "Integration plan", greenSeconds = 9, yellowSeconds = 3 });
        Assert.Equal(HttpStatusCode.Created, createResponse.StatusCode);
        var createPayload = await createResponse.Content.ReadFromJsonAsync<JsonElement>();
        var newPlanId = createPayload.GetProperty("data").GetProperty("id").GetInt32();

        using var activateResponse = await client.PostAsJsonAsync(
            $"/api/phase-plans/{newPlanId}/activate",
            new { });
        Assert.Equal(HttpStatusCode.OK, activateResponse.StatusCode);

        var finalPlans = await client.GetFromJsonAsync<JsonElement>(
            "/api/intersections/1/phase-plans");
        var activePlans = finalPlans.GetProperty("data")
            .EnumerateArray()
            .Where(plan => plan.GetProperty("is_active").GetInt32() == 1)
            .ToList();
        Assert.Single(activePlans);
        Assert.Equal(newPlanId, activePlans[0].GetProperty("id").GetInt32());
    }

    [Fact]
    public async Task MQTT_status_is_deterministic_and_tests_use_an_isolated_database()
    {
        using var factory = new TrafficApiFactory();
        using var client = factory.CreateClient();

        var mqtt = await client.GetFromJsonAsync<JsonElement>("/api/mqtt/status");
        var status = mqtt.GetProperty("data");
        Assert.False(status.GetProperty("enabled").GetBoolean());
        Assert.False(status.GetProperty("connected").GetBoolean());
        Assert.Equal("traffic/integration-tests", status.GetProperty("topicPrefix").GetString());

        Assert.True(File.Exists(factory.DatabasePath));
        Assert.DoesNotContain(
            Path.Combine("backend", "traffic.db"),
            factory.DatabasePath,
            StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task MQTT_repository_updates_device_status_and_scopes_ack_to_the_intersection()
    {
        using var factory = new TrafficApiFactory();
        using var client = factory.CreateClient();

        await client.PostAsJsonAsync("/api/intersections/1/commands", new
        {
            command = "SET_NIGHT",
            source = "flutter"
        });
        var commandHistory = await client.GetFromJsonAsync<JsonElement>(
            "/api/intersections/1/commands?limit=1");
        var commandId = commandHistory.GetProperty("data")[0].GetProperty("id").GetInt32();

        using (var scope = factory.Services.CreateScope())
        {
            var repository = scope.ServiceProvider.GetRequiredService<TrafficRepository>();
            await repository.UpsertDeviceStatusAsync(
                new MqttStatusMessage(
                    IntersectionId: 1,
                    DeviceId: "wokwi-test",
                    ModeCode: "NIGHT",
                    PhaseCode: "YELLOW_BLINK",
                    RemainingSeconds: -1),
                """{"intersectionId":1,"deviceId":"wokwi-test","modeCode":"NIGHT"}""");

            await repository.MarkCommandAcknowledgedAsync(
                new MqttAckMessage(
                    IntersectionId: 999,
                    CommandId: commandId,
                    Status: "acknowledged",
                    Message: "wrong intersection"));
        }

        var devices = await client.GetFromJsonAsync<JsonElement>(
            "/api/intersections/1/devices");
        var device = Assert.Single(devices.GetProperty("data").EnumerateArray());
        Assert.Equal("wokwi-test", device.GetProperty("device_id").GetString());
        Assert.Equal("NIGHT", device.GetProperty("last_mode_code").GetString());

        var unchangedHistory = await client.GetFromJsonAsync<JsonElement>(
            "/api/intersections/1/commands?limit=1");
        Assert.Equal(
            "published",
            unchangedHistory.GetProperty("data")[0].GetProperty("device_status").GetString());

        using (var scope = factory.Services.CreateScope())
        {
            var repository = scope.ServiceProvider.GetRequiredService<TrafficRepository>();
            await repository.MarkCommandAcknowledgedAsync(
                new MqttAckMessage(
                    IntersectionId: 1,
                    CommandId: commandId,
                    Status: "acknowledged",
                    Message: "device applied"));
        }

        var acknowledgedHistory = await client.GetFromJsonAsync<JsonElement>(
            "/api/intersections/1/commands?limit=1");
        var acknowledged = acknowledgedHistory.GetProperty("data")[0];
        Assert.Equal("acknowledged", acknowledged.GetProperty("device_status").GetString());
        Assert.Equal("device applied", acknowledged.GetProperty("device_message").GetString());
    }
}
