import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/storage/token_storage.dart';
import '../models.dart';

/// Thrown by services on any handled failure. Carries a user-facing message.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Unwraps the `{success, data, message}` envelope, throwing on `success != true`.
Object? _unwrap(Response res) {
  final body = res.data;
  if (body is Map && body['success'] == true) {
    return body['data'];
  }
  final msg = body is Map ? body['message']?.toString() : null;
  throw ApiException(msg ?? 'Permintaan gagal', statusCode: res.statusCode);
}

class AuthService {
  static Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final res = await ApiClient.instance.post(
        ApiEndpoints.register,
        data: {
          'name': name,
          'email': email,
          'password': password,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );
      _persistAuth(_unwrap(res));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await ApiClient.instance.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );
      _persistAuth(_unwrap(res));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  static Future<void> signOut() async {
    try {
      await ApiClient.instance.post(ApiEndpoints.logout);
    } on DioException {
      // ignore — local clear still runs
    } finally {
      await TokenStorage.clear();
    }
  }

  static Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final res = await ApiClient.instance.put(
        ApiEndpoints.changePassword,
        data: {'old_password': oldPassword, 'new_password': newPassword},
      );
      final data = _unwrap(res);
      // Backend revokes old tokens and issues a new one.
      final token = data is Map ? data['token']?.toString() : null;
      if (token != null) await TokenStorage.saveToken(token);
    } on DioException catch (e) {
      final data = e.response?.data;
      final errors = data is Map ? data['errors'] : null;
      if (errors is Map && errors['old_password'] is List) {
        throw ApiException((errors['old_password'] as List).first.toString(),
            statusCode: 422);
      }
      throw _mapError(e);
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await TokenStorage.getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> _persistAuth(Object? data) async {
    if (data is! Map) throw ApiException('Respons tidak valid');
    final token = data['token']?.toString();
    final user = data['user'];
    if (token == null) throw ApiException('Token tidak ditemukan');
    await TokenStorage.saveToken(token);
    if (user is Map) {
      await TokenStorage.saveUser(Map<String, dynamic>.from(user));
    }
  }

  static ApiException _mapError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final msg = data is Map ? data['message']?.toString() : null;
    switch (status) {
      case 401:
        return ApiException(msg ?? 'Email atau password salah', statusCode: 401);
      case 403:
        return ApiException(msg ?? 'Akun kamu dinonaktifkan', statusCode: 403);
      case 422:
        return ApiException(msg ?? 'Data tidak valid', statusCode: 422);
      case 429:
        return ApiException(msg ?? 'Terlalu banyak percobaan. Coba lagi sebentar.', statusCode: 429);
      default:
        return ApiException(extractApiError(e), statusCode: status);
    }
  }
}

