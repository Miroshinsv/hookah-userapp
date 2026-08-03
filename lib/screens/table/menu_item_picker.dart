import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/graphql/queries.dart';
import '../../core/models/menu_item.dart';
import '../../core/utils/logger.dart';

class MenuItemPickResult {
  final MenuItem item;
  final int quantity;

  const MenuItemPickResult({required this.item, required this.quantity});
}

// Минимальный выбор позиции меню для addSessionItem — плоский список без
// категорий-вкладок, без корзины. Полноценный конструктор меню — отдельная задача.
Future<MenuItemPickResult?> showMenuItemPicker(
  BuildContext context, {
  required String loungeId,
}) {
  return showModalBottomSheet<MenuItemPickResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MenuItemPickerSheet(loungeId: loungeId),
  );
}

class _MenuItemPickerSheet extends StatefulWidget {
  final String loungeId;

  const _MenuItemPickerSheet({required this.loungeId});

  @override
  State<_MenuItemPickerSheet> createState() => _MenuItemPickerSheetState();
}

class _MenuItemPickerSheetState extends State<_MenuItemPickerSheet> {
  static const _tag = 'MenuPicker';

  bool _loading = true;
  String? _error;
  List<MenuItem> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(GQLQueries.menuItems(loungeId: widget.loungeId)),
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    if (!mounted) return;

    if (result.hasException) {
      final message =
          result.exception?.graphqlErrors.firstOrNull?.message ?? 'Не удалось загрузить меню';
      AppLogger.w(_tag, 'load failed loungeId=${widget.loungeId}: $message');
      setState(() {
        _loading = false;
        _error = message;
      });
      return;
    }

    final data = (result.data?['menuItems'] as List<Object?>?) ?? const [];
    final items = data
        .cast<Map<String, dynamic>>()
        .map(MenuItem.fromJson)
        .where((i) => !i.stopped && i.available)
        .toList();

    AppLogger.d(_tag, 'loaded loungeId=${widget.loungeId} items=${items.length}');

    setState(() {
      _loading = false;
      _items = items;
    });
  }

  Future<void> _pick(MenuItem item) async {
    final result = await _showQuantityDialog(item);
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  Future<MenuItemPickResult?> _showQuantityDialog(MenuItem item) {
    int quantity = 1;
    return showDialog<MenuItemPickResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(item.name),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: quantity > 1
                    ? () => setDialogState(() => quantity--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$quantity', style: const TextStyle(fontSize: 18)),
              IconButton(
                onPressed: () => setDialogState(() => quantity++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                MenuItemPickResult(item: item, quantity: quantity),
              ),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Выберите позицию', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }
    if (_items.isEmpty) {
      return const Center(child: Text('Меню пока пустое'));
    }
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return ListTile(
          title: Text(item.name),
          trailing: Text('${item.price.toStringAsFixed(0)} ₽'),
          onTap: () => _pick(item),
        );
      },
    );
  }
}
