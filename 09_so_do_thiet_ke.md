# 09. Sơ Đồ Thiết Kế Dự Án

## ERD có phù hợp dự án không?

Có, ERD phù hợp với hệ thống IoT Traffic Light mở rộng theo hướng có bảng điều khiển web / ứng dụng di động và cơ sở dữ liệu quản lý.

Phần mô phỏng Wokwi có thể hoạt động độc lập, tuy nhiên cơ sở dữ liệu giúp hệ thống có chiều sâu hơn:

- Lưu cấu hình thời gian các pha đèn.
- Lưu chế độ hoạt động của hệ thống.
- Lưu lịch sử lệnh điều khiển.
- Lưu log trạng thái đèn theo thời gian.
- Hỗ trợ mở rộng backend/API thực tế.

Mô hình triển khai:

- ESP32/Wokwi: mô phỏng thiết bị.
- Máy chủ: xử lý lệnh.
- Cơ sở dữ liệu: lưu dữ liệu quản lý.

---

# Danh sách sơ đồ trong báo cáo

| Sơ đồ | Đưa vào report | Mục đích |
|-|-|-|
| Kiến trúc hệ thống | Có | Mô tả các thành phần IoT |
| ERD Database | Có | Thiết kế cơ sở dữ liệu |
| State Machine | Có | Thuật toán điều khiển đèn |
| Class Diagram | Có | Thể hiện lập trình hướng đối tượng |
| Sequence Diagram | Có | Mô tả luồng gửi lệnh |

---

# 1. Sơ đồ kiến trúc tổng thể

```mermaid
flowchart TD

NguoiVanHanh["Người vận hành"]
QuanTri["Người quản trị"]

BangDieuKhien["Bảng điều khiển Web / Ứng dụng di động"]

MayChu["Máy chủ API"]

CoSoDuLieu[("Cơ sở dữ liệu SQLite")]

MQTT["MQTT Gateway"]

ESP32["ESP32 Controller"]

Wokwi["Mô phỏng Wokwi"]

DenGiaoThong["Đèn giao thông"]

LCD["LCD Countdown"]

NutBam["Nút bấm"]


NguoiVanHanh --> BangDieuKhien
QuanTri --> BangDieuKhien

BangDieuKhien --> MayChu

MayChu --> CoSoDuLieu

MayChu --> MQTT

MQTT --> ESP32

ESP32 --> DenGiaoThong
ESP32 --> LCD

NutBam --> ESP32

ESP32 --> Wokwi
```

---

# 2. ERD / Database Schema

```mermaid
erDiagram


GIAO_LO ||--o{ CAU_HINH_PHA_DEN : co

GIAO_LO ||--o{ LENH_DIEU_KHIEN : nhan

GIAO_LO ||--o{ NHAT_KY_SU_KIEN : luu


CHE_DO_GIAO_THONG ||--o{ CAU_HINH_PHA_DEN : cau_hinh

CHE_DO_GIAO_THONG ||--o{ LENH_DIEU_KHIEN : su_dung

CHE_DO_GIAO_THONG ||--o{ NHAT_KY_SU_KIEN : ghi_nhan



GIAO_LO {

int id PK

string ten

string vi_tri

string trang_thai

datetime thoi_gian_tao

}



CHE_DO_GIAO_THONG {

int id PK

string ma_che_do UK

string ten

string mo_ta

}



CAU_HINH_PHA_DEN {

int id PK

int giao_lo_id FK

string ma_che_do FK

string huong

int thoi_gian_xanh

int thoi_gian_vang

int thoi_gian_do

boolean dang_hoat_dong

}



LENH_DIEU_KHIEN {

int id PK

int giao_lo_id FK

string lenh

string nguon

string nguoi_tao

datetime thoi_gian_tao

}



NHAT_KY_SU_KIEN {

int id PK

int giao_lo_id FK

string ma_che_do

string den_bac_nam

string den_dong_tay

int thoi_gian_con_lai

datetime thoi_gian_tao

}


```

---

# Giải thích database

## giao_lo

Lưu thông tin giao lộ.

Ví dụ:

- tên giao lộ
- vị trí
- trạng thái hiện tại


## che_do_giao_thong

Lưu các chế độ:

- AUTO
- NIGHT
- PRIORITY
- EMERGENCY


## cau_hinh_pha_den

Lưu cấu hình thời gian đèn:

- xanh
- vàng
- đỏ


## lenh_dieu_khien

Lưu các lệnh từ:

- bảng điều khiển
- ứng dụng di động


## nhat_ky_su_kien

Lưu lịch sử hoạt động:

- trạng thái đèn
- countdown
- thời gian xảy ra

---

# 3. State Machine điều khiển đèn

## State Diagram

