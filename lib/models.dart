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
  final List<CondimentGroup> condimentGroups;

  Product({
    required this.id,
    required this.name,
    required this.image,
    required this.price,
    required this.category,
    required this.description,
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
