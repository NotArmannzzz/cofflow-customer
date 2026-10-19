import 'core/utils/json_parse.dart';

/// A condiment option (e.g., "Large", "Less Sugar", "Extra Espresso Shot").
class CondimentOption {
  final int id;
  final int condimentGroupId;
  final String name;
  final double additionalPrice;

  const CondimentOption({
    required this.id,
    required this.condimentGroupId,
    required this.name,
    required this.additionalPrice,
  });

  factory CondimentOption.fromJson(Map<String, dynamic> json) => CondimentOption(
        id: parseInt(json['id']),
        condimentGroupId: parseInt(json['condiment_group_id']),
        name: json['name']?.toString() ?? '',
        additionalPrice: parseDouble(json['additional_price']),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CondimentOption && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// A group of condiment options (e.g., "Ukuran", "Tingkat Manis", "Extra").
class CondimentGroup {
  final int id;
  final String name;
  final String type; // single_select | multi_select
  final bool isRequired;
  final List<CondimentOption> options;

  const CondimentGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.isRequired,
    required this.options,
  });

  bool get isMulti => type == 'multi_select';

  factory CondimentGroup.fromJson(Map<String, dynamic> json) => CondimentGroup(
        id: parseInt(json['id']),
        name: json['name']?.toString() ?? '',
        type: json['type']?.toString() ?? 'single_select',
        isRequired: parseBool(json['is_required']),
        options: (json['options'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CondimentOption.fromJson)
            .toList(),
      );
}

/// A menu item from the backend (`/menus`).
class Product {
  final int id;
  final String name;
  final String image;
  final int price;
  final String category; // category display name, e.g. "Coffee"
  final String description;
  /// Member points earned per unit (backend `points_per_item`).
  final int points;
  final List<CondimentGroup> condimentGroups;

