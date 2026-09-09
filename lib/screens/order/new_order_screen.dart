import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/graphql/mutations.dart';
import '../../core/graphql/queries.dart';
import '../../core/models/lounge.dart';
import '../../core/models/order.dart';
import '../../core/notifications/push_navigation.dart' show findOrderById;
import '../../core/utils/logger.dart';
import '../../core/utils/phone_hash.dart';
import '../table/hookah_item_picker.dart';
import '../table/menu_item_picker.dart';
import '../table/table_selection_screen.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _QuickTimeChip extends StatelessWidget {
  const _QuickTimeChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.timer_outlined, size: 16),
      onPressed: onTap,
    );
  }
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  static const _tag = 'NewOrder';

  final _formKey    = GlobalKey<FormState>();
  final _commentCtrl = TextEditingController();
  DateTime? _arrivalAt;
  String?   _error;
  bool      _loading = false;
  // Позиции меню, выбранные до создания заказа — чисто локальное состояние
  // (можно убрать позицию из этого списка без ограничений, это ещё не
  // заказ). После успешного createOrder каждая позиция докидывается через
  // addOrderItems, так как контракт addOrderItems требует существующий
  // orderId — добавить позиции в самой мутации createOrder нельзя.
  final List<MenuItemPickResult> _cartItems = [];
  // Кальян, в отличие от меню, отправляется прямо в createOrder (аргумент
  // hookahItems), поэтому отдельного докидывания через addOrderItems после
  // создания заказа не требуется (hook.txt).
  final List<HookahPickResult> _hookahCartItems = [];

  bool _tablesEnabled = false;
  bool _tablesEnabledLoaded = false;
  bool _selectingTable = false;
  String? _selectedTableId;
  String? _selectedTableLabel;
  int? _selectedGuestCount;

  double get _cartSubtotal =>
      _cartItems.fold(0.0, (sum, c) => sum + c.item.price * c.quantity);

  double get _hookahSubtotal =>
      _hookahCartItems.fold(0.0, (sum, c) => sum + c.unitPrice * c.input.quantity);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tablesEnabledLoaded) {
      _tablesEnabledLoaded = true;
      final lounge = ModalRoute.of(context)!.settings.arguments as Lounge;
      _loadTablesEnabled(lounge.id);
    }
  }

  // Не блокирует остальную загрузку экрана — кнопка "Место" просто остаётся
  // скрытой, пока флаг не резолвится (или если фича вообще не настроена для
  // этого лаунджа / запрос упал), см. sitplace.txt.
  Future<void> _loadTablesEnabled(String loungeId) async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(GQLQueries.isTablesEnabled(loungeId)),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    if (result.hasException) {
      AppLogger.w(_tag, 'isTablesEnabled failed loungeId=$loungeId', result.exception);
      return;
    }
    final enabled = result.data?['isTablesEnabled'] as bool? ?? false;
    AppLogger.d(_tag, 'isTablesEnabled loungeId=$loungeId enabled=$enabled');
    setState(() => _tablesEnabled = enabled);
  }

  // Предзаказный выбор стола — заказа ещё нет, поэтому TableSelectionScreen
  // пушится с orderId: null (см. Task 14) и просто возвращает выбор, не
  // вызывая openTableSession. Реальная попытка занять стол происходит
  // внутри createOrder при отправке формы (_submit).
  Future<void> _selectTable(Lounge lounge) async {
    setState(() => _selectingTable = true);
    AppLogger.d(_tag, 'open pre-order table selection loungeId=${lounge.id}');

    final result = await Navigator.push<TableSelectionResult>(
      context,
      MaterialPageRoute(
        builder: (_) => TableSelectionScreen(loungeId: lounge.id, orderId: null),
      ),
    );

    if (!mounted) return;
    setState(() => _selectingTable = false);
    if (result == null) return;

    setState(() {
      _selectedTableId = result.tableId;
      _selectedTableLabel = result.tableLabel;
      _selectedGuestCount = result.guestCount;
    });
    AppLogger.i(
      _tag,
      'table pre-selected tableId=${result.tableId} tableLabel=${result.tableLabel} '
      'guestCount=${result.guestCount}',
    );
  }

  void _clearSelectedTable() {
    AppLogger.d(_tag, 'clear pre-selected table tableId=$_selectedTableId');
    setState(() {
      _selectedTableId = null;
      _selectedTableLabel = null;
      _selectedGuestCount = null;
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _setArrivalIn(int minutes) {
    setState(() {
      _arrivalAt = DateTime.now().add(Duration(minutes: minutes));
      _error = null;
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (picked.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя выбрать прошедшее время')),
      );
      return;
    }
    setState(() {
      _arrivalAt = picked;
      _error = null;
    });
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}'
      '  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<void> _addMenuItem(Lounge lounge) async {
    final picked = await showMenuItemPicker(context, loungeId: lounge.id);
    if (picked == null || !mounted) return;

    AppLogger.d(_tag, 'cart add menuItemId=${picked.item.itemId} quantity=${picked.quantity}');
    setState(() {
      final idx = _cartItems.indexWhere((c) => c.item.itemId == picked.item.itemId);
      if (idx != -1) {
        final existing = _cartItems[idx];
        _cartItems[idx] =
            MenuItemPickResult(item: existing.item, quantity: existing.quantity + picked.quantity);
      } else {
        _cartItems.add(picked);
      }
    });
  }

  void _removeFromCart(int index) {
    AppLogger.d(_tag, 'cart remove menuItemId=${_cartItems[index].item.itemId}');
    setState(() => _cartItems.removeAt(index));
  }

  Future<void> _addHookah(Lounge lounge) async {
    final picked = await showHookahItemPicker(context, loungeId: lounge.id);
    if (picked == null || !mounted) return;

    AppLogger.d(_tag, 'hookah cart add ${picked.displayName} quantity=${picked.input.quantity}');
    setState(() {
      _hookahCartItems.add(picked);
      _error = null;
    });
  }

  void _removeHookahFromCart(int index) {
    AppLogger.d(_tag, 'hookah cart remove ${_hookahCartItems[index].displayName}');
    setState(() => _hookahCartItems.removeAt(index));
  }

  Future<void> _submit(Lounge lounge) async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_arrivalAt == null) {
      setState(() => _error = 'Выберите время прибытия');
      return;
    }
    if (_hookahCartItems.isEmpty) {
      setState(() => _error = 'Выберите кальян');
      return;
    }
    setState(() => _loading = true);

    final auth = context.read<AuthState>();
    final phone = auth.phone ?? '';
    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(GQLMutations.createOrder(
        loungeId:    lounge.id,
        hookahItems: _hookahCartItems.map((c) => c.input).toList(),
        comment:     _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
        phoneLast4:  PhoneHash.last4(phone),
        phoneMock:   PhoneHash.mock(phone),
        arrivalAt:   _arrivalAt!.toUtc().toIso8601String(),
        tableId:     _selectedTableId,
        guestCount:  _selectedTableId != null ? _selectedGuestCount : null,
      )),
    ));

    if (!mounted) return;
    if (result.hasException) {
      setState(() {
        _loading = false;
        _error = result.exception?.graphqlErrors.firstOrNull?.message ??
            'Ошибка создания заказа';
      });
      return;
    }

    final orderData = result.data?['createOrder'] as Map<String, dynamic>?;
    if (orderData != null) {
      final auth = context.read<AuthState>();
      var order = Order.fromJson({
        ...orderData,
        'loungeId':  lounge.id,
        'comment':   _commentCtrl.text,
        'phone':     auth.phone ?? '',
        'arrivalAt': _arrivalAt?.toUtc().toIso8601String(),
      });

      if (_cartItems.isNotEmpty) {
        order = await _addCartItemsToOrder(client, order, lounge);
        if (!mounted) return;
      }

      // Кальян отправляется прямо в createOrder, но её inline-ответ иногда
      // не отражает только что созданные hookahItems (сообщено пользователем:
      // заказ с кальяном "классический" создался, но на order_detail_screen
      // секция позиций была пустой). Подстраховываемся свежим orders() сразу
      // после создания вместо слепого доверия ответу мутации.
      final reloaded = await _reloadFreshOrder(client, order.id);
      if (!mounted) return;
      if (reloaded != null) order = reloaded;

      final tableSeatConflict = orderData['tableSeatConflict'] as bool? ?? false;
      if (tableSeatConflict) {
        AppLogger.w(
          _tag,
          'createOrder table conflict orderId=${order.id} tableId=$_selectedTableId — '
          'order created without the table, guest must retry from the order screen',
        );
      }

      Navigator.pushReplacementNamed(context, '/order', arguments: {
        'order': order,
        'lounge': lounge,
        'tableSeatConflict': tableSeatConflict,
      });
    }
  }

  // Свежий orders() сразу после createOrder — источник истины на случай,
  // если inline-ответ мутации не успел отразить только что созданные
  // hookahItems. Сбой или отсутствие заказа в списке не блокирует переход
  // на экран заказа — просто остаётся то, что вернул createOrder напрямую.
  Future<Order?> _reloadFreshOrder(GraphQLClient client, String orderId) async {
    final result = await client.query(QueryOptions(
      document: gql(GQLQueries.orders),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted || result.hasException || result.data == null) {
      AppLogger.w(_tag, 'reload after createOrder failed orderId=$orderId', result.exception);
      return null;
    }
    final raw = (result.data!['orders'] as List<dynamic>?) ?? const [];
    final orders = raw.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
    final found = findOrderById(orders, orderId);
    if (found == null) {
      AppLogger.w(_tag, 'reload after createOrder: order not found orderId=$orderId');
    } else {
      AppLogger.d(
        _tag,
        'reload after createOrder ok orderId=$orderId hookahItems=${found.hookahItems.length} '
        'menuItems=${found.menuItems.length}',
      );
    }
    return found;
  }

  // createOrder не принимает позиции меню — контракт addOrderItems требует
  // уже существующий orderId, поэтому корзина докидывается отдельными
  // вызовами сразу после успешного создания заказа. Заказ уже создан к
  // этому моменту, так что сбой добавления одной позиции не блокирует
  // переход на экран заказа — только предупреждает тостом.
  Future<Order> _addCartItemsToOrder(GraphQLClient client, Order order, Lounge lounge) async {
    var updated = order;
    final failed = <String>[];

    for (final cartItem in _cartItems) {
      AppLogger.d(
        _tag,
        'addOrderItems orderId=${updated.id} menuItemId=${cartItem.item.itemId} quantity=${cartItem.quantity}',
      );
      final addResult = await client.mutate(MutationOptions(
        document: gql(GQLMutations.addOrderItems(
          orderId: updated.id,
          loungeId: lounge.id,
          menuItemId: cartItem.item.itemId,
          quantity: cartItem.quantity,
        )),
      ));

      if (!mounted) return updated;

      if (addResult.hasException) {
        final message = addResult.exception?.graphqlErrors.firstOrNull?.message;
        AppLogger.w(
          _tag,
          'addOrderItems failed orderId=${updated.id} menuItemId=${cartItem.item.itemId}: $message',
          addResult.exception,
        );
        failed.add(cartItem.item.name);
        continue;
      }

      final data = addResult.data?['addOrderItems'] as Map<String, dynamic>?;
      if (data == null) continue;
      updated = updated.copyWith(
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
      AppLogger.i(_tag, 'addOrderItems ok orderId=${updated.id} menuItemId=${cartItem.item.itemId}');
    }

    if (failed.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заказ создан, но не удалось добавить: ${failed.join(", ")}')),
      );
    }
    return updated;
  }

  @override
  Widget build(BuildContext context) {
    final lounge = ModalRoute.of(context)!.settings.arguments as Lounge;

    return Scaffold(
      appBar: AppBar(title: const Text('Новый заказ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset('assets/logo.png', width: 20, height: 20),
                  const SizedBox(width: 6),
                  Text(lounge.name, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _commentCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Комментарий',
                  prefixIcon: Icon(Icons.comment_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Время прибытия *',
                    prefixIcon: const Icon(Icons.access_time),
                    suffixIcon: const Icon(Icons.calendar_today, size: 18),
                    errorText: _error != null && _arrivalAt == null ? 'Выберите время' : null,
                  ),
                  child: Text(
                    _arrivalAt != null ? _formatDateTime(_arrivalAt!) : 'Выберите дату и время',
                    style: TextStyle(
                      color: _arrivalAt != null ? null : Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _QuickTimeChip(label: '30 мин', onTap: () => _setArrivalIn(30)),
                  const SizedBox(width: 8),
                  _QuickTimeChip(label: '45 мин', onTap: () => _setArrivalIn(45)),
                  const SizedBox(width: 8),
                  _QuickTimeChip(label: '1 час',  onTap: () => _setArrivalIn(60)),
                ],
              ),
              const SizedBox(height: 20),
              if (_hookahCartItems.isNotEmpty) ...[
                const Text('Кальян',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                const SizedBox(height: 6),
                for (var i = 0; i < _hookahCartItems.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_hookahCartItems[i].displayName} × ${_hookahCartItems[i].input.quantity}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        Text(
                          '${(_hookahCartItems[i].unitPrice * _hookahCartItems[i].input.quantity).toStringAsFixed(0)} ₽',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        IconButton(
                          onPressed: () => _removeHookahFromCart(i),
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Убрать кальян',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text('Кальян на сумму: ${_hookahSubtotal.toStringAsFixed(0)} ₽',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : () => _addHookah(lounge),
                  icon: const Icon(Icons.local_fire_department),
                  label: const Text('кальян'),
                ),
              ),
              const SizedBox(height: 20),
              if (_cartItems.isNotEmpty) ...[
                const Text('Позиции меню',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                const SizedBox(height: 6),
                for (var i = 0; i < _cartItems.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${_cartItems[i].item.name} × ${_cartItems[i].quantity}',
                              style: const TextStyle(color: Colors.grey)),
                        ),
                        Text(
                          '${(_cartItems[i].item.price * _cartItems[i].quantity).toStringAsFixed(0)} ₽',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        IconButton(
                          onPressed: () => _removeFromCart(i),
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Убрать позицию',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text('Меню на сумму: ${_cartSubtotal.toStringAsFixed(0)} ₽',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : () => _addMenuItem(lounge),
                  icon: const Icon(Icons.add),
                  label: const Text('меню'),
                ),
              ),
              if (_tablesEnabled) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loading || _selectingTable ? null : () => _selectTable(lounge),
                    icon: const Icon(Icons.event_seat),
                    label: const Text('место'),
                  ),
                ),
                if (_selectedTableLabel != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Стол: $_selectedTableLabel · $_selectedGuestCount гостей',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                      IconButton(
                        onPressed: _loading ? null : _clearSelectedTable,
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Убрать выбор стола',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading || (lounge.ownerUserId == null || lounge.ownerUserId!.isEmpty)
                      ? null
                      : () => _submit(lounge),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Оформить заказ', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
