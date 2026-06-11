# 01. Kế Hoạch Dự Án

## Tên đề tài

Hệ thống mô phỏng điều khiển đèn giao thông thông minh tại một giao lộ.

## Bối cảnh

Nhóm không có phần cứng thật, vì vậy dự án ưu tiên mô phỏng đầy đủ trên Wokwi. Báo cáo và slide sẽ tập trung vào sơ đồ khối, thuật toán điều khiển, mạch mô phỏng, code và kết quả chạy mô phỏng.

Một điểm quan trọng khi làm bài lớn là nên thể hiện được nhiều kiến thức đã học trong môn và các học phần liên quan. Vì vậy ngoài mô phỏng Wokwi, nhóm cần trình bày thêm thiết kế CSDL, database lưu lịch sử điều khiển, ứng dụng OOP trong code, dashboard/mobile app điều khiển và hướng kết nối IoT.

## Phạm vi MVP

MVP là bản tối thiểu phải hoàn thành để nộp được:

- Mô phỏng một giao lộ gồm 2 hướng: Bắc-Nam và Đông-Tây.
- Mỗi hướng có 3 đèn: đỏ, vàng, xanh.
- Có đếm ngược thời gian pha đèn bằng LCD 16x2 hoặc 7-segment.
- Chế độ tự động:
  - Hướng Bắc-Nam xanh 30 giây.
  - Hướng Bắc-Nam vàng 5 giây.
  - Hướng Đông-Tây xanh 30 giây.
  - Hướng Đông-Tây vàng 5 giây.
- Chế độ ban đêm: đèn vàng nhấp nháy.
- Chế độ ưu tiên: ưu tiên Bắc-Nam hoặc Đông-Tây.
- Chế độ khẩn cấp: tất cả hướng đỏ.
- Điều khiển chế độ bằng nút nhấn trong Wokwi hoặc Serial Monitor.
- Có ảnh chụp mô phỏng và video/GIF demo.

## Quyết định kỹ thuật đã chốt

- Board mô phỏng chính: ESP32 DevKit.
- Công cụ mô phỏng: Wokwi.
- Hiển thị: LCD 16x2 I2C.
- Điều khiển mode: 4 nút nhấn dùng `INPUT_PULLUP`.
- Database/ERD: dùng để trình bày phần dashboard/app và lưu lịch sử điều khiển, không bắt buộc Wokwi phải kết nối database thật.
- App/mobile: làm dashboard web/mobile mock để trình bày luồng điều khiển, không làm app native trong MVP.

## Phạm vi mở rộng

Chỉ làm nếu MVP đã ổn:

- Dashboard web/mobile mock để thể hiện điều khiển từ app.
- Thiết kế CSDL để lưu cấu hình pha đèn, lịch sử chuyển chế độ và log sự kiện.
- Backend/API đơn giản để dashboard gửi lệnh điều khiển và đọc trạng thái.
- Áp dụng OOP trong code: lớp điều khiển giao lộ, lớp đèn, lớp pha đèn, lớp quản lý chế độ.
- ESP32 kết nối WiFi/MQTT để mô phỏng điều khiển IoT.
- Hiển thị trạng thái lên màn hình OLED/LCD đẹp hơn.
- Thêm cảm biến giả lập xe chờ bằng nút nhấn hoặc ultrasonic sensor.

## Không làm trong bản chính

- Không làm xe thật, cảm biến thật, module thật.
- Không làm app mobile native phức tạp.
- Không làm nhiều giao lộ.
- Không làm thuật toán tối ưu giao thông nâng cao nếu chưa xong MVP.

## Linh kiện mô phỏng dự kiến

- ESP32 DevKit hoặc Arduino Uno.
- 6 LED cho 2 cụm đèn giao thông.
- 6 điện trở 220Ω.
- LCD 16x2 I2C hoặc OLED để hiển thị trạng thái và countdown.
- 3-4 nút nhấn:
  - AUTO
  - NIGHT
  - PRIORITY
  - EMERGENCY

## Các bước tiến hành

1. Chốt yêu cầu và phạm vi MVP.
2. Vẽ sơ đồ khối hệ thống.
3. Thiết kế thuật toán trạng thái đèn.
4. Dựng mạch trên Wokwi.
5. Viết code điều khiển tự động.
6. Thêm điều khiển chế độ bằng nút nhấn hoặc Serial Monitor.
7. Thêm LCD/7-seg hiển thị countdown.
8. Test đủ các chế độ.
9. Chụp ảnh mạch và quay demo.
10. Viết báo cáo.
11. Làm slide.
12. Tập thuyết trình và đóng gói sản phẩm.

## Tiêu chí hoàn thành

- Demo Wokwi chạy được ít nhất 4 chế độ: AUTO, NIGHT, PRIORITY, EMERGENCY.
- Có code rõ ràng, dễ giải thích.
- Có ảnh mạch trong báo cáo.
- Có video/GIF demo.
- Báo cáo có đủ sơ đồ khối, nguyên lý, thuật toán, code, kết quả.
- Slide trình bày trong 7-10 phút.
