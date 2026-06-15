using System.Data;
using System.Text.Json;
using Microsoft.Data.Sqlite;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

builder.Services.AddSingleton<TrafficDatabase>();
builder.Services.AddScoped<TrafficRepository>();
builder.Services.AddScoped<TrafficService>();

var app = builder.Build();

app.UseCors();

using (var scope = app.Services.CreateScope())
{
    var database = scope.ServiceProvider.GetRequiredService<TrafficDatabase>();
    await database.InitializeAsync();
}

app.MapGet("/api/health", (TrafficDatabase database) =>
{
    return Results.Ok(new { status = "ok", stack = "ASP.NET Core 8 + SQLite", database = database.DatabaseFileName });
});

app.MapGet("/api/intersections", async (TrafficRepository repository) =>
{
    return Results.Ok(new { data = await repository.ListIntersectionsAsync() });
});

app.MapGet("/api/traffic-modes", async (TrafficRepository repository) =>
{
    return Results.Ok(new { data = await repository.ListTrafficModesAsync() });
});

app.MapGet("/api/intersections/{id:int}/status", async Task<IResult> (int id, TrafficService service) =>
{
    var status = await service.GetStatusAsync(id);
    return status is null ? Results.NotFound(Error("Intersection not found")) : Results.Ok(new { data = status });
});

app.MapGet("/api/intersections/{id:int}/dashboard", async Task<IResult> (int id, TrafficService service) =>
{
    var dashboard = await service.GetDashboardAsync(id);
    return dashboard is null ? Results.NotFound(Error("Intersection not found")) : Results.Ok(new { data = dashboard });
});

app.MapGet("/api/intersections/{id:int}/approaches", async Task<IResult> (int id, TrafficRepository repository) =>
{
    if (!await repository.IntersectionExistsAsync(id))
    {
        return Results.NotFound(Error("Intersection not found"));
    }

    return Results.Ok(new { data = await repository.ListApproachesAsync(id) });
});

app.MapPost("/api/intersections/{id:int}/approaches", async Task<IResult> (int id, CreateApproachRequest request, TrafficRepository repository) =>
{
    if (!await repository.IntersectionExistsAsync(id))
    {
        return Results.NotFound(Error("Intersection not found"));
    }

    try
    {
        var approach = await repository.CreateApproachAsync(id, request);
        return Results.Created($"/api/intersections/{id}/approaches", new { data = approach });
    }
    catch (ArgumentException ex)
    {
        return Results.BadRequest(Error(ex.Message));
    }
    catch (SqliteException ex) when (ex.SqliteErrorCode == 19)
    {
        return Results.BadRequest(Error("Approach code already exists for this intersection"));
    }
});

app.MapPut("/api/approaches/{id:int}", async Task<IResult> (int id, UpdateApproachRequest request, TrafficRepository repository) =>
{
    var approach = await repository.UpdateApproachAsync(id, request);
    return approach is null ? Results.NotFound(Error("Approach not found")) : Results.Ok(new { data = approach });
});

app.MapGet("/api/intersections/{id:int}/phase-plans", async Task<IResult> (int id, TrafficRepository repository) =>
{
    if (!await repository.IntersectionExistsAsync(id))
    {
        return Results.NotFound(Error("Intersection not found"));
    }

    return Results.Ok(new { data = await repository.ListPhasePlansAsync(id) });
});

app.MapPost("/api/intersections/{id:int}/phase-plans", async Task<IResult> (int id, CreatePhasePlanRequest request, TrafficService service) =>
{
    try
    {
        var plan = await service.CreateBasicPhasePlanAsync(id, request);
        return plan is null ? Results.NotFound(Error("Intersection not found")) : Results.Created($"/api/intersections/{id}/phase-plans", new { data = plan });
    }
    catch (ArgumentException ex)
    {
        return Results.BadRequest(Error(ex.Message));
    }
});

app.MapPut("/api/phase-plans/{id:int}", async Task<IResult> (int id, UpdatePhasePlanRequest request, TrafficService service) =>
{
    try
    {
        var plan = await service.UpdatePhasePlanDurationsAsync(id, request);
        return plan is null ? Results.NotFound(Error("Phase plan not found")) : Results.Ok(new { data = plan });
    }
    catch (ArgumentException ex)
    {
        return Results.BadRequest(Error(ex.Message));
    }
});

app.MapPost("/api/phase-plans/{id:int}/activate", async Task<IResult> (int id, TrafficRepository repository) =>
{
    var activated = await repository.ActivatePhasePlanAsync(id);
    return activated ? Results.Ok(new { data = new { id, isActive = true } }) : Results.NotFound(Error("Phase plan not found"));
});

app.MapGet("/api/intersections/{id:int}/commands", async Task<IResult> (int id, int? limit, TrafficRepository repository) =>
{
    if (!await repository.IntersectionExistsAsync(id))
    {
        return Results.NotFound(Error("Intersection not found"));
    }

    return Results.Ok(new { data = await repository.ListCommandsAsync(id, Math.Clamp(limit ?? 20, 1, 100)) });
});

app.MapPost("/api/intersections/{id:int}/commands", async Task<IResult> (int id, CommandRequest request, TrafficService service) =>
{
    try
    {
        var result = await service.HandleCommandAsync(id, request);
        return result is null ? Results.NotFound(Error("Intersection not found")) : Results.Created($"/api/intersections/{id}/commands", new { data = result });
    }
    catch (ArgumentException ex)
    {
        return Results.BadRequest(Error(ex.Message));
    }
});

