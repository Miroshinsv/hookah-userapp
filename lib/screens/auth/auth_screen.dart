import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/graphql/mutations.dart';
import '../../core/utils/phone_hash.dart';

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

class _AuthScreenState extends State<AuthScreen> {
  final _phoneCtrl        = TextEditingController();
  final _passCtrl         = TextEditingController();
  final _confirmPassCtrl  = TextEditingController();
  bool _isRegisterMode = false;
  String? _error;
  bool _loading = false;

  String get _rawPhone {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    return '+$digits';
  }

  bool get _phoneComplete =>
      _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '').length == 11;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  GraphQLClient get _client => GraphQLProvider.of(context).value;

  void _toggleMode(bool registerMode) {
    setState(() {
      _isRegisterMode = registerMode;
      _error = null;
      _confirmPassCtrl.clear();
    });
  }

  Future<void> _submit() =>
      _isRegisterMode ? _register() : _login();

  Future<void> _login() async {
    if (!_phoneComplete) {
      setState(() => _error = 'Введите полный номер телефона');
      return;
    }
    setState(() { _error = null; _loading = true; });
    final phone = _rawPhone;
    final result = await _client.mutate(MutationOptions(
      document: gql(GQLMutations.loginUser(
        phoneHash: PhoneHash.sha256Hex(phone),
        password: _passCtrl.text,
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
        phone:    phone,
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
    if (!_phoneComplete) {
      setState(() => _error = 'Введите полный номер телефона');
      return;
    }
    if (_passCtrl.text != _confirmPassCtrl.text) {
      setState(() => _error = 'Пароли не совпадают');
      return;
    }
    setState(() { _error = null; _loading = true; });
    final phone = _rawPhone;
    final result = await _client.mutate(MutationOptions(
      document: gql(GQLMutations.registerUser(
        phoneHash: PhoneHash.sha256Hex(phone),
        phoneLast4: PhoneHash.last4(phone),
        phoneMock: PhoneHash.mock(phone),
        password: _passCtrl.text,
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
      await context.read<AuthState>().login(token, phone: phone);
      if (mounted && !widget.embedded) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } else {
      setState(() { _loading = false; _error = 'Ошибка регистрации'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: ClipOval(
                  child: Image.asset('assets/logo.png', width: 72, height: 72,
                      fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'HOOKAH ORDER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _phoneCtrl,
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
                controller: _passCtrl,
                obscureText: true,
                textInputAction:
                    _isRegisterMode ? TextInputAction.next : TextInputAction.done,
                onSubmitted: (_) => _isRegisterMode || _loading ? null : _submit(),
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              if (_isRegisterMode) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPassCtrl,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _loading ? null : _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Повторите пароль',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isRegisterMode ? 'Зарегистрироваться' : 'Войти'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Зарегистрироваться'),
                value: _isRegisterMode,
                onChanged: _loading ? null : _toggleMode,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
