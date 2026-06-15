# Phu luc trien khai MVP va OOP

Tai lieu nay dung de chen vao bao cao hoac tach thanh phu luc khi thuyet trinh. Noi dung tap trung vao cac diem cong: OOP, backend C#, SQLite, API that, PWA dashboard va mo hinh mo rong nhieu tuyen duong.

## 1. Pham vi da trien khai

He thong hien co 3 lop:

| Lop | Cong nghe | Vai tro |
|---|---|---|
| Thiet bi mo phong | ESP32/Wokwi + Arduino C++ | Dieu khien den, LCD, button, Serial command |
| Ung dung van hanh | Mobile web/PWA HTML/CSS/JS | Dashboard, control mode, phase config, roads, history, logs |
| Backend va database | C# ASP.NET Core 8 + SQLite | REST API, xu ly command, luu config/history/log |

MVP dap ung Muc 1 va Muc 2:

- Wokwi chay du mode `AUTO`, `NIGHT`, `PRIORITY_NS`, `PRIORITY_EW`, `EMERGENCY`.
- Backend C# cung cap API that, khong chi mock UI.
- SQLite luu command, log, phase plan, road approaches, signal heads va conflict rules.
- PWA goi backend API that va hien thi dashboard truc quan.
- Mo hinh database ho tro N tuyen duong, N signal heads va nhieu phase plans.

## 2. OOP tren ESP32/Wokwi

File: `wokwi/sketch.ino`

| Class/Thanh phan | Trach nhiem | Diem OOP |
|---|---|---|
| `TrafficLight` | Dong goi 3 chan red/yellow/green va ham `show()` | Encapsulation phan dieu khien LED |
| `RoadApproach` | Dai dien mot huong vao giao lo: NORTH, SOUTH, EAST, WEST | Model hoa tung tuyen duong rieng |
| `ModeManager` | Quan ly mode, button debounce, serial command | Tach input command khoi logic den |
| `DisplayManager` | Cap nhat LCD va Serial log | Single Responsibility |
| `IntersectionController` | Dieu phoi state machine, timer va mode | Composition cac object |
| `TrafficPhase` | Mo ta phase AUTO gom mau den va duration | Model hoa domain traffic light |

Ly do co diem cong:

- Code thiet bi khong viet theo kieu `loop()` dai va roi rac.
- Cac class co trach nhiem rieng, de giai thich trong class diagram.
- State machine nam trong `IntersectionController`, input command nam trong `ModeManager`.
- Wokwi da nang tu 2 cum NS/EW len 4 cum den NORTH/SOUTH/EAST/WEST de nhin giong nga tu that hon.

## 3. OOP trong backend C#

File: `backend/Program.cs`

| Class/Record | Vai tro |
|---|---|
| `TrafficDatabase` | Mo ket noi SQLite, init schema, seed du lieu demo |
| `TrafficRepository` | Doc/ghi du lieu: intersections, roads, phase plans, commands, logs |
| `TrafficService` | Xu ly nghiep vu: status, dashboard, command, validate duration |
| `TrafficStatus` | DTO trang thai hien tai cua giao lo |
| `SignalStatus` | DTO trang thai tung signal head |
| `DashboardSnapshot` | DTO tong hop cho dashboard PWA |
| `CommandRequest`, `CreateApproachRequest`, `CreatePhasePlanRequest` | DTO input cho API |

Nguyen tac OOP/clean code da ap dung:

- Tach database access vao repository.
- Tach business logic vao service.
- Dung record DTO de mo ta request/response ro rang.
- Validate command va emergency guard trong service layer.
- Dung parameterized query cua `Microsoft.Data.Sqlite`, tranh ghep SQL tu input nguoi dung.

## 4. OOP trong PWA/mobile app

File: `mobile_app/app.js`

PWA khong co class theo framework Flutter, nhung da tach module logic theo vai tro:

| Nhom ham | Vai tro |
|---|---|
| `apiGet`, `apiPost`, `apiPut`, `api` | Data access layer goi backend |
| `loadDashboard`, `loadStatus`, `loadHistory`, `loadRoads`, `loadPhasePlans`, `loadLogs` | Repository/controller logic |
| `sendCommand`, `savePhaseConfig`, `createRoad`, `toggleRoad` | Use case/action logic |
| `render`, `renderSignals`, `renderPhasePlan`, `renderModes`, `renderLogs` | Presentation rendering |
| `normalizeStatus`, `applyActivePlanConfig`, `activePhasePlan` | Domain transformation |

