# 08. Requirements Dự Án

> Bản này được cập nhật theo mức triển khai hiện tại của repository. Một số mục ban đầu là đề xuất hoặc yêu cầu nâng điểm nay đã có implementation thật trong source.

## Ghi chú định hướng điểm

Để bài lớn có điểm tốt hơn, nhóm không nên chỉ dừng ở mô phỏng đèn giao thông. Nên trình bày rõ cách dự án áp dụng nhiều phần đã học:

- Mô phỏng IoT bằng Wokwi.
- Thuật toán điều khiển và state machine.
- Thiết kế CSDL và database.
- OOP trong code điều khiển.
- Dashboard/mobile app để điều khiển và giám sát.
- Báo cáo có sơ đồ khối, sơ đồ mạch, ERD/database schema, flow xử lý và kết quả demo.

Bộ sơ đồ thiết kế hiện tại nằm ở [09_so_do_thiet_ke.md](./09_so_do_thiet_ke.md). Các source Mermaid riêng nằm trong `../../assets/diagrams/`.

## Vai trò người dùng

| Vai trò | Mô tả |
|---|---|
| Người vận hành | Chọn chế độ điều khiển đèn, theo dõi trạng thái giao lộ |
| Hệ thống điều khiển | Nhận lệnh, chạy thuật toán, bật/tắt đèn theo trạng thái |
| Người quản trị | Xem lịch sử lệnh, cấu hình thời gian pha đèn |

## Yêu cầu chức năng bắt buộc

| ID | Yêu cầu | Mức ưu tiên | Ghi chú |
|---|---|---:|---|
| FR-01 | Hệ thống mô phỏng 1 giao lộ gồm 2 trục Bắc-Nam và Đông-Tây, hiển thị 4 cụm NORTH/SOUTH/EAST/WEST | Must | Mỗi cụm có đỏ, vàng, xanh |
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
| ER-01 | Có thiết kế CSDL/ERD cho hệ thống | Should | Đã có schema và tài liệu kiến trúc |
| ER-02 | Có database lưu cấu hình pha đèn và lịch sử lệnh | Should | Đã triển khai SQLite thật trong backend |
| ER-03 | Code áp dụng OOP | Should | Arduino C++ hoặc dashboard/backend |
| ER-04 | Có dashboard/mobile web | Should | Đã có Flutter app source và có thể build Flutter web |
| ER-05 | Có API gửi lệnh điều khiển | Should | Đã có C# API thật + MQTT bridge |
| ER-06 | Có mô tả kết nối IoT qua WiFi/MQTT/HTTP | Could | Dùng trong báo cáo và slide |
| ER-07 | Có mobile app/web | Should | Đã có trong `flutter_app/` |

## Thiết kế CSDL và mức triển khai

Repository hiện đã dùng SQLite thật trong `backend/schema.sql`. Thay vì dừng ở mô hình 4 bảng tối thiểu, schema thực tế đã mở rộng thành mô hình điều phối giao lộ gồm approach, signal head, phase plan, conflict rule, command history, device status và traffic log.

### Bảng `intersections`

Lưu thông tin giao lộ.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | Mã giao lộ |
| `name` | TEXT | Tên giao lộ |
| `location` | TEXT | Vị trí mô tả |
| `status` | TEXT | `active`, `maintenance` |
| `current_mode_code` | TEXT | Mode logic hiện tại của backend |
| `active_phase_plan_id` | INTEGER FK | Phase plan đang được chọn |
| `created_at` | DATETIME | Thời điểm tạo |
| `updated_at` | DATETIME | Thời điểm cập nhật |

### Bảng `road_approaches`

Lưu các hướng đường logic của một giao lộ.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | Mã hướng đường |
| `intersection_id` | INTEGER FK | Giao lộ sở hữu |
| `code` | TEXT | `NORTH`, `SOUTH`, `EAST`, `WEST` |
| `name` | TEXT | Tên hiển thị |
| `display_order` | INTEGER | Thứ tự hiển thị trên app |
| `is_active` | BOOLEAN | Có đang bật trong dashboard không |

### Bảng `signal_heads`

