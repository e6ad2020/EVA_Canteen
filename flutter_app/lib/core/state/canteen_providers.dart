import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design_system/eva_theme.dart';
import '../localization/eva_i18n.dart';
import '../models/domain_models.dart';
import '../network/eva_socket_client.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPrefsProvider must be overridden at startup');
});

class AppPreferencesState extends Equatable {
  const AppPreferencesState({
    this.locale = const Locale('en'),
    this.surfaceMode = EvaSurfaceMode.daylight,
    this.accentPreset = EvaAccentPreset.lightBlue,
    this.navBarBehavior = EvaNavBarBehavior.adaptive,
    this.showDoodlePattern = true,
    this.customServerOrigin,
  });

  final Locale locale;
  final EvaSurfaceMode surfaceMode;
  final EvaAccentPreset accentPreset;
  final EvaNavBarBehavior navBarBehavior;
  final bool showDoodlePattern;
  final String? customServerOrigin;

  AppPreferencesState copyWith({
    Locale? locale,
    EvaSurfaceMode? surfaceMode,
    EvaAccentPreset? accentPreset,
    EvaNavBarBehavior? navBarBehavior,
    bool? showDoodlePattern,
    String? customServerOrigin,
    bool clearServerOrigin = false,
  }) {
    return AppPreferencesState(
      locale: locale ?? this.locale,
      surfaceMode: surfaceMode ?? this.surfaceMode,
      accentPreset: accentPreset ?? this.accentPreset,
      navBarBehavior: navBarBehavior ?? this.navBarBehavior,
      showDoodlePattern: showDoodlePattern ?? this.showDoodlePattern,
      customServerOrigin: clearServerOrigin
          ? null
          : (customServerOrigin ?? this.customServerOrigin),
    );
  }

  @override
  List<Object?> get props => [
    locale,
    surfaceMode,
    accentPreset,
    navBarBehavior,
    showDoodlePattern,
    customServerOrigin,
  ];
}

class AppPreferencesNotifier extends Notifier<AppPreferencesState> {
  static const _kLang = 'eva_pref_lang';
  static const _kMode = 'eva_pref_mode';
  static const _kAccent = 'eva_pref_accent';
  static const _kNavBehavior = 'eva_pref_nav_bar_behavior';
  static const _kDoodle = 'eva_pref_doodle';
  static const _kServer = 'eva_pref_server_origin';

  @override
  AppPreferencesState build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final lang = prefs.getString(_kLang) ?? 'en';
    final modeName = prefs.getString(_kMode) ?? EvaSurfaceMode.daylight.name;
    final accentName =
        prefs.getString(_kAccent) ?? EvaAccentPreset.lightBlue.name;
    final navName = prefs.getString(_kNavBehavior);
    final doodle = prefs.getBool(_kDoodle) ?? true;
    final server = prefs.getString(_kServer);

    final mode = EvaSurfaceMode.values.firstWhere(
      (e) => e.name == modeName,
      orElse: () => EvaSurfaceMode.daylight,
    );
    final accent = EvaAccentPreset.fromStorageName(accentName);
    final navBehavior = EvaNavBarBehavior.fromStorageName(navName);

    return AppPreferencesState(
      locale: Locale(lang == 'ar' ? 'ar' : 'en'),
      surfaceMode: mode,
      accentPreset: accent,
      navBarBehavior: navBehavior,
      showDoodlePattern: doodle,
      customServerOrigin: (server == null || server.isEmpty) ? null : server,
    );
  }

  void toggleLanguage() {
    final next = state.locale.languageCode == 'ar' ? 'en' : 'ar';
    setLanguage(next);
  }

  void setLanguage(String code) {
    final normalized = code == 'ar' ? 'ar' : 'en';
    ref.read(sharedPrefsProvider).setString(_kLang, normalized);
    state = state.copyWith(locale: Locale(normalized));
  }

  void setSurfaceMode(EvaSurfaceMode mode) {
    ref.read(sharedPrefsProvider).setString(_kMode, mode.name);
    state = state.copyWith(surfaceMode: mode);
  }

  void setAccentPreset(EvaAccentPreset accent) {
    final prefs = ref.read(sharedPrefsProvider);
    prefs.setString(_kAccent, accent.name);
    if (accent.isWallpaperLightTheme &&
        state.surfaceMode != EvaSurfaceMode.daylight) {
      prefs.setString(_kMode, EvaSurfaceMode.daylight.name);
      state = state.copyWith(
        accentPreset: accent,
        surfaceMode: EvaSurfaceMode.daylight,
      );
      return;
    }
    state = state.copyWith(accentPreset: accent);
  }

  void setNavBarBehavior(EvaNavBarBehavior behavior) {
    ref.read(sharedPrefsProvider).setString(_kNavBehavior, behavior.name);
    state = state.copyWith(navBarBehavior: behavior);
  }

  void setShowDoodlePattern(bool enabled) {
    ref.read(sharedPrefsProvider).setBool(_kDoodle, enabled);
    state = state.copyWith(showDoodlePattern: enabled);
  }

  void setCustomServerOrigin(String? rawOrigin) {
    final cleaned = rawOrigin?.trim() ?? '';
    final prefs = ref.read(sharedPrefsProvider);
    if (cleaned.isEmpty) {
      prefs.remove(_kServer);
      state = state.copyWith(clearServerOrigin: true);
    } else {
      prefs.setString(_kServer, cleaned);
      state = state.copyWith(customServerOrigin: cleaned);
    }
    ref.read(socketClientProvider).updateServerOrigin(state.customServerOrigin);
  }
}

