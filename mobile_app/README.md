# Mobile App PWA

Day la mobile web/PWA dung de van hanh MVP. Ban hien tai goi backend C# ASP.NET Core tai `http://127.0.0.1:8000`.

## Cach chay

1. Chay backend:

```powershell
cd backend
dotnet run
```

2. Chay static server tu thu muc repo:

```powershell
python -m http.server 4173
```

3. Mo app:

```text
http://localhost:4173/mobile_app/
```

## Chuc nang da co

- Doc trang thai den, mode, phase va countdown tu API.
- Gui lenh `AUTO`, `NIGHT`, `PRIORITY_NS`, `PRIORITY_EW`, `EMERGENCY`.
- Cap nhat thoi gian xanh/vang vao SQLite thong qua API.
- Xem lich su command tu backend.
- Xem, them va bat/tat road approaches trong mot giao lo.
- Xem dashboard truc quan gom metrics, 4 huong signal, signal heads, phase plan, mode priority va event logs.
- Doi backend URL truc tiep trong o `Backend API URL`; app luu gia tri vao `localStorage`.

## Ghi chu

Wokwi/ESP32 van chay doc lap bang button/Serial trong Muc 1-2. Backend va app dung cung command workflow de demo lop van hanh va database; ban nang cao co the noi ESP32 voi backend bang MQTT.
