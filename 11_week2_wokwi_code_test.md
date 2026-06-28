# 11. Week 2 - Wokwi, Code Và Test

## Issue liên quan

- `#5` Dựng mạch Wokwi bản MVP
- `#6` Code AUTO mode và countdown
- `#7` Code NIGHT, PRIORITY và EMERGENCY mode
- `#8` Test tích hợp Wokwi và chụp ảnh 4 chế độ
- `#15` Áp dụng OOP vào code điều khiển hoặc backend

## File đã triển khai

| File | Vai trò |
|---|---|
| `wokwi/diagram.json` | Sơ đồ mạch Wokwi ESP32, 4 cụm đèn xe, 4 đèn người đi bộ, LCD I2C và 4 button |
| `wokwi/sketch.ino` | Code điều khiển ESP32 theo OOP/state machine |
| `wokwi/libraries.txt` | Khai báo thư viện LCD I2C cho Wokwi |

## Linh kiện và pin map

| Chức năng | GPIO ESP32 |
|---|---:|
| Bắc-Nam đỏ | 16 |
| Bắc-Nam vàng | 17 |
| Bắc-Nam xanh | 18 |
| Đông-Tây đỏ | 19 |
| Đông-Tây vàng | 23 |
| Đông-Tây xanh | 25 |
| Button AUTO | 26 |
| Button NIGHT | 27 |
| Button PRIORITY | 32 |
| Button EMERGENCY | 33 |
| LCD SDA | 21 |
| LCD SCL | 22 |
| Pedestrian N/S/E/W | 4 / 5 / 12 / 13 |

Các button nối về GND và code dùng `INPUT_PULLUP`, nên khi nhấn button thì chân GPIO đọc giá trị `LOW`.

## Các chế độ đã code

| Mode | Hành vi |
|---|---|
| `AUTO` | Chạy 4 pha: NS xanh, NS vàng, EW xanh, EW vàng |
| `NIGHT` | Hai hướng vàng nhấp nháy cảnh báo |
| `PRIORITY NS` | Bắc-Nam xanh, Đông-Tây đỏ |
| `PRIORITY EW` | Đông-Tây xanh, Bắc-Nam đỏ |
| `EMERGENCY` | Tất cả đèn đỏ |

Nút `PRIORITY` sẽ luân phiên giữa `PRIORITY NS` và `PRIORITY EW` sau mỗi lần nhấn.

## Serial command để test nhanh

| Command | Mode |
|---|---|
| `a` hoặc `auto` | AUTO |
| `n` hoặc `night` | NIGHT |
| `p`, `priority`, `priority_ns` | PRIORITY NS |
| `pe`, `priority_ew` | PRIORITY EW |
| `e` hoặc `emergency` | EMERGENCY |

## OOP đã áp dụng

| Class/Struct | Trách nhiệm |
|---|---|
| `TrafficLight` | Quản lý 3 đèn đỏ/vàng/xanh của một hướng |
| `TrafficPhase` | Lưu tên pha, trạng thái 4 hướng logic và thời gian pha |
| `ModeManager` | Đọc button/Serial và quản lý mode hiện tại |
| `DisplayManager` | Cập nhật LCD 16x2 và Serial Monitor |
| `IntersectionController` | Điều phối toàn bộ giao lộ theo mode/state machine |

## Checklist test Wokwi

- [x] Validate `wokwi/diagram.json` bằng `jq`.
- [x] Compile syntax `wokwi/sketch.ino` bằng Arduino CLI với core AVR nhẹ để bắt lỗi C++/Arduino.
- [ ] Mở project Wokwi với `wokwi/diagram.json`, `wokwi/sketch.ino`, `wokwi/libraries.txt`.
- [ ] Bấm Run trên Wokwi, kiểm tra LCD hiện `AUTO`.
- [ ] Quan sát đủ 4 pha AUTO.
- [ ] Nhấn `NIGHT`, kiểm tra 4 cụm vàng nhấp nháy.
- [ ] Nhấn `PRIORITY`, kiểm tra một hướng xanh và hướng còn lại đỏ.
- [ ] Nhấn `PRIORITY` lần nữa, kiểm tra đổi hướng ưu tiên.
- [ ] Nhấn `EMERGENCY`, kiểm tra tất cả đèn đỏ.
- [ ] Chụp 5 ảnh: `assets/wokwi/wokwi_auto.png`, `assets/wokwi/wokwi_night.png`, `assets/wokwi/wokwi_priority_ns.png`, `assets/wokwi/wokwi_priority_ew.png`, `assets/wokwi/wokwi_emergency.png`.
- [ ] Quay video/GIF demo 30-60 giây lưu vào `demo/`.

## Trạng thái Week 2

- Có thể đóng `#5`, `#6`, `#7`, `#15` vì đã có mạch, code mode và OOP trong repo.
- `#8` chỉ nên đóng sau khi đã có ảnh chụp thật từ Wokwi trong `assets/`.

## Lệnh kiểm tra đã chạy

```bash
jq . wokwi/diagram.json >/dev/null
arduino-cli compile --fqbn arduino:avr:uno <thu-muc-tam>/sketch
```

Ghi chú: compile bằng AVR chỉ dùng để bắt lỗi cú pháp Arduino/C++ nhanh trên máy local. Bản demo chính vẫn dùng ESP32 trên Wokwi; phần test chạy thực tế và ảnh chụp được theo dõi riêng ở `#8`.
