# Bằng chứng kiểm thử E2E

> Thư mục này chứa ảnh chụp màn hình và log MQTT capture cho `docs/report/e2e_test_results.md`.
> Tất cả tên file đã được tham chiếu trong báo cáo; chỉ cần đặt đúng tên là báo cáo tự "nhặt" được.

## Cấu trúc file cần có

| File | Test case | Nội dung mong đợi |
|------|-----------|-------------------|
| `tc01_health.png` | TC-01 | Terminal/Postman hiện `GET /api/health` trả `200 ok` |
| `tc02_auto_connect.png` | TC-02 | Flutter Dashboard nhãn `Đã kết nối http://127.0.0.1:8000` + SnackBar xanh |
| `tc04_auto_result.png` | TC-04 | Hộp thoại kết quả `Command accepted: SET_AUTO` |
| `tc05_night_result.png` | TC-05 | Hộp thoại `SET_NIGHT` |
| `tc06_priority_ns_confirm.png` | TC-06 | Hộp thoại xác nhận `Risk level: Risky` + nút `Send anyway` |
| `tc07_priority_ns_result.png` | TC-07 | Hộp thoại kết quả sau khi tap `Send anyway` |
| `tc08_priority_ew_confirm.png` | TC-08 | Hộp thoại xác nhận PRIORITY_EW |
| `tc09_emergency_confirm.png` | TC-09 | Hộp thoại `Risk level: Critical` + mô tả `flashing red` |
| `tc10_success_snackbar.png` | TC-10 | SnackBar xanh dưới đáy màn hình |
| `tc11_error_snackbar.png` | TC-11 | SnackBar đỏ khi backend ngắt |
| `tc12_wokwi_serial.png` | TC-12 | Wokwi Serial Monitor in `MQTT msg: SET_*` |
| `tc13_wokwi_acks.png` | TC-13 | Wokwi in `Publishing acks: ...` |
| `tc14_vietnamese_ui.png` | TC-14 | UI hiện `Mất kết nối backend`, `Tải lại`, `Bắc - Nam`... |
| `tc15_api_base_settings.png` | TC-15 | Tab Settings, ô `API base URL` |
| `tc16_skip_confirm.png` | TC-16 | Toggle `Confirm risky commands` |
| `tc17_phase_config.png` | TC-17 | Thanh trượt `Xanh` / `Vàng` |
| `tc18_phase_activate.png` | TC-18 | Bảng phase plan, nút `Activate` |
| `tc19_approach_toggle.png` | TC-19 | Danh sách `Tuyến đường`, nút bật/tắt |
| `tc20_history_tab.png` | TC-20 | Tab `History` liệt kê lệnh đã gửi |
| `tc21_logs_tab.png` | TC-21 | Tab `Device logs` |
| `mqtt_capture_auto.log` | TC-04 | Sniff thấy `SET_AUTO` trên `.../commands` |
| `mqtt_capture_priority.log` | TC-06/07 | Sniff thấy `SET_PRIORITY_NS` |
| `mqtt_capture_emergency.log` | TC-09 | Sniff thấy `SET_EMERGENCY` |
| `mqtt_capture_acks.log` | TC-13 | Sniff thấy `.../acks` về từ Wokwi |

## Quy trình chụp ảnh (gợi ý)

1. Mở Chrome DevTools, bật chế độ "Capture full size screenshot" hoặc dùng extension như Fireshot.
2. Chụp trực tiếp cửa sổ Chrome (không cần toàn trang) cho gọn.
3. Đặt tên đúng theo bảng trên.
4. Copy file vào thư mục `docs/evidence/e2e/`.

## Quy trình capture MQTT

Mở terminal (Windows PowerShell hoặc WSL bash) **trước khi** gửi lệnh, rồi chạy:

```bash
python3 scripts/mqtt-sniff.py --seconds 60 \
  > docs/evidence/e2e/mqtt_capture_live.log 2>&1
```

Trong 60 giây đó, lần lượt bấm 5 nút chế độ (AUTO, NIGHT, PRIORITY NS, PRIORITY EW, EMERGENCY) trên Flutter.
Sau khi sniff kết thúc, kiểm tra log phải có ≥ 5 message `SET_*` trên topic `.../commands`.

Để capture riêng từng mode (file `.log` riêng theo bảng), chạy sniff ngay trước khi bấm nút tương ứng, ví dụ:

```bash
python3 scripts/mqtt-sniff.py --seconds 10 \
  --topic traffic/hainx-iot-traffic-light/intersections/1/commands \
  > docs/evidence/e2e/mqtt_capture_auto.log 2>&1 &
# ... trong 10s này bấm nút AUTO
```

## Lệnh kiểm tra nhanh

```bash
# Liệt kê file PNG đã có
ls -la docs/evidence/e2e/*.png

# Đếm số lệnh SET_* trong mọi log
grep -h "SET_" docs/evidence/e2e/mqtt_capture_*.log | sort -u
```
