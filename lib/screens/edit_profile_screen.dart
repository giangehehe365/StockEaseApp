import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../services/store_profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
    required this.profiles,
    required this.auth,
    this.email,
  });
  final StoreProfile profile;
  final StoreProfileService profiles;
  final AuthService auth;
  final String? email;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.name);
  late final _store = TextEditingController(text: widget.profile.storeName);
  late final _phone = TextEditingController(text: widget.profile.phoneNumber);
  late final _address = TextEditingController(
    text: widget.profile.storeAddress,
  );
  late StoreProfile _saved = widget.profile.normalized;
  bool _busy = false;
  bool _leaving = false;
  bool _syncPending = false;
  String? _error;

  StoreProfile get _draft => StoreProfile(
    uid: widget.profile.uid,
    name: _name.text,
    storeName: _store.text,
    phoneNumber: _phone.text,
    storeAddress: _address.text,
  ).normalized;
  bool get _changed => !_draft.sameInformation(_saved);
  bool get _needsNameSync => widget.auth.displayName != _draft.name;

  @override
  void dispose() {
    _name.dispose();
    _store.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _exit() async {
    if (_busy || _leaving) return;
    _leaving = true;
    final discard = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Rời chỉnh sửa hồ sơ?'),
        content: Text(
          _syncPending
              ? 'Hồ sơ đã lưu nhưng tên tài khoản chưa đồng bộ. Bạn có thể quay lại để thử đồng bộ.'
              : 'Bạn có thay đổi chưa lưu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục sửa'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rời màn hình'),
          ),
        ],
      ),
    );
    _leaving = false;
    if (mounted && discard == true) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (_busy ||
        (!_changed && !_needsNameSync) ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..removeCurrentSnackBar();
    final draft = _draft;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!draft.sameInformation(_saved)) {
        await widget.profiles.save(draft);
        if (!mounted) return;
        setState(() => _saved = draft);
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = productErrorMessage(error);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể hoàn tất cập nhật hồ sơ.')),
        );
      }
      return;
    }
    try {
      await widget.auth.syncDisplayName(draft.uid, draft.name);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _syncPending = true;
          _error =
              'Hồ sơ đã lưu vào Firestore, nhưng tên tài khoản chưa đồng bộ. ${profileAuthError(error)} Nhấn Lưu để thử đồng bộ lại.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hồ sơ đã lưu; đồng bộ tên tài khoản chưa hoàn tất.'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_changed && !_syncPending,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _exit();
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa hồ sơ')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: () => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: 'Họ và tên'),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => cleanProfileText(value ?? '').isEmpty
                        ? 'Hãy nhập họ và tên.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Email (chỉ đọc)',
                    ),
                    child: Text(widget.email ?? 'Chưa cập nhật'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phone,
                    enabled: !_busy,
                    maxLength: 30,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại (không bắt buộc)',
                      helperText: '7–15 chữ số, có thể bắt đầu bằng +.',
                    ),
                    validator: (value) =>
                        validProfilePhone(cleanPhone(value ?? ''))
                        ? null
                        : 'Số điện thoại không hợp lệ.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _store,
                    enabled: !_busy,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Tên cửa hàng',
                    ),
                    validator: (value) => cleanProfileText(value ?? '').isEmpty
                        ? 'Hãy nhập tên cửa hàng.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    enabled: !_busy,
                    maxLength: 200,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ cửa hàng (không bắt buộc)',
                    ),
                  ),
                  if (_needsNameSync && !_changed && _error == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Tên hồ sơ và tên tài khoản chưa đồng bộ. Nhấn Lưu để đồng bộ.',
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy || (!_changed && !_needsNameSync)
                        ? null
                        : _save,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _syncPending
                                ? 'Lưu / thử đồng bộ lại'
                                : 'Lưu hồ sơ',
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