Lưu từng cụm tín hiệu gắn với một approach.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | Mã cụm đèn |
| `road_approach_id` | INTEGER FK | Hướng đường sở hữu |
| `code` | TEXT | Mã cụm tín hiệu |
| `type` | TEXT | `vehicle` hoặc `pedestrian` |
| `red_pin` | INTEGER | GPIO đỏ |
| `yellow_pin` | INTEGER | GPIO vàng |
| `green_pin` | INTEGER | GPIO xanh |
| `is_active` | BOOLEAN | Có đang dùng không |

### Bảng `traffic_modes`

Lưu danh sách chế độ điều khiển.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | Mã chế độ |
| `code` | TEXT UNIQUE | `AUTO`, `NIGHT`, `PRIORITY_NS`, `PRIORITY_EW`, `EMERGENCY` |
| `name` | TEXT | Tên hiển thị |
| `priority_level` | INTEGER | Độ ưu tiên xử lý mode |
| `description` | TEXT | Mô tả chế độ |

### Nhóm bảng `phase_plans`, `phase_steps`, `phase_signal_states`

Lưu phase plan ở mức backend để app có thể xem, sửa và kích hoạt.

| Bảng | Vai trò |
|---|---|
| `phase_plans` | Header của một plan, ví dụ `Default plan` |
| `phase_steps` | Từng bước `NS_GREEN`, `NS_YELLOW`, `EW_GREEN`, `EW_YELLOW` với `sequence_no` và `duration_seconds` |
| `phase_signal_states` | Màu đèn áp cho từng signal head tại mỗi step |

Phần app hiện có thể cập nhật `greenSeconds` và `yellowSeconds` ở backend. Tuy nhiên trong bản MVP hiện tại, phase plan này **chưa tự động đồng bộ** thành runtime config của firmware qua luồng app thông thường.

### Bảng `conflict_rules`

Lưu ma trận xung đột giữa các hướng đường để backend phát hiện cấu hình phase nguy hiểm.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | Mã rule |
| `intersection_id` | INTEGER FK | Giao lộ áp dụng |
| `source_approach_id` | INTEGER FK | Hướng nguồn |
| `target_approach_id` | INTEGER FK | Hướng xung đột |
| `reason` | TEXT | Diễn giải lý do xung đột |

### Bảng `control_commands`

Lưu lịch sử lệnh từ dashboard/mobile app.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | Mã lệnh |
| `intersection_id` | INTEGER FK | Giao lộ nhận lệnh |
| `command` | TEXT | `SET_AUTO`, `SET_NIGHT`, `SET_PRIORITY_NS`, `SET_PRIORITY_EW`, `SET_EMERGENCY` |
| `mode_code` | TEXT FK | Mode suy ra từ command |
| `source` | TEXT | `button`, `serial`, `dashboard`, `mobile` |
| `created_by` | TEXT | Người/thiết bị gửi lệnh |
| `status` | TEXT | `success` hoặc `rejected` ở lớp API |
| `device_status` | TEXT | `queued`, `published`, `acknowledged`, `publish_failed`, `not_sent` |
| `mqtt_topic` | TEXT | Topic đã publish |
| `published_at` | DATETIME | Thời điểm broker nhận publish |
| `acknowledged_at` | DATETIME | Thời điểm thiết bị ACK |
| `created_at` | DATETIME | Thời điểm gửi |

### Bảng `device_statuses`

Lưu trạng thái mới nhất thiết bị báo về qua MQTT.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | Mã trạng thái |
| `intersection_id` | INTEGER FK | Giao lộ tương ứng |
| `device_id` | TEXT | Ví dụ `wokwi-esp32-01` |
| `connection_state` | TEXT | `online`, `offline`... |
| `last_mode_code` | TEXT | Mode cuối thiết bị báo về |
| `last_phase_code` | TEXT | Pha cuối thiết bị báo về |
| `last_remaining_seconds` | INTEGER | Countdown thiết bị báo về |
| `last_status_json` | TEXT | JSON status đầy đủ |
| `last_seen_at` | DATETIME | Lần cuối thiết bị xuất hiện |

### Bảng `traffic_event_logs`

Lưu log trạng thái hệ thống.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | Mã log |
| `intersection_id` | INTEGER FK | Giao lộ |
| `mode_code` | TEXT | Chế độ tại thời điểm log |
| `phase_code` | TEXT | Pha như `NS_GREEN`, `EW_YELLOW` |
| `remaining_seconds` | INTEGER | Thời gian còn lại |
| `status_json` | TEXT | Snapshot JSON của trạng thái |
| `created_at` | DATETIME | Thời điểm ghi log |

