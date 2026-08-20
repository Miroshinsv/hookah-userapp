import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/graphql/mutations.dart';

void main() {
  group('GQLMutations.registerDevice', () {
    test('interpolates fcmToken and loungeId when both are provided', () {
      final query = GQLMutations.registerDevice(fcmToken: 'tok"en', loungeId: '42');

      expect(query, contains('registerDevice('));
      expect(query, contains(r'fcmToken: "tok\"en"'));
      expect(query, contains('loungeId: "42"'));
    });

    test('omits loungeId argument when not provided', () {
      final query = GQLMutations.registerDevice(fcmToken: 'abc');

      expect(query, contains('fcmToken: "abc"'));
      expect(query, isNot(contains('loungeId:')));
    });
  });

  group('GQLMutations.unregisterDevice', () {
    test('interpolates fcmToken and takes no loungeId argument', () {
      final query = GQLMutations.unregisterDevice('tok"en');

      expect(query, contains('unregisterDevice(fcmToken:'));
      expect(query, contains(r'"tok\"en"'));
      expect(query, isNot(contains('loungeId')));
    });
  });
}