app.MapGet("/api/intersections/{id:int}/logs", async Task<IResult> (int id, TrafficRepository repository) =>
{
    if (!await repository.IntersectionExistsAsync(id))
    {
        return Results.NotFound(Error("Intersection not found"));
    }

    return Results.Ok(new { data = await repository.ListLogsAsync(id, 50) });
});

app.MapPost("/api/intersections/{id:int}/logs", async Task<IResult> (int id, CreateLogRequest request, TrafficRepository repository) =>
{
    if (!await repository.IntersectionExistsAsync(id))
    {
        return Results.NotFound(Error("Intersection not found"));
    }

    try
    {
        var log = await repository.CreateLogAsync(id, request);
        return Results.Created($"/api/intersections/{id}/logs", new { data = log });
    }
    catch (ArgumentException ex)
    {
        return Results.BadRequest(Error(ex.Message));
    }
});

var port = Environment.GetEnvironmentVariable("PORT") ?? "8000";
app.Run($"http://0.0.0.0:{port}");

static object Error(string message) => new { error = new { message } };

public sealed class TrafficDatabase
{
    private readonly string connectionString;
    private readonly string schemaPath;

    public TrafficDatabase(IWebHostEnvironment environment)
    {
        var basePath = environment.ContentRootPath;
        var dbPath = Path.Combine(basePath, "traffic.db");
        schemaPath = Path.Combine(basePath, "schema.sql");
        connectionString = new SqliteConnectionStringBuilder { DataSource = dbPath }.ToString();
        DatabaseFileName = Path.GetFileName(dbPath);
    }

    public string DatabaseFileName { get; }

    public async Task<SqliteConnection> OpenConnectionAsync()
    {
        var connection = new SqliteConnection(connectionString);
        await connection.OpenAsync();
        await ExecuteAsync(connection, "PRAGMA foreign_keys = ON");
        return connection;
    }

    public async Task InitializeAsync()
    {
        await using var connection = await OpenConnectionAsync();
        var schema = await File.ReadAllTextAsync(schemaPath);
        await ExecuteAsync(connection, schema);

        var count = Convert.ToInt32(await ScalarAsync(connection, "SELECT COUNT(*) FROM intersections"));
        if (count > 0)
        {
            return;
        }

        await SeedAsync(connection);
    }

    private static async Task SeedAsync(SqliteConnection connection)
    {
        using var transaction = connection.BeginTransaction();

        var modes = new[]
        {
            new object[] { "AUTO", "Auto", 1, "Run the active phase plan" },
            new object[] { "NIGHT", "Night warning", 2, "Blink yellow lights for low-traffic hours" },
            new object[] { "PRIORITY_NS", "Priority north-south", 3, "Give green to north/south" },
            new object[] { "PRIORITY_EW", "Priority east-west", 3, "Give green to east/west" },
            new object[] { "EMERGENCY", "Emergency all-red", 4, "Force every direction to red" }
        };

        foreach (var mode in modes)
        {
            await ExecuteAsync(connection, """
                INSERT INTO traffic_modes(code, name, priority_level, description)
                VALUES ($code, $name, $priority, $description)
                """, transaction, ("$code", mode[0]), ("$name", mode[1]), ("$priority", mode[2]), ("$description", mode[3]));
        }

        var intersectionId = Convert.ToInt32(await ScalarAsync(connection, """
            INSERT INTO intersections(name, location, status, current_mode_code)
            VALUES ('Demo Intersection 1', 'Wokwi ESP32 demo', 'active', 'AUTO')
            RETURNING id
            """, transaction));

        var approachIds = new Dictionary<string, int>();
        var approaches = new[] { ("NORTH", "North approach", 1), ("SOUTH", "South approach", 2), ("EAST", "East approach", 3), ("WEST", "West approach", 4) };
        foreach (var approach in approaches)
        {
            var id = Convert.ToInt32(await ScalarAsync(connection, """
                INSERT INTO road_approaches(intersection_id, code, name, display_order)
                VALUES ($intersectionId, $code, $name, $displayOrder)
                RETURNING id
                """, transaction, ("$intersectionId", intersectionId), ("$code", approach.Item1), ("$name", approach.Item2), ("$displayOrder", approach.Item3)));
            approachIds[approach.Item1] = id;
        }

        var signalIds = new Dictionary<string, int>();
        var pinMap = new Dictionary<string, (int Red, int Yellow, int Green)>
        {
            ["NORTH"] = (16, 17, 18),
            ["SOUTH"] = (16, 17, 18),
            ["EAST"] = (19, 23, 25),
            ["WEST"] = (19, 23, 25)
        };

        foreach (var (code, approachId) in approachIds)
        {
            var pins = pinMap[code];
            var signalId = Convert.ToInt32(await ScalarAsync(connection, """
                INSERT INTO signal_heads(road_approach_id, code, type, red_pin, yellow_pin, green_pin)
                VALUES ($approachId, $code, 'vehicle', $redPin, $yellowPin, $greenPin)
                RETURNING id
                """, transaction, ("$approachId", approachId), ("$code", $"{code}_MAIN"), ("$redPin", pins.Red), ("$yellowPin", pins.Yellow), ("$greenPin", pins.Green)));
            signalIds[code] = signalId;
        }

        var phasePlanId = Convert.ToInt32(await ScalarAsync(connection, """
            INSERT INTO phase_plans(intersection_id, name, is_active)
            VALUES ($intersectionId, 'Default 4-way plan', 1)
            RETURNING id
            """, transaction, ("$intersectionId", intersectionId)));

        await ExecuteAsync(connection, "UPDATE intersections SET active_phase_plan_id = $planId WHERE id = $intersectionId", transaction, ("$planId", phasePlanId), ("$intersectionId", intersectionId));

        var steps = new[]
        {
            new PhaseSeed("NS_GREEN", 1, 8, new Dictionary<string, string> { ["NORTH"] = "GREEN", ["SOUTH"] = "GREEN", ["EAST"] = "RED", ["WEST"] = "RED" }),
            new PhaseSeed("NS_YELLOW", 2, 3, new Dictionary<string, string> { ["NORTH"] = "YELLOW", ["SOUTH"] = "YELLOW", ["EAST"] = "RED", ["WEST"] = "RED" }),
            new PhaseSeed("EW_GREEN", 3, 8, new Dictionary<string, string> { ["NORTH"] = "RED", ["SOUTH"] = "RED", ["EAST"] = "GREEN", ["WEST"] = "GREEN" }),
            new PhaseSeed("EW_YELLOW", 4, 3, new Dictionary<string, string> { ["NORTH"] = "RED", ["SOUTH"] = "RED", ["EAST"] = "YELLOW", ["WEST"] = "YELLOW" })
        };

        foreach (var step in steps)
        {
            var stepId = Convert.ToInt32(await ScalarAsync(connection, """
                INSERT INTO phase_steps(phase_plan_id, code, sequence_no, duration_seconds)
                VALUES ($planId, $code, $sequenceNo, $duration)
                RETURNING id
                """, transaction, ("$planId", phasePlanId), ("$code", step.Code), ("$sequenceNo", step.SequenceNo), ("$duration", step.DurationSeconds)));

            foreach (var state in step.SignalStates)
            {
                await ExecuteAsync(connection, """
                    INSERT INTO phase_signal_states(phase_step_id, signal_head_id, light_color)
                    VALUES ($stepId, $signalId, $color)
                    """, transaction, ("$stepId", stepId), ("$signalId", signalIds[state.Key]), ("$color", state.Value));
            }
        }

        var conflicts = new[] { ("NORTH", "EAST"), ("NORTH", "WEST"), ("SOUTH", "EAST"), ("SOUTH", "WEST") };
        foreach (var conflict in conflicts)
        {
            foreach (var pair in new[] { conflict, (conflict.Item2, conflict.Item1) })
            {
                await ExecuteAsync(connection, """
                    INSERT INTO conflict_rules(intersection_id, source_approach_id, target_approach_id, reason)
                    VALUES ($intersectionId, $sourceId, $targetId, 'Straight-through conflict')
                    """, transaction, ("$intersectionId", intersectionId), ("$sourceId", approachIds[pair.Item1]), ("$targetId", approachIds[pair.Item2]));
            }
        }

        await ExecuteAsync(connection, """
            INSERT INTO control_commands(intersection_id, mode_code, command, source, created_by, message)
            VALUES ($intersectionId, 'AUTO', 'SET_AUTO', 'seed', 'system', 'Initial seed command')
            """, transaction, ("$intersectionId", intersectionId));

        transaction.Commit();
    }