```mermaid
stateDiagram-v2

[*] --> AUTO_NS_GREEN


AUTO_NS_GREEN --> AUTO_NS_YELLOW: hết thời gian xanh Bắc-Nam
AUTO_NS_YELLOW --> AUTO_EW_GREEN: hết thời gian vàng Bắc-Nam
AUTO_EW_GREEN --> AUTO_EW_YELLOW: hết thời gian xanh Đông-Tây
AUTO_EW_YELLOW --> AUTO_NS_GREEN: hết thời gian vàng Đông-Tây


AUTO_NS_GREEN --> NIGHT: lệnh NIGHT
AUTO_NS_YELLOW --> NIGHT: lệnh NIGHT
AUTO_EW_GREEN --> NIGHT: lệnh NIGHT
AUTO_EW_YELLOW --> NIGHT: lệnh NIGHT


NIGHT --> AUTO_NS_GREEN: lệnh AUTO
NIGHT --> NIGHT: vàng nhấp nháy


AUTO_NS_GREEN --> PRIORITY_NS: lệnh PRIORITY_NS
AUTO_EW_GREEN --> PRIORITY_EW: lệnh PRIORITY_EW

PRIORITY_NS --> AUTO_NS_GREEN: lệnh AUTO
PRIORITY_EW --> AUTO_NS_GREEN: lệnh AUTO


AUTO_NS_GREEN --> EMERGENCY: lệnh EMERGENCY
AUTO_EW_GREEN --> EMERGENCY: lệnh EMERGENCY
NIGHT --> EMERGENCY: lệnh EMERGENCY
PRIORITY_NS --> EMERGENCY: lệnh EMERGENCY
PRIORITY_EW --> EMERGENCY: lệnh EMERGENCY

EMERGENCY --> AUTO_NS_GREEN: lệnh AUTO
```

---

# Pseudo Code điều khiển

```text
START

while hệ thống đang chạy:

    đọc chế độ hiện tại

    nếu chế độ == EMERGENCY:

        bật tất cả đèn đỏ


    ngược lại nếu chế độ == PRIORITY:

        cho hướng ưu tiên đèn xanh


    ngược lại nếu chế độ == NIGHT:

        nhấp nháy đèn vàng


    ngược lại:

        chạy chu trình AUTO


END
```

---

# 4. Class Diagram / OOP

```mermaid
classDiagram


class DenGiaoThong {

-int chanDo

-int chanVang

-int chanXanh

+batDau()

+batDo()

+batVang()

+batXanh()

}



class PhaTinHieu {

+String ten

+String bacNam

+String dongTay

+int thoiGian

}



class QuanLyCheDo {

-String cheDoHienTai

+datCheDo()

+layCheDo()

+kiemTraKhanCap()

+kiemTraBanDem()

}



class QuanLyHienThi {

+hienThiCheDo()

+hienThiDemNguoc()

+hienThiTrangThai()

}



class BoDieuKhienGiaoLo {

+batDau()

+capNhat()

+chayTuDong()

+chayBanDem()

+chayUuTien()

+chayKhanCap()

}



BoDieuKhienGiaoLo --> DenGiaoThong

BoDieuKhienGiaoLo --> PhaTinHieu

BoDieuKhienGiaoLo --> QuanLyCheDo

BoDieuKhienGiaoLo --> QuanLyHienThi


```

---

# 5. Sequence Flow điều khiển

```mermaid
sequenceDiagram

actor NguoiDung

participant BangDieuKhien

participant MayChu

participant CoSoDuLieu

participant ESP32

participant Wokwi


NguoiDung->>BangDieuKhien:
chọn chế độ


BangDieuKhien->>MayChu:
gửi lệnh


MayChu->>CoSoDuLieu:
lưu lệnh


MayChu->>ESP32:
gửi command


ESP32->>Wokwi:
đổi trạng thái LED


ESP32->>MayChu:
gửi trạng thái


MayChu->>CoSoDuLieu:
lưu log


MayChu->>BangDieuKhien:
trả trạng thái


```

---

# 6. Mobile App Command Flow

```mermaid
sequenceDiagram

actor NguoiVanHanh

participant UngDung

participant MayChu

participant MQTT

participant ESP32

participant Den


NguoiVanHanh->>UngDung:
chọn AUTO/NIGHT/PRIORITY/EMERGENCY


UngDung->>MayChu:
POST command


MayChu->>MQTT:
publish message


MQTT->>ESP32:
receive command


ESP32->>Den:
update LED


ESP32->>MQTT:
publish status


MQTT->>MayChu:
status event


MayChu->>UngDung:
update display


```

---

# 7. Data Flow

```mermaid
flowchart LR

Input["Nút bấm / Lệnh từ Dashboard"]

KiemTra["Kiểm tra lệnh"]

CheDo["Cập nhật chế độ"]

DieuKhien["Điều khiển LED"]

LuuLog["Lưu nhật ký"]

Output["LCD / Dashboard"]


Input --> KiemTra

KiemTra --> CheDo

CheDo --> DieuKhien

DieuKhien --> LuuLog

DieuKhien --> Output


```

---

# Diagram Images

Sau khi export Mermaid:

```
assets/diagrams/erd.png

assets/diagrams/state_machine.png
```

Dùng cho report và slide.

---

# Cách dùng trong báo cáo

- Kiến trúc hệ thống: phần tổng quan.
- ERD: phần thiết kế database.
- State machine: phần thuật toán.
- Class diagram: phần OOP.
- Sequence: phần IoT communication.