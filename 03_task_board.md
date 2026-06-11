# 03. Task Board

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
| Thiết kế state machine đèn | Trần Đình Đức | [ ] | AUTO, NIGHT, PRIORITY, EMERGENCY |
| Chốt linh kiện Wokwi | Nguyễn Xuân Hải | [x] | ESP32, LED, LCD, button |
| Review sơ đồ khối và state machine | Nguyễn Xuân Hải | [x] | Sơ đồ khối đã khớp scope demo |
| Viết bảng chân kết nối | Trần Đình Đức | [ ] | Pin map cho báo cáo |
| Chốt requirements CSDL/OOP/dashboard | Nguyễn Xuân Hải | [x] | Đã tạo `08_requirements.md` |
| Thiết kế ERD/database schema | Trần Đình Đức | [ ] | Dựa theo `08_requirements.md` |
| Thiết kế class/OOP diagram | Trần Đình Đức | [ ] | TrafficLight, TrafficPhase, Controller |

## C. Mô phỏng Wokwi

| Task | Owner | Trạng thái | Ghi chú |
|---|---|---:|---|
| Dựng mạch cơ bản 6 LED | Nguyễn Xuân Hải | [ ] | 2 hướng, mỗi hướng 3 LED |
| Thêm LCD/7-seg countdown | Nguyễn Xuân Hải | [ ] | Ưu tiên LCD I2C |
| Thêm nút chuyển chế độ | Nguyễn Xuân Hải | [ ] | AUTO/NIGHT/PRIORITY/EMERGENCY |
| Lưu `diagram.json` | Nguyễn Xuân Hải | [ ] | Đưa vào folder `wokwi/` |
| Test tích hợp code trên mạch Wokwi | Nguyễn Xuân Hải | [ ] | Chạy đủ 4 chế độ |

## D. Code Arduino/ESP32

| Task | Owner | Trạng thái | Ghi chú |
|---|---|---:|---|
| Code AUTO mode | Trần Đình Đức | [ ] | Chạy 2 hướng theo chu kỳ |
| Code NIGHT mode | Trần Đình Đức | [ ] | Vàng nhấp nháy |
| Code PRIORITY mode | Trần Đình Đức | [ ] | Ưu tiên một hướng |
| Code EMERGENCY mode | Trần Đình Đức | [ ] | Tất cả đỏ |
| Code countdown LCD | Trần Đình Đức | [ ] | Hiển thị pha và số giây còn lại |
| Refactor code dễ giải thích | Trần Đình Đức | [ ] | Tách hàm rõ ràng |
| Review code trước khi đưa vào báo cáo | Nguyễn Xuân Hải | [ ] | Kiểm tra compile và tên hàm |

## E. App/dashboard mô phỏng

| Task | Owner | Trạng thái | Ghi chú |
|---|---|---:|---|
| Thiết kế giao diện điều khiển mock | Nguyễn Xuân Hải | [ ] | Mobile/web style |
| Tạo màn hình AUTO/NIGHT/PRIORITY/EMERGENCY | Nguyễn Xuân Hải | [ ] | Có thể dùng HTML hoặc slide mock |
| Viết phần giải thích mở rộng app | Nguyễn Xuân Hải | [ ] | App/WinForm gửi lệnh đến ESP32 |
| Chốt dashboard mock đưa vào slide | Nguyễn Xuân Hải | [ ] | Không để app mock lệch scope |

## E2. Database và OOP

| Task | Owner | Trạng thái | Ghi chú |
|---|---|---:|---|
| Vẽ ERD database | Trần Đình Đức | [ ] | intersections, modes, configs, commands, logs |
| Viết SQL schema hoặc bảng mô tả CSDL | Trần Đình Đức | [ ] | Có thể dùng SQLite/JSON mock |
| Viết phần giải thích OOP trong code | Trần Đình Đức | [ ] | Class, trách nhiệm, luồng gọi |
| Review CSDL/OOP có khớp demo | Nguyễn Xuân Hải | [ ] | Tránh thiết kế quá rộng |

## F. Báo cáo

| Task | Owner | Trạng thái | Ghi chú |
|---|---|---:|---|
| Viết giới thiệu đề tài | Trần Đình Đức | [ ] | 1-2 trang |
| Viết mục tiêu và yêu cầu | Trần Đình Đức | [ ] | Bám đề bài |
| Viết nguyên lý hoạt động | Trần Đình Đức | [ ] | State machine |
| Chèn sơ đồ mạch Wokwi | Nguyễn Xuân Hải | [ ] | Ảnh rõ, đang chạy |
| Chèn code chính | Trần Đình Đức | [ ] | Có giải thích |
| Viết kết quả mô phỏng | Nguyễn Xuân Hải | [ ] | Ảnh/GIF/video |
| Rà soát format PDF | Nguyễn Xuân Hải | [ ] | Trước khi nộp |
| Review nội dung báo cáo cuối | Nguyễn Xuân Hải | [ ] | Đọc lại tính logic và thiếu sót |

## G. Slide và thuyết trình

| Task | Owner | Trạng thái | Ghi chú |
|---|---|---:|---|
| Làm slide outline | Trần Đình Đức | [ ] | 8-10 slide |
| Chèn video/GIF demo | Nguyễn Xuân Hải | [ ] | Demo rõ |
| Chia phần thuyết trình | Nguyễn Xuân Hải | [ ] | 2 người đều có phần |
| Tập nói và test demo | Cả nhóm | [ ] | Trước ngày nộp |
| Chốt slide bản cuối | Nguyễn Xuân Hải | [ ] | Kiểm tra flow thuyết trình |
