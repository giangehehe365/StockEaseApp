import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../stock_shell.dart';
import 'auth_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth, this.firestore});

  final AuthService auth;
  final FirebaseFirestore? firestore;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Stream<User?> _session = widget.auth.authStateChanges();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _session,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  setState(() => _session = widget.auth.authStateChanges());
                },
                child: const Text('Không thể kiểm tra phiên. Thử lại'),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return AuthScreen(auth: widget.auth);
        return _SignedInNavigation(
          key: ValueKey(user.uid),
          user: user,
          auth: widget.auth,
          firestore: widget.firestore,
        );
      },
    );
  }
}

class _SignedInNavigation extends StatefulWidget {
  const _SignedInNavigation({
    super.key,
    required this.user,
    required this.firestore,
    required this.auth,
  });

  final User user;
  final AuthService auth;
  final FirebaseFirestore? firestore;

  @override
  State<_SignedInNavigation> createState() => _SignedInNavigationState();
}

class _SignedInNavigationState extends State<_SignedInNavigation> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler<void>(
      onPopWithResult: (_) => _navigator.currentState?.maybePop(),
      child: Navigator(
        key: _navigator,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => StockShell(
            uid: widget.user.uid,
            displayName: widget.user.displayName,
            email: widget.user.email,
            auth: widget.auth,
            firestore: widget.firestore,
          ),
        ),
      ),
    );
  }
}
