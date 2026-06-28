# 09. Sơ Đồ Thiết Kế Dự Án

> Cập nhật theo repository ngày 28/06/2026. Source Mermaid trong `assets/diagrams/` là bộ sơ đồ gốc để đưa sang report/PPT.

## 1. Nguyên tắc trình bày cho đúng thực tế

- Wokwi là lớp **thiết bị mô phỏng**, không phải toàn bộ hệ thống.
- App không điều khiển trực tiếp ESP32; luồng đúng là **Flutter/PWA -> C# API -> MQTT -> ESP32/Wokwi**.
- SQLite là phần backend quản lý phase plan, command history, device status và log; không phải thành phần bắt buộc để firmware tự chạy AUTO/NIGHT/PRIORITY/EMERGENCY.
- Dashboard có thể hiển thị **trạng thái logic backend** trước khi thiết bị ACK. Vì vậy khi demo cần phân biệt `HTTP 201`, `published` và `acknowledged`.
- Wokwi đang hiển thị 4 hướng logic `NORTH/SOUTH/EAST/WEST`, nhưng phần cứng mô phỏng hiện dùng **2 nhóm GPIO độc lập**: một nhóm cho trục Bắc-Nam, một nhóm cho trục Đông-Tây.

## 2. Danh sách sơ đồ nên dùng

| Sơ đồ | File nguồn | Mục đích |
|---|---|---|
| Kiến trúc tổng thể | `assets/diagrams/architecture.mmd` | Thể hiện app, backend, MQTT, SQLite và thiết bị |
| Luồng dữ liệu | `assets/diagrams/data_flow.mmd` | Phân biệt command từ app với input local ở Wokwi |
| ERD / schema | `assets/diagrams/erd.mmd` | Bám đúng schema SQLite hiện tại |
| State machine | `assets/diagrams/state_machine.mmd` | Mô tả AUTO 8s/3s, các mode và service mode |
| Sequence command | `assets/diagrams/sequence_command.mmd` | Giải thích publish, ACK và lịch sử command |
| Sequence mobile demo | `assets/diagrams/mobile_command_flow.mmd` | Giải thích demo app trên điện thoại |
| Class diagram / OOP | `assets/diagrams/class_diagram.mmd` | Thể hiện OOP ở firmware + backend bridge |

## 3. Sơ đồ kiến trúc tổng thể

```mermaid
flowchart LR
    Operator["Nguoi van hanh"]
    Mobile["Flutter app / PWA"]
    Api["C# ASP.NET Core API"]
    Service["TrafficService"]
    Repo["TrafficRepository"]
    Db[("SQLite")]
    Bridge["MqttTrafficBridge"]
    Broker["MQTT broker"]
    Device["ESP32 firmware"]
    Controller["IntersectionController + mode strategies"]
    Inputs["Button / Serial command"]
    Scene["Wokwi scene"]
    Signals["4 huong logic: NORTH, SOUTH, EAST, WEST"]
    Display["LCD + countdown + event log"]
    Ack["ACK / status / log stream"]

    Operator --> Mobile
    Mobile -->|"HTTP/JSON"| Api
    Api --> Service
    Service --> Repo
    Repo --> Db
    Service --> Bridge
    Bridge -->|"publish command"| Broker
    Broker -->|"traffic/.../commands"| Device
    Device --> Controller
    Inputs --> Controller
    Controller --> Signals
    Controller --> Display
    Signals --> Scene
    Display --> Scene
    Controller --> Ack
    Ack -->|"traffic/.../status + acks"| Broker
    Broker --> Bridge
    Bridge --> Repo
    Repo --> Db
```

## 4. Luồng dữ liệu chính

```mermaid
flowchart TD
    Remote["Flutter/PWA gui command"]
    Local["Button / Serial command tai Wokwi"]
    Api["POST /api/intersections/1/commands"]
    Guard["TrafficService validate + emergency guard"]
    CommandDb["SQLite: control_commands = queued/published/acknowledged"]
    Publish["MQTT publish command"]
    Firmware["ModeManager + IntersectionController"]
    Render["LED/LCD doi trang thai"]
    Status["ESP32 publish status + ACK"]
    StatusDb["SQLite: device_statuses + traffic_event_logs"]
    Read["GET /dashboard va /status"]
    User["Nguoi van hanh xem app va Wokwi"]

    Remote --> Api
    Api --> Guard
    Guard --> CommandDb
    Guard --> Publish
    Publish --> Firmware
    Local --> Firmware
    Firmware --> Render
    Firmware --> Status
    Status --> StatusDb
    CommandDb --> Read
    StatusDb --> Read
    Read --> User
    Render --> User
```

