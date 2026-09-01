import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/graphql/mutations.dart';
import 'package:user_app/core/models/hookah_template.dart';

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

    test('omits menuItems/hookahItems arguments when neither is provided', () {
      final query = GQLMutations.addOrderItems(orderId: '1', loungeId: '2');

      expect(query, isNot(contains('menuItems:')));
      expect(query, isNot(contains('hookahItems:')));
      expect(query, contains('hookahItems {'));
    });

    test('embeds hookahItems (hook.txt) when provided, without menuItems', () {
      final query = GQLMutations.addOrderItems(
        orderId: '1',
        loungeId: '2',
        hookahItems: const [HookahItemInput(templateId: '5', quantity: 1)],
      );

      expect(query, isNot(contains('menuItems:')));
      expect(query, contains(r'hookahItems: [{ templateId: "5", quantity: 1 }]'));
    });
  });
}
