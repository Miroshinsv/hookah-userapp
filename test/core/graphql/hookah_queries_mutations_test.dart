import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/graphql/mutations.dart';
import 'package:user_app/core/graphql/queries.dart';
import 'package:user_app/core/models/hookah_template.dart';

void main() {
  group('GQLQueries hookah', () {
    test('hookahTemplates embeds loungeId and requests basePrice/pricing', () {
      final query = GQLQueries.hookahTemplates('6');
      expect(query, contains('hookahTemplates'));
      expect(query, contains(r'"6"'));
      expect(query, contains('basePrice'));
      expect(query, contains('fillingPropertyId'));
    });

    test('defaultHookahTemplate embeds loungeId', () {
      final query = GQLQueries.defaultHookahTemplate('6');
      expect(query, contains('defaultHookahTemplate'));
      expect(query, contains(r'"6"'));
    });

    test('paidProperties embeds loungeId without a kind filter', () {
      final query = GQLQueries.paidProperties('6');
      expect(query, contains('paidProperties(loungeId: "6")'));
      expect(query, contains('kind'));
    });
  });

  group('GQLMutations.priceCustomHookah', () {
    // Бэкенд требует flavor: String! без default (проверено интроспекцией
    // прод-схемы), хотя пример в hook.txt его не передаёт — без этого
    // аргумента бэкенд отвечает ошибкой валидации.
    test('always sends flavor: "" regardless of other args', () {
      final query = GQLMutations.priceCustomHookah(loungeId: '6', strength: 5);
      expect(query, contains('flavor: ""'));
    });

    test('embeds fillingPropertyId, tobaccos and additionalPropertyIds when provided', () {
      final query = GQLMutations.priceCustomHookah(
        loungeId: '6',
        strength: 5,
        fillingPropertyId: '1',
        tobaccos: const [TobaccoLineInput(tobaccoId: '10', flavor: 'Мята', grammage: 20)],
        additionalPropertyIds: const ['3'],
      );
      expect(query, contains('fillingPropertyId: "1"'));
      expect(query, contains('tobaccos: [{ tobaccoId: "10", flavor: "Мята", grammage: 20.0 }]'));
      expect(query, contains('additionalPropertyIds: ["3"]'));
    });
  });

  group('GQLMutations.createOrder — hookahItems (hook.txt)', () {
    String baseCall({List<HookahItemInput> hookahItems = const []}) => GQLMutations.createOrder(
          loungeId: '5',
          hookahItems: hookahItems,
          phoneLast4: '1234',
          phoneMock: '+7 (900) ***-**-34',
          arrivalAt: '2026-08-25T20:00:00Z',
        );

    test('omits hookahItems argument when the cart is empty', () {
      final mutation = baseCall();
      expect(mutation, isNot(contains('hookahItems:')));
    });

    test('embeds hookahItems when provided', () {
      final mutation = baseCall(
        hookahItems: const [HookahItemInput(templateId: '5', quantity: 1)],
      );
      expect(mutation, contains(r'hookahItems: [{ templateId: "5", quantity: 1 }]'));
    });

    test('response selection set includes hookahItems/subtotal/finalTotal', () {
      final mutation = baseCall();
      expect(mutation, contains('hookahItems {'));
      expect(mutation, contains('subtotal'));
      expect(mutation, contains('finalTotal'));
    });
  });
}
