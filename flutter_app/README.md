# EVA Canteen — Flutter Application (`v2.0.0`)

Modern bilingual (**Arabic RTL / English LTR**) Flutter rebuild of **EVA Canteen** for **EVA International Applied Technology School**, paired with the real-time WebSocket + SQLite v1.1 backend.

## Highlights
- **Crisp Campus Bistro Design System (`EvaTokens`):** Daylight & Night Shift surface modes, 6 campus brand accents, optional subtle bistro doodle canvas, and bundled `Cairo` + `Nunito` fonts.
- **Student Experience:** Unified menu with bilingual search, Smart Combos & automatic `% OFF` bundle discounts, morphing inline cart steppers, 1-tap checkout (`Cash`, `Card`, `EVA Wallet`), Live `#ORD` Pickup Pass with barcode & ready chime, and 1-tap Reorder.
- **Admin & Kitchen Display System (KDS):** Adaptive mobile `NavigationBar` / desktop `NavigationRail` shell, 3-column live Kanban board (`Pending` | `Preparing` | `Delivered Today`) with ticking wait timers, touch-native Catalog & Bundle Studio with photo upload, interactive `fl_chart` Analytics, and Student Wallet Desk (`الرصيد`).

## Connecting from an Android Phone (`arm64-v8a`)
1. Start the backend server on your host machine:
   ```bash
   npm install
   npm start
   ```
   Note the `On Your Network: http://<LAN-IP>:8080` address printed in the terminal.
2. Install `EVA-Canteen-v2.0.0-arm64-v8a.apk` on your Android device.
3. In the app, tap **Browse Menu Only** (or sign in) → **Settings** → **Canteen Server Endpoint** and enter `http://<LAN-IP>:8080`.

## Building From Source
```bash
flutter pub get
flutter analyze
flutter test

# Android arm64-v8a Release APK
flutter build apk --release --target-platform android-arm64 --split-per-abi

# Web Production Bundle (auto-served by ../server.js)
flutter build web --no-web-resources-cdn
```