    public static async Task ExecuteAsync(SqliteConnection connection, string sql, SqliteTransaction? transaction = null, params (string Name, object? Value)[] parameters)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        command.Transaction = transaction;
        foreach (var parameter in parameters)
        {
            command.Parameters.AddWithValue(parameter.Name, parameter.Value ?? DBNull.Value);
        }
        await command.ExecuteNonQueryAsync();
    }

    public static async Task<object?> ScalarAsync(SqliteConnection connection, string sql, SqliteTransaction? transaction = null, params (string Name, object? Value)[] parameters)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        command.Transaction = transaction;
        foreach (var parameter in parameters)
        {
            command.Parameters.AddWithValue(parameter.Name, parameter.Value ?? DBNull.Value);
        }
        return await command.ExecuteScalarAsync();
    }
}

public sealed class TrafficRepository(TrafficDatabase database)
{
    public async Task<bool> IntersectionExistsAsync(int intersectionId)
    {
        await using var connection = await database.OpenConnectionAsync();
        var result = await TrafficDatabase.ScalarAsync(connection, "SELECT 1 FROM intersections WHERE id = $id", null, ("$id", intersectionId));
        return result is not null;
    }

    public async Task<List<Dictionary<string, object?>>> ListIntersectionsAsync()
    {
        await using var connection = await database.OpenConnectionAsync();
        return await QueryAsync(connection, "SELECT * FROM intersections ORDER BY id ASC");
    }

    public async Task<List<Dictionary<string, object?>>> ListTrafficModesAsync()
    {
        await using var connection = await database.OpenConnectionAsync();
        return await QueryAsync(connection, "SELECT * FROM traffic_modes ORDER BY priority_level ASC, code ASC");
    }

    public async Task<IntersectionRow?> GetIntersectionAsync(int intersectionId)
    {
        await using var connection = await database.OpenConnectionAsync();
        var rows = await QueryAsync(connection, "SELECT * FROM intersections WHERE id = $id", null, ("$id", intersectionId));
        var row = rows.FirstOrDefault();
        return row is null ? null : new IntersectionRow(Convert.ToInt32(row["id"]), Convert.ToString(row["current_mode_code"]) ?? "AUTO");
    }

    public async Task<List<Dictionary<string, object?>>> ListApproachesAsync(int intersectionId)
    {
        await using var connection = await database.OpenConnectionAsync();
        return await QueryAsync(connection, """
            SELECT
              ra.id,
              ra.code,
              ra.name,
              ra.display_order,
              ra.is_active,
              sh.id AS signal_head_id,
              sh.code AS signal_code,
              sh.red_pin,
              sh.yellow_pin,
              sh.green_pin
            FROM road_approaches ra
            LEFT JOIN signal_heads sh ON sh.road_approach_id = ra.id
            WHERE ra.intersection_id = $intersectionId
            ORDER BY ra.display_order ASC
            """, null, ("$intersectionId", intersectionId));
    }

