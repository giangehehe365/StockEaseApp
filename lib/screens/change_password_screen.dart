import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    super.key,
    required this.auth,
    required this.uid,
  });
  final AuthService auth;
  final String uid;
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  final _visible = [false, false, false];
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _clear() {
    _current.clear();
    _new.clear();
    _confirm.clear();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..removeCurrentSnackBar();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.changePassword(
        uid: widget.uid,
        currentPassword: _current.text,
        newPassword: _new.text,
      );
    } on Exception catch (error) {
      if (!mounted) return;
      _clear();
      if (mounted) {
        setState(() {
          _busy = false;
          _error = profileAuthError(error);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa đổi được mật khẩu. Hãy kiểm tra thông báo trên form.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    _clear();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu.')));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Mật khẩu mới cần ít nhất 6 ký tự và đáp ứng chính sách bảo mật Firebase đang áp dụng.',
                  ),
                  const SizedBox(height: 20),
                  for (var index = 0; index < 3; index++) ...[
                    TextFormField(
                      controller: [_current, _new, _confirm][index],
                      enabled: !_busy,
                      obscureText: !_visible[index],
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: [
                          'Mật khẩu hiện tại',
                          'Mật khẩu mới',
                          'Xác nhận mật khẩu mới',
                        ][index],
                        suffixIcon: IconButton(
                          tooltip: _visible[index]
                              ? 'Ẩn mật khẩu'
                              : 'Hiện mật khẩu',
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _visible[index] = !_visible[index],
                                ),
                          icon: Icon(
                            _visible[index]
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Hãy nhập mật khẩu.';
                        }
                        if (index == 1 && value.length < 6) {
                          return 'Mật khẩu mới cần ít nhất 6 ký tự.';
                        }
                        if (index == 1 && value == _current.text) {
                          return 'Mật khẩu mới phải khác mật khẩu hiện tại.';
                        }
                        if (index == 2 && value != _new.text) {
                          return 'Mật khẩu xác nhận không khớp.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_error != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Đổi mật khẩu'),
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
