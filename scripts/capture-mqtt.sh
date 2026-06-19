#!/usr/bin/env bash
# capture-mqtt.sh — tự động gửi 5 lệnh qua API + sniff MQTT song song.
# Tạo file assets/e2e/mqtt_capture_<mode>.log cho từng lệnh.
#
# Cách dùng:
#   bash scripts/capture-mqtt.sh                    # dùng default API base
#   API_BASE=http://192.168.1.10:8000 bash scripts/capture-mqtt.sh
#
# Điều kiện:
#   - Backend C# đang chạy ở API_BASE (mặc định http://127.0.0.1:8000)
#   - Wokwi ESP32 đang chạy và subscribe traffic/.../commands
#   - Internet ra broker.hivemq.com:1883

set -euo pipefail

API_BASE="${API_BASE:-http://127.0.0.1:8000}"
INTERSECTION_ID="${INTERSECTION_ID:-1}"
TOPIC="traffic/hainx-iot-traffic-light/intersections/${INTERSECTION_ID}/commands"
SNIFF_SECONDS="${SNIFF_SECONDS:-12}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EVIDENCE_DIR="$REPO_ROOT/assets/e2e"

mkdir -p "$EVIDENCE_DIR"

# Sanity check: backend có chạy không?
if ! curl -sf -m 3 "$API_BASE/api/health" >/dev/null; then
  echo "[ERROR] Backend không phản hồi ở $API_BASE" >&2
  echo "        Hãy chạy backend trước: cd backend && dotnet run" >&2
  exit 1
fi

echo "[OK] Backend đang chạy ở $API_BASE"
echo "[OK] Sniff topic: $TOPIC"
echo "[OK] Evidence lưu tại: $EVIDENCE_DIR/"
echo ""

send_command() {
  local mode_code="$1"
  local evidence_file="$2"

  echo "─── $mode_code ───"
  echo "  [1/2] Khởi động sniff ${SNIFF_SECONDS}s, ghi vào $(basename "$evidence_file")"

  # Chạy sniff ở background, đợi 1s cho sniff subscribe xong
  python3 "$SCRIPT_DIR/mqtt-sniff.py" \
    --broker broker.hivemq.com \
    --port 1883 \
    --topic "$TOPIC" \
    --seconds "$SNIFF_SECONDS" \
    > "$evidence_file" 2>&1 &
  local sniff_pid=$!
  sleep 2

  echo "  [2/2] Gửi $mode_code qua API"
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "{\"command\":\"SET_${mode_code}\",\"source\":\"capture-script\",\"createdBy\":\"e2e-capture\"}" \
    "$API_BASE/api/intersections/${INTERSECTION_ID}/commands")

  if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
    echo "        HTTP $http_code ✓"
  else
    echo "        HTTP $http_code ✗ (xem $evidence_file để debug)"
  fi

  # Đợi sniff xong
  wait "$sniff_pid" 2>/dev/null || true

  # Đếm số message nhận được
  local count
  count=$(grep -c "topic=$TOPIC" "$evidence_file" 2>/dev/null || echo "0")
  echo "        Sniff nhận: $count message(s) trên $TOPIC"
  echo ""
}

# 5 mode theo thứ tự báo cáo E2E
send_command "AUTO"        "$EVIDENCE_DIR/mqtt_capture_auto.log"
send_command "NIGHT"       "$EVIDENCE_DIR/mqtt_capture_night.log"
send_command "PRIORITY_NS" "$EVIDENCE_DIR/mqtt_capture_priority.log"
send_command "PRIORITY_EW" "$EVIDENCE_DIR/mqtt_capture_priority_ew.log"
send_command "EMERGENCY"   "$EVIDENCE_DIR/mqtt_capture_emergency.log"

echo "─── Tổng kết ───"
echo "Đã ghi:"
ls -1 "$EVIDENCE_DIR"/mqtt_capture_*.log
echo ""
echo "Tổng số SET_* message (1 mode nên xuất hiện 1 lần trong file tương ứng):"
grep -h "command" "$EVIDENCE_DIR"/mqtt_capture_*.log | grep -oE 'SET_[A-Z_]+' | sort -u
