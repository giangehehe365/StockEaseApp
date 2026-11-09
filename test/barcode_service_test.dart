// SDK implementations below are test doubles only.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockease/models/product.dart';
import 'package:stockease/models/product_barcode.dart';
import 'package:stockease/services/product_service.dart';
import 'package:stockease/services/inventory_service.dart';
import 'package:stockease/models/stock_movement.dart';

import 'inventory_service_test.dart'
    show MemoryFirestore, MemoryTransaction, MemorySnapshot;
import 'dashboard_navigation_test.dart'
    show NavigationFirestore, NavigationCollection, NavigationDocument;

class BarcodeFirestore extends NavigationFirestore {
  bool failGet = false;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      BarcodeCollection(this, path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = BarcodeTransaction(documents);
    final result = await handler(transaction);
    for (final path in transaction.deleted) {
      documents.remove(path);
    }
    for (final entry in transaction.writes.entries) {
      documents[entry.key] = {
        for (final field in entry.value.entries)
          field.key: field.value is FieldValue ? Timestamp.now() : field.value,
      };
    }
    publish();
    return result;
  }
}

class BarcodeTransaction extends MemoryTransaction {
  BarcodeTransaction(super.documents);
  final deleted = <String>[];
  @override
  Transaction delete(DocumentReference reference) {
    deleted.add(reference.path);
    return this;
  }

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) {
    expect(
      deleted,
      isEmpty,
      reason: 'All barcode and SKU reads must precede writes',
    );
    return super.get(reference);
  }
}

class BarcodeCollection extends NavigationCollection {
  BarcodeCollection(BarcodeFirestore super.db, super.path, [super.filters]);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      BarcodeDocument(db as BarcodeFirestore, '${this.path}/${path ?? 'new'}');
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => BarcodeCollection(db as BarcodeFirestore, path, [
    ...filters,
    (field, isEqualTo),
  ]);
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    expect(options?.source, Source.server);
    if ((db as BarcodeFirestore).failGet) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    return current();
  }
}

class BarcodeDocument extends NavigationDocument {
  BarcodeDocument(BarcodeFirestore super.db, super.path);
  @override
  String get id => path.split('/').last;
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.multi((controller) {
    void emit() => controller.add(BarcodeSnapshot(id, db.documents[path]));
    emit();
    final sub = db.changes.stream.listen((_) => emit());
    controller.onCancel = sub.cancel;
  });
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      BarcodeCollection(db as BarcodeFirestore, '$path/$collectionPath');
}

class BarcodeSnapshot extends MemorySnapshot<Map<String, dynamic>> {
  BarcodeSnapshot(this.id, super.value);
  @override
  final String id;
}

