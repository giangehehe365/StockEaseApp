import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _switchMode() {
    _formKey.currentState!.reset();
    _password.clear();
    _confirmation.clear();
    setState(() {
      _registering = !_registering;
      _showPassword = false;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    try {
      final email = _email.text.trim();
      final password = _password.text;
      if (_registering) {
        await widget.auth.register(email, password);
      } else {
        await widget.auth.signIn(email, password);
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error.code) {
          'invalid-email' => 'Địa chỉ email không hợp lệ.',
          'invalid-credential' ||
          'user-not-found' ||
          'wrong-password' => 'Email hoặc mật khẩu không đúng.',
          'email-already-in-use' => 'Email này đã được đăng ký.',
          'weak-password' => 'Mật khẩu chưa đáp ứng yêu cầu bảo mật.',
          'user-disabled' => 'Tài khoản đã bị vô hiệu hóa.',
          'network-request-failed' => 'Mất kết nối mạng. Hãy thử lại.',
          'too-many-requests' => 'Bạn đã thử quá nhiều lần. Hãy thử lại sau.',
          'operation-not-allowed' => 'Đăng nhập bằng email chưa được bật.',
          _ => 'Không thể xác thực. Hãy thử lại.',
        };
      });
    } on Exception {
      if (mounted) {
        setState(() => _error = 'Không thể xác thực. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.signInWithGoogle();
    } on GoogleSignInException catch (error) {
      if (!mounted || error.code == GoogleSignInExceptionCode.canceled) return;
      setState(() {
        _error =
            error.code == GoogleSignInExceptionCode.clientConfigurationError
            ? 'Cấu hình đăng nhập Google chưa hợp lệ.'
            : 'Không thể đăng nhập bằng Google. Hãy thử lại.';
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error.code) {
          'account-exists-with-different-credential' => 'Email này đã có tài khoản. Hãy đăng nhập bằng phương thức đã dùng.',
          'network-request-failed' => 'Mất kết nối mạng. Hãy thử lại.',
          'operation-not-allowed' => 'Đăng nhập bằng Google chưa được bật.',
          _ => 'Không thể đăng nhập bằng Google. Hãy thử lại.',
        };
      });
    } on Exception {
      if (mounted) {
        setState(
          () => _error = 'Không thể đăng nhập bằng Google. Hãy thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = _registering ? 'Đăng ký' : 'Đăng nhập';
    return Scaffold(
      appBar: AppBar(title: const Text('StockEase')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                        child: const Icon(Icons.inventory_2_outlined, size: 32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Quản lý sản phẩm và theo dõi tồn kho của bạn.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      action,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Hãy nhập email.';
                        if (!RegExp(r'^[^\s@]+@[^\s@]+$').hasMatch(email)) {
                          return 'Địa chỉ email không hợp lệ.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: !_showPassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: _registering
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onFieldSubmitted: _registering ? null : (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? 'Ẩn mật khẩu'
                              : 'Hiện mật khẩu',
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _showPassword = !_showPassword,
                                ),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Hãy nhập mật khẩu.';
                        }
                        if (_registering && value.length < 6) {
                          return 'Mật khẩu cần ít nhất 6 ký tự.';
                        }
                        return null;
                      },
                    ),
                    if (_registering) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmation,
                        enabled: !_busy,
                        obscureText: !_showPassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Xác nhận mật khẩu',
                        ),
                        validator: (value) => value != _password.text
                            ? 'Mật khẩu xác nhận không khớp.'
                            : null,
                      ),
                    ],
                    if (_error case final error?) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? 'Đang xử lý…' : action),
                    ),
                    if (!_registering)
                      OutlinedButton(
                        onPressed: _busy ? null : _signInWithGoogle,
                        child: const Text('Tiếp tục với Google'),
                      ),
                    TextButton(
                      onPressed: _busy ? null : _switchMode,
                      child: Text(
                        _registering ? 'Quay lại đăng nhập' : 'Tạo tài khoản',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
