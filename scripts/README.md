# Scripts

## E2E screenshots

The screenshot capture scripts expect the Flutter web app and proxy to be available at `http://localhost:8080`.

```powershell
npm install --save-dev playwright
cd flutter_app
..\.flutter\bin\flutter.bat build web
cd ..
python .\scripts\proxy_server.py
node .\scripts\capture-full.js
```

Run `proxy_server.py` and the capture script in separate terminals. Use `APP_URL` to target another server and `E2E_OUT_DIR` to change the screenshot output directory.
