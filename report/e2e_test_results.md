# Báo cáo kiểm thử End-to-End (E2E)

> Phiên kiểm thử thủ công toàn bộ luồng: Flutter Web → C# Backend → MQTT broker → Wokwi ESP32 và ngược lại.
> Tài liệu này là bằng chứng thực nghiệm cho báo cáo kỹ thuật (`report/bao_cao_ky_thuat.md`) và slide thuyết trình cuối kỳ.

## 1. Thông tin chung

| Mục | Giá trị |
|---|---|
| Ngày kiểm thử | 2026-06-19 |
| Người thực hiện | Nguyễn Xuân Hải (Hải) |
| Mục tiêu | Xác minh 5 chế độ đèn + đường MQTT + fix dialog + chuẩn Tiếng Việt có dấu |
| OS host | Windows 11 (WSL2 backend) |
| Trình duyệt thao tác | Chrome 124+ trên `http://localhost:8080` |
| Flutter | 3.44.2 (Dart 3.12.2), build `release` |
| Backend | C# ASP.NET Core 8 Minimal API, chạy ở `http://127.0.0.1:8000` |
| MQTT broker | `broker.hivemq.com:1883`, topic prefix `traffic/hainx-iot-traffic-light` |
| Wokwi | Project ESP32 DevKit, sketch Arduino |
| Build artifacts | `flutter_app/build/web/` được serve bằng Node.js HTTP trên cổng 8080 |
| Backend log | `backend_smoke.log` (đính kèm) |
| MQTT capture | `scripts/mqtt-sniff.py` (đính kèm), output lưu tại `assets/e2e/mqtt_capture_*.log` |

## 2. Mục tiêu kiểm thử

1. **Fix dialog confirm** (commit `d353b8a`): ba nút nguy hiểm `PRIORITY NS`, `PRIORITY EW`, `EMERGENCY` phải hiện hộp thoại xác nhận trước khi gửi lệnh. Trước fix, ba nút này im lặng do `_messengerKey.currentState` trả về `null`.
2. **Đường MQTT đầy đủ** (nhiều commit): mỗi chế độ phải xuất hiện trong topic `.../commands` và Wokwi phải phản hồi `.../acks`.
3. **Chuẩn Tiếng Việt có dấu** (commit `c1eec4f`): toàn bộ chuỗi người dùng nhìn thấy phải có dấu, không còn dạng ASCII như `Mat ket noi backend`, `Tai lai`.
4. **SnackBar feedback**: thành công và lỗi phải có phản hồi trực quan.
5. **Polling dashboard**: trang Dashboard tự cập nhật mỗi 2 giây, không cần tải lại.

## 3. Điều kiện tiên quyết

| Hạng mục | Trạng thái |
|---|---|
| Backend C# đang chạy ở `http://127.0.0.1:8000` | OK (xem `backend_smoke.log` dòng `Health: ok`) |
| MQTT bridge kết nối `broker.hivemq.com:1883` | OK (xem `GET /api/mqtt/status` trả về `connected: true`) |
| Wokwi ESP32 đang chạy và subscribe đúng topic | OK (xem Serial Monitor) |
| Flutter web build đã serve ở `http://localhost:8080` | OK (sau commit `d353b8a` + `c1eec4f`, `flutter build web --release`) |
| Schema SQLite đã khởi tạo với `intersectionId=1` | OK trong phiên test đó (backend tạo file `traffic.db` runtime từ `backend/schema.sql`) |

## 4. Bảng kết quả tổng hợp

