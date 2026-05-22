import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppStorage {
  static const _jwtKey       = 'jwt';
  static const _staffIdKey   = 'staffId';
  static const _firstNameKey = 'firstName';
  static const _lastNameKey  = 'lastName';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> readToken() => _storage.read(key: _jwtKey);
  Future<void> writeToken(String token) => _storage.write(key: _jwtKey, value: token);
  Future<void> deleteToken() => _storage.delete(key: _jwtKey);

  Future<String?> readStaffId() => _storage.read(key: _staffIdKey);
  Future<void> writeStaffId(String v) => _storage.write(key: _staffIdKey, value: v);
  Future<void> deleteStaffId() => _storage.delete(key: _staffIdKey);

  Future<String?> readFirstName() => _storage.read(key: _firstNameKey);
  Future<String?> readLastName()  => _storage.read(key: _lastNameKey);

  Future<void> writeFirstName(String v) => _storage.write(key: _firstNameKey, value: v);
  Future<void> writeLastName(String v)  => _storage.write(key: _lastNameKey, value: v);

  Future<void> deleteNames() async {
    await _storage.delete(key: _firstNameKey);
    await _storage.delete(key: _lastNameKey);
    await _storage.delete(key: _staffIdKey);
  }
}
