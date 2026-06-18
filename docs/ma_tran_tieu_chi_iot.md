# Ma trận tiêu chí môn IoT

> Đánh giá repository ngày 15/06/2026. “Đạt source” nghĩa là có implementation trong mã; không đồng nghĩa đã có đầy đủ evidence nghiệm thu.

## 1. Yêu cầu chức năng bắt buộc

| ID | Tiêu chí | Trạng thái | Bằng chứng/ghi chú |
|---|---|---|---|
| FR-01 | Giao lộ Bắc-Nam và Đông-Tây, đủ đỏ/vàng/xanh | Đạt source | `wokwi/diagram.json`, `sketch.ino`; bốn cụm hiển thị nhưng chỉ hai bộ GPIO độc lập |
| FR-02 | AUTO | Đạt source | `IntersectionController::runAuto` |
| FR-03 | NIGHT vàng nhấp nháy | Đạt source | `runNight`, chu kỳ 500 ms |
| FR-04 | PRIORITY | Đạt source | `PRIORITY_NS`, `PRIORITY_EW` |
| FR-05 | EMERGENCY tất cả đỏ | Đạt source | `runEmergency` |
| FR-06 | LCD/Serial có mode và countdown | Đạt source | `DisplayManager`; countdown chỉ có ý nghĩa ở AUTO |
| FR-07 | Nút hoặc Serial command | Đạt source | Bốn nút và command `a/n/p/pe/e` |
| FR-08 | Ảnh/video/GIF chứng minh mô phỏng chạy | Đạt ảnh, chưa có video | Đã có 5 ảnh mode và ảnh compile/run trong `assets/wokwi/`; video cuối chưa quay |

## 2. Yêu cầu nâng điểm

| ID | Tiêu chí | Trạng thái | Bằng chứng/ghi chú |
|---|---|---|---|
| ER-01 | Thiết kế CSDL/ERD | Đạt | `backend/schema.sql`, tài liệu kiến trúc |
| ER-02 | Database lưu phase và lịch sử | Đạt implementation | SQLite có phase plan, command, log, device status |
| ER-03 | Áp dụng OOP | Đạt | Firmware, C# và Flutter; xem [phụ lục OOP](../report/mvp_oop_implementation.md) |
| ER-04 | Dashboard/mobile | Đạt implementation | Flutter có Dashboard, Control, Manage, History, Settings |
| ER-05 | API gửi command | Đạt implementation | `POST /api/intersections/{id}/commands` |
| ER-06 | Kết nối IoT WiFi/MQTT/HTTP | Đạt runtime demo | Backend nhận device `wokwi-esp32-01`, 5 command có `device_status=acknowledged` |
| ER-07 | Mobile app/PWA | Đạt implementation | Flutter source và APK artifact hiện có |

## 3. UI/mobile

| ID | Tiêu chí | Trạng thái | Ghi chú |
|---|---|---|---|
| UI-01 | Trạng thái hai trục đèn | Đạt | Hiển thị NORTH/SOUTH/EAST/WEST |
| UI-02 | AUTO | Đạt | Control button |
| UI-03 | NIGHT | Đạt | Control button |
| UI-04 | PRIORITY NS/EW | Đạt | Hai control button |
| UI-05 | EMERGENCY | Đạt | Control button |
| UI-06 | Countdown và mode | Đạt logic backend | Có thể lệch Wokwi vì backend chạy clock riêng |
| UI-07 | Lịch sử lệnh | Đạt | Hiển thị `device_status` |
| UI-08 | Cấu hình thời gian pha | Đạt ở backend | Chưa gửi cấu hình này xuống firmware |
| UI-09 | Phân biệt demo và triển khai thật | Đạt trong bộ tài liệu mới | Không coi API success là device ACK |

## 4. Yêu cầu phi chức năng

| ID | Tiêu chí | Trạng thái | Ghi chú |
|---|---|---|---|
| NFR-01 | Wokwi chạy ổn, không lỗi compile | Đạt evidence ảnh | Wokwi UI compile/run đã xác nhận; xem `assets/wokwi/wokwi_compile_run.png` |
| NFR-02 | Code dễ đọc, tách lớp | Đạt mức MVP | OOP rõ, nhưng backend/Flutter còn file lớn |
| NFR-03 | Phân biệt đã làm và mở rộng | Đạt sau cập nhật tài liệu | Có nhãn xác nhận và production gap |
| NFR-04 | Video/GIF 30-60 giây | Chưa đạt | Chưa tìm thấy file video/GIF |
| NFR-05 | Repo có README, task, source, assets | Đạt một phần | Source/tài liệu có; media cuối và trạng thái commit sạch chưa có |

## 5. Tiêu chí nghiệm thu tổng hợp

| Hạng mục | Đánh giá |
|---|---|
| Wokwi đủ mode | Đạt ảnh evidence; còn thiếu video |
| Sơ đồ khối và pin map | Có source thiết kế và diagram |
| CSDL ít nhất bốn bảng | Đạt, schema rộng hơn yêu cầu |
| Giải thích OOP | Đạt |
| Dashboard/mobile | Đạt implementation |
| Mô tả app -> API/MQTT -> ESP32 | Đạt |
| Report PDF | Chưa tìm thấy |
| Slide hoàn chỉnh | Chưa tìm thấy, `slides/` mới có `.gitkeep` |
| Video/GIF demo | Chưa tìm thấy |
| Repo cuối đầy đủ | Chưa thể kết luận; working tree đang có nhiều file chưa commit |

## 6. Điểm mạnh có thể trình bày

- Không chỉ mock UI: có C# API, SQLite và MQTT bridge.
- Có command lifecycle đến mức ACK.
- Firmware chia class theo trách nhiệm.
- Database model hỗ trợ nhiều approach, signal head và phase plan.
- Flutter có artifact APK và màn hình vận hành tương đối đầy đủ.
- Backend đã có 8 integration tests cho API contract, command lifecycle, phase plan, road update và ACK scoping.

## 7. Điểm không nên tô hồng

- Đã có evidence ảnh và log command ACK; vẫn thiếu video quay cuối.
- `published` không phải `acknowledged`.
- Dashboard status chưa chắc là reported state của ESP32.
- Cấu hình phase từ Flutter chưa cập nhật firmware.
- Conflict matrix chưa enforce khi activate.
- Public MQTT và API mở không phù hợp production.
- State machine thiếu all-red clearance có thời lượng.

## 8. Việc cần hoàn tất trước khi nộp

1. Cài APK lên điện thoại thật và nhập API URL LAN.
2. Quay video 30-60 giây có app -> Wokwi -> ACK.
3. Chụp Flutter History có `acknowledged` và Settings có ESP32 `Last seen`.
4. Xuất report PDF và slide.
5. Kiểm tra file media, link Wokwi và link deploy nếu dùng.
6. Commit trạng thái cuối có chủ đích.
