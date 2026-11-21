# AgriSphere - Setup Guide

## Backend (Node + MongoDB)
1. Start the MongoDB service.
2. In `backend/`, copy `.env.example` to `.env` and fill in the values.
3. Run:

    cd backend
    npm install
    npm start

You should see `MongoDB connected` and `API running on port 5000`.

## Flutter app
    flutter pub get
    flutter run -d chrome

Android emulator uses `10.0.2.2:5000`, Chrome uses `localhost:5000`.

## Project structure
    lib/
      core/        shared services, theme, utils, widgets
      modules/
        module_01_auth/         onboarding, login, signup, email verification, profile
        module_02_dashboard/    farmer dashboard and bottom navigation
        module_03_crops/        my crops, crop detail, add crop
        module_04_marketplace/  marketplace, product detail, sell produce
        module_05_orders/       cart, checkout, order tracking
        module_06_expert/       ask an expert
        module_07_supplier/     (planned)
        module_08_admin/        (planned)

## Branches
`main` is stable. Work happens in `feature/<module>-module` branches and is merged by pull request.