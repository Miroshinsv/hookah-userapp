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

class LoungeChatScreen extends StatefulWidget {
  const LoungeChatScreen({super.key});

  @override
  State<LoungeChatScreen> createState() => _LoungeChatScreenState();
}

class _LoungeChatScreenState extends State<LoungeChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl  = ScrollController();
  List<LoungeChatMessage> _messages = [];
  late Lounge _lounge;
  StreamSubscription<QueryResult<Object?>>? _subSub;
  Timer? _pollingTimer;
  bool _initialized = false;
  bool _isAtBottom  = true;
  int  _newInSession = 0;
  bool _sending = false;
  late GraphQLClient _graphqlClient;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _graphqlClient = GraphQLProvider.of(context).value;
      _lounge = ModalRoute.of(context)!.settings.arguments as Lounge;

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
    _subSub?.cancel();
    _pollingTimer?.cancel();
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _subscribeMessages() {
    final stream = _graphqlClient.subscribe(SubscriptionOptions(
      document: gql(GQLSubscriptions.newLoungeChatMessage(_lounge.id)),
    ));
    _subSub = stream.listen((result) {
      if (!mounted || result.data == null) return;
      final raw = result.data!['newLoungeChatMessage'] as Map<String, dynamic>?;
      if (raw == null) return;
      final msg = LoungeChatMessage.fromJson(raw);
      final isNew = !_messages.any((m) => m.messageId == msg.messageId);
      if (!isNew) return;
      final isStaff = msg.senderRole != 'user';
      setState(() {
        _messages = [..._messages, msg];
        if (isStaff && !_isAtBottom) _newInSession++;
      });
      if (!isStaff || _isAtBottom) _scrollToBottom();
    });
  }

  Future<void> _fetchMessages({bool scroll = false}) async {
    if (!mounted) return;
    final result = await _graphqlClient.query(QueryOptions(
      document: gql(GQLQueries.loungeChatMessages(_lounge.id)),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted || result.data == null) return;
    final raw = result.data!['loungeChatMessages'] as List<dynamic>? ?? [];
    final fetched = raw
        .map((e) => LoungeChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    final hasNew = fetched.length > _messages.length;
    setState(() => _messages = fetched);
    if (scroll || (hasNew && _isAtBottom)) _scrollToBottom();
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

  String _formatTime(String iso) {
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
      appBar: AppBar(title: Text('Чат: ${_lounge.name}')),
      body: Column(
        children: [
          Expanded(child: _buildChatWithBadge()),
          _buildInput(),
        ],
      ),
    );
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
    final auth = context.read<AuthState>();
    final phone = auth.phone ?? '';

    if (_messages.isEmpty) {
      return const Center(
        child: Text('Нет сообщений', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg  = _messages[i];
        final isMe = msg.senderRole == 'user' ||
            (phone.isNotEmpty && msg.senderId == phone);

        const myBg    = Color(0xFF3D2800);
        const staffBg = Color(0xFF2E1F10);
        const myText  = Color(0xFFF5E6D0);

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints:
                BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.72),
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
                    style: const TextStyle(color: myText, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  _formatTime(msg.createdAt),
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput() {
    final isLoggedIn = context.watch<AuthState>().isLoggedIn;

    if (!isLoggedIn) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                'Войдите, чтобы писать в чат',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

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
    final result = await _graphqlClient.mutate(MutationOptions(
      document: gql(GQLMutations.sendLoungeChatMessage(_lounge.id, text.trim())),
    ));
    if (!mounted) return;
    setState(() => _sending = false);
    if (!result.hasException) _fetchMessages(scroll: true);
  }
}
