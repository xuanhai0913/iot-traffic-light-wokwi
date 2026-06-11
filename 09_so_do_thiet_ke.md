# 09. Sơ Đồ Thiết Kế Dự Án

## ERD có phù hợp dự án không?

Có, ERD phù hợp nếu nhóm trình bày hệ thống theo hướng IoT có dashboard/mobile app và database quản lý. Phần mô phỏng Wokwi không bắt buộc database để chạy, nhưng database giúp bài lớn có chiều sâu hơn vì thể hiện được:

- Lưu cấu hình thời gian pha đèn.
- Lưu lịch sử lệnh điều khiển từ dashboard/mobile app.
- Lưu log trạng thái đèn theo thời gian.
- Có cơ sở để mở rộng sang backend/API thật.

Vì vậy cách trình bày tốt nhất là: Wokwi mô phỏng phần thiết bị, còn ERD/database mô tả phần hệ thống quản lý khi triển khai thực tế.

## Danh sách sơ đồ nên đưa vào báo cáo

| Sơ đồ | Có nên đưa vào report? | Mục đích |
|---|---:|---|
| Kiến trúc tổng thể | Có | Cho thấy app, backend, database và thiết bị mô phỏng liên kết thế nào |
| ERD/CSDL | Có | Thể hiện thiết kế database và dữ liệu log |
| State machine | Có | Giải thích thuật toán điều khiển đèn |
| Class diagram/OOP | Có | Thể hiện áp dụng OOP vào code |
| Sequence gửi lệnh | Nên có | Giải thích flow app gửi lệnh điều khiển |

## 1. Sơ đồ kiến trúc tổng thể

```mermaid
flowchart TD
    Operator["Người vận hành"]
    Admin["Người quản trị"]
    Dashboard["Dashboard / Mobile Web"]
    Backend["Backend API"]
    Database[("SQLite / Database")]
    Gateway["Serial / WiFi / MQTT Gateway"]
    Controller["ESP32 / Arduino Controller"]
    Wokwi["Wokwi Simulation"]
    Lights["2 cụm đèn giao thông"]
    Display["LCD / 7-seg countdown"]
    Buttons["Nút nhấn đổi chế độ"]

    Operator --> Dashboard
    Admin --> Dashboard
    Dashboard --> Backend
    Backend --> Database
    Backend --> Gateway
    Gateway --> Controller
    Buttons --> Controller
    Controller --> Lights
    Controller --> Display
    Controller --> Wokwi
    Controller --> Backend
```

## 2. ERD / Database schema

```mermaid
erDiagram
    INTERSECTIONS ||--o{ PHASE_CONFIGS : has
    INTERSECTIONS ||--o{ CONTROL_COMMANDS : receives
    INTERSECTIONS ||--o{ TRAFFIC_EVENT_LOGS : logs
    TRAFFIC_MODES ||--o{ PHASE_CONFIGS : configures
    TRAFFIC_MODES ||--o{ CONTROL_COMMANDS : used_by
    TRAFFIC_MODES ||--o{ TRAFFIC_EVENT_LOGS : appears_in

    INTERSECTIONS {
        int id PK
        string name
        string location
        string status
        datetime created_at
    }

    TRAFFIC_MODES {
        int id PK
        string code UK
        string name
        string description
    }

    PHASE_CONFIGS {
        int id PK
        int intersection_id FK
        string mode_code FK
        string direction
        int green_seconds
        int yellow_seconds
        int red_seconds
        boolean is_active
    }

    CONTROL_COMMANDS {
        int id PK
        int intersection_id FK
        string command
        string mode_code FK
        string source
        string created_by
        datetime created_at
    }

    TRAFFIC_EVENT_LOGS {
        int id PK
        int intersection_id FK
        string mode_code FK
        string ns_light
        string ew_light
        int remaining_seconds
        datetime created_at
    }
```

## 3. State machine điều khiển đèn

