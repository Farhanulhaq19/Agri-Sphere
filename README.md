<p align="center">
  <img src="assets/img/3_logo_horizontal_light.png" alt="AgriSphere" width="320">
</p>

<h3 align="center">One platform for the whole farm-to-market chain</h3>

<p align="center">
  Final Year Project: a Flutter mobile app with a Node.js + MongoDB backend that connects
  farmers, buyers, agricultural experts, input suppliers, machinery owners and warehouse owners.
</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-%5E3.9-0175C2?logo=dart">
  <img alt="Node.js" src="https://img.shields.io/badge/Node.js-Express%205-339933?logo=node.js">
  <img alt="MongoDB" src="https://img.shields.io/badge/MongoDB-Mongoose-47A248?logo=mongodb">
</p>

---

## Documentation

| Doc | What's inside |
|---|---|
| [docs/DEMO.md](docs/DEMO.md) | Demo accounts and a 10-minute demo script (`npm run seed:demo`) |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Architecture, ER, use-case and sequence diagrams |
| [docs/DEPLOY.md](docs/DEPLOY.md) | Going online: MongoDB Atlas, Render, APK, Firebase push |
| [docs/SETUP.md](docs/SETUP.md) | Local setup notes |

**Tests:** `npm test` in `backend` (19 unit tests) and `flutter test` (17 tests). **Urdu coverage:** `python scripts/check_urdu.py`.

## Table of contents

