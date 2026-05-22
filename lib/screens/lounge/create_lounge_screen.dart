import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/graphql/mutations.dart';

class CreateLoungeScreen extends StatefulWidget {
  const CreateLoungeScreen({super.key});

  @override
  State<CreateLoungeScreen> createState() => _CreateLoungeScreenState();
}

class _CreateLoungeScreenState extends State<CreateLoungeScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _addressCtrl   = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _scheduleCtrl  = TextEditingController();
  final _latCtrl       = TextEditingController();
  final _lngCtrl       = TextEditingController();

  bool   _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _scheduleCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  double? _parseCoord(String v) => double.tryParse(v.replaceAll(',', '.'));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final lat = _parseCoord(_latCtrl.text)!;
    final lng = _parseCoord(_lngCtrl.text)!;

    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(GQLMutations.createLounge(
        name:         _nameCtrl.text.trim(),
        description:  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        shortAddress: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        phone:        _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        schedule:     _scheduleCtrl.text.trim().isEmpty ? null : _scheduleCtrl.text.trim(),
        latitude:     lat,
        longitude:    lng,
      )),
    ));

    if (!mounted) return;
    if (result.hasException) {
      setState(() {
        _loading = false;
        _error = result.exception?.graphqlErrors.firstOrNull?.message ??
            result.exception?.linkException?.toString() ??
            'Ошибка создания кальянной';
      });
      return;
    }

    final data = result.data?['createLounge'] as Map<String, dynamic>?;
    if (data != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Кальянная «${data['name']}» создана')),
        );
        Navigator.pop(context, true);
      }
    } else {
      setState(() { _loading = false; _error = 'Неожиданный ответ сервера'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новая кальянная')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Название *',
                  prefixIcon: Icon(Icons.store_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Укажите название' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                textInputAction: TextInputAction.next,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Краткий адрес',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _scheduleCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Режим работы',
                  hintText: 'Пн-Вс 12:00–02:00',
                  prefixIcon: Icon(Icons.schedule_outlined),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Координаты',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          signed: true, decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,\-]')),
                      ],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Широта *',
                        hintText: '55.7558',
                        prefixIcon: Icon(Icons.explore_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Укажите';
                        if (_parseCoord(v) == null) return 'Неверный формат';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          signed: true, decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,\-]')),
                      ],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: _loading ? null : (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Долгота *',
                        hintText: '37.6173',
                        prefixIcon: Icon(Icons.explore_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Укажите';
                        if (_parseCoord(v) == null) return 'Неверный формат';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Создать кальянную', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
