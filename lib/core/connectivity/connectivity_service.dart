import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// Отслеживает наличие сети и уведомляет слушателей об изменениях.
class ConnectivityService extends ChangeNotifier {
  static const _tag = 'Connectivity';

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _isConnected = true;

  /// true — есть хотя бы одно активное сетевое подключение.
  bool get isConnected => _isConnected;

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _update(result);
    } catch (e, st) {
      AppLogger.w(_tag, 'checkConnectivity failed', e, st);
    }

    _sub = _connectivity.onConnectivityChanged.listen(
      _update,
      onError: (e) => AppLogger.w(_tag, 'stream error', e),
    );
  }

  void _update(List<ConnectivityResult> results) {
    final online =
        results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
    if (_isConnected == online) return;
    _isConnected = online;
    AppLogger.i(_tag, online ? '🟢 online' : '🔴 offline');
    notifyListeners();
  }

  /// Принудительная повторная проверка (вызывается кнопкой «Повторить»).
  Future<void> retry() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _update(result);
    } catch (e) {
      _update([ConnectivityResult.none]);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
