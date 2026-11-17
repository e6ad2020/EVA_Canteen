import 'package:eva_canteen/core/models/domain_models.dart';
import 'package:eva_canteen/core/network/eva_socket_client.dart';
import 'package:eva_canteen/core/state/canteen_providers.dart';
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

      // Verify English LTR on Welcome screen
      expect(find.text('Fresh Campus Meals, Zero Queue.'), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.text('Fresh Campus Meals, Zero Queue.')),
        ),
        TextDirection.ltr,
      );

      // Tap Arabic quick toggle ('عربي')
      await tester.tap(find.text('عربي'));
      await tester.pumpAndSettle();

      expect(
        find.text('وجبات طازجة في مدرستك، بدون طابور.'),
        findsOneWidget,
      );
      expect(
        Directionality.of(
          tester.element(find.text('وجبات طازجة في مدرستك، بدون طابور.')),
        ),
        TextDirection.rtl,
      );

      // Enter Guest Browse Menu mode
      await tester.tap(find.text('تصفح القائمة فقط'));
      await tester.pumpAndSettle();

      // Should now be on Student Menu screen in Arabic
      expect(find.text('القائمة'), findsWidgets);
    },
  );

  testWidgets(
    'Student Menu displays products and inline stepper updates tray bar',
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
      expect(find.text('Review Order'), findsOneWidget);
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
          'user': {'email': 'eyad@eva.edu', 'profilePic': 'pic2'},
        },
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('#07'), findsOneWidget);
      expect(find.text('eyad@eva.edu'), findsOneWidget);
      expect(find.text('Iced Latte'), findsOneWidget);
      expect(find.text('Start Preparing'), findsOneWidget);
    },
  );
}