class ProductService {
  static Future<List<Product>> fetchByCategory(String category) async {
    try {
      final res = await ApiClient.instance.get(ApiEndpoints.menus);
      final list = (_unwrap(res) as List?) ?? const [];
      final products = list
          .whereType<Map>()
          .map((m) => Product.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      if (category == 'Semua') return products;
      return products.where((p) => p.category == category).toList();
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }

  /// Category display names, with "Semua" prepended for the filter bar.
  static Future<List<String>> fetchCategories() async {
    try {
      final res = await ApiClient.instance.get(ApiEndpoints.categories);
      final list = (_unwrap(res) as List?) ?? const [];
      final names = list
          .whereType<Map>()
          .map((m) => m['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      return ['Semua', ...names];
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }
}

class OrderService {
  static List<Map<String, dynamic>> _itemsPayload(List<CartItem> cartItems) => cartItems
      .map((i) => {
            'menu_id': i.product.id,
            'quantity': i.quantity,
            'notes': i.note,
          })
      .toList();

  /// Server-side pricing of the cart (incl. voucher) without creating an order.
  static Future<OrderQuote> quote({
    required List<CartItem> cartItems,
    int? voucherId,
  }) async {
    try {
      final res = await ApiClient.instance.post(
        ApiEndpoints.orderQuote,
        data: {
          'voucher_id': ?voucherId,
          'items': _itemsPayload(cartItems),
        },
      );
      return OrderQuote.fromJson(Map<String, dynamic>.from(_unwrap(res) as Map));
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }

  static Future<Order> createOrder({
    required List<CartItem> cartItems,
    required String paymentMethod, // cash | qris | virtual_account
    String? paymentChannel, // bca | bni | bri | mandiri (VA only)
    String orderType = 'preorder',
    int? voucherId,
  }) async {
    try {
      final res = await ApiClient.instance.post(
        ApiEndpoints.orders,
        data: {
          'order_type': orderType,
          'payment_method': paymentMethod,
          'payment_channel': ?paymentChannel,
          'voucher_id': ?voucherId,
          'items': _itemsPayload(cartItems),
        },
      );
      final data = _unwrap(res) as Map;
      return Order.fromJson(Map<String, dynamic>.from(data), items: cartItems);
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }

  /// Polls a single order to refresh its status/payment fields.
  static Future<Order> fetchOrder(int id) async {
    try {
      final res = await ApiClient.instance.get(ApiEndpoints.orderDetail(id));
      final data = _unwrap(res) as Map;
      return Order.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }

  static Future<List<Map<String, dynamic>>> fetchHistory() async {
    try {
      final res = await ApiClient.instance.get(ApiEndpoints.orders);
      final list = (_unwrap(res) as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }
}

class LoyaltyService {
  static Future<LoyaltySummary> summary() async {
    try {
      final res = await ApiClient.instance.get(ApiEndpoints.loyalty);
      return LoyaltySummary.fromJson(Map<String, dynamic>.from(_unwrap(res) as Map));
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }

  static Future<List<PointReward>> rewards() async {
    try {
      final res = await ApiClient.instance.get(ApiEndpoints.loyaltyRewards);
      return ((_unwrap(res) as List?) ?? const [])
          .whereType<Map>()
          .map((m) => PointReward.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }

  static Future<List<PointHistory>> history() async {
    try {
      final res = await ApiClient.instance.get(ApiEndpoints.loyaltyHistory);
      return ((_unwrap(res) as List?) ?? const [])
          .whereType<Map>()
          .map((m) => PointHistory.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }

  static Future<List<UserVoucher>> vouchers() async {
    try {
      final res = await ApiClient.instance.get(ApiEndpoints.loyaltyVouchers);
      return ((_unwrap(res) as List?) ?? const [])
          .whereType<Map>()
          .map((m) => UserVoucher.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }

  static Future<UserVoucher> redeem(int rewardId) async {
    try {
      final res = await ApiClient.instance.post(ApiEndpoints.redeemReward(rewardId));
      return UserVoucher.fromJson(Map<String, dynamic>.from(_unwrap(res) as Map));
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }
}

class NotificationService {
  static Future<List<AppNotification>> fetch() async {
    try {
      final res = await ApiClient.instance.get(ApiEndpoints.notifications);
      return ((_unwrap(res) as List?) ?? const [])
          .whereType<Map>()
          .map((m) => AppNotification.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }

  static Future<int> unreadCount() async {
    try {
      final res = await ApiClient.instance.get(ApiEndpoints.notificationsUnread);
      final data = _unwrap(res);
      return data is Map ? (data['unread_count'] as num?)?.toInt() ?? 0 : 0;
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }

  static Future<void> markRead(int id) async {
    try {
      await ApiClient.instance.patch(ApiEndpoints.notificationRead(id));
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }

  static Future<void> markAllRead() async {
    try {
      await ApiClient.instance.post(ApiEndpoints.notificationsReadAll);
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }
}

class SupportMessage {
  SupportMessage({
    required this.id,
    required this.fromCustomer,
    required this.body,
    this.createdAt,
  });

  final int id;
  final bool fromCustomer;
  final String body;
  final DateTime? createdAt;

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
        id: (j['id'] as num).toInt(),
        fromCustomer: j['from_customer'] == true || j['from_customer'] == 1,
        body: j['body']?.toString() ?? '',
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal(),
      );
}

class SupportService {
  /// Pass [afterId] to fetch only messages newer than that id (polling).
  static Future<List<SupportMessage>> fetchMessages({int? afterId}) async {
    try {
      final res = await ApiClient.instance.get(
        ApiEndpoints.supportMessages,
        queryParameters: {'after_id': ?afterId},
      );
      final list = (_unwrap(res) as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((m) => SupportMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }

  static Future<SupportMessage> send(String body) async {
    try {
      final res = await ApiClient.instance.post(
        ApiEndpoints.supportMessages,
        data: {'body': body},
      );
      final data = _unwrap(res) as Map;
      return SupportMessage.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }
}

class ProfileService {
  static Future<Map<String, dynamic>> fetchProfile() async {
    try {
      final res = await ApiClient.instance.get(ApiEndpoints.me);
      final data = _unwrap(res);
      if (data is! Map) throw ApiException('Profil tidak ditemukan');
      final user = Map<String, dynamic>.from(data);
      await TokenStorage.saveUser(user);
      return user;
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }
}
