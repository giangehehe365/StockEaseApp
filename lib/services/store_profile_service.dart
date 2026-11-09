import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/store_profile.dart';
import 'product_service.dart';
export '../models/store_profile.dart';

class StoreProfileService {
  StoreProfileService(FirebaseFirestore firestore, String uid)
    : _db = firestore,
      _uid = uid,
      _profile = firestore
          .collection('users')
          .doc(uid)
          .collection('stockease')
          .doc('profile');

  final DocumentReference<Map<String, dynamic>> _profile;
  final FirebaseFirestore _db;
  final String _uid;

  Stream<StoreProfile?> watch() => _profile.snapshots().map((snapshot) {
    final data = snapshot.data();
    return data == null ? null : StoreProfile.fromData(_uid, data);
  });

  Future<void> save(StoreProfile profile) async {
    final clean = profile.normalized;
    if (clean.uid != _uid || !clean.isValid) {
      throw const ProductException('Thông tin hồ sơ không hợp lệ.');
    }
    await _db.runTransaction((transaction) async {
      final existing = (await transaction.get(_profile)).data();
      transaction.set(_profile, {
        ...clean.toData(),
        'createdAt': existing == null
            ? FieldValue.serverTimestamp()
            : existing['createdAt'],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