    public async Task<Dictionary<string, object?>> CreateApproachAsync(int intersectionId, CreateApproachRequest request)
    {
        var code = NormalizeCode(request.Code);
        if (string.IsNullOrWhiteSpace(code))
        {
            throw new ArgumentException("Approach code is required");
        }

        var name = TextOrDefault(request.Name, code);
        var displayOrder = request.DisplayOrder ?? 99;

        await using var connection = await database.OpenConnectionAsync();
        using var transaction = connection.BeginTransaction();

        var approachId = Convert.ToInt32(await TrafficDatabase.ScalarAsync(connection, """
            INSERT INTO road_approaches(intersection_id, code, name, display_order, is_active)
            VALUES ($intersectionId, $code, $name, $displayOrder, $isActive)
            RETURNING id
            """, transaction, ("$intersectionId", intersectionId), ("$code", code), ("$name", name), ("$displayOrder", displayOrder), ("$isActive", request.IsActive ? 1 : 0)));

        await TrafficDatabase.ExecuteAsync(connection, """
            INSERT INTO signal_heads(road_approach_id, code, type, red_pin, yellow_pin, green_pin)
            VALUES ($approachId, $signalCode, 'vehicle', $redPin, $yellowPin, $greenPin)
            """, transaction, ("$approachId", approachId), ("$signalCode", $"{code}_MAIN"), ("$redPin", request.RedPin), ("$yellowPin", request.YellowPin), ("$greenPin", request.GreenPin));

        transaction.Commit();

        var rows = await ListApproachesAsync(intersectionId);
        return rows.Single(row => Convert.ToInt32(row["id"]) == approachId);
    }

    public async Task<Dictionary<string, object?>?> UpdateApproachAsync(int approachId, UpdateApproachRequest request)
    {
        await using var connection = await database.OpenConnectionAsync();
        var existing = await QueryAsync(connection, "SELECT intersection_id FROM road_approaches WHERE id = $id", null, ("$id", approachId));
        if (existing.Count == 0)
        {
            return null;
        }

        var intersectionId = Convert.ToInt32(existing[0]["intersection_id"]);
        await TrafficDatabase.ExecuteAsync(connection, """
            UPDATE road_approaches
            SET
              name = COALESCE($name, name),
              display_order = COALESCE($displayOrder, display_order),
              is_active = COALESCE($isActive, is_active),
              updated_at = CURRENT_TIMESTAMP
            WHERE id = $id
            """, null, ("$name", string.IsNullOrWhiteSpace(request.Name) ? null : request.Name.Trim()), ("$displayOrder", request.DisplayOrder), ("$isActive", request.IsActive is null ? null : request.IsActive.Value ? 1 : 0), ("$id", approachId));

        var rows = await ListApproachesAsync(intersectionId);
        return rows.Single(row => Convert.ToInt32(row["id"]) == approachId);
    }

    public async Task<List<Dictionary<string, object?>>> ListPhasePlansAsync(int intersectionId)
    {
        await using var connection = await database.OpenConnectionAsync();
        var plans = await QueryAsync(connection, """
            SELECT * FROM phase_plans
            WHERE intersection_id = $intersectionId
            ORDER BY is_active DESC, id ASC
            """, null, ("$intersectionId", intersectionId));

        foreach (var plan in plans)
        {
            var steps = await QueryAsync(connection, """
                SELECT * FROM phase_steps
                WHERE phase_plan_id = $planId
                ORDER BY sequence_no ASC
                """, null, ("$planId", plan["id"]));

            foreach (var step in steps)
            {
                step["signals"] = await PhaseSignalStatesAsync(connection, Convert.ToInt32(step["id"]));
                step["conflictErrors"] = await ValidatePhaseConflictsAsync(connection, Convert.ToInt32(step["id"]));
            }

            plan["steps"] = steps;
        }

        return plans;
    }