  Product({
    required this.id,
    required this.name,
    required this.image,
    required this.price,
    required this.category,
    required this.description,
    this.points = 0,
    this.condimentGroups = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final cat = json['category'];
    return Product(
      id: parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      image: json['image_url']?.toString() ?? '',
      price: parseDouble(json['price']).round(),
      category: cat is Map ? (cat['name']?.toString() ?? '') : '',
      description: json['description']?.toString() ?? '',
      points: parseInt(json['points_per_item']),
      condimentGroups: (json['condiment_groups'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CondimentGroup.fromJson)
          .toList(),
    );
  }
}

class CartItem {
  final Product product;
  final List<CondimentOption> selectedCondiments;
  final String notes;
  int quantity;

  CartItem({
    required this.product,
    this.selectedCondiments = const [],
    this.notes = '',
    this.quantity = 1,
  });

  List<int> get condimentOptionIds =>
      selectedCondiments.map((c) => c.id).toList();

  int get unitPrice {
    final condimentSum = selectedCondiments.fold<double>(
      0.0,
      (sum, c) => sum + c.additionalPrice,
    );
    return product.price + condimentSum.round();
  }

  int get totalPrice => unitPrice * quantity;

  String get uniqueId {
    final ids = [...condimentOptionIds]..sort();
    final cleanNotes = notes.trim().toLowerCase();
    return '${product.id}_${ids.join('-')}_$cleanNotes';
  }

  String get note {
    final parts = <String>[];
    if (selectedCondiments.isNotEmpty) {
      parts.add(selectedCondiments.map((c) => c.name).join(', '));
    }
    if (notes.trim().isNotEmpty) {
      parts.add('Catatan: ${notes.trim()}');
    }
    return parts.join(' | ');
  }
}

/// Maps backend status enum → Indonesian display label.
const Map<String, String> kStatusLabels = {
  'pending': 'Pesanan Diterima',
  'processing': 'Sedang Dibuat',
  'ready': 'Siap Diambil',
  'completed': 'Selesai',
  'cancelled': 'Dibatalkan',
};

/// Ordered status steps used by the tracking timeline.
const List<String> kStatusFlow = ['pending', 'processing', 'ready', 'completed'];

class Order {
  final int id;
  final List<CartItem> items;
  final int total;
  final DateTime timestamp;
  final String status; // backend enum value
  final int queueNumber;
  final String paymentMethod;
  final String paymentStatus;
  final String? qrCodeUrl;
  final String? vaNumber;
  final String? paymentChannel;

  Order({
    required this.id,
    required this.items,
    required this.total,
    required this.timestamp,
    required this.status,
    required this.queueNumber,
    required this.paymentMethod,
    required this.paymentStatus,
    this.qrCodeUrl,
    this.vaNumber,
    this.paymentChannel,
  });

  String get statusLabel => kStatusLabels[status] ?? status;

  String get estimatedTime {
    switch (status) {
      case 'completed':
        return 'Selesai';
      case 'ready':
        return 'Siap';
      case 'cancelled':
        return '-';
      default:
        return '5-7 Menit';
    }
  }

  bool get isActive => status == 'pending' || status == 'processing' || status == 'ready';

  /// Builds an order from a backend payload. [items] is supplied separately
  /// because polling responses are only used to refresh status fields.
  factory Order.fromJson(Map<String, dynamic> json, {List<CartItem> items = const []}) {
    return Order(
      id: parseInt(json['id']),
      items: items,
      total: parseDouble(json['total']).round(),
      timestamp: parseDateTime(json['created_at']) ?? DateTime.now(),
      status: json['status']?.toString() ?? 'pending',
      queueNumber: parseInt(json['queue_number']),
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      paymentStatus: json['payment_status']?.toString() ?? 'unpaid',
      qrCodeUrl: json['qr_code_url']?.toString(),
      vaNumber: json['va_number']?.toString(),
      paymentChannel: json['payment_channel']?.toString(),
    );
  }

  Order copyWith({String? status, String? paymentStatus}) => Order(
        id: id,
        items: items,
        total: total,
        timestamp: timestamp,
        status: status ?? this.status,
        queueNumber: queueNumber,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        qrCodeUrl: qrCodeUrl,
        vaNumber: vaNumber,
        paymentChannel: paymentChannel,
      );
}

/// Customer profile, sourced from `/auth/me`.
class UserProfile {
  final int id;
  final String fullName;
  final String email;
  final String? phone;
  final String role;
  final DateTime? memberSince;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    this.memberSince,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: parseInt(json['id']),
      fullName: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'customer',
      memberSince: parseDateTime(json['created_at']),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Loyalty / membership
// ─────────────────────────────────────────────────────────

const Map<String, String> kTierLabels = {
  'bronze': 'Bronze',
  'silver': 'Silver',
  'gold': 'Gold',
};

class TierThreshold {
  TierThreshold(this.tier, this.threshold);
  final String tier;
  final int threshold;
}

/// `/loyalty` summary: balance, tier and progress to the next tier.
class LoyaltySummary {
  LoyaltySummary({
    required this.enabled,
    required this.pointsBalance,
    required this.lifetimePoints,
    required this.tier,
    this.nextTier,
    this.nextTierAt,
    required this.pointsToNextTier,
    required this.minItemPrice,
    required this.tiers,
  });

  final bool enabled;
  final int pointsBalance;
  final int lifetimePoints;
  final String tier;
  final String? nextTier;
  final int? nextTierAt;
  final int pointsToNextTier;
  final int minItemPrice;
  final List<TierThreshold> tiers;

  /// 0..1 progress from the current tier threshold to the next one.
  double get progress {
    if (nextTierAt == null) return 1;
    final current = tiers
        .firstWhere((t) => t.tier == tier, orElse: () => TierThreshold(tier, 0))
        .threshold;
    final span = nextTierAt! - current;
    if (span <= 0) return 1;
    return ((lifetimePoints - current) / span).clamp(0, 1).toDouble();
  }

  factory LoyaltySummary.fromJson(Map<String, dynamic> j) => LoyaltySummary(
        enabled: parseBool(j['enabled'], fallback: true),
        pointsBalance: parseInt(j['points_balance']),
        lifetimePoints: parseInt(j['lifetime_points']),
        tier: j['tier']?.toString() ?? 'bronze',
        nextTier: j['next_tier']?.toString(),
        nextTierAt: j['next_tier_at'] == null ? null : parseInt(j['next_tier_at']),
        pointsToNextTier: parseInt(j['points_to_next_tier']),
        minItemPrice: parseDouble(j['min_item_price']).round(),
        tiers: ((j['tiers'] as List?) ?? const [])
            .whereType<Map>()
            .map((t) => TierThreshold(t['tier']?.toString() ?? '', parseInt(t['threshold'])))
            .toList(),
      );
}

/// Reward from the catalog that can be exchanged for a voucher.
class PointReward {
  PointReward({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.value,
    this.maxDiscount,
    required this.minOrder,
    required this.pointsCost,
    required this.minTier,
    required this.soldOut,
    required this.tierLocked,
    required this.canRedeem,
  });

  final int id;
  final String name;
  final String description;
  final String type; // nominal | percentage
  final double value;
  final double? maxDiscount;
  final double minOrder;
  final int pointsCost;
  final String minTier;
  final bool soldOut;
  final bool tierLocked;
  final bool canRedeem;

  factory PointReward.fromJson(Map<String, dynamic> j) => PointReward(
        id: parseInt(j['id']),
        name: j['name']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        type: j['type']?.toString() ?? 'nominal',
        value: parseDouble(j['value']),
        maxDiscount: j['max_discount'] == null ? null : parseDouble(j['max_discount']),
        minOrder: parseDouble(j['min_order']),
        pointsCost: parseInt(j['points_cost']),
        minTier: j['min_tier']?.toString() ?? 'bronze',
        soldOut: parseBool(j['sold_out']),
        tierLocked: parseBool(j['tier_locked']),
        canRedeem: parseBool(j['can_redeem']),
      );
}

class PointHistory {
  PointHistory({
    required this.id,
    required this.type,
    required this.points,
    required this.description,
    this.createdAt,
  });

  final int id;
  final String type; // earn | redeem | adjust
  final int points;
  final String description;
  final DateTime? createdAt;

  factory PointHistory.fromJson(Map<String, dynamic> j) => PointHistory(
        id: parseInt(j['id']),
        type: j['type']?.toString() ?? '',
        points: parseInt(j['points']),
        description: j['description']?.toString() ?? '',
        createdAt: parseDateTime(j['created_at'])?.toLocal(),
      );
}

class UserVoucher {
  UserVoucher({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.value,
    this.maxDiscount,
    required this.minOrder,
    required this.status,
    this.expiresAt,
  });

  final int id;
  final String code;
  final String name;
  final String type;
  final double value;
  final double? maxDiscount;
  final double minOrder;
  final String status; // available | used | expired
  final DateTime? expiresAt;

  factory UserVoucher.fromJson(Map<String, dynamic> j) => UserVoucher(
        id: parseInt(j['id']),
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        type: j['type']?.toString() ?? 'nominal',
        value: parseDouble(j['value']),
        maxDiscount: j['max_discount'] == null ? null : parseDouble(j['max_discount']),
        minOrder: parseDouble(j['min_order']),
        status: j['status']?.toString() ?? 'available',
        expiresAt: parseDateTime(j['expires_at'])?.toLocal(),
      );
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.createdAt,
  });

  final int id;
  final String title;
  final String body;
  final String type;
  bool isRead;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: parseInt(j['id']),
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        isRead: parseBool(j['is_read']),
        createdAt: parseDateTime(j['created_at'])?.toLocal(),
      );
}

/// `/orders/quote` result: server-side totals for the current cart.
class OrderQuote {
  OrderQuote({
    required this.subtotal,
    required this.voucherDiscount,
    required this.total,
    required this.estimatedPoints,
  });

  final double subtotal;
  final double voucherDiscount;
  final double total;
  final int estimatedPoints;

  factory OrderQuote.fromJson(Map<String, dynamic> j) => OrderQuote(
        subtotal: parseDouble(j['subtotal']),
        voucherDiscount: parseDouble(j['voucher_discount']),
        total: parseDouble(j['total']),
        estimatedPoints: parseInt(j['estimated_points']),
      );
}