## Áp dụng OOP

OOP có thể áp dụng ở 2 nơi: code điều khiển và dashboard/backend.

### Trong code điều khiển Arduino/ESP32

| Class | Trách nhiệm |
|---|---|
| `TrafficLight` | Quản lý 3 đèn đỏ/vàng/xanh của một hướng |
| `RoadApproach` | Bọc một hướng đường logic và đèn tương ứng |
| `IntersectionController` | Điều phối toàn bộ giao lộ, mode strategy và trạng thái |
| `ModeManager` | Quản lý chế độ AUTO/NIGHT/PRIORITY/EMERGENCY/MAINTENANCE |
| `DisplayManager` | Cập nhật LCD/Serial countdown |
| `MqttClientManager` | Nhận command MQTT và publish ACK/status |

### Trong dashboard/backend

| Class/Module | Trách nhiệm |
|---|---|
| `TrafficDatabase` | Khởi tạo schema, seed dữ liệu và mở SQLite connection |
| `TrafficRepository` | Lưu/đọc command, phase plan, device status, traffic log |
| `TrafficService` | Xử lý command lifecycle, business rule và traffic status |
| `MqttTrafficBridge` | Publish command và consume ACK/status từ MQTT |

## Yêu cầu dashboard/mobile app

Vì nhóm không có phần cứng thật, dashboard/mobile app hiện được triển khai bằng `flutter_app/`, có thể chạy dưới dạng app hoặc web build. UI này gọi backend C# thật thay vì chạy mock local thuần.

| ID | Yêu cầu | Ghi chú |
|---|---|---|
| UI-01 | Hiển thị trạng thái 4 cụm đèn | NORTH, SOUTH, EAST, WEST |
| UI-02 | Có nút AUTO | Gửi lệnh chuyển AUTO |
| UI-03 | Có nút NIGHT | Gửi lệnh vàng nhấp nháy |
| UI-04 | Có nút PRIORITY NS/EW | Ưu tiên một hướng |
| UI-05 | Có nút EMERGENCY | Tất cả đỏ |
| UI-06 | Hiển thị countdown và mode hiện tại | Lấy từ backend; có thể lệch device state vì backend giữ clock riêng |
| UI-07 | Hiển thị lịch sử lệnh gần nhất | Lấy từ SQLite qua API |
| UI-08 | Cấu hình thời gian pha đèn | Qua API phase plan của backend; chưa đồng bộ runtime firmware tự động |
| UI-09 | Phân biệt trạng thái demo và trạng thái triển khai thật | Tránh nói app điều khiển trực tiếp Wokwi |

## Phạm vi mobile app đã chốt

| Phần | Quyết định |
|---|---|
| Loại app | Flutter app source + Flutter web build |
| Mục tiêu demo | Chứng minh luồng vận hành và điều khiển từ app |
| Kết nối Wokwi | Không kết nối trực tiếp trong MVP |
| Kết nối thực tế | App -> Backend API/MQTT -> ESP32 -> Đèn |
| Lưu lịch sử | Backend SQLite thật |

## API đề xuất nếu làm backend

| Method | Endpoint | Mục đích |
|---|---|---|
| `GET` | `/api/intersections/1/status` | Lấy trạng thái đèn hiện tại |
| `POST` | `/api/intersections/1/commands` | Gửi lệnh đổi chế độ |
| `GET` | `/api/intersections/1/commands` | Xem lịch sử lệnh |
| `GET` | `/api/intersections/1/phase-plans` | Xem phase plan |
| `PUT` | `/api/phase-plans/:id` | Cập nhật thời gian pha |

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
- Có thiết kế CSDL ít nhất 4 bảng; bản hiện tại đã vượt mức đó với schema SQLite mở rộng.
- Có phần giải thích OOP trong code.
- Có dashboard/mobile implementation hoặc ít nhất one-click demo rõ ràng.
- Có mô tả hướng mobile app gửi lệnh đến backend/API/MQTT.
- Có report PDF, slide và video/GIF demo.
- GitHub repo cập nhật đầy đủ file cuối.
