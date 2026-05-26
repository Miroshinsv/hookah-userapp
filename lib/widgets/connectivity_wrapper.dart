import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/connectivity/connectivity_service.dart';
import '../main.dart' show kGold;

/// Оборачивает всё приложение и показывает баннер при отсутствии сети.
///
/// • Красный баннер «Нет соединения» — пока нет интернета.
/// • Зелёный баннер «Соединение восстановлено» — 2 секунды после восстановления.
/// Баннеры появляются/исчезают плавно (SizeTransition + FadeTransition).
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({required this.child, super.key});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  // null = первый кадр, состояние ещё неизвестно
  bool? _lastConnected;
  bool _showRestored = false;
  Timer? _restoredTimer;

  @override
  void dispose() {
    _restoredTimer?.cancel();
    super.dispose();
  }

  /// Вызывается в build при каждом изменении состояния соединения.
  /// Обновляет поля без лишних setState — следующий кадр уже запланирован
  /// самим Consumer/watch.
  void _handleTransition(bool isConnected) {
    if (_lastConnected == isConnected) return; // нет изменений

    if (_lastConnected == false && isConnected) {
      // offline → online: показываем "восстановлено"
      _restoredTimer?.cancel();
      _showRestored = true;
      _restoredTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showRestored = false);
      });
    } else if (!isConnected) {
      // online → offline: сбрасываем "восстановлено"
      _restoredTimer?.cancel();
      _showRestored = false;
    }

    _lastConnected = isConnected;
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<ConnectivityService>();
    final isConnected = svc.isConnected;

    _handleTransition(isConnected);

    Widget? banner;
    if (!isConnected) {
      banner = _OfflineBanner(key: const ValueKey('offline'), onRetry: svc.retry);
    } else if (_showRestored) {
      banner = const _RestoredBanner(key: ValueKey('restored'));
    }

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1.0,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: banner ?? const SizedBox.shrink(key: ValueKey('none')),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Баннер «Нет соединения»
// ─────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _OfflineBanner({required this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      color: const Color(0xFF3A1010),
      padding: EdgeInsets.only(
        top: topPad + 6,
        bottom: 10,
        left: 16,
        right: 6,
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFE57373), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Нет соединения с интернетом',
                  style: TextStyle(
                    color: Color(0xFFE57373),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Подключение восстановится автоматически',
                  style: TextStyle(
                    color: Color(0xFFAA6060),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: kGold,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Повторить',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Баннер «Соединение восстановлено»
// ─────────────────────────────────────────────

class _RestoredBanner extends StatelessWidget {
  const _RestoredBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      color: const Color(0xFF0D3320),
      padding: EdgeInsets.only(
        top: topPad + 6,
        bottom: 10,
        left: 16,
        right: 16,
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_rounded, color: Color(0xFF66BB6A), size: 18),
          SizedBox(width: 10),
          Text(
            'Соединение восстановлено',
            style: TextStyle(
              color: Color(0xFF66BB6A),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
