import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../services/sample_product_service.dart';
import '../services/store_profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.email,
    required this.profile,
    required this.auth,
    required this.profiles,
    required this.products,
    required this.profileUnavailable,
  });

  final String? email;
  final StoreProfile profile;
  final AuthService auth;
  final StoreProfileService? profiles;
  final ProductService? products;
  final bool profileUnavailable;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action, String failure) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      if (mounted && message != null) _notify(message);
    } on Exception {
      if (mounted) _notify(failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notify(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _edit() async {
    final form = GlobalKey<FormState>();
    var (name: name, storeName: storeName) = widget.profile;
    final result = await showDialog<StoreProfile>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa hồ sơ'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              children: [
                TextFormField(
                  initialValue: name,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Tên hiển thị'),
                  validator: _required,
                  onChanged: (value) => name = value,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: storeName,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Tên cửa hàng'),
                  validator: _required,
                  onChanged: (value) => storeName = value,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, (
                  name: name.trim(),
                  storeName: storeName.trim(),
                ));
              }
            },
            child: const Text('Lưu hồ sơ'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    await _run(() async {
      await widget.profiles!.save(result);
      return 'Đã cập nhật hồ sơ.';
    }, 'Không thể lưu hồ sơ. Hãy kiểm tra kết nối và quyền Firestore.');
  }

  static String? _required(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Hãy điền thông tin.' : null;

  Future<void> _seed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Nạp dữ liệu mẫu?'),
        content: const Text(
          'Thêm tối đa 20 sản phẩm mẫu vào kho này. Các SKU đang có sẽ được bỏ qua.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Nạp dữ liệu'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _run(() async {
      final result = await seedSampleProducts(widget.products!);
      final counts = 'Đã thêm ${result.added} • Đã tồn tại ${result.existing}';
      if (result.failed == 0) return counts;
      return '$counts • Lỗi ${result.failed}. Kiểm tra kết nối và Firestore Rules rồi thử lại.';
    }, 'Không thể nạp dữ liệu mẫu.');
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  child: Text(profile.name.characters.first.toUpperCase()),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                if (widget.email case final email?)
                  Text(email, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(profile.storeName, textAlign: TextAlign.center),
                if (widget.profileUnavailable)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Chưa đọc được hồ sơ. Kiểm tra kết nối và Firestore Rules.',
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: _busy || widget.profiles == null ? null : _edit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Chỉnh sửa hồ sơ'),
        ),
        if (kDebugMode && widget.products != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _seed,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Nạp dữ liệu mẫu'),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() async {
                  await widget.auth.signOut();
                  return null;
                }, 'Không thể đăng xuất. Hãy thử lại.'),
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}