final appPreferencesProvider =
    NotifierProvider<AppPreferencesNotifier, AppPreferencesState>(
      AppPreferencesNotifier.new,
    );

final socketClientProvider = Provider<EvaSocketClient>((ref) {
  final initialOrigin = ref.read(appPreferencesProvider).customServerOrigin;
  final client = EvaSocketClient(customHttpOrigin: initialOrigin);
  ref.onDispose(client.dispose);
  return client;
});

class UiBannerNotice extends Equatable {
  const UiBannerNotice({
    required this.id,
    required this.message,
    this.isError = false,
    this.isCelebration = false,
  });

  final int id;
  final String message;
  final bool isError;
  final bool isCelebration;

  @override
  List<Object?> get props => [id, message, isError, isCelebration];
}

String _encodeJsonForCache(Object? encodable) => jsonEncode(encodable);

class _CanteenStoreCache {
  _CanteenStoreCache({this.productsById, this.studentCategories});

  Map<String, ProductItem>? productsById;
  List<CategoryItem>? studentCategories;
  final Map<String, List<ProductItem>> orderedProducts = {};
}

class CanteenStoreState extends Equatable {
  CanteenStoreState({
    this.connectionPhase = SocketConnectionPhase.connecting,
    this.isCanteenOpen = true,
    this.products = const [],
    this.categories = const [],
    this.bundles = const [],
    this.adminBundles = const [],
    this.translations = const {},
    this.paymentMethods = const PaymentMethodsConfig(),
    this.currentUser,
    this.myOrders = const [],
    this.adminOrders = const [],
    this.analytics,
    this.walletsSnapshot = const AdminWalletsSnapshot(),
    this.authBusy = false,
    this.checkoutBusy = false,
    this.adminNewOrderTick = 0,
    this.lastConfirmedOrder,
    this.notice,
    _CanteenStoreCache? cache,
  }) : _cache = cache ?? _CanteenStoreCache();

  final SocketConnectionPhase connectionPhase;
  final bool isCanteenOpen;
  final List<ProductItem> products;
  final List<CategoryItem> categories;
  final List<BundleOffer> bundles;
  final List<BundleOffer> adminBundles;
  final Map<String, Map<String, String>> translations;
  final PaymentMethodsConfig paymentMethods;
  final UserProfile? currentUser;
  final List<CanteenOrder> myOrders;
  final List<CanteenOrder> adminOrders;
  final AnalyticsSnapshot? analytics;
  final AdminWalletsSnapshot walletsSnapshot;
  final bool authBusy;
  final bool checkoutBusy;
  final int adminNewOrderTick;
  final CanteenOrder? lastConfirmedOrder;
  final UiBannerNotice? notice;
  final _CanteenStoreCache _cache;

  bool get isConnected => connectionPhase == SocketConnectionPhase.connected;

  Map<String, ProductItem> get productsById =>
      _cache.productsById ??= Map<String, ProductItem>.unmodifiable({
        for (final p in products) p.id: p,
      });

  List<CategoryItem> get studentCategories => _cache.studentCategories ??=
      List<CategoryItem>.unmodifiable(categories.where((c) => !c.isArchive));

  List<ProductItem> orderedProductsForCategory(
    String? categoryKey, {
    bool includeArchived = false,
  }) {
    final normalizedKey = (categoryKey != null && categoryKey.isNotEmpty)
        ? categoryKey
        : '';
    final cacheKey = '$normalizedKey#$includeArchived';
    final cached = _cache.orderedProducts[cacheKey];
    if (cached != null) return cached;

    final map = productsById;
    if (normalizedKey.isNotEmpty) {
      final cat = categories.where((c) => c.key == normalizedKey).firstOrNull;
      final ordered = <ProductItem>[];
      final seen = <String>{};
      if (cat != null) {
        for (final id in cat.productIds) {
          final prod = map[id];
          if (prod != null && prod.categoryKey == normalizedKey) {
            ordered.add(prod);
            seen.add(id);
          }
        }
      }
      for (final prod in products) {
        if (prod.categoryKey == normalizedKey && !seen.contains(prod.id)) {
          ordered.add(prod);
        }
      }
      final unmodifiable = List<ProductItem>.unmodifiable(ordered);
      _cache.orderedProducts[cacheKey] = unmodifiable;
      return unmodifiable;
    }

    final result = <ProductItem>[];
    final seen = <String>{};
    for (final cat in categories) {
      if (!includeArchived && cat.isArchive) continue;
      for (final prod in orderedProductsForCategory(
        cat.key,
        includeArchived: includeArchived,
      )) {
        if (seen.add(prod.id)) {
          result.add(prod);
        }
      }
    }
    for (final prod in products) {
      if (!includeArchived && prod.isArchived) continue;
      if (seen.add(prod.id)) {
        result.add(prod);
      }
    }
    final unmodifiable = List<ProductItem>.unmodifiable(result);
    _cache.orderedProducts[cacheKey] = unmodifiable;
    return unmodifiable;
  }

  CanteenOrder? get activeStudentOrder {
    for (final order in myOrders) {
      if (order.isToday && order.status != OrderStatus.delivered) {
        return order;
      }
    }
    for (final order in myOrders) {
      if (order.isToday) {
        return order;
      }
    }
    return null;
  }

