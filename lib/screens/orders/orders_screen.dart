import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/chat/unread_state.dart';
import '../../core/graphql/queries.dart';
import '../../core/graphql/subscriptions.dart';
import '../../core/models/order.dart';
import '../../core/notifications/notification_service.dart';
import '../../widgets/status_badge.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => OrdersScreenState();
}

class OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  bool _loading = false;
  String? _error;
  bool _showCompleted = false;
  StreamSubscription<QueryResult<Object?>>? _statusSub;
  StreamSubscription<QueryResult<Object?>>? _msgSub;

  bool _listenerAdded = false;
  late AuthState _auth;

  void refresh() => _fetch();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listenerAdded) {
      _listenerAdded = true;
      _auth = context.read<AuthState>();
      _auth.addListener(_onAuthChanged);
      if (_auth.isLoggedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) { _fetch(); _subscribe(); }
        });
      }
    }
  }

  @override
  void dispose() {
    if (_listenerAdded) _auth.removeListener(_onAuthChanged);
    _statusSub?.cancel();
    _msgSub?.cancel();
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (_auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { _fetch(); _subscribe(); }
      });
    } else {
      _statusSub?.cancel();
      _statusSub = null;
      _msgSub?.cancel();
      _msgSub = null;
      setState(() { _orders = []; _error = null; _loading = false; });
    }
  }

  GraphQLClient get _client => GraphQLProvider.of(context).value;

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    final result = await _client.query(QueryOptions(
      document: gql(GQLQueries.orders),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    if (result.hasException) {
      setState(() {
        _loading = false;
        _error = result.exception?.graphqlErrors.firstOrNull?.message ??
            'Ошибка загрузки';
      });
      return;
    }
    final raw = result.data?['orders'] as List<dynamic>? ?? [];
    setState(() {
      _loading = false;
      _orders = raw
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  void _subscribe() {
    _statusSub?.cancel();
    _msgSub?.cancel();

    // Подписка на изменение статуса заказа
    _statusSub = _client.subscribe(SubscriptionOptions(
      document: gql(GQLSubscriptions.orderStatusChanged),
    )).listen((result) {
      if (!mounted || result.data == null) return;
      final changed =
          result.data!['orderStatusChanged'] as Map<String, dynamic>?;
      if (changed != null) {
        final id     = changed['id']     as String? ?? '';
        final status = changed['status'] as String? ?? '';
        if (id.isNotEmpty && status.isNotEmpty) {
          NotificationService.showStatusChanged(orderId: id, newStatus: status);
        }
      }
      _fetch();
    });

    // Глобальная подписка на новые сообщения от сотрудников
    _msgSub = _client.subscribe(SubscriptionOptions(
      document: gql(GQLSubscriptions.messageCreated),
    )).listen((result) {
      if (!mounted || result.data == null) return;
      final msg = result.data!['messageCreated'] as Map<String, dynamic>?;
      if (msg == null) return;

      final senderRole = msg['senderRole'] as String? ?? '';
      final orderId    = msg['orderId'] as String? ?? '';
      final text       = msg['text'] as String? ?? '';

      // Уведомления и бейджик только для сообщений от сотрудников
      if (senderRole == 'staff' && orderId.isNotEmpty) {
        final unread = context.read<UnreadState>();
        unread.onNewStaffMessage(orderId);
        // Показать пуш только если пользователь не в этом чате
        if (unread.currentOrderId != orderId) {
          NotificationService.showChatMessage(orderId: orderId, text: text);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Мои заказы')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 56, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'Для просмотра заказов\nнеобходимо авторизоваться',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои заказы'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  static const _doneStatuses = {'completed', 'canceled', 'canceled_by_staff'};

  List<Order> get _visible => _showCompleted
      ? _orders
      : _orders.where((o) => !_doneStatuses.contains(o.status)).toList();

  Widget _buildBody() {
    if (_loading && _orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetch, child: const Text('Повторить')),
          ],
        ),
      );
    }

    final visible = _visible;

    return Column(
      children: [
        _buildFilter(),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long, size: 56, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        _orders.isEmpty
                            ? 'Заказов пока нет'
                            : 'Нет активных заказов',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final o = visible[i];
                      return _OrderTile(
                        order: o,
                        onTap: () async {
                          await Navigator.pushNamed(ctx, '/order',
                              arguments: {'order': o});
                          _fetch();
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Завершённые заказы',
              style: TextStyle(fontSize: 13),
            ),
          ),
          Switch(
            value: _showCompleted,
            onChanged: (v) => setState(() => _showCompleted = v),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _OrderTile({required this.order, required this.onTap});

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}'
          ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<UnreadState>().unreadFor(order.id);

    return ListTile(
      leading: ClipOval(
        child: Image.asset('assets/logo.png', width: 40, height: 40,
            fit: BoxFit.cover),
      ),
      title: Text('Заказ #${order.id}',
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        [
          if (order.flavor != null) order.flavor!,
          if (order.arrivalAt != null) _formatDate(order.arrivalAt),
        ].join(' · '),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFC9A84C),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Color(0xFF1A0E05),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          StatusBadge(status: order.status),
        ],
      ),
      onTap: onTap,
    );
  }
}
