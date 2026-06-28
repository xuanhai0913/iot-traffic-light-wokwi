# 04. Phân Công Và Mức Độ Hoàn Thành Thực Tế

> Tài liệu này ghi theo sản phẩm nộp thực tế trong repository, tài liệu trong workspace và artifact demo đang có. Mục tiêu là ghi nhận đúng phần việc đã bàn giao, tách khỏi phân công dự kiến ban đầu.

## Thành viên nhóm

| Thành viên | Phần phụ trách chính theo sản phẩm nộp | Ghi nhận mức độ đóng góp |
|---|---|---|
| Nguyễn Xuân Hải | Nhóm trưởng, chốt scope, thiết kế hệ thống, Wokwi, code điều khiển, backend C#, Flutter/PWA, kiểm thử, demo, tích hợp bản nộp | Phần implementation và tích hợp chính của dự án |
| Trần Đình Đức | Database/ERD, hỗ trợ nội dung report Word, slide thuyết trình | Hỗ trợ một phần ở mảng CSDL và tài liệu; không phải phần implementation chính |

## Nguyễn Xuân Hải

Vai trò thực tế: nhóm trưởng và người thực hiện phần lớn khối lượng kỹ thuật của bản nộp cuối.

### Phần việc ghi nhận thực tế

- Chốt scope MVP, cấu trúc thư mục, timeline và hướng triển khai.
- Quản lý folder OneDrive, GitHub repo, issue flow và tiến độ.
- Thiết kế sơ đồ tổng thể, pin map, kiến trúc app -> API -> MQTT -> ESP32/Wokwi.
- Dựng và hoàn thiện mạch Wokwi, tích hợp LCD, nút nhấn, sơ đồ chân và ảnh chụp mô phỏng.
- Thực hiện và hoàn thiện code điều khiển đèn, state machine, mode AUTO/NIGHT/PRIORITY/EMERGENCY, countdown và OOP trong `wokwi/sketch.ino`.
- Thực hiện backend C# ASP.NET Core, SQLite schema thực tế, MQTT bridge và integration tests.
- Thực hiện Flutter app, PWA, script verify/build/demo và các tài liệu kỹ thuật chính.
- Kiểm thử, chụp evidence, rà báo cáo/slide và tích hợp bản nộp cuối.

### Deliverable thực tế

- Repo dự án hoàn chỉnh.
- Firmware `wokwi/sketch.ino`, `diagram.json` và assets mô phỏng.
- Backend `backend/` với API, SQLite, MQTT và test.
- Flutter app `flutter_app/` và PWA `mobile_app/`.
- Tài liệu kỹ thuật, checklist demo, script build/test và cấu trúc bản nộp cuối.

## Trần Đình Đức

Vai trò thực tế: hỗ trợ phần CSDL/ERD và một phần tài liệu trình bày.

### Phần việc ghi nhận thực tế

- Hỗ trợ phần database/ERD theo hướng yêu cầu trong `08_requirements.md`.
- Hỗ trợ một phần nội dung report Word và slide thuyết trình.
- Phối hợp theo phân công ban đầu ở các hạng mục tài liệu.

### Ghi chú phạm vi đóng góp

- Ở trạng thái repository hiện tại, không ghi nhận đầy đủ bằng chứng độc lập cho việc Trần Đình Đức thực hiện các hạng mục implementation chính như Wokwi, firmware, backend C#, Flutter app, test và tích hợp demo cuối.
- Vì vậy các phần kỹ thuật lõi của bản nộp không nên ghi nhận là do Trần Đình Đức thực hiện chính.

### Deliverable ghi nhận

- Một phần nội dung CSDL/ERD.
- Một phần nội dung Word/PPT phục vụ thuyết trình.

## Bản ngắn để đưa vào report hoặc slide

| Thành viên | Đóng góp thực tế |
|---|---|
| Nguyễn Xuân Hải | Thực hiện phần chính của dự án: scope, kiến trúc hệ thống, Wokwi, code điều khiển, backend C#, Flutter/PWA, kiểm thử, demo và tích hợp bản nộp cuối |
| Trần Đình Đức | Hỗ trợ phần database/ERD và một phần nội dung report Word, slide thuyết trình |

## Phân chia phần thuyết trình nên dùng

| Người | Nội dung nói | Thời lượng gợi ý |
|---|---|---:|
| Nguyễn Xuân Hải | Giới thiệu đề tài, scope, kiến trúc hệ thống, Wokwi, code điều khiển, backend/app, demo và kết quả | 7-9 phút |
| Trần Đình Đức | Database/ERD và phần tổng hợp tài liệu, slide | 2-4 phút |

## Cách trình bày với giáo viên

Không nên dùng các từ cảm tính như "lười", "không làm gì". Nên trình bày theo mẫu:

> Nhóm có phân công ban đầu cho cả hai thành viên. Tuy nhiên khi hoàn thiện sản phẩm nộp thực tế, phần lớn implementation và tích hợp cuối do Nguyễn Xuân Hải thực hiện; Trần Đình Đức hỗ trợ chủ yếu ở phần CSDL/ERD và tài liệu trình bày. Bảng này ghi theo sản phẩm đã bàn giao, không chỉ theo kế hoạch phân công ban đầu.
