import 'package:firebase_core/firebase_core.dart';

/// Environment-safe Firebase configuration for EVA Canteen.
///
/// Android and iOS read native configuration from `google-services.json` and
/// `GoogleService-Info.plist` when present. Flutter Web reads optional build-time
/// `--dart-define` values (and `EVA_FIREBASE_WEB_VAPID_KEY` for Web Push).
///
/// When credentials are absent, all platforms fall back cleanly to live
/// WebSocket alerts without throwing initialization errors.
class EvaFirebaseEnvConfig {
  const EvaFirebaseEnvConfig._();

  static const String webApiKey = String.fromEnvironment(
    'EVA_FIREBASE_WEB_API_KEY',
  );
  static const String webAppId = String.fromEnvironment(
    'EVA_FIREBASE_WEB_APP_ID',
  );
  static const String webMessagingSenderId = String.fromEnvironment(
    'EVA_FIREBASE_WEB_MESSAGING_SENDER_ID',
  );
  static const String webProjectId = String.fromEnvironment(
    'EVA_FIREBASE_WEB_PROJECT_ID',
  );
  static const String webAuthDomain = String.fromEnvironment(
    'EVA_FIREBASE_WEB_AUTH_DOMAIN',
  );
  static const String webStorageBucket = String.fromEnvironment(
    'EVA_FIREBASE_WEB_STORAGE_BUCKET',
  );
  static const String webVapidKey = String.fromEnvironment(
    'EVA_FIREBASE_WEB_VAPID_KEY',
  );

  static bool get isWebConfigured =>
      webApiKey.isNotEmpty &&
      webAppId.isNotEmpty &&
      webMessagingSenderId.isNotEmpty &&
      webProjectId.isNotEmpty;

  static bool get hasWebVapidKey => webVapidKey.isNotEmpty;

  static FirebaseOptions? get webFirebaseOptions {
    if (!isWebConfigured) return null;
    return FirebaseOptions(
      apiKey: webApiKey,
      appId: webAppId,
      messagingSenderId: webMessagingSenderId,
      projectId: webProjectId,
      authDomain: webAuthDomain.isEmpty ? null : webAuthDomain,
      storageBucket: webStorageBucket.isEmpty ? null : webStorageBucket,
    );
  }
}
