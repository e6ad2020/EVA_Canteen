import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/domain_models.dart';
import '../network/eva_socket_client.dart';
import '../state/canteen_providers.dart';
import 'notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final socket = ref.watch(socketClientProvider);
  if (!socket.enableNetwork) {
    final noop = NoopNotificationService();
    ref.onDispose(noop.dispose);
    return noop;
  }

  final supportedPlatform =
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  final NotificationService service = supportedPlatform
      ? FcmNotificationService()
      : NoopNotificationService();
  ref.onDispose(service.dispose);
  return service;
});

class PendingDeepLinkNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setPending(String? location) {
    final cleaned = location?.trim();
    state = (cleaned == null || cleaned.isEmpty) ? null : cleaned;
  }

  void clear() {
    state = null;
  }
}

final pendingDeepLinkProvider =
    NotifierProvider<PendingDeepLinkNotifier, String?>(
      PendingDeepLinkNotifier.new,
    );

class NotificationState extends Equatable {
  const NotificationState({
    this.permissionState = PushPermissionState.unknown,
    this.currentToken,
    this.initialized = false,
    this.promptedAfterFirstOrder = false,
    this.syncBusy = false,
  });

  final PushPermissionState permissionState;
  final String? currentToken;
  final bool initialized;
  final bool promptedAfterFirstOrder;
  final bool syncBusy;

  NotificationState copyWith({
    PushPermissionState? permissionState,
    String? currentToken,
    bool clearToken = false,
    bool? initialized,
    bool? promptedAfterFirstOrder,
    bool? syncBusy,
  }) {
    return NotificationState(
      permissionState: permissionState ?? this.permissionState,
      currentToken: clearToken ? null : (currentToken ?? this.currentToken),
      initialized: initialized ?? this.initialized,
      promptedAfterFirstOrder:
          promptedAfterFirstOrder ?? this.promptedAfterFirstOrder,
      syncBusy: syncBusy ?? this.syncBusy,
    );
  }

  @override
  List<Object?> get props => [
    permissionState,
    currentToken,
    initialized,
    promptedAfterFirstOrder,
    syncBusy,
  ];
}

class NotificationController extends Notifier<NotificationState> {
  static const _kCachedPushToken = 'eva_cached_push_token_v1';
  static const _kPromptedFirstOrder = 'eva_push_prompted_v1';
  static const _kMaxAlertedIds = 200;

  final Set<String> _alertedReadyOrderIds = <String>{};
  StreamSubscription<IncomingOrderNotification>? _foregroundSub;
  StreamSubscription<IncomingOrderNotification>? _tapSub;
  StreamSubscription<String>? _tokenRefreshSub;

  bool _disposed = false;
  bool _isOnOrdersTab = false;
  String? _lastSyncedSignature;

  @override
  NotificationState build() {
    _disposed = false;
    final prefs = ref.watch(sharedPrefsProvider);
    final service = ref.watch(notificationServiceProvider);

    final cachedToken = prefs.getString(_kCachedPushToken);
    final prompted = prefs.getBool(_kPromptedFirstOrder) ?? false;

    ref.listen<(String?, UserRole?, String?, SocketConnectionPhase)>(
      canteenStoreProvider.select(
        (s) => (
          s.currentUser?.email,
          s.currentUser?.role,
          s.currentUser?.token,
          s.connectionPhase,
        ),
      ),
      (prev, next) {
        final (prevEmail, prevRole, prevToken, _) =
            prev ?? (null, null, null, null);
        final (email, role, token, phase) = next;

        final wasStudent =
            prevRole == UserRole.student &&
            (prevEmail?.isNotEmpty ?? false) &&
            (prevToken?.isNotEmpty ?? false);
        final isStudent =
            role == UserRole.student &&
            (email?.isNotEmpty ?? false) &&
            (token?.isNotEmpty ?? false);

        if (wasStudent && (!isStudent || prevEmail != email)) {
          unawaited(unregisterBeforeLogout(authToken: prevToken));
        }

        if (!isStudent) {
          _lastSyncedSignature = null;
          return;
        }

        final userChanged = prevEmail != email || prevToken != token;
        final becameConnected =
            prev?.$4 != SocketConnectionPhase.connected &&
            phase == SocketConnectionPhase.connected;
        if ((userChanged || becameConnected) &&
            state.permissionState == PushPermissionState.authorized) {
          unawaited(syncTokenWithBackend(force: becameConnected));
        }
      },
    );

    ref.listen<OrderStatusTransitionEvent?>(
      canteenStoreProvider.select((s) => s.lastOrderUpdate),
      (prev, next) {
        if (next == null || next.seq == prev?.seq) return;
        if (next.order.status != OrderStatus.delivered) {
          clearOrderReadyAlerted(next.order.id);
        } else if (next.previousStatus != OrderStatus.delivered) {
          handleWsOrderReady(next.order);
        }
      },
    );

    ref.listen<CanteenOrder?>(
      canteenStoreProvider.select((s) => s.lastConfirmedOrder),
      (prev, next) {
        if (next != null && next.id != prev?.id) {
          unawaited(promptAfterFirstOrderIfNeeded());
        }
      },
    );

    ref.listen<(String, String?)>(
      appPreferencesProvider.select(
        (p) => (p.locale.languageCode, p.customServerOrigin),
      ),
      (prev, next) {
        if (prev != next &&
            state.permissionState == PushPermissionState.authorized) {
          unawaited(syncTokenWithBackend(force: true));
        }
      },
    );

    ref.onDispose(() {
      _disposed = true;
      _foregroundSub?.cancel();
      _tapSub?.cancel();
      _tokenRefreshSub?.cancel();
    });

    Future.microtask(() => _bootstrap(service));

    return NotificationState(
      permissionState: PushPermissionState.unknown,
      currentToken: (cachedToken != null && cachedToken.isNotEmpty)
          ? cachedToken
          : null,
      initialized: false,
      promptedAfterFirstOrder: prompted,
    );
  }

