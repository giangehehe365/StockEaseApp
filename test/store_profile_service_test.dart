import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockease/services/store_profile_service.dart';
import 'package:stockease/services/product_service.dart';

import 'inventory_service_test.dart' show MemoryFirestore;

void main() {
  test('legacy profile missing a creation date stays unknown instead of inventing one', () async {
    final db = MemoryFirestore();
    db.documents['users/u/stockease/profile'] = {
      'name': 'Tên cũ',
      'storeName': 'Kho cũ',
    };
    await StoreProfileService(
      db,
      'u',
    ).save(const StoreProfile(uid: 'u', name: 'Tên mới', storeName: 'Kho cũ'));
    expect(db.documents['users/u/stockease/profile']!['createdAt'], isNull);
    expect(
      db.documents['users/u/stockease/profile']!['updatedAt'],
      isA<FieldValue>(),
    );
  });
  test(
    'legacy fields, missing optional data and normalization remain compatible',
    () {
      final old = StoreProfile.fromData('u', {
        'name': 'Tên cũ',
        'storeName': 'Kho cũ',
      });
      expect(old.phoneNumber, '');
      expect(old.storeAddress, '');
      expect(old.createdAt, isNull);
      final clean = const StoreProfile(
        uid: 'u',
        name: '  Nguyễn   An ',
        storeName: ' Kho  A ',
        phoneNumber: '+84 (90) 123-4567',
        storeAddress: ' 123   Đường A ',
      ).normalized;
      expect(clean.name, 'Nguyễn An');
      expect(clean.phoneNumber, '+84901234567');
      expect(clean.storeAddress, '123 Đường A');
      expect(clean.isValid, isTrue);
      for (final phone in ['abc', '123', '+12+1234567', '090123456789123456']) {
        expect(validProfilePhone(phone), isFalse);
      }
      expect(validProfilePhone(''), isTrue);
    },
  );
  test('profile transaction writes only current owner profile and keeps created timestamp', () async {
    final db = MemoryFirestore();
    final created = Timestamp.fromDate(DateTime(2025));
    db.documents['users/u/stockease/profile'] = {
      'name': 'Tên cũ',
      'storeName': 'Kho cũ',
      'createdAt': created,
    };
    db.documents['users/u/products/p'] = {'quantity': 5};
    db.documents['users/u/stockMovements/m'] = {'quantity': 2};
    final service = StoreProfileService(db, 'u');
    await service.save(
      const StoreProfile(
        uid: 'u',
        name: '  Tên  mới ',
        storeName: 'Kho mới',
        phoneNumber: '090-123-4567',
        storeAddress: 'Địa chỉ',
      ),
    );
    final saved = db.documents['users/u/stockease/profile']!;
    expect(saved['name'], 'Tên mới');
    expect(saved['phoneNumber'], '0901234567');
    expect(saved['createdAt'], created);
    expect(saved['updatedAt'], isA<FieldValue>());
    expect(
      saved.keys,
      unorderedEquals([
        'name',
        'storeName',
        'phoneNumber',
        'storeAddress',
        'createdAt',
        'updatedAt',
      ]),
    );
    expect(db.documents['users/u/products/p']!['quantity'], 5);
    expect(db.documents['users/u/stockMovements/m']!['quantity'], 2);
    final restored = StoreProfile.fromData('u', {...saved, 'updatedAt': null});
    expect(restored.name, 'Tên mới');
    expect(restored.createdAt, DateTime(2025));
    final before = db.transactions;
    await expectLater(
      service.save(
        const StoreProfile(uid: 'other', name: 'Sai', storeName: 'Kho'),
      ),
      throwsA(isA<ProductException>()),
    );
    await expectLater(
      service.save(const StoreProfile(uid: 'u', name: '', storeName: 'Kho')),
      throwsA(isA<ProductException>()),
    );
    expect(db.transactions, before);
  });
}
