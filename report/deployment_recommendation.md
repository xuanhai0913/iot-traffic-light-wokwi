# Deployment Recommendation

## De xuat deploy free cho demo

| Thanh phan | Nen deploy o dau | Ly do |
|---|---|---|
| Wokwi simulation | Wokwi share link | Dung dung muc dich mo phong ESP32/Arduino |
| PWA mobile app | Vercel hoac Netlify | Static site, free tier, deploy nhanh |
| C# backend API | Render Web Service Free | Ho tro Docker/web service, phu hop demo API |
| Database demo | SQLite seed tu backend | Don gian cho bai tap lon |

## Luu y ve SQLite tren hosting free

SQLite phu hop local demo. Tren Render Free, filesystem co the bi reset khi redeploy/restart/spin down. Vi vay:

- Demo van on vi backend tu tao schema va seed data.
- Khong nen xem SQLite local la production database khi deploy free.
- Neu can luu data ben vung, nen doi sang Postgres.

## Bien moi truong nen them khi deploy

PWA mac dinh dung local backend:

```js
const DEFAULT_API_BASE = "http://127.0.0.1:8000";
```

Khi deploy production, co 2 cach dung URL backend Render:

1. Nhap URL Render truc tiep trong o `Backend API URL` tren PWA. App se luu vao `localStorage`.
2. Hoac sua `DEFAULT_API_BASE` trong `mobile_app/app.js`, vi du `https://traffic-light-api.onrender.com`.

## Huong deploy de xuat

1. Tao Wokwi project va share link.
2. Deploy backend C# len Render bang Docker hoac native build.
3. Deploy `mobile_app/` len Vercel/Netlify.
4. Nhap URL Render vao o `Backend API URL` tren PWA, hoac doi `DEFAULT_API_BASE` trong `mobile_app/app.js`.
5. Test:
   - `/api/health`
   - PWA online
   - Gui command
   - Xem history/log