    public async Task<Dictionary<string, object?>> CreateBasicPhasePlanAsync(int intersectionId, string name, int greenSeconds, int yellowSeconds, bool activate)
    {
        await using var connection = await database.OpenConnectionAsync();
        using var transaction = connection.BeginTransaction();

        var approaches = await QueryAsync(connection, """
            SELECT ra.id, ra.code, sh.id AS signal_head_id
            FROM road_approaches ra
            JOIN signal_heads sh ON sh.road_approach_id = ra.id
            WHERE ra.intersection_id = $intersectionId
            ORDER BY ra.display_order ASC
            """, transaction, ("$intersectionId", intersectionId));

        var requiredCodes = new[] { "NORTH", "SOUTH", "EAST", "WEST" };
        if (!requiredCodes.All(code => approaches.Any(row => Convert.ToString(row["code"]) == code)))
        {
            throw new ArgumentException("Basic phase plan requires NORTH, SOUTH, EAST, and WEST approaches");
        }

        var planId = Convert.ToInt32(await TrafficDatabase.ScalarAsync(connection, """
            INSERT INTO phase_plans(intersection_id, name, is_active)
            VALUES ($intersectionId, $name, 0)
            RETURNING id
            """, transaction, ("$intersectionId", intersectionId), ("$name", name)));

        var signalIds = approaches.ToDictionary(row => Convert.ToString(row["code"]) ?? "", row => Convert.ToInt32(row["signal_head_id"]));
        var steps = new[]
        {
            new PhaseSeed("NS_GREEN", 1, greenSeconds, new Dictionary<string, string> { ["NORTH"] = "GREEN", ["SOUTH"] = "GREEN", ["EAST"] = "RED", ["WEST"] = "RED" }),
            new PhaseSeed("NS_YELLOW", 2, yellowSeconds, new Dictionary<string, string> { ["NORTH"] = "YELLOW", ["SOUTH"] = "YELLOW", ["EAST"] = "RED", ["WEST"] = "RED" }),
            new PhaseSeed("EW_GREEN", 3, greenSeconds, new Dictionary<string, string> { ["NORTH"] = "RED", ["SOUTH"] = "RED", ["EAST"] = "GREEN", ["WEST"] = "GREEN" }),
            new PhaseSeed("EW_YELLOW", 4, yellowSeconds, new Dictionary<string, string> { ["NORTH"] = "RED", ["SOUTH"] = "RED", ["EAST"] = "YELLOW", ["WEST"] = "YELLOW" })
        };

        foreach (var step in steps)
        {
            var stepId = Convert.ToInt32(await TrafficDatabase.ScalarAsync(connection, """
                INSERT INTO phase_steps(phase_plan_id, code, sequence_no, duration_seconds)
                VALUES ($planId, $code, $sequenceNo, $duration)
                RETURNING id
                """, transaction, ("$planId", planId), ("$code", step.Code), ("$sequenceNo", step.SequenceNo), ("$duration", step.DurationSeconds)));

            foreach (var state in step.SignalStates)
            {
                await TrafficDatabase.ExecuteAsync(connection, """
                    INSERT INTO phase_signal_states(phase_step_id, signal_head_id, light_color)
                    VALUES ($stepId, $signalId, $color)
                    """, transaction, ("$stepId", stepId), ("$signalId", signalIds[state.Key]), ("$color", state.Value));
            }
        }

        if (activate)
        {
            await TrafficDatabase.ExecuteAsync(connection, "UPDATE phase_plans SET is_active = 0 WHERE intersection_id = $intersectionId", transaction, ("$intersectionId", intersectionId));
            await TrafficDatabase.ExecuteAsync(connection, "UPDATE phase_plans SET is_active = 1, updated_at = CURRENT_TIMESTAMP WHERE id = $planId", transaction, ("$planId", planId));
            await TrafficDatabase.ExecuteAsync(connection, "UPDATE intersections SET active_phase_plan_id = $planId, updated_at = CURRENT_TIMESTAMP WHERE id = $intersectionId", transaction, ("$planId", planId), ("$intersectionId", intersectionId));
        }

        transaction.Commit();

        var plans = await ListPhasePlansAsync(intersectionId);
        return plans.Single(plan => Convert.ToInt32(plan["id"]) == planId);
    }

    public async Task<bool> ActivatePhasePlanAsync(int phasePlanId)
    {
        await using var connection = await database.OpenConnectionAsync();
        var rows = await QueryAsync(connection, "SELECT intersection_id FROM phase_plans WHERE id = $id", null, ("$id", phasePlanId));
        if (rows.Count == 0)
        {
            return false;
        }

        var intersectionId = rows[0]["intersection_id"];
        using var transaction = connection.BeginTransaction();
        await TrafficDatabase.ExecuteAsync(connection, "UPDATE phase_plans SET is_active = 0 WHERE intersection_id = $intersectionId", transaction, ("$intersectionId", intersectionId));
        await TrafficDatabase.ExecuteAsync(connection, "UPDATE phase_plans SET is_active = 1, updated_at = CURRENT_TIMESTAMP WHERE id = $id", transaction, ("$id", phasePlanId));
        await TrafficDatabase.ExecuteAsync(connection, "UPDATE intersections SET active_phase_plan_id = $id, updated_at = CURRENT_TIMESTAMP WHERE id = $intersectionId", transaction, ("$id", phasePlanId), ("$intersectionId", intersectionId));
        transaction.Commit();
        return true;
    }

    public async Task UpdatePhaseDurationsAsync(int phasePlanId, int greenSeconds, int yellowSeconds)
    {
        await using var connection = await database.OpenConnectionAsync();
        await TrafficDatabase.ExecuteAsync(connection, """
            UPDATE phase_steps
            SET duration_seconds = CASE
              WHEN code LIKE '%GREEN' THEN $greenSeconds
              WHEN code LIKE '%YELLOW' THEN $yellowSeconds
              ELSE duration_seconds
            END,
            updated_at = CURRENT_TIMESTAMP
            WHERE phase_plan_id = $phasePlanId
            """, null, ("$greenSeconds", greenSeconds), ("$yellowSeconds", yellowSeconds), ("$phasePlanId", phasePlanId));
    }

    public async Task<List<Dictionary<string, object?>>> ActivePhaseStepsAsync(int intersectionId)
    {
        await using var connection = await database.OpenConnectionAsync();
        return await QueryAsync(connection, """
            SELECT ps.*
            FROM phase_steps ps
            JOIN phase_plans pp ON pp.id = ps.phase_plan_id
            WHERE pp.intersection_id = $intersectionId AND pp.is_active = 1
            ORDER BY ps.sequence_no ASC
            """, null, ("$intersectionId", intersectionId));
    }

    public async Task<List<Dictionary<string, object?>>> PhaseSignalStatesAsync(int phaseStepId)
    {
        await using var connection = await database.OpenConnectionAsync();
        return await PhaseSignalStatesAsync(connection, phaseStepId);
    }

    public async Task<List<Dictionary<string, object?>>> ListCommandsAsync(int intersectionId, int limit)
    {
        await using var connection = await database.OpenConnectionAsync();
        return await QueryAsync(connection, """
            SELECT * FROM control_commands
            WHERE intersection_id = $intersectionId
            ORDER BY created_at DESC, id DESC
            LIMIT $limit
            """, null, ("$intersectionId", intersectionId), ("$limit", limit));
    }

