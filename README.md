# Project 2 - Hệ thống mô phỏng điều khiển đèn giao thông 1 giao lộ

## Thông tin nhanh

- Môn học: Internet vạn vật (IoT)
- Đề tài: Xây dựng hệ thống mô phỏng điều khiển hệ thống đèn giao thông ở 1 giao lộ
- Hình thức demo chính: Wokwi
- Hình thức điều khiển mở rộng: Flutter app/web -> C# API -> MQTT -> ESP32/Wokwi
- Thành viên: 2 người, gồm Nguyễn Xuân Hải và Trần Đình Đức
- Sản phẩm cần nộp: report, slide, sản phẩm demo

## Mục tiêu

Xây dựng một mô hình đèn giao thông tại 1 giao lộ có thể mô phỏng được hoàn toàn trên Wokwi, không cần phần cứng thật. Hệ thống có các chế độ tự động, ban đêm, ưu tiên một hướng và khẩn cấp. Bản nâng cấp hiện tại bổ sung C# backend, SQLite, Flutter app source và MQTT bridge để điện thoại/app có thể gửi lệnh xuống ESP32/Wokwi qua broker public.

## Tài liệu dự án

Tài liệu dự án đã được gom vào [docs/README.md](./docs/README.md) và chia theo nhóm:

- `docs/planning/`: kế hoạch, timeline, task board, phân công, deliverables theo tuần
- `docs/design/`: requirements, sơ đồ thiết kế, ma trận tiêu chí, kiến trúc app/backend/MQTT
- `docs/demo/`: checklist demo, kịch bản điện thoại, khung slide
- `docs/report/`: báo cáo kỹ thuật, phụ lục OOP, đóng góp thành viên, E2E notes
- `docs/status/`: implementation status và plan theo thời điểm
- `docs/meetings/`: ghi chú họp

File nên mở đầu tiên:

- [docs/README.md](./docs/README.md): chỉ mục tài liệu đầy đủ
- [docs/design/09_so_do_thiet_ke.md](./docs/design/09_so_do_thiet_ke.md): bộ sơ đồ chuẩn để đưa vào report/PPT
- [docs/report/dong_gop_tung_thanh_vien.md](./docs/report/dong_gop_tung_thanh_vien.md): bản ngắn về đóng góp từng thành viên

## Theo dõi công việc trên GitHub

- Issue tracker: https://github.com/xuanhai0913/iot-traffic-light-wokwi/issues
- Week 1 - Scope & thiết kế: https://github.com/xuanhai0913/iot-traffic-light-wokwi/milestone/1
- Week 2 - Wokwi, code & test: https://github.com/xuanhai0913/iot-traffic-light-wokwi/milestone/2
- Week 3 - Report, slide & nộp: https://github.com/xuanhai0913/iot-traffic-light-wokwi/milestone/3

Nhóm dùng label `member: ...` để biết người phụ trách. Các issue của Nguyễn Xuân Hải được assign trực tiếp vào GitHub user `xuanhai0913`; các issue của Trần Đình Đức dùng label `member: tran-dinh-duc` cho đến khi có GitHub username để assign trực tiếp.

## Cấu trúc thư mục

- `wokwi/`: lưu code Arduino/ESP32 và file `diagram.json`.
- `flutter_app/`: lưu Flutter mobile app source gọi C# API.
- `backend/`: lưu C# ASP.NET Core API, SQLite schema và MQTT bridge.
- `docs/`: lưu toàn bộ tài liệu dự án đã được nhóm lại theo chủ đề.
- `assets/diagrams/`: lưu source Mermaid của các sơ đồ để export sang ảnh khi làm report/slide.

## Hướng triển khai đề xuất

MVP nâng cấp dùng ESP32 trong Wokwi vì ESP32 có WiFi tích hợp và phù hợp IoT/MQTT hơn Arduino Uno. Luồng product:

```text
Flutter app/web -> C# Backend API -> MQTT Broker -> ESP32/Wokwi -> Den + LCD
ESP32/Wokwi -> MQTT Broker -> C# Backend API -> Flutter app/web
```

`flutter_app/` là source UI vận hành chính hiện còn trong repo. Có thể chạy cho điện thoại, emulator hoặc build web để demo trên browser.

## Chạy nhanh backend + MQTT

```powershell
cd backend
dotnet restore
$env:MQTT_ENABLED="true"
dotnet run
```

Kiểm tra:

```text
http://127.0.0.1:8000/api/health
http://127.0.0.1:8000/api/mqtt/status
```

MQTT topic mặc định:

```text
traffic/hainx-iot-traffic-light/intersections/1/commands
traffic/hainx-iot-traffic-light/intersections/1/status
traffic/hainx-iot-traffic-light/intersections/1/acks
```

## Lưu ý để tăng điểm

Môn này có thể được đánh giá cao hơn nếu sản phẩm không chỉ chạy mô phỏng đèn, mà còn thể hiện được nhiều kiến thức đã học: thiết kế CSDL, database, OOP, dashboard/mobile app, thuật toán điều khiển và mô hình IoT. Vì vậy nhóm nên trình bày rõ phần nào đã triển khai, phần nào là thiết kế mở rộng có thể triển khai thực tế.

## Demo nhanh sau ban nang cap

Chay backend cho dien thoai va Wokwi:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\run-backend-demo.ps1
```

Kiem tra source Wokwi truoc khi mo simulator:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\test-wokwi-source.ps1
```

Build Android APK:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\build-flutter-android.ps1
```

Expected APK output after a successful build:

```text
dist/android/iot-traffic-light-v1.0.0.apk
```

Kich ban nghiem thu day du nam trong `docs/demo/demo_dien_thoai.md` va `docs/demo/wokwi_capture_checklist.md`.
