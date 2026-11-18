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
    'welcome_eyebrow': {
      'en': 'Freshly prepared • Live pickup',
      'ar': 'تحضير طازج • استلام فوري',
    },
    'welcome_headline': {
      'en': 'Order ahead, skip the wait.',
      'ar': 'اطلب مسبقاً، واستلم بدون انتظار.',
    },
    'welcome_subtitle': {
      'en':
          'Browse the live menu, pay with cash, card, or wallet, and pick up your order as soon as it is ready.',
      'ar':
          'تصفح القائمة المباشرة، ادفع نقداً أو بالبطاقة أو المحفظة، واستلم طلبك فور جهوزيته.',
    },
    'welcome_feat_fast': {'en': 'Live pickup pass', 'ar': 'بطاقة استلام فوري'},
    'welcome_feat_pay': {
      'en': 'Cash • Card • Wallet',
      'ar': 'نقداً • بطاقة • محفظة',
    },
    'welcome_feat_deals': {'en': 'Combo deals', 'ar': 'عروض التوفير'},
    'auth_welcome_back': {'en': 'Welcome back', 'ar': 'أهلاً بك مجدداً'},
    'auth_signin_sub': {
      'en': 'Sign in to order, pay from your wallet, and track pickup live.',
      'ar': 'سجّل الدخول للطلب والدفع من محفظتك ومتابعة الاستلام مباشرة.',
    },
    'auth_create_title': {'en': 'Create your account', 'ar': 'إنشاء حساب جديد'},
    'auth_register_sub': {
      'en': 'Pick an avatar and set up your account in seconds.',
      'ar': 'اختر صورتك الرمزية وأنشئ حسابك في ثوانٍ.',
    },
    'currency_symbol': {'en': 'L.E', 'ar': 'ج.م'},
    'sign_in_tab': {'en': 'Sign in', 'ar': 'تسجيل الدخول'},
    'register_tab': {'en': 'Create account', 'ar': 'إنشاء حساب'},
    'email_label': {'en': 'Email address', 'ar': 'البريد الإلكتروني'},
    'email_hint': {'en': 'name@example.com', 'ar': 'name@example.com'},
    'password_label': {'en': 'Password', 'ar': 'كلمة المرور'},
    'confirm_password_label': {
      'en': 'Confirm password',
      'ar': 'تأكيد كلمة المرور',
    },
    'choose_avatar_label': {
      'en': 'Select profile avatar',
      'ar': 'اختر الصورة الرمزية',
    },
    'login_cta': {'en': 'Sign in', 'ar': 'تسجيل الدخول'},
    'register_cta': {'en': 'Create account', 'ar': 'إنشاء حساب'},
    'browse_menu_guest': {
      'en': 'Browse menu as guest',
      'ar': 'تصفح القائمة كزائر',
    },
    'guest_mode_short': {'en': 'Guest mode', 'ar': 'تصفح كزائر'},
    'staff_portal_button': {
      'en': 'Staff & kitchen portal',
      'ar': 'بوابة المطبخ والإدارة',
    },
    'customer_portal_button': {
      'en': 'Back to customer sign in',
      'ar': 'العودة لدخول العملاء',
    },
    'canteen_open_badge': {'en': 'Open', 'ar': 'مفتوح'},
    'canteen_closed_badge': {'en': 'Closed', 'ar': 'مغلق'},
    'canteen_closed_browse_banner': {
      'en':
          'Counter is currently closed. You can browse the menu and prices, and checkout unlocks as soon as service opens.',
      'ar':
          'الكانتين مغلق حالياً. يمكنك تصفح القائمة والأسعار، وسيُفتح إتمام الطلب فور بدء الخدمة.',
    },
    'reconnecting_banner': {
      'en': 'Reconnecting to live server... Your cart is saved.',
      'ar': 'جاري إعادة الاتصال بالخادم... سلتك محفوظة.',
    },
    'nav_menu': {'en': 'Menu', 'ar': 'القائمة'},
    'nav_orders': {'en': 'Orders', 'ar': 'طلباتي'},
    'nav_settings': {'en': 'Settings', 'ar': 'الإعدادات'},
    'search_hint': {
      'en': 'Search menu...',
      'ar': 'ابحث في القائمة...',
    },
    'all_categories': {'en': 'All', 'ar': 'الكل'},
    'smart_combos_title': {
      'en': 'Featured Combos & Deals',
      'ar': 'عروض وكومبو التوفير',
    },
    'meal_ideas_badge': {'en': 'Combo', 'ar': 'كومبو'},
    'discount_badge': {'en': 'Save {percent}%', 'ar': 'وفر {percent}%'},
    'add_button': {'en': 'Add', 'ar': 'إضافة'},
    'add_combo_button': {'en': 'Add deal', 'ar': 'أضف العرض'},
    'out_of_stock': {'en': 'Sold out', 'ar': 'نفد'},
    'low_stock_left': {'en': '{count} left', 'ar': 'متبقي {count}'},
    'unlimited_stock': {'en': 'Available', 'ar': 'متوفر'},
    'review_order_cta': {'en': 'Review order', 'ar': 'مراجعة الطلب'},
    'items_count': {'en': '{count} items', 'ar': '{count} منتجات'},
    'cart_title': {'en': 'Your Order', 'ar': 'سلة طلبك'},
    'clear_cart': {'en': 'Clear', 'ar': 'إفراغ'},
    'cart_empty_title': {
      'en': 'Your order is empty',
      'ar': 'سلة طلبك فارغة',
    },
    'cart_empty_subtitle': {
      'en': 'Add freshly prepared items or combo deals from the menu.',
      'ar': 'أضف وجبات طازجة أو عروض كومبو من القائمة.',
    },
    'subtotal_label': {'en': 'Subtotal', 'ar': 'المجموع الفرعي'},
    'bundle_savings_label': {'en': 'saved', 'ar': 'توفير'},
    'bundle_discount_applied': {'en': 'Combo discount', 'ar': 'خصم العرض'},
    'total_label': {'en': 'Total', 'ar': 'الإجمالي'},
    'payment_method_label': {'en': 'Payment method', 'ar': 'طريقة الدفع'},
    'payment_cash': {'en': 'Cash', 'ar': 'نقداً'},
    'payment_card': {'en': 'Card', 'ar': 'بطاقة بنكية'},
    'payment_wallet': {'en': 'Wallet', 'ar': 'المحفظة'},
    'wallet_balance_label': {'en': 'Balance', 'ar': 'الرصيد'},
    'insufficient_wallet_hint': {
      'en':
          'Insufficient wallet balance ({balance}). Top up at the counter or choose another payment method.',
      'ar':
          'رصيد المحفظة غير كافٍ ({balance}). اشحن رصيدك من الكاونتر أو اختر طريقة دفع أخرى.',
    },
    'sign_in_to_checkout': {
      'en': 'Sign in to place order',
      'ar': 'سجّل الدخول لإتمام الطلب',
    },
    'place_order_cta': {'en': 'Place order', 'ar': 'تأكيد الطلب'},
    'live_pickup_pass': {'en': 'Live Pickup Pass', 'ar': 'بطاقة الاستلام المباشر'},
    'active_order_pill': {
      'en': 'Order {num} • {status}',
      'ar': 'طلب {num} • {status}',
    },
    'status_pending': {'en': 'Received', 'ar': 'تم الاستلام'},
    'status_preparing': {'en': 'Preparing', 'ar': 'قيد التحضير'},
    'status_delivered': {'en': 'Ready', 'ar': 'جاهز'},
    'pickup_counter_hint': {
      'en': 'Show this pickup code at the counter when collecting your order.',
      'ar': 'أظهر رقم الاستلام هذا عند الكاونتر لاستلام طلبك.',
    },
    'order_ready_toast': {
      'en': 'Order {num} is ready for pickup!',
      'ar': 'طلبك رقم {num} جاهز للاستلام الآن!',
    },
    'past_orders_title': {'en': 'Order History', 'ar': 'سجل الطلبات'},
    'no_orders_yet': {
      'en': 'No orders yet',
      'ar': 'لا توجد طلبات بعد',
    },
    'reorder_button': {'en': 'Reorder', 'ar': 'إعادة الطلب'},
    'reordered_toast': {
      'en': 'Available items added to your order.',
      'ar': 'تمت إضافة المنتجات المتوفرة إلى طلبك.',
    },
    // Admin & KDS (Crisp 1-word nav labels + descriptive page headers)
    'admin_portal_title': {
      'en': 'Kitchen & Operations',
      'ar': 'إدارة المطبخ والتشغيل',
    },
    'admin_signin_subtitle': {
      'en': 'Manage live orders, menu catalog, analytics, and customer wallets.',
      'ar': 'إدارة الطلبات المباشرة والقائمة والتحليلات ومحافظ العملاء.',
    },
    'admin_kds_tab': {'en': 'Orders', 'ar': 'الطلبات'},
    'admin_kds_title': {'en': 'Kitchen Display', 'ar': 'شاشة الطلبات المباشرة'},
    'admin_catalog_tab': {'en': 'Catalog', 'ar': 'المنتجات'},
    'admin_catalog_title': {'en': 'Catalog & Deals', 'ar': 'المنتجات والعروض'},
    'admin_analytics_tab': {'en': 'Analytics', 'ar': 'التحليلات'},
    'admin_ops_tab': {'en': 'Operations', 'ar': 'العمليات'},
    'admin_ops_title': {
      'en': 'Wallets & Operations',
      'ar': 'المحافظ وإعدادات التشغيل',
    },
    'kds_today_toggle': {'en': 'Live', 'ar': 'اليوم'},
    'kds_archive_toggle': {'en': 'Archive', 'ar': 'الأرشيف'},
    'kds_search_hint': {
      'en': 'Filter by #number or email...',
      'ar': 'ابحث برقم الطلب أو البريد...',
    },
    'kds_start_preparing': {
      'en': 'Start preparing',
      'ar': 'بدء التحضير',
    },
    'kds_mark_delivered': {
      'en': 'Mark ready',
      'ar': 'تحديد كجاهز',
    },
    'kds_reopen_pending': {'en': 'Move to received', 'ar': 'إرجاع للاستلام'},
    'kds_empty_column': {
      'en': 'No orders in this stage',
      'ar': 'لا توجد طلبات في هذه المرحلة',
    },
    // Catalog Studio
    'studio_products_tab': {'en': 'Items', 'ar': 'الأصناف'},
    'studio_categories_tab': {'en': 'Categories', 'ar': 'الفئات'},
    'studio_bundles_tab': {'en': 'Combos', 'ar': 'العروض'},
    'archive_shelf_label': {'en': 'Archived', 'ar': 'الأرشيف'},
    'new_product_cta': {'en': 'Add item', 'ar': 'إضافة صنف'},
    'edit_product_cta': {'en': 'Edit item', 'ar': 'تعديل الصنف'},
    'edit_button': {'en': 'Edit', 'ar': 'تعديل'},
    'restore_button': {'en': 'Restore', 'ar': 'استعادة'},
    'new_category_cta': {'en': 'Add category', 'ar': 'إضافة فئة'},
    'new_bundle_cta': {'en': 'Add combo', 'ar': 'إضافة عرض'},
    'upload_photo_cta': {'en': 'Upload photo', 'ar': 'رفع صورة'},
    'move_to_archive': {'en': 'Archive', 'ar': 'أرشفة'},
    'save_cta': {'en': 'Save changes', 'ar': 'حفظ التغييرات'},
    'cancel_cta': {'en': 'Cancel', 'ar': 'إلغاء'},
    'delete_cta': {'en': 'Delete', 'ar': 'حذف'},
    // Analytics
    'kpi_revenue': {'en': 'Revenue', 'ar': 'الإيرادات'},
    'kpi_orders': {'en': 'Orders', 'ar': 'الطلبات'},
    'kpi_aov': {'en': 'Avg. order', 'ar': 'متوسط الطلب'},
    'chart_orders_mode': {'en': 'Orders', 'ar': 'الطلبات'},
    'chart_revenue_mode': {'en': 'Revenue', 'ar': 'الإيرادات'},
    'top_products_title': {
      'en': 'Top Selling Items',
      'ar': 'الأصناف الأكثر مبيعاً',
    },
    'low_stock_watchlist': {
      'en': 'Low Stock Watchlist',
      'ar': 'تنبيهات المخزون',
    },
    // Ops, Wallet & Settings
    'storefront_status_card': {
      'en': 'Service Status',
      'ar': 'حالة الخدمة',
    },
    'payment_controls_title': {
      'en': 'Payment Methods',
      'ar': 'طرق الدفع المتاحة',
    },
    'wallet_desk_title': {
      'en': 'Customer Wallets',
      'ar': 'محافظ العملاء',
    },
    'wallet_accounts_count': {
      'en': '{count} accounts',
      'ar': '{count} حساب',
    },
    'wallet_search_hint': {
      'en': 'Search by email...',
      'ar': 'ابحث بالبريد الإلكتروني...',
    },
    'wallet_empty_hint': {
      'en': 'No customer accounts match this search.',
      'ar': 'لا توجد حسابات مطابقة للبحث.',
    },
    'wallet_add': {'en': 'Top up', 'ar': 'شحن'},
    'wallet_deduct': {'en': 'Deduct', 'ar': 'خصم'},
    'wallet_set': {'en': 'Set', 'ar': 'تعيين'},
    'currency_settings_title': {
      'en': 'Currency Symbol',
      'ar': 'رمز العملة باللغتين',
    },
    'catalog_backup_title': {
      'en': 'Catalog Backup (JSON)',
      'ar': 'نسخ واستيراد القائمة (JSON)',
    },
    'appearance_title': {'en': 'Appearance & Theme', 'ar': 'المظهر والثيمات'},
    'mode_daylight': {'en': 'Light', 'ar': 'نهاري'},
    'mode_night': {'en': 'Dark', 'ar': 'ليلي'},
    'theme_light_blue': {'en': 'Light Blue', 'ar': 'أزرق فاتح'},
    'theme_light_red': {'en': 'Light Red', 'ar': 'أحمر فاتح'},
    'theme_cobalt': {'en': 'Cobalt', 'ar': 'أزرق كوبالت'},
    'theme_emerald': {'en': 'Emerald', 'ar': 'زمردي'},
    'theme_violet': {'en': 'Violet', 'ar': 'بنفسجي'},
    'theme_amber': {'en': 'Amber', 'ar': 'كهرماني'},
    'theme_monochrome': {'en': 'Monochrome', 'ar': 'أحادي اللون'},
    'doodle_pattern_toggle': {
      'en': 'Subtle background pattern',
      'ar': 'نقشة خلفية خفيفة',
    },
    'language_label': {'en': 'Language', 'ar': 'اللغة'},
    'server_connection_label': {
      'en': 'Server Endpoint',
      'ar': 'عنوان الخادم',
    },
    'sign_out_cta': {'en': 'Sign out', 'ar': 'تسجيل الخروج'},
    'about_project_title': {
      'en': 'About EVA Canteen',
      'ar': 'حول كانتين إيفا',
    },
    'about_project_credits': {
      'en':
          'Designed & engineered by:\nEyad Gaber • Anwar Qasem • Dina Mahmoud • Ahmed Mohamed\n\nLicensed under GNU GPL v3.0.',
      'ar':
          'تصميم وتطوير:\nإياد جابر • أنور قاسم • دينا محمود • أحمد محمد\n\nمرخص بموجب رخصة GNU GPL v3.0.',
    },
  };
}
