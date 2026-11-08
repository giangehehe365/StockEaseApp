import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockease/main.dart';
import 'package:stockease/screens/auth/auth_screen.dart';
import 'package:stockease/services/auth_service.dart';

class RecordingAuthService extends Fake implements AuthService {
  final session = StreamController<User?>();
  String? email;
  String? password;

  @override
  Stream<User?> authStateChanges() => session.stream;

  @override
  Future<void> signOut() async => session.add(null);

  @override
  Future<void> register(String email, String password) async {
    this.email = email;
    this.password = password;
  }
}

class SignedInUser extends Fake implements User {
  @override
  String? get displayName => null;

  @override
  String get uid => 'stockease-test-user';

  @override
  String get email => 'owner@example.com';
}

void main() {
  testWidgets('Registration requires matching passwords', (tester) async {
    final auth = RecordingAuthService();
    await tester.pumpWidget(MaterialApp(home: AuthScreen(auth: auth)));
    await tester.tap(find.text('Tạo tài khoản'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), ' owner@example.com ');
    await tester.enterText(fields.at(1), 'stockease123');
    await tester.enterText(fields.at(2), 'stockease124');
    final submit = find.widgetWithText(FilledButton, 'Đăng ký');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
    expect(auth.email, isNull);

    await tester.enterText(fields.at(2), 'stockease123');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(auth.email, 'owner@example.com');
    expect(auth.password, 'stockease123');
  });

  testWidgets('Restored session opens the app and sign-out returns to login', (
    tester,
  ) async {
    final auth = RecordingAuthService();
    addTearDown(auth.session.close);
    await tester.pumpWidget(StockEaseApp(auth: auth));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    auth.session.add(SignedInUser());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);

    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('owner@example.com'), findsNothing);
  });
}
