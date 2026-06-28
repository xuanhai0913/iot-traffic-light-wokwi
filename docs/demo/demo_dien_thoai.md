# Hướng dẫn demo bằng điện thoại Android

## 1. Mục tiêu demo

Chứng minh một lượt đầy đủ:

```text
Flutter trên điện thoại
-> C# API
-> SQLite ghi command
-> MQTT publish
-> ESP32/Wokwi đổi đèn
-> ESP32 gửi ACK/status
-> Flutter thấy history và last seen
```

Không dùng riêng HTTP `201` để kết luận ESP32 đã đổi đèn. Cần nhìn Wokwi và trạng thái `acknowledged`.

## 2. Chuẩn bị

- Laptop chạy backend và Wokwi.
- Điện thoại Android và laptop cùng WiFi, hoặc backend đã deploy công khai.
- APK expected output sau khi chạy script build:

```text
dist/android/iot-traffic-light-v1.0.0.apk
```

Nếu file chưa có trong workspace hiện tại, hãy chạy lại `scripts/build-flutter-android.ps1` trước buổi demo. APK vẫn chưa được cài thử trên điện thoại thật trong lượt rà soát tài liệu này.

## 3. Cách A: backend chạy trên laptop

### Bước 1: lấy IP của laptop

Chạy PowerShell:

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {
    $_.IPAddress -notlike "127.*" -and
    $_.IPAddress -notlike "169.254.*"
  } |
  Select-Object InterfaceAlias, IPAddress
```

Chọn IPv4 của WiFi, ví dụ `192.168.1.10`.

### Bước 2: chạy backend

```powershell
cd backend
dotnet run
```

Backend bind `0.0.0.0:8000`. Kiểm tra trên laptop:

```text
http://127.0.0.1:8000/api/health
```

Kiểm tra trên trình duyệt điện thoại:

```text
http://192.168.1.10:8000/api/health
```

Nếu điện thoại không mở được:

- xác nhận hai thiết bị cùng mạng;
- tránh guest WiFi có client isolation;
- cho phép ứng dụng .NET/TCP 8000 qua Windows Firewall;
- kiểm tra VPN trên laptop/điện thoại.

### Bước 3: chạy Wokwi

Mở project từ `wokwi/sketch.ino`, `diagram.json`, `libraries.txt` và Start Simulation.

Serial Monitor cần cho thấy:

```text
Connecting WiFi Wokwi-GUEST
MQTT connected
```

Nếu MQTT chưa kết nối, app vẫn có thể gọi API nhưng command sẽ không được ESP32 ACK.

### Bước 4: cài Flutter APK

Có thể chép APK trong `dist/android/` sang điện thoại và cài thủ công.
Nếu dùng thiết bị USB và Flutter CLI:

```powershell
cd flutter_app
flutter install
```

APK hiện dùng package mẫu và debug signing cho release build, chỉ phù hợp demo nội bộ.

### Bước 5: cấu hình API

Trong app:

1. Mở tab **Settings**.
2. Nhập `http://192.168.1.10:8000`.
3. Nhấn **Apply** hoặc **Test**.
4. Xác nhận `Connected`.

Flutter app lưu `API base URL` qua `SharedPreferences`. Thông thường sau khi đóng/mở app không cần nhập lại trừ khi xóa dữ liệu ứng dụng.

## 4. Kịch bản trình bày 3-5 phút

1. Mở **Dashboard**, chỉ mode, phase, countdown và bốn hướng.
2. Mở **Settings**, chỉ ESP32 device và `Last seen`.
3. Mở **Control**, gửi `NIGHT`.
4. Quan sát Wokwi chớp vàng và LCD đổi mode.
5. Mở **History**, kiểm tra command chuyển sang `acknowledged`.
6. Gửi `PRIORITY NS`, sau đó `AUTO`.
7. Gửi `EMERGENCY`, xác nhận tất cả đỏ.
8. Thử gửi `PRIORITY EW` khi backend vẫn ở emergency để minh họa emergency guard; API phải từ chối.
9. Gửi `AUTO` để thoát emergency.
10. Mở **Manage**, cập nhật green/yellow duration và giải thích đây là phase plan của backend.

