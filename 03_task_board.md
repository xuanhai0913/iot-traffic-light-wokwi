# 03. Task Board

> Bản này được rà lại theo sản phẩm nộp thực tế. Một số mục dưới đây phản ánh người hoàn thiện cuối cùng, không chỉ người được giao trong kế hoạch ban đầu.

Quy ước trạng thái:

- `[ ]`: chưa làm
- `[~]`: đang làm
- `[x]`: đã xong

## A. Quản lý dự án

| Task | Owner | Trạng thái | Ghi chú |
|---|---|---:|---|
| Tạo folder dự án trên OneDrive | Nguyễn Xuân Hải | [x] | Đã tạo |
| Chốt scope MVP | Nguyễn Xuân Hải | [x] | Đã chốt tại `10_week1_hai_deliverables.md` |
| Chốt timeline | Nguyễn Xuân Hải | [x] | Theo file 02 |
| Theo dõi tiến độ hằng ngày | Nguyễn Xuân Hải | [ ] | Cập nhật task board |
| Review tiến độ từng thành viên | Nguyễn Xuân Hải | [ ] | Nhắc deadline và tháo blocker |
| Chốt bản cuối trước khi nộp | Nguyễn Xuân Hải | [ ] | Kiểm tra report, slide, demo |

## B. Thiết kế hệ thống

| Task | Owner | Trạng thái | Ghi chú |
|---|---|---:|---|
| Vẽ sơ đồ khối | Nguyễn Xuân Hải | [x] | Đã có trong `09_so_do_thiet_ke.md` |
| Thiết kế state machine đèn | Nguyễn Xuân Hải | [x] | Đã thể hiện trong `wokwi/sketch.ino` bản nộp cuối |
| Chốt linh kiện Wokwi | Nguyễn Xuân Hải | [x] | ESP32, LED, LCD, button |
| Review sơ đồ khối và state machine | Nguyễn Xuân Hải | [x] | Sơ đồ khối đã khớp scope demo |
| Viết bảng chân kết nối | Nguyễn Xuân Hải | [x] | Đã chốt theo pin map và phần Wokwi |
| Chốt requirements CSDL/OOP/dashboard | Nguyễn Xuân Hải | [x] | Đã tạo `08_requirements.md` |
| Thiết kế ERD/database schema | Trần Đình Đức | [~] | Có hỗ trợ một phần theo `08_requirements.md`; cần ghi đúng phạm vi đóng góp |
| Thiết kế class/OOP diagram | Nguyễn Xuân Hải | [x] | Đã khớp với code OOP bản nộp cuối |

## C. Mô phỏng Wokwi

| Task | Owner | Trạng thái | Ghi chú |
|---|---|---:|---|
| Dựng mạch cơ bản 4 cụm đèn và LCD | Nguyễn Xuân Hải | [x] | Đã có `wokwi/diagram.json` bản hiện tại |
| Thêm LCD/7-seg countdown | Nguyễn Xuân Hải | [x] | Dùng LCD 16x2 I2C |
| Thêm nút chuyển chế độ | Nguyễn Xuân Hải | [x] | AUTO/NIGHT/PRIORITY/EMERGENCY |
| Lưu `diagram.json` | Nguyễn Xuân Hải | [x] | Đã lưu vào folder `wokwi/` |
| Test tích hợp code trên mạch Wokwi | Nguyễn Xuân Hải | [~] | Cần chạy Wokwi và chụp ảnh cho `#8` |

## D. Code Arduino/ESP32

| Task | Owner | Trạng thái | Ghi chú |
|---|---|---:|---|
| Code AUTO mode | Nguyễn Xuân Hải | [x] | Hoàn thiện trong `wokwi/sketch.ino` bản nộp cuối |
| Code NIGHT mode | Nguyễn Xuân Hải | [x] | Vàng nhấp nháy |
| Code PRIORITY mode | Nguyễn Xuân Hải | [x] | Ưu tiên NS/EW |
| Code EMERGENCY mode | Nguyễn Xuân Hải | [x] | Tất cả đỏ |
| Code countdown LCD | Nguyễn Xuân Hải | [x] | Hiển thị pha và số giây còn lại |
| Refactor code dễ giải thích | Nguyễn Xuân Hải | [x] | Đã tách class OOP trong bản hiện tại |
| Review code trước khi đưa vào báo cáo | Nguyễn Xuân Hải | [~] | Đã compile syntax bằng Arduino CLI; cần test runtime Wokwi |

## E. App/dashboard mô phỏng

| Task | Owner | Trạng thái | Ghi chú |
|---|---|---:|---|
| Thiết kế giao diện điều khiển PWA | Nguyễn Xuân Hải | [x] | Đã có `mobile_app/` gọi backend thật |
| Tạo màn hình AUTO/NIGHT/PRIORITY/EMERGENCY | Nguyễn Xuân Hải | [x] | PWA đã gọi API thật |
| Viết phần giải thích mở rộng app | Nguyễn Xuân Hải | [x] | Đã có `12_mobile_app_extension.md` |
| Chốt dashboard/PWA đưa vào slide | Nguyễn Xuân Hải | [~] | Cần chụp ảnh app đưa vào slide/report |

## E2. Database và OOP

| Task | Owner | Trạng thái | Ghi chú |
|---|---|---:|---|
| Vẽ ERD database | Trần Đình Đức | [~] | Có hỗ trợ phần ý tưởng ERD |
| Viết SQL schema hoặc bảng mô tả CSDL | Trần Đình Đức | [~] | Có hỗ trợ phần mô tả CSDL; schema thực tế cần ghi nhận theo source |
| Viết phần giải thích OOP trong code | Nguyễn Xuân Hải | [x] | Đã khớp với mã nguồn bản nộp cuối |
| Review CSDL/OOP có khớp demo | Nguyễn Xuân Hải | [ ] | Tránh thiết kế quá rộng |

## F. Báo cáo

| Task | Owner | Trạng thái | Ghi chú |
|---|---|---:|---|
| Viết giới thiệu đề tài | Trần Đình Đức | [~] | Có thể hỗ trợ bản nháp Word |
| Viết mục tiêu và yêu cầu | Trần Đình Đức | [~] | Có thể hỗ trợ bản nháp Word |
| Viết nguyên lý hoạt động | Trần Đình Đức | [~] | Hỗ trợ phần mô tả tài liệu |
| Chèn sơ đồ mạch Wokwi | Nguyễn Xuân Hải | [ ] | Ảnh rõ, đang chạy |
| Chèn code chính | Nguyễn Xuân Hải | [~] | Cần chọn đoạn code sát sản phẩm nộp cuối |
| Viết kết quả mô phỏng | Nguyễn Xuân Hải | [ ] | Ảnh/GIF/video |
| Rà soát format PDF | Nguyễn Xuân Hải | [ ] | Trước khi nộp |
| Review nội dung báo cáo cuối | Nguyễn Xuân Hải | [ ] | Đọc lại tính logic và thiếu sót |

## G. Slide và thuyết trình

| Task | Owner | Trạng thái | Ghi chú |
|---|---|---:|---|
| Làm slide outline | Trần Đình Đức | [~] | Có draft slide; cần cập nhật đúng mức đóng góp thực tế |
| Chèn video/GIF demo | Nguyễn Xuân Hải | [ ] | Demo rõ |
| Chia phần thuyết trình | Nguyễn Xuân Hải | [ ] | 2 người đều có phần |
| Tập nói và test demo | Cả nhóm | [ ] | Trước ngày nộp |
| Chốt slide bản cuối | Nguyễn Xuân Hải | [ ] | Kiểm tra flow thuyết trình |
