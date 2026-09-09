import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/models/hookah_template.dart';

void main() {
  group('HookahTemplate', () {
    test('hasFilling is false for null and for the "0" sentinel (hook.txt раздел 1)', () {
      const withNull = HookahTemplate(templateId: '1', name: 'A', basePrice: 100);
      const withZero = HookahTemplate(templateId: '1', name: 'A', basePrice: 100, fillingPropertyId: '0');
      const withReal = HookahTemplate(templateId: '1', name: 'A', basePrice: 100, fillingPropertyId: '3');

      expect(withNull.hasFilling, isFalse);
      expect(withZero.hasFilling, isFalse);
      expect(withReal.hasFilling, isTrue);
    });

    test('hasTobaccos reflects the tobaccos list', () {
      const empty = HookahTemplate(templateId: '1', name: 'A', basePrice: 100);
      const withTobacco = HookahTemplate(
        templateId: '1',
        name: 'A',
        basePrice: 100,
        tobaccos: [HookahTemplateTobaccoLine(name: 'Chabacco', price: 0)],
      );

      expect(empty.hasTobaccos, isFalse);
      expect(withTobacco.hasTobaccos, isTrue);
    });

    test('displayPrice falls back to basePrice when pricing.totalPrice is 0 or absent', () {
      const noPricing = HookahTemplate(templateId: '1', name: 'A', basePrice: 1700);
      const zeroPricing = HookahTemplate(
        templateId: '1',
        name: 'A',
        basePrice: 1700,
        pricing: HookahTemplatePricing(totalPrice: 0),
      );
      const realPricing = HookahTemplate(
        templateId: '1',
        name: 'A',
        basePrice: 1700,
        pricing: HookahTemplatePricing(totalPrice: 1700),
      );

      expect(noPricing.displayPrice, 1700);
      expect(zeroPricing.displayPrice, 1700);
      expect(realPricing.displayPrice, 1700);
    });

    test('fromJson parses nested tobaccos and pricing', () {
      final tpl = HookahTemplate.fromJson({
        'templateId': '5',
        'name': 'На чаше премиум',
        'strength': 5,
        'basePrice': 1700,
        'fillingPropertyId': '1',
        'tobaccos': [
          {'tobaccoId': '1', 'name': 'Chabacco', 'flavor': '', 'grammage': 10, 'price': 0},
        ],
        'pricing': {'totalPrice': 1700},
      });

      expect(tpl.templateId, '5');
      expect(tpl.strength, 5);
      expect(tpl.tobaccos.single.name, 'Chabacco');
      expect(tpl.pricing?.totalPrice, 1700);
    });
  });

  group('TobaccoLineInput.toGraphQL', () {
    test('always includes tobaccoId, omits empty flavor and null grammage', () {
      const line = TobaccoLineInput(tobaccoId: '1');
      expect(line.toGraphQL(), '{ tobaccoId: "1" }');
    });

    test('includes flavor and grammage when provided', () {
      const line = TobaccoLineInput(tobaccoId: '1', flavor: 'Мята', grammage: 20);
      expect(line.toGraphQL(), '{ tobaccoId: "1", flavor: "Мята", grammage: 20.0 }');
    });
  });

  group('HookahItemInput.toGraphQL', () {
    test('template selection — only templateId and quantity', () {
      const input = HookahItemInput(templateId: '5', quantity: 1);
      expect(input.toGraphQL(), '{ templateId: "5", quantity: 1 }');
    });

    test('strength override and comment are included only when set', () {
      const input = HookahItemInput(
        templateId: '5',
        strength: 9,
        comment: 'поменьше дыма',
        quantity: 1,
      );
      expect(
        input.toGraphQL(),
        '{ templateId: "5", strength: 9, comment: "поменьше дыма", quantity: 1 }',
      );
    });

    test('constructor selection — fillingPropertyId, tobaccos, additionalPropertyIds', () {
      const input = HookahItemInput(
        fillingPropertyId: '1',
        tobaccos: [TobaccoLineInput(tobaccoId: '10', flavor: 'Мята', grammage: 20)],
        additionalPropertyIds: ['7'],
        strength: 5,
        quantity: 2,
      );
      expect(
        input.toGraphQL(),
        '{ fillingPropertyId: "1", tobaccos: [{ tobaccoId: "10", flavor: "Мята", grammage: 20.0 }], '
        'additionalPropertyIds: ["7"], strength: 5, quantity: 2 }',
      );
    });
  });
}
