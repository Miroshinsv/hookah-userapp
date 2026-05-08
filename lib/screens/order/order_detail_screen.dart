import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/graphql/mutations.dart';
import '../../core/graphql/queries.dart';
import '../../core/graphql/subscriptions.dart';
import '../../core/models/lounge.dart';
import '../../core/models/message.dart';
import '../../core/models/order.dart';
import '../../widgets/status_badge.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<ChatMessage> _messages = [];
  late Order _order;
  Lounge? _lounge;
  Timer? _pollTimer;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _order = args['order'] as Order;
      _lounge = args['lounge'] as Lounge?;
      _startPolling();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _startPolling() {
    _fetchMessages();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _fetchMessages());
  }

  Future<void> _fetchMessages() async {
    if (!mounted) return;
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(GQLQueries.messages(_order.id)),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted || result.data == null) return;
    final raw = result.data!['messages'] as List<dynamic>? ?? [];
    setState(() {
      _messages = raw
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    });
    _scrollToBottom();
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
          Expanded(child: _buildChat()),
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
            ],
          ),
        );
      },
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
        // сообщение моё, если роль явно 'user' ИЛИ senderId совпадает с телефоном
        final isMe = msg.senderRole == 'user' ||
            (phone.isNotEmpty && msg.senderId == phone);

        const myBg    = Color(0xFF3D2800);   // тёмно-золотистый
        const staffBg = Color(0xFF2E1F10);   // тёмно-коричневый
        const myText  = Color(0xFFF5E6D0);   // кремовый

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

  bool _sending = false;

  Widget _buildInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
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
    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(GQLMutations.sendMessage(_order.id, text.trim())),
    ));
    if (!mounted) return;
    setState(() => _sending = false);
    if (!result.hasException) _fetchMessages();
  }
}
