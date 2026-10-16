import 'package:firebase_core/firebase_core.dart';

/// Local-only configuration for checking out Spendify without Firebase.
/// Copy to firebase_options.dart; flutterfire configure replaces that local file
/// when you connect your own project. These values do not identify a service.
class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:android:placeholder',
    messagingSenderId: '000000000000',
    projectId: 'spendify-placeholder',
  );

  static FirebaseOptions get currentPlatform => android;
}
