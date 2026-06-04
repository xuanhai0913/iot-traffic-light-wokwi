# 07. Đề Xuất Làm Rõ Chủ Đề

## Vấn đề cần tránh

Đề bài ghi có thể điều khiển bằng app mobile hoặc WinForm. Nếu nhóm ôm cả app thật, WinForm thật, IoT thật và mô phỏng thật thì scope sẽ rộng, dễ không kịp. Vì nhóm không có phần cứng, hướng tốt nhất là làm demo Wokwi thật rõ, còn app/mobile/WinForm trình bày ở mức giao diện điều khiển và hướng mở rộng.

## Tên đề tài nên dùng

Hệ thống mô phỏng điều khiển đèn giao thông thông minh tại một giao lộ bằng Wokwi.

Tên này rõ 3 ý:

- Hệ thống là đèn giao thông 1 giao lộ.
- Sản phẩm chính là mô phỏng.
- Công cụ demo là Wokwi, phù hợp khi không có phần cứng.

## Scope nên chốt

### Bắt buộc làm

- 2 hướng giao thông: Bắc-Nam và Đông-Tây.
- Mỗi hướng có đỏ, vàng, xanh.
- AUTO mode chạy theo chu kỳ.
- NIGHT mode vàng nhấp nháy.
- PRIORITY mode ưu tiên một hướng.
- EMERGENCY mode tất cả đỏ.
- LCD hoặc 7-seg hiển thị chế độ và countdown.
- Button hoặc Serial Monitor để đổi chế độ.
- Ảnh chụp và video/GIF demo Wokwi.

### Nên làm nếu kịp

- Dashboard web/mobile mock để thể hiện app điều khiển.
- Sơ đồ giao tiếp app -> ESP32 -> đèn.
- Mô phỏng lệnh điều khiển qua Serial command.

### Không nên làm

- App mobile native thật.
- WinForms thật nếu nhóm không có máy Windows.
- Mô hình xe/cảm biến phức tạp.
- Nhiều giao lộ hoặc tối ưu AI.

## Demo nên kể thành câu chuyện

1. Bình thường hệ thống chạy AUTO mode.
2. Ban đêm chuyển sang NIGHT mode để cảnh báo vàng nhấp nháy.
3. Khi có xe ưu tiên, nhấn PRIORITY để mở xanh cho một hướng.
4. Khi có sự cố, nhấn EMERGENCY để toàn bộ đèn đỏ.
5. Hệ thống hiển thị trạng thái và thời gian còn lại trên LCD.

## Điểm cần làm cho bài dễ thuyết phục

- Có state machine rõ ràng thay vì chỉ delay từng đèn.
- Có bảng pin map.
- Có bảng trạng thái đèn theo từng mode.
- Có ảnh Wokwi đang chạy từng mode.
- Có video/GIF demo không quá dài, khoảng 30-60 giây.
- Có dashboard mock để đáp ứng ý "điều khiển bằng app mobile/WinForm".

## Câu giải thích khi thầy hỏi vì sao không dùng phần cứng

Do nhóm không có đủ thiết bị phần cứng, nhóm triển khai mô phỏng bằng Wokwi để kiểm thử mạch và thuật toán. Wokwi cho phép mô phỏng Arduino/ESP32, LED, nút nhấn, LCD và logic điều khiển, nên phù hợp để chứng minh nguyên lý hoạt động. Khi triển khai thực tế, chỉ cần thay các LED mô phỏng bằng module đèn thật và kết nối app qua WiFi/MQTT hoặc Serial.

