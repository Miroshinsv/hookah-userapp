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

// Минимальный выбор позиции меню — список с фильтром по категориям (чай,
// холодные напитки и т.д.), без корзины/поиска. Полноценный конструктор
// меню — отдельная задача.
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
  List<MenuCategory> _categories = const [];
  // null = фильтр "Все"
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final client = GraphQLProvider.of(context).value;
    // Категории и позиции грузятся параллельно одним query-барьером — весь
    // список позиций загружается сразу (без categoryId), фильтр по
    // категории дальше применяется на клиенте без повторных запросов.
    final results = await Future.wait([
      client.query(QueryOptions(
        document: gql(GQLQueries.menuItems(loungeId: widget.loungeId)),
        fetchPolicy: FetchPolicy.networkOnly,
      )),
      client.query(QueryOptions(
        document: gql(GQLQueries.menuCategories(widget.loungeId)),
        fetchPolicy: FetchPolicy.networkOnly,
      )),
    ]);

    if (!mounted) return;

    final itemsResult = results[0];
    final categoriesResult = results[1];

    if (itemsResult.hasException) {
      final message =
          itemsResult.exception?.graphqlErrors.firstOrNull?.message ?? 'Не удалось загрузить меню';
      AppLogger.w(_tag, 'load items failed loungeId=${widget.loungeId}: $message');
      setState(() {
        _loading = false;
        _error = message;
      });
      return;
    }

    final itemsData = (itemsResult.data?['menuItems'] as List<Object?>?) ?? const [];
    final items = itemsData
        .cast<Map<String, dynamic>>()
        .map(MenuItem.fromJson)
        .where((i) => !i.stopped && i.available)
        .toList();

    // Категории — вспомогательный UI-фильтр, а не обязательные данные: сбой
    // их загрузки не должен блокировать выбор позиций, просто не будет
    // строки фильтра.
    var categories = const <MenuCategory>[];
    if (categoriesResult.hasException) {
      AppLogger.w(
        _tag,
        'load categories failed loungeId=${widget.loungeId}',
        categoriesResult.exception,
      );
    } else {
      final categoriesData =
          (categoriesResult.data?['menuCategories'] as List<Object?>?) ?? const [];
      categories = categoriesData.cast<Map<String, dynamic>>().map(MenuCategory.fromJson).toList();
    }

    AppLogger.d(
      _tag,
      'loaded loungeId=${widget.loungeId} items=${items.length} categories=${categories.length}',
    );

    setState(() {
      _loading = false;
      _items = items;
      _categories = categories;
    });
  }

  // Только категории, у которых реально есть видимые позиции — иначе фильтр
  // предлагал бы выбрать пустую категорию.
  List<MenuCategory> get _categoriesWithItems {
    final presentIds = _items.map((i) => i.categoryId).whereType<String>().toSet();
    final filtered = _categories.where((c) => presentIds.contains(c.categoryId)).toList();
    filtered.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return filtered;
  }

  List<MenuItem> get _visibleItems {
    if (_selectedCategoryId == null) return _items;
    return _items.where((i) => i.categoryId == _selectedCategoryId).toList();
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
              child: const Text('  Добавить  '),
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
            if (!_loading && _error == null) _buildCategoryFilter(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = _categoriesWithItems;
    // Меньше двух категорий с позициями — фильтровать нечего.
    if (categories.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final selected = _selectedCategoryId == null;
            return ChoiceChip(
              label: const Text('Все'),
              selected: selected,
              selectedColor: _chipSelectedColor,
              labelStyle: _chipLabelStyle(selected),
              onSelected: (_) => setState(() => _selectedCategoryId = null),
            );
          }
          final category = categories[index - 1];
          final selected = _selectedCategoryId == category.categoryId;
          return ChoiceChip(
            label: Text(category.name),
            selected: selected,
            selectedColor: _chipSelectedColor,
            labelStyle: _chipLabelStyle(selected),
            onSelected: (_) => setState(() => _selectedCategoryId = category.categoryId),
          );
        },
      ),
    );
  }

  // Дефолтный ChoiceChip в выбранном состоянии даёт жёлтый фон с белым
  // текстом — нечитаемо. Фон оставляем жёлтым (kGold из main.dart), но
  // текст выбранного чипа делаем чёрным; невыбранный чип не трогаем — его
  // цвет по-прежнему берётся из ChipThemeData.labelStyle (main.dart).
  static const _chipSelectedColor = Color(0xFFC9A84C);

  TextStyle? _chipLabelStyle(bool selected) =>
      selected ? const TextStyle(color: Colors.black) : null;

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
    final visible = _visibleItems;
    if (visible.isEmpty) {
      return const Center(child: Text('В этой категории пока нет позиций'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final item = visible[index];
        return ListTile(
          title: Text(item.name),
          trailing: Text('${item.price.toStringAsFixed(0)} ₽'),
          onTap: () => _pick(item),
        );
      },
    );
  }
}
