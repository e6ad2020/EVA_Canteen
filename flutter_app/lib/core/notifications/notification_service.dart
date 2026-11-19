import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:equatable/equatable.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';

const String kOrderReadyAndroidChannelId = 'eva_order_ready_v1';

enum PushPermissionState {
  unknown,
  authorized,
  denied,
  permanentlyDenied,
  unsupported,
}

class IncomingOrderNotification extends Equatable {
  const IncomingOrderNotification({
    required this.type,
    required this.orderId,
    required this.pickupNumber,
    this.route = '/orders',
    this.title,
    this.body,
  });

  final String type;
  final String orderId;
  final String pickupNumber;
  final String route;
  final String? title;
  final String? body;

  String get targetLocation {
    final normalizedRoute = route.startsWith('/') ? route : '/orders';
    if (orderId.isEmpty) return normalizedRoute;
    return '$normalizedRoute?orderId=${Uri.encodeQueryComponent(orderId)}';
  }

  static IncomingOrderNotification? fromDataMap(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    final type = (data['type']?.toString() ?? 'order_ready').trim();
    final orderId = (data['orderId']?.toString() ?? '').trim();
    final pickupNumber = (data['pickupNumber']?.toString() ?? '').trim();
    final route = (data['route']?.toString() ?? '/orders').trim();
    if (orderId.isEmpty && route.isEmpty) {
      return null;
    }
    return IncomingOrderNotification(
      type: type.isEmpty ? 'order_ready' : type,
      orderId: orderId,
      pickupNumber: pickupNumber,
      route: route.isEmpty ? '/orders' : route,
      title: title,
      body: body,
    );
  }

  @override
  List<Object?> get props => [type, orderId, pickupNumber, route, title, body];
}

@pragma('vm:entry-point')
Future<void> evaFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  // Background isolate wake handler. OS renders the hybrid `notification`
  // payload natively; we only ensure Firebase is initialized cleanly without
  // touching UI state.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
}

abstract class NotificationService {
  String? get platformName;
  bool get isSupported;

  Stream<IncomingOrderNotification> get foregroundMessages;
  Stream<IncomingOrderNotification> get notificationTaps;
  Stream<String> get tokenRefreshes;

  Future<void> initialize();
  Future<PushPermissionState> getPermissionState();
  Future<PushPermissionState> requestPermission();
  Future<String?> getToken();
  Future<IncomingOrderNotification?> getInitialTap();
  Future<void> showLocalOrderReadyNotification({
    required String orderId,
    required String title,
    required String body,
    String route = '/orders',
  });
  void dispose();
}

class NoopNotificationService implements NotificationService {
  final _foregroundController =
      StreamController<IncomingOrderNotification>.broadcast();
  final _tapController =
      StreamController<IncomingOrderNotification>.broadcast();
  final _tokenRefreshController = StreamController<String>.broadcast();

  @override
  String? get platformName => null;

  @override
  bool get isSupported => false;

  @override
  Stream<IncomingOrderNotification> get foregroundMessages =>
      _foregroundController.stream;

  @override
  Stream<IncomingOrderNotification> get notificationTaps =>
      _tapController.stream;

  @override
  Stream<String> get tokenRefreshes => _tokenRefreshController.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<PushPermissionState> getPermissionState() async =>
      PushPermissionState.unsupported;

  @override
  Future<PushPermissionState> requestPermission() async =>
      PushPermissionState.unsupported;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<IncomingOrderNotification?> getInitialTap() async => null;

  @override
  Future<void> showLocalOrderReadyNotification({
    required String orderId,
    required String title,
    required String body,
    String route = '/orders',
  }) async {}

  @override
  void dispose() {
    _foregroundController.close();
    _tapController.close();
    _tokenRefreshController.close();
  }
}

