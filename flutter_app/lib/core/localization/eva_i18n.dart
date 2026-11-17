class EvaTranslator {
  const EvaTranslator({
    required this.langCode,
    required this.cmsTranslations,
  });

  final String langCode;
  final Map<String, Map<String, String>> cmsTranslations;

  bool get isRtl => langCode == 'ar';

  String t(String key, [Map<String, String>? params]) {
    String? resolved = cmsTranslations[key]?[langCode];
    resolved ??= _staticStrings[key]?[langCode];
    resolved ??= cmsTranslations[key]?['en'];
    resolved ??= _staticStrings[key]?['en'];
    resolved ??= key;

    var cleaned = resolved.replaceAll('<br>', ' ').replaceAll('<br/>', ' ');
    if (params != null && params.isNotEmpty) {
      for (final entry in params.entries) {
        cleaned = cleaned.replaceAll('{${entry.key}}', entry.value);
      }
    }
    return cleaned;
  }

  /// Checks whether [query] matches either the English or Arabic translation of [key].
  bool matchesBilingualQuery(String key, String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    final en = (cmsTranslations[key]?['en'] ?? _staticStrings[key]?['en'] ?? '')
        .toLowerCase();
    final ar = (cmsTranslations[key]?['ar'] ?? _staticStrings[key]?['ar'] ?? '')
        .toLowerCase();
    return en.contains(q) || ar.contains(q) || key.toLowerCase().contains(q);
  }

  String get currencySymbol => t('currency_symbol');

  String formatPrice(double amount) {
    final rounded = (amount - amount.truncateToDouble()).abs() < 0.005
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '$rounded $currencySymbol';
  }

  String rawForLang(String key, String targetLang) {
    return cmsTranslations[key]?[targetLang] ??
        _staticStrings[key]?[targetLang] ??
        '';
  }

  static const Map<String, Map<String, String>> _staticStrings = {
    'canteen_name': {'en': 'EVA Canteen', 'ar': 'كانتين إيفا'},
    'welcome_headline': {
      'en': 'Fresh Campus Meals, Zero Queue.',
      'ar': 'وجبات طازجة في مدرستك، بدون طابور.',
    },
    'welcome_subtitle': {
      'en': 'Order ahead, get your live pickup pass, and grab your meal when ready.',
      'ar': 'اطلب مسبقاً، احصل على بطاقة الاستلام المباشرة، واستلم وجبتك فور جهوزيتها.',
    },
    'currency_symbol': {'en': 'L.E', 'ar': 'ج.م'},
    'sign_in_tab': {'en': 'Sign In', 'ar': 'تسجيل الدخول'},
    'register_tab': {'en': 'Create Account', 'ar': 'إنشاء حساب'},
    'email_label': {'en': 'School Email', 'ar': 'البريد الإلكتروني'},
    'email_hint': {'en': 'student@eva.edu', 'ar': 'student@eva.edu'},
    'password_label': {'en': 'Password', 'ar': 'كلمة المرور'},
    'confirm_password_label': {
      'en': 'Confirm Password',
      'ar': 'تأكيد كلمة المرور',
    },
    'choose_avatar_label': {
      'en': 'Choose Your Avatar',
      'ar': 'اختر صورتك الرمزية',
    },
    'login_cta': {'en': 'Sign In to Order', 'ar': 'دخول للطلب'},
    'register_cta': {'en': 'Create Student Account', 'ar': 'إنشاء حساب طالب'},
    'browse_menu_guest': {
      'en': 'Browse Menu Only',
      'ar': 'تصفح القائمة فقط',
    },
    'staff_portal_button': {
      'en': 'Canteen Staff / Admin',
      'ar': 'بوابة الإدارة والكانتين',
    },
    'canteen_open_badge': {'en': 'Open Now', 'ar': 'مفتوح الآن'},
    'canteen_closed_badge': {'en': 'Closed', 'ar': 'مغلق حالياً'},
    'canteen_closed_browse_banner': {
      'en': 'Canteen is currently closed. You can browse the menu, and ordering will unlock as soon as staff open the counter.',
      'ar': 'الكانتين مغلق حالياً. يمكنك تصفح القائمة والأسعار، وسيُفتح الطلب فور تشغيل الكانتين.',
    },
    'reconnecting_banner': {
      'en': 'Reconnecting to canteen server... Your cart is safe.',
      'ar': 'جاري إعادة الاتصال بالخادم... سلتك محفوظة بأمان.',
    },
    'nav_menu': {'en': 'Menu', 'ar': 'القائمة'},
    'nav_orders': {'en': 'My Orders', 'ar': 'طلباتي'},
    'nav_settings': {'en': 'Settings', 'ar': 'الإعدادات'},
    'search_hint': {
      'en': 'Search meals, drinks, or snacks (EN / عربي)...',
      'ar': 'ابحث عن وجبة أو مشروب أو سناك (عربي / EN)...',
    },
    'all_categories': {'en': 'All', 'ar': 'الكل'},
    'smart_combos_title': {
      'en': 'Smart Combos & Deals',
      'ar': 'عروض وكومبو التوفير',
    },
    'meal_ideas_badge': {'en': 'Combo Idea', 'ar': 'كومبو مقترح'},
    'discount_badge': {'en': 'Save {percent}%', 'ar': 'وفر {percent}%'},
    'add_button': {'en': 'Add', 'ar': 'إضافة'},
    'add_combo_button': {'en': 'Add Combo', 'ar': 'أضف العرض'},
    'out_of_stock': {'en': 'Sold Out', 'ar': 'نفد المخزون'},
    'low_stock_left': {'en': '{count} left', 'ar': 'متبقي {count}'},
    'unlimited_stock': {'en': 'Available', 'ar': 'متوفر دائماً'},
    'review_order_cta': {'en': 'Review Order', 'ar': 'مراجعة الطلب'},
    'items_count': {'en': '{count} items', 'ar': '{count} منتجات'},
    'cart_title': {'en': 'Your Tray', 'ar': 'سلة طلبك'},
    'clear_cart': {'en': 'Clear', 'ar': 'إفراغ'},
    'cart_empty_title': {
      'en': 'Your tray is empty',
      'ar': 'سلة طلبك فارغة حالياً',
    },
    'cart_empty_subtitle': {
      'en': 'Explore fresh sandwiches, drinks, and bundle deals from the menu.',
      'ar': 'استكشف الساندويتشات والمشروبات وعروض التوفير من القائمة.',
    },
    'subtotal_label': {'en': 'Subtotal', 'ar': 'المجموع الفرعي'},
    'bundle_savings_label': {'en': 'Bundle Savings', 'ar': 'خصم العروض'},
    'bundle_discount_applied': {'en': 'Bundle Discount', 'ar': 'خصم الحزمة'},
    'total_label': {'en': 'Total Due', 'ar': 'الإجمالي المستحق'},
    'payment_method_label': {'en': 'Payment Method', 'ar': 'طريقة الدفع'},
    'payment_cash': {'en': 'Cash at Counter', 'ar': 'نقداً عند الاستلام'},
    'payment_card': {'en': 'Bank Card', 'ar': 'بطاقة بنكية'},
    'payment_wallet': {'en': 'EVA Wallet', 'ar': 'رصيد المحفظة'},
    'wallet_balance_label': {'en': 'Balance', 'ar': 'الرصيد'},
    'insufficient_wallet_hint': {
      'en': 'Insufficient wallet balance ({balance}). Ask canteen staff to top up or pick another method.',
      'ar': 'رصيد المحفظة غير كافٍ ({balance}). يرجى شحن الرصيد من الإدارة أو اختيار طريقة دفع أخرى.',
    },
    'sign_in_to_checkout': {
      'en': 'Sign In to Place Order',
      'ar': 'سجّل الدخول لإتمام الطلب',
    },
    'place_order_cta': {'en': 'Place Order', 'ar': 'تأكيد الطلب'},
    'live_pickup_pass': {'en': 'Live Pickup Pass', 'ar': 'بطاقة الاستلام المباشر'},
    'active_order_pill': {
      'en': 'Order {num} • {status}',
      'ar': 'طلب {num} • {status}',
    },
    'status_pending': {'en': 'Received', 'ar': 'قيد الانتظار'},
    'status_preparing': {'en': 'Preparing', 'ar': 'جاري التحضير'},
    'status_delivered': {'en': 'Ready / Delivered', 'ar': 'جاهز للاستلام'},
    'pickup_counter_hint': {
      'en': 'Show this pickup number at the EVA Canteen counter.',
      'ar': 'أظهر رقم الاستلام هذا لموظف كانتين إيفا.',
    },
    'order_ready_toast': {
      'en': 'Order {num} is ready at the counter!',
      'ar': 'طلبك رقم {num} جاهز الآن للاستلام!',
    },
    'past_orders_title': {'en': 'Order History', 'ar': 'سجل الطلبات السابقة'},
    'no_orders_yet': {
      'en': 'No orders placed yet',
      'ar': 'لا توجد طلبات سابقة بعد',
    },
    'reorder_button': {'en': 'Reorder', 'ar': 'إعادة الطلب'},
    'reordered_toast': {
      'en': 'Available items added back to your tray!',
      'ar': 'تمت إعادة إضافة المنتجات المتوفرة إلى سلتك!',
    },
    // Admin & KDS
    'admin_portal_title': {
      'en': 'EVA Canteen Management',
      'ar': 'إدارة كانتين إيفا',
    },
    'admin_signin_subtitle': {
      'en': 'Sign in to access Kitchen Display (KDS), Catalog Studio, Analytics & Student Wallets.',
      'ar': 'سجّل الدخول للوصول إلى شاشة المطبخ وإدارة المنتجات والتحليلات ومحافظ الطلاب.',
    },
    'admin_kds_tab': {'en': 'Kitchen KDS', 'ar': 'شاشة الطلبات'},
    'admin_catalog_tab': {'en': 'Catalog Studio', 'ar': 'المنتجات والعروض'},
    'admin_analytics_tab': {'en': 'Analytics', 'ar': 'التحليلات'},
    'admin_ops_tab': {'en': 'Wallet & Ops', 'ar': 'الرصيد والإعدادات'},
    'kds_today_toggle': {'en': 'Live Today', 'ar': 'طلبات اليوم'},
    'kds_archive_toggle': {'en': 'Order Archive', 'ar': 'الأرشيف'},
    'kds_search_hint': {
      'en': 'Filter by #number or student email...',
      'ar': 'ابحث برقم الطلب أو بريد الطالب...',
    },
    'kds_start_preparing': {
      'en': 'Start Preparing',
      'ar': 'بدء التجهيز',
    },
    'kds_mark_delivered': {
      'en': 'Mark Ready / Delivered',
      'ar': 'تم التسليم / جاهز',
    },
    'kds_reopen_pending': {'en': 'Move to Pending', 'ar': 'إرجاع للانتظار'},
    'kds_empty_column': {
      'en': 'No orders in this stage',
      'ar': 'لا توجد طلبات في هذه المرحلة',
    },
    // Catalog Studio
    'studio_products_tab': {'en': 'Products', 'ar': 'المنتجات'},
    'studio_categories_tab': {'en': 'Categories', 'ar': 'الفئات'},
    'studio_bundles_tab': {'en': 'Bundles & Combos', 'ar': 'العروض والكومبو'},
    'archive_shelf_label': {'en': 'Archive Shelf', 'ar': 'رف الأرشيف'},
    'new_product_cta': {'en': 'New Product', 'ar': 'منتج جديد'},
    'edit_product_cta': {'en': 'Edit Product', 'ar': 'تعديل المنتج'},
    'edit_button': {'en': 'Edit', 'ar': 'تعديل'},
    'restore_button': {'en': 'Restore', 'ar': 'استعادة'},
    'new_category_cta': {'en': 'New Category', 'ar': 'فئة جديدة'},
    'new_bundle_cta': {'en': 'New Deal / Combo', 'ar': 'عرض / كومبو جديد'},
    'upload_photo_cta': {'en': 'Upload Photo', 'ar': 'رفع صورة'},
    'move_to_archive': {'en': 'Move to Archive', 'ar': 'نقل للأرشيف'},
    'save_cta': {'en': 'Save Changes', 'ar': 'حفظ التغييرات'},
    'cancel_cta': {'en': 'Cancel', 'ar': 'إلغاء'},
    'delete_cta': {'en': 'Delete', 'ar': 'حذف'},
    // Analytics
    'kpi_revenue': {'en': 'Total Revenue', 'ar': 'إجمالي الإيرادات'},
    'kpi_orders': {'en': 'Total Orders', 'ar': 'عدد الطلبات'},
    'kpi_aov': {'en': 'Avg Order Value', 'ar': 'متوسط قيمة الطلب'},
    'chart_orders_mode': {'en': 'Daily Orders', 'ar': 'الطلبات اليومية'},
    'chart_revenue_mode': {'en': 'Daily Revenue', 'ar': 'الإيرادات اليومية'},
    'top_products_title': {
      'en': 'Product Sales Ranking',
      'ar': 'ترتيب مبيعات المنتجات',
    },
    'low_stock_watchlist': {
      'en': 'Low-Stock Watchlist',
      'ar': 'تنبيهات انخفاض المخزون',
    },
    // Ops, Wallet & Settings
    'storefront_status_card': {
      'en': 'Storefront Open / Closed',
      'ar': 'حالة فتح وإغلاق الكانتين',
    },
    'payment_controls_title': {
      'en': 'Accepted Payment Methods',
      'ar': 'التحكم في طرق الدفع',
    },
    'wallet_desk_title': {
      'en': 'Student Wallet Balances',
      'ar': 'إدارة أرصدة الطلاب (المحفظة)',
    },
    'wallet_add': {'en': 'Top Up (+)', 'ar': 'إضافة رصيد (+)'},
    'wallet_deduct': {'en': 'Deduct (-)', 'ar': 'خصم رصيد (-)'},
    'wallet_set': {'en': 'Set Exact', 'ar': 'تعيين الرصيد'},
    'currency_settings_title': {
      'en': 'Bilingual Currency Symbol',
      'ar': 'رمز العملة باللغتين',
    },
    'catalog_backup_title': {
      'en': 'Catalog JSON Export / Import',
      'ar': 'تصدير واستيراد بيانات القائمة (JSON)',
    },
    'appearance_title': {'en': 'Appearance & Theme', 'ar': 'المظهر والألوان'},
    'mode_daylight': {'en': 'Daylight', 'ar': 'نهاري ساطع'},
    'mode_night': {'en': 'Night Shift', 'ar': 'ليلي مريح'},
    'doodle_pattern_toggle': {
      'en': 'Subtle Bistro Doodle Texture',
      'ar': 'نقشة رسومات الكانتين الخفيفة',
    },
    'language_label': {'en': 'Language / اللغة', 'ar': 'اللغة / Language'},
    'server_connection_label': {
      'en': 'Canteen Server Endpoint',
      'ar': 'عنوان خادم الكانتين',
    },
    'sign_out_cta': {'en': 'Sign Out', 'ar': 'تسجيل الخروج'},
    'about_project_title': {
      'en': 'About EVA Canteen',
      'ar': 'عن مشروع كانتين إيفا',
    },
    'about_project_credits': {
      'en': 'Developed by students at EVA International Applied Technology School:\nEyad Gaber • Anwar Qasem • Dina Mahmoud • Ahmed Mohamed\n\nLicensed under GNU GPL v3.0.',
      'ar': 'تم تطوير هذا المشروع من قبل طلاب في مدرسة إيفا الدولية للتكنولوجيا التطبيقية:\nإياد جابر • أنور قاسم • دينا محمود • أحمد محمد\n\nمرخص بموجب رخصة GNU GPL v3.0.',
    },
  };
}