  Future<void> _bootstrap(NotificationService service) async {
    if (_disposed) return;
    await service.initialize();
    if (_disposed) return;

    final perm = await service.getPermissionState();
    if (_disposed) return;

    state = state.copyWith(permissionState: perm, initialized: true);

    _foregroundSub?.cancel();
    _foregroundSub = service.foregroundMessages.listen(_handleForegroundPush);

    _tapSub?.cancel();
    _tapSub = service.notificationTaps.listen(_handleNotificationTap);

    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = service.tokenRefreshes.listen((newToken) {
      if (_disposed) return;
      unawaited(syncTokenWithBackend(force: true, tokenOverride: newToken));
    });

    final initialTap = await service.getInitialTap();
    if (!_disposed && initialTap != null) {
      _handleNotificationTap(initialTap);
    }

    if (!_disposed && perm == PushPermissionState.authorized) {
      await syncTokenWithBackend();
    }
  }

  void setViewingOrdersTab(bool viewing) {
    _isOnOrdersTab = viewing;
  }

  bool claimOrderReadyAlert(String orderId) {
    final cleaned = orderId.trim();
    if (cleaned.isEmpty) return true;
    if (_alertedReadyOrderIds.contains(cleaned)) {
      return false;
    }
    if (_alertedReadyOrderIds.length >= _kMaxAlertedIds) {
      _alertedReadyOrderIds.remove(_alertedReadyOrderIds.first);
    }
    _alertedReadyOrderIds.add(cleaned);
    return true;
  }

  void clearOrderReadyAlerted(String orderId) {
    final cleaned = orderId.trim();
    if (cleaned.isNotEmpty) {
      _alertedReadyOrderIds.remove(cleaned);
    }
  }

  Future<PushPermissionState> requestPermissionAndSync() async {
    final service = ref.read(notificationServiceProvider);
    if (!service.isSupported) {
      state = state.copyWith(
        permissionState: PushPermissionState.unsupported,
        syncBusy: false,
      );
      return PushPermissionState.unsupported;
    }

    state = state.copyWith(syncBusy: true);
    final perm = await service.requestPermission();
    if (_disposed) return perm;

    state = state.copyWith(permissionState: perm, syncBusy: false);
    if (perm == PushPermissionState.authorized) {
      await syncTokenWithBackend(force: true);
    }
    return perm;
  }

  Future<void> promptAfterFirstOrderIfNeeded() async {
    if (_disposed) return;
    final user = ref.read(canteenStoreProvider).currentUser;
    if (user == null || !user.isStudent) return;

    final service = ref.read(notificationServiceProvider);
    if (!service.isSupported) return;

    if (state.promptedAfterFirstOrder) return;
    if (state.permissionState == PushPermissionState.authorized ||
        state.permissionState == PushPermissionState.permanentlyDenied ||
        state.permissionState == PushPermissionState.unsupported) {
      return;
    }

    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool(_kPromptedFirstOrder, true);
    if (_disposed) return;
    state = state.copyWith(promptedAfterFirstOrder: true);

    await requestPermissionAndSync();
  }

