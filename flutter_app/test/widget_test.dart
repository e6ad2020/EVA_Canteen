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
}
