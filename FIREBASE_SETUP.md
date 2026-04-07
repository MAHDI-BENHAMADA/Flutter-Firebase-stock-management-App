# Firebase Setup (Use Your Own Project)

This repository currently includes Firebase wiring in app code, but you should generate your own Firebase config files for your own Firebase project.

## 1) Create your Firebase project

1. Go to Firebase Console.
2. Create a new project.
3. Enable the services you need (Authentication, Firestore, Storage, etc.).

## 2) Register app IDs that match this repo

- Android package name: `com.example.wa_inventory`
- iOS bundle ID: update to your own in Xcode if needed, then register that same ID in Firebase.

If you change Android or iOS IDs, regenerate Firebase config after that change.

## 3) Generate FlutterFire config for this project

From the project root, run:

```bash
flutter pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project-id>
```

This regenerates:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `firebase.json`
- and `ios/Runner/GoogleService-Info.plist` (if iOS is selected)

## 4) Get packages and run

```bash
flutter pub get
flutter run
```

## 5) Optional cleanup of old tracked config (if already in git history)

If old config files are still tracked in git, untrack them once:

```bash
git rm --cached android/app/google-services.json lib/firebase_options.dart firebase.json
```

If you use iOS:

```bash
git rm --cached ios/Runner/GoogleService-Info.plist
```

Then commit.

## Notes

- `lib/main.dart` already initializes Firebase using `DefaultFirebaseOptions.currentPlatform`.
- Keep generated Firebase config files local for your own project unless your team intentionally shares a non-sensitive Firebase setup.
