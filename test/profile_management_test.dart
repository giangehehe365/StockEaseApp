import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockease/screens/profile_screen.dart';
import 'package:stockease/screens/edit_profile_screen.dart';
import 'package:stockease/screens/change_password_screen.dart';
import 'package:stockease/services/auth_service.dart';
import 'package:stockease/services/store_profile_service.dart';
import 'package:stockease/services/product_service.dart';
import 'package:stockease/theme/stock_theme.dart';

class ProfileAuth extends Fake implements AuthService {
  @override
  String? displayName = 'Chủ kho';
  @override
  bool canChangePassword = true;
  int syncCalls = 0;
  int passwordCalls = 0;
  int logoutCalls = 0;
  bool failSync = false;
  bool failPassword = false;
  Completer<void>? passwordPending;
  @override
  Future<void> syncDisplayName(String uid, String name) async {
    syncCalls++;
    if (failSync) throw FirebaseAuthException(code: 'network-request-failed');
    displayName = name;
  }

  @override
  Future<void> changePassword({
    required String uid,
    required String currentPassword,
    required String newPassword,
  }) async {
    passwordCalls++;
    if (failPassword) throw FirebaseAuthException(code: 'wrong-password');
    if (passwordPending != null) await passwordPending!.future;
  }

  @override
  Future<void> signOut() async {
    logoutCalls++;
  }
}

class Profiles extends Fake implements StoreProfileService {
  int saves = 0;
  StoreProfile? saved;
  bool fail = false;
  @override
  Future<void> save(StoreProfile profile) async {
    saves++;
    if (fail) throw const ProductException('Không thể lưu hồ sơ');
    saved = profile;
  }
}

const profile = StoreProfile(uid: 'u', name: 'Chủ kho', storeName: 'Kho cũ');
void main() {
  Future<void> setup(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(400, 1200),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: stockTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => screen),
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester, [String label = 'Lưu hồ sơ']) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'edit validates fields, avoids unchanged requests and warns before leaving',
    (tester) async {
      final auth = ProfileAuth();
      final profiles = Profiles();
      await setup(
        tester,
        EditProfileScreen(
          profile: profile,
          profiles: profiles,
          auth: auth,
          email: 'owner@example.com',
        ),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Lưu hồ sơ'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Họ và tên'),
        '',
      );
      await save(tester);
      expect(find.text('Hãy nhập họ và tên.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Họ và tên'),
        'Tên mới',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên cửa hàng'),
        '',
      );
      await save(tester);
      expect(find.text('Hãy nhập tên cửa hàng.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên cửa hàng'),
        'Kho mới',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Số điện thoại (không bắt buộc)'),
        'abc',
      );
      await save(tester);
      expect(find.text('Số điện thoại không hợp lệ.'), findsOneWidget);
      expect(profiles.saves, 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Bạn có thay đổi chưa lưu.'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục sửa'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
    },
  );
  testWidgets(
    'partial DB/Auth success is explicit and retry only synchronizes Auth',
    (tester) async {
      final auth = ProfileAuth()..failSync = true;
      final profiles = Profiles();
      await setup(
        tester,
        EditProfileScreen(profile: profile, profiles: profiles, auth: auth),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Họ và tên'),
        ' Nguyễn   An ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên cửa hàng'),
        ' Kho  mới ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Số điện thoại (không bắt buộc)'),
        '+84 (90) 123-4567',
      );
      await save(tester);
      expect(profiles.saved!.name, 'Nguyễn An');
      expect(profiles.saved!.phoneNumber, '+84901234567');
      expect(find.textContaining('Hồ sơ đã lưu vào Firestore'), findsOneWidget);
      expect(find.text('Đã cập nhật hồ sơ.'), findsNothing);
      auth.failSync = false;
      await save(tester, 'Lưu / thử đồng bộ lại');
      expect(profiles.saves, 1);
      expect(auth.syncCalls, 2);
      expect(find.text('Đã cập nhật hồ sơ.'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsNothing);
    },
  );
  testWidgets('DB failure does not update Auth or report success', (
    tester,
  ) async {
    final auth = ProfileAuth();
    final profiles = Profiles()..fail = true;
    await setup(
      tester,
      EditProfileScreen(profile: profile, profiles: profiles, auth: auth),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên cửa hàng'),
      'Kho mới',
    );
    await save(tester);
    expect(find.text('Không thể lưu hồ sơ'), findsOneWidget);
    expect(auth.syncCalls, 0);
    expect(find.text('Đã cập nhật hồ sơ.'), findsNothing);
  });
  testWidgets('password validation, wrong password error and clearing fields', (
    tester,
  ) async {
    final auth = ProfileAuth()..failPassword = true;
    await setup(tester, ChangePasswordScreen(auth: auth, uid: 'u'));
    final fields = find.byType(TextFormField);
    final button = find.widgetWithText(FilledButton, 'Đổi mật khẩu');
    await tester.enterText(fields.at(0), 'old-fixture');
    await tester.enterText(fields.at(1), 'old-fixture');
    await tester.enterText(fields.at(2), 'different');
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.text('Mật khẩu mới phải khác mật khẩu hiện tại.'),
      findsOneWidget,
    );
    expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
    expect(auth.passwordCalls, 0);
    await tester.enterText(fields.at(1), 'New-fixture123!');
    await tester.enterText(fields.at(2), 'New-fixture123!');
    await tester.tap(find.byTooltip('Hiện mật khẩu').first);
    await tester.pump();
    expect(
      tester.widget<TextFormField>(fields.first).controller!.text,
      'old-fixture',
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu hiện tại không đúng.'), findsOneWidget);
    for (final field in tester.widgetList<TextFormField>(fields)) {
      expect(field.controller!.text, '');
    }
    auth.failPassword = false;
    await tester.enterText(fields.at(0), 'old-fixture');
    await tester.enterText(fields.at(1), 'New-fixture123!');
    await tester.enterText(fields.at(2), 'New-fixture123!');
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Đã đổi mật khẩu.'), findsOneWidget);
  });
  testWidgets(
    'profile missing fields, provider-specific settings and logout confirmation fit small screens',
    (tester) async {
      final auth = ProfileAuth()..canChangePassword = false;
      await setup(
        tester,
        Scaffold(
          body: ProfileScreen(
            email: 'google@example.com',
            profile: const StoreProfile(uid: 'u'),
            auth: auth,
            profiles: Profiles(),
            products: null,
            profileUnavailable: false,
          ),
        ),
        size: const Size(360, 800),
      );
      expect(find.text('Chưa cập nhật'), findsWidgets);
      final scroll = find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Đăng xuất'),
        250,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      expect(find.text('Đổi mật khẩu'), findsNothing);
      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(auth.logoutCalls, 0);
      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận đăng xuất'));
      await tester.pumpAndSettle();
      expect(auth.logoutCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
