# 05. Kế Hoạch Demo Wokwi

## Mục tiêu demo

Demo phải cho thấy hệ thống đèn giao thông chạy được trên mô phỏng, có chuyển pha rõ ràng, có điều khiển chế độ và có hiển thị trạng thái.

## Board đề xuất

Ưu tiên 1: ESP32 DevKit nếu nhóm muốn nhấn mạnh IoT.

Ưu tiên 2: Arduino Uno nếu muốn code đơn giản và ổn định nhất.

## Linh kiện

| Linh kiện | Số lượng | Mục đích |
|---|---:|---|
| ESP32 hoặc Arduino Uno | 1 | Bộ điều khiển chính |
| LED đỏ | 2 | Đèn đỏ cho 2 hướng |
| LED vàng | 2 | Đèn vàng cho 2 hướng |
| LED xanh | 2 | Đèn xanh cho 2 hướng |
| Điện trở 220Ω | 6 | Hạn dòng LED |
| LCD 16x2 I2C | 1 | Hiển thị trạng thái/countdown |
| Button | 3-4 | Chuyển chế độ |

## Pin map dự kiến

Nếu dùng Arduino Uno:

| Chức năng | Pin |
|---|---:|
| Bắc-Nam đỏ | D2 |
| Bắc-Nam vàng | D3 |
| Bắc-Nam xanh | D4 |
| Đông-Tây đỏ | D5 |
| Đông-Tây vàng | D6 |
| Đông-Tây xanh | D7 |
| Button AUTO/NEXT | D8 |
| Button NIGHT | D9 |
| Button PRIORITY | D10 |
| Button EMERGENCY | D11 |
| LCD SDA | A4 |
| LCD SCL | A5 |

Nếu dùng ESP32:

| Chức năng | GPIO |
|---|---:|
| Bắc-Nam đỏ | 13 |
| Bắc-Nam vàng | 12 |
| Bắc-Nam xanh | 14 |
| Đông-Tây đỏ | 27 |
| Đông-Tây vàng | 26 |
| Đông-Tây xanh | 25 |
| Button AUTO/NEXT | 33 |
| Button NIGHT | 32 |
| Button PRIORITY | 35 |
| Button EMERGENCY | 34 |
| LCD SDA | 21 |
| LCD SCL | 22 |

## Các trạng thái cần demo

### 1. AUTO

- Bắc-Nam xanh, Đông-Tây đỏ.
- Bắc-Nam vàng, Đông-Tây đỏ.
- Bắc-Nam đỏ, Đông-Tây xanh.
- Bắc-Nam đỏ, Đông-Tây vàng.
- Lặp lại.

### 2. NIGHT

- Hai hướng vàng nhấp nháy.
- LCD hiển thị `NIGHT MODE`.

### 3. PRIORITY

- Ưu tiên một hướng xanh lâu hơn.
- Hướng còn lại đỏ.
- LCD hiển thị `PRIORITY NS` hoặc `PRIORITY EW`.

### 4. EMERGENCY

- Tất cả đèn đỏ.
- LCD hiển thị `EMERGENCY`.

## Kịch bản quay demo

1. Mở Wokwi và chạy simulation.
2. Quay AUTO mode chạy ít nhất 1 vòng pha.
3. Nhấn NIGHT, quay vàng nhấp nháy.
4. Nhấn PRIORITY, quay hướng ưu tiên.
5. Nhấn EMERGENCY, quay tất cả đỏ.
6. Chụp lại 4 ảnh đại diện cho 4 chế độ.

## File cần lưu

- `wokwi/sketch.ino`
- `wokwi/diagram.json`
- `assets/so_do_khoi.png`
- `assets/wokwi_auto.png`
- `assets/wokwi_night.png`
- `assets/wokwi_priority.png`
- `assets/wokwi_emergency.png`
- `demo/demo_wokwi.mp4` hoặc `demo/demo_wokwi.gif`

