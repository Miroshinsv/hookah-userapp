import 'dart:convert';

import 'package:crypto/crypto.dart';

// Бэкенд больше не принимает телефон в открытом виде для identity-полей
// (registerUser/loginUser) — вместо этого клиент сам хэширует номер и
// присылает phoneHash/phoneLast4/phoneMock. Сервер домешивает свой секретный
// pepper через HMAC (см. derivePhoneIdentity на бэкенде) — это не наша забота,
// только исходный SHA-256(phone) в hex.
//
// Ожидается канонический формат телефона: "+7XXXXXXXXXX" (12 символов, как
// уже строит AuthScreen._rawPhoneFrom).
class PhoneHash {
  /// SHA-256(phone) в hex — аргумент `phoneHash` для registerUser/loginUser.
  static String sha256Hex(String canonicalPhone) =>
      sha256.convert(utf8.encode(canonicalPhone)).toString();

  /// Последние 4 цифры номера (без кода страны) — аргумент `phoneLast4`.
  static String last4(String canonicalPhone) {
    final local = _localDigits(canonicalPhone);
    return local != null ? local.substring(6, 10) : '';
  }

  /// Маска вида "+7 (999) ***-45-67" — аргумент `phoneMock`, формат должен
  /// точно совпадать с бэкендовой regex `^\+7 \(\d{3}\) \*{3}-\d{2}-\d{2}$`.
  static String mock(String canonicalPhone) {
    final local = _localDigits(canonicalPhone);
    if (local == null) return '';
    return '+7 (${local.substring(0, 3)}) ***-${local.substring(6, 8)}-${local.substring(8, 10)}';
  }

  /// Извлекает 10-значный номер без кода страны "7" из "+7XXXXXXXXXX".
  /// Возвращает null, если телефон не в ожидаемом каноническом формате.
  static String? _localDigits(String canonicalPhone) {
    final digits = canonicalPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length != 11 || !digits.startsWith('7')) return null;
    return digits.substring(1);
  }
}
