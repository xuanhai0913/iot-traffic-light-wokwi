# Implementation Status

## Selected Tech Stack

- Main backend: C# ASP.NET Core 8 Minimal API.
- Database: SQLite, using the schema in `backend/schema.sql`.
- Mobile operator app: PWA in `mobile_app/`, calling the C# backend API at `http://127.0.0.1:8000`.
- Device simulation: ESP32/Wokwi using Arduino C/C++ in `wokwi/sketch.ino`.

Arduino/ESP32 does not require C#. The `.ino` file is expected to use Arduino C/C++. C# is used as the main application/backend stack for the MVP.

## Level 1 Coverage

- Wokwi supports AUTO, NIGHT, PRIORITY_NS, PRIORITY_EW, and EMERGENCY modes.
- Wokwi diagram now shows 4 visual signal clusters: NORTH, SOUTH, EAST, and WEST.
- LCD, buttons, and Serial commands are implemented in the Wokwi sketch.
- Backend exposes status, command, history, and logs APIs.
- SQLite stores command history, traffic logs, phase plans, approaches, signal heads, and conflict rules.
- PWA displays the current mode, phase, countdown, signal state, and command history from the backend.
- PWA now includes operator dashboard panels: metrics, four approach signals, signal heads, phase plan, mode priority, roads, history, and logs.

## Level 2 Coverage

- PWA calls the real C# backend API.
- Backend persists data in real SQLite tables.
- PWA includes road/approach management for a multi-road intersection model.
- Database schema supports N road approaches, N signal heads, and phase plans.
- Backend code is organized around database/repository/service responsibilities.
- Backend exposes `/api/intersections/1/dashboard` for a complete dashboard snapshot.
- Repo includes deploy-ready files: `backend/Dockerfile`, `backend/.dockerignore`, and `render.yaml`.

## How To Run

Install .NET SDK 8 first. The current machine only has the .NET Runtime, so `dotnet build` and `dotnet run` will not work until the SDK is installed.

```powershell
cd backend
dotnet restore
dotnet run
```

Then run the PWA:

```powershell
python -m http.server 4173
```

Open:

```text
http://localhost:4173/mobile_app/
```

## Verification Notes

- `mobile_app/app.js` passes `node --check`.
- `dotnet build backend/TrafficLightMvp.csproj` is currently blocked because no .NET SDK is installed.
