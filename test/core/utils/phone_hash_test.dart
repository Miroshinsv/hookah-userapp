import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/utils/phone_hash.dart';

void main() {
  // Значение независимо проверено через `printf '%s' '+79991234567' |
  // sha256sum` и `openssl dgst -sha256` — оба дают один и тот же hex.
  // Алгоритм на бэкенде: hex(sha256(phone)) до HMAC-пересаливания сервером
  // (см. derivePhoneIdentity в staff/cmd/rehash-phone-identities/main.go).
  const canonicalPhone = '+79991234567';
  const expectedSha256Hex =
      'aaa3a8d51bbd45911d65744e547c0b7094464669438951c04b8a86c56e1ce8db';

  group('PhoneHash.sha256Hex', () {
    test('matches an independently computed SHA-256 hex digest', () {
      expect(PhoneHash.sha256Hex(canonicalPhone), expectedSha256Hex);
    });

    test('produces exactly 64 lowercase hex characters', () {
      final hash = PhoneHash.sha256Hex(canonicalPhone);
      expect(hash.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
    });
  });

  group('PhoneHash.last4', () {
    test('returns the last 4 digits of the local number', () {
      expect(PhoneHash.last4(canonicalPhone), '4567');
    });

    test('returns empty string for a non-canonical phone', () {
      expect(PhoneHash.last4('not-a-phone'), '');
    });
  });

  group('PhoneHash.mock', () {
    test('matches the backend mask format exactly', () {
      // Формат должен точно совпадать с backend regex
      // ^\+7 \(\d{3}\) \*{3}-\d{2}-\d{2}$
      expect(PhoneHash.mock(canonicalPhone), '+7 (999) ***-45-67');
      expect(
        RegExp(r'^\+7 \(\d{3}\) \*{3}-\d{2}-\d{2}$')
            .hasMatch(PhoneHash.mock(canonicalPhone)),
        isTrue,
      );
    });

    test('returns empty string for a non-canonical phone', () {
      expect(PhoneHash.mock('+123'), '');
    });
  });
}
