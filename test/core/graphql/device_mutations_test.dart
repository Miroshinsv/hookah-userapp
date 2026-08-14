import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/graphql/mutations.dart';

void main() {
  group('GQLMutations.registerDevice', () {
    test('interpolates userId, role, fcmToken and loungeId when all are provided', () {
      final query = GQLMutations.registerDevice(
        userId: 'u1',
        role: 'guest',
        fcmToken: 'tok"en',
        loungeId: '42',
      );

      expect(query, contains('registerDevice('));
      expect(query, contains('userId: "u1"'));
      expect(query, contains('role: "guest"'));
      expect(query, contains(r'fcmToken: "tok\"en"'));
      expect(query, contains('loungeId: "42"'));
    });

    test('omits loungeId argument when not provided but keeps userId/role', () {
      final query = GQLMutations.registerDevice(
        userId: 'u1',
        role: 'guest',
        fcmToken: 'abc',
      );

      expect(query, contains('userId: "u1"'));
      expect(query, contains('role: "guest"'));
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
