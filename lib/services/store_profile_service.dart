import 'package:cloud_firestore/cloud_firestore.dart';

typedef StoreProfile = ({String name, String storeName});

class StoreProfileService {
  StoreProfileService(FirebaseFirestore firestore, String uid)
    : _profile = firestore
          .collection('users')
          .doc(uid)
          .collection('stockease')
          .doc('profile');

  final DocumentReference<Map<String, dynamic>> _profile;

  Stream<StoreProfile?> watch() => _profile.snapshots().map((snapshot) {
    final data = snapshot.data();
    return data == null
        ? null
        : (
            name: data['name'] as String,
            storeName: data['storeName'] as String,
          );
  });

  Future<void> save(StoreProfile profile) =>
      _profile.set({'name': profile.name, 'storeName': profile.storeName});
}