  CanteenStoreState copyWith({
    SocketConnectionPhase? connectionPhase,
    bool? isCanteenOpen,
    List<ProductItem>? products,
    List<CategoryItem>? categories,
    List<BundleOffer>? bundles,
    List<BundleOffer>? adminBundles,
    Map<String, Map<String, String>>? translations,
    PaymentMethodsConfig? paymentMethods,
    UserProfile? currentUser,
    bool clearUser = false,
    List<CanteenOrder>? myOrders,
    List<CanteenOrder>? adminOrders,
    AnalyticsSnapshot? analytics,
    AdminWalletsSnapshot? walletsSnapshot,
    bool? authBusy,
    bool? checkoutBusy,
    int? adminNewOrderTick,
    CanteenOrder? lastConfirmedOrder,
    UiBannerNotice? notice,
    bool clearNotice = false,
  }) {
    final sameProducts = products == null || identical(products, this.products);
    final sameCategories =
        categories == null || identical(categories, this.categories);
    final nextCache = (sameProducts && sameCategories)
        ? _cache
        : _CanteenStoreCache(
            productsById: sameProducts ? _cache.productsById : null,
            studentCategories:
                sameCategories ? _cache.studentCategories : null,
          );

    return CanteenStoreState(
      connectionPhase: connectionPhase ?? this.connectionPhase,
      isCanteenOpen: isCanteenOpen ?? this.isCanteenOpen,
      products: products ?? this.products,
      categories: categories ?? this.categories,
      bundles: bundles ?? this.bundles,
      adminBundles: adminBundles ?? this.adminBundles,
      translations: translations ?? this.translations,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      myOrders: myOrders ?? this.myOrders,
      adminOrders: adminOrders ?? this.adminOrders,
      analytics: analytics ?? this.analytics,
      walletsSnapshot: walletsSnapshot ?? this.walletsSnapshot,
      authBusy: authBusy ?? this.authBusy,
      checkoutBusy: checkoutBusy ?? this.checkoutBusy,
      adminNewOrderTick: adminNewOrderTick ?? this.adminNewOrderTick,
      lastConfirmedOrder: lastConfirmedOrder ?? this.lastConfirmedOrder,
      notice: clearNotice ? null : (notice ?? this.notice),
      cache: nextCache,
    );
  }

  @override
  List<Object?> get props => [
    connectionPhase,
    isCanteenOpen,
    products,
    categories,
    bundles,
    adminBundles,
    translations,
    paymentMethods,
    currentUser,
    myOrders,
    adminOrders,
    analytics,
    walletsSnapshot,
    authBusy,
    checkoutBusy,
    adminNewOrderTick,
    lastConfirmedOrder,
    notice,
  ];
}

class CanteenStoreNotifier extends Notifier<CanteenStoreState> {
  static const _kCachedProducts = 'eva_cache_products_v2';
  static const _kCachedCategories = 'eva_cache_categories_v2';
  static const _kCachedBundles = 'eva_cache_bundles_v2';
  static const _kCachedTranslations = 'eva_cache_translations_v2';
  static const _kSavedSession = 'eva_saved_session_v2';

  int _noticeSeq = 0;
  Completer<CanteenOrder?>? _pendingCheckoutCompleter;
  Completer<String?>? _pendingAuthCompleter;
  final Map<String, Timer> _cacheWriteTimers = {};

  void _scheduleCacheWrite(
    SharedPreferences prefs,
    String key,
    Object Function() buildEncodable,
  ) {
    _cacheWriteTimers[key]?.cancel();
    _cacheWriteTimers[key] = Timer(const Duration(milliseconds: 120), () async {
      _cacheWriteTimers.remove(key);
      try {
        final encodable = buildEncodable();
        final encoded = kIsWeb
            ? _encodeJsonForCache(encodable)
            : await compute(_encodeJsonForCache, encodable);
        await prefs.setString(key, encoded);
      } catch (_) {}
    });
  }

  @override
  CanteenStoreState build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final socket = ref.watch(socketClientProvider);

    final initial = _hydrateFromCache(prefs).copyWith(
      connectionPhase: socket.currentPhase,
    );
    if (initial.currentUser?.token != null) {
      socket.setAuthToken(initial.currentUser!.token);
    }

    final phaseSub = socket.phaseStream.listen((phase) {
      state = state.copyWith(connectionPhase: phase);
    });
    final eventSub = socket.events.listen(_onSocketEvent);

    Future.microtask(socket.connect);

    ref.onDispose(() {
      phaseSub.cancel();
      eventSub.cancel();
      for (final timer in _cacheWriteTimers.values) {
        timer.cancel();
      }
      _cacheWriteTimers.clear();
    });

