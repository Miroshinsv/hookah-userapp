import 'dart:convert';

class JwtHelper {
  static bool isExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final exp = data['exp'];
      if (exp == null) return false;
      return DateTime.now().millisecondsSinceEpoch > (exp as int) * 1000;
    } catch (_) {
      return true;
    }
  }
}
