import 'package:eva_canteen/core/models/domain_models.dart';
import 'package:eva_canteen/core/network/eva_socket_client.dart';
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

      // Verify English LTR on Welcome screen with simple Logo + Name header
      expect(find.text('EVA Canteen'), findsOneWidget);
      expect(find.text('Order ahead, skip the wait.'), findsNothing);
      expect(
        Directionality.of(tester.element(find.text('EVA Canteen'))),
        TextDirection.ltr,
      );

      // Tap subtle Arabic footer link ('عربي')
      await tester.ensureVisible(find.text('عربي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('عربي'));
      await tester.pumpAndSettle();

      expect(find.text('كانتين إيفا'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('كانتين إيفا'))),
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
}