Diem trinh bay:

- UI khong tu tinh toan mock state machine nua; no doc state that tu backend.
- App co cac man hinh/section tuong ung plan: Dashboard, Control, Config, Roads, History, Logs.
- App co offline state va request timeout de demo khong bi treo khi backend chua chay.

## 5. Database va mo hinh mo rong

File: `backend/schema.sql`

Bang chinh:

- `intersections`: giao lo.
- `road_approaches`: nhieu tuyen duong trong mot giao lo.
- `signal_heads`: cum den cua tung tuyen.
- `traffic_modes`: mode va priority level.
- `phase_plans`: tap phase co the kich hoat.
- `phase_steps`: tung buoc trong phase plan.
- `phase_signal_states`: mau den cua tung signal head trong tung phase.
- `conflict_rules`: ma tran xung dot.
- `control_commands`: lich su lenh.
- `traffic_event_logs`: log trang thai.

Thiet ke nay tot hon mo hinh chi co `NS` va `EW` vi co the mo rong sang:

- Nga ba, nga nam.
- Huong re trai rieng.
- Nhieu phase plan cho tung thoi diem.
- Nhieu signal head cho mot road approach.

## 6. API da trien khai

| Endpoint | Vai tro |
|---|---|
| `GET /api/health` | Kiem tra backend |
| `GET /api/traffic-modes` | Danh sach mode va priority |
| `GET /api/intersections` | Danh sach giao lo |
| `GET /api/intersections/1/dashboard` | Snapshot tong hop cho PWA |
| `GET /api/intersections/1/status` | Trang thai hien tai |
| `GET/POST /api/intersections/1/approaches` | Xem/them tuyen duong |
| `PUT /api/approaches/{id}` | Bat/tat hoac cap nhat tuyen |
| `GET/POST /api/intersections/1/phase-plans` | Xem/tao phase plan |
| `PUT /api/phase-plans/{id}` | Cap nhat green/yellow duration |
| `POST /api/phase-plans/{id}/activate` | Kich hoat phase plan |
| `GET/POST /api/intersections/1/commands` | Xem/gui command |
| `GET/POST /api/intersections/1/logs` | Xem/ghi log |

## 7. Luong demo de thuyet trinh

1. Mo Wokwi va chay ESP32.
2. Nhan button hoac Serial command de cho thay thiet bi co `AUTO`, `NIGHT`, `PRIORITY`, `EMERGENCY`.
3. Mo backend C# va PWA.
4. Trong PWA, bam `AUTO/NIGHT/NS/EW/SOS`.
5. Chi ra command duoc luu vao SQLite va history/log cap nhat.
6. Sua green/yellow duration trong Config.
7. Them road approach `NORTH_LEFT` de chung minh data model mo rong.
8. Mo section `Phase plan`, `Signal heads`, `Mode priority` de giai thich OOP va state machine.

## 8. Test evidence

Lenh build backend:

```powershell
.\.dotnet\dotnet.exe build backend\TrafficLightMvp.csproj
```

Ket qua da dat:

```text
Build succeeded.
0 Warning(s)
0 Error(s)
```

Smoke test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File backend\smoke-test.ps1
```

Ket qua da dat:

```text
Health: ok
Command result: SET_NIGHT success
History rows: 2
Phase plans: 1
Approaches: 4
Smoke test completed.
```

## 9. Noi dung nen dua vao slide

- Slide kien truc 3 lop: PWA -> C# API -> SQLite va ESP32/Wokwi.
- Slide state machine: AUTO/NIGHT/PRIORITY/EMERGENCY.
- Slide OOP ESP32: `TrafficLight`, `ModeManager`, `DisplayManager`, `IntersectionController`.
- Slide OOP backend: `TrafficDatabase`, `TrafficRepository`, `TrafficService`, DTO records.
- Slide database ERD: intersections, road approaches, signal heads, phase plans, commands, logs.
- Slide demo: anh PWA dashboard + anh Wokwi + API smoke test.

## 10. Gioi han va huong phat trien

Gioi han hien tai:

- Wokwi va backend chua noi realtime voi nhau.
- SQLite local tren free hosting co the mat data neu filesystem bi reset.
- Chua co authentication/role admin/operator.

Huong phat trien:

- Them MQTT: backend publish command, ESP32 subscribe command.
- ESP32 publish status/log ve backend.
- Doi SQLite sang Postgres khi deploy production.
- Them dashboard phan tich luu luong, sensor gia lap va conflict matrix nang cao.
