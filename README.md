# TPEO New Fellow (Hook'd Up)

Mobile marketplace app for UT Austin students built with Flutter, Riverpod, Firebase, and GoRouter.

## Current product scope

- UT-only authentication flow with onboarding and profile setup
- Main tabs: `Find`, `Appointments`, `Chat`, and `Profile`
- Provider discovery with detail/about pages and booking flows
- Appointment lifecycle support (create, edit, status updates)
- In-app chat threads with media support
- Local notification preferences + appointment reminder scheduling

## Tech stack

- Flutter + Dart
- `flutter_riverpod` for app state
- `go_router` for route orchestration
- Firebase Auth, Firestore, and Firebase Storage
- `flutter_local_notifications` + `timezone` for reminders

## Project structure

- `lib/features/` app UI and feature flows
- `lib/core/` shared services (Firebase init, Firestore, notifications, etc.)
- `lib/models/` app models
- `assets/` static assets, including demo seed images
- `firestore.rules` and `storage.rules` backend access rules

## Local setup

1. Install Flutter and Xcode (for iOS).
2. Install dependencies:

```bash
flutter pub get
```

3. Ensure Firebase config files are present (`lib/firebase_options.dart` and platform plist/json files). If needed:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project tpeo-nf-project --out=lib/firebase_options.dart
```

4. Run the app:

```bash
flutter run -d ios
```

## Firebase notes

- Firebase project: `tpeo-nf-project` (wired via `firebase.json`).
- Firestore rules are currently permissive for signed-in users during development (`firestore.rules`).
- Storage rules allow public reads for provider/seed assets and authenticated writes (`storage.rules`).
- If notifications are enabled in-app, iOS permission prompts are triggered from the notifications settings page.

## Dev notes

- Seed/demo data helpers live under `lib/core/seeder/`.
- Seed assets are under `assets/seed_images/`.
- Make sure Apple signing + bundle IDs are valid in the iOS project before building on device.