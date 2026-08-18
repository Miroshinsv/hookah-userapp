import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/models/order.dart';

void main() {
  group('Order.fromJson', () {
    test('parses menuItems, hookahItems, subtotal and finalTotal', () {
      final order = Order.fromJson({
        'id': '1',
        'loungeId': '2',
        'status': 'in_progress',
        'menuItems': [
          {
            'id': 'mi1',
            'menuItemId': 'm1',
            'name': 'Кола',
            'quantity': 2,
            'unitPrice': 150.0,
            'status': 'new',
          },
        ],
        'hookahItems': [
          {
            'id': 'hi1',
            'name': 'Кальян',
            'flavor': 'Мята',
            'quantity': 1,
            'unitPrice': 800.0,
            'status': 'new',
          },
        ],
        'subtotal': 950.0,
        'finalTotal': 950.0,
      });

      expect(order.menuItems, hasLength(1));
      expect(order.menuItems.first.name, 'Кола');
      expect(order.menuItems.first.quantity, 2);
      expect(order.menuItems.first.unitPrice, 150.0);
      expect(order.hookahItems, hasLength(1));
      expect(order.hookahItems.first.flavor, 'Мята');
      expect(order.subtotal, 950.0);
      expect(order.finalTotal, 950.0);
    });

    test('defaults to empty item lists and null totals when fields are absent', () {
      final order = Order.fromJson({
        'id': '1',
        'loungeId': '2',
        'status': 'new',
      });

      expect(order.menuItems, isEmpty);
      expect(order.hookahItems, isEmpty);
      expect(order.subtotal, isNull);
      expect(order.finalTotal, isNull);
    });
  });

  group('Order.isEditable', () {
    for (final status in ['new', 'in_progress', 'calculation']) {
      test('true for status=$status', () {
        final order = Order(id: '1', loungeId: '2', status: status);
        expect(order.isEditable, isTrue);
      });
    }

    for (final status in ['completed', 'canceled', 'canceled_by_user', 'canceled_by_staff']) {
      test('false for status=$status', () {
        final order = Order(id: '1', loungeId: '2', status: status);
        expect(order.isEditable, isFalse);
      });
    }
  });

  group('Order.copyWith', () {
    test('updates item/total fields without losing unrelated fields', () {
      const order = Order(
        id: '1',
        loungeId: '2',
        flavor: 'Мята',
        comment: 'без сахара',
        phone: '+70000000000',
        arrivalAt: '2026-08-18T20:00:00Z',
        status: 'in_progress',
        createdAt: '2026-08-18T19:00:00Z',
      );

      final updated = order.copyWith(
        status: 'calculation',
        menuItems: const [
          OrderMenuItem(
            id: 'mi1',
            menuItemId: 'm1',
            name: 'Кола',
            quantity: 1,
            unitPrice: 150.0,
            status: 'new',
          ),
        ],
        subtotal: 150.0,
        finalTotal: 150.0,
      );

      expect(updated.status, 'calculation');
      expect(updated.menuItems, hasLength(1));
      expect(updated.subtotal, 150.0);
      expect(updated.finalTotal, 150.0);
      // Unrelated fields preserved.
      expect(updated.id, order.id);
      expect(updated.loungeId, order.loungeId);
      expect(updated.flavor, order.flavor);
      expect(updated.comment, order.comment);
      expect(updated.phone, order.phone);
      expect(updated.arrivalAt, order.arrivalAt);
      expect(updated.createdAt, order.createdAt);
    });
  });
}
