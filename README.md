# Campus Connect (TPEO New Fellow) — Flutter scaffold

This repo contains a minimal Flutter scaffold for Campus Connect — a UT-only marketplace app.

What I added today:
- Flutter project skeleton (lib/ scaffold)
- Riverpod for state management and go_router for routing
- Firebase package dependencies in `pubspec.yaml`
- Core services for Auth + Firestore and minimal UI (Login + Profile)
- Firestore security rules in `firestore.rules`

Important: I did not generate `firebase_options.dart` or platform Firebase files. You must run `flutterfire configure` locally with your Firebase project to generate them.

Quick setup
1. Install Flutter and Xcode for iOS development.
2. Activate FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
```

3. Add packages:

```bash
flutter pub get
```

4. Run FlutterFire configure (from repo root):

```bash
flutterfire configure --project tpeo-nf-project --out=lib/firebase_options.dart
```

Follow prompts to select iOS platform and enter bundle id `com.tpeo.nfproject`.

5. Place the generated `GoogleService-Info.plist` into `ios/Runner/` and update Xcode signing.

6. Run on iOS simulator / device:

```bash
flutter run -d ios
```

Notes
- You must configure the OAuth client in Firebase console for iOS Google sign-in and provide the reversed client id in Info.plist if needed.
- This scaffold enforces UT-only sign-in in the app and includes Firestore security rules that also enforce UT emails and email_verified.
# TPEO-New-Fellow