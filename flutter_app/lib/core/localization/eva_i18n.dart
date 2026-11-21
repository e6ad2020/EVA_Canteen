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
    'theme_moon': {'en': 'Moon', 'ar': 'القمر'},
    'theme_cobalt': {'en': 'Cobalt', 'ar': 'أزرق كوبالت'},
    'theme_emerald': {'en': 'Emerald', 'ar': 'زمردي'},
    'theme_violet': {'en': 'Violet', 'ar': 'بنفسجي'},
    'theme_amber': {'en': 'Amber', 'ar': 'كهرماني'},
    'theme_monochrome': {'en': 'Monochrome', 'ar': 'أحادي اللون'},
    'doodle_pattern_toggle': {
      'en': 'Subtle background pattern',
      'ar': 'نقشة خلفية خفيفة',
    },
    'navbar_behavior_title': {
      'en': 'Navigation bar labels',
      'ar': 'عناوين شريط التنقل',
    },
    'navbar_behavior_sub': {
      'en': 'Control whether tab titles disappear while scrolling down.',
      'ar': 'تحكّم في إخفاء عناوين التبويبات عند التمرير لأسفل.',
    },
    'navbar_adaptive': {
      'en': 'Hide on scroll',
      'ar': 'إخفاء عند التمرير',
    },
    'navbar_expanded': {
      'en': 'Always show',
      'ar': 'إظهار دائماً',
    },
    'navbar_compact': {
      'en': 'Icons only',
      'ar': 'أيقونات فقط',
    },
    'done_cta': {'en': 'Done', 'ar': 'تم'},
    'language_label': {'en': 'Language', 'ar': 'اللغة'},
    'server_connection_label': {
      'en': 'Server Endpoint',
      'ar': 'عنوان الخادم',
    },
    'sign_out_cta': {'en': 'Sign out', 'ar': 'تسجيل الخروج'},
    'about_project_button': {'en': 'About Project', 'ar': 'عن المشروع'},
    'about_project_title': {'en': 'About Project', 'ar': 'عن المشروع'},
    'about_project_credits': {
      'en':
          'Designed & engineered by:\nEyad Gaber • Anwar Qasem • Dina Mahmoud • Ahmed Mohamed\n\nLicensed under GNU GPL v3.0.',
      'ar':
          'تصميم وتطوير:\nإياد جابر • أنور قاسم • دينا محمود • أحمد محمد\n\nمرخص بموجب رخصة GNU GPL v3.0.',
    },
    'about_project_description': {
      'en':
          'This project was developed by students at EVA International Applied Technology School:\n\nEyad Gaber • Anwar Qasem • Dina Mahmoud • Ahmed Mohamed',
      'ar':
          'تم تطوير هذا المشروع من قبل طلاب في مدرسة إيفا الدولية للتكنولوجيا التطبيقية:\n\nإياد جابر • أنور قاسم • دينا محمود • أحمد محمد',
    },
    'about_project_school_badge': {
      'en': 'EVA International Applied Technology School',
      'ar': 'مدرسة إيفا الدولية للتكنولوجيا التطبيقية',
    },
    'ok_button': {'en': 'OK', 'ar': 'حسناً'},
    'copyright_title': {
      'en': 'License & Copyright',
      'ar': 'الترخيص وحقوق النشر',
    },
    'copyright_info_title': {
      'en': 'Copyright Information',
      'ar': 'معلومات حقوق النشر',
    },
    'copyright_info_text': {
      'en': 'Copyright (C) 2025 EVA International School',
      'ar': 'حقوق النشر (C) 2025 مدرسة إيفا الدولية للتكنولوچيا التطبيقية',
    },
    'license_info_title': {
      'en': 'License Information',
      'ar': 'معلومات الترخيص',
    },
    'license_info_text': {
      'en':
          'This project is licensed under the GNU General Public License v3.0 or later.',
      'ar':
          'هذا المشروع مرخص بموجب رخصة جنو العمومية العامة الإصدار 3.0 أو أحدث.',
    },
    'gpl_license_title': {
      'en': 'GNU General Public License',
      'ar': 'رخصة جنو العمومية العامة',
    },
    'gpl_license_text_1': {
      'en':
          'This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.',
      'ar':
          'هذا البرنامج هو برنامج حر؛ يمكنك إعادة توزيعه و/أو تعديله تحت شروط رخصة جنو العمومية العامة كما نشرتها مؤسسة البرمجيات الحرة؛ سواء الإصدار 3 من الرخصة، أو (حسب اختيارك) أي إصدار لاحق.',
    },
    'gpl_license_text_2': {
      'en':
          'This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.',
      'ar':
          'يُوزَّع هذا البرنامج على أمل أن يكون مفيداً، ولكن دون أية ضمانات؛ دون حتى ضمان المبيعية أو الملاءمة لغرض معين. انظر رخصة جنو العمومية العامة لمزيد من التفاصيل.',
    },
    'gpl_license_text_3': {
      'en':
          'You should have received a copy of the GNU General Public License along with this program. If not, see https://www.gnu.org/licenses/.',
      'ar':
          'من المفترض أن تكون قد استلمت نسخة من رخصة جنو العمومية العامة مع هذا البرنامج؛ وإن لم يحدث، فاذهب إلى https://www.gnu.org/licenses/.',
    },
    'catalog_grid_rank_hint': {
      'en':
          'Hold & drag cards across the grid or tap ‹ › to rank items just like the live menu.',
      'ar':
          'اضغط مطولاً واسحب البطاقات داخل الشبكة أو اضغط ‹ › لترتيب الأصناف كما تظهر في القائمة.',
    },
    'stock_out_short': {'en': 'Out', 'ar': 'نفد'},
    'stock_qty_short': {'en': 'Qty', 'ar': 'كمية'},
    'rank_earlier_tooltip': {'en': 'Move earlier', 'ar': 'تقديم الترتيب'},
    'rank_later_tooltip': {'en': 'Move later', 'ar': 'تأخير الترتيب'},
    'order_ready_alerts_title': {
      'en': 'Order Ready Alerts',
      'ar': 'تنبيهات جهوزية الطلب',
    },
    'order_ready_alerts_sub': {
      'en':
          'Get notified the moment your order is ready for pickup, even when the app is closed.',
      'ar':
          'تلقَّ إشعاراً فور جهوزية طلبك للاستلام، حتى عند إغلاق التطبيق.',
    },
    'notifications_status_enabled': {'en': 'Enabled', 'ar': 'مفعّلة'},
    'notifications_status_disabled': {'en': 'Not enabled', 'ar': 'غير مفعّلة'},
    'notifications_status_denied': {
      'en': 'Blocked in settings',
      'ar': 'محظورة من الإعدادات',
    },
    'notifications_status_unavailable': {
      'en': 'Live in-app only',
      'ar': 'داخل التطبيق فقط',
    },
    'notifications_enable_cta': {'en': 'Enable alerts', 'ar': 'تفعيل التنبيهات'},
    'notifications_denied_hint': {
      'en':
          'Enable notifications for EVA Canteen in your device or browser settings to receive background alerts. In-app alerts still work while open.',
      'ar':
          'فعّل الإشعارات لتطبيق كانتين إيفا من إعدادات الجهاز أو المتصفح لتلقي التنبيهات في الخلفية. التنبيهات داخل التطبيق تعمل دائماً أثناء الفتح.',
    },
    'notifications_view_order_cta': {'en': 'View', 'ar': 'عرض'},
    'order_ready_channel_name': {
      'en': 'Order Ready Alerts',
      'ar': 'تنبيهات جهوزية الطلب',
    },
    'order_ready_channel_desc': {
      'en': 'High-priority alerts when your EVA Canteen order is ready for pickup.',
      'ar': 'تنبيهات عالية الأولوية عند جهوزية طلبك للاستلام من كانتين إيفا.',
    },
  };
}
