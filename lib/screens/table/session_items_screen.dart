import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/graphql/mutations.dart';
import '../../core/graphql/queries.dart';
import '../../core/models/session_item.dart';
import '../../core/utils/logger.dart';
import 'menu_item_picker.dart';

class _SessionItemStatus {
  static String localize(String status) {
    const map = {
      'new': 'Ожидает подтверждения',
      'delivered': 'Подтверждена/подана',
      'canceled': 'Отклонена персоналом',
    };
    return map[status] ?? status;
  }

  static Color color(String status) {
    switch (status) {
      case 'new':
        return Colors.amber.shade700;
      case 'delivered':
        return Colors.green;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class SessionItemsScreen extends StatefulWidget {
  const SessionItemsScreen({super.key});

  @override
  State<SessionItemsScreen> createState() => _SessionItemsScreenState();
}

class _SessionItemsScreenState extends State<SessionItemsScreen> {
  static const _tag = 'SessionItems';

  bool _loading = true;
  bool _adding = false;
  String? _error;
  List<SessionItem> _items = const [];

  late String _sessionId;
  late String _loungeId;
  late String _tableLabel;
  bool _argsResolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies (not initState) is the correct place to read
    // ModalRoute — it runs before the first build(), which already reads
    // _tableLabel below.
    if (_argsResolved) return;
    _argsResolved = true;
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _sessionId = args['sessionId'] as String;
    _loungeId = args['loungeId'] as String;
    _tableLabel = args['tableLabel'] as String? ?? '';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final client = GraphQLProvider.of(context).value;
    AppLogger.d(_tag, 'load sessionId=$_sessionId');

    final result = await client.query(QueryOptions(
      document: gql(GQLQueries.sessionItems(sessionId: _sessionId, loungeId: _loungeId)),
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    if (!mounted) return;

    if (result.hasException) {
      final message =
          result.exception?.graphqlErrors.firstOrNull?.message ?? 'Не удалось загрузить позиции';
      AppLogger.w(_tag, 'load failed sessionId=$_sessionId: $message');
      setState(() {
        _loading = false;
        _error = message;
      });
      return;
    }

    final data = (result.data?['sessionItems'] as List<Object?>?) ?? const [];
    final items = data.cast<Map<String, dynamic>>().map(SessionItem.fromJson).toList();

    AppLogger.d(_tag, 'loaded sessionId=$_sessionId items=${items.length}');

    setState(() {
      _loading = false;
      _items = items;
    });
  }

  Future<void> _addItem() async {
    final picked = await showMenuItemPicker(context, loungeId: _loungeId);
    if (picked == null || !mounted) return;

    setState(() => _adding = true);
    final client = GraphQLProvider.of(context).value;
    AppLogger.d(
      _tag,
      'addSessionItem sessionId=$_sessionId menuItemId=${picked.item.itemId} quantity=${picked.quantity}',
    );

    final result = await client.mutate(MutationOptions(
      document: gql(GQLMutations.addSessionItem(
        sessionId: _sessionId,
        loungeId: _loungeId,
        menuItemId: picked.item.itemId,
        quantity: picked.quantity,
      )),
    ));

    if (!mounted) return;
    setState(() => _adding = false);

    if (result.hasException) {
      final message =
          result.exception?.graphqlErrors.firstOrNull?.message ?? 'Не удалось добавить позицию';
      AppLogger.w(_tag, 'addSessionItem failed sessionId=$_sessionId: $message');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final itemData = result.data?['addSessionItem'] as Map<String, dynamic>?;
    AppLogger.i(
      _tag,
      'addSessionItem ok sessionId=$_sessionId itemId=${itemData?['itemId']} status=${itemData?['status']}',
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tableLabel.isEmpty ? 'Мой заказ за столом' : _tableLabel)),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adding ? null : _addItem,
        icon: _adding
            ? const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Вы ещё не добавили ни одной позиции')),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          child: ListTile(
            title: Text('${item.name} × ${item.quantity}'),
            subtitle: Text('${item.price.toStringAsFixed(0)} ₽'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _SessionItemStatus.color(item.status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _SessionItemStatus.color(item.status).withValues(alpha: 0.4)),
              ),
              child: Text(
                _SessionItemStatus.localize(item.status),
                style: TextStyle(
                  color: _SessionItemStatus.color(item.status),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
