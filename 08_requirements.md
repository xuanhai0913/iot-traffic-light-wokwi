# 08. Requirements Dự Án

## Ghi chú định hướng điểm

Để bài lớn có điểm tốt hơn, nhóm không nên chỉ dừng ở mô phỏng đèn giao thông. Nên trình bày rõ cách dự án áp dụng nhiều phần đã học:

- Mô phỏng IoT bằng Wokwi.
- Thuật toán điều khiển và state machine.
- Thiết kế CSDL và database.
- OOP trong code điều khiển.
- Dashboard/mobile app để điều khiển và giám sát.
- Báo cáo có sơ đồ khối, sơ đồ mạch, ERD/database schema, flow xử lý và kết quả demo.

Bộ sơ đồ thiết kế ban đầu nằm ở [09_so_do_thiet_ke.md](./09_so_do_thiet_ke.md). Các source Mermaid riêng nằm trong `assets/diagrams/`.

## Vai trò người dùng

| Vai trò | Mô tả |
|---|---|
| Người vận hành | Chọn chế độ điều khiển đèn, theo dõi trạng thái giao lộ |
| Hệ thống điều khiển | Nhận lệnh, chạy thuật toán, bật/tắt đèn theo trạng thái |
| Người quản trị | Xem lịch sử lệnh, cấu hình thời gian pha đèn |

## Yêu cầu chức năng bắt buộc

| ID | Yêu cầu | Mức ưu tiên | Ghi chú |
|---|---|---:|---|
| FR-01 | Hệ thống mô phỏng 1 giao lộ gồm 2 hướng Bắc-Nam và Đông-Tây | Must | Mỗi hướng có đỏ, vàng, xanh |
| FR-02 | Hệ thống có chế độ AUTO | Must | Chạy theo chu kỳ xanh-vàng-đỏ |
| FR-03 | Hệ thống có chế độ NIGHT | Must | Vàng nhấp nháy cảnh báo ban đêm |
| FR-04 | Hệ thống có chế độ PRIORITY | Must | Ưu tiên một hướng khi cần |
| FR-05 | Hệ thống có chế độ EMERGENCY | Must | Tất cả hướng đỏ |
| FR-06 | LCD/7-seg/Serial hiển thị trạng thái hiện tại và countdown | Must | Ưu tiên LCD trong Wokwi |
| FR-07 | Có nút nhấn hoặc Serial command để đổi chế độ | Must | Dùng được trong demo Wokwi |
| FR-08 | Có ảnh/video/GIF chứng minh mô phỏng chạy | Must | Dùng trong report/slide |

## Yêu cầu nâng điểm

| ID | Yêu cầu | Mức ưu tiên | Ghi chú |
|---|---|---:|---|
| ER-01 | Có thiết kế CSDL/ERD cho hệ thống | Should | Dù demo chưa cần database thật vẫn nên trình bày |
| ER-02 | Có database lưu cấu hình pha đèn và lịch sử lệnh | Should | Có thể dùng SQLite/JSON mock |
| ER-03 | Code áp dụng OOP | Should | Arduino C++ hoặc dashboard/backend |
| ER-04 | Có dashboard/mobile web mock | Should | Giao diện điều khiển AUTO/NIGHT/PRIORITY/EMERGENCY |
| ER-05 | Có API mô phỏng gửi lệnh điều khiển | Should | Mobile app gửi command, backend lưu lịch sử |
| ER-06 | Có mô tả kết nối IoT qua WiFi/MQTT/HTTP | Could | Dùng trong báo cáo và slide |
| ER-07 | Có mobile app/PWA mock | Should | Đã có trong `mobile_app/` |

## Thiết kế CSDL đề xuất

Nếu làm database thật, dùng SQLite là đủ nhẹ. Nếu không kịp, nhóm vẫn nên đưa schema này vào báo cáo để thể hiện năng lực thiết kế CSDL.

### Bảng `intersections`

Lưu thông tin giao lộ.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | Mã giao lộ |
| `name` | TEXT | Tên giao lộ |
| `location` | TEXT | Vị trí mô tả |
| `status` | TEXT | `active`, `maintenance` |
| `created_at` | DATETIME | Thời điểm tạo |

### Bảng `traffic_modes`

Lưu danh sách chế độ điều khiển.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | Mã chế độ |
| `code` | TEXT UNIQUE | `AUTO`, `NIGHT`, `PRIORITY_NS`, `PRIORITY_EW`, `EMERGENCY` |
| `name` | TEXT | Tên hiển thị |
| `description` | TEXT | Mô tả chế độ |

### Bảng `phase_configs`

Lưu cấu hình thời gian từng pha đèn.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | Mã cấu hình |
| `intersection_id` | INTEGER FK | Giao lộ áp dụng |
| `mode_code` | TEXT | Chế độ áp dụng |
| `direction` | TEXT | `NS` hoặc `EW` |
| `green_seconds` | INTEGER | Thời gian đèn xanh |
| `yellow_seconds` | INTEGER | Thời gian đèn vàng |
| `red_seconds` | INTEGER | Thời gian đèn đỏ |
| `is_active` | BOOLEAN | Cấu hình đang dùng |

### Bảng `control_commands`

Lưu lịch sử lệnh từ dashboard/mobile app.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | Mã lệnh |
| `intersection_id` | INTEGER FK | Giao lộ nhận lệnh |
| `command` | TEXT | `SET_AUTO`, `SET_NIGHT`, `SET_PRIORITY_NS`, `SET_PRIORITY_EW`, `SET_EMERGENCY` |
| `source` | TEXT | `button`, `serial`, `dashboard`, `mobile` |
| `created_by` | TEXT | Người/thiết bị gửi lệnh |
| `created_at` | DATETIME | Thời điểm gửi |

