import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppStorage {
  static const _jwtKey       = 'jwt';
  static const _staffIdKey   = 'staffId';
  static const _phoneKey     = 'phone';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> readToken() => _storage.read(key: _jwtKey);
  Future<void> writeToken(String token) => _storage.write(key: _jwtKey, value: token);
  Future<void> deleteToken() => _storage.delete(key: _jwtKey);

  Future<String?> readStaffId() => _storage.read(key: _staffIdKey);
  Future<void> writeStaffId(String v) => _storage.write(key: _staffIdKey, value: v);
  Future<void> deleteStaffId() => _storage.delete(key: _staffIdKey);

  // Токен больше не содержит номер телефона в открытом виде (sub — это
  // server-side identity hash), поэтому реальный номер сохраняется отдельно
  // на клиенте при login/register, чтобы его можно было показать в профиле
  // и пересчитать phoneLast4/phoneMock для createOrder при восстановлении сессии.
  Future<String?> readPhone() => _storage.read(key: _phoneKey);
  Future<void> writePhone(String v) => _storage.write(key: _phoneKey, value: v);
  Future<void> deletePhone() => _storage.delete(key: _phoneKey);
}
