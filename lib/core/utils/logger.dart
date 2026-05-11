import 'dart:developer' as dev;

class AppLogger {
  static void d(String tag, String message) =>
      dev.log(message, name: tag, level: 500);

  static void i(String tag, String message) =>
      dev.log(message, name: tag, level: 800);

  static void w(String tag, String message, [Object? error, StackTrace? stack]) =>
      dev.log(message, name: tag, level: 900, error: error, stackTrace: stack);

  static void e(String tag, String message, [Object? error, StackTrace? stack]) =>
      dev.log(message, name: tag, level: 1000, error: error, stackTrace: stack);
}
