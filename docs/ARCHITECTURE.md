# AgriSphere — Architecture & Design Diagrams

Diagrams are written in [Mermaid](https://mermaid.js.org/); GitHub renders them automatically.
To export images for the report, paste a block into <https://mermaid.live> and download PNG/SVG.

---

## 1. System architecture

```mermaid
flowchart LR
  subgraph Client["Flutter app (Android / Web)"]
    UI[Screens: 11 modules] --> SVC[AgriApi / ApiService]
    UI --> RT[Socket.IO client]
    SVC --> CACHE[(Offline cache\nSharedPreferences)]
  end

  subgraph Server["Node.js + Express API"]
    AUTH[/api/auth\nJWT, OTP, Google/]
    AGRI[/api/agri\n13 feature routers/]
    WS[Socket.IO\nlive chat & alerts]
    MW[helmet · sanitize · rate limit]
  end

  subgraph Data["Storage"]
    DB[(MongoDB)]
    FILES[(uploads/\nphotos + private receipts)]
  end

  subgraph External["External services"]
    CLAUDE[Claude API\nAgriChatBot + Crop Doctor]
    OSM[OpenStreetMap\ntiles + Nominatim]
    METEO[Open-Meteo\nweather]
    FCM[Firebase Cloud Messaging]
  end

  SVC -- HTTPS JSON --> MW --> AUTH & AGRI
  RT <-- WebSocket --> WS
  AUTH & AGRI --> DB
  AGRI --> FILES
  AGRI --> CLAUDE
  AGRI --> FCM
  UI --> OSM
  UI --> METEO
```

## 2. Database (ER diagram, main collections)

```mermaid
erDiagram
  USER ||--o| PROFILE : has
  USER ||--o{ LISTING : sells
  USER ||--o{ ORDER : places
  ORDER }o--|| USER : "seller"
  ORDER ||--|{ ORDER_ITEM : contains
  ORDER_ITEM }o--|| LISTING : refers
  LISTING ||--o{ REVIEW : receives
  USER ||--o{ CROP : grows
  CROP ||--|{ TASK : plans
  USER ||--o{ MACHINE : owns
  MACHINE ||--o{ MACHINE_BOOKING : booked
  USER ||--o{ WAREHOUSE : owns
  WAREHOUSE ||--o{ STORAGE_BOOKING : stores
  STORAGE_BOOKING ||--o{ PAYMENT : "part payments"
  USER ||--o{ CONVERSATION : joins
  CONVERSATION ||--o{ MESSAGE : has
  USER ||--o{ FAVORITE : saves
  USER ||--o{ NOTIFICATION : gets
  USER ||--o{ AI_CHAT : "talks to AgriChatBot"
  USER ||--o{ DIAGNOSIS : "crop doctor"

  USER { string name string email string roles bool emailVerified }
  LISTING { string title string category number pricePerKg number quantityKg number rating number lat number lng }
  ORDER { number number string status string payment string paymentStatus string paymentProof number total }
  MACHINE_BOOKING { number number date startAt string status string paymentStatus number total }
  STORAGE_BOOKING { number number number quantityTons string status number paidAmount }
```

## 3. Use cases

```mermaid
flowchart LR
  F((Farmer)) --- UC1[Manage crops & tasks]
  F --- UC2[Sell produce]
  F --- UC3[Rent machinery]
  F --- UC4[Store crop in warehouse]
  F --- UC5[Ask expert / AgriChatBot / Crop Doctor]
  B((Buyer)) --- UC6[Browse, filter, save, chat]
  B --- UC7[Checkout: COD / Easypaisa / Card]
  B --- UC8[Track order & review]
  S((Supplier)) --- UC9[List seeds, fertilizer, tools]
  E((Expert)) --- UC10[Answer questions]
  M((Machinery owner)) --- UC11[Manage fleet, bookings, earnings]
  W((Warehouse owner)) --- UC12[Manage space, labour, readings]
  A((Admin)) --- UC13[Verify payments & users]
  A --- UC14[Moderate listings, view reports & log]
```

## 4. Sequence — checkout with Easypaisa

```mermaid
sequenceDiagram
  actor Buyer
  participant App
  participant API
  participant DB
  actor Admin as Seller / Admin
  Buyer->>App: Proceed to checkout (address, delivery, Easypaisa)
  App->>API: POST /orders
  API->>DB: reserve stock atomically (quantity >= qty)
  API->>DB: create order(s), paymentStatus = awaiting_proof
  API-->>App: order + Easypaisa account
  Buyer->>Buyer: Send money in Easypaisa app
  Buyer->>App: Attach screenshot + transaction ID
  App->>API: POST /orders/:id/payment-proof
  API->>DB: save private receipt, status = under_review
  API-->>Admin: notification + push
  Admin->>App: Open receipt, Approve
  App->>API: PATCH /orders/:id/payment
  API->>DB: paymentStatus = paid, admin log entry
  API-->>Buyer: notification "Payment verified"
```

## 5. Sequence — machinery booking

```mermaid
sequenceDiagram
  actor Farmer
  participant API
  actor Owner
  Farmer->>API: GET /machinery?lat&lng&sort=near
  Farmer->>API: POST /machinery/:id/book (time, hours, technician, field pin)
  API->>API: price quote + clash check
  API-->>Owner: notification
  Owner->>API: PATCH /machinery-bookings/:id/respond (accept, assign technician)
  Owner->>API: PATCH .../progress (in_progress) + GPS location
  API-->>Farmer: live update (Socket.IO) + map
  Farmer->>API: POST .../pay (Cash or Easypaisa screenshot)
  Owner->>API: PATCH .../payment (approve)
  Owner->>API: PATCH .../progress (completed)
  Farmer->>API: POST .../rate
```

## 6. AI features

```mermaid
flowchart TD
  P[Farmer takes leaf photo] --> R[POST /ai/diagnose]
  R --> C[Claude vision\nstructured JSON]
  C --> D[Disease, confidence, severity,\ntreatment, prevention]
  D --> H[(Saved to history)]
  D --> X{Low confidence or severe?}
  X -- yes --> EX[Suggest asking a human expert]
  Q[Question in AgriChatBot] --> CH[POST /ai/chat]
  CH --> C2[Claude, Pakistani farming context,\nEnglish or Urdu]
  C2 --> A[Answer + follow-up suggestions]
```