Lưu ý: phase duration trên backend chưa được đồng bộ xuống firmware. Không nên chỉnh thời gian rồi nói Wokwi đã dùng cấu hình mới.

## 5. Cách B: backend trên Render

1. Deploy backend bằng `render.yaml`.
2. Mở trước:

```text
https://<service>.onrender.com/api/health
```

3. Chờ service wake up.
4. Trong Flutter Settings nhập URL HTTPS trên.
5. Chạy Wokwi và thực hiện kịch bản như trên.

Render Free có thể ngủ sau 15 phút và filesystem SQLite là tạm thời. Hãy warm up service trước buổi trình bày.

## 6. Checklist bằng chứng cần quay/chụp

- Điện thoại hiển thị `Connected`.
- Settings có ESP32 `ONLINE` và `Last seen` mới.
- Command history có ít nhất một dòng `acknowledged`.
- Wokwi có LCD và LED đúng mode.
- Serial Monitor có MQTT connected và command nhận được.
- Ảnh riêng cho AUTO, NIGHT, PRIORITY_NS, PRIORITY_EW, EMERGENCY.
- Video 30-60 giây có ít nhất một lượt app -> Wokwi -> ACK.

## 7. Xử lý lỗi nhanh

| Hiện tượng | Nguyên nhân thường gặp | Kiểm tra |
|---|---|---|
| App Offline | Sai IP/URL, firewall, backend chưa chạy | Mở `/api/health` trên điện thoại |
| API success nhưng đèn không đổi | MQTT lỗi hoặc Wokwi chưa subscribe | `/api/mqtt/status`, Serial Monitor |
| History là `publish_failed` | Backend không kết nối broker | Host/port/network của backend |
| History là `published` mãi | ESP32 không online hoặc ACK không về | Wokwi MQTT connected, đúng topic |
| Device list trống | Chưa nhận status định kỳ | Chờ hơn 2 giây, refresh dashboard |
| Dashboard và Wokwi lệch pha | Backend tự tính phase theo đồng hồ riêng | Dùng Wokwi/status device làm bằng chứng thiết bị |
| App quên API URL | URL chưa được persist | Nhập lại trong Settings |

## 8. Lenh demo da chuan hoa

Tu thu muc goc repository, chay backend cho dien thoai bang:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\run-backend-demo.ps1
```

Script se bat MQTT, bind API ra `0.0.0.0:8000` va in cac URL LAN co the nhap vao Flutter Settings.

Truoc khi dan code vao Wokwi, chay:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\test-wokwi-source.ps1
```

Script nay da kiem tra local: `diagram.json` hop le, co `LiquidCrystal I2C`/`PubSubClient`, va `sketch.ino` can bang dau ngoac. Van phai bam Start Simulation tren Wokwi de lay evidence compile/runtime cuoi.

## 9. Evidence da co den 28/06/2026

- Wokwi UI da compile/run thanh cong voi source hien tai.
- Backend da nhan device `wokwi-esp32-01` online qua MQTT.
- Cac command ID 22-26 da co `device_status=acknowledged`: AUTO, NIGHT, PRIORITY_NS, PRIORITY_EW, EMERGENCY.
- Anh da luu trong `docs/evidence/wokwi/`: `wokwi_compile_run.png`, `wokwi_auto.png`, `wokwi_night.png`, `wokwi_priority_ns.png`, `wokwi_priority_ew.png`, `wokwi_emergency.png`.
- Viec con lai cho demo dien thoai: cai APK len may Android that, nhap `http://192.168.3.83:8000` neu van o cung LAN hien tai, chup History/Settings va quay video 30-60 giay.
