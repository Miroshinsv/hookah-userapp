import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/chat/sender_role.dart';
import '../../core/chat/unread_state.dart';
import '../../core/graphql/mutations.dart';
import '../../core/graphql/queries.dart';
import '../../core/graphql/subscriptions.dart';
import '../../core/models/lounge.dart';
import '../../core/models/message.dart';
import '../../core/models/order.dart';
import '../../core/notifications/push_navigation.dart' show findOrderById;
import '../../core/utils/logger.dart';
import '../../widgets/feedback_sheet.dart';
import '../../widgets/status_badge.dart';
import '../table/menu_item_picker.dart';

const _terminalFeedbackStatuses = {
  'completed',
  'canceled',
  'canceled_by_user',
  'canceled_by_staff',
};

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  static const _tag = 'OrderDetail';

  final _messageCtrl = TextEditingController();
  final _scrollCtrl  = ScrollController();
  List<ChatMessage> _messages = [];
  late Order _order;
  Lounge? _lounge;
  StreamSubscription<QueryResult<Object?>>? _msgSub;
  Timer? _pollingTimer;
  bool _initialized = false;
  int _newInSession = 0;   // новые сообщения от сотрудника, пока прокручено вверх
  bool _isAtBottom  = true;
  bool _feedbackShown = false;
  bool _addingMenuItem = false;
  late GraphQLClient _graphqlClient;
  late UnreadState _unreadState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _graphqlClient = GraphQLProvider.of(context).value;
      _unreadState   = context.read<UnreadState>();

      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _order = args['order'] as Order;
      _lounge = args['lounge'] as Lounge?;

      _unreadState.currentOrderId = _order.id;
      _unreadState.markRead(_order.id);

      _scrollCtrl.addListener(_onScroll);
      _fetchMessages(scroll: true);
      _subscribeMessages();
      _pollingTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _fetchMessages(),
      );
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 60;
    if (atBottom && _newInSession > 0) setState(() => _newInSession = 0);
    if (atBottom != _isAtBottom) setState(() => _isAtBottom = atBottom);
  }

  @override
  void dispose() {
    if (_unreadState.currentOrderId == _order.id) {
      _unreadState.currentOrderId = null;
    }
    _msgSub?.cancel();
    _pollingTimer?.cancel();
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _subscribeMessages() {
    final stream = _graphqlClient.subscribe(SubscriptionOptions(
      document: gql(GQLSubscriptions.messageCreatedForOrder(_order.id)),
    ));
    _msgSub = stream.listen((result) {
      if (!mounted || result.data == null) return;
      final raw = result.data!['messageCreated'] as Map<String, dynamic>?;
      if (raw == null) return;
      final msg = ChatMessage.fromJson(raw);
      final isNew = !_messages.any((m) => m.id == msg.id);
      if (!isNew) return;
      final isStaff = SenderRole.isStaff(msg.senderRole);
      setState(() {
        _messages = [..._messages, msg];
        if (isStaff && !_isAtBottom) _newInSession++;
      });
      if (!isStaff || _isAtBottom) _scrollToBottom();
      // Действия персонала (подтверждение/отмена/удаление позиций) всегда
      // сопровождаются системным сообщением в чате — по нему перезапрашиваем
      // актуальное состояние заказа, а не полагаемся на локальный кэш
      // позиций (order.txt раздел 3).
      if (isStaff) {
        AppLogger.d(_tag,
            'staff message triggered order reload orderId=${_order.id}');
        _reloadOrderState();
      }
    });
  }

  Future<void> _fetchMessages({bool scroll = false}) async {
    if (!mounted) return;
    final result = await _graphqlClient.query(QueryOptions(
      document: gql(GQLQueries.messages(_order.id)),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted || result.data == null) return;
    final raw = result.data!['messages'] as List<dynamic>? ?? [];
    final fetched = raw
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    final oldIds = _messages.map((m) => m.id).toSet();
    final newOnes = fetched.where((m) => !oldIds.contains(m.id)).toList();
    final hasNew = newOnes.isNotEmpty;
    setState(() => _messages = fetched);
    if (scroll || (hasNew && _isAtBottom)) _scrollToBottom();
    // Подстраховка на случай, если подписка временно не доставила событие
    // (например, реконнект WS) — 4-секундный поллинг чата всё равно подхватит
    // системное сообщение персонала и перезапросит состояние заказа.
    if (newOnes.any((m) => SenderRole.isStaff(m.senderRole))) {
      AppLogger.d(_tag,
          'staff message triggered order reload orderId=${_order.id}');
      _reloadOrderState();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDateTime(String iso) {
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
    return Scaffold(
      appBar: AppBar(title: Text('Заказ #${_order.id}')),
      body: Column(
        children: [
          _buildOrderInfo(),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Чат с заведением',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          Expanded(child: _buildChatWithBadge()),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildOrderInfo() {
    return Subscription(
      options: SubscriptionOptions(
        document: gql(GQLSubscriptions.orderStatusChanged),
      ),
      builder: (result) {
        if (result.data != null) {
          final changed =
              result.data!['orderStatusChanged'] as Map<String, dynamic>?;
          if (changed != null && changed['id'] == _order.id) {
            final newStatus = changed['status'] as String?;
            if (newStatus != null && newStatus != _order.status) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _order = _order.copyWith(status: newStatus));
                  if (_terminalFeedbackStatuses.contains(newStatus) &&
                      !_feedbackShown) {
                    _feedbackShown = true;
                    _maybeShowFeedbackDialog();
                  }
                }
              });
            }
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_lounge != null)
                Text(
                  'Кальянная: ${_lounge!.name}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 15),
                ),
              const SizedBox(height: 6),
              if (_order.flavor != null)
                Text('Вкус: ${_order.flavor}',
                    style: const TextStyle(color: Colors.grey)),
              if (_order.arrivalAt != null)
                Text('Прибытие: ${_formatDateTime(_order.arrivalAt!)}',
                    style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Статус: ',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  StatusBadge(status: _order.status),
                ],
              ),
              ..._buildOrderItemsSection(),
            ],
          ),
        );
      },
    );
  }

  // Позиции заказа — только отображение, без кнопок удаления/отмены (роль
  // "user" не имеет прав на removeOrderItems/updateOrderItemsStatus, см.
  // order.txt раздел 4). Пустой список не рендерится вовсе — не показываем
  // заголовок без содержимого.
  List<Widget> _buildOrderItemsSection() {
    final hasItems = _order.menuItems.isNotEmpty || _order.hookahItems.isNotEmpty;

    return [
      // Список позиций рендерится только если он не пуст — не показываем
      // пустой заголовок. Кнопка "+ Меню" ниже НЕ зависит от hasItems: она
      // должна быть доступна и для только что созданного заказа без единой
      // позиции — это единственный способ добавить самую первую.
      if (hasItems) ...[
        const SizedBox(height: 14),
        const Text('Позиции заказа',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(height: 6),
        for (final item in _order.menuItems)
          _buildOrderItemRow(
              '${item.name} × ${item.quantity}', item.unitPrice, item.status),
        for (final item in _order.hookahItems)
          _buildOrderItemRow(
              '${item.name}${item.flavor != null ? ' (${item.flavor})' : ''} × ${item.quantity}',
              item.unitPrice,
              item.status),
        const SizedBox(height: 6),
        Text('Итого: ${_order.finalTotal?.toStringAsFixed(0) ?? '—'} ₽',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
      if (_order.isEditable) ...[
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addingMenuItem ? null : _addMenuItem,
            icon: _addingMenuItem
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add),
            label: const Text('+ Меню'),
          ),
        ),
      ],
    ];
  }

  // Отменённая персоналом позиция (status: "canceled") остаётся в списке, но
  // помечается зачёркиванием и меткой "Отменено" — гость видит, что именно
  // отменили, даже не читая системное сообщение в чате (order.txt раздел
  // 1.b). Безвозвратно удалённые позиции (только admin) сюда не попадают —
  // их просто больше нет в menuItems/hookahItems после перезагрузки заказа.
  Widget _buildOrderItemRow(String label, double unitPrice, String status) {
    final canceled = status == 'canceled';
    final style = TextStyle(
      color: Colors.grey,
      decoration: canceled ? TextDecoration.lineThrough : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: Text(label, style: style)),
                if (canceled) ...[
                  const SizedBox(width: 6),
                  const Text(
                    'Отменено',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          Text('${unitPrice.toStringAsFixed(0)} ₽', style: style),
        ],
      ),
    );
  }

  // Общий обработчик для обеих точек входа ("+ Меню" в блоке заказа и
  // "Меню" в панели чата) — дозаказ позиций через addOrderItems (order.txt
  // раздел 3). Позиции только добавляются, удаление/отмена пользователю
  // недоступны в принципе (см. order.txt раздел 4) — соответствующих
  // элементов управления в UI нет и не будет.
  Future<void> _addMenuItem() async {
    final picked = await showMenuItemPicker(context, loungeId: _order.loungeId);
    if (picked == null || !mounted) return;

    setState(() => _addingMenuItem = true);
    AppLogger.d(
      _tag,
      'addOrderItems orderId=${_order.id} menuItemId=${picked.item.itemId} quantity=${picked.quantity}',
    );

    final result = await _graphqlClient.mutate(MutationOptions(
      document: gql(GQLMutations.addOrderItems(
        orderId: _order.id,
        loungeId: _order.loungeId,
        menuItemId: picked.item.itemId,
        quantity: picked.quantity,
      )),
    ));

    if (!mounted) return;
    setState(() => _addingMenuItem = false);

    if (result.hasException) {
      _handleAddOrderItemsError(result.exception);
      return;
    }

    final data = result.data?['addOrderItems'] as Map<String, dynamic>?;
    if (data == null) return;
    setState(() {
      _order = _order.copyWith(
        status: data['status'] as String?,
        menuItems: (data['menuItems'] as List<dynamic>?)
            ?.map((e) => OrderMenuItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        hookahItems: (data['hookahItems'] as List<dynamic>?)
            ?.map((e) => OrderHookahItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: (data['subtotal'] as num?)?.toDouble(),
        finalTotal: (data['finalTotal'] as num?)?.toDouble(),
      );
    });
    AppLogger.i(
      _tag,
      'addOrderItems ok orderId=${_order.id} menuItems=${_order.menuItems.length} '
      'hookahItems=${_order.hookahItems.length} finalTotal=${_order.finalTotal}',
    );
  }

  // Реакция на ошибки addOrderItems по order.txt разделу 5. "unauthorized"
  // отдельно не обрабатываем — AuthState._handleUnauthenticated() уже
  // форсирует logout на уровне общего GraphQLClient при протухшем токене.
  void _handleAddOrderItemsError(OperationException? exception) {
    final message = exception?.graphqlErrors.firstOrNull?.message;
    AppLogger.w(_tag, 'addOrderItems failed orderId=${_order.id}: $message', exception);

    if (message != null &&
        (message.contains('invalid orderId') || message.contains('invalid loungeId'))) {
      AppLogger.e(
        _tag,
        'addOrderItems client bug orderId=${_order.id} loungeId=${_order.loungeId}: $message',
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Не удалось добавить позицию')));
      _reloadOrderState();
      return;
    }

    if (message != null && message.contains('no longer be modified')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Заказ уже закрыт, дозаказ недоступен')));
      _reloadOrderState();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? 'Не удалось добавить позицию')),
    );
    _reloadOrderState();
  }

  // Перезагружает состояние заказа с сервера после ошибки addOrderItems —
  // экран не должен оставаться в устаревшем состоянии (order.txt раздел 5).
  // Переиспользует уже протестированную чистую функцию findOrderById из
  // push_navigation.dart вместо дублирования поиска по id.
  Future<void> _reloadOrderState() async {
    final result = await _graphqlClient.query(QueryOptions(
      document: gql(GQLQueries.orders),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted || result.data == null) return;

    final raw = (result.data!['orders'] as List<dynamic>?) ?? const [];
    final orders = raw.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
    final found = findOrderById(orders, _order.id);
    if (found == null) {
      AppLogger.w(_tag, 'reloadOrderState: order not found orderId=${_order.id}');
      return;
    }
    setState(() => _order = found);
    AppLogger.d(_tag, 'reloadOrderState ok orderId=${_order.id} status=${_order.status}');
  }

  Widget _buildChatWithBadge() {
    return Stack(
      children: [
        _buildChat(),
        if (_newInSession > 0)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  setState(() => _newInSession = 0);
                  _scrollToBottom();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A84C),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black38,
                          blurRadius: 6,
                          offset: Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_downward,
                          size: 14, color: Color(0xFF1A0E05)),
                      const SizedBox(width: 5),
                      Text(
                        '$_newInSession новых',
                        style: const TextStyle(
                          color: Color(0xFF1A0E05),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChat() {
    final auth  = context.read<AuthState>();
    final phone = auth.phone ?? '';

    if (_messages.isEmpty) {
      return const Center(
        child: Text('Нет сообщений',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg  = _messages[i];
        final isMe = !SenderRole.isStaff(msg.senderRole) ||
            (phone.isNotEmpty && msg.senderId == phone);

        const myBg    = Color(0xFF3D2800);
        const staffBg = Color(0xFF2E1F10);
        const myText  = Color(0xFFF5E6D0);

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(ctx).size.width * 0.72),
            decoration: BoxDecoration(
              color: isMe ? myBg : staffBg,
              borderRadius: BorderRadius.only(
                topLeft:     const Radius.circular(14),
                topRight:    const Radius.circular(14),
                bottomLeft:  Radius.circular(isMe ? 14 : 2),
                bottomRight: Radius.circular(isMe ? 2 : 14),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Сотрудник',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFC9A84C),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                Text(msg.text,
                    style: const TextStyle(
                        color: myText,
                        fontSize: 14)),
              ],
            ),
          ),
        );
      },
    );
  }

  // Показывает запрос отзыва только если на бэкенде есть активный
  // (status == 'new') FeedbackRequest по этому заказу.
  Future<void> _maybeShowFeedbackDialog() async {
    if (!mounted || _lounge == null) return;
    final result = await _graphqlClient.query(QueryOptions(
      document: gql(GQLQueries.feedbackRequest(_order.id)),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted || result.hasException) return;
    final request = result.data?['feedbackRequest'] as Map<String, dynamic>?;
    if (request == null || request['status'] != 'new') return;

    final orderTime = _order.arrivalAt != null
        ? _formatDateTime(_order.arrivalAt!)
        : null;
    await showFeedbackSheet(
      context,
      client: _graphqlClient,
      title: request['message'] as String? ?? 'Заказ завершён',
      loungeName: _lounge!.name,
      loungeId: _lounge!.id,
      orderId: _order.id,
      orderTime: orderTime,
    );
  }

  bool _sending = false;

  Widget _buildInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            if (_order.isEditable) ...[
              IconButton(
                onPressed: _addingMenuItem ? null : _addMenuItem,
                icon: const Icon(Icons.restaurant_menu),
                tooltip: 'Меню',
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: TextField(
                controller: _messageCtrl,
                decoration: const InputDecoration(
                  hintText: 'Введите сообщение...',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onSubmitted: (text) => _send(text),
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : () => _send(_messageCtrl.text),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _messageCtrl.clear();
    setState(() => _sending = true);
    final result = await _graphqlClient.mutate(MutationOptions(
      document: gql(GQLMutations.sendMessage(_order.id, text.trim())),
    ));
    if (!mounted) return;
    setState(() => _sending = false);
    if (!result.hasException) _fetchMessages(scroll: true);
  }
}
