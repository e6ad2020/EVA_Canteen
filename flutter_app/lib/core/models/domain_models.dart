import 'package:equatable/equatable.dart';

enum UserRole { guest, student, admin }

enum OrderStatus {
  pending,
  preparing,
  delivered;

  static OrderStatus fromWire(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'preparing':
        return OrderStatus.preparing;
      case 'delivered':
        return OrderStatus.delivered;
      default:
        return OrderStatus.pending;
    }
  }

  String get wireValue => name;
}

class UserProfile extends Equatable {
  const UserProfile({
    required this.email,
    required this.role,
    this.profilePic = 'pic2',
    this.balance = 0,
    this.token,
  });

  final String email;
  final UserRole role;
  final String profilePic;
  final double balance;
  final String? token;

  bool get isAdmin => role == UserRole.admin;
  bool get isStudent => role == UserRole.student;

  String get avatarAssetPath => avatarAssetForPic(profilePic);

  static String avatarAssetForPic(String? pic) {
    switch (pic) {
      case 'pic1':
        return 'assets/images/pfp1.png';
      case 'pic3':
        return 'assets/images/pfp3.png';
      case 'pic2':
      default:
        return 'assets/images/pfp2.png';
    }
  }

  UserProfile copyWith({
    String? email,
    UserRole? role,
    String? profilePic,
    double? balance,
    String? token,
  }) {
    return UserProfile(
      email: email ?? this.email,
      role: role ?? this.role,
      profilePic: profilePic ?? this.profilePic,
      balance: balance ?? this.balance,
      token: token ?? this.token,
    );
  }

  Map<String, dynamic> toJson() => {
    'email': email,
    'role': role.name,
    'profilePic': profilePic,
    'balance': balance,
    'token': token,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final roleStr = (json['role'] as String?) ?? 'student';
    final role = switch (roleStr) {
      'admin' => UserRole.admin,
      'guest' => UserRole.guest,
      _ => UserRole.student,
    };
    return UserProfile(
      email: (json['email'] as String?) ?? '',
      role: role,
      profilePic: (json['profilePic'] as String?) ?? 'pic2',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      token: json['token'] as String?,
    );
  }

  @override
  List<Object?> get props => [email, role, profilePic, balance, token];
}

class CategoryItem extends Equatable {
  const CategoryItem({
    required this.key,
    required this.nameKey,
    this.productIds = const [],
  });

  final String key;
  final String nameKey;
  final List<String> productIds;

  bool get isArchive => key == 'archive';

  CategoryItem copyWith({
    String? key,
    String? nameKey,
    List<String>? productIds,
  }) {
    return CategoryItem(
      key: key ?? this.key,
      nameKey: nameKey ?? this.nameKey,
      productIds: productIds ?? this.productIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'name_key': nameKey,
    'productIds': productIds,
  };

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    final rawIds = json['productIds'];
    return CategoryItem(
      key: (json['key'] as String?) ?? '',
      nameKey: (json['name_key'] as String?) ?? '',
      productIds: rawIds is List
          ? rawIds.map((e) => e.toString()).toList(growable: false)
          : const [],
    );
  }

  @override
  List<Object?> get props => [key, nameKey, productIds];
}

class ProductItem extends Equatable {
  const ProductItem({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required this.price,
    required this.quantity,
    required this.image,
    required this.categoryKey,
  });

  final String id;
  final String nameKey;
  final String descriptionKey;
  final double price;
  final int quantity;
  final String image;
  final String categoryKey;

  bool get isUnlimited => quantity == 999;
  bool get isOutOfStock => !isUnlimited && quantity <= 0;
  bool get isLowStock => !isUnlimited && quantity > 0 && quantity <= 5;
  bool get isArchived => categoryKey == 'archive';

