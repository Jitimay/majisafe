# Deploy MajiSafe Backend to Andasy

## 1. Install CLI
```bash
curl -fsSL https://andasy.io/install.sh | bash
source ~/.bashrc
```

## 2. Login
```bash
andasy login
```

## 3. Init app (run from backend/ folder)
```bash
cd backend
andasy init
# App name: majisafe-backend
# Check andasy.hcl — port must be 3000
```

## 4. Create persistent volume for SQLite
```bash
andasy volumes create -a majisafe-backend -s 5 majisafe-data
```

## 5. Set secrets
```bash
andasy secrets set JWT_SECRET=81626d33dc0a199c68457aa3b7a8feea0ad03da25c845b269a5a78a4a80c3178 -a majisafe-backend
andasy secrets set JWT_REFRESH_SECRET=abedb5f66ac7143aa7caa9784475da78ba44ddc1b5f975df0f34f463f4e6262d -a majisafe-backend
andasy secrets set STATION_DEFAULT_SECRET=station_shared_secret_change_me -a majisafe-backend
andasy secrets set ADMIN_PHONE=25761000000 -a majisafe-backend
andasy secrets set SMS_WEBHOOK_SECRET=6ac49bf8d2bf3a6749b0ff10d6ffcd4f799ae7f940791060 -a majisafe-backend
andasy secrets set COIN_PRICE_BIF=10 -a majisafe-backend
andasy secrets set DB_PATH=/data/majisafe.db -a majisafe-backend
andasy secrets set PORT=3000 -a majisafe-backend
andasy secrets set HOST=0.0.0.0 -a majisafe-backend
andasy secrets set DISPATCH_HTTP_TIMEOUT_MS=10000 -a majisafe-backend
```

## 6. Deploy (Kigali region)
```bash
ANDASY_REGION=kgl andasy deploy
```

## 7. Test
```bash
curl https://majisafe-backend.andasy.dev/health
# {"success":true,"service":"majisafe-backend"}
```

## 8. View logs
```bash
andasy logs -a majisafe-backend
```

## 9. SSH for debugging
```bash
andasy ssh shell -a majisafe-backend
```

## After deploying — update Flutter app
```bash
cd majisafe_app
flutter run --dart-define=API_BASE_URL=https://majisafe-backend.andasy.dev
```

## Update firmware config.h
```cpp
#define MAJISAFE_SERVER_HOST "majisafe-backend.andasy.dev"
#define MAJISAFE_SERVER_PORT 80
```
Note: SIM800L uses plain HTTP — Andasy serves HTTP on port 80 by default.
