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
  static Future<Order> createOrder({
    required List<CartItem> cartItems,
    required String paymentMethod, // cash | qris | virtual_account
    String? paymentChannel, // bca | bni | bri | mandiri (VA only)
    String orderType = 'preorder',
  }) async {
    try {
      final res = await ApiClient.instance.post(
        ApiEndpoints.orders,
        data: {
          'order_type': orderType,
          'payment_method': paymentMethod,
          'payment_channel': ?paymentChannel,
          'items': cartItems
              .map((i) => {
                    'menu_id': i.product.id,
                    'quantity': i.quantity,
                    if (i.condimentOptionIds.isNotEmpty)
                      'condiment_option_ids': i.condimentOptionIds,
                    if (i.note.isNotEmpty) 'notes': i.note,
                  })
              .toList(),
        },
      );
      final data = _unwrap(res) as Map;
      return Order.fromJson(Map<String, dynamic>.from(data), items: cartItems);
    } on DioException catch (e) {
      throw ApiException(extractApiError(e));
    }
  }

  /// Polls a single order to refresh its status/payment fields.
  /// Returns null on transient errors (network, timeout) so polling can retry.
  static Future<Order?> fetchOrder(int id) async {
    try {
      final res = await ApiClient.instance.get(ApiEndpoints.orderDetail(id));
      final data = _unwrap(res) as Map;
      return Order.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      // Bubble up auth errors; swallow transient errors for polling resilience
      if (e.response?.statusCode == 401) rethrow;
      return null;
    } catch (_) {
      return null;
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
