import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockease/services/auth_service.dart';

class PolicyStatus extends Fake implements PasswordValidationStatus {
  PolicyStatus(this.valid);
  final bool valid;
  @override
  bool get isValid => valid;
}

class Provider extends Fake implements UserInfo {
  Provider(this.providerId);
  @override
  final String providerId;
}

class CredentialResult extends Fake implements UserCredential {}

class Account extends Fake implements User {
  Account(this.uid, this.events, {this.passwordProvider = true});
  @override
  final String uid;
  final List<String> events;
  final bool passwordProvider;
  bool failReauth = false;
  bool failName = false;
  String? updatedPassword;
  @override
  String? get email => 'account@example.com';
  String? _displayName = 'Tên cũ';
  @override
  String? get displayName => _displayName;
  @override
  List<UserInfo> get providerData => [
    Provider(passwordProvider ? 'password' : 'google.com'),
  ];
  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    events.add('reauth');
    expect(credential.providerId, 'password');
    if (failReauth) throw FirebaseAuthException(code: 'wrong-password');
    return CredentialResult();
  }

  @override
  Future<void> updatePassword(String password) async {
    events.add('update');
    updatedPassword = password;
  }

  @override
  Future<void> updateDisplayName(String? name) async {
    events.add('name');
    if (failName) throw FirebaseAuthException(code: 'network-request-failed');
    _displayName = name;
  }
}

class Accounts extends Fake implements FirebaseAuth {
  Accounts(this.user, this.events);
  User? user;
  final List<String> events;
  bool validPolicy = true;
  VoidCallback? afterPolicy;
  @override
  User? get currentUser => user;
  @override
  Future<PasswordValidationStatus> validatePassword(
    FirebaseAuth auth,
    String? password,
  ) async {
    events.add('policy');
    afterPolicy?.call();
    return PolicyStatus(validPolicy);
  }

  @override
  Future<void> signOut() async {
    events.add('logout');
    user = null;
  }
}

typedef VoidCallback = void Function();

void main() {
  late List<String> events;
  late Account user;
  late Accounts accounts;
  late AuthService service;
  setUp(() {
    events = [];
    user = Account('u', events);
    accounts = Accounts(user, events);
    service = AuthService(accounts);
  });
  Future<void> change() => service.changePassword(
    uid: 'u',
    currentPassword: 'old-fixture',
    newPassword: 'New-fixture123!',
  );
  test(
    'password validates policy then reauthenticates before updating',
    () async {
      await change();
      expect(events, ['policy', 'reauth', 'update']);
      expect(user.updatedPassword, 'New-fixture123!');
    },
  );
  test('wrong current password cannot reach password update', () async {
    user.failReauth = true;
    await expectLater(change(), throwsA(isA<FirebaseAuthException>()));
    expect(events, ['policy', 'reauth']);
    expect(user.updatedPassword, isNull);
    expect(
      profileAuthError(FirebaseAuthException(code: 'wrong-password')),
      'Mật khẩu hiện tại không đúng.',
    );
  });
  test(
    'policy failure, Google-only account and session changes are rejected',
    () async {
      accounts.validPolicy = false;
      await expectLater(change(), throwsA(isA<FirebaseAuthException>()));
      expect(events, ['policy']);
      events.clear();
      accounts.user = Account('u', events, passwordProvider: false);
      expect(service.canChangePassword, isFalse);
      await expectLater(change(), throwsA(isA<FirebaseAuthException>()));
      expect(events, isEmpty);
      accounts.user = user;
      accounts.validPolicy = true;
      accounts.afterPolicy = () => accounts.user = Account('other', events);
      await expectLater(change(), throwsA(isA<FirebaseAuthException>()));
      expect(events, ['policy']);
      accounts.user = null;
      await expectLater(change(), throwsA(isA<FirebaseAuthException>()));
    },
  );
  test('name sync is skipped when unchanged and guarded by UID', () async {
    await service.syncDisplayName('u', 'Tên cũ');
    expect(events, isEmpty);
    await service.syncDisplayName('u', 'Tên mới');
    expect(user.displayName, 'Tên mới');
    await expectLater(
      service.syncDisplayName('other', 'Sai tài khoản'),
      throwsA(isA<FirebaseAuthException>()),
    );
    expect(events, ['name']);
  });
  test(
    'logout ends the Firebase session without modifying stored data',
    () async {
      await service.signOut();
      expect(accounts.currentUser, isNull);
      expect(events, ['logout']);
    },
  );
}