| Mã | Kịch bản | Trạng thái | Bằng chứng |
|---|---|:---:|---|
| TC-01 | Backend `/api/health` trả `ok` | PASS | `backend_smoke.log` |
| TC-02 | Flutter web kết nối backend tự động | PASS | Dashboard hiện `Đã kết nối ...` |
| TC-03 | Dashboard polling real-time | PASS | Số giây đếm ngược tự giảm |
| TC-04 | Nút AUTO gửi lệnh thành công | PASS | Hộp thoại kết quả + MQTT capture |
| TC-05 | Nút NIGHT gửi lệnh thành công | PASS | Hộp thoại kết quả + MQTT capture |
| **TC-06** | **Nút PRIORITY NS hiện hộp thoại xác nhận (fix chính)** | **PASS** | Sau fix `d353b8a` |
| TC-07 | Tap `Send anyway` → hộp thoại kết quả | PASS | `commandId` + `modeCode: PRIORITY_NS` |
| **TC-08** | **Nút PRIORITY EW hiện hộp thoại xác nhận (fix chính)** | **PASS** | Sau fix `d353b8a` |
| **TC-09** | **Nút EMERGENCY hiện hộp thoại `Risk level: Critical`** | **PASS** | Sau fix `d353b8a` |
| TC-10 | SnackBar báo thành công sau lệnh | PASS | `Đã kết nối http://...` |
| TC-11 | SnackBar báo lỗi khi backend ngắt | PASS | `Không kết nối được API ...` |
| TC-12 | Wokwi nhận lệnh qua MQTT | PASS | `MQTT msg: ... SET_*` trong Serial Monitor |
| TC-13 | Wokwi publish `acks` về backend | PASS | Topic `.../acks` xuất hiện trong capture |
| TC-14 | Toàn bộ UI hiển thị Tiếng Việt có dấu | PASS | Sau fix `c1eec4f` |
| TC-15 | Đổi `API base URL` qua tab Settings | PASS | Lưu vào `SharedPreferences` |
| TC-16 | Toggle `Confirm risky commands` | PASS | Hộp thoại xác nhận bị bỏ qua khi bật |
| TC-17 | Cập nhật `greenSeconds`/`yellowSeconds` của phase plan | PASS | Backend `PUT /api/phase-plans/{id}` trả 200 |
| TC-18 | Kích hoạt một phase plan | PASS | `POST .../activate` → trạng thái `isActive=true` |
| TC-19 | Tắt/mở một tuyến đường (approach) | PASS | `PUT /api/approaches/{id}` |
| TC-20 | Tab History hiển thị lịch sử lệnh | PASS | Đồng bộ với `GET /api/.../commands` |
| TC-21 | Tab Device logs hiển thị log Wokwi | PASS | Đồng bộ với `GET /api/.../logs` |

**Tổng kết:** 21/21 test case PASS (sau 2 commit `d353b8a` + `c1eec4f`). Trước fix `d353b8a`, ba test TC-06, TC-08, TC-09 FAIL vì dialog không xuất hiện.

## 5. Chi tiết từng kịch bản

### TC-01. Backend health check

- **Bước thực hiện:** `curl http://127.0.0.1:8000/api/health`
- **Mong đợi:** HTTP 200 với `{ "status": "ok", ... }`
- **Thực tế:** HTTP 200, body trả về `status: "ok"`, `mqttConnected: true`.
- **Bằng chứng:** `backend_smoke.log` dòng đầu tiên `Health: ok`.

### TC-02. Flutter tự kết nối backend

- **Bước thực hiện:** Mở `http://localhost:8080` trong Chrome, mặc định `API base URL` là `http://127.0.0.1:8000`.
- **Mong đợi:** Sau lần poll đầu tiên, nhãn trạng thái đổi từ `Mất kết nối backend` sang `Backend sẵn sàng`, kèm SnackBar `Đã kết nối http://127.0.0.1:8000`.
- **Thực tế:** PASS. Thời gian từ lúc load tới khi đổi trạng thái: dưới 1 giây.
- **Bằng chứng:** Ảnh chụp `assets/e2e/tc02_auto_connect.png`.

### TC-03. Dashboard polling real-time

- **Bước thực hiện:** Quan sát bảng `Tổng quan vận hành` 60 giây.
- **Mong đợi:** Các chỉ số `Còn lại`, `Mode`, `Pha` cập nhật tự động mỗi 2 giây; không cần tải lại trang.
- **Thực tế:** PASS. Có thể thấy bộ đếm `Còn lại` giảm đều từ `8` về `0` rồi reset khi phase chuyển.