    return initial;
  }

  CanteenStoreState _hydrateFromCache(SharedPreferences prefs) {
    List<ProductItem> products = const [];
    List<CategoryItem> categories = const [];
    List<BundleOffer> bundles = const [];
    Map<String, Map<String, String>> translations = const {};
    UserProfile? user;

    try {
      final rawProducts = prefs.getString(_kCachedProducts);
      if (rawProducts != null) {
        products = (jsonDecode(rawProducts) as List)
            .whereType<Map>()
            .map((e) => ProductItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false);
      }
      final rawCategories = prefs.getString(_kCachedCategories);
      if (rawCategories != null) {
        categories = (jsonDecode(rawCategories) as List)
            .whereType<Map>()
            .map((e) => CategoryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false);
      }
      final rawBundles = prefs.getString(_kCachedBundles);
      if (rawBundles != null) {
        bundles = (jsonDecode(rawBundles) as List)
            .whereType<Map>()
            .map((e) => BundleOffer.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false);
      }
      final rawTrans = prefs.getString(_kCachedTranslations);
      if (rawTrans != null) {
        translations = _parseTranslationsPayload(jsonDecode(rawTrans));
      }
      final rawUser = prefs.getString(_kSavedSession);
      if (rawUser != null) {
        user = UserProfile.fromJson(
          Map<String, dynamic>.from(jsonDecode(rawUser) as Map),
        );
      }
    } catch (_) {}

    return CanteenStoreState(
      products: products,
      categories: categories,
      bundles: bundles,
      translations: translations,
      currentUser: user,
    );
  }

  Map<String, Map<String, String>> _parseTranslationsPayload(dynamic payload) {
    if (payload is! Map) return const {};
    final mapped = <String, Map<String, String>>{};
    for (final entry in payload.entries) {
      final key = entry.key.toString();
      final val = entry.value;
      if (val is Map) {
        final inner = <String, String>{};
        for (final langEntry in val.entries) {
          if (langEntry.value != null) {
            inner[langEntry.key.toString()] = langEntry.value.toString();
          }
        }
        if (inner.isNotEmpty) {
          mapped[key] = inner;
        }
      }
    }
    return mapped;
  }

  void _emitNotice(
    String message, {
    bool isError = false,
    bool isCelebration = false,
  }) {
    _noticeSeq += 1;
    state = state.copyWith(
      notice: UiBannerNotice(
        id: _noticeSeq,
        message: message,
        isError: isError,
        isCelebration: isCelebration,
      ),
    );
  }

  void clearNotice() {
    state = state.copyWith(clearNotice: true);
  }

  void _persistSession(UserProfile? profile) {
    final prefs = ref.read(sharedPrefsProvider);
    final socket = ref.read(socketClientProvider);
    if (profile == null) {
      prefs.remove(_kSavedSession);
      socket.setAuthToken(null);
    } else {
      prefs.setString(_kSavedSession, jsonEncode(profile.toJson()));
      socket.setAuthToken(profile.token);
    }
  }

  void _onSocketEvent(WsIncomingEvent event) {
    final prefs = ref.read(sharedPrefsProvider);
    final payload = event.payload;

    switch (event.type) {
      case 'initial_products':
      case 'products_updated':
        if (payload is List) {
          final parsed = payload
              .whereType<Map>()
              .map((e) => ProductItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false);
          state = state.copyWith(products: parsed);
          _scheduleCacheWrite(
            prefs,
            _kCachedProducts,
            () => parsed.map((e) => e.toJson()).toList(growable: false),
          );
        }
        break;

      case 'initial_categories':
      case 'categories_updated':
        if (payload is List) {
          final parsed = payload
              .whereType<Map>()
              .map((e) => CategoryItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false);
          state = state.copyWith(categories: parsed);
          _scheduleCacheWrite(
            prefs,
            _kCachedCategories,
            () => parsed.map((e) => e.toJson()).toList(growable: false),
          );
        }
        break;

      case 'initial_bundles':
      case 'bundles_updated':
        if (payload is List) {
          final parsed = payload
              .whereType<Map>()
              .map((e) => BundleOffer.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false);
          state = state.copyWith(bundles: parsed);
          _scheduleCacheWrite(
            prefs,
            _kCachedBundles,
            () => parsed.map((e) => e.toJson()).toList(growable: false),
          );
        }
        break;

      case 'admin_bundles_updated':
        if (payload is List) {
          final parsed = payload
              .whereType<Map>()
              .map((e) => BundleOffer.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false);
          state = state.copyWith(adminBundles: parsed);
        }
        break;

      case 'initial_translations':
      case 'translations_updated':
        final merged = <String, Map<String, String>>{
          ...state.translations,
          ..._parseTranslationsPayload(payload),
        };
        state = state.copyWith(translations: merged);
        _scheduleCacheWrite(prefs, _kCachedTranslations, () => merged);
        break;

      case 'initial_canteen_status':
      case 'canteen_status_updated':
        if (payload is Map) {
          state = state.copyWith(isCanteenOpen: payload['isOpen'] == true);
        }
        break;

      case 'initial_payment_methods':
      case 'payment_methods_updated':
        if (payload is Map) {
          state = state.copyWith(
            paymentMethods: PaymentMethodsConfig.fromJson(
              Map<String, dynamic>.from(payload),
            ),
          );
        }
        break;

      case 'login_success':
      case 'register_success':
        if (payload is Map) {
          final user = UserProfile(
            email: (payload['email'] as String?) ?? '',
            role: UserRole.student,
            profilePic: (payload['profilePic'] as String?) ?? 'pic2',
            balance: (payload['balance'] as num?)?.toDouble() ?? 0,
            token: payload['token'] as String?,
          );
          _persistSession(user);
          state = state.copyWith(currentUser: user, authBusy: false);
          _completeAuth(null);
        }
        break;

      case 'login_error':
      case 'register_error':
      case 'admin_login_error':
        final errMsg = (payload is Map ? payload['message']?.toString() : null) ??
            'Authentication failed.';
        state = state.copyWith(authBusy: false);
        _completeAuth(errMsg);
        break;

      case 'admin_login_success':
        if (payload is Map) {
          final admin = UserProfile(
            email: (payload['email'] as String?) ?? 'admin@canteen.app',
            role: UserRole.admin,
            profilePic: 'pic1',
            token: payload['token'] as String?,
          );
          _persistSession(admin);
          state = state.copyWith(currentUser: admin, authBusy: false);
          _completeAuth(null);
        }
        break;

      case 'session_restored':
        if (payload is Map) {
          final role = payload['role'] == 'admin'
              ? UserRole.admin
              : UserRole.student;
          final current = state.currentUser;
          final updated = UserProfile(
            email: (payload['email'] as String?) ?? current?.email ?? '',
            role: role,
            profilePic:
                (payload['profilePic'] as String?) ??
                current?.profilePic ??
                'pic2',
            balance:
                (payload['balance'] as num?)?.toDouble() ??
                current?.balance ??
                0,
            token: current?.token,
          );
          _persistSession(updated);
          state = state.copyWith(currentUser: updated);
        }
        break;

      case 'session_expired':
      case 'admin_auth_required':
        if (state.currentUser != null && state.currentUser!.role != UserRole.guest) {
          _persistSession(null);
          state = state.copyWith(clearUser: true);
        }
        break;

      case 'wallet_balance_updated':
        if (payload is Map && state.currentUser != null) {
          final nextBal = (payload['balance'] as num?)?.toDouble();
          if (nextBal != null) {
            final updated = state.currentUser!.copyWith(balance: nextBal);
            _persistSession(updated);
            state = state.copyWith(currentUser: updated);
          }
        }
        break;

      case 'my_orders':
        if (payload is List) {
          final orders = payload
              .whereType<Map>()
              .map((e) => CanteenOrder.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false);
          state = state.copyWith(myOrders: orders);
        }
        break;

      case 'my_order_updated':
        if (payload is Map && payload['updatedOrder'] is Map) {
          final updatedOrder = CanteenOrder.fromJson(
            Map<String, dynamic>.from(payload['updatedOrder'] as Map),
          );
          final nextList = [
            for (final o in state.myOrders)
              if (o.id == updatedOrder.id) updatedOrder else o,
          ];
          if (!nextList.any((o) => o.id == updatedOrder.id)) {
            nextList.insert(0, updatedOrder);
          }
          state = state.copyWith(myOrders: nextList);

          if (updatedOrder.status == OrderStatus.delivered) {
            final translator = ref.read(i18nProvider);
            _emitNotice(
              translator.t('order_ready_toast', {
                'num': updatedOrder.pickupNumber,
              }),
              isCelebration: true,
            );
          }
        }
        break;

      case 'order_confirmed_by_server':
        if (payload is Map) {
          final confirmed = CanteenOrder.fromJson(
            Map<String, dynamic>.from(payload),
          );
          final existing = state.myOrders
              .where((o) => o.id != confirmed.id)
              .toList();
          state = state.copyWith(
            checkoutBusy: false,
            lastConfirmedOrder: confirmed,
            myOrders: [confirmed, ...existing],
          );
          ref.read(cartProvider.notifier).clear();
          _completeCheckout(confirmed);
        }
        break;

      case 'order_rejected':
        final reason = payload is Map ? payload['reason']?.toString() : 'Error';
        state = state.copyWith(checkoutBusy: false);
        _emitNotice('Order rejected: ${reason ?? "Unavailable"}', isError: true);
        _completeCheckout(null);
        break;

      case 'initial_orders':
        if (payload is List) {
          final orders = payload
              .whereType<Map>()
              .map((e) => CanteenOrder.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false);
          state = state.copyWith(adminOrders: orders);
        }
        break;

      case 'new_order':
        if (payload is Map) {
          final order = CanteenOrder.fromJson(
            Map<String, dynamic>.from(payload),
          );
          final rest = state.adminOrders
              .where((o) => o.id != order.id)
              .toList();
          state = state.copyWith(
            adminOrders: [order, ...rest],
            adminNewOrderTick: state.adminNewOrderTick + 1,
          );
        }
        break;

      case 'order_status_updated_broadcast':
        if (payload is Map && payload['updatedOrder'] is Map) {
          final updated = CanteenOrder.fromJson(
            Map<String, dynamic>.from(payload['updatedOrder'] as Map),
          );
          state = state.copyWith(
            adminOrders: [
              for (final o in state.adminOrders)
                if (o.id == updated.id) updated else o,
            ],
          );
        }
        break;

      case 'analytics_data':
        if (payload is Map) {
          state = state.copyWith(
            analytics: AnalyticsSnapshot.fromJson(
              Map<String, dynamic>.from(payload),
            ),
          );
        }
        break;

      case 'admin_wallets_data':
        if (payload is Map) {
          final isBroadcastRefresh = payload['isBroadcastRefresh'] == true;
          final cur = state.walletsSnapshot;
          if (isBroadcastRefresh &&
              (cur.offset > 0 || cur.query.isNotEmpty || cur.users.isNotEmpty)) {
            break;
          }
          state = state.copyWith(
            walletsSnapshot: AdminWalletsSnapshot.fromJson(
              Map<String, dynamic>.from(payload),
            ),
          );
        }
        break;

      case 'admin_wallet_entry_updated':
        if (payload is Map) {
          final rawUser = payload['user'];
          final updatedUser = rawUser is Map
              ? WalletUserSummary.fromJson(Map<String, dynamic>.from(rawUser))
              : null;
          final rawTxs = payload['recentTransactions'];
          final parsedTxs = rawTxs is List
              ? rawTxs
                    .whereType<Map>()
                    .map(
                      (e) => WalletTransactionItem.fromJson(
                        Map<String, dynamic>.from(e),
                      ),
                    )
                    .toList(growable: false)
              : null;

          final cur = state.walletsSnapshot;
          final updatedUsers = updatedUser == null
              ? cur.users
              : cur.users
                    .map(
                      (u) => u.email.toLowerCase() ==
                              updatedUser.email.toLowerCase()
                          ? updatedUser
                          : u,
                    )
                    .toList(growable: false);

          state = state.copyWith(
            walletsSnapshot: cur.copyWith(
              users: updatedUsers,
              recentTransactions: parsedTxs ?? cur.recentTransactions,
            ),
          );
        }
        break;

      case 'request_error':
        if (payload is Map && payload['message'] != null) {
          _emitNotice(payload['message'].toString(), isError: true);
        }
        break;
    }
  }

  void _completeAuth(String? errorMessage) {
    final c = _pendingAuthCompleter;
    _pendingAuthCompleter = null;
    if (c != null && !c.isCompleted) {
      c.complete(errorMessage);
    }
  }

  void _completeCheckout(CanteenOrder? order) {
    final c = _pendingCheckoutCompleter;
    _pendingCheckoutCompleter = null;
    if (c != null && !c.isCompleted) {
      c.complete(order);
    }
  }

  Future<String?> loginStudent({
    required String email,
    required String password,
  }) {
    return _performAuthRequest('login_user', {
      'email': email.trim(),
      'password': password,
    });
  }

  Future<String?> registerStudent({
    required String email,
    required String password,
    required String profilePic,
  }) {
    return _performAuthRequest('register_user', {
      'email': email.trim(),
      'password': password,
      'profilePic': profilePic,
    });
  }

  Future<String?> loginAdmin({
    required String email,
    required String password,
  }) {
    return _performAuthRequest('admin_login', {
      'email': email.trim(),
      'password': password,
    });
  }

  Future<String?> _performAuthRequest(
    String eventType,
    Map<String, dynamic> payload,
  ) async {
    final socket = ref.read(socketClientProvider);
    if (!socket.isConnected) {
      return 'Not connected to canteen server yet.';
    }
    _pendingAuthCompleter = Completer<String?>();
    state = state.copyWith(authBusy: true);
    socket.send(eventType, payload);

    return _pendingAuthCompleter!.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        state = state.copyWith(authBusy: false);
        _pendingAuthCompleter = null;
        return 'Request timed out. Please try again.';
      },
    );
  }

  void enterBrowseGuestMode() {
    state = state.copyWith(
      currentUser: const UserProfile(
        email: 'Guest',
        role: UserRole.guest,
        profilePic: 'pic2',
      ),
    );
  }

  void logout() {
    _persistSession(null);
    state = state.copyWith(
      clearUser: true,
      myOrders: const [],
      adminOrders: const [],
    );
    ref.read(socketClientProvider).reconnectNow();
  }

  Future<CanteenOrder?> submitOrder({required String paymentMethod}) async {
    final socket = ref.read(socketClientProvider);
    final summary = ref.read(cartPricingProvider);
    final productsMap = state.productsById;
    final user = state.currentUser;

    if (summary.isEmpty) return null;
    if (!socket.isConnected) {
      _emitNotice('Cannot place order while reconnecting.', isError: true);
      return null;
    }

    final itemsPayload = <Map<String, dynamic>>[];
    for (final entry in summary.quantities.entries) {
      final prod = productsMap[entry.key];
      if (prod == null || entry.value <= 0) continue;
      itemsPayload.add({
        'id': prod.id,
        'quantity': entry.value,
        'price': prod.price,
        'isDiscount': false,
        'name_key': prod.nameKey,
      });
    }

    for (final applied in summary.appliedDiscounts) {
      itemsPayload.add({
        'id':
            'discount-${applied.bundle.id}-${DateTime.now().millisecondsSinceEpoch}',
        'bundleId': applied.bundle.id,
        'quantity': 1,
        'price': -applied.discountAmount,
        'isDiscount': true,
        'name_key': 'bundle_discount_applied',
      });
    }

    _pendingCheckoutCompleter = Completer<CanteenOrder?>();
    state = state.copyWith(checkoutBusy: true);

    socket.send('place_order', {
      'id': 'TEMP-${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'items': itemsPayload,
      'totalAmount': double.parse(summary.finalTotal.toStringAsFixed(2)),
      'status': 'pending',
      'paymentMethod': paymentMethod,
      'user': (user != null && user.role == UserRole.student)
          ? {'email': user.email, 'profilePic': user.profilePic}
          : null,
    });

    return _pendingCheckoutCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        state = state.copyWith(checkoutBusy: false);
        _pendingCheckoutCompleter = null;
        _emitNotice('Order confirmation timed out.', isError: true);
        return null;
      },
    );
  }

  // --- Admin Mutations ---
  void updateOrderStatus(String orderId, OrderStatus nextStatus) {
    ref.read(socketClientProvider).send('update_order_status', {
      'orderId': orderId,
      'newStatus': nextStatus.wireValue,
    });
  }

  void setCanteenOpen(bool isOpen) {
    state = state.copyWith(isCanteenOpen: isOpen);
    ref.read(socketClientProvider).send('admin_set_canteen_status', {
      'isOpen': isOpen,
    });
  }

  void requestAnalytics({int? month, int? year}) {
    final now = DateTime.now();
    ref.read(socketClientProvider).send('get_analytics_data', {
      'month': month ?? state.analytics?.selectedMonth ?? now.month,
      'year': year ?? state.analytics?.selectedYear ?? now.year,
    });
  }

  void requestWallets({String query = '', int limit = 5, int offset = 0}) {
    ref.read(socketClientProvider).send('admin_get_users_wallets', {
      'query': query.trim(),
      'limit': limit,
      'offset': offset < 0 ? 0 : offset,
    });
  }

  void adjustStudentWallet({
    required String email,
    required String mode,
    required double amount,
    required String reason,
  }) {
    ref.read(socketClientProvider).send('admin_adjust_wallet', {
      'email': email,
      'mode': mode,
      'amount': amount,
      'reason': reason,
    });
  }

  void updatePaymentMethods(PaymentMethodsConfig config) {
    state = state.copyWith(paymentMethods: config);
    ref
        .read(socketClientProvider)
        .send('admin_payment_methods_updated', config.toJson());
  }

  void updateCurrency({required String enSymbol, required String arSymbol}) {
    ref.read(socketClientProvider).send('admin_currency_updated', {
      'currency': {'en': enSymbol.trim(), 'ar': arSymbol.trim()},
    });
  }

  void saveProduct({
    required bool isNew,
    required ProductItem product,
    required String nameEn,
    required String nameAr,
    required String descEn,
    required String descAr,
  }) {
    final translations = {
      product.nameKey: {'en': nameEn.trim(), 'ar': nameAr.trim()},
      product.descriptionKey: {'en': descEn.trim(), 'ar': descAr.trim()},
    };

    if (isNew) {
      ref.read(socketClientProvider).send('admin_product_added', {
        'categoryKey': product.categoryKey,
        'product': product.toJson(),
        'translations': translations,
      });
    } else {
      ref.read(socketClientProvider).send('admin_product_updated', {
        'productId': product.id,
        'updatedFields': {
          'price': product.price,
          'quantity': product.quantity,
          'image': product.image,
          'category': product.categoryKey,
          'name_key': product.nameKey,
          'description_key': product.descriptionKey,
        },
        'translations': translations,
      });
    }
  }

  void quickUpdateProductStockOrCategory(
    ProductItem product, {
    int? quantity,
    String? categoryKey,
  }) {
    final nextQty = quantity ?? product.quantity;
    final nextCat = categoryKey ?? product.categoryKey;
    ref.read(socketClientProvider).send('admin_product_updated', {
      'productId': product.id,
      'updatedFields': {
        'price': product.price,
        'quantity': nextQty,
        'image': product.image,
        'category': nextCat,
      },
    });
  }

  void deleteProduct(String productId) {
    ref.read(socketClientProvider).send('admin_product_removed', {
      'productId': productId,
    });
  }

  void saveCategory({
    required bool isNew,
    required String key,
    required String nameKey,
    required String nameEn,
    required String nameAr,
  }) {
    final translations = {
      nameKey: {'en': nameEn.trim(), 'ar': nameAr.trim()},
    };
    if (isNew) {
      ref.read(socketClientProvider).send('admin_category_added', {
        'category': {'key': key, 'name_key': nameKey},
        'translations': translations,
      });
    } else {
      ref.read(socketClientProvider).send('admin_category_updated', {
        'categoryKey': key,
        'nameKey': nameKey,
        'translations': translations,
      });
    }
  }

  void deleteCategory(String categoryKey) {
    ref.read(socketClientProvider).send('admin_category_deleted', {
      'categoryKey': categoryKey,
    });
  }

  void reorderCategories(List<CategoryItem> orderedCategories) {
    state = state.copyWith(categories: orderedCategories);
    ref.read(socketClientProvider).send(
      'admin_categories_reordered',
      orderedCategories.map((c) => c.toJson()).toList(growable: false),
    );
  }

  void saveBundle({
    required BundleOffer bundle,
    required String nameEn,
    required String nameAr,
    required String descEn,
    required String descAr,
  }) {
    ref.read(socketClientProvider).send('admin_bundle_saved', {
      'bundle': bundle.toJson(),
      'translations': {
        bundle.nameKey: {'en': nameEn.trim(), 'ar': nameAr.trim()},
        bundle.descriptionKey: {'en': descEn.trim(), 'ar': descAr.trim()},
      },
    });
  }

  void deleteBundle(String bundleId) {
    ref.read(socketClientProvider).send('admin_bundle_deleted', {
      'bundleId': bundleId,
    });
  }

  Future<String?> uploadProductPhoto({
    required Uint8List bytes,
    required String mimeType,
  }) {
    return ref
        .read(socketClientProvider)
        .uploadProductImage(bytes: bytes, mimeType: mimeType);
  }

  String exportCatalogConfigJson() {
    final relatedTranslations = <String, Map<String, String>>{};
    for (final cat in state.categories) {
      if (state.translations[cat.nameKey] != null) {
        relatedTranslations[cat.nameKey] = state.translations[cat.nameKey]!;
      }
    }
    for (final prod in state.products) {
      if (state.translations[prod.nameKey] != null) {
        relatedTranslations[prod.nameKey] = state.translations[prod.nameKey]!;
      }
      if (state.translations[prod.descriptionKey] != null) {
        relatedTranslations[prod.descriptionKey] =
            state.translations[prod.descriptionKey]!;
      }
    }

    final payload = {
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'categories': state.categories.map((c) => c.toJson()).toList(),
      'products': state.products.map((p) => p.toJson()).toList(),
      'productRelatedTranslations': relatedTranslations,
      'currency': state.translations['currency_symbol'] ??
          {'en': 'L.E', 'ar': 'ج.م'},
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  bool importCatalogConfigJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) return false;
      if (decoded['categories'] is! List || decoded['products'] is! List) {
        return false;
      }
      return ref
          .read(socketClientProvider)
          .send('admin_config_imported', decoded);
    } catch (_) {
      return false;
    }
  }
}