```mermaid
stateDiagram-v2
    [*] --> AUTO_NS_GREEN

    AUTO_NS_GREEN --> AUTO_NS_YELLOW: hết thời gian xanh Bắc-Nam
    AUTO_NS_YELLOW --> AUTO_EW_GREEN: hết thời gian vàng Bắc-Nam
    AUTO_EW_GREEN --> AUTO_EW_YELLOW: hết thời gian xanh Đông-Tây
    AUTO_EW_YELLOW --> AUTO_NS_GREEN: hết thời gian vàng Đông-Tây

    AUTO_NS_GREEN --> NIGHT: lệnh NIGHT
    AUTO_NS_YELLOW --> NIGHT: lệnh NIGHT
    AUTO_EW_GREEN --> NIGHT: lệnh NIGHT
    AUTO_EW_YELLOW --> NIGHT: lệnh NIGHT

    NIGHT --> AUTO_NS_GREEN: lệnh AUTO
    NIGHT --> NIGHT: vàng nhấp nháy

    AUTO_NS_GREEN --> PRIORITY_NS: lệnh PRIORITY_NS
    AUTO_EW_GREEN --> PRIORITY_EW: lệnh PRIORITY_EW
    PRIORITY_NS --> AUTO_NS_GREEN: lệnh AUTO
    PRIORITY_EW --> AUTO_NS_GREEN: lệnh AUTO

    AUTO_NS_GREEN --> EMERGENCY: lệnh EMERGENCY
    AUTO_EW_GREEN --> EMERGENCY: lệnh EMERGENCY
    NIGHT --> EMERGENCY: lệnh EMERGENCY
    PRIORITY_NS --> EMERGENCY: lệnh EMERGENCY
    PRIORITY_EW --> EMERGENCY: lệnh EMERGENCY
    EMERGENCY --> AUTO_NS_GREEN: lệnh AUTO
```

## 4. Class diagram / OOP

```mermaid
classDiagram
    class TrafficLight {
        -int redPin
        -int yellowPin
        -int greenPin
        +begin()
        +setRed()
        +setYellow()
        +setGreen()
        +turnOff()
    }

    class TrafficPhase {
        +String name
        +String nsLight
        +String ewLight
        +int durationSeconds
    }

    class ModeManager {
        -String currentMode
        +setMode(mode)
        +getMode()
        +isAuto()
        +isNight()
        +isEmergency()
    }

    class DisplayManager {
        +begin()
        +showMode(mode)
        +showCountdown(seconds)
        +showLights(nsLight, ewLight)
    }

    class IntersectionController {
        -TrafficLight nsLight
        -TrafficLight ewLight
        -ModeManager modeManager
        -DisplayManager displayManager
        +begin()
        +update()
        +runAuto()
        +runNight()
        +runPriority(direction)
        +runEmergency()
    }

    class CommandRepository {
        +saveCommand(command)
        +listRecentCommands()
    }

    class TrafficLogRepository {
        +saveLog(state)
        +listRecentLogs()
    }

    IntersectionController --> TrafficLight
    IntersectionController --> TrafficPhase
    IntersectionController --> ModeManager
    IntersectionController --> DisplayManager
    ModeManager --> CommandRepository
    IntersectionController --> TrafficLogRepository
```

## 5. Sequence flow khi người dùng đổi chế độ

```mermaid
sequenceDiagram
    actor User as Người vận hành
    participant UI as Dashboard/Mobile Web
    participant API as Backend API
    participant DB as Database
    participant Device as ESP32/Arduino
    participant Sim as Wokwi/Đèn mô phỏng

    User->>UI: Chọn mode NIGHT/PRIORITY/EMERGENCY
    UI->>API: POST /api/commands
    API->>DB: Lưu control_commands
    API->>Device: Gửi lệnh điều khiển
    Device->>Device: ModeManager cập nhật mode
    Device->>Sim: Bật/tắt LED theo mode
    Device->>API: Gửi trạng thái hiện tại
    API->>DB: Lưu traffic_event_logs
    API->>UI: Trả về trạng thái mới
    UI->>User: Hiển thị mode và countdown
```

## 6. Data flow rút gọn

```mermaid
flowchart LR
    Input["Input: button / dashboard command"]
    Validate["Kiểm tra lệnh"]
    Mode["Cập nhật mode"]
    Control["Điều khiển LED + countdown"]
    Log["Ghi log trạng thái"]
    Output["Output: đèn, LCD, dashboard"]

    Input --> Validate
    Validate --> Mode
    Mode --> Control
    Control --> Log
    Control --> Output
    Log --> Output
```

## Cách dùng trong báo cáo

- Dùng sơ đồ kiến trúc ở phần tổng quan hệ thống.
- Dùng ERD ở phần thiết kế CSDL.
- Dùng state machine ở phần thuật toán điều khiển.
- Dùng class diagram ở phần áp dụng OOP.
- Dùng sequence flow ở phần dashboard/mobile app điều khiển.

