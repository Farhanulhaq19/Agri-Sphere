# AgriSphere — Going Online

You get one public API URL (e.g. `https://agrisphere-api.onrender.com`) that the Android app and the web app both use.
Total time: about 30 minutes. Everything below is free-tier.

---

## 1. Database: MongoDB Atlas

1. Sign in at **mongodb.com/atlas** → *Create* → **M0 Free** cluster (region close to Pakistan, e.g. Mumbai / Bahrain).
2. *Database Access* → **Add user** (username + strong password).
3. *Network Access* → **Add IP** → `0.0.0.0/0` (Render's IPs change).
4. *Connect* → *Drivers* → copy the connection string and put your password in it:
   `mongodb+srv://USER:PASSWORD@cluster0.xxxxx.mongodb.net/agrisphere`

## 2. API: Render

1. Push this project to GitHub (the repo must contain `render.yaml`).
2. **render.com** → *New* → **Blueprint** → choose the repository.
3. Fill in the values it asks for:

| Variable | Value |
|---|---|
| `MONGO_URI` | the Atlas string from step 1 |
| `ANTHROPIC_API_KEY` | your key from console.anthropic.com (AgriChatBot + Crop Doctor) |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | full contents of the Firebase service-account JSON (step 4) |
| `ADMIN_EMAILS` | your admin email(s), comma separated |
| `EMAIL_USER` / `EMAIL_PASS` | optional, for real OTP emails (Gmail app password) |

`JWT_SECRET` is generated automatically.

4. Wait for **Live**, then open `https://YOUR-SERVICE.onrender.com/api/health`. It should show `"db":"connected"`.
5. Load demo data once: Render → your service → **Shell** → `npm run seed:demo`.

> **Good to know:** the free plan sleeps after 15 minutes idle; the first request then takes ~30 s.
> Open the health link a minute before your demo. Uploaded photos are lost on redeploy unless you add a
> Render **Disk** (see the comment in `render.yaml`).

## 3. Android app (APK)

```powershell
flutter build apk --release --dart-define=API_HOST=https://YOUR-SERVICE.onrender.com
```

The APK is in `build\app\outputs\flutter-apk\app-release.apk`. Copy it to any phone and install.

## 4. Push notifications: Firebase

1. **console.firebase.google.com** → *Add project* (Analytics not needed).
2. *Add app* → **Android** → package name `com.example.agrisphere` → download **`google-services.json`**
   → put it in `android/app/` (the build picks it up automatically).
3. *Project settings* → *Service accounts* → **Generate new private key** → this JSON file is secret:
   - local: save it as `backend/firebase-service-account.json` and set `FIREBASE_SERVICE_ACCOUNT=./firebase-service-account.json` in `backend/.env`
   - Render: paste its contents into `FIREBASE_SERVICE_ACCOUNT_JSON`
4. Rebuild the APK. After logging in, the phone receives pushes for orders, payments, bookings and chat.
   `/api/health` shows `"push":true` when the server side is set up.

## 5. Web app

```powershell
flutter build web --release --dart-define=API_HOST=https://YOUR-SERVICE.onrender.com
```

Then upload the `build\web` folder to any static host, for example:
- **Netlify**: app.netlify.com → *Add new site* → *Deploy manually* → drag the `build\web` folder in.
- **Firebase Hosting** (same Firebase project): `firebase init hosting` (public dir `build/web`) → `firebase deploy`.

## 6. Checklist before the presentation

- [ ] `/api/health` → `db: connected`, `ai: true`, `push: true`
- [ ] Demo accounts work (see `docs/DEMO.md`)
- [ ] APK installed on a phone, logged in, a test chat message arrives instantly
- [ ] Location permission allowed on the phone (for *Near me* and weather)
