# AgriSphere — Demo Guide

Everything you need for a smooth 10-minute demo.

## 1. Load the demo data

```powershell
cd backend
npm run seed:demo
```

Safe to run again before every demo: it resets only the demo accounts' data.

> **Admin login:** if `ADMIN_EMAILS` in `backend/.env` is not empty, add
> `admin.demo@agrisphere.test` to it (comma separated) so the demo admin can open the admin console.

## 2. Demo accounts

All accounts use the password **`Demo@12345`** (change it with `DEMO_PASSWORD` in `backend/.env` before seeding).

| Role | Email | What's ready |
|---|---|---|
| Farmer | `farmer.demo@agrisphere.test` | 2 crops with tasks, 3 listings, an answered expert question, a tractor booking, potatoes in cold storage, a buyer chat |
| Farmer 2 | `farmer2.demo@agrisphere.test` | Fruit & vegetable listings, an open expert question |
| Buyer | `buyer.demo@agrisphere.test` | Delivered + reviewed orders, one Easypaisa payment waiting for verification, a saved item |
| Supplier | `supplier.demo@agrisphere.test` | Fertilizer, seed and tool listings |
| Expert | `expert.demo@agrisphere.test` | One open farmer question to answer |
| Machinery owner | `machinery.demo@agrisphere.test` | 3 machines, an accepted booking, a technician |
| Warehouse owner | `warehouse.demo@agrisphere.test` | 2 warehouses, a stored booking with readings and part payment |
| Admin | `admin.demo@agrisphere.test` | Charts, payment queue, users, listing moderation, activity log |

## 3. Suggested demo flow (≈10 min)

1. **Buyer** → Marketplace: banners, categories, *Best deals*, filters, voice search → open *Sehar Wheat* → price vs market, reviews, seller card → **Buy now** → checkout with Easypaisa → upload screenshot.
2. **Admin** → *Payments* tab → open the receipt → **Approve** → *Activity* tab shows the log.
3. **Farmer** → Dashboard: weather tips, needs-attention, crop progress, tick a task → **AgriChatBot** ("My wheat has yellow stripes") → **Crop Doctor** (photo of a leaf).
4. **Farmer** → Rent machinery → *Near me* → tractor → map, chat with owner → booking → pay.
5. **Warehouse owner** → stored booking → add a temperature reading.
6. Switch the app to **Urdu** and make the text bigger from the top bar.

## 4. Quick checks before presenting

- `http://localhost:5000/api/health` shows `"db":"connected"` (and `"ai":true` if the Anthropic key is set).
- `npm test` in `backend` and `flutter test` in the project root both pass.
