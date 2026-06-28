# Khuyến nghị deploy và production gap

> Cập nhật ngày 28/06/2026. Free tier có thể thay đổi; cần kiểm tra lại điều khoản trước ngày demo.

## 1. Kết luận ngắn

- **Demo miễn phí khả thi**: Flutter APK/web -> Render C# API -> public MQTT broker -> ESP32/Wokwi.
- **Không nên gọi là production**: SQLite trên Render Free mất dữ liệu khi service restart/spin down; public MQTT broker mở cho mọi người; API chưa có xác thực; safety state machine chưa đủ.
- Không có phương án “miễn phí, không sửa code, bền vững và production-safe” cho trạng thái repository hiện tại.

## 2. Phương án A: demo miễn phí, ít thay đổi nhất

| Thành phần | Nơi chạy |
|---|---|
| Flutter Android | Cài APK trực tiếp lên điện thoại |
| Flutter web, nếu cần | Render Static Site, GitHub Pages hoặc Firebase Hosting |
| C# API | Render Free Web Service bằng `backend/Dockerfile` và `render.yaml` |
| Database | SQLite local trong container, chỉ dùng dữ liệu demo |
| MQTT | `broker.hivemq.com:1883` |
| ESP32 | Wokwi Public Gateway |

### Luồng demo

```text
Điện thoại Flutter
    -> HTTPS Render API
    -> MQTT public broker
    -> ESP32/Wokwi
    -> ACK/status qua MQTT
    -> Render API
    -> Flutter history/device status
```

### Các bước

1. Push repository lên Git provider.
2. Tạo Render Blueprint từ `render.yaml`, hoặc tạo Web Service với root `backend/`.
3. Kiểm tra `GET https://<service>.onrender.com/api/health`.
4. Chạy Wokwi và chờ MQTT connected.
5. Trong Flutter Settings, nhập URL Render, không thêm dấu `/` cuối.
6. Gửi command và kiểm tra `History` cùng `ESP32 devices`.

### Hạn chế bắt buộc phải nói khi demo

Theo tài liệu Render Free:

- service ngủ sau 15 phút không có inbound traffic;
- lần gọi đầu sau khi ngủ có thể mất khoảng một phút;
- filesystem là ephemeral, nên SQLite local mất thay đổi khi redeploy, restart hoặc spin down;
- Free Web Service không gắn persistent disk;
- Render nêu rõ free instance không nên dùng cho production.

Vì vậy cần mở `/api/health` trước buổi demo vài phút và chấp nhận dữ liệu có thể được seed lại.

## 3. Flutter trên điện thoại

Artifact hiện có:

```text
dist/android/iot-traffic-light-v1.0.0.apk
```

Tại thời điểm rà soát:

- version: `1.0.0+1`;
- application ID: `com.example.iot_traffic_light`;
- kích thước khoảng 47,7 MB;
- artifact tồn tại, nhưng chưa được cài thử trong lượt viết tài liệu.

Đây là fat APK dùng cho demo. Khi phát hành chính thức nên:

- đổi application ID;
- dùng release keystore, không dùng debug signing;
- build split APK hoặc AAB;
- quản lý API URL bằng build flavor/environment thay vì nhập thủ công.

## 4. Flutter web miễn phí

Flutter chính thức tạo bundle deploy bằng:

```powershell
flutter build web
```

Output nằm trong `flutter_app/build/web/` và có thể đưa lên static hosting. Khi dùng Flutter web:

- API phải là HTTPS nếu trang Flutter chạy HTTPS;
- cần cấu hình base URL production;
- backend hiện cho phép CORS mọi origin, tiện demo nhưng phải giới hạn origin khi production.

## 5. MQTT: demo và production

### Hiện tại

Firmware và backend dùng:

```text
broker.hivemq.com:1883
traffic/hainx-iot-traffic-light/intersections/1/...
```

HiveMQ mô tả public broker là mở cho mọi người sử dụng. Kết hợp với topic cố định và không có credential trong mã, có thể suy ra người khác có khả năng publish/subscribe cùng topic. Chỉ nên dùng cho lớp học và test ngắn hạn.

### Hướng nâng cấp

HiveMQ Dashboard hiện quảng bá HiveMQ Cloud miễn phí tối đa 100 thiết bị. Tuy nhiên để chuyển sang đó, repository cần được sửa:

- TLS MQTT;
- username/password hoặc certificate;
- ACL theo device/topic;
- secret qua environment, không hard-code;
- topic prefix ngẫu nhiên theo project/environment;
- reconnect/backoff và kiểm soát session phù hợp.

## 6. Database bền vững hơn

### Không sửa code

Giữ SQLite chỉ phù hợp local hoặc demo ngắn. Render Free không giữ được file SQLite qua lifecycle của service.

### Có sửa code

Chuyển repository sang PostgreSQL managed:

- dùng connection string từ environment;
- migration có version;
- unique constraint cho idempotency command;
- transaction cho desired state và outbox;
- backup/export trước demo.

Render Free Postgres hiện có giới hạn 1 GB và hết hạn sau 30 ngày, không có backup. Nó có thể dùng cho một đợt demo ngắn nhưng vẫn không phải nơi lưu dữ liệu lâu dài.

## 7. Production gap ưu tiên

### P0 - an toàn và bảo mật

- Xác thực API, role operator/admin và audit identity.
- MQTT TLS, credential và ACL.
- All-red clearance có thời lượng.
- Conflict validator phải chặn activate, không chỉ trả cảnh báo.
- Device-reported state là nguồn sự thật.

### P1 - độ tin cậy

- Command outbox, retry, expiry và ACK timeout.
- Idempotency/deduplication theo command ID.
- Không cập nhật desired/current mode thành “đã chạy” trước khi publish/ACK.
- Health/readiness riêng cho database và MQTT.

### P2 - vận hành

- PostgreSQL bền vững và backup.
- Structured log, metrics, alert khi thiết bị offline.
- CI chạy backend tests, Flutter analyze/test/build và firmware compile.
- Release signing cho Android.

## 8. Nguồn chính thức

- [Render - Deploy for Free](https://render.com/docs/free)
- [Render FAQ](https://render.com/docs/faq)
- [HiveMQ Public MQTT Broker](https://www.hivemq.com/mqtt/public-mqtt-broker/)
- [HiveMQ MQTT Dashboard](https://www.mqtt-dashboard.com/)
- [Flutter - Build and release a web app](https://docs.flutter.dev/deployment/web)
- [Flutter - Build and release an Android app](https://docs.flutter.dev/deployment/android)