  ProductItem copyWith({
    String? id,
    String? nameKey,
    String? descriptionKey,
    double? price,
    int? quantity,
    String? image,
    String? categoryKey,
  }) {
    return ProductItem(
      id: id ?? this.id,
      nameKey: nameKey ?? this.nameKey,
      descriptionKey: descriptionKey ?? this.descriptionKey,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      image: image ?? this.image,
      categoryKey: categoryKey ?? this.categoryKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name_key': nameKey,
    'description_key': descriptionKey,
    'price': price,
    'quantity': quantity,
    'image': image,
    'category': categoryKey,
  };

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: (json['id'] as String?) ?? '',
      nameKey: (json['name_key'] as String?) ?? '',
      descriptionKey:
          (json['description_key'] as String?) ?? 'item_desc_default',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      image: (json['image'] as String?) ?? '',
      categoryKey:
          (json['category'] as String?) ??
          (json['category_key'] as String?) ??
          '',
    );
  }

  @override
  List<Object?> get props => [
    id,
    nameKey,
    descriptionKey,
    price,
    quantity,
    image,
    categoryKey,
  ];
}

class BundleOffer extends Equatable {
  const BundleOffer({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required this.itemIds,
    this.discountPercent = 0,
    this.isSuggestion = false,
    this.active = true,
    this.displayOrder = 0,
  });

  final String id;
  final String nameKey;
  final String descriptionKey;
  final List<String> itemIds;
  final double discountPercent;
  final bool isSuggestion;
  final bool active;
  final int displayOrder;

