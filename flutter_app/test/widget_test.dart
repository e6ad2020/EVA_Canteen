import 'dart:async';

import 'package:eva_canteen/core/media/eva_image_cache.dart';
import 'package:eva_canteen/core/models/domain_models.dart';
import 'package:eva_canteen/core/network/eva_socket_client.dart';
import 'package:eva_canteen/core/notifications/notification_providers.dart';
import 'package:eva_canteen/core/notifications/notification_service.dart';
import 'package:eva_canteen/core/state/canteen_providers.dart';
import 'package:eva_canteen/design_system/eva_theme.dart';
import 'package:eva_canteen/design_system/widgets/eva_widgets.dart';
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

      // Verify English LTR on Welcome screen with hero Logo (and no duplicate EVA Canteen text)
      expect(find.byType(EvaBrandLogo), findsOneWidget);
      expect(find.text('EVA Canteen'), findsNothing);
      expect(find.text('Order ahead, skip the wait.'), findsNothing);
      expect(
        Directionality.of(tester.element(find.text('Welcome back'))),
        TextDirection.ltr,
      );

      // Tap subtle Arabic footer link ('عربي')
      await tester.ensureVisible(find.text('عربي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('عربي'));
      await tester.pumpAndSettle();

      expect(find.text('كانتين إيفا'), findsNothing);
      expect(
        Directionality.of(tester.element(find.text('أهلاً بك مجدداً'))),
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

      // Verify top bar has no language trigger, then switch to Arabic via Settings tab
      expect(find.text('عربي'), findsNothing);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('العربية'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.bySemanticsLabel('العمليات'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Light Blue is the default theme and Light Red activates wallpaper tokens cleanly',
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

      // Verify Light Blue is the out-of-the-box default theme
      expect(
        container.read(appPreferencesProvider).accentPreset,
        EvaAccentPreset.lightBlue,
      );
      expect(
        container.read(appPreferencesProvider).surfaceMode,
        EvaSurfaceMode.daylight,
      );

      // Switch to Dark mode first to verify selecting Light Blue/Red restores Daylight wallpaper mode
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
      expect(tokens.logoFill, const Color(0xFF5CE1E6));
      expect(tokens.logoOutline, const Color(0xFF3B01D9));
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
      expect(tokens.logoFill, const Color(0xFFFF9E9E));
      expect(tokens.logoOutline, const Color(0xFF8E001C));
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

      // Enter Guest Menu on 360x800 phone and verify 2-column grid + rounded top bar
      await tester.ensureVisible(find.text('Browse menu as guest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browse menu as guest'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      mockSocket.injectTestEvent('initial_products', [
        {
          'id': 'g1',
          'name_key': 'item_1',
          'description_key': 'desc_1',
          'price': 35,
          'quantity': 10,
          'image': '',
          'category': 'sandwiches',
        },
        {
          'id': 'g2',
          'name_key': 'item_2',
          'description_key': 'desc_2',
          'price': 50,
          'quantity': 4,
          'image': '',
          'category': 'sandwiches',
        },
        {
          'id': 'g3',
          'name_key': 'item_3',
          'description_key': 'desc_3',
          'price': 125.50,
          'quantity': -1,
          'image': '',
          'category': 'drinks',
        },
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);

      // Scroll menu to exercise animated rounded top bar scroll state
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify EvaFloatingNavBar is active on mobile (< 840dp) with zero BackdropFilter
      expect(find.byType(EvaFloatingNavBar), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);

      // Add an item to cart on mobile and verify checkout dock sits completely above EvaFloatingNavBar
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 120));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();
      expect(find.text('Review order'), findsOneWidget);

      final dockRect = tester.getRect(
        find.byKey(const ValueKey('checkout_dock_visible')),
      );
      final navBarRect = tester.getRect(find.byType(EvaFloatingNavBar));
      expect(dockRect.bottom, lessThanOrEqualTo(navBarRect.top));

      // Scrub horizontally across EvaFloatingNavBar from Menu (left) to Settings (right)
      final navCenterLeft = Offset(
        navBarRect.left + 44,
        navBarRect.center.dy,
      );
      final navDragDistance = Offset(navBarRect.width - 88, 0);
      await tester.timedDragFrom(
        navCenterLeft,
        navDragDistance,
        const Duration(milliseconds: 220),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Light Blue'), findsOneWidget);
    },
  );

  testWidgets(
    'Navbar hold-and-move jelly physics, adaptive scroll label hide + Settings toggle, and unblocked flush-aligned ItemDetailBottomSheet CTA work on 360x800 phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
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

      expect(
        container.read(appPreferencesProvider).navBarBehavior,
        EvaNavBarBehavior.adaptive,
      );

      container.read(canteenStoreProvider.notifier).enterBrowseGuestMode();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EvaCanteenApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Inject 10 products so the menu scrolls comfortably on 360x800
      mockSocket.injectTestEvent('initial_translations', {
        'item_club': {'en': 'Crispy Chicken Club', 'ar': 'كلوب دجاج مقرمش'},
        'desc_club': {
          'en': 'Double-layered toasted brioche',
          'ar': 'بريوش محمص طازج',
        },
      });
      mockSocket.injectTestEvent('initial_products', [
        for (int i = 1; i <= 10; i++)
          {
            'id': 'club_$i',
            'name_key': 'item_club',
            'description_key': 'desc_club',
            'price': 55,
            'quantity': 999,
            'image': '',
            'category': 'sandwiches',
          },
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 1. Open ItemDetailBottomSheet by tapping the first product title
      await tester.tap(find.text('Crispy Chicken Club').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify EvaQuantityStepper inside the sheet is 100% flush with the right content edge (360 - 20 = 340)
      final sheetCtaFinder = find.byKey(
        const ValueKey('item_detail_cta_button'),
      );
      expect(sheetCtaFinder, findsOneWidget);
      final sheetCtaRect = tester.getRect(sheetCtaFinder);
      final sheetStepperFinder = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(EvaQuantityStepper),
      );
      final sheetStepperRect = tester.getRect(sheetStepperFinder);
      expect((sheetStepperRect.right - sheetCtaRect.right).abs(), lessThan(1.0));

      // Verify tapping the bottom Add CTA button is NOT blocked by EvaFloatingNavBar
      await tester.tap(sheetCtaFinder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(sheetCtaFinder, findsNothing);
      expect(container.read(cartProvider)['club_1'], 1);

      // Reopen sheet when qty > 0 to verify `[ - 1 + ]` stepper stays flush right too
      await tester.tap(find.text('Crispy Chicken Club').first);
      await tester.pumpAndSettle();
      final activeStepperRect = tester.getRect(sheetStepperFinder);
      expect(
        (activeStepperRect.right - sheetCtaRect.right).abs(),
        lessThan(1.0),
      );
      await tester.tap(find.byKey(const ValueKey('item_detail_cta_button')));
      await tester.pumpAndSettle();

      // 2. Verify scrolling down collapses floating navbar labels (62dp + padding -> 48dp + padding)
      final expandedNavHeight = tester
          .getSize(find.byType(EvaFloatingNavBar))
          .height;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
      await tester.pumpAndSettle();
      final collapsedNavHeight = tester
          .getSize(find.byType(EvaFloatingNavBar))
          .height;
      expect(collapsedNavHeight, lessThan(expandedNavHeight - 10));

      // Scrolling back up restores floating navbar labels
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 260));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(EvaFloatingNavBar)).height,
        closeTo(expandedNavHeight, 1.0),
      );

      // 3. Hold pill & move with 2D vertical + horizontal tug (NuvioMobile jelly physics)
      final navRect = tester.getRect(find.byType(EvaFloatingNavBar));
      final holdGesture = await tester.startGesture(
        Offset(navRect.left + 44, navRect.center.dy),
      );
      // Hold in place to trigger press-and-hold pill inflation
      await tester.pump(const Duration(milliseconds: 140));
      expect(tester.takeException(), isNull);
      // Move horizontally + vertically to exercise 2D rubber-band & velocity stretch
      for (int step = 1; step <= 6; step++) {
        await holdGesture.moveBy(
          Offset((navRect.width - 88) / 6, step.isEven ? -6 : 4),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await holdGesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Should now be on Settings tab; customize navbar behavior ('Icons only' -> 'Always show')
      await tester.ensureVisible(find.text('Icons only'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Icons only'));
      await tester.pumpAndSettle();
      expect(
        container.read(appPreferencesProvider).navBarBehavior,
        EvaNavBarBehavior.compact,
      );
      expect(
        tester.getSize(find.byType(EvaFloatingNavBar)).height,
        closeTo(collapsedNavHeight, 1.0),
      );

      await tester.tap(find.text('Always show'));
      await tester.pumpAndSettle();
      expect(
        container.read(appPreferencesProvider).navBarBehavior,
        EvaNavBarBehavior.expanded,
      );
      expect(
        tester.getSize(find.byType(EvaFloatingNavBar)).height,
        closeTo(expandedNavHeight, 1.0),
      );
    },
  );

  testWidgets(
    'Admin Catalog Items tab renders menu-matched 2-col/4-col GridView and ranks items via 2D drag & 1-tap nudges',
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

      mockSocket.injectTestEvent('initial_categories', [
        {
          'key': 'sandwiches',
          'name_key': 'cat_sandwiches',
          'productIds': ['p1', 'p2', 'p3', 'p4'],
        },
        {'key': 'archive', 'name_key': 'sort_archive', 'productIds': []},
      ]);
      mockSocket.injectTestEvent('initial_translations', {
        'cat_sandwiches': {'en': 'Sandwiches', 'ar': 'الساندويتشات'},
        'item_p1': {'en': 'Alpha Panini', 'ar': 'بانيني ألفا'},
        'item_p2': {'en': 'Bravo Burger', 'ar': 'برجر برافو'},
        'item_p3': {'en': 'Crispy Club', 'ar': 'كلوب مقرمش'},
        'item_p4': {'en': 'Delta Wrap', 'ar': 'راب دلتا'},
      });
      mockSocket.injectTestEvent('initial_products', [
        for (int i = 1; i <= 4; i++)
          {
            'id': 'p$i',
            'name_key': 'item_p$i',
            'description_key': 'item_p$i',
            'price': 30 + i * 5,
            'quantity': 999,
            'image': '',
            'category': 'sandwiches',
          },
      ]);
      await tester.pumpAndSettle();

      // Open Admin Catalog tab
      await tester.tap(find.text('Catalog'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify full-bleed CustomScrollView (y == 0) + 2-column SliverGrid on 360dp phone
      expect(tester.getTopLeft(find.byType(CustomScrollView)).dy, 0.0);
      final gridFinder = find.byKey(const ValueKey('admin_catalog_items_grid'));
      expect(gridFinder, findsOneWidget);
      var gridDelegate =
          tester.widget<SliverGrid>(gridFinder).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(gridDelegate.crossAxisCount, 2);

      // Select Sandwiches category chip — stays a 2-column SliverGrid (not a 1-column list!)
      await tester.tap(find.widgetWithText(ChoiceChip, 'Sandwiches'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      gridDelegate =
          tester.widget<SliverGrid>(gridFinder).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(gridDelegate.crossAxisCount, 2);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
      expect(find.text('#4'), findsOneWidget);

      // Scroll slightly on 360x800 phone so row 2 sits completely above EvaFloatingNavBar
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
      await tester.pumpAndSettle();

      // 1-Tap Rank Nudge: move p3 (#3) earlier to #2
      await tester.tap(find.byKey(const ValueKey('rank_earlier_p3')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(container.read(canteenStoreProvider).categories.first.productIds, [
        'p1',
        'p3',
        'p2',
        'p4',
      ]);

      // 2D Grid Drag-and-Drop: hold p4 (bottom-right) and drop onto p1 (top-left, #1)
      final p4Center = tester.getCenter(
        find.byKey(const ValueKey('admin_prod_card_p4')),
      );
      final p1Center = tester.getCenter(
        find.byKey(const ValueKey('admin_prod_card_p1')),
      );
      final drag = await tester.startGesture(p4Center);
      await tester.pump(const Duration(milliseconds: 260));
      await drag.moveTo(p1Center);
      await tester.pump(const Duration(milliseconds: 80));
      await drag.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(container.read(canteenStoreProvider).categories.first.productIds, [
        'p4',
        'p1',
        'p3',
        'p2',
      ]);

      // Verify desktop (1280x900) scales cleanly to 4-column grid matching StudentMenuView
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      gridDelegate =
          tester.widget<SliverGrid>(gridFinder).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(gridDelegate.crossAxisCount, 4);
    },
  );

  testWidgets(
    'Full-bleed floating header avoids clipping seam, menu category navigation animates, and cart quantity/removal animations run cleanly',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
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
          'productIds': ['s1'],
        },
        {
          'key': 'drinks',
          'name_key': 'cat_drinks',
          'productIds': ['d1'],
        },
      ]);
      mockSocket.injectTestEvent('initial_translations', {
        'cat_sandwiches': {'en': 'Sandwiches', 'ar': 'الساندويتشات'},
        'cat_drinks': {'en': 'Drinks', 'ar': 'المشروبات'},
        'item_s1': {'en': 'Smoked Turkey Sub', 'ar': 'ساب تركي مدخن'},
        'desc_s1': {'en': 'Toasted sourdough baguette', 'ar': 'خبز ساور دو'},
        'item_d1': {'en': 'Iced Matcha Latte', 'ar': 'ماتشا لاتيه مثلج'},
        'desc_d1': {'en': 'Ceremonial grade matcha', 'ar': 'ماتشا فاخرة'},
      });
      mockSocket.injectTestEvent('initial_products', [
        {
          'id': 's1',
          'name_key': 'item_s1',
          'description_key': 'desc_s1',
          'price': 60,
          'quantity': 999,
          'image': '',
          'category': 'sandwiches',
        },
        {
          'id': 'd1',
          'name_key': 'item_d1',
          'description_key': 'desc_d1',
          'price': 40,
          'quantity': 999,
          'image': '',
          'category': 'drinks',
        },
      ]);
      await tester.pumpAndSettle();

      // 1. Verify full-bleed viewport: CustomScrollView starts at y = 0.0 behind floating EvaGlassBar
      final scrollTopY = tester.getTopLeft(find.byType(CustomScrollView)).dy;
      final glassBottomY = tester.getBottomRight(find.byType(EvaGlassBar)).dy;
      expect(scrollTopY, 0.0);
      expect(glassBottomY, greaterThan(50.0));

      // 2. Navigate across categories ('All' -> 'Sandwiches' -> 'Drinks' -> 'All') & pump mid-flight frames
      await tester.tap(find.text('Sandwiches'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('Smoked Turkey Sub'), findsOneWidget);
      expect(find.text('Iced Matcha Latte'), findsNothing);

      await tester.tap(find.text('Drinks'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('Iced Matcha Latte'), findsOneWidget);
      expect(find.text('Smoked Turkey Sub'), findsNothing);

      await tester.ensureVisible(find.text('All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      expect(find.text('Smoked Turkey Sub'), findsOneWidget);
      expect(find.text('Iced Matcha Latte'), findsOneWidget);

      // 3. Add both items to cart, open CartCheckoutSheet, and verify quantity + removal animations
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();
      expect(container.read(cartPricingProvider).totalItemCount, 2);

      await tester.tap(find.text('Review order'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cart_entry_s1')), findsOneWidget);
      expect(find.byKey(const ValueKey('cart_entry_d1')), findsOneWidget);

      // Increment s1 (1 -> 2) inside CartCheckoutSheet and verify odometer/pulse frames
      final s1Stepper = find.descendant(
        of: find.byKey(const ValueKey('cart_entry_s1')),
        matching: find.byType(EvaQuantityStepper),
      );
      await tester.tap(
        find.descendant(of: s1Stepper, matching: find.byIcon(Icons.add_rounded)),
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(container.read(cartProvider)['s1'], 2);

      // Decrement s1 back to 1 (2 -> 1), morphing '-' into delete_outline_rounded
      await tester.tap(
        find.descendant(
          of: s1Stepper,
          matching: find.byIcon(Icons.remove_rounded),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(cartProvider)['s1'], 1);
      expect(
        find.descendant(
          of: s1Stepper,
          matching: find.byIcon(Icons.delete_outline_rounded),
        ),
        findsOneWidget,
      );

      // Remove s1 (1 -> 0): row stays mounted mid-exit animation (80ms) while collapsing, then unmounts cleanly
      await tester.tap(
        find.descendant(
          of: s1Stepper,
          matching: find.byIcon(Icons.delete_outline_rounded),
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('cart_entry_s1')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cart_entry_s1')), findsNothing);
      expect(find.byKey(const ValueKey('cart_entry_d1')), findsOneWidget);

      // Clear remaining cart item -> animates row exit then transitions to cart_empty_view
      await tester.tap(find.byKey(const ValueKey('clear_cart_btn')));
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cart_empty_view')), findsOneWidget);
    },
  );

  testWidgets(
    'Welcome screen pins Open status to top-left with enlarged hero logo, and 5-item Cart keeps Payment Method + Confirm button fixed above fold',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
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

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EvaCanteenApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify status badge is at top-left, logo is hero-sized (210dp wide), title is centered, hintStyle is translucent, and footer buttons are stroked on 360x800 phone
      final statusRect = tester.getRect(
        find.byKey(const ValueKey('welcome_status_top_left')),
      );
      expect(statusRect.left, closeTo(16.0, 1.0));
      expect(statusRect.top, lessThan(40.0));
      expect(statusRect.right, lessThan(180.0));

      final logoFinder = find.byType(EvaBrandLogo);
      expect(logoFinder, findsOneWidget);
      final logoSize = tester.getSize(logoFinder);
      expect(logoSize.width, 210.0);
      expect(logoSize.height, closeTo(210.0 * 0.72, 0.5));
      expect(tester.widget<EvaBrandLogo>(logoFinder).hero, isTrue);

      final emailField = tester.widget<TextField>(find.byType(TextField).first);
      final hintColor = Theme.of(
        tester.element(find.byWidget(emailField)),
      ).inputDecorationTheme.hintStyle?.color;
      expect(hintColor, isNotNull);
      expect(hintColor!.a, lessThan(0.6));

      final titleWidget = tester.widget<Text>(find.text('Welcome back'));
      expect(titleWidget.textAlign, TextAlign.center);
      expect(
        find.ancestor(
          of: find.text('Staff & kitchen portal'),
          matching: find.byType(OutlinedButton),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('عربي'),
          matching: find.byType(OutlinedButton),
        ),
        findsOneWidget,
      );

      // 2. Sign in as a customer (balance 50 L.E) with 5 distinct items in cart
      SharedPreferences.setMockInitialValues({
        'eva_saved_session_v2':
            '{"email":"eyad@canteen.app","role":"student","profilePic":"pic2","balance":50,"token":"jwt-1"}',
      });
      final signedInPrefs = await SharedPreferences.getInstance();
      final signedInContainer = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(signedInPrefs),
          socketClientProvider.overrideWithValue(mockSocket),
        ],
      );
      addTearDown(signedInContainer.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: signedInContainer,
          child: const EvaCanteenApp(),
        ),
      );
      await tester.pumpAndSettle();

      mockSocket.injectTestEvent('initial_translations', {
        for (int i = 1; i <= 5; i++) ...{
          'item_m$i': {'en': 'Dish #$i', 'ar': 'طبق #$i'},
          'desc_m$i': {'en': 'Fresh kitchen dish', 'ar': 'طبق طازج'},
        },
      });
      mockSocket.injectTestEvent('initial_products', [
        for (int i = 1; i <= 5; i++)
          {
            'id': 'm$i',
            'name_key': 'item_m$i',
            'description_key': 'desc_m$i',
            'price': 55,
            'quantity': 999,
            'image': '',
            'category': 'lunch',
          },
      ]);
      await tester.pumpAndSettle();

      // Add all 5 items (total = 275 L.E, matching Screenshot 2 scenario!)
      final products = signedInContainer.read(canteenStoreProvider).products;
      for (final p in products) {
        signedInContainer.read(cartProvider.notifier).increment(p);
      }
      await tester.pumpAndSettle();

      // Open CartCheckoutSheet
      await tester.tap(find.text('Review order'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify Fixed Checkout Dock + Cash/Card/Wallet pills + Confirm CTA are ALL visible immediately WITHOUT scrolling!
      final dockRect = tester.getRect(
        find.byKey(const ValueKey('cart_fixed_checkout_dock')),
      );
      expect(dockRect.bottom, lessThanOrEqualTo(800.0));
      expect(find.byKey(const ValueKey('pay_method_cash')), findsOneWidget);
      expect(find.byKey(const ValueKey('pay_method_card')), findsOneWidget);
      expect(find.byKey(const ValueKey('pay_method_wallet')), findsOneWidget);
      expect(
        find.textContaining('Place order (Cash)'),
        findsOneWidget,
      );

      // Switch to Card in 1 tap right above Confirm button -> Confirm button reflects (Card)
      await tester.tap(find.byKey(const ValueKey('pay_method_card')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Place order (Card)'), findsOneWidget);

      // Switch to Wallet (balance 50 < 275) -> disables Confirm button & reveals warning in fixed dock
      await tester.tap(find.byKey(const ValueKey('pay_method_wallet')));
      await tester.pumpAndSettle();
      final confirmBtn = tester.widget<FilledButton>(
        find.byKey(const ValueKey('cart_confirm_order_btn')),
      );
      expect(confirmBtn.onPressed, isNull);

      // Switch back to Cash -> Confirm button re-enables immediately
      await tester.tap(find.byKey(const ValueKey('pay_method_cash')));
      await tester.pumpAndSettle();
      final enabledConfirmBtn = tester.widget<FilledButton>(
        find.byKey(const ValueKey('cart_confirm_order_btn')),
      );
      expect(enabledConfirmBtn.onPressed, isNotNull);
    },
  );

  testWidgets(
    'Settings About Project button opens web-style About modal and Copyright dialog without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({
        'eva_saved_session_v2':
            '{"email":"eyad@canteen.app","role":"student","profilePic":"pic1","balance":100,"token":"jwt-1"}',
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

      // Navigate to Settings tab via floating navbar
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Scroll down to About Project button & tap it
      final aboutBtn = find.byKey(const ValueKey('about_project_button'));
      await tester.scrollUntilVisible(
        aboutBtn,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(aboutBtn);
      await tester.pumpAndSettle();

      // Note: Image.network in widget tests triggers mock HTTP 400 -> errorBuilder handles it cleanly
      expect(find.text('About Project'), findsWidgets);
      expect(
        find.textContaining('Eyad Gaber • Anwar Qasem • Dina Mahmoud • Ahmed Mohamed'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('copyright_info_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('about_project_close_button')),
        findsOneWidget,
      );

      // Tap copyright icon -> closes About modal & opens License & Copyright modal
      await tester.tap(find.byKey(const ValueKey('copyright_info_button')));
      await tester.pumpAndSettle();
      expect(find.text('License & Copyright'), findsOneWidget);
      expect(
        find.textContaining('Copyright (C) 2025 EVA International School'),
        findsOneWidget,
      );
      expect(find.text('GNU General Public License'), findsOneWidget);

      // Dismiss Copyright modal cleanly via OK
      await tester.tap(find.byKey(const ValueKey('copyright_close_button')));
      await tester.pumpAndSettle();
      expect(find.text('License & Copyright'), findsNothing);
    },
  );

  test(
    'EvaSocketClient defaults to Render backend URL over HTTPS/WSS',
    () {
      final client = EvaSocketClient(enableNetwork: false);
      addTearDown(client.dispose);
      expect(client.httpBaseUrl, 'https://eva-canteen-backend.onrender.com');
      expect(
        client.wsUri.toString(),
        'wss://eva-canteen-backend.onrender.com',
      );
    },
  );

  test(
    'NotificationController deduplicates foreground WS + FCM alerts and allows re-alerting after reopen',
    () async {
      SharedPreferences.setMockInitialValues({
        'eva_saved_session_v2':
            '{"email":"student@eva.edu","role":"student","profilePic":"pic2","balance":50,"token":"jwt-student-1"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final socket = _RecordingSocketClient();
      final mockNotif = _MockNotificationService(
        initialPermission: PushPermissionState.authorized,
        tokenValue: 'fcm-token-dedup-1',
      );

      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          socketClientProvider.overrideWithValue(socket),
          notificationServiceProvider.overrideWithValue(mockNotif),
        ],
      );
      addTearDown(container.dispose);

      container.read(canteenStoreProvider);
      container.read(notificationControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(socket.registeredCalls.length, 1);
      expect(socket.registeredCalls.first['token'], 'fcm-token-dedup-1');

      final nowIso = DateTime.now().toUtc().toIso8601String();
      socket.injectTestEvent('my_orders', [
        {
          'id': 'ORD-42-1700000001',
          'totalAmount': 40,
          'status': 'preparing',
          'paymentMethod': 'wallet',
          'timestamp': nowIso,
          'items': const [],
        },
      ]);
      await Future<void>.delayed(Duration.zero);

      // 1. WS delivers 'delivered' status -> triggers notice + local notification
      socket.injectTestEvent('my_order_updated', {
        'updatedOrder': {
          'id': 'ORD-42-1700000001',
          'totalAmount': 40,
          'status': 'delivered',
          'paymentMethod': 'wallet',
          'timestamp': nowIso,
          'items': const [],
        },
      });
      await Future<void>.delayed(Duration.zero);

      final firstNotice = container.read(canteenStoreProvider).notice;
      expect(firstNotice, isNotNull);
      expect(firstNotice!.isCelebration, isTrue);
      expect(firstNotice.orderId, 'ORD-42-1700000001');
      expect(mockNotif.shownLocalOrderIds, ['ORD-42-1700000001']);

      // 2. Duplicate FCM foreground push for the exact same order is suppressed
      mockNotif.emitForeground(
        const IncomingOrderNotification(
          type: 'order_ready',
          orderId: 'ORD-42-1700000001',
          pickupNumber: '42',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(canteenStoreProvider).notice!.id, firstNotice.id);
      expect(mockNotif.shownLocalOrderIds.length, 1);

      // 3. Admin re-opens order to 'pending' -> clears dedup entry
      socket.injectTestEvent('my_order_updated', {
        'updatedOrder': {
          'id': 'ORD-42-1700000001',
          'totalAmount': 40,
          'status': 'pending',
          'paymentMethod': 'wallet',
          'timestamp': nowIso,
          'items': const [],
        },
      });
      await Future<void>.delayed(Duration.zero);

      // 4. Order transitions to 'delivered' again -> alerts a second time
      socket.injectTestEvent('my_order_updated', {
        'updatedOrder': {
          'id': 'ORD-42-1700000001',
          'totalAmount': 40,
          'status': 'delivered',
          'paymentMethod': 'wallet',
          'timestamp': nowIso,
          'items': const [],
        },
      });
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(canteenStoreProvider).notice!.id,
        greaterThan(firstNotice.id),
      );
      expect(mockNotif.shownLocalOrderIds, [
        'ORD-42-1700000001',
        'ORD-42-1700000001',
      ]);
    },
  );

  test(
    'Just-in-time push permission prompt fires once after first order and logout unregisters token with JWT',
    () async {
      SharedPreferences.setMockInitialValues({
        'eva_saved_session_v2':
            '{"email":"student@eva.edu","role":"student","profilePic":"pic2","balance":100,"token":"jwt-student-99"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final socket = _RecordingSocketClient();
      final mockNotif = _MockNotificationService(
        initialPermission: PushPermissionState.denied,
        permissionAfterRequest: PushPermissionState.authorized,
        tokenValue: 'fcm-token-jit-99',
      );

      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          socketClientProvider.overrideWithValue(socket),
          notificationServiceProvider.overrideWithValue(mockNotif),
        ],
      );
      addTearDown(container.dispose);

      container.read(canteenStoreProvider);
      container.read(notificationControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(mockNotif.requestPermissionCalls, 0);
      expect(socket.registeredCalls, isEmpty);

      final nowIso = DateTime.now().toUtc().toIso8601String();
      socket.injectTestEvent('order_confirmed_by_server', {
        'id': 'ORD-01-1700000001',
        'totalAmount': 25,
        'status': 'pending',
        'paymentMethod': 'wallet',
        'timestamp': nowIso,
        'items': const [],
      });
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(mockNotif.requestPermissionCalls, 1);
      expect(socket.registeredCalls.length, 1);
      expect(socket.registeredCalls.first['token'], 'fcm-token-jit-99');
      expect(socket.registeredCalls.first['authToken'], 'jwt-student-99');

      // Second order should NOT re-prompt
      socket.injectTestEvent('order_confirmed_by_server', {
        'id': 'ORD-02-1700000002',
        'totalAmount': 25,
        'status': 'pending',
        'paymentMethod': 'wallet',
        'timestamp': nowIso,
        'items': const [],
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(mockNotif.requestPermissionCalls, 1);

      // Logout unregisters push token using the student's JWT before clearing session
      container.read(canteenStoreProvider.notifier).logout();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(socket.unregisteredCalls.length, 1);
      expect(socket.unregisteredCalls.first['token'], 'fcm-token-jit-99');
      expect(socket.unregisteredCalls.first['authToken'], 'jwt-student-99');
      expect(container.read(canteenStoreProvider).currentUser, isNull);
    },
  );

  testWidgets(
    'Permission denial falls back cleanly in Settings and live WS alerts still work',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({
        'eva_saved_session_v2':
            '{"email":"student@eva.edu","role":"student","profilePic":"pic2","balance":50,"token":"jwt-denied"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final socket = _RecordingSocketClient();
      final mockNotif = _MockNotificationService(
        initialPermission: PushPermissionState.permanentlyDenied,
        permissionAfterRequest: PushPermissionState.permanentlyDenied,
      );

      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          socketClientProvider.overrideWithValue(socket),
          notificationServiceProvider.overrideWithValue(mockNotif),
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

      // Open Settings tab and verify Order Ready Alerts card shows blocked state + hint
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      final alertsCard = find.byKey(const ValueKey('order_ready_alerts_card'));
      await tester.scrollUntilVisible(
        alertsCard,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(alertsCard, findsOneWidget);
      expect(find.text('Order Ready Alerts'), findsOneWidget);
      expect(find.text('Blocked in settings'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('order_ready_alerts_denied_hint')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('enable_order_alerts_button')),
        findsNothing,
      );

      // Live WS celebration SnackBar with 'View' action still fires even when push is blocked
      final nowIso = DateTime.now().toUtc().toIso8601String();
      socket.injectTestEvent('my_order_updated', {
        'updatedOrder': {
          'id': 'ORD-18-1700000001',
          'totalAmount': 30,
          'status': 'delivered',
          'paymentMethod': 'cash',
          'timestamp': nowIso,
          'items': const [],
        },
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('View'), findsOneWidget);
      expect(mockNotif.shownLocalOrderIds, isEmpty);
    },
  );

  testWidgets(
    'Notification tap deep-links to /orders?orderId=... and pins the tapped Ready order',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({
        'eva_saved_session_v2':
            '{"email":"student@eva.edu","role":"student","profilePic":"pic2","balance":80,"token":"jwt-deeplink"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final socket = _RecordingSocketClient();
      final mockNotif = _MockNotificationService(
        initialPermission: PushPermissionState.authorized,
        tokenValue: 'fcm-token-deeplink',
      );

      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          socketClientProvider.overrideWithValue(socket),
          notificationServiceProvider.overrideWithValue(mockNotif),
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

      final nowIso = DateTime.now().toUtc().toIso8601String();
      // Inject two today orders: #12 is still preparing (default active order)
      // and #09 is delivered (Ready).
      socket.injectTestEvent('my_orders', [
        {
          'id': 'ORD-12-1700000002',
          'totalAmount': 45,
          'status': 'preparing',
          'paymentMethod': 'wallet',
          'timestamp': nowIso,
          'items': const [],
        },
        {
          'id': 'ORD-09-1700000001',
          'totalAmount': 30,
          'status': 'delivered',
          'paymentMethod': 'wallet',
          'timestamp': nowIso,
          'items': const [],
        },
      ]);
      await tester.pumpAndSettle();

      // Simulate tapping a notification for the Ready order #09
      mockNotif.emitTap(
        const IncomingOrderNotification(
          type: 'order_ready',
          orderId: 'ORD-09-1700000001',
          pickupNumber: '09',
          route: '/orders',
        ),
      );
      await tester.pumpAndSettle();

      // Should land on Orders tab with #09 pinned in the live pickup pass card
      expect(find.text('Live Pickup Pass'), findsOneWidget);
      expect(find.text('#09'), findsWidgets);
      expect(find.text('ORD-09-1700000001'), findsWidgets);

      final passCardFinder = find.byKey(const ValueKey('live_pickup_pass_card'));
      expect(passCardFinder, findsOneWidget);
      final passCard = tester.widget<EvaSurfaceCard>(passCardFinder);
      expect(passCard.borderRadius, 22);
      expect(passCard.clipBehavior, Clip.antiAlias);
      final innerMat = tester.widget<Material>(
        find
            .descendant(of: passCardFinder, matching: find.byType(Material))
            .first,
      );
      expect(innerMat.clipBehavior, Clip.antiAlias);
      expect(innerMat.borderRadius, isNotNull);
    },
  );

  testWidgets(
    'Order Ready floating SnackBar floats cleanly above EvaFloatingNavBar on 360x800 phone (with gesture bar inset)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      final dpr = tester.view.devicePixelRatio;
      tester.view.padding = FakeViewPadding(bottom: 24 * dpr);
      tester.view.viewPadding = FakeViewPadding(bottom: 24 * dpr);
      addTearDown(() {
        tester.view.resetPadding();
        tester.view.resetViewPadding();
        return tester.binding.setSurfaceSize(null);
      });

      SharedPreferences.setMockInitialValues({
        'eva_saved_session_v2':
            '{"email":"student@eva.edu","role":"student","profilePic":"pic2","balance":80,"token":"jwt-snackbar"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final socket = _RecordingSocketClient();
      final mockNotif = _MockNotificationService(
        initialPermission: PushPermissionState.authorized,
        tokenValue: 'fcm-token-snackbar',
      );

      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          socketClientProvider.overrideWithValue(socket),
          notificationServiceProvider.overrideWithValue(mockNotif),
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

      final nowIso = DateTime.now().toUtc().toIso8601String();
      socket.injectTestEvent('my_order_updated', {
        'updatedOrder': {
          'id': 'ORD-21-1700000005',
          'totalAmount': 45,
          'status': 'delivered',
          'paymentMethod': 'wallet',
          'timestamp': nowIso,
          'items': const [],
        },
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final navBarFinder = find.byType(EvaFloatingNavBar);
      final snackBarFinder = find.byType(SnackBar);
      expect(navBarFinder, findsOneWidget);
      expect(snackBarFinder, findsOneWidget);
      expect(find.text('View'), findsOneWidget);

      // Measure the visible SnackBar card (the Material inside SnackBar) against
      // the floating navbar bounds to guarantee zero overlap.
      final snackBarCardFinder = find
          .descendant(of: snackBarFinder, matching: find.byType(Material))
          .first;
      final snackBarRect = tester.getRect(snackBarCardFinder);
      final navBarRect = tester.getRect(navBarFinder);
      expect(
        snackBarRect.bottom,
        lessThanOrEqualTo(navBarRect.top),
        reason:
            'SnackBar bottom (${snackBarRect.bottom}) must sit above EvaFloatingNavBar top (${navBarRect.top})',
      );

      // Verify tapping the navbar still works while the SnackBar is visible
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Light Blue'), findsOneWidget);
    },
  );

  testWidgets(
    'EvaImageCache quantizes RAM cache widths, caches data URIs, and preserves Menu images across tab switches',
    (tester) async {
      // 1. Quantized bucket checks
      expect(EvaImageCache.quantizeCacheWidth(28, 3.0), 160);
      expect(EvaImageCache.quantizeCacheWidth(160, 2.5), 480);
      expect(EvaImageCache.quantizeCacheWidth(360, 3.0), 960);
      expect(EvaImageCache.quantizeCacheWidth(double.infinity, 2.0), 480);

      // 2. Memory cache configuration
      EvaImageCache.configureMemoryCache();
      expect(PaintingBinding.instance.imageCache.maximumSize, 300);
      expect(PaintingBinding.instance.imageCache.maximumSizeBytes, 150 << 20);

      // 3. Cached data-URI decoding returns identical Uint8List reference on repeat calls
      const tinyPngDataUri =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      final decoded1 = EvaImageCache.decodeDataUri(tinyPngDataUri);
      final decoded2 = EvaImageCache.decodeDataUri(tinyPngDataUri);
      expect(decoded1, isNotNull);
      expect(identical(decoded1, decoded2), isTrue);
      expect(EvaImageCache.decodeDataUri('data:image/png;base64,!!!'), isNull);

      // 4. Widget test: Menu -> Orders -> Settings -> Menu keeps Menu images rendered with zero spinner
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({
        'eva_saved_session_v2':
            '{"email":"student@eva.edu","role":"student","profilePic":"pic2","balance":90,"token":"jwt-img-cache"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final socket = _RecordingSocketClient();

      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          socketClientProvider.overrideWithValue(socket),
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

      socket.injectTestEvent('initial_translations', {
        'item_cached_burger': {'en': 'Classic Burger', 'ar': 'برجر كلاسيك'},
        'desc_cached_burger': {'en': 'Grilled beef patty', 'ar': 'لحم مشوي'},
      });
      socket.injectTestEvent('initial_products', [
        {
          'id': 'p_cached_1',
          'name_key': 'item_cached_burger',
          'description_key': 'desc_cached_burger',
          'price': 60,
          'quantity': 12,
          'image': tinyPngDataUri,
          'category': 'sandwiches',
        },
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Classic Burger'), findsOneWidget);
      expect(find.byType(EvaCachedImage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Navigate away to Orders, then Settings, then back to Menu
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Classic Burger'), findsOneWidget);
      expect(find.byType(EvaCachedImage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'EvaSplashOverlay plays pure logo-only animation with zero text and unmounts completely on finish',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final socket = _RecordingSocketClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            socketClientProvider.overrideWithValue(socket),
          ],
          child: const EvaCanteenApp(forceShowSplashInTests: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      final overlayFinder = find.byKey(const ValueKey('eva_splash_overlay'));
      expect(overlayFinder, findsOneWidget);
      // Verify 100% pure visual logo animation with ZERO Text widgets inside splash
      expect(
        find.descendant(of: overlayFinder, matching: find.byType(Text)),
        findsNothing,
      );

      // Pump through all 4 choreography phases + handoff
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      // Overlay must completely unmount after finishing
      expect(overlayFinder, findsNothing);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'EvaSplashOverlay supports tap-to-skip, Reduce Motion bypass, and cold-start deep-link bypass',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final socket = _RecordingSocketClient();

      // 1. Tap-to-skip dismisses quickly
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            socketClientProvider.overrideWithValue(socket),
          ],
          child: const EvaCanteenApp(forceShowSplashInTests: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final overlayFinder = find.byKey(const ValueKey('eva_splash_overlay'));
      expect(overlayFinder, findsOneWidget);

      await tester.tap(overlayFinder);
      await tester.pump(const Duration(milliseconds: 260));
      await tester.pumpAndSettle();
      expect(overlayFinder, findsNothing);

      // 2. Reduce Motion (disableAnimations: true) bypasses immediately
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('reduce_motion_scope'),
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            socketClientProvider.overrideWithValue(socket),
          ],
          child: const EvaCanteenApp(forceShowSplashInTests: true),
        ),
      );
      await tester.pump();
      expect(overlayFinder, findsNothing);
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();

      // 3. Cold-start notification deep link bypasses splash immediately
      final deepLinkContainer = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          socketClientProvider.overrideWithValue(socket),
        ],
      );
      addTearDown(deepLinkContainer.dispose);
      deepLinkContainer
          .read(pendingDeepLinkProvider.notifier)
          .setPending('/orders?orderId=ORD-77-1700000001');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: deepLinkContainer,
          child: const EvaCanteenApp(forceShowSplashInTests: true),
        ),
      );
      await tester.pump();
      expect(overlayFinder, findsNothing);
    },
  );

  testWidgets(
    'Menu category switches use single-layer SliverFadeTransition without per-card Opacity saveLayers or SliverLayoutBuilder churn',
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
          'productIds': ['s1', 's2'],
        },
        {
          'key': 'drinks',
          'name_key': 'cat_drinks',
          'productIds': ['d1', 'd2'],
        },
      ]);
      mockSocket.injectTestEvent('initial_translations', {
        'cat_sandwiches': {'en': 'Sandwiches', 'ar': 'الساندويتشات'},
        'cat_drinks': {'en': 'Drinks', 'ar': 'المشروبات'},
        'item_s1': {'en': 'Club Sandwich', 'ar': 'كلوب ساندويتش'},
        'item_s2': {'en': 'Cheese Panini', 'ar': 'بانيني جبنة'},
        'item_d1': {'en': 'Mango Juice', 'ar': 'عصير مانجو'},
        'item_d2': {'en': 'Cold Brew', 'ar': 'كولد برو'},
        'bundle_combo': {'en': 'Lunch Combo', 'ar': 'كومبو الغداء'},
        'desc_generic': {'en': 'Fresh daily', 'ar': 'طازج يومياً'},
      });
      mockSocket.injectTestEvent('initial_products', [
        {
          'id': 's1',
          'name_key': 'item_s1',
          'description_key': 'desc_generic',
          'price': 55,
          'quantity': 20,
          'image': '',
          'category': 'sandwiches',
        },
        {
          'id': 's2',
          'name_key': 'item_s2',
          'description_key': 'desc_generic',
          'price': 45,
          'quantity': 20,
          'image': '',
          'category': 'sandwiches',
        },
        {
          'id': 'd1',
          'name_key': 'item_d1',
          'description_key': 'desc_generic',
          'price': 30,
          'quantity': 20,
          'image': '',
          'category': 'drinks',
        },
        {
          'id': 'd2',
          'name_key': 'item_d2',
          'description_key': 'desc_generic',
          'price': 35,
          'quantity': 20,
          'image': '',
          'category': 'drinks',
        },
      ]);
      mockSocket.injectTestEvent('initial_bundles', [
        {
          'id': 'b1',
          'name_key': 'bundle_combo',
          'description_key': 'desc_generic',
          'itemIds': ['s1', 'd1'],
          'discountPercent': 15,
          'isSuggestion': false,
          'active': true,
        },
      ]);
      await tester.pumpAndSettle();

      // Structural guarantees: single SliverFadeTransition, zero SliverLayoutBuilder, zero per-card Opacity
      expect(find.byType(SliverFadeTransition), findsOneWidget);
      expect(find.byType(SliverLayoutBuilder), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SliverGrid),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );

      // Capture element of card s1 on 'All'
      final s1ElementBefore = tester.element(find.byKey(const ValueKey<String>('s1')));

      // Switch 'All' -> 'Sandwiches' (combos collapse + grid slides)
      await tester.tap(find.text('Sandwiches'));
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(SliverGrid),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );

      // Card s1 stayed stably keyed and mounted without teardown!
      final s1ElementAfter = tester.element(find.byKey(const ValueKey<String>('s1')));
      expect(identical(s1ElementBefore, s1ElementAfter), isTrue);

      // Rapid mid-flight switches ('Sandwiches' -> 'Drinks' -> 'All') before previous animation finishes
      await tester.tap(find.text('Drinks'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.text('Mango Juice'), findsOneWidget);
      expect(find.text('Club Sandwich'), findsNothing);

      await tester.tap(find.text('All'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Club Sandwich'), findsOneWidget);
      expect(find.text('Mango Juice'), findsOneWidget);
      expect(find.text('Lunch Combo'), findsOneWidget);
    },
  );
}

class _RecordingSocketClient extends EvaSocketClient {
  _RecordingSocketClient() : super(enableNetwork: false);

  final List<Map<String, String?>> registeredCalls = [];
  final List<Map<String, String?>> unregisteredCalls = [];

  @override
  Future<bool> registerPushToken({
    required String token,
    required String platform,
    required String locale,
    String? authTokenOverride,
  }) async {
    registeredCalls.add({
      'token': token,
      'platform': platform,
      'locale': locale,
      'authToken': authTokenOverride,
    });
    return true;
  }

  @override
  Future<bool> unregisterPushToken({
    required String token,
    String? authTokenOverride,
  }) async {
    unregisteredCalls.add({'token': token, 'authToken': authTokenOverride});
    return true;
  }
}

class _MockNotificationService implements NotificationService {
  _MockNotificationService({
    this.initialPermission = PushPermissionState.authorized,
    this.permissionAfterRequest = PushPermissionState.authorized,
    this.tokenValue = 'mock-fcm-token',
  }) : _currentPermission = initialPermission;

  final PushPermissionState initialPermission;
  final PushPermissionState permissionAfterRequest;
  final String? tokenValue;

  PushPermissionState _currentPermission;
  int requestPermissionCalls = 0;
  final List<String> shownLocalOrderIds = [];

  final _foregroundController =
      StreamController<IncomingOrderNotification>.broadcast();
  final _tapController =
      StreamController<IncomingOrderNotification>.broadcast();
  final _tokenRefreshController = StreamController<String>.broadcast();

  void emitForeground(IncomingOrderNotification msg) {
    _foregroundController.add(msg);
  }

  void emitTap(IncomingOrderNotification msg) {
    _tapController.add(msg);
  }

  @override
  String? get platformName => 'android';

  @override
  bool get isSupported => true;

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
  Future<PushPermissionState> getPermissionState() async => _currentPermission;

  @override
  Future<PushPermissionState> requestPermission() async {
    requestPermissionCalls += 1;
    _currentPermission = permissionAfterRequest;
    return _currentPermission;
  }

  @override
  Future<String?> getToken() async => tokenValue;

  @override
  Future<IncomingOrderNotification?> getInitialTap() async => null;

  @override
  Future<void> showLocalOrderReadyNotification({
    required String orderId,
    required String title,
    required String body,
    String route = '/orders',
  }) async {
    shownLocalOrderIds.add(orderId);
  }

  @override
  void dispose() {
    _foregroundController.close();
    _tapController.close();
    _tokenRefreshController.close();
  }
}