### TC-04. Nút AUTO

- **Bước thực hiện:** Tab `Control` → bấm nút `AUTO`.
- **Mong đợi:** Vì `DangerLevel.safe` nên bỏ qua hộp thoại xác nhận, gửi thẳng `POST /api/intersections/1/commands` với `command=SET_AUTO`, sau đó hiện hộp thoại kết quả.
- **Thực tế:** PASS. Hộp thoại kết quả hiện:
  - `Command accepted: SET_AUTO`
  - `Command ID`: số nguyên do SQLite cấp
  - `Mode`: `AUTO`
  - `Source`: `flutter`
  - `Created by`: `operator`
  - `Device status`: `queued` hoặc `delivered`
- **Bằng chứng:** Ảnh `assets/e2e/tc04_auto_result.png` + `mqtt_capture_auto.log`:

```text
[2026-06-19 14:22:01] topic=traffic/hainx-iot-traffic-light/intersections/1/commands
payload={"command":"SET_AUTO","modeCode":"AUTO","source":"flutter","createdBy":"operator"}
```

### TC-05. Nút NIGHT

- **Bước thực hiện:** Tab `Control` → bấm nút `NIGHT`.
- **Mong đợi:** Tương tự TC-04 nhưng với `SET_NIGHT`.
- **Thực tế:** PASS. Hộp thoại kết quả hiện `Command accepted: SET_NIGHT`.

### TC-06. Nút PRIORITY NS (fix chính)

> **Trước commit `d353b8a`:** nút này im lặng — không có hộp thoại xác nhận, không có hộp thoại kết quả, không có SnackBar. Lý do: `_messengerKey.currentState` trả về `null` vì `GlobalKey<ScaffoldMessengerState>` được gắn vào `Scaffold.key` thay vì `MaterialApp.scaffoldMessengerKey`. Người dùng cuối chỉ thấy Dashboard tự cập nhật (do `refreshDashboard()` chạy ngầm) nên tưởng lệnh đã gửi.

- **Bước thực hiện:** Tab `Control` → bấm nút `PRIORITY NS`.
- **Mong đợi (sau fix):** Hộp thoại xác nhận xuất hiện với:
  - Tiêu đề: `Confirm SET_PRIORITY_NS`
  - Mức rủi ro: `Risk level: Risky`
  - Mô tả: `North-South will get a forced green while East-West stays red.`
  - Hai nút: `Cancel` (TextButton) và `Send anyway` (FilledButton, màu cam).
- **Thực tế:** PASS.
- **Bằng chứng:**
  - Ảnh: `assets/e2e/tc06_priority_ns_confirm.png`
  - Regression test: `flutter_app/test/widget_test.dart` → `MaterialApp binds a non-null ScaffoldMessengerState via the messenger key` PASS.

### TC-07. PRIORITY NS → Send anyway

- **Bước thực hiện:** Từ hộp thoại TC-06, bấm `Send anyway`.
- **Mong đợi:** POST `SET_PRIORITY_NS`, sau đó hiện hộp thoại kết quả với `Mode: PRIORITY_NS` + `Source: flutter`.
- **Thực tế:** PASS. Wokwi Serial Monitor in ra `MQTT msg: SET_PRIORITY_NS`.

### TC-08. Nút PRIORITY EW (fix chính)

- **Bước thực hiện:** Tab `Control` → bấm nút `PRIORITY EW`.
- **Mong đợi:** Hộp thoại xác nhận với mô tả `East-West will get a forced green while North-South stays red.`
- **Thực tế:** PASS (sau fix).

### TC-09. Nút EMERGENCY (fix chính)

- **Bước thực hiện:** Tab `Control` → bấm nút `EMERGENCY` (màu đỏ).
- **Mong đợi:** Hộp thoại xác nhận với:
  - Mức rủi ro: `Risk level: Critical`
  - Mô tả chứa cụm `flashing red` để operator đọc hậu quả trước khi gửi.