## 5. ERD / Database schema

```mermaid
erDiagram
    INTERSECTIONS ||--o{ ROAD_APPROACHES : has
    ROAD_APPROACHES ||--o{ SIGNAL_HEADS : owns
    INTERSECTIONS ||--o{ PHASE_PLANS : has
    PHASE_PLANS ||--o{ PHASE_STEPS : contains
    PHASE_STEPS ||--o{ PHASE_SIGNAL_STATES : applies
    SIGNAL_HEADS ||--o{ PHASE_SIGNAL_STATES : receives
    INTERSECTIONS ||--o{ CONFLICT_RULES : defines
    ROAD_APPROACHES ||--o{ CONFLICT_RULES : source
    ROAD_APPROACHES ||--o{ CONFLICT_RULES : target
    TRAFFIC_MODES ||--o{ CONTROL_COMMANDS : used_by
    INTERSECTIONS ||--o{ CONTROL_COMMANDS : receives
    TRAFFIC_MODES ||--o{ TRAFFIC_EVENT_LOGS : appears_in
    INTERSECTIONS ||--o{ TRAFFIC_EVENT_LOGS : logs
    INTERSECTIONS ||--o{ DEVICE_STATUSES : monitors
```

ERD hiện tại bám đúng `backend/schema.sql`, không còn dừng ở mô hình cũ chỉ có `intersections`, `phase_configs`, `control_commands`, `traffic_event_logs`.

## 6. State machine điều khiển

```mermaid
stateDiagram-v2
    [*] --> AUTO

    state AUTO {
        [*] --> NS_GREEN
        NS_GREEN --> NS_YELLOW: 8s mac dinh
        NS_YELLOW --> EW_GREEN: 3s mac dinh
        EW_GREEN --> EW_YELLOW: 8s mac dinh
        EW_YELLOW --> NS_GREEN: 3s mac dinh
    }

    AUTO --> NIGHT: SET_NIGHT
    AUTO --> PRIORITY_NS: SET_PRIORITY_NS
    AUTO --> PRIORITY_EW: SET_PRIORITY_EW
    AUTO --> EMERGENCY: SET_EMERGENCY
    AUTO --> MAINTENANCE: SET_MAINTENANCE

    NIGHT --> AUTO: SET_AUTO
    NIGHT --> EMERGENCY: SET_EMERGENCY
    NIGHT --> MAINTENANCE: SET_MAINTENANCE

    PRIORITY_NS --> AUTO: SET_AUTO
    PRIORITY_NS --> EMERGENCY: SET_EMERGENCY
    PRIORITY_NS --> MAINTENANCE: SET_MAINTENANCE

    PRIORITY_EW --> AUTO: SET_AUTO
    PRIORITY_EW --> EMERGENCY: SET_EMERGENCY
    PRIORITY_EW --> MAINTENANCE: SET_MAINTENANCE

    EMERGENCY --> AUTO: SET_AUTO
    EMERGENCY --> NIGHT: SET_NIGHT
    EMERGENCY --> MAINTENANCE: SET_MAINTENANCE

    MAINTENANCE --> AUTO: SET_AUTO
```

Ghi chú:

- `AUTO` dùng chu kỳ mặc định `8s xanh / 3s vàng / 8s xanh / 3s vàng`.
- `MAINTENANCE` có trong firmware như service mode, nhưng không phải mode chính đang expose ở app cho buổi demo thông thường.
- Backend hiện cho chỉnh phase plan ở SQLite, nhưng **chưa tự động đồng bộ** duration đó xuống firmware qua luồng app chuẩn.

## 7. Class diagram / OOP

