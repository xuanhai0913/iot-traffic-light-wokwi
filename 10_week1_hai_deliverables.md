# 10. Week 1 - Deliverables Của Nguyễn Xuân Hải

## Mục tiêu Week 1

Hoàn thành phần chốt scope, sơ đồ hệ thống và pin map để nhóm có nền tảng triển khai Wokwi/code ở Week 2.

## Issue liên quan

- `#1` Chốt scope MVP và tiêu chí demo
- `#2` Thiết kế sơ đồ khối hệ thống
- `#4` Chốt linh kiện Wokwi và pin map

## 1. Scope MVP đã chốt

Tên đề tài:

**Hệ thống mô phỏng điều khiển đèn giao thông thông minh tại một giao lộ bằng Wokwi**

MVP bắt buộc:

- 1 giao lộ gồm 2 trục điều khiển Bắc-Nam và Đông-Tây, hiển thị 4 cụm NORTH/SOUTH/EAST/WEST.
- Mỗi cụm có 3 đèn: đỏ, vàng, xanh.
- ESP32 DevKit là bộ điều khiển chính.
- LCD 16x2 I2C hiển thị mode và countdown.
- 4 chế độ vận hành:
  - `AUTO`: chạy chu kỳ đèn bình thường.
  - `NIGHT`: vàng nhấp nháy cảnh báo ban đêm.
  - `PRIORITY`: ưu tiên một hướng.
  - `EMERGENCY`: tất cả đèn đỏ.
- Điều khiển mode bằng button trong Wokwi.
- Có ảnh chụp và video/GIF demo để đưa vào báo cáo/slide.

Không làm trong MVP:

- Không làm app mobile native trong Week 1.
- Không phụ thuộc database/MQTT để hoàn thành mốc Week 1.
- Không mô phỏng nhiều giao lộ.
- Không làm thuật toán AI/tối ưu giao thông nâng cao.

## 2. Sơ đồ hệ thống

Bộ sơ đồ đã chuẩn bị trong [09_so_do_thiet_ke.md](./09_so_do_thiet_ke.md):

- Sơ đồ kiến trúc tổng thể.
- ERD/database schema.
- State machine.
- Class/OOP diagram.
- Sequence flow gửi lệnh từ dashboard.
- Data flow rút gọn.

Các source Mermaid nằm trong `assets/diagrams/`.

## 3. Linh kiện Wokwi đã chốt

| Linh kiện | Số lượng | Vai trò |
|---|---:|---|
| ESP32 DevKit | 1 | Bộ điều khiển chính |
| LED đỏ/vàng/xanh xe | 12 | 4 cụm đèn NORTH/SOUTH/EAST/WEST |
| LED xanh người đi bộ | 4 | Minh họa hướng đi bộ |
| Điện trở 220Ω | 16 | Hạn dòng LED |
| LCD 16x2 I2C | 1 | Hiển thị mode và countdown |
| Button | 4 | Đổi mode AUTO/NIGHT/PRIORITY/EMERGENCY |

## 4. Pin map đã chốt

| Chức năng | GPIO ESP32 | Ghi chú |
|---|---:|---|
| Bắc-Nam đỏ | 16 | Output |
| Bắc-Nam vàng | 17 | Output |
| Bắc-Nam xanh | 18 | Output |
| Đông-Tây đỏ | 19 | Output |
| Đông-Tây vàng | 23 | Output |
| Đông-Tây xanh | 25 | Output |
| Button AUTO | 26 | Input pull-up |
| Button NIGHT | 27 | Input pull-up |
| Button PRIORITY | 32 | Input pull-up |
| Button EMERGENCY | 33 | Input pull-up |
| LCD SDA | 21 | I2C |
| LCD SCL | 22 | I2C |
| Pedestrian N/S/E/W | 4, 5, 12, 13 | Output |

Quy ước button: một chân nối GPIO, một chân nối GND, code dùng `INPUT_PULLUP`.

## 5. Tiêu chí nghiệm thu Week 1

- [x] Chốt tên đề tài và scope MVP.
- [x] Chốt không phụ thuộc app native hoặc phần cứng thật trong MVP.
- [x] Chốt dùng ESP32 DevKit.
- [x] Chốt linh kiện Wokwi.
- [x] Chốt pin map ESP32.
- [x] Có sơ đồ kiến trúc tổng thể trong `09_so_do_thiet_ke.md`.
- [x] Có checklist chuyển sang Week 2.

## 6. Việc chuyển sang Week 2

- Kế hoạch ban đầu: Nguyễn Xuân Hải dựng mạch Wokwi theo pin map trên.
- Kế hoạch ban đầu: Trần Đình Đức viết code theo state machine và áp dụng OOP.
- Kế hoạch ban đầu: Đức xử lý phần database/ERD/report/slide liên quan theo issue đã assign.

### Ghi chú đối chiếu sản phẩm nộp cuối

Khi hoàn thiện bản nộp thực tế, phần lớn implementation và tích hợp cuối của hệ thống được ghi nhận ở phía Nguyễn Xuân Hải. Trần Đình Đức chủ yếu hỗ trợ phần database/ERD và một phần tài liệu Word/PPT. Vì vậy khi dùng tài liệu này trong report hoặc slide, cần phân biệt rõ giữa **phân công dự kiến ban đầu** và **đóng góp thực tế ở bản nộp cuối**.