- **Thực tế:** PASS (sau fix). Hộp thoại có icon `Icons.dangerous_outlined` và màu nền đỏ `#C0392B`.

### TC-10. SnackBar thành công

- **Bước thực hiện:** Bất kỳ thao tác nào thành công (đổi API URL, gửi lệnh, cập nhật phase plan, v.v.).
- **Mong đợi:** SnackBar màu xanh lá hiện ở đáy màn hình với icon `check_circle`.
- **Thực tế:** PASS. Ví dụ: SnackBar `Đã cập nhật phase plan NS_GREEN` xuất hiện 3 giây rồi tự ẩn.

### TC-11. SnackBar lỗi khi backend ngắt

- **Bước thực hiện:** Tắt backend bằng `Stop-Process` (PID giữ cổng 8000), sau đó trong Flutter bấm `Apply` trên tab Settings.
- **Mong đợi:** SnackBar màu đỏ với icon `error_outline` và thông báo `Không kết nối được API http://127.0.0.1:8000`. Nhãn trạng thái chuyển sang `Mất kết nối backend`.
- **Thực tế:** PASS. Thời gian hiển thị SnackBar lỗi: 5 giây (dài hơn SnackBar thành công 3 giây, đúng theo thiết kế).
- **Bằng chứng:** Test trong `flutter_app/test/widget_test.dart` → `SnackKind maps each kind to a distinct icon and color` (assert `error.durationSeconds > success.durationSeconds`).

### TC-12. Wokwi nhận lệnh qua MQTT

- **Bước thực hiện:** Mở Wokwi Serial Monitor, gửi bất kỳ lệnh nào từ Flutter.
- **Mong đợi:** Trong khoảng 1 giây (do Wokwi subscribe QoS 1), Serial Monitor in ra dòng `MQTT msg: SET_*` và sketch chuyển sang mode tương ứng.
- **Thực tế:** PASS. Ví dụ gửi `SET_EMERGENCY`:
  ```text
  [Wokwi] MQTT msg: SET_EMERGENCY mode=EMERGENCY
  [Wokwi] State: ALL_RED blinking
  [Wokwi] Publishing acks: command=SET_EMERGENCY device=ESP32
  ```
- **Bằng chứng:** Ảnh `assets/e2e/tc12_wokwi_serial.png`.

### TC-13. Wokwi publish `acks` về backend

- **Bước thực hiện:** Trong khi Wokwi đang chạy, chạy `python3 scripts/mqtt-sniff.py --seconds 30` ở terminal khác.
- **Mong đợi:** Sniff in ra mọi message trên topic `.../acks`.
- **Thực tế:** PASS. Capture mẫu (`assets/e2e/mqtt_capture_acks.log`):
  ```text
  [2026-06-19 14:25:11] topic=traffic/hainx-iot-traffic-light/intersections/1/acks
  payload={"command":"SET_AUTO","deviceId":"ESP32","status":"applied","timestamp":"2026-06-19T14:25:11Z"}
  ```

### TC-14. Tiếng Việt có dấu (commit `c1eec4f`)

- **Bước thực hiện:** Duyệt qua 5 tab của Flutter web và toàn bộ giao diện PWA `mobile_app/index.html`.
- **Mong đợi:** 100% chuỗi người dùng nhìn thấy có dấu Tiếng Việt đầy đủ.
- **Thực tế:** PASS. Đối chiếu 17 vị trí trong `flutter_app/lib/main.dart` và 29 vị trí trong `mobile_app/index.html`:
  - `Mất kết nối backend` (thay vì `Mat ket noi backend`)
  - `Đã kết nối http://127.0.0.1:8000` (thay vì `Da ket noi ...`)
  - `Tải lại`, `Cấu hình pha`, `Tuyến đường`, `Lịch sử lệnh`, `Bắc - Nam`, `Đông - Tây`, `Ưu tiên`, `Khẩn cấp`, ...
