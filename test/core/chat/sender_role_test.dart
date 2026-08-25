import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/chat/sender_role.dart';

void main() {
  group('SenderRole.isStaff', () {
    test('returns false for the guest role "user"', () {
      expect(SenderRole.isStaff('user'), isFalse);
    });

    test('returns true for all staff-like roles from order.txt', () {
      expect(SenderRole.isStaff('staff'), isTrue);
      expect(SenderRole.isStaff('admin'), isTrue);
      expect(SenderRole.isStaff('owner'), isTrue);
      expect(SenderRole.isStaff('deputy'), isTrue);
    });

    test('treats an empty/unrecognized role as staff (anything but "user")', () {
      expect(SenderRole.isStaff(''), isTrue);
      expect(SenderRole.isStaff('unknown'), isTrue);
    });
  });
}
