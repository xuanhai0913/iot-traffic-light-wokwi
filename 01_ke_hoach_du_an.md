# 01. Kế Hoạch Dự Án

> File này bắt đầu từ kế hoạch MVP ban đầu, nhưng đã được cập nhật lại để phản ánh mức triển khai hiện tại của repository.

## Tên đề tài

Hệ thống mô phỏng điều khiển đèn giao thông thông minh tại một giao lộ.

## Bối cảnh

Nhóm không có phần cứng thật, vì vậy dự án ưu tiên mô phỏng đầy đủ trên Wokwi. Ở trạng thái hiện tại, repo không chỉ có mô phỏng Wokwi mà còn có backend C# ASP.NET Core, SQLite, MQTT bridge, Flutter app và PWA để thể hiện đầy đủ lớp vận hành IoT.

Một điểm quan trọng khi làm bài lớn là nên thể hiện được nhiều kiến thức đã học trong môn và các học phần liên quan. Vì vậy ngoài mô phỏng Wokwi, bản hiện tại còn triển khai thật phần thiết kế CSDL, database lưu lịch sử điều khiển, OOP trong firmware, backend/API, Flutter/PWA và luồng MQTT end-to-end.

## Phạm vi MVP

MVP là bản tối thiểu phải hoàn thành để nộp được:

- Mô phỏng một giao lộ gồm 2 trục điều khiển Bắc-Nam và Đông-Tây, hiển thị thành 4 cụm NORTH/SOUTH/EAST/WEST.
- Mỗi cụm có 3 đèn: đỏ, vàng, xanh.
- Có đếm ngược thời gian pha đèn bằng LCD 16x2 hoặc 7-segment.
- Chế độ tự động:
  - Mặc định Bắc-Nam xanh 8 giây.
  - Bắc-Nam vàng 3 giây.
  - Đông-Tây xanh 8 giây.
  - Đông-Tây vàng 3 giây.
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
- Database/ERD: đã triển khai bằng SQLite để lưu lịch sử lệnh, phase plan, approaches, signal heads, device status và log.
- App/mobile: đã có mobile web/PWA và Flutter app source gọi backend C#; luồng điều khiển dùng HTTP + MQTT.
- Backend/API: đã có ASP.NET Core 8 Minimal API và MQTT bridge.

## Phạm vi mở rộng

Chỉ làm nếu MVP đã ổn:

- Đồng bộ phase duration backend -> firmware bằng command cấu hình hoàn chỉnh và xác nhận áp dụng.
- Thêm all-red clearance và safety interlock có thời lượng.
- Thêm auth, giới hạn CORS và bảo mật MQTT production-grade.
- Thêm cảm biến giả lập xe chờ hoặc AI/camera nếu còn thời gian.

## Không làm trong bản chính

- Không làm xe thật, cảm biến thật, module thật.
- Không làm production deployment hoặc safety model ngoài thực tế.
- Không làm nhiều giao lộ.
- Không làm thuật toán tối ưu giao thông nâng cao nếu chưa xong MVP.

## Linh kiện mô phỏng dự kiến

- ESP32 DevKit.
- 12 LED cho 4 cụm đèn xe NORTH/SOUTH/EAST/WEST.
- 4 LED cho đèn người đi bộ.
- 16 điện trở 220Ω.
- LCD 16x2 I2C để hiển thị trạng thái và countdown.
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