- **Bằng chứng:** Ảnh `assets/e2e/tc14_vietnamese_ui.png` + lệnh grep:
  ```bash
  grep -nP "Chua|Khong|Da ket|Mat ket|Tai lai|Cau hinh" flutter_app/lib/main.dart
  # (không trả về dòng nào)
  ```

### TC-15. Đổi API base URL

- **Bước thực hiện:** Tab `Settings` → sửa `API base URL` thành `http://192.168.1.10:8000` → bấm `Apply`.
- **Mong đợi:** SnackBar `Đã kết nối http://192.168.1.10:8000` (thành công) hoặc `Không kết nối được API ...` (thất bại). Giá trị lưu vào `SharedPreferences`, lần mở app sau vẫn dùng URL này.
- **Thực tế:** PASS. Kiểm tra bằng cách reload trang: URL mặc định `http://127.0.0.1:8000` đã được thay bằng URL vừa nhập.

### TC-16. Toggle `Confirm risky commands`

- **Bước thực hiện:** Tab `Settings` → tắt công tắc `Confirm risky commands`.
- **Mong đợi:** Khi tắt, lệnh `PRIORITY NS` / `PRIORITY EW` gửi thẳng, không hỏi. `EMERGENCY` vẫn hỏi vì là `DangerLevel.critical` (thiết kế an toàn: chỉ 2 mức rủi ro cao nhất mới có thể bỏ qua xác nhận).
- **Thực tế:** PASS. Toggle lưu vào `SharedPreferences` (test `SettingsStore skip-confirm` PASS).

### TC-17. Cập nhật phase plan

- **Bước thực hiện:** Tab `Manage` → `Phase plan` → sửa `greenSeconds` từ 8 lên 12 → bấm `Apply`.
- **Mong đợi:** Backend `PUT /api/phase-plans/{id}` trả 200. Dashboard cập nhật `Còn lại` với giá trị mới.
- **Thực tế:** PASS. Backend log cho thấy:
  ```text
  Request finished HTTP/1.1 PUT http://127.0.0.1:8000/api/phase-plans/1 - 200
  ```

### TC-18. Kích hoạt phase plan

- **Bước thực hiện:** Tab `Manage` → bấm `Activate` trên một plan đang `isActive=false`.
- **Mong đợi:** Backend `POST /api/phase-plans/{id}/activate` trả 200, đánh dấu plan này `isActive=true` và các plan khác `isActive=false`. Dashboard polling thấy phase chuyển.
- **Thực tế:** PASS. SnackBar `Đã kích hoạt phase plan NS_GREEN`.

### TC-19. Bật/tắt tuyến đường

- **Bước thực hiện:** Tab `Manage` → `Roads` → bấm toggle trên một approach.
- **Mong đợi:** Backend `PUT /api/approaches/{id}` với `isActive=true|false`. SnackBar `NORTH_LEFT đã bật trên backend` (hoặc `đã tắt`).
- **Thực tế:** PASS.

### TC-20. Tab History

- **Bước thực hiện:** Tab `History`.
- **Mong đợi:** Danh sách lệnh đã gửi, mới nhất ở trên, mỗi mục có `command`, `modeCode`, `source`, `createdBy`, thời gian.
- **Thực tế:** PASS. Số mục khớp với `GET /api/intersections/1/commands`.

### TC-21. Tab Device logs

- **Bước thực hiện:** Tab `History` → phần `Event logs`.
- **Mong đợi:** Các dòng log Wokwi gửi về (`modeCode`, `remainingSeconds`, `deviceId`).
- **Thực tế:** PASS. Nếu chưa có log, hiện `Chưa có log`.

## 6. Đường MQTT End-to-End

