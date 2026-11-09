import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../services/sample_product_service.dart';
import '../services/store_profile_service.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.email,
    required this.profile,
    required this.auth,
    required this.profiles,
    required this.products,
    required this.profileUnavailable,
    this.profileLoading = false,
    this.onRetry,
  });
  final String? email;
  final StoreProfile profile;
  final AuthService auth;
  final StoreProfileService? profiles;
  final ProductService? products;
  final bool profileUnavailable;
  final bool profileLoading;
  final VoidCallback? onRetry;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;
  bool _confirmingLogout = false;
  String _value(String? value) =>
      value == null || value.trim().isEmpty ? 'Chưa cập nhật' : value;

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

  void _edit() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => EditProfileScreen(
        profile: widget.profile,
        profiles: widget.profiles!,
        auth: widget.auth,
        email: widget.email,
      ),
    ),
  );

  Future<void> _logout() async {
    if (_busy || _confirmingLogout) return;
    _confirmingLogout = true;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text(
          'Bạn sẽ quay về màn hình đăng nhập. Dữ liệu kho vẫn được giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận đăng xuất'),
          ),
        ],
      ),
    );
    _confirmingLogout = false;
    if (!mounted || confirmed != true) return;
    await _run(() async {
      await widget.auth.signOut();
      return null;
    }, 'Không thể đăng xuất. Hãy thử lại.');
  }

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
      return result.failed == 0
          ? counts
          : '$counts • Lỗi ${result.failed}. Kiểm tra kết nối và Firestore Rules rồi thử lại.';
    }, 'Không thể nạp dữ liệu mẫu.');
  }

  Widget _title(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
  Widget _field(IconData icon, String title, String? value) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(_value(value)),
  );

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final colors = Theme.of(context).colorScheme;
    final canEdit =
        !_busy &&
        !widget.profileLoading &&
        !widget.profileUnavailable &&
        widget.profiles != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (widget.profileLoading) const LinearProgressIndicator(),
        Card(
          color: colors.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  child: Text(
                    profile.name.trim().isEmpty
                        ? '?'
                        : profile.name.trim().characters.first.toUpperCase(),
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(color: colors.onPrimary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _value(profile.name),
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: colors.onPrimaryContainer),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _value(widget.email),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
                const SizedBox(height: 8),
                Text(
                  _value(profile.storeName),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: canEdit ? _edit : null,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Chỉnh sửa hồ sơ'),
                ),
              ],
            ),
          ),
        ),
        if (widget.profileUnavailable)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Chưa đọc được hồ sơ. Kiểm tra kết nối và Firestore Rules.',
                  ),
                  if (widget.onRetry != null)
                    TextButton(
                      onPressed: widget.onRetry,
                      child: const Text('Thử lại'),
                    ),
                ],
              ),
            ),
          ),
        _title('Thông tin cá nhân'),
        Card(
          child: Column(
            children: [
              _field(Icons.person_outline, 'Họ và tên', profile.name),
              _field(Icons.email_outlined, 'Email (chỉ đọc)', widget.email),
              _field(
                Icons.phone_outlined,
                'Số điện thoại',
                profile.phoneNumber,
              ),
            ],
          ),
        ),
        _title('Thông tin cửa hàng'),
        Card(
          child: Column(
            children: [
              _field(
                Icons.storefront_outlined,
                'Tên cửa hàng',
                profile.storeName,
              ),
              _field(
                Icons.location_on_outlined,
                'Địa chỉ cửa hàng',
                profile.storeAddress,
              ),
              _field(
                Icons.phone_outlined,
                'Điện thoại liên hệ',
                profile.phoneNumber,
              ),
            ],
          ),
        ),
        _title('Cài đặt tài khoản'),
        Card(
          child: Column(
            children: [
              if (widget.auth.canChangePassword)
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Đổi mật khẩu'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy
                      ? null
                      : () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => ChangePasswordScreen(
                              auth: widget.auth,
                              uid: profile.uid,
                            ),
                          ),
                        ),
                )
              else
                const ListTile(
                  leading: Icon(Icons.verified_user_outlined),
                  title: Text('Phương thức đăng nhập'),
                  subtitle: Text(
                    'Mật khẩu được quản lý bởi nhà cung cấp đăng nhập.',
                  ),
                ),
            ],
          ),
        ),
        if (kDebugMode && widget.products != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : _seed,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Nạp dữ liệu mẫu'),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _busy ? null : _logout,
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