  BundleOffer copyWith({
    String? id,
    String? nameKey,
    String? descriptionKey,
    List<String>? itemIds,
    double? discountPercent,
    bool? isSuggestion,
    bool? active,
    int? displayOrder,
  }) {
    return BundleOffer(
      id: id ?? this.id,
      nameKey: nameKey ?? this.nameKey,
      descriptionKey: descriptionKey ?? this.descriptionKey,
      itemIds: itemIds ?? this.itemIds,
      discountPercent: discountPercent ?? this.discountPercent,
      isSuggestion: isSuggestion ?? this.isSuggestion,
      active: active ?? this.active,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name_key': nameKey,
    'description_key': descriptionKey,
    'itemIds': itemIds,
    'discountPercent': discountPercent,
    'isSuggestion': isSuggestion,
    'active': active,
    'displayOrder': displayOrder,
  };

  factory BundleOffer.fromJson(Map<String, dynamic> json) {
    final rawItems = json['itemIds'];
    return BundleOffer(
      id: (json['id'] as String?) ?? '',
      nameKey: (json['name_key'] as String?) ?? '',
      descriptionKey: (json['description_key'] as String?) ?? '',
      itemIds: rawItems is List
          ? rawItems.map((e) => e.toString()).toList(growable: false)
          : const [],
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0,
      isSuggestion: json['isSuggestion'] == true,
      active: json['active'] != false,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    id,
    nameKey,
    descriptionKey,
    itemIds,
    discountPercent,
    isSuggestion,
    active,
    displayOrder,
  ];
}

class PaymentMethodsConfig extends Equatable {
  const PaymentMethodsConfig({
    this.cash = true,
    this.card = true,
    this.wallet = true,
  });

  final bool cash;
  final bool card;
  final bool wallet;

  List<String> get enabledKeys => [
    if (cash) 'cash',
    if (card) 'card',
    if (wallet) 'wallet',
  ];

  bool isEnabled(String method) {
    switch (method) {
      case 'cash':
        return cash;
      case 'card':
        return card;
      case 'wallet':
        return wallet;
      default:
        return false;
    }
  }

  PaymentMethodsConfig copyWith({bool? cash, bool? card, bool? wallet}) {
    return PaymentMethodsConfig(
      cash: cash ?? this.cash,
      card: card ?? this.card,
      wallet: wallet ?? this.wallet,
    );
  }

  Map<String, dynamic> toJson() => {
    'cash': cash,
    'card': card,
    'wallet': wallet,
  };

  factory PaymentMethodsConfig.fromJson(Map<String, dynamic> json) {
    return PaymentMethodsConfig(
      cash: json['cash'] != false,
      card: json['card'] != false,
      wallet: json['wallet'] != false,
    );
  }

  @override
  List<Object?> get props => [cash, card, wallet];
}

class OrderLineItem extends Equatable {
  const OrderLineItem({
    required this.id,
    required this.quantity,
    required this.price,
    required this.nameKey,
    this.isDiscount = false,
    this.bundleId,
  });

  final String id;
  final int quantity;
  final double price;
  final String nameKey;
  final bool isDiscount;
  final String? bundleId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'quantity': quantity,
    'price': price,
    'name_key': nameKey,
    'isDiscount': isDiscount,
    if (bundleId != null) 'bundleId': bundleId,
  };

  factory OrderLineItem.fromJson(Map<String, dynamic> json) {
    return OrderLineItem(
      id: (json['id'] as String?) ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      nameKey: (json['name_key'] as String?) ?? '',
      isDiscount: json['isDiscount'] == true,
      bundleId: json['bundleId'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, quantity, price, nameKey, isDiscount, bundleId];
}

class CanteenOrder extends Equatable {
  const CanteenOrder({
    required this.id,
    required this.totalAmount,
    required this.status,
    required this.paymentMethod,
    required this.timestamp,
    required this.items,
    required this.userEmail,
    this.userProfilePic = 'pic2',
  });

  final String id;
  final double totalAmount;
  final OrderStatus status;
  final String paymentMethod;
  final DateTime timestamp;
  final List<OrderLineItem> items;
  final String userEmail;
  final String userProfilePic;

  String get pickupNumber {
    final match = RegExp(r'^ORD-(\d+)-').firstMatch(id);
    if (match != null) {
      return '#${match.group(1)}';
    }
    return id;
  }

  bool isPlacedOnDate(DateTime localDay) {
    final localTs = timestamp.toLocal();
    return localTs.year == localDay.year &&
        localTs.month == localDay.month &&
        localTs.day == localDay.day;
  }

  bool get isToday => isPlacedOnDate(DateTime.now());

  List<OrderLineItem> get regularItems =>
      items.where((i) => !i.isDiscount).toList(growable: false);

  List<OrderLineItem> get discountItems =>
      items.where((i) => i.isDiscount).toList(growable: false);

  int get totalItemCount =>
      regularItems.fold<int>(0, (sum, item) => sum + item.quantity);

  CanteenOrder copyWith({OrderStatus? status}) {
    return CanteenOrder(
      id: id,
      totalAmount: totalAmount,
      status: status ?? this.status,
      paymentMethod: paymentMethod,
      timestamp: timestamp,
      items: items,
      userEmail: userEmail,
      userProfilePic: userProfilePic,
    );
  }

  factory CanteenOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final userMap = json['user'] as Map<String, dynamic>?;
    final rawTs = json['timestamp']?.toString() ?? '';
    return CanteenOrder(
      id: (json['id'] as String?) ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      status: OrderStatus.fromWire(json['status'] as String?),
      paymentMethod: (json['paymentMethod'] as String?) ?? 'cash',
      timestamp: DateTime.tryParse(rawTs) ?? DateTime.now(),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((e) => OrderLineItem.fromJson(Map<String, dynamic>.from(e)))
                .toList(growable: false)
          : const [],
      userEmail: (userMap?['email'] as String?) ?? 'Guest',
      userProfilePic: (userMap?['profilePic'] as String?) ?? 'pic2',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'totalAmount': totalAmount,
    'status': status.wireValue,
    'paymentMethod': paymentMethod,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(growable: false),
    'user': {'email': userEmail, 'profilePic': userProfilePic},
  };

  @override
  List<Object?> get props => [
    id,
    totalAmount,
    status,
    paymentMethod,
    timestamp,
    items,
    userEmail,
    userProfilePic,
  ];
}

class SalesRankItem extends Equatable {
  const SalesRankItem({
    required this.id,
    required this.nameKey,
    required this.image,
    required this.count,
    this.revenue = 0,
    this.quantity = 999,
  });

  final String id;
  final String nameKey;
  final String image;
  final int count;
  final double revenue;
  final int quantity;

  factory SalesRankItem.fromJson(Map<String, dynamic> json) {
    return SalesRankItem(
      id: (json['id'] as String?) ?? '',
      nameKey: (json['name_key'] as String?) ?? '',
      image: (json['image'] as String?) ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 999,
    );
  }

  @override
  List<Object?> get props => [id, nameKey, image, count, revenue, quantity];
}

class AnalyticsSnapshot extends Equatable {
  const AnalyticsSnapshot({
    required this.totalRevenue,
    required this.totalOrders,
    required this.avgOrderValue,
    required this.itemSalesRanking,
    required this.lowStockProducts,
    required this.dailyOrders,
    required this.dailyRevenue,
    required this.ordersByStatus,
    required this.revenueByPaymentMethod,
    required this.selectedMonth,
    required this.selectedYear,
    required this.availableYears,
  });

  final double totalRevenue;
  final int totalOrders;
  final double avgOrderValue;
  final List<SalesRankItem> itemSalesRanking;
  final List<SalesRankItem> lowStockProducts;
  final Map<int, int> dailyOrders;
  final Map<int, double> dailyRevenue;
  final Map<String, int> ordersByStatus;
  final Map<String, double> revenueByPaymentMethod;
  final int selectedMonth;
  final int selectedYear;
  final List<int> availableYears;

  factory AnalyticsSnapshot.fromJson(Map<String, dynamic> json) {
    final ordersMap = <int, int>{};
    final rawDailyOrders = json['dailyOrders'];
    if (rawDailyOrders is Map) {
      for (final entry in rawDailyOrders.entries) {
        final day = int.tryParse(entry.key.toString());
        if (day != null) {
          ordersMap[day] = (entry.value as num?)?.toInt() ?? 0;
        }
      }
    }

    final revenueMap = <int, double>{};
    final rawDailyRevenue = json['dailyRevenue'];
    if (rawDailyRevenue is Map) {
      for (final entry in rawDailyRevenue.entries) {
        final day = int.tryParse(entry.key.toString());
        if (day != null) {
          revenueMap[day] = (entry.value as num?)?.toDouble() ?? 0;
        }
      }
    }

    final statusMap = <String, int>{};
    final rawStatus = json['ordersByStatus'];
    if (rawStatus is Map) {
      for (final entry in rawStatus.entries) {
        statusMap[entry.key.toString()] = (entry.value as num?)?.toInt() ?? 0;
      }
    }

    final paymentMap = <String, double>{};
    final rawMethods = json['revenueByPaymentMethod'];
    if (rawMethods is Map) {
      for (final entry in rawMethods.entries) {
        final val = entry.value;
        if (val is Map) {
          paymentMap[entry.key.toString()] =
              (val['revenue'] as num?)?.toDouble() ?? 0;
        } else if (val is num) {
          paymentMap[entry.key.toString()] = val.toDouble();
        }
      }
    }

    final now = DateTime.now();
    return AnalyticsSnapshot(
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      avgOrderValue: (json['avgOrderValue'] as num?)?.toDouble() ?? 0,
      itemSalesRanking: (json['itemSalesRanking'] as List?)
              ?.whereType<Map>()
              .map((e) => SalesRankItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false) ??
          const [],
      lowStockProducts: (json['lowStockProducts'] as List?)
              ?.whereType<Map>()
              .map((e) => SalesRankItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false) ??
          const [],
      dailyOrders: ordersMap,
      dailyRevenue: revenueMap,
      ordersByStatus: statusMap,
      revenueByPaymentMethod: paymentMap,
      selectedMonth: (json['selectedMonth'] as num?)?.toInt() ?? now.month,
      selectedYear: (json['selectedYear'] as num?)?.toInt() ?? now.year,
      availableYears: (json['availableYears'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList(growable: false) ??
          [now.year],
    );
  }

  @override
  List<Object?> get props => [
    totalRevenue,
    totalOrders,
    avgOrderValue,
    itemSalesRanking,
    lowStockProducts,
    dailyOrders,
    dailyRevenue,
    ordersByStatus,
    revenueByPaymentMethod,
    selectedMonth,
    selectedYear,
    availableYears,
  ];
}

class WalletUserSummary extends Equatable {
  const WalletUserSummary({
    required this.email,
    required this.profilePic,
    required this.balance,
    required this.orderCount,
    required this.totalSpent,
    this.createdAt,
  });

  final String email;
  final String profilePic;
  final double balance;
  final int orderCount;
  final double totalSpent;
  final String? createdAt;

  factory WalletUserSummary.fromJson(Map<String, dynamic> json) {
    return WalletUserSummary(
      email: (json['email'] as String?) ?? '',
      profilePic: (json['profilePic'] as String?) ?? 'pic2',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0,
      createdAt: json['createdAt'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    email,
    profilePic,
    balance,
    orderCount,
    totalSpent,
    createdAt,
  ];
}

class WalletTransactionItem extends Equatable {
  const WalletTransactionItem({
    required this.id,
    required this.email,
    required this.delta,
    required this.balanceAfter,
    required this.reason,
    required this.actor,
    required this.timestamp,
  });

  final int id;
  final String email;
  final double delta;
  final double balanceAfter;
  final String reason;
  final String actor;
  final DateTime timestamp;

  factory WalletTransactionItem.fromJson(Map<String, dynamic> json) {
    return WalletTransactionItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: (json['email'] as String?) ?? '',
      delta: (json['delta'] as num?)?.toDouble() ?? 0,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0,
      reason: (json['reason'] as String?) ?? '',
      actor: (json['actor'] as String?) ?? 'admin',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    delta,
    balanceAfter,
    reason,
    actor,
    timestamp,
  ];
}

class AdminWalletsSnapshot extends Equatable {
  const AdminWalletsSnapshot({
    this.users = const [],
    this.recentTransactions = const [],
  });

  final List<WalletUserSummary> users;
  final List<WalletTransactionItem> recentTransactions;

  factory AdminWalletsSnapshot.fromJson(Map<String, dynamic> json) {
    return AdminWalletsSnapshot(
      users: (json['users'] as List?)
              ?.whereType<Map>()
              .map(
                (e) => WalletUserSummary.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList(growable: false) ??
          const [],
      recentTransactions: (json['recentTransactions'] as List?)
              ?.whereType<Map>()
              .map(
                (e) => WalletTransactionItem.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList(growable: false) ??
          const [],
    );
  }

  @override
  List<Object?> get props => [users, recentTransactions];
}

class AppliedBundleDiscount extends Equatable {
  const AppliedBundleDiscount({
    required this.bundle,
    required this.discountAmount,
  });

  final BundleOffer bundle;
  final double discountAmount;

  @override
  List<Object?> get props => [bundle, discountAmount];
}

class CartPricingSummary extends Equatable {
  const CartPricingSummary({
    required this.quantities,
    required this.subtotal,
    required this.appliedDiscounts,
    required this.totalDiscount,
    required this.finalTotal,
  });

  final Map<String, int> quantities;
  final double subtotal;
  final List<AppliedBundleDiscount> appliedDiscounts;
  final double totalDiscount;
  final double finalTotal;

  int get totalItemCount =>
      quantities.values.fold<int>(0, (sum, q) => sum + q);

  bool get isEmpty => totalItemCount == 0;

  @override
  List<Object?> get props => [
    quantities,
    subtotal,
    appliedDiscounts,
    totalDiscount,
    finalTotal,
  ];
}
