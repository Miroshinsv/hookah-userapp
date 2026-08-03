import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/graphql/mutations.dart';
import '../../core/models/lounge.dart';
import '../../core/models/order.dart';
import '../../core/utils/phone_hash.dart';

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
  final _formKey    = GlobalKey<FormState>();
  final _flavorCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  DateTime? _arrivalAt;
  String?   _error;
  bool      _loading = false;

  @override
  void dispose() {
    _flavorCtrl.dispose();
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

  Future<void> _submit(Lounge lounge) async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_arrivalAt == null) {
      setState(() => _error = 'Выберите время прибытия');
      return;
    }
    setState(() => _loading = true);

    final auth = context.read<AuthState>();
    final phone = auth.phone ?? '';
    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(GQLMutations.createOrder(
        loungeId:   lounge.id,
        flavor:     _flavorCtrl.text.trim(),
        comment:    _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
        phoneLast4: PhoneHash.last4(phone),
        phoneMock:  PhoneHash.mock(phone),
        arrivalAt:  _arrivalAt!.toUtc().toIso8601String(),
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
      final order = Order.fromJson({
        ...orderData,
        'loungeId':  lounge.id,
        'flavor':    _flavorCtrl.text,
        'comment':   _commentCtrl.text,
        'phone':     auth.phone ?? '',
        'arrivalAt': _arrivalAt?.toUtc().toIso8601String(),
      });
      Navigator.pushReplacementNamed(context, '/order',
          arguments: {'order': order, 'lounge': lounge});
    }
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
                controller: _flavorCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Вкус *',
                  hintText: 'Например: Манго',
                  prefixIcon: Icon(Icons.local_florist),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Укажите вкус' : null,
              ),
              const SizedBox(height: 16),
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
