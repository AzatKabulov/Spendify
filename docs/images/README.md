# App screenshots

The README previews are captured from the Android app using the built-in debug seed, with Firebase and Gemini unconfigured. All transactions, account labels, budgets and rewards are synthetic. They are not examples of a live AI response or personal financial records.

Captured on 2026-10-16 using Flutter 3.44.2 / Dart 3.12.2 and an isolated Android API 36 emulator at 1080 × 2400. The images show Home, the monthly Budgets view, and the Reports overview. No interface elements or financial values were added to the captures.

To reproduce the dataset on a fresh emulator:

```sh
flutter run -d <android-device-id> --dart-define=DEMO_SEED=true
```

Capture Home, Budgets and Reports after the sample data appears. Keep screenshots readable at phone size and preserve the actual interface. The sample dates are relative to launch time, so totals and periods can differ between captures. Use a dedicated preview emulator; never clear an existing user's data just to regenerate screenshots.
