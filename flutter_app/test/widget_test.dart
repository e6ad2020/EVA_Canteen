import 'package:eva_canteen/core/models/domain_models.dart';
import 'package:eva_canteen/core/network/eva_socket_client.dart';
import 'package:eva_canteen/core/state/canteen_providers.dart';
import 'package:eva_canteen/design_system/eva_theme.dart';
import 'package:eva_canteen/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'CartPricingSummary calculates automatic % OFF bundle discounts accurately',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockSocket = EvaSocketClient(enableNetwork: false);

      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          socketClientProvider.overrideWithValue(mockSocket),
        ],
      );
      addTearDown(container.dispose);

      // Activate canteenStoreProvider listener
      container.read(canteenStoreProvider);

      mockSocket.injectTestEvent('initial_products', [
        {
          'id': 'prod-1',
          'name_key': 'item_sandwich',
          'description_key': 'desc_sandwich',
          'price': 25,
          'quantity': 20,
          'image': '',
          'category': 'sandwiches',
        },
        {
          'id': 'prod-2',
          'name_key': 'item_juice',
          'description_key': 'desc_juice',
          'price': 15,
          'quantity': 20,
          'image': '',
          'category': 'drinks',
        },
      ]);

      mockSocket.injectTestEvent('initial_bundles', [
        {
          'id': 'bundle-breakfast',
          'name_key': 'bundle_breakfast_name',
          'description_key': 'bundle_breakfast_desc',
          'itemIds': ['prod-1', 'prod-2'],
          'discountPercent': 15,
          'isSuggestion': false,
          'active': true,
        },
      ]);

      await Future<void>.delayed(Duration.zero);

      final store = container.read(canteenStoreProvider);
      expect(store.products.length, 2);

      final cart = container.read(cartProvider.notifier);
      cart.increment(store.productsById['prod-1']!);
      var pricing = container.read(cartPricingProvider);
      expect(pricing.subtotal, 25);
      expect(pricing.totalDiscount, 0);
      expect(pricing.finalTotal, 25);

      // Adding the second bundle item unlocks the 15% discount on (25 + 15 = 40 -> 34, save 6)
      cart.increment(store.productsById['prod-2']!);
      pricing = container.read(cartPricingProvider);
      expect(pricing.subtotal, 40);
      expect(pricing.totalDiscount, 6);
      expect(pricing.finalTotal, 34);
      expect(pricing.appliedDiscounts.length, 1);
    },
  );

  testWidgets(
    'Welcome screen switches EN <-> AR RTL instantly and enters Guest Menu',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockSocket = EvaSocketClient(enableNetwork: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            socketClientProvider.overrideWithValue(mockSocket),
          ],
          child: const EvaCanteenApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify English LTR on Welcome screen with modern retail copy
      expect(find.text('Order ahead, skip the wait.'), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.text('Order ahead, skip the wait.')),
        ),
        TextDirection.ltr,
      );

      // Tap Arabic quick toggle ('عربي')
      await tester.tap(find.text('عربي'));
      await tester.pumpAndSettle();

      expect(
        find.text('اطلب مسبقاً، واستلم بدون انتظار.'),
        findsOneWidget,
      );
      expect(
        Directionality.of(
          tester.element(find.text('اطلب مسبقاً، واستلم بدون انتظار.')),
        ),
        TextDirection.rtl,
      );

      // Enter Guest Browse Menu mode
      await tester.tap(find.text('تصفح القائمة كزائر'));
      await tester.pumpAndSettle();

      // Should now be on Menu screen in Arabic
      expect(find.text('القائمة'), findsWidgets);
    },
  );

  testWidgets(
    'Menu displays products and inline stepper updates animated checkout dock',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockSocket = EvaSocketClient(enableNetwork: false);

      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          socketClientProvider.overrideWithValue(mockSocket),
        ],
      );
      addTearDown(container.dispose);

      container.read(canteenStoreProvider.notifier).enterBrowseGuestMode();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EvaCanteenApp(),
        ),
      );
      await tester.pumpAndSettle();

      mockSocket.injectTestEvent('initial_categories', [
        {
          'key': 'sandwiches',
          'name_key': 'cat_sandwiches',
          'productIds': ['p1'],
        },
      ]);
      mockSocket.injectTestEvent('initial_translations', {
        'cat_sandwiches': {'en': 'Sandwiches', 'ar': 'الساندويتشات'},
        'item_panini': {'en': 'Grilled Turkey Panini', 'ar': 'بانيني رومي'},
        'desc_panini': {'en': 'Toasted artisan bread', 'ar': 'خبز محمص طازج'},
      });
      mockSocket.injectTestEvent('initial_products', [
        {
          'id': 'p1',
          'name_key': 'item_panini',
          'description_key': 'desc_panini',
          'price': 45,
          'quantity': 10,
          'image': '',
          'category': 'sandwiches',
        },
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Grilled Turkey Panini'), findsOneWidget);

      // Tap Add button on product card
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(container.read(cartProvider)['p1'], 1);
      expect(find.text('Review order'), findsOneWidget);
    },
  );

  testWidgets(
    'Admin KDS renders live Kanban columns and Order Ticket pickup numbers',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final adminProfile = const UserProfile(
        email: 'admin@canteen.app',
        role: UserRole.admin,
        token: 'test-jwt',
      );
      SharedPreferences.setMockInitialValues({
        'eva_saved_session_v2':
            '{"email":"${adminProfile.email}","role":"admin","profilePic":"pic1","balance":0,"token":"test-jwt"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final mockSocket = EvaSocketClient(enableNetwork: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            socketClientProvider.overrideWithValue(mockSocket),
          ],
          child: const EvaCanteenApp(),
        ),
      );
      await tester.pump();

      mockSocket.injectTestEvent('initial_translations', {
        'item_coffee': {'en': 'Iced Latte', 'ar': 'آيس لاتيه'},
      });
      mockSocket.injectTestEvent('initial_orders', [
        {
          'id': 'ORD-07-1700000000',
          'totalAmount': 35,
          'status': 'pending',
          'paymentMethod': 'wallet',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'items': [
            {
              'id': 'p-latte',
              'quantity': 1,
              'price': 35,
              'name_key': 'item_coffee',
              'isDiscount': false,
            },
          ],
          'user': {'email': 'eyad@example.com', 'profilePic': 'pic2'},
        },
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('#07'), findsOneWidget);
      expect(find.text('eyad@example.com'), findsOneWidget);
      expect(find.text('Iced Latte'), findsOneWidget);
      expect(find.text('Start preparing'), findsOneWidget);
    },
  );

  testWidgets(
    'Narrow 360x800 phone viewport renders Welcome, Menu, and Admin Operations without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({
        'eva_saved_session_v2':
            '{"email":"admin@canteen.app","role":"admin","profilePic":"pic1","balance":0,"token":"test-jwt"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final mockSocket = EvaSocketClient(enableNetwork: false);

      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          socketClientProvider.overrideWithValue(mockSocket),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EvaCanteenApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Navigate to Operations tab on 5-tab mobile bottom bar
      await tester.tap(find.text('Operations'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Inject an extremely long unspaced email to verify zero horizontal overflow
      mockSocket.injectTestEvent('users_list', [
        {
          'email':
              'tttttttttttttttttttttttttttttttttttttttttttttttttttttttt@example.com',
          'role': 'student',
          'profilePic': 'pic3',
          'balance': 250,
        },
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch to Arabic RTL on 360dp phone and verify zero overflow across tabs
      await tester.tap(find.text('عربي'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Light Blue and Light Red themes activate Liquid Glass tokens and illustrated wallpapers',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockSocket = EvaSocketClient(enableNetwork: false);

      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          socketClientProvider.overrideWithValue(mockSocket),
        ],
      );
      addTearDown(container.dispose);

      // Start in Dark mode first to verify Light Blue/Red automatically switches to Daylight Liquid Glass
      container
          .read(appPreferencesProvider.notifier)
          .setSurfaceMode(EvaSurfaceMode.nightShift);
      container.read(canteenStoreProvider.notifier).enterBrowseGuestMode();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EvaCanteenApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Open Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Select 'Light Blue' theme
      await tester.tap(find.text('Light Blue'));
      await tester.pumpAndSettle();

      var appPrefs = container.read(appPreferencesProvider);
      expect(appPrefs.accentPreset, EvaAccentPreset.lightBlue);
      expect(appPrefs.surfaceMode, EvaSurfaceMode.daylight);

      var tokens = EvaTokens.of(tester.element(find.text('Light Blue')));
      expect(tokens.isLiquidGlass, isTrue);
      expect(tokens.brandPrimary, const Color(0xFF0D47A1));
      expect(
        tokens.wallpaperFolder,
        'assets/images/wallpapers/light_blue',
      );

      expect(find.byType(BackdropFilter), findsNothing);

      // Select 'Light Red' theme
      await tester.tap(find.text('Light Red'));
      await tester.pumpAndSettle();

      appPrefs = container.read(appPreferencesProvider);
      expect(appPrefs.accentPreset, EvaAccentPreset.lightRed);
      expect(appPrefs.surfaceMode, EvaSurfaceMode.daylight);

      tokens = EvaTokens.of(tester.element(find.text('Light Red')));
      expect(tokens.isLiquidGlass, isTrue);
      expect(tokens.brandPrimary, const Color(0xFFB71C1C));
      expect(
        tokens.wallpaperFolder,
        'assets/images/wallpapers/light_red',
      );
      expect(find.byType(BackdropFilter), findsNothing);
    },
  );

  testWidgets(
    'Redesigned WelcomeAuthScreen has no top bar and scrolls cleanly on 360x800 phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockSocket = EvaSocketClient(enableNetwork: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            socketClientProvider.overrideWithValue(mockSocket),
          ],
          child: const EvaCanteenApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify top bar is completely gone on the landing/login screen
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Welcome back'), findsOneWidget);

      // Switch to Create account mode (reveals avatar picker) and scroll
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Create your account'), findsOneWidget);

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