- [The problem](#the-problem)
- [What AgriSphere does](#what-agrisphere-does)
- [User roles](#user-roles)
- [Features by module](#features-by-module)
- [Tech stack](#tech-stack)
- [Architecture](#architecture)
- [Project structure](#project-structure)
- [Getting started](#getting-started)
- [Configuration](#configuration)
- [API overview](#api-overview)
- [Demo data](#demo-data)
- [Development workflow](#development-workflow)
- [Team](#team)

---

## The problem

Small and medium farmers rely on middlemen to sell produce, can't easily get expert advice,
and have trouble finding tractors, harvesters or cold storage when they need them. Each of these
services lives in a different place, usually offline, with little price transparency.

## What AgriSphere does

AgriSphere brings these services into one app:

- **Sell directly:** farmers list produce, buyers browse, make offers and place orders.
- **Get advice:** farmers ask questions and verified experts answer.
- **Buy inputs:** suppliers sell seeds, fertilizer and tools.
- **Rent machinery:** farmers book machines and owners manage their fleet, technicians, schedule and earnings.
- **Store produce:** farmers request warehouse space and owners track stored goods, readings, labour and payments.
- **Manage crops:** farmers track their crops and the tasks for each one.

The app supports **English and Urdu**, with right-to-left layout for Urdu.

## User roles

One account can hold several roles and switch between them without logging out.

| Role | What they do |
|---|---|
| **Farmer** | Manages crops, sells produce, asks experts, books machinery and storage |
| **Buyer** | Browses the marketplace, makes offers, orders and tracks deliveries |
| **Expert** | Answers farmers' questions |
| **Supplier** | Lists agricultural inputs and handles their orders |
| **Machinery Owner** | Lists machines, accepts bookings, manages technicians, maintenance and earnings |
| **Warehouse Owner** | Lists warehouses, accepts storage requests, manages labour, readings and payments |
| **Admin** | Views platform stats, verifies users and moderates listings. Only emails listed in `ADMIN_EMAILS` can be admins. |

## Features by module

| # | Module | Highlights |
|---|---|---|
| 01 | **Auth & Profile** | Onboarding, sign up / log in, email OTP verification, Google Sign-In, forgot / reset / change password, role selection and switching, notifications, account settings |
| 02 | **Dashboard** | Home dashboard and bottom navigation for farmers and buyers |
| 03 | **Crops** | Smart crop calendar (full-season task plan per crop with real dates), weather-aware irrigation tips, crop photos |
| 04 | **Marketplace** | Browse with photos, sort by newest / near me / price / rating, distance badges, product photo gallery and pickup map, sell produce with photos and map pin, offers, market average price |
| 05 | **Orders & Checkout** | Cart → checkout (receiver, phone, city, address), Standard / Express delivery, **Cash on Delivery, Easypaisa or card via Easypaisa** with payment screenshot + transaction ID, seller / admin verification, order tracking, cancellation |
| 06 | **Expert** | Ask an expert, expert inbox and answers |
| 11 | **Social** | Buyer ↔ seller **live chat** (WebSockets), saved items, reviews, seller profiles, push notifications |
| 12 | **AI** | **AgriChatBot** (free AI farming assistant for every role, English & Urdu, 24/7) and **Crop Doctor** (photo → disease, severity, treatment) |
| 07 | **Supplier** | Supplier dashboard, product catalogue, incoming orders, profile |
| 08 | **Admin** | Charts (sales, users, orders), Easypaisa payment verification queue, user verification, listing moderation, activity log |
| 09 | **Machinery** | Machine photos, map location and "near me" search, field pin with directions, live machine position on map, Easypaisa / card / cash payments with owner verification, browse and book machines, booking detail and live progress, payment and rating; owner home, fleet, technicians, schedule, maintenance and earnings |
| 10 | **Warehouse** | Warehouse photos, map location and "near me" search, partial online payments with screenshot verification, browse warehouses and request storage, storage booking detail, payment and rating; owner home, warehouses, labour, storage readings and tasks, payments |

## Tech stack

| Layer | Technology |
|---|---|
| Mobile / web client | Flutter (Dart ^3.9), Material Design |
| Client packages | `http`, `shared_preferences`, `google_sign_in`, `image_picker`, `flutter_map` + `latlong2` (OpenStreetMap), `geolocator`, `url_launcher` |
| Maps & location | OpenStreetMap tiles and Nominatim search (free, no API key), device GPS, Google Maps directions link |
| AI | Free by default: **Ollama** (runs on the server computer, offline) or **Groq** (free online key); a built-in farming guide answers when no model is running. Claude is optional. |
| Real-time | Socket.IO live chat and notifications; Firebase Cloud Messaging push (optional) |
| CI | GitHub Actions: Flutter analyze, tests and debug APK build; backend install, syntax checks and unit tests |
| Payments | Cash on Delivery and manual Easypaisa transfers (card payments through the Easypaisa app) verified by screenshot |
| Backend | Node.js, Express 5 |
| Database | MongoDB with Mongoose |
| Auth | JWT, bcrypt password hashing, Google ID token verification, email OTP |
| Email | Nodemailer (codes are logged to the console when email isn't configured) |
| Security | Custom per-IP rate limiting on sensitive auth routes, role-based access checks |

## Architecture

```
┌──────────────────────────────┐        HTTPS / JSON        ┌──────────────────────────────┐
│        Flutter app           │  ───────────────────────▶  │     Express API (Node.js)    │
│                              │   Authorization: Bearer    │                              │
│  modules/  (10 feature UIs)  │                            │  /api/auth   → routes/auth   │
│  core/services/api_service   │  ◀───────────────────────  │  /api/agri   → routes/agri   │
│  core/services/agri_api      │                            │        └─ modules/*.js       │
│  core/i18n  (EN / UR)        │                            │  utils/ identity, rateLimit, │
└──────────────────────────────┘                            │         seed, sendEmail      │
                                                            └──────────────┬───────────────┘
                                                                           │ Mongoose
                                                                    ┌──────▼──────┐
                                                                    │   MongoDB   │
                                                                    └─────────────┘
```

- **`/api/auth`** handles accounts: signup, OTP, login, Google, passwords and roles.
- **`/api/agri`** handles everything else. A shared middleware works out the caller from the JWT
  (`utils/identity.js`), then the request goes to the router of the matching module.

## Project structure

```
agrisphere/
├── lib/                          Flutter app
│   ├── main.dart                 App entry point
│   ├── core/
│   │   ├── i18n/                 English / Urdu strings and language switching
│   │   ├── services/             api_service.dart (auth), agri_api.dart (features)
│   │   ├── theme/                App theme
│   │   ├── utils/                Form validators
│   │   └── widgets/              Shared UI components
│   └── modules/
│       ├── module_01_auth/
│       ├── module_02_dashboard/
│       ├── module_03_crops/
│       ├── module_04_marketplace/
│       ├── module_05_orders/
│       ├── module_06_expert/
│       ├── module_07_supplier/
│       ├── module_08_admin/
│       ├── module_09_machinery/
│       └── module_10_warehouse/
├── backend/                      Node.js API
│   ├── server.js                 Express app and MongoDB connection
│   ├── models/                   User, OTPs, crops/listings/orders, machinery, offers, warehouse
│   ├── routes/
│   │   ├── auth.js               /api/auth
│   │   ├── agri.js               /api/agri (loads modules/*)
│   │   └── modules/              One router per feature module
│   ├── utils/                    Identity, rate limiting, email, demo seeding
│   └── .env.example              Environment template
├── assets/img/                   Logos, hero and role images
├── docs/SETUP.md                 Short setup notes
└── test/                         Flutter tests
```

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart 3.9 or newer)
- [Node.js](https://nodejs.org/) 18 or newer
- [MongoDB](https://www.mongodb.com/try/download/community), running locally or on MongoDB Atlas
- Android Studio with an emulator, or Chrome for the web build

### 1. Clone

```powershell
git clone https://github.com/Farhanulhaq19/Agri-Sphere.git
```

```powershell
cd Agri-Sphere
```

### 2. Start the backend

```powershell
cd backend
```

```powershell
copy .env.example .env
```

Edit `backend/.env` (see [Configuration](#configuration)), then:

```powershell
npm install
```

```powershell
npm start
```

You should see `MongoDB connected` and `API running on port 5000`.
Open <http://localhost:5000> to check that it prints *AgriSphere API is running*.

### 3. Run the Flutter app

From the project root:

```powershell
flutter pub get
```

| Target | Command | API address used |
|---|---|---|
| Chrome | `flutter run -d chrome` | `http://localhost:5000` |
| Android emulator | `flutter run` | `http://10.0.2.2:5000` |
| Real phone (same Wi-Fi) | `flutter run --dart-define=API_HOST=http://YOUR_PC_IP:5000` | your PC's LAN IP |

> On a real phone, find your PC's IP with `ipconfig` and allow port 5000 through Windows Firewall.

### 4. Run checks

```powershell
flutter analyze
```

```powershell
flutter test
```

## Configuration

All backend settings live in `backend/.env` (never commit this file).

| Variable | Required | Description |
|---|---|---|
| `PORT` | no | API port, defaults to `5000` |
| `MONGO_URI` | **yes** | MongoDB connection string, e.g. `mongodb://127.0.0.1:27017/agrisphere` |
| `JWT_SECRET` | **yes** | Long random string used to sign login tokens |
| `GOOGLE_CLIENT_ID` | for Google login | Google OAuth **web** client ID |
| `EMAIL_USER` / `EMAIL_PASS` | no | Email account for sending OTP codes (e.g. a Gmail app password) |
| `DEV_MODE` | no | `true` makes development easier: OTP codes are returned/logged instead of only emailed |
| `ADMIN_EMAILS` | no | Comma-separated emails that are allowed to be Admin |
| `CORS_ORIGIN` | no | Allowed origin for the web client, defaults to `*` |
| `EASYPAISA_NUMBER` / `EASYPAISA_NAME` | no | Easypaisa account buyers send online payments to |
| `SEED_DEMO_DATA` | no | `true` loads demo listings and fleet on first request. Set to `false` in production |

> **No email set up?** Leave `EMAIL_USER` / `EMAIL_PASS` empty. The OTP code is printed in the backend console,
> so you can still verify accounts during development.

### Free AI setup

AgriChatBot and the Crop Doctor need no paid service:

| Option | Setup | Notes |
|---|---|---|
| **Ollama** (default) | Install from [ollama.com](https://ollama.com), then `ollama pull gemma3:4b` | Runs on the backend computer, offline, no limits |
| **Groq** | Free key from [console.groq.com](https://console.groq.com) → `GROQ_API_KEY=` (and `AI_PROVIDER=groq`) in `backend/.env` | Fast, free tier has rate limits |
| **Built-in guide** | Nothing | Answers ~25 common farming topics when no model is running |

`http://localhost:5000/api/health` shows which one is active (`"ai": "ollama" | "groq" | "offline"`).

### Testing on a phone

Run the backend on your laptop, allow port 5000 in Windows Firewall, then build with your laptop's Wi-Fi IP:

```powershell
flutter build apk --release --dart-define=API_HOST=http://YOUR-LAPTOP-IP:5000
```

## API overview

All `/api/agri` routes require `Authorization: Bearer <token>`.

<details>
<summary><b>Auth</b>: <code>/api/auth</code></summary>

| Method | Path | Purpose |
|---|---|---|
| POST | `/signup` | Create account |
| POST | `/send-otp` | Send email verification code |
| POST | `/verify-email` | Verify email with code |
| POST | `/login` | Email + password login |
| POST | `/google` | Google Sign-In |
| POST | `/forgot-password` · `/reset-password` | Password reset via OTP |
| POST | `/change-password` | Change password (logged in) |
| POST | `/switch-role` · `/add-role` · `/remove-role` | Multi-role management |
| PUT | `/account` | Update account |
| GET | `/me` | Current user |

</details>

<details>
<summary><b>Features</b>: <code>/api/agri</code></summary>

| Area | Main endpoints |
|---|---|
| Profile | `GET /me`, `PUT /profile`, `GET /notifications`, `POST /notifications/read` |
| Farmer & crops | `GET /dashboard`, `GET/POST /crops`, `GET/PATCH/DELETE /crops/:id`, `POST /crops/:id/tasks/:tid/toggle` |
| Marketplace | `GET/POST /listings`, `GET/PATCH/DELETE /listings/:id`, `GET /market-average` |
| Offers | `POST /listings/:id/offers`, `GET /offers`, `PATCH /offers/:id/respond`, `PATCH /offers/:id/cancel` |
| Cart & orders | `GET/POST /cart`, `PATCH/DELETE /cart/:id`, `GET/POST /orders`, `GET /orders/sales`, `PATCH /orders/:id/status`, `POST /orders/:id/cancel` |
| Expert | `GET/POST /queries`, `GET /expert/queries`, `POST /expert/queries/:id/answer` |
| Supplier | `GET /supplier/dashboard`, `GET/POST /supplier/products`, `PATCH/DELETE /supplier/products/:id`, `GET /supplier/orders` |
| Admin | `GET /admin/stats`, `GET /admin/users`, `PATCH /admin/verify/:userId`, `PATCH /admin/listings/:id` |
| Machinery (renter) | `GET /machinery`, `GET /machinery/:id`, `POST /machinery/:id/book`, `GET /machinery-bookings/mine`, cancel / pay / rate |
| Machinery (owner) | `/machinery-owner/dashboard`, `machines`, `technicians`, `bookings`, `schedule`, `earnings`, `maintenance`; booking `respond` / `progress` / `location` / `mark-paid` |
| Warehouse (renter) | `GET /warehouses`, `GET /warehouses/:id`, `POST /warehouses/:id/request`, `GET /storage-bookings/mine`, cancel / pay / rate |
| Warehouse (owner) | `/warehouse-owner/dashboard`, `warehouses`, `labour`, `bookings`, `payments`; booking `respond` / `stored` / `release` / `readings` / `tasks` / `mark-paid` |

</details>

## Demo data

When `SEED_DEMO_DATA` is not `false`, the backend adds sample marketplace listings, orders,
machinery and warehouses on the first `/api/agri` request. That way the app has realistic
content for a demo straight away. The seeded owners have no login, so they are for browsing only.

## Development workflow

- `main` is the stable branch.
- New work happens on `feature/<module>-module` branches and goes into `develop`, then into `main` through pull requests.
- Run `flutter analyze` before you commit.
- Never commit `backend/.env`, `google-services.json` or any keys.

## Team

| Name | Role |
|---|---|
| Farhan Ul Haq | Group Member |
| Adeel Abbas | Group Member |
| Muhammad Amanullah | Group Member |
| **Mr. Abu Zhar** | Supervisor |

_Final Year Project, Semester 7–8._