```mermaid
classDiagram
    class TrafficLight {
        +begin()
        +setColor(color)
        +turnOff()
    }

    class RoadApproach {
        +setColor(color)
        +allOff()
        +name()
    }

    class PedestrianSignal {
        +setWalk(enabled)
    }

    class ModeManager {
        +setMode(mode)
        +cycleButtonMode()
        +parseCommand(command)
    }

    class PhaseConfig {
        +greenSeconds()
        +yellowSeconds()
        +setDuration(phase, seconds)
    }

    class DisplayManager {
        +showMode(mode)
        +showPhase(phase)
        +showCountdown(seconds)
    }

    class EventLog {
        +add(level, message)
        +recentEntries()
    }

    class IModeStrategy {
        <<interface>>
        +enter()
        +tick(nowMs)
        +phaseCode()
    }

    class AutoMode
    class NightMode
    class PriorityNSMode
    class PriorityEWMode
    class EmergencyMode
    class MaintenanceMode

    class IntersectionController {
        +begin()
        +update()
        +applyExternalCommand(cmd)
        +buildStatusJson()
    }

    class MqttClientManager {
        +connect()
        +handleIncomingCommand()
        +publishStatus()
        +publishAck()
    }

    class TrafficRepository {
        +InsertCommandAsync()
        +MarkCommandPublishedAsync()
        +UpsertDeviceStatusAsync()
    }

    class TrafficService {
        +HandleCommandAsync()
        +GetDashboardAsync()
        +UpdatePhasePlanDurationsAsync()
    }
```

Điểm cần nói khi thuyết trình:

- Firmware áp dụng OOP rõ nhất ở `ModeManager`, `IntersectionController` và nhóm `IModeStrategy`.
- Backend áp dụng service/repository + interface publisher.
- Flutter cũng có tách model/view/client, nhưng nếu cần một class diagram ngắn gọn thì nên ưu tiên firmware + backend như trên để sát phần điều khiển IoT.

## 8. Sequence flow khi gửi lệnh

```mermaid
sequenceDiagram
    actor User as Nguoi van hanh
    participant App as Flutter/PWA
    participant API as C# API
    participant DB as SQLite
    participant MQTT as MQTT broker
    participant Device as ESP32/Wokwi

    User->>App: Chon mode
    App->>API: POST /api/intersections/1/commands
    API->>DB: Insert command (device_status=queued)
    API->>DB: Update current_mode_code + insert log logic
    API->>MQTT: Publish command
    alt Publish thanh cong
        API->>DB: Mark command = published
        API-->>App: HTTP 201 + trafficStatus logic
        MQTT->>Device: Deliver command
        Device->>Device: Apply mode, doi LED/LCD
        Device->>MQTT: Publish ACK + status
        MQTT->>API: ACK/status event
        API->>DB: Update device_status = acknowledged
        API->>DB: Upsert device_statuses + insert traffic_event_logs
        App->>API: GET /dashboard or /status
        API-->>App: History + last seen + status
    else Publish loi
        API->>DB: Mark command = publish_failed
        API-->>App: HTTP 201 + trafficStatus logic
    end
```

Điểm quan trọng để tránh nói sai:

- `HTTP 201` chi cho biết API da nhan va xu ly nghiep vu.
- `published` chi cho biết backend da publish len broker.
- `acknowledged` moi la bang chung manh nhat rang ESP32/Wokwi da nhan lenh.

## 9. Sequence mobile demo

```mermaid
sequenceDiagram
    actor Operator as Nguoi van hanh
    participant Phone as Flutter app tren dien thoai
    participant API as C# API
    participant DB as SQLite
    participant MQTT as MQTT broker
    participant ESP32 as ESP32/Wokwi

    Operator->>Phone: Nhap API URL va bam Test
    Phone->>API: GET /health
    API-->>Phone: status ok

    Operator->>Phone: Gui SET_PRIORITY_NS
    Phone->>API: POST /commands
    API->>DB: Luu command + mode logic
    API->>MQTT: Publish command
    API-->>Phone: 201 Created

    MQTT->>ESP32: Command
    ESP32->>ESP32: ModeManager + IntersectionController xu ly
    ESP32->>MQTT: ACK + status moi
    MQTT->>API: Forward ACK/status
    API->>DB: Update acknowledged + device last seen

    loop Moi 1 giay khi online
        Phone->>API: GET /dashboard
        API-->>Phone: command history + device status
    end

    Phone-->>Operator: Thay history, mode va last seen
```

## 10. Khuyen nghi khi dua vao report/PPT

- Neu can ngan gon, uu tien 4 so do: **kien truc tong the, ERD, state machine, sequence command**.
- Neu giang vien hoi ve OOP, mo them class diagram va noi ro phan strategy mode trong firmware.
- Neu giang vien hoi ve database, dung ERD moi; khong quay lai mo hinh cu chi co 4 bang.
- Neu giang vien hoi ve app, noi dung chuan la: app dieu khien backend, backend dieu phoi MQTT, Wokwi mo phong thiet bi.