final canteenStoreProvider =
    NotifierProvider<CanteenStoreNotifier, CanteenStoreState>(
      CanteenStoreNotifier.new,
    );

class CartNotifier extends Notifier<Map<String, int>> {
  static const _kCartKey = 'eva_saved_cart_v2';

  @override
  Map<String, int> build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final raw = prefs.getString(_kCartKey);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final restored = <String, int>{};
      for (final entry in decoded.entries) {
        final q = (entry.value as num?)?.toInt() ?? 0;
        if (q > 0) restored[entry.key] = q;
      }
      return restored;
    } catch (_) {
      return const {};
    }
  }

  void _save(Map<String, int> next) {
    state = Map<String, int>.unmodifiable(next);
    ref.read(sharedPrefsProvider).setString(_kCartKey, jsonEncode(next));
  }

  bool increment(ProductItem product) {
    if (product.isOutOfStock || product.isArchived) return false;
    final currentQty = state[product.id] ?? 0;
    if (!product.isUnlimited && currentQty >= product.quantity) {
      return false;
    }
    final next = Map<String, int>.from(state);
    next[product.id] = currentQty + 1;
    _save(next);
    return true;
  }

  void decrement(String productId) {
    final currentQty = state[productId] ?? 0;
    if (currentQty <= 0) return;
    final next = Map<String, int>.from(state);
    if (currentQty == 1) {
      next.remove(productId);
    } else {
      next[productId] = currentQty - 1;
    }
    _save(next);
  }

  void removeItem(String productId) {
    if (!state.containsKey(productId)) return;
    final next = Map<String, int>.from(state)..remove(productId);
    _save(next);
  }

  bool addBundleOrCombo(
    BundleOffer bundle,
    Map<String, ProductItem> productsById,
  ) {
    final next = Map<String, int>.from(state);
    for (final itemId in bundle.itemIds) {
      final prod = productsById[itemId];
      if (prod == null || prod.isOutOfStock || prod.isArchived) {
        return false;
      }
      final desired = (next[itemId] ?? 0) + 1;
      if (!prod.isUnlimited && desired > prod.quantity) {
        return false;
      }
      next[itemId] = desired;
    }
    _save(next);
    return true;
  }

  int reorderAvailableItems(
    CanteenOrder pastOrder,
    Map<String, ProductItem> productsById,
  ) {
    final next = Map<String, int>.from(state);
    var addedCount = 0;
    for (final line in pastOrder.regularItems) {
      final prod = productsById[line.id];
      if (prod == null || prod.isOutOfStock || prod.isArchived) continue;
      final cur = next[prod.id] ?? 0;
      final allowed = prod.isUnlimited
          ? cur + line.quantity
          : (cur + line.quantity).clamp(0, prod.quantity);
      if (allowed > cur) {
        next[prod.id] = allowed;
        addedCount += (allowed - cur);
      }
    }
    _save(next);
    return addedCount;
  }

  void clear() {
    _save(const {});
  }
}

