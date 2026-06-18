# Project 2 - Hệ thống mô phỏng điều khiển đèn giao thông 1 giao lộ

## Thông tin nhanh

- Môn học: Internet vạn vật (IoT)
- Đề tài: Xây dựng hệ thống mô phỏng điều khiển hệ thống đèn giao thông ở 1 giao lộ
- Hình thức demo chính: Wokwi
- Hình thức điều khiển mở rộng: Flutter/PWA -> C# API -> MQTT -> ESP32/Wokwi
- Thành viên: 2 người, gồm Nguyễn Xuân Hải và Trần Đình Đức
- Sản phẩm cần nộp: report, slide, sản phẩm demo

## Mục tiêu

Xây dựng một mô hình đèn giao thông tại 1 giao lộ có thể mô phỏng được hoàn toàn trên Wokwi, không cần phần cứng thật. Hệ thống có các chế độ tự động, ban đêm, ưu tiên một hướng và khẩn cấp. Bản nâng cấp hiện tại bổ sung C# backend, SQLite, Flutter app source và MQTT bridge để điện thoại/app có thể gửi lệnh xuống ESP32/Wokwi qua broker public.

## File quản lý dự án

- [01_ke_hoach_du_an.md](./01_ke_hoach_du_an.md): phạm vi, mục tiêu, yêu cầu, các bước tiến hành.
- [02_timeline.md](./02_timeline.md): timeline theo ngày từ 04/06/2026 đến 18/06/2026.
- [03_task_board.md](./03_task_board.md): danh sách task dạng checklist, có owner và trạng thái.
- [04_phan_cong_2_thanh_vien.md](./04_phan_cong_2_thanh_vien.md): phân công việc cho 2 thành viên.
- [05_demo_wokwi.md](./05_demo_wokwi.md): kế hoạch dựng mạch, mô phỏng, quay demo.
- [06_bao_cao_slide_checklist.md](./06_bao_cao_slide_checklist.md): khung report, slide và kịch bản thuyết trình.
- [07_de_xuat_lam_ro_chu_de.md](./07_de_xuat_lam_ro_chu_de.md): đề xuất làm rõ scope, chế độ demo và tiêu chí chấm điểm.
- [08_requirements.md](./08_requirements.md): yêu cầu chức năng, CSDL, OOP, dashboard mobile/web và tiêu chí nghiệm thu.
- [09_so_do_thiet_ke.md](./09_so_do_thiet_ke.md): bộ sơ đồ thiết kế gồm kiến trúc hệ thống, ERD, state machine, OOP class diagram và sequence flow.
- [10_week1_hai_deliverables.md](./10_week1_hai_deliverables.md): phần Week 1 đã chốt của Nguyễn Xuân Hải gồm scope, sơ đồ hệ thống, linh kiện và pin map.
- [11_week2_wokwi_code_test.md](./11_week2_wokwi_code_test.md): phần Week 2 gồm mạch Wokwi, code OOP, mode điều khiển và checklist test.
- [12_mobile_app_extension.md](./12_mobile_app_extension.md): hướng triển khai mobile app/PWA điều khiển, kiến trúc thực tế và roadmap mở rộng.

## Theo dõi công việc trên GitHub

- Issue tracker: https://github.com/xuanhai0913/iot-traffic-light-wokwi/issues
- Week 1 - Scope & thiết kế: https://github.com/xuanhai0913/iot-traffic-light-wokwi/milestone/1
- Week 2 - Wokwi, code & test: https://github.com/xuanhai0913/iot-traffic-light-wokwi/milestone/2
- Week 3 - Report, slide & nộp: https://github.com/xuanhai0913/iot-traffic-light-wokwi/milestone/3

Nhóm dùng label `member: ...` để biết người phụ trách. Các issue của Nguyễn Xuân Hải được assign trực tiếp vào GitHub user `xuanhai0913`; các issue của Trần Đình Đức dùng label `member: tran-dinh-duc` cho đến khi có GitHub username để assign trực tiếp.

## Cấu trúc thư mục

- `wokwi/`: lưu code Arduino/ESP32 và file `diagram.json`.
- `mobile_app/`: lưu mobile web/PWA mock để điều khiển và giám sát giao lộ.
- `flutter_app/`: lưu Flutter mobile app source gọi C# API.
- `backend/`: lưu C# ASP.NET Core API, SQLite schema và MQTT bridge.
- `report/`: lưu báo cáo Word/PDF.
- `slides/`: lưu slide thuyết trình.
- `assets/`: lưu hình mạch, sơ đồ khối, ảnh chụp mô phỏng.
- `assets/diagrams/`: lưu source Mermaid của các sơ đồ để export sang ảnh khi làm report/slide.
- `demo/`: lưu video/GIF demo.
- `meeting_notes/`: ghi chú họp nhóm.

## Hướng triển khai đề xuất

MVP nâng cấp dùng ESP32 trong Wokwi vì ESP32 có WiFi tích hợp và phù hợp IoT/MQTT hơn Arduino Uno. Luồng product:

```text
Flutter/PWA -> C# Backend API -> MQTT Broker -> ESP32/Wokwi -> Den + LCD
ESP32/Wokwi -> MQTT Broker -> C# Backend API -> Flutter/PWA
```

PWA trong `mobile_app/` vẫn dùng được để demo nhanh trên browser. Flutter app trong `flutter_app/` là hướng mobile app thật cho điện thoại/emulator.

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

APK output:

```text
dist/android/iot-traffic-light-v1.0.0.apk
```

Kich ban nghiem thu day du nam trong `docs/demo_dien_thoai.md` va `demo/wokwi_capture_checklist.md`.
