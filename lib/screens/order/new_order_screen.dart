import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/graphql/mutations.dart';
import '../../core/models/lounge.dart';
import '../../core/models/order.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _flavorCtrl    = TextEditingController();
  final _commentCtrl   = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  DateTime? _arrivalAt;
  String?   _error;
  bool      _loading = false;
  bool      _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final phone = context.read<AuthState>().phone;
      if (phone != null) _phoneCtrl.text = phone;
    }
  }

  @override
  void dispose() {
    _flavorCtrl.dispose();
    _commentCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
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
    if (time == null) return;
    setState(() {
      _arrivalAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(GQLMutations.createOrder(
        loungeId:  lounge.id,
        flavor:    _flavorCtrl.text.trim(),
        comment:   _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
        phone:     _phoneCtrl.text.trim(),
        firstName: auth.firstName,
        lastName:  auth.lastName,
        arrivalAt: _arrivalAt!.toUtc().toIso8601String(),
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
      final order = Order.fromJson({
        ...orderData,
        'loungeId':  lounge.id,
        'flavor':    _flavorCtrl.text,
        'comment':   _commentCtrl.text,
        'phone':     _phoneCtrl.text,
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
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\+\-\(\) ]'))],
                decoration: const InputDecoration(
                  labelText: 'Телефон *',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Укажите телефон' : null,
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
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : () => _submit(lounge),
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