    public async Task<List<Dictionary<string, object?>>> ListLogsAsync(int intersectionId, int limit)
    {
        await using var connection = await database.OpenConnectionAsync();
        return await QueryAsync(connection, """
            SELECT * FROM traffic_event_logs
            WHERE intersection_id = $intersectionId
            ORDER BY created_at DESC, id DESC
            LIMIT $limit
            """, null, ("$intersectionId", intersectionId), ("$limit", limit));
    }

    public async Task<Dictionary<string, object?>> CreateLogAsync(int intersectionId, CreateLogRequest request)
    {
        var modeCode = NormalizeCode(request.ModeCode);
        if (string.IsNullOrWhiteSpace(modeCode))
        {
            throw new ArgumentException("modeCode is required");
        }

        var phaseCode = string.IsNullOrWhiteSpace(request.PhaseCode) ? "" : request.PhaseCode.Trim().ToUpperInvariant();
        var statusJson = string.IsNullOrWhiteSpace(request.StatusJson) ? "{}" : request.StatusJson.Trim();

        await using var connection = await database.OpenConnectionAsync();
        var id = Convert.ToInt32(await TrafficDatabase.ScalarAsync(connection, """
            INSERT INTO traffic_event_logs(intersection_id, mode_code, phase_code, remaining_seconds, status_json)
            VALUES ($intersectionId, $modeCode, $phaseCode, $remainingSeconds, $statusJson)
            RETURNING id
            """, null, ("$intersectionId", intersectionId), ("$modeCode", modeCode), ("$phaseCode", phaseCode), ("$remainingSeconds", request.RemainingSeconds), ("$statusJson", statusJson)));

        var rows = await QueryAsync(connection, "SELECT * FROM traffic_event_logs WHERE id = $id", null, ("$id", id));
        return rows.Single();
    }

    public async Task InsertCommandAsync(int intersectionId, string modeCode, string command, string source, string createdBy, string status, string message)
    {
        await using var connection = await database.OpenConnectionAsync();
        await TrafficDatabase.ExecuteAsync(connection, """
            INSERT INTO control_commands(intersection_id, mode_code, command, source, created_by, status, message)
            VALUES ($intersectionId, $modeCode, $command, $source, $createdBy, $status, $message)
            """, null, ("$intersectionId", intersectionId), ("$modeCode", modeCode), ("$command", command), ("$source", source), ("$createdBy", createdBy), ("$status", status), ("$message", message));
    }

    public async Task SetCurrentModeAsync(int intersectionId, string modeCode)
    {
        await using var connection = await database.OpenConnectionAsync();
        await TrafficDatabase.ExecuteAsync(connection, """
            UPDATE intersections
            SET current_mode_code = $modeCode, updated_at = CURRENT_TIMESTAMP
            WHERE id = $intersectionId
            """, null, ("$modeCode", modeCode), ("$intersectionId", intersectionId));
    }

    public async Task InsertLogAsync(int intersectionId, TrafficStatus status)
    {
        await using var connection = await database.OpenConnectionAsync();
        await TrafficDatabase.ExecuteAsync(connection, """
            INSERT INTO traffic_event_logs(intersection_id, mode_code, phase_code, remaining_seconds, status_json)
            VALUES ($intersectionId, $modeCode, $phaseCode, $remainingSeconds, $statusJson)
            """, null, ("$intersectionId", intersectionId), ("$modeCode", status.ModeCode), ("$phaseCode", status.PhaseCode), ("$remainingSeconds", status.RemainingSeconds), ("$statusJson", JsonSerializer.Serialize(status)));
    }

    private static async Task<List<Dictionary<string, object?>>> PhaseSignalStatesAsync(SqliteConnection connection, int phaseStepId)
    {
        return await QueryAsync(connection, """
            SELECT
              ra.code AS approach,
              sh.code AS signal,
              pss.light_color AS color
            FROM phase_signal_states pss
            JOIN signal_heads sh ON sh.id = pss.signal_head_id
            JOIN road_approaches ra ON ra.id = sh.road_approach_id
            WHERE pss.phase_step_id = $phaseStepId
            ORDER BY ra.display_order ASC
            """, null, ("$phaseStepId", phaseStepId));
    }

    private static async Task<List<Dictionary<string, object?>>> ValidatePhaseConflictsAsync(SqliteConnection connection, int phaseStepId)
    {
        var greenApproaches = await QueryAsync(connection, """
            SELECT ra.id, ra.code
            FROM phase_signal_states pss
            JOIN signal_heads sh ON sh.id = pss.signal_head_id
            JOIN road_approaches ra ON ra.id = sh.road_approach_id
            WHERE pss.phase_step_id = $phaseStepId AND pss.light_color = 'GREEN'
            """, null, ("$phaseStepId", phaseStepId));

        if (greenApproaches.Count < 2)
        {
            return [];
        }

        var ids = greenApproaches.Select(row => Convert.ToInt32(row["id"])).ToList();
        var placeholders = string.Join(",", ids.Select((_, index) => $"$id{index}"));
        var parameters = ids.Select((id, index) => ($"$id{index}", (object?)id)).ToArray();
        return await QueryAsync(connection, $"""
            SELECT source_approach_id, target_approach_id, reason
            FROM conflict_rules
            WHERE source_approach_id IN ({placeholders})
              AND target_approach_id IN ({placeholders})
            """, null, parameters);
    }

