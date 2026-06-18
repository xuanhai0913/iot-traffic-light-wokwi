# Traffic Light MVP Backend - C# ASP.NET Core

Backend chinh cua MVP dung:

- C# / ASP.NET Core 8 Minimal API
- SQLite qua `Microsoft.Data.Sqlite`
- MQTT bridge qua `MQTTnet`
- Schema trong `schema.sql`

ESP32/Wokwi van dung Arduino C/C++ trong `wokwi/sketch.ino`. C# la stack chinh cho lop backend/API va database.

## Yeu cau

May can cai **.NET SDK 8**. Neu `dotnet --info` chi hien Runtime va bao `No SDKs were found`, hay cai SDK truoc khi chay.

## Chay backend

```powershell
cd backend
dotnet restore
dotnet run
```

API chay tai:

```text
http://127.0.0.1:8000
```

Khi khoi dong lan dau, backend tu tao `traffic.db`, tao schema va seed du lieu demo cho giao lo 4 huong.

## Chay demo bang dien thoai

Tu thu muc goc repository, dung script nay de backend bind ra LAN, bat MQTT va in ra IP cho dien thoai:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\run-backend-demo.ps1
```

Neu can doi port:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\run-backend-demo.ps1 -Port 8010
```

Neu chi muon xem IP/env ma khong start backend:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\run-backend-demo.ps1 -DryRun
```

Giu terminal nay mo trong luc demo. Tren Flutter Settings, nhap URL dang `http://<IP_LAN_CUA_LAPTOP>:8000`.

## MQTT bridge

Mac dinh backend ket noi public broker de dieu khien ESP32/Wokwi:

```text
broker.hivemq.com:1883
```

Topic mac dinh:

```text
traffic/hainx-iot-traffic-light/intersections/1/commands
traffic/hainx-iot-traffic-light/intersections/1/status
traffic/hainx-iot-traffic-light/intersections/1/acks
```

Bien moi truong co the cau hinh:

```powershell
$env:MQTT_ENABLED="true"
$env:MQTT_HOST="broker.hivemq.com"
$env:MQTT_PORT="1883"
$env:MQTT_TOPIC_PREFIX="traffic/hainx-iot-traffic-light"
dotnet run
```

Neu chi muon test API/database khong dung MQTT:

```powershell
$env:MQTT_ENABLED="false"
dotnet run
```

## Endpoints

| Method | Endpoint | Muc dich |
|---|---|---|
| GET | `/api/health` | Kiem tra backend |
| GET | `/api/traffic-modes` | Danh sach mode dieu khien |
| GET | `/api/intersections` | Danh sach giao lo |
| GET | `/api/intersections/1/dashboard` | Snapshot tong hop cho dashboard PWA |
| GET | `/api/intersections/1/status` | Trang thai hien tai |
| GET | `/api/intersections/1/approaches` | Danh sach tuyen duong va signal head |
| POST | `/api/intersections/1/approaches` | Them tuyen duong |
| PUT | `/api/approaches/{id}` | Cap nhat/bat tat tuyen duong |
| GET | `/api/intersections/1/phase-plans` | Xem phase plan |
| GET | `/api/intersections/1/devices` | Trang thai thiet bi ESP32/Wokwi |
| POST | `/api/intersections/1/phase-plans` | Tao phase plan co ban |
| PUT | `/api/phase-plans/{id}` | Cap nhat thoi gian xanh/vang |
| POST | `/api/phase-plans/{id}/activate` | Kich hoat phase plan |
| POST | `/api/intersections/1/commands` | Gui lenh doi mode |
| GET | `/api/intersections/1/commands` | Lich su lenh |
| GET | `/api/intersections/1/logs` | Log trang thai |
| POST | `/api/intersections/1/logs` | Ghi log trang thai |
| GET | `/api/mqtt/status` | Kiem tra ket noi MQTT bridge |
| POST | `/api/mqtt/test-command` | Publish command test qua MQTT |

## Lenh dieu khien

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:8000/api/intersections/1/commands `
  -ContentType "application/json" `
  -Body '{"command":"SET_EMERGENCY","source":"mobile","createdBy":"operator"}'
```

Lenh ho tro:

- `SET_AUTO`
- `SET_NIGHT`
- `SET_PRIORITY_NS`
- `SET_PRIORITY_EW`
- `SET_EMERGENCY`

## Cap nhat cau hinh pha

```powershell
Invoke-RestMethod `
  -Method Put `
  -Uri http://127.0.0.1:8000/api/phase-plans/1 `
  -ContentType "application/json" `
  -Body '{"greenSeconds":10,"yellowSeconds":3}'
```

## Tao phase plan co ban

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:8000/api/intersections/1/phase-plans `
  -ContentType "application/json" `
  -Body '{"name":"Plan 10-3","greenSeconds":10,"yellowSeconds":3,"activate":true}'
```

## Them tuyen duong

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:8000/api/intersections/1/approaches `
  -ContentType "application/json" `
  -Body '{"code":"NORTH_LEFT","name":"North left turn","displayOrder":5,"isActive":true}'
```

## MVP coverage

- SQLite schema mo rong cho intersections, approaches, signal heads, modes, phase plans, commands va logs.
- MQTT command/status/ack bridge cho luong Flutter/backend dieu khien Wokwi.
- Seed du lieu giao lo 4 huong.
- API status, command, history, logs, roads, modes va phase config.
- Guard cho emergency mode.
- Validate conflict helper cho phase step.
- PWA trong `mobile_app/` goi API C# that.

## Smoke test

Sau khi backend dang chay, co the test nhanh bang:

```powershell
.\smoke-test.ps1
```

Neu PowerShell chan script:

```powershell
powershell -ExecutionPolicy Bypass -File .\smoke-test.ps1
```

Hoac mo `backend/requests.http` bang Visual Studio/VS Code REST Client de goi tung endpoint.
