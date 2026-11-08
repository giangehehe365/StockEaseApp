import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/auth/auth_gate.dart';
import 'services/auth_service.dart';
import 'theme/stock_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AuthService? auth;
  try {
    await Firebase.initializeApp();
    auth = AuthService(FirebaseAuth.instance);
  } on Exception {
    // The setup screen below gives users a next step without exposing SDK errors.
  }

  runApp(
    StockEaseApp(
      auth: auth,
      firestore: auth == null ? null : FirebaseFirestore.instance,
    ),
  );
}

class StockEaseApp extends StatelessWidget {
  const StockEaseApp({super.key, required this.auth, this.firestore});

  final AuthService? auth;
  final FirebaseFirestore? firestore;

  @override
  Widget build(BuildContext context) {
    final auth = this.auth;
    return MaterialApp(
      title: 'StockEase',
      theme: stockTheme(Brightness.light),
      darkTheme: stockTheme(Brightness.dark),
      home: auth == null
          ? Scaffold(
              appBar: AppBar(title: const Text('StockEase')),
              body: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Không thể khởi tạo Firebase. Hãy kiểm tra cấu hình '
                    'Firebase cho Android rồi mở lại ứng dụng.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          : AuthGate(auth: auth, firestore: firestore),
    );
  }
}