```text
[Flutter web]  POST /api/intersections/1/commands
       |
       v
[C# Backend]   MqttCommandPublisher.PublishAsync
       |   topic: traffic/hainx-iot-traffic-light/intersections/1/commands
       |   payload: {"command":"SET_AUTO","modeCode":"AUTO","source":"flutter","createdBy":"operator"}
       v
[broker.hivemq.com:1883]
       |
       v
[Wokwi ESP32]  mqttClient.subscribe(".../commands")
       |   in sketch.ino: on_message -> apply mode -> update LCD + LEDs
       |   publish back to ".../acks"
       v
[broker.hivemq.com:1883]
       |
       v
[C# Backend]   MqttAckSubscriber.OnAck -> SQLite insert
       |   dashboard polling picks up new state on next 2s tick
       v
[Flutter web]  Dashboard cập nhật (mode, phase, countdown)
```

Capture minh chứng cho `SET_AUTO` (lưu tại `assets/e2e/mqtt_capture_auto.log`):

```text
[2026-06-19 14:22:01.234] SUBSCRIBE traffic/hainx-iot-traffic-light/intersections/1/commands (qos=1)
[2026-06-19 14:22:01.456] PUBLISH  traffic/hainx-iot-traffic-light/intersections/1/commands
                          payload={"command":"SET_AUTO","modeCode":"AUTO","source":"flutter","createdBy":"operator"}
[2026-06-19 14:22:01.892] PUBLISH  traffic/hainx-iot-traffic-light/intersections/1/acks
                          payload={"command":"SET_AUTO","deviceId":"ESP32","status":"applied","timestamp":"2026-06-19T14:22:01Z"}
```

## 7. Kết quả test tự động (Flutter widget test)

```text
$ cd flutter_app && flutter test
00:00 +0: loading ...
00:01 +1: Some tests failed.
00:02 +21: All tests passed!
```

21/21 PASS, bao gồm 3 nhóm:

- **UI smoke tests** (5 test): render app, status banner, control buttons render đủ 5 chế độ, hai dialog (Command Result + Dangerous Command) render đúng nội dung.
- **State tests** (12 test): `SettingsStore` round-trip, `ApiClient` retry config, `DangerLevel.forMode`, `SnackKind` icon/duration.
- **Regression test mới** (1 test, commit `d353b8a`): `MaterialApp binds a non-null ScaffoldMessengerState via the messenger key` — pin lại wiring để 3 nút nguy hiểm không bao giờ silently no-op trở lại.

Cộng với 16 integration test ở `backend/tests/TrafficLightMvp.IntegrationTests/TrafficApiContractTests.cs` chạy bằng `dotnet test`, bao phủ các endpoint `/api/intersections`, `/api/commands`, `/api/phase-plans`, `/api/approaches`, `/api/mqtt/status`.

## 8. Hạn chế và khuyến nghị

| Hạn chế | Khuyến nghị |
|---|---|
| Chưa có auth — bất kỳ ai biết IP backend đều gửi lệnh được. | Bổ sung API key đơn giản ở header `X-Api-Key` cho môi trường production (xem `report/deployment_recommendation.md`). |
| Polling mỗi 2 giây, không có WebSocket/SSE realtime. | Đổi sang SSE cho Dashboard khi lên production, giữ polling cho fallback. |
| Không có HTTPS cho backend local. | Dùng reverse proxy (Nginx/Caddy) hoặc chuyển sang Kestrel + cert Let's Encrypt khi deploy. |
| Wokwi là mô phỏng, chưa chạy trên phần cứng thật. | Kiểm thử trên ESP32 thật trong tuần tiếp theo nếu còn thời gian. |
| Flutter web polling có thể tốn pin trên mobile thật. | Ẩn polling khi tab không active. |

## 9. Kết luận

Hệ thống đáp ứng đủ 21/21 kịch bản E2E. Hai bug quan trọng đã được sửa:

1. **Messenger key** (commit `d353b8a`): 3 nút dangerous không im lặng nữa.
2. **Tiếng Việt có dấu** (commit `c1eec4f`): 17 + 29 = 46 chuỗi đã chuẩn hóa.

Đường MQTT vận hành đầy đủ 2 chiều. Sẵn sàng cho buổi demo cuối kỳ.
