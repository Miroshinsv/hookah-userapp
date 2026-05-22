import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/graphql/mutations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();

  bool _editing = false;
  bool _loading = false;
  String? _error;
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_editing) _syncControllers();
  }

  void _syncControllers() {
    final auth = context.read<AuthState>();
    _firstNameCtrl.text = auth.firstName ?? '';
    _lastNameCtrl.text  = auth.lastName ?? '';
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  void _startEditing() {
    _syncControllers();
    setState(() { _editing = true; _error = null; });
  }

  void _cancelEditing() {
    setState(() { _editing = false; _error = null; });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final firstName = _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim();
    final lastName  = _lastNameCtrl.text.trim().isEmpty ? null : _lastNameCtrl.text.trim();
    final staffId   = context.read<AuthState>().staffId;

    if (staffId == null) {
      setState(() { _loading = false; _error = 'Не удалось получить ID пользователя'; });
      return;
    }

    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(GQLMutations.updateUser(
        staffId:   staffId,
        firstName: firstName,
        lastName:  lastName,
      )),
    ));

    if (!mounted) return;

    if (result.hasException) {
      setState(() {
        _loading = false;
        _error = result.exception?.graphqlErrors.firstOrNull?.message ?? 'Ошибка сохранения';
      });
      return;
    }

    await context.read<AuthState>().updateProfile(
      firstName: firstName,
      lastName:  lastName,
    );
    setState(() { _loading = false; _editing = false; });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Редактировать',
              onPressed: _startEditing,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.person, size: 44),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  _displayName(auth),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Center(
                child: Text(
                  auth.isOwner ? 'Владелец' : 'Пользователь',
                  style: TextStyle(
                    color: auth.isOwner
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // Телефон — всегда только чтение
              TextFormField(
                initialValue: auth.phone ?? '—',
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Телефон',
                  prefixIcon: const Icon(Icons.phone),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                ),
              ),

              const SizedBox(height: 16),

              IgnorePointer(
                ignoring: !_editing,
                child: TextFormField(
                  controller: _firstNameCtrl,
                  readOnly: !_editing,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Имя',
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: !_editing,
                    fillColor: _editing
                        ? null
                        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              IgnorePointer(
                ignoring: !_editing,
                child: TextFormField(
                  controller: _lastNameCtrl,
                  readOnly: !_editing,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: _editing && !_loading ? (_) => _save() : null,
                  decoration: InputDecoration(
                    labelText: 'Фамилия',
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: !_editing,
                    fillColor: _editing
                        ? null
                        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],

              if (_editing) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading ? null : _cancelEditing,
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        child: _loading
                            ? const SizedBox(height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Сохранить'),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              if (auth.isOwner) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _editing
                        ? null
                        : () => Navigator.pushNamed(context, '/lounge/create'),
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Создать кальянную'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _editing ? null : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Выход'),
                        content: const Text('Вы уверены, что хотите выйти?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('Отмена'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Выйти'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await auth.logout();
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Выйти из аккаунта'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: Text(
                  _version != null ? 'v$_version' : '',
                  style: TextStyle(
                    color: Colors.grey.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _displayName(AuthState auth) {
    final parts = [auth.firstName, auth.lastName].where((v) => v != null && v.isNotEmpty).toList();
    if (parts.isEmpty) return auth.phone ?? 'Пользователь';
    return parts.join(' ');
  }
}