### Bảng `traffic_event_logs`

Lưu log trạng thái hệ thống.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | Mã log |
| `intersection_id` | INTEGER FK | Giao lộ |
| `mode_code` | TEXT | Chế độ tại thời điểm log |
| `ns_light` | TEXT | Trạng thái Bắc-Nam: `red`, `yellow`, `green` |
| `ew_light` | TEXT | Trạng thái Đông-Tây: `red`, `yellow`, `green` |
| `remaining_seconds` | INTEGER | Thời gian còn lại |
| `created_at` | DATETIME | Thời điểm ghi log |

## Áp dụng OOP

OOP có thể áp dụng ở 2 nơi: code điều khiển và dashboard/backend.

### Trong code điều khiển Arduino/ESP32

| Class | Trách nhiệm |
|---|---|
| `TrafficLight` | Quản lý 3 đèn đỏ/vàng/xanh của một hướng |
| `TrafficPhase` | Lưu thông tin một pha: hướng, màu đèn, thời gian |
| `IntersectionController` | Điều phối toàn bộ giao lộ và chuyển trạng thái |
| `ModeManager` | Quản lý chế độ AUTO/NIGHT/PRIORITY/EMERGENCY |
| `DisplayManager` | Cập nhật LCD/Serial countdown |

### Trong dashboard/backend

| Class/Module | Trách nhiệm |
|---|---|
| `TrafficModeService` | Xử lý đổi chế độ |
| `CommandRepository` | Lưu và đọc lịch sử lệnh |
| `PhaseConfigRepository` | Quản lý cấu hình thời gian pha |
| `TrafficLogRepository` | Lưu log trạng thái |

## Yêu cầu dashboard/mobile app

Vì nhóm không có phần cứng thật, dashboard/mobile app nên triển khai theo dạng PWA hoặc web responsive giả lập mobile. Đây là hướng thực tế nhất để demo trên Mac, chụp ảnh đưa vào report và vẫn thể hiện được tư duy IoT.

| ID | Yêu cầu | Ghi chú |
|---|---|---|
| UI-01 | Hiển thị trạng thái 2 hướng đèn | Bắc-Nam và Đông-Tây |
| UI-02 | Có nút AUTO | Gửi lệnh chuyển AUTO |
| UI-03 | Có nút NIGHT | Gửi lệnh vàng nhấp nháy |
| UI-04 | Có nút PRIORITY NS/EW | Ưu tiên một hướng |
| UI-05 | Có nút EMERGENCY | Tất cả đỏ |
| UI-06 | Hiển thị countdown và mode hiện tại | Đồng bộ với demo hoặc dữ liệu mock |
| UI-07 | Hiển thị lịch sử lệnh gần nhất | Lấy từ database/mock data |
| UI-08 | Cấu hình thời gian pha đèn | Xanh/vàng ở mức mock hoặc API |
| UI-09 | Phân biệt trạng thái demo và trạng thái triển khai thật | Tránh nói app điều khiển trực tiếp Wokwi |

## Phạm vi mobile app đã chốt

| Phần | Quyết định |
|---|---|
| Loại app | Mobile web/PWA mock |
| Mục tiêu demo | Chứng minh luồng vận hành và điều khiển từ app |
| Kết nối Wokwi | Không kết nối trực tiếp trong MVP |
| Kết nối thực tế | App -> Backend API/MQTT -> ESP32 -> Đèn |
| Lưu lịch sử | Local mock hiện tại, database SQLite ở hướng mở rộng |

## API đề xuất nếu làm backend

| Method | Endpoint | Mục đích |
|---|---|---|
| `GET` | `/api/status` | Lấy trạng thái đèn hiện tại |
| `POST` | `/api/commands` | Gửi lệnh đổi chế độ |
| `GET` | `/api/commands` | Xem lịch sử lệnh |
| `GET` | `/api/phase-configs` | Xem cấu hình pha đèn |
| `PUT` | `/api/phase-configs/:id` | Cập nhật thời gian pha |

Ví dụ command từ mobile app:

```json
{
  "intersectionId": 1,
  "command": "SET_EMERGENCY",
  "source": "mobile",
  "createdBy": "operator"
}
```

## Yêu cầu phi chức năng

| ID | Yêu cầu | Ghi chú |
|---|---|---|
| NFR-01 | Demo phải chạy ổn trên Wokwi | Không lỗi compile |
| NFR-02 | Code dễ đọc, tách hàm/lớp rõ ràng | Dễ thuyết trình |
| NFR-03 | Báo cáo phải phân biệt rõ phần đã làm và phần mở rộng | Tránh bị hỏi quá scope |
| NFR-04 | Video/GIF demo 30-60 giây | Đủ thấy các mode chính |
| NFR-05 | Repo GitHub có README, task, source, assets | Team dễ theo dõi |

## Tiêu chí nghiệm thu

Một bản được xem là đạt để nộp khi:

- Wokwi chạy đủ 4 mode bắt buộc.
- Có sơ đồ khối và pin map.
- Có thiết kế CSDL ít nhất 4 bảng: mode, config, command, log.
- Có phần giải thích OOP trong code.
- Có dashboard/mobile mock hoặc ít nhất wireframe rõ ràng.
- Có mô tả hướng mobile app gửi lệnh đến backend/API/MQTT.
- Có report PDF, slide và video/GIF demo.
- GitHub repo cập nhật đầy đủ file cuối.