    private static async Task<List<Dictionary<string, object?>>> QueryAsync(SqliteConnection connection, string sql, SqliteTransaction? transaction = null, params (string Name, object? Value)[] parameters)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        command.Transaction = transaction;
        foreach (var parameter in parameters)
        {
            command.Parameters.AddWithValue(parameter.Name, parameter.Value ?? DBNull.Value);
        }

        await using var reader = await command.ExecuteReaderAsync();
        var rows = new List<Dictionary<string, object?>>();
        while (await reader.ReadAsync())
        {
            var row = new Dictionary<string, object?>();
            for (var index = 0; index < reader.FieldCount; index++)
            {
                var value = reader.IsDBNull(index) ? null : reader.GetValue(index);
                row[reader.GetName(index)] = value;
            }
            rows.Add(row);
        }

        return rows;
    }

    private static string NormalizeCode(string? code)
    {
        return string.IsNullOrWhiteSpace(code)
            ? ""
            : code.Trim().Replace(" ", "_", StringComparison.Ordinal).ToUpperInvariant();
    }

    private static string TextOrDefault(string? value, string fallback)
    {
        return string.IsNullOrWhiteSpace(value) ? fallback : value.Trim();
    }
}

public sealed class TrafficService(TrafficRepository repository)
{
    private static readonly IReadOnlyDictionary<string, string> ValidCommands = new Dictionary<string, string>
    {
        ["SET_AUTO"] = "AUTO",
        ["SET_NIGHT"] = "NIGHT",
        ["SET_PRIORITY_NS"] = "PRIORITY_NS",
        ["SET_PRIORITY_EW"] = "PRIORITY_EW",
        ["SET_EMERGENCY"] = "EMERGENCY"
    };

    public async Task<TrafficStatus?> GetStatusAsync(int intersectionId)
    {
        var intersection = await repository.GetIntersectionAsync(intersectionId);
        if (intersection is null)
        {
            return null;
        }

        return await StatusForModeAsync(intersectionId, intersection.CurrentModeCode);
    }

    public async Task<DashboardSnapshot?> GetDashboardAsync(int intersectionId)
    {
        if (!await repository.IntersectionExistsAsync(intersectionId))
        {
            return null;
        }

        var status = await StatusForModeAsync(intersectionId, (await repository.GetIntersectionAsync(intersectionId))?.CurrentModeCode ?? "AUTO");
        var approaches = await repository.ListApproachesAsync(intersectionId);
        var phasePlans = await repository.ListPhasePlansAsync(intersectionId);
        var commands = await repository.ListCommandsAsync(intersectionId, 10);
        var logs = await repository.ListLogsAsync(intersectionId, 10);
        var modes = await repository.ListTrafficModesAsync();

        return new DashboardSnapshot(status, approaches, phasePlans, commands, logs, modes);
    }

    public async Task<CommandResult?> HandleCommandAsync(int intersectionId, CommandRequest request)
    {
        var intersection = await repository.GetIntersectionAsync(intersectionId);
        if (intersection is null)
        {
            return null;
        }

        var command = NormalizeCommand(request.Command, request.ModeCode);
        if (!ValidCommands.TryGetValue(command, out var modeCode))
        {
            await repository.InsertCommandAsync(intersectionId, "AUTO", string.IsNullOrWhiteSpace(command) ? "UNKNOWN" : command, request.SourceOrDefault(), request.CreatedByOrDefault(), "rejected", "Unsupported command");
            throw new ArgumentException("Unsupported command");
        }

        if (intersection.CurrentModeCode == "EMERGENCY" && command is not ("SET_AUTO" or "SET_NIGHT" or "SET_EMERGENCY"))
        {
            await repository.InsertCommandAsync(intersectionId, modeCode, command, request.SourceOrDefault(), request.CreatedByOrDefault(), "rejected", "Emergency mode only allows SET_AUTO, SET_NIGHT, or SET_EMERGENCY");
            throw new ArgumentException("Command rejected while emergency mode is active");
        }

        await repository.InsertCommandAsync(intersectionId, modeCode, command, request.SourceOrDefault(), request.CreatedByOrDefault(), "success", "Command accepted");
        await repository.SetCurrentModeAsync(intersectionId, modeCode);

        var status = await StatusForModeAsync(intersectionId, modeCode);
        await repository.InsertLogAsync(intersectionId, status);

        return new CommandResult(command, "success", status);
    }

    public async Task<List<Dictionary<string, object?>>?> UpdatePhasePlanDurationsAsync(int phasePlanId, UpdatePhasePlanRequest request)
    {
        ValidateDurations(request.GreenSeconds, request.YellowSeconds);

        await repository.UpdatePhaseDurationsAsync(phasePlanId, request.GreenSeconds, request.YellowSeconds);

        var intersections = await repository.ListIntersectionsAsync();
        foreach (var intersection in intersections)
        {
            var plans = await repository.ListPhasePlansAsync(Convert.ToInt32(intersection["id"]));
            var updated = plans.FirstOrDefault(plan => Convert.ToInt32(plan["id"]) == phasePlanId);
            if (updated is not null)
            {
                return plans;
            }
        }

        return null;
    }

    public async Task<Dictionary<string, object?>?> CreateBasicPhasePlanAsync(int intersectionId, CreatePhasePlanRequest request)
    {
        if (!await repository.IntersectionExistsAsync(intersectionId))
        {
            return null;
        }

        ValidateDurations(request.GreenSeconds, request.YellowSeconds);
        var name = string.IsNullOrWhiteSpace(request.Name) ? $"Plan {DateTimeOffset.UtcNow:yyyyMMddHHmmss}" : request.Name.Trim();
        return await repository.CreateBasicPhasePlanAsync(intersectionId, name, request.GreenSeconds, request.YellowSeconds, request.Activate);
    }

