import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../utils/logger.dart';

class LoggingLink extends Link {
  static const _tag = 'GQL';

  final VoidCallback? onUnauthenticated;

  LoggingLink({this.onUnauthenticated});

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    final op = request.operation.operationName ??
        _extractOperationName(request.operation.document.toString()) ??
        'anonymous';

    final sw = Stopwatch()..start();
    AppLogger.d(_tag, '▶ $op vars=${request.variables}');

    return forward!(request).map((response) {
      sw.stop();
      final ms = sw.elapsedMilliseconds;

      if (response.errors != null && response.errors!.isNotEmpty) {
        AppLogger.w(_tag, '✗ $op ${ms}ms errors=${response.errors}');
        final isUnauth = response.errors!.any((e) {
          final code = e.extensions?['code']?.toString().toUpperCase() ?? '';
          final msg  = e.message.toUpperCase();
          return code == 'UNAUTHENTICATED' ||
              msg.contains('UNAUTHENTICATED') ||
              msg.contains('UNAUTHORIZED');
        });
        if (isUnauth) {
          AppLogger.w(_tag, 'token rejected — logging out');
          onUnauthenticated?.call();
        }
      } else {
        final dataStr = response.data != null
            ? _truncate(response.data.toString())
            : 'null';
        AppLogger.d(_tag, '◀ $op ${ms}ms data=$dataStr');
      }
      return response;
    });
  }

  static String _truncate(String s, [int max = 500]) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  static String? _extractOperationName(String doc) {
    final match = RegExp(r'(?:query|mutation|subscription)\s+(\w+)').firstMatch(doc);
    return match?.group(1);
  }
}
