# daily_brief

A new Flutter project.

## Firebase and crash reporting

The Android, iOS, and Web app configurations are generated in
`lib/firebase_options.dart` for the Firebase project `dailybrief-ivanmahendraa`.
Regenerate them with:

```powershell
dart pub global run flutterfire_cli:flutterfire configure --project=dailybrief-ivanmahendraa --platforms=android,ios,web
```

Cloud Firestore stores only recognized command categories and server timestamps.
It does not store speech transcripts, audio, responses, or location coordinates.
The Firestore access rules are in `firestore.rules`.

Reverse geocoding uses the device's native Android/iOS geocoder and does not
require a Google Geocoding API key. Results depend on the platform geocoder and
may require network access; the app uses the returned city/region only for the
current spoken response and does not persist coordinates.

Firebase Analytics is not integrated, and the app does not send product
analytics events. If analytics is considered in the future, its purpose,
collected fields, and user privacy impact must be reviewed before enabling it;
speech transcripts, audio, precise location, and response text must not be
logged as analytics data.

Crashlytics is configured for Android and iOS. Automatic crash collection is
enabled in release builds and disabled in debug builds. Global Flutter and
uncaught asynchronous errors are reported with generic exception messages and
their stack traces; user utterances, location data, and error text are not added
to crash reports. Review reports in the Firebase Console under
**DevOps & Engagement > Crashlytics**.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
