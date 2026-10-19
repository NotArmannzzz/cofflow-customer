class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String changePassword = '/auth/change-password';
  static const String updateProfile = '/auth/profile';

  // Info toko + FAQ (public)
  static const String appInfo = '/app-info';

  // Menu (public)
  static const String menus = '/menus';
  static const String categories = '/categories';
  static String menuDetail(int id) => '/menus/$id';

  // Orders
  static const String orders = '/orders';
  static const String orderQuote = '/orders/quote';
  static String orderDetail(int id) => '/orders/$id';
  static String orderPaymentStatus(int id) => '/orders/$id/payment-status';
  static String cancelOrder(int id) => '/orders/$id';

  // Loyalty / membership
  static const String loyalty = '/loyalty';
  static const String loyaltyHistory = '/loyalty/history';
  static const String loyaltyRewards = '/loyalty/rewards';
  static String redeemReward(int id) => '/loyalty/rewards/$id/redeem';
  static const String loyaltyVouchers = '/loyalty/vouchers';

  // Notifications
  static const String notifications = '/notifications';
  static String notificationRead(int id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/mark-all-read';
  static const String notificationsUnread = '/notifications/unread-count';

  // Customer service chat
  static const String supportMessages = '/support/messages';
  static const String supportUnread = '/support/unread-count';
}
