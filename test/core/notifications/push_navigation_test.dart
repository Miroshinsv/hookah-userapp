import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/models/order.dart';
import 'package:user_app/core/notifications/push_navigation.dart';

Order _order(String id) => Order(id: id, loungeId: 'l1', status: 'new');

void main() {
  group('findOrderById', () {
    test('returns the matching order when present', () {
      final orders = [_order('1'), _order('2'), _order('3')];

      final found = findOrderById(orders, '2');

      expect(found, isNotNull);
      expect(found!.id, '2');
    });

    test('returns null when no order matches', () {
      final orders = [_order('1'), _order('2')];

      final found = findOrderById(orders, '99');

      expect(found, isNull);
    });

    test('returns null for an empty list', () {
      final found = findOrderById(const [], '1');

      expect(found, isNull);
    });
  });
}