Map<String, dynamic> data(String uid, String sku, [String? barcode]) => {
  'userId': uid,
  'name': 'Demo',
  'sku': sku,
  'category': 'Đồ uống',
  'price': 1000,
  'quantity': 10,
  'minStock': 2,
  'unit': 'box',
  'isArchived': false,
  'barcode': ?barcode,
};
Future<void> save(
  ProductService service, {
  String? id,
  String sku = 'NEW',
  String? barcode,
}) => service.save(
  id: id,
  name: 'Demo',
  sku: sku,
  category: 'Đồ uống',
  price: 1000,
  minStock: 2,
  unit: 'box',
  quantity: id == null ? 10 : null,
  barcode: barcode,
);
void main() {
  test(
    'legacy products and textual barcodes retain leading zeros and case',
    () {
      expect(Product.fromData('old', data('owner', 'OLD')).barcode, '');
      expect(
        Product.fromData('p', data('owner', 'SKU', '00123')).barcode,
        '00123',
      );
      expect(normalizeBarcode(' Ab/001 '), 'Ab/001');
      expect(barcodeReservationId('Ab/001'), hasLength(64));
      expect(
        barcodeReservationId('036000291452'),
        barcodeReservationId('0036000291452'),
      );
      expect(
        barcodeReservationId('Ab/001'),
        isNot(barcodeReservationId('ab/001')),
      );
      expect(validBarcode('01234567'), isTrue);
      expect(validBarcode('a\nb'), isFalse);
      expect(validBarcode('a' * 129), isFalse);
    },
  );
  test('create reserves barcode separately from SKU and rejects duplicate atomically', () async {
    final db = BarcodeFirestore();
    final service = ProductService(db, 'owner');
    await save(service, barcode: '0012345678905');
    final product = db.documents['users/owner/products/new']!;
    expect(product['barcode'], '0012345678905');
    expect(product['sku'], 'NEW');
    final key = barcodeReservationId('0012345678905');
    expect(
      db.documents['users/owner/productBarcodes/$key']!['productId'],
      'new',
    );
    db.documents['users/owner/productBarcodes/${barcodeReservationId('taken')}'] =
        {'productId': 'other', 'barcode': 'taken'};
    final before = Map.of(db.documents);
    await expectLater(
      save(service, id: 'new', sku: 'CHANGED', barcode: 'taken'),
      throwsA(isA<DuplicateBarcodeException>()),
    );
    expect(db.documents, before);
  });
  test('edit SKU and barcode together, clear, reuse and archive without changing stock', () async {
    final db = BarcodeFirestore();
    final service = ProductService(db, 'owner');
    await save(service, barcode: '0001');
    await save(service, id: 'new', sku: 'EDITED', barcode: 'ABC/128');
    expect(
      db.documents.containsKey(
        'users/owner/productBarcodes/${barcodeReservationId('0001')}',
      ),
      isFalse,
    );
    expect(db.documents['users/owner/products/new']!['quantity'], 10);
    await save(service, id: 'new', sku: 'EDITED');
    expect(db.documents['users/owner/products/new']!['barcode'], 'ABC/128');
    await save(service, id: 'new', sku: 'EDITED', barcode: '');
    expect(
      db.documents.containsKey(
        'users/owner/productBarcodes/${barcodeReservationId('ABC/128')}',
      ),
      isFalse,
    );
    await save(service, id: 'new', sku: 'EDITED', barcode: '0001');
    await service.archive('new');
    expect(db.documents['users/owner/products/new']!['isArchived'], isTrue);
    expect(
      db.documents.containsKey(
        'users/owner/productBarcodes/${barcodeReservationId('0001')}',
      ),
      isFalse,
    );
  });
  test(
    'lookup is exact, active-only, user-scoped and never treats SKU as barcode',
    () async {
      final db = BarcodeFirestore();
      db.documents['users/owner/products/p'] = data('owner', 'SKU', '00123');
      db.documents['users/other/products/p'] = data('other', 'SKU', '00123');
      final service = ProductService(db, 'owner');
      expect((await service.findByBarcode('00123'))!.userId, 'owner');
      expect(await service.findByBarcode('123'), isNull);
      expect(await service.findByBarcode('SKU'), isNull);
      db.documents['users/owner/products/upc'] = data(
        'owner',
        'UPC',
        '036000291452',
      );
      expect((await service.findByBarcode('0036000291452'))!.id, 'upc');
      db.documents['users/owner/products/p']!['isArchived'] = true;
      expect(await service.findByBarcode('00123'), isNull);
      expect(
        (await ProductService(db, 'other').findByBarcode('00123'))!.userId,
        'other',
      );
      await ProductService(db, 'fresh').save(
        name: 'Demo',
        sku: 'NEW',
        category: 'Đồ uống',
        price: 1000,
        minStock: 2,
        unit: 'box',
        quantity: 10,
        barcode: '00123',
      );
      expect(
        (await ProductService(db, 'fresh').findByBarcode('00123'))!.userId,
        'fresh',
      );
    },
  );
  test('barcode selected product uses existing stock transactions, idempotence and stock limits', () async {
    final db = MemoryFirestore();
    db.documents['users/owner/products/p'] = data('owner', 'SKU', '00123');
    final inventory = InventoryService(db, 'owner');
    Future<void> record(String id, StockMovementType type, int quantity) =>
        inventory.record(
          movementId: id,
          productId: 'p',
          type: type,
          quantity: quantity,
          note: 'Barcode selection',
          transactionDate: DateTime(2025),
        );
    await record('IN', StockMovementType.stockIn, 5);
    await record('IN', StockMovementType.stockIn, 5);
    expect(db.documents['users/owner/products/p']!['quantity'], 15);
    await record('OUT', StockMovementType.stockOut, 3);
    expect(db.documents['users/owner/products/p']!['quantity'], 12);
    expect(db.documents['users/owner/products/p']!['barcode'], '00123');
    await expectLater(
      record('TOO_MUCH', StockMovementType.stockOut, 13),
      throwsA(isA<ProductException>()),
    );
    expect(
      db.documents.keys.where((k) => k.contains('stockMovements')),
      hasLength(2),
    );
  });
}