final cartProvider = NotifierProvider<CartNotifier, Map<String, int>>(
  CartNotifier.new,
);

final cartPricingProvider = Provider<CartPricingSummary>((ref) {
  final rawQuantities = ref.watch(cartProvider);
  final (productsById, bundles) = ref.watch(
    canteenStoreProvider.select((s) => (s.productsById, s.bundles)),
  );

  final validQuantities = <String, int>{};
  double subtotal = 0;

  for (final entry in rawQuantities.entries) {
    final prod = productsById[entry.key];
    if (prod == null || prod.isArchived || prod.isOutOfStock) continue;
    final clampedQty = prod.isUnlimited
        ? entry.value
        : entry.value.clamp(0, prod.quantity);
    if (clampedQty > 0) {
      validQuantities[prod.id] = clampedQty;
      subtotal += prod.price * clampedQty;
    }
  }

  final appliedDiscounts = <AppliedBundleDiscount>[];
  double totalDiscount = 0;

  for (final bundle in bundles) {
    if (!bundle.active ||
        bundle.isSuggestion ||
        bundle.discountPercent <= 0 ||
        bundle.itemIds.isEmpty) {
      continue;
    }

    var qualifies = true;
    double bundleOriginalSum = 0;
    for (final reqId in bundle.itemIds) {
      final qty = validQuantities[reqId] ?? 0;
      final prod = productsById[reqId];
      if (qty < 1 || prod == null) {
        qualifies = false;
        break;
      }
      bundleOriginalSum += prod.price;
    }

    if (qualifies && bundleOriginalSum > 0) {
      final discountedPrice =
          (bundleOriginalSum * ((100 - bundle.discountPercent) / 100))
              .roundToDouble();
      final discountVal = (bundleOriginalSum - discountedPrice).clamp(
        0.0,
        subtotal,
      );
      if (discountVal > 0) {
        appliedDiscounts.add(
          AppliedBundleDiscount(bundle: bundle, discountAmount: discountVal),
        );
        totalDiscount += discountVal;
      }
    }
  }

  final clampedDiscount = totalDiscount.clamp(0.0, subtotal);
  final finalTotal = double.parse(
    (subtotal - clampedDiscount).clamp(0.0, double.infinity).toStringAsFixed(2),
  );

  return CartPricingSummary(
    quantities: validQuantities,
    subtotal: double.parse(subtotal.toStringAsFixed(2)),
    appliedDiscounts: appliedDiscounts,
    totalDiscount: double.parse(clampedDiscount.toStringAsFixed(2)),
    finalTotal: finalTotal,
  );
});

final i18nProvider = Provider<EvaTranslator>((ref) {
  final lang = ref.watch(
    appPreferencesProvider.select((s) => s.locale.languageCode),
  );
  final cms = ref.watch(canteenStoreProvider.select((s) => s.translations));
  return EvaTranslator(langCode: lang, cmsTranslations: cms);
});
