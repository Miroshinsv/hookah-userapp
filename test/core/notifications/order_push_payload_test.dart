import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/notifications/order_push_payload.dart';

void main() {
  group('OrderPushPayload.tryParse', () {
    test('parses a valid order_status_updated payload', () {
      final payload = OrderPushPayload.tryParse({
        'eventType': 'order_status_updated',
        'orderId': '123',
        'loungeId': '42',
        'status': 'in_progress',
      });

      expect(payload, isNotNull);
      expect(payload!.orderId, '123');
      expect(payload.loungeId, '42');
      expect(payload.status, 'in_progress');
    });

    test('returns null when eventType is missing', () {
      final payload = OrderPushPayload.tryParse({
        'orderId': '123',
      });

      expect(payload, isNull);
    });

    test('returns null for an unrelated/unknown eventType', () {
      final payload = OrderPushPayload.tryParse({
        'eventType': 'chat_message_created',
        'orderId': '123',
      });

      expect(payload, isNull);
    });

    test('returns null when orderId is missing', () {
      final payload = OrderPushPayload.tryParse({
        'eventType': 'order_status_updated',
      });

      expect(payload, isNull);
    });

    test('returns null when orderId is blank', () {
      final payload = OrderPushPayload.tryParse({
        'eventType': 'order_status_updated',
        'orderId': '',
      });

      expect(payload, isNull);
    });

    test('parses with optional loungeId/status absent', () {
      final payload = OrderPushPayload.tryParse({
        'eventType': 'order_status_updated',
        'orderId': '123',
      });

      expect(payload, isNotNull);
      expect(payload!.orderId, '123');
      expect(payload.loungeId, isNull);
      expect(payload.status, isNull);
    });
  });
}
