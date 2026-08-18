import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/graphql/mutations.dart';

void main() {
  group('GQLMutations.addOrderItems', () {
    test('interpolates orderId, loungeId, menuItemId and quantity', () {
      final query = GQLMutations.addOrderItems(
        orderId: '1',
        loungeId: '2',
        menuItemId: 'm"1',
        quantity: 3,
      );

      expect(query, contains('addOrderItems('));
      expect(query, contains('orderId: "1"'));
      expect(query, contains('loungeId: "2"'));
      expect(query, contains(r'menuItemId: "m\"1"'));
      expect(query, contains('quantity: 3'));
    });

    test('defaults quantity to 1', () {
      final query = GQLMutations.addOrderItems(orderId: '1', loungeId: '2', menuItemId: 'm1');

      expect(query, contains('quantity: 1'));
    });

    test('does not send hookahItems — out of scope for this feature', () {
      final query = GQLMutations.addOrderItems(orderId: '1', loungeId: '2', menuItemId: 'm1');

      expect(query, isNot(contains('hookahItems:')));
      expect(query, contains('hookahItems {'));
    });
  });
}
