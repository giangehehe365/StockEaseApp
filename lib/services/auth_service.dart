import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;
  late final Future<void> _googleReady = GoogleSignIn.instance.initialize();

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  String? get displayName => _auth.currentUser?.displayName;
  bool get canChangePassword =>
      _auth.currentUser?.providerData.any(
        (p) => p.providerId == EmailAuthProvider.PROVIDER_ID,
      ) ??
      false;

  User _currentUser(String expectedUid) {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'user-token-expired');
    if (user.uid != expectedUid) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    return user;
  }

  Future<void> syncDisplayName(String uid, String name) async {
    final user = _currentUser(uid);
    if (user.displayName != name) await user.updateDisplayName(name);
  }

  Future<void> changePassword({
    required String uid,
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _currentUser(uid);
    if (!canChangePassword || user.email == null) {
      throw FirebaseAuthException(code: 'operation-not-allowed');
    }
    if (currentPassword.isEmpty ||
        newPassword.length < 6 ||
        currentPassword == newPassword) {
      throw FirebaseAuthException(code: 'weak-password');
    }
    final policy = await _auth.validatePassword(_auth, newPassword);
    if (!policy.isValid) throw FirebaseAuthException(code: 'weak-password');
    _currentUser(uid);
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      ),
    );
    _currentUser(uid);
    await user.updatePassword(newPassword);
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> register(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signInWithGoogle() async {
    await _googleReady;
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(code: 'missing-google-id-token');
    }
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  Future<void> signOut() async {
    final hasGoogleProvider =
        _auth.currentUser?.providerData.any(
          (provider) => provider.providerId == GoogleAuthProvider.PROVIDER_ID,
        ) ??
        false;
    if (hasGoogleProvider) {
      try {
        await _googleReady;
        await GoogleSignIn.instance.signOut();
      } on Exception {
        // Firebase owns the app session; Google cleanup must not prevent logout.
      }
    }
    await _auth.signOut();
  }
}

String profileAuthError(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'wrong-password' ||
      'invalid-credential' ||
      'invalid-login-credentials' => 'Mật khẩu hiện tại không đúng.',
      'weak-password' || 'password-does-not-meet-requirements' => 'Mật khẩu mới chưa đáp ứng chính sách Firebase. Hãy dùng mật khẩu mạnh hơn.',
      'network-request-failed' => 'Mất kết nối mạng. Hãy thử lại.',
      'requires-recent-login' ||
      'user-token-expired' ||
      'invalid-user-token' ||
      'user-mismatch' ||
      'user-not-found' =>
        'Phiên đăng nhập không còn hợp lệ. Hãy đăng nhập lại.',
      'user-disabled' => 'Tài khoản đã bị vô hiệu hóa.',
      'too-many-requests' => 'Bạn đã thử quá nhiều lần. Hãy thử lại sau.',
      'operation-not-allowed' => 'Tài khoản này không sử dụng mật khẩu email.',
      _ => 'Không thể cập nhật tài khoản. Hãy thử lại.',
    };
  }
  return 'Không thể cập nhật tài khoản. Hãy kiểm tra kết nối và thử lại.';
}
