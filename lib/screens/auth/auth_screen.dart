import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/graphql/mutations.dart';

class _RuPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('7') || digits.startsWith('8')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) digits = digits.substring(0, 10);

    final buf = StringBuffer('+7');
    if (digits.isEmpty) {
      return TextEditingValue(
        text: buf.toString(),
        selection: TextSelection.collapsed(offset: buf.length),
      );
    }
    buf.write(' (${digits.substring(0, digits.length.clamp(0, 3))}');
    if (digits.length < 3) {
      return TextEditingValue(text: buf.toString(), selection: TextSelection.collapsed(offset: buf.length));
    }
    buf.write(') ${digits.substring(3, digits.length.clamp(3, 6))}');
    if (digits.length < 6) {
      return TextEditingValue(text: buf.toString(), selection: TextSelection.collapsed(offset: buf.length));
    }
    buf.write('-${digits.substring(6, digits.length.clamp(6, 8))}');
    if (digits.length < 8) {
      return TextEditingValue(text: buf.toString(), selection: TextSelection.collapsed(offset: buf.length));
    }
    buf.write('-${digits.substring(8, digits.length.clamp(8, 10))}');
    return TextEditingValue(
      text: buf.toString(),
      selection: TextSelection.collapsed(offset: buf.length),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final bool embedded;
  const AuthScreen({super.key, this.embedded = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginPhoneCtrl    = TextEditingController();
  final _loginPassCtrl     = TextEditingController();
  final _regPhoneCtrl      = TextEditingController();
  final _regPassCtrl       = TextEditingController();
  final _regFirstNameCtrl  = TextEditingController();
  final _regLastNameCtrl   = TextEditingController();
  String? _error;
  bool _loading = false;

  String _rawPhoneFrom(TextEditingController ctrl) {
    final digits = ctrl.text.replaceAll(RegExp(r'[^\d]'), '');
    return '+$digits';
  }

  bool _phoneComplete(TextEditingController ctrl) =>
      ctrl.text.replaceAll(RegExp(r'[^\d]'), '').length == 11;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginPhoneCtrl.dispose();
    _loginPassCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regPassCtrl.dispose();
    _regFirstNameCtrl.dispose();
    _regLastNameCtrl.dispose();
    super.dispose();
  }

  GraphQLClient get _client => GraphQLProvider.of(context).value;

  Future<void> _login() async {
    if (!_phoneComplete(_loginPhoneCtrl)) {
      setState(() => _error = 'Введите полный номер телефона');
      return;
    }
    setState(() { _error = null; _loading = true; });
    final result = await _client.mutate(MutationOptions(
      document: gql(GQLMutations.loginUser(
        _rawPhoneFrom(_loginPhoneCtrl),
        _loginPassCtrl.text,
      )),
    ));
    if (!mounted) return;
    if (result.hasException) {
      setState(() {
        _loading = false;
        _error = result.exception?.graphqlErrors.firstOrNull?.message ??
            result.exception?.linkException?.toString() ??
            'Произошла ошибка';
      });
      return;
    }
    final payload = result.data?['loginUser'] as Map<String, dynamic>?;
    final token = payload?['token'] as String?;
    if (token != null) {
      await context.read<AuthState>().login(
        token,
        role:     payload?['role'] as String?,
        loungeId: payload?['loungeId'] as String?,
      );
      if (mounted && !widget.embedded) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } else {
      setState(() { _loading = false; _error = 'Неверный номер телефона или пароль'; });
    }
  }

  Future<void> _register() async {
    if (!_phoneComplete(_regPhoneCtrl)) {
      setState(() => _error = 'Введите полный номер телефона');
      return;
    }
    setState(() { _error = null; _loading = true; });
    final result = await _client.mutate(MutationOptions(
      document: gql(GQLMutations.registerUser(
        _rawPhoneFrom(_regPhoneCtrl),
        _regPassCtrl.text,
        firstName: _regFirstNameCtrl.text.trim().isEmpty ? null : _regFirstNameCtrl.text.trim(),
        lastName: _regLastNameCtrl.text.trim().isEmpty ? null : _regLastNameCtrl.text.trim(),
      )),
    ));
    if (!mounted) return;
    if (result.hasException) {
      setState(() {
        _loading = false;
        _error = result.exception?.graphqlErrors.firstOrNull?.message ??
            result.exception?.linkException?.toString() ??
            'Произошла ошибка';
      });
      return;
    }
    final regPayload = result.data?['registerUser'] as Map<String, dynamic>?;
    final token = regPayload?['token'] as String?;
    if (token != null) {
      await context.read<AuthState>().login(
        token,
        firstName: _regFirstNameCtrl.text.trim().isEmpty ? null : _regFirstNameCtrl.text.trim(),
        lastName:  _regLastNameCtrl.text.trim().isEmpty ? null : _regLastNameCtrl.text.trim(),
      );
      if (mounted && !widget.embedded) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } else {
      setState(() { _loading = false; _error = 'Ошибка регистрации'; });
    }
  }

  Widget _buildLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: _loginPhoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [_RuPhoneFormatter()],
            decoration: const InputDecoration(
              labelText: 'Телефон',
              hintText: '+7 (999) 123-45-67',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _loginPassCtrl,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _loading ? null : _login(),
            decoration: const InputDecoration(
              labelText: 'Пароль',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          if (_error != null && _tabController.index == 0) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _login,
            child: _loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Войти'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: _regPhoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [_RuPhoneFormatter()],
            decoration: const InputDecoration(
              labelText: 'Телефон',
              hintText: '+7 (999) 123-45-67',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _regPassCtrl,
            obscureText: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Пароль',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _regFirstNameCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Имя',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _regLastNameCtrl,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _loading ? null : _register(),
            decoration: const InputDecoration(
              labelText: 'Фамилия',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          if (_error != null && _tabController.index == 1) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _register,
            child: _loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Зарегистрироваться'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            ClipOval(
              child: Image.asset('assets/logo.png', width: 72, height: 72,
                  fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
            const Text(
              'HOOKAH ORDER',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 32),
            TabBar(
              controller: _tabController,
              tabs: const [Tab(text: 'Вход'), Tab(text: 'Регистрация')],
              onTap: (_) => setState(() => _error = null),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildLoginTab(), _buildRegisterTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
