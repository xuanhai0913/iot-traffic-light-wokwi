# Mobile App Mock

Đây là bản mobile web/PWA mock để trình bày hướng mở rộng điều khiển đèn giao thông bằng app.

## Cách chạy

Mở trực tiếp:

```text
mobile_app/index.html
```

Hoặc chạy local server từ thư mục repo:

```bash
python3 -m http.server 4173
```

Sau đó mở:

```text
http://localhost:4173/mobile_app/
```

## Chức năng đã có

- Hiển thị trạng thái đèn 2 hướng Bắc-Nam và Đông-Tây.
- Điều khiển `AUTO`, `NIGHT`, `PRIORITY NS`, `PRIORITY EW`, `EMERGENCY`.
- Hiển thị mode, pha hiện tại và countdown.
- Cấu hình thời gian xanh/vàng ở mức mock.
- Lưu lịch sử lệnh bằng `localStorage`.

## Ghi chú triển khai thật

Bản này chưa kết nối trực tiếp Wokwi/ESP32. Trong triển khai thực tế, app sẽ gửi command đến backend API hoặc MQTT broker. ESP32 nhận lệnh qua WiFi, cập nhật đèn, rồi gửi trạng thái ngược lại cho app.
