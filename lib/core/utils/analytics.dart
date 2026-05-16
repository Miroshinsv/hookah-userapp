import 'package:firebase_analytics/firebase_analytics.dart';

class Analytics {
  Analytics._();

  static final FirebaseAnalytics _fa = FirebaseAnalytics.instance;

  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _fa);

  // Auth
  static Future<void> login(String method) =>
      _fa.logLogin(loginMethod: method);

  static Future<void> signUp(String method) =>
      _fa.logSignUp(signUpMethod: method);

  // Orders
  static Future<void> orderCreated({
    required String loungeId,
    required String loungeName,
  }) =>
      _fa.logEvent(
        name: 'order_created',
        parameters: {'lounge_id': loungeId, 'lounge_name': loungeName},
      );

  static Future<void> orderCancelled(String orderId) =>
      _fa.logEvent(name: 'order_cancelled', parameters: {'order_id': orderId});

  // Lounge
  static Future<void> loungeOpened({
    required String loungeId,
    required String loungeName,
  }) =>
      _fa.logEvent(
        name: 'lounge_opened',
        parameters: {'lounge_id': loungeId, 'lounge_name': loungeName},
      );
}