    private async Task<TrafficStatus> StatusForModeAsync(int intersectionId, string modeCode)
    {
        if (modeCode == "AUTO")
        {
            return await ComputeAutoStatusAsync(intersectionId);
        }

        var approaches = await repository.ListApproachesAsync(intersectionId);
        var signals = approaches
            .Where(row => Convert.ToInt32(row["is_active"]) == 1)
            .Select(row =>
            {
                var code = Convert.ToString(row["code"]) ?? "";
                var color = modeCode switch
                {
                    "NIGHT" => DateTimeOffset.UtcNow.ToUnixTimeSeconds() % 2 == 0 ? "YELLOW" : "OFF",
                    "PRIORITY_NS" => code is "NORTH" or "SOUTH" ? "GREEN" : "RED",
                    "PRIORITY_EW" => code is "EAST" or "WEST" ? "GREEN" : "RED",
                    "EMERGENCY" => "RED",
                    _ => "OFF"
                };
                return new SignalStatus(code, Convert.ToString(row["signal_code"]) ?? "", color);
            })
            .ToList();

        var phaseCode = modeCode switch
        {
            "NIGHT" => "YELLOW_BLINK",
            "PRIORITY_NS" => "NS_PRIORITY",
            "PRIORITY_EW" => "EW_PRIORITY",
            "EMERGENCY" => "ALL_RED",
            _ => "MANUAL"
        };

        return new TrafficStatus(modeCode, phaseCode, -1, signals);
    }

    private async Task<TrafficStatus> ComputeAutoStatusAsync(int intersectionId)
    {
        var steps = await repository.ActivePhaseStepsAsync(intersectionId);
        if (steps.Count == 0)
        {
            return new TrafficStatus("AUTO", "NO_ACTIVE_PLAN", -1, []);
        }

        var totalDuration = steps.Sum(row => Convert.ToInt32(row["duration_seconds"]));
        var offset = (int)(DateTimeOffset.UtcNow.ToUnixTimeSeconds() % totalDuration);
        var elapsed = 0;
        var selected = steps[0];

        foreach (var step in steps)
        {
            elapsed += Convert.ToInt32(step["duration_seconds"]);
            if (offset < elapsed)
            {
                selected = step;
                break;
            }
        }

        var remaining = elapsed - offset;
        var states = await repository.PhaseSignalStatesAsync(Convert.ToInt32(selected["id"]));
        var signals = states
            .Select(row => new SignalStatus(Convert.ToString(row["approach"]) ?? "", Convert.ToString(row["signal"]) ?? "", Convert.ToString(row["color"]) ?? "OFF"))
            .ToList();

        return new TrafficStatus("AUTO", Convert.ToString(selected["code"]) ?? "AUTO", remaining, signals);
    }

    private static string NormalizeCommand(string? command, string? modeCode)
    {
        var normalized = string.IsNullOrWhiteSpace(command) ? "" : command.Trim().Replace(" ", "_", StringComparison.Ordinal).ToUpperInvariant();
        if (!string.IsNullOrWhiteSpace(normalized))
        {
            return normalized;
        }

        var mode = string.IsNullOrWhiteSpace(modeCode) ? "" : modeCode.Trim().Replace(" ", "_", StringComparison.Ordinal).ToUpperInvariant();
        return string.IsNullOrWhiteSpace(mode) ? "" : $"SET_{mode}";
    }

    private static void ValidateDurations(int greenSeconds, int yellowSeconds)
    {
        if (greenSeconds < 5)
        {
            throw new ArgumentException("greenSeconds must be at least 5");
        }

        if (yellowSeconds < 2)
        {
            throw new ArgumentException("yellowSeconds must be at least 2");
        }
    }
}

public sealed record IntersectionRow(int Id, string CurrentModeCode);
public sealed record CommandRequest(string? Command = null, string? ModeCode = null, string? Source = "mobile", string? CreatedBy = "operator")
{
    public string SourceOrDefault() => string.IsNullOrWhiteSpace(Source) ? "mobile" : Source.Trim();
    public string CreatedByOrDefault() => string.IsNullOrWhiteSpace(CreatedBy) ? "operator" : CreatedBy.Trim();
}
public sealed record CommandResult(string Command, string Status, TrafficStatus TrafficStatus);
public sealed record DashboardSnapshot(
    TrafficStatus Status,
    List<Dictionary<string, object?>> Approaches,
    List<Dictionary<string, object?>> PhasePlans,
    List<Dictionary<string, object?>> Commands,
    List<Dictionary<string, object?>> Logs,
    List<Dictionary<string, object?>> Modes);
public sealed record TrafficStatus(string ModeCode, string PhaseCode, int RemainingSeconds, List<SignalStatus> Signals);
public sealed record SignalStatus(string Approach, string Signal, string Color);
public sealed record CreateApproachRequest(string? Code = null, string? Name = null, int? DisplayOrder = null, bool IsActive = true, int? RedPin = null, int? YellowPin = null, int? GreenPin = null);
public sealed record UpdateApproachRequest(string? Name = null, int? DisplayOrder = null, bool? IsActive = null);
public sealed record UpdatePhasePlanRequest(int GreenSeconds, int YellowSeconds);
public sealed record CreatePhasePlanRequest(string? Name = null, int GreenSeconds = 8, int YellowSeconds = 3, bool Activate = false);
public sealed record CreateLogRequest(string? ModeCode = null, string? PhaseCode = null, int RemainingSeconds = -1, string? StatusJson = null);
public sealed record PhaseSeed(string Code, int SequenceNo, int DurationSeconds, Dictionary<string, string> SignalStates);