  Future<bool> syncTokenWithBackend({
    bool force = false,
    String? tokenOverride,
  }) async {
    if (_disposed) return false;
    final service = ref.read(notificationServiceProvider);
    final platform = service.platformName;
    if (!service.isSupported || platform == null) return false;
    if (state.permissionState != PushPermissionState.authorized) return false;

    final user = ref.read(canteenStoreProvider).currentUser;
    final authToken = user?.token?.trim();
    if (user == null ||
        !user.isStudent ||
        authToken == null ||
        authToken.isEmpty) {
      return false;
    }

    final token = (tokenOverride ?? await service.getToken())?.trim();
    if (_disposed || token == null || token.isEmpty) return false;

    final locale = ref.read(appPreferencesProvider).locale.languageCode;
    final socket = ref.read(socketClientProvider);
    final signature = '${user.email}|$token|$locale|${socket.httpBaseUrl}';
    if (!force && _lastSyncedSignature == signature) {
      return true;
    }

    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString(_kCachedPushToken, token);
    if (_disposed) return false;
    state = state.copyWith(currentToken: token);

    final ok = await socket.registerPushToken(
      token: token,
      platform: platform,
      locale: locale,
      authTokenOverride: authToken,
    );
    if (!_disposed && ok) {
      _lastSyncedSignature = signature;
    }
    return ok;
  }

  Future<void> unregisterBeforeLogout({required String? authToken}) async {
    final prefs = ref.read(sharedPrefsProvider);
    final token = (state.currentToken ?? prefs.getString(_kCachedPushToken))
        ?.trim();
    _lastSyncedSignature = null;
    await prefs.remove(_kCachedPushToken);
    if (!_disposed) {
      state = state.copyWith(clearToken: true);
    }

    final cleanedAuth = authToken?.trim();
    if (token == null ||
        token.isEmpty ||
        cleanedAuth == null ||
        cleanedAuth.isEmpty) {
      return;
    }

    await ref
        .read(socketClientProvider)
        .unregisterPushToken(token: token, authTokenOverride: cleanedAuth);
  }

  void handleWsOrderReady(CanteenOrder order) {
    if (_disposed) return;
    if (!claimOrderReadyAlert(order.id)) return;

    final i18n = ref.read(i18nProvider);
    final body = i18n.t('order_ready_toast', {'num': order.pickupNumber});
    final title = i18n.t('order_ready_alerts_title');

    ref
        .read(canteenStoreProvider.notifier)
        .emitOrderReadyNotice(orderId: order.id, message: body);

    if (!_isOnOrdersTab &&
        state.permissionState == PushPermissionState.authorized) {
      unawaited(
        ref
            .read(notificationServiceProvider)
            .showLocalOrderReadyNotification(
              orderId: order.id,
              title: title,
              body: body,
            ),
      );
    }
  }

  void _handleForegroundPush(IncomingOrderNotification msg) {
    if (_disposed) return;
    if (msg.type != 'order_ready') return;
    if (!claimOrderReadyAlert(msg.orderId)) return;

    final socket = ref.read(socketClientProvider);
    if (socket.isConnected) {
      socket.send('get_my_orders', null);
    }

    final i18n = ref.read(i18nProvider);
    final fallbackPickup = msg.pickupNumber.isNotEmpty
        ? msg.pickupNumber
        : msg.orderId;
    final body = (msg.body != null && msg.body!.trim().isNotEmpty)
        ? msg.body!.trim()
        : i18n.t('order_ready_toast', {'num': fallbackPickup});
    final title = (msg.title != null && msg.title!.trim().isNotEmpty)
        ? msg.title!.trim()
        : i18n.t('order_ready_alerts_title');

    ref
        .read(canteenStoreProvider.notifier)
        .emitOrderReadyNotice(orderId: msg.orderId, message: body);

    if (!_isOnOrdersTab) {
      unawaited(
        ref
            .read(notificationServiceProvider)
            .showLocalOrderReadyNotification(
              orderId: msg.orderId,
              title: title,
              body: body,
              route: msg.route,
            ),
      );
    }
  }

  void _handleNotificationTap(IncomingOrderNotification tap) {
    if (_disposed) return;
    ref.read(pendingDeepLinkProvider.notifier).setPending(tap.targetLocation);

    final socket = ref.read(socketClientProvider);
    final user = ref.read(canteenStoreProvider).currentUser;
    if (socket.isConnected && user != null && user.isStudent) {
      socket.send('get_my_orders', null);
    }
  }
}

final notificationControllerProvider =
    NotifierProvider<NotificationController, NotificationState>(
      NotificationController.new,
    );