class FcmNotificationService implements NotificationService {
  FcmNotificationService({
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _localNotifications;

  final _foregroundController =
      StreamController<IncomingOrderNotification>.broadcast();
  final _tapController =
      StreamController<IncomingOrderNotification>.broadcast();
  final _tokenRefreshController = StreamController<String>.broadcast();

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  bool _initialized = false;
  bool _firebaseReady = false;
  bool _localNotificationsReady = false;

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  String? get platformName {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return null;
  }

  @override
  bool get isSupported => _firebaseReady && platformName != null;

  @override
  Stream<IncomingOrderNotification> get foregroundMessages =>
      _foregroundController.stream;

  @override
  Stream<IncomingOrderNotification> get notificationTaps =>
      _tapController.stream;

  @override
  Stream<String> get tokenRefreshes => _tokenRefreshController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (platformName == null) {
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        if (kIsWeb) {
          final webOptions = EvaFirebaseEnvConfig.webFirebaseOptions;
          if (webOptions == null) {
            return;
          }
          await Firebase.initializeApp(options: webOptions);
        } else {
          await Firebase.initializeApp();
        }
      }
      _firebaseReady = true;
    } catch (err) {
      debugPrint(
        'EVA Canteen: Firebase not configured on $platformName; '
        'falling back to live WebSocket alerts ($err)',
      );
      _firebaseReady = false;
      return;
    }

    if (_isMobilePlatform) {
      FirebaseMessaging.onBackgroundMessage(
        evaFirebaseMessagingBackgroundHandler,
      );
      await _initLocalNotifications();

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          await FirebaseMessaging.instance
              .setForegroundNotificationPresentationOptions(
                alert: false,
                badge: false,
                sound: false,
              );
        } catch (_) {}
      }
    }

    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      final parsed = _parseRemoteMessage(message);
      if (parsed != null && !_foregroundController.isClosed) {
        _foregroundController.add(parsed);
      }
    });

    _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      final parsed = _parseRemoteMessage(message);
      if (parsed != null && !_tapController.isClosed) {
        _tapController.add(parsed);
      }
    });

    // ignore: deprecated_member_use
    _onTokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) {
      final cleaned = token.trim();
      if (cleaned.isNotEmpty && !_tokenRefreshController.isClosed) {
        _tokenRefreshController.add(cleaned);
      }
    });
  }

  Future<void> _initLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings(
        '@drawable/ic_stat_eva_canteen',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _handleLocalNotificationTap,
      );

      if (defaultTargetPlatform == TargetPlatform.android) {
        const channel = AndroidNotificationChannel(
          kOrderReadyAndroidChannelId,
          'Order Ready Alerts',
          description:
              'High-priority alerts when your EVA Canteen order is ready for pickup.',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.createNotificationChannel(channel);
      }

      _localNotificationsReady = true;
    } catch (err) {
      debugPrint('EVA Canteen: local notifications init skipped ($err)');
      _localNotificationsReady = false;
    }
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    final parsed = _parseLocalPayload(response.payload);
    if (parsed != null && !_tapController.isClosed) {
      _tapController.add(parsed);
    }
  }

  IncomingOrderNotification? _parseRemoteMessage(RemoteMessage message) {
    return IncomingOrderNotification.fromDataMap(
      message.data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }

  IncomingOrderNotification? _parseLocalPayload(String? rawPayload) {
    if (rawPayload == null || rawPayload.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map<String, dynamic>) {
        return IncomingOrderNotification.fromDataMap(decoded);
      }
    } catch (_) {}
    return null;
  }

  PushPermissionState _mapAuthStatus(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return PushPermissionState.authorized;
      case AuthorizationStatus.deniedPermanently:
        return PushPermissionState.permanentlyDenied;
      case AuthorizationStatus.denied:
      case AuthorizationStatus.notDetermined:
        return PushPermissionState.denied;
    }
  }

  @override
  Future<PushPermissionState> getPermissionState() async {
    if (!isSupported) return PushPermissionState.unsupported;
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return _mapAuthStatus(settings.authorizationStatus);
    } catch (_) {
      return PushPermissionState.unsupported;
    }
  }

  @override
  Future<PushPermissionState> requestPermission() async {
    if (!isSupported) return PushPermissionState.unsupported;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: false,
        sound: true,
        provisional: false,
      );
      return _mapAuthStatus(settings.authorizationStatus);
    } catch (_) {
      return PushPermissionState.denied;
    }
  }

  @override
  Future<String?> getToken() async {
    if (!isSupported) return null;
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        for (int attempt = 0; attempt < 3 && apnsToken == null; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        }
        if (apnsToken == null) {
          return null;
        }
      }

      // Use FCM registration tokens (compatible with firebase-admin `tokens:`
      // multicast payloads across Android, iOS, and Web).
      final token = kIsWeb
          // ignore: deprecated_member_use
          ? await FirebaseMessaging.instance.getToken(
              vapidKey: EvaFirebaseEnvConfig.hasWebVapidKey
                  ? EvaFirebaseEnvConfig.webVapidKey
                  : null,
            )
          // ignore: deprecated_member_use
          : await FirebaseMessaging.instance.getToken();
      final cleaned = token?.trim();
      return (cleaned == null || cleaned.isEmpty) ? null : cleaned;
    } catch (err) {
      debugPrint('EVA Canteen: failed to fetch FCM token ($err)');
      return null;
    }
  }

  @override
  Future<IncomingOrderNotification?> getInitialTap() async {
    if (!isSupported) return null;
    try {
      final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMsg != null) {
        return _parseRemoteMessage(initialMsg);
      }
    } catch (_) {}

    if (_localNotificationsReady) {
      try {
        final launchDetails = await _localNotifications
            .getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp == true) {
          return _parseLocalPayload(
            launchDetails?.notificationResponse?.payload,
          );
        }
      } catch (_) {}
    }

    return null;
  }

  @override
  Future<void> showLocalOrderReadyNotification({
    required String orderId,
    required String title,
    required String body,
    String route = '/orders',
  }) async {
    if (!_localNotificationsReady || kIsWeb) return;
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          kOrderReadyAndroidChannelId,
          'Order Ready Alerts',
          channelDescription:
              'High-priority alerts when your EVA Canteen order is ready for pickup.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@drawable/ic_stat_eva_canteen',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          color: const Color(0xFF10B981),
          category: AndroidNotificationCategory.status,
          visibility: NotificationVisibility.public,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: 'EVA Canteen',
          ),
          ticker: title,
          tag: orderId,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          presentBadge: false,
        ),
      );

      final payload = jsonEncode({
        'type': 'order_ready',
        'orderId': orderId,
        'route': route,
      });

      await _localNotifications.show(
        id: orderId.hashCode & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();
    _onTokenRefreshSub?.cancel();
    _foregroundController.close();
    _tapController.close();
    _tokenRefreshController.close();
  }
}
