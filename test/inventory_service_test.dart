// SDK interfaces are implemented only by test doubles, never by app code.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockease/models/stock_movement.dart';
import 'package:stockease/models/purchase_price.dart';
import 'package:stockease/services/inventory_service.dart';
import 'package:stockease/services/product_service.dart';

// These doubles exercise the actual InventoryService transaction callback.
// Server-side atomicity and security are tested separately with the emulator.
class MemoryFirestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  bool failCommit = false;
  int transactions = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      MemoryCollection(path);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    transactions++;
    final transaction = MemoryTransaction(documents);
    final result = await handler(transaction);
    if (failCommit) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    documents.addAll(transaction.writes);
    return result;
  }
}

class MemoryCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  MemoryCollection(this.path);
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      MemoryDocument('${this.path}/${path ?? 'new'}');
}

class MemoryDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  MemoryDocument(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      MemoryCollection('$path/$collectionPath');
}

class MemorySnapshot<T extends Object?> extends Fake
    implements DocumentSnapshot<T> {
  MemorySnapshot(this.value);
  final T? value;
  @override
  T? data() => value;
  @override
  bool get exists => value != null;
}

class MemoryTransaction extends Fake implements Transaction {
  MemoryTransaction(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  final writes = <String, Map<String, dynamic>>{};

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async {
    expect(
      writes,
      isEmpty,
      reason: 'Firestore requires all reads before writes',
    );
    return MemorySnapshot<T>(documents[reference.path] as T?);
  }

  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    writes[reference.path] = {
      ...documents[reference.path]!,
      for (final entry in data.entries) entry.key as String: entry.value,
    };
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    writes[reference.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }
}

void main() {
  test('product creation persists separate purchase snapshot without changing selling price or stock', () async {
    final db = MemoryFirestore();
    const purchase = PurchasePrice(
      original: 2,
      currency: 'USD',
      rate: 100.25,
      vnd: 201,
      rateDate: '2025-01-02',
    );
    final service = ProductService(db, 'owner');
    await service.save(
      name: 'Hàng mới',
      sku: 'NEW',
      category: 'Khác',
      price: 15000,
      minStock: 2,
      unit: 'box',
      quantity: 8,
      purchasePrice: purchase,
    );
    final saved = db.documents['users/owner/products/new']!;
    expect(saved['price'], 15000);
    expect(saved['quantity'], 8);
    expect(PurchasePrice.fromData(saved)!.toData(), purchase.toData());
    await service.save(
      id: 'new',
      name: 'Đổi tên',
      sku: 'NEW',
      category: 'Khác',
      price: 15000,
      minStock: 2,
      unit: 'box',
    );
    expect(db.documents['users/owner/products/new']!['quantity'], 8);
    expect(
      PurchasePrice.fromData(db.documents['users/owner/products/new']!)!
          .toData(),
      purchase.toData(),
    );
    await InventoryService(db, 'owner').record(
      movementId: 'in',
      productId: 'new',
      type: StockMovementType.stockIn,
      quantity: 2,
      note: '',
      transactionDate: DateTime(2025),
    );
    expect(db.documents['users/owner/products/new']!['quantity'], 10);
    expect(db.documents['users/owner/products/new']!['price'], 15000);
    expect(
      PurchasePrice.fromData(db.documents['users/owner/products/new']!)!
          .toData(),
      purchase.toData(),
    );
  });

  const productPath = 'users/owner/products/p';
  const movementPath = 'users/owner/stockMovements/m';
  final past = DateTime(2025, 2, 1, 9, 30);
  late MemoryFirestore db;
  late InventoryService inventory;
  setUp(() {
    db = MemoryFirestore();
    inventory = InventoryService(db, 'owner');
    db.documents[productPath] = {
      'userId': 'owner',
      'name': 'Coca-Cola',
      'sku': 'BV001',
      'isArchived': false,
      'quantity': 10,
    };
  });
  Future<void> record({
    int quantity = 3,
    StockMovementType type = StockMovementType.stockIn,
    DateTime? date,
  }) => inventory.record(
    movementId: 'm',
    productId: 'p',
    type: type,
    quantity: quantity,
    note: '  Ghi chú  ',
    transactionDate: date ?? past,
  );

  test('writes date and product snapshots atomically and retries without double stock', () async {
    await record();
    expect(db.documents[productPath]!['quantity'], 13);
    final movement = db.documents[movementPath]!;
    expect(movement['movementId'], 'm');
    expect(movement['userId'], 'owner');
    expect(movement['productId'], 'p');
    expect(movement['productName'], 'Coca-Cola');
    expect(movement['sku'], 'BV001');
    expect(movement['transactionDate'], Timestamp.fromDate(past));
    expect(movement['createdAt'], isA<FieldValue>());
    expect(movement['note'], 'Ghi chú');
    await record();
    expect(db.documents[productPath]!['quantity'], 13);
    expect(db.documents.length, 2);
    await expectLater(
      record(date: past.subtract(const Duration(days: 1))),
      throwsA(isA<ProductException>()),
    );
    expect(db.documents[productPath]!['quantity'], 13);
  });

  test(
    'stock out uses stock read inside transaction and rejects excess',
    () async {
      await record(type: StockMovementType.stockOut, quantity: 4);
      expect(db.documents[productPath]!['quantity'], 6);
      db.documents.remove(movementPath);
      db.documents[productPath]!['quantity'] = 1;
      await expectLater(
        record(type: StockMovementType.stockOut, quantity: 2),
        throwsA(isA<ProductException>()),
      );
      expect(db.documents[productPath]!['quantity'], 1);
      expect(db.documents.containsKey(movementPath), isFalse);
    },
  );

  test(
    'failed commit leaves both documents unchanged and can be retried',
    () async {
      db.failCommit = true;
      await expectLater(record(), throwsA(isA<FirebaseException>()));
      expect(db.documents[productPath]!['quantity'], 10);
      expect(db.documents.containsKey(movementPath), isFalse);
      db.failCommit = false;
      await record();
      expect(db.documents[productPath]!['quantity'], 13);
      expect(db.documents.containsKey(movementPath), isTrue);
    },
  );

  test(
    'future dates and invalid quantities are rejected before database access',
    () async {
      await expectLater(
        record(date: DateTime.now().add(const Duration(days: 1))),
        throwsA(isA<ProductException>()),
      );
      for (final quantity in [0, -1, ProductService.maxNumber + 1]) {
        await expectLater(
          record(quantity: quantity),
          throwsA(isA<ProductException>()),
        );
      }
      expect(db.transactions, 0);
    },
  );

  test(
    'missing, archived and foreign-owner products cannot create movements',
    () async {
      db.documents[productPath]!['isArchived'] = true;
      await expectLater(record(), throwsA(isA<ProductException>()));
      db.documents[productPath]!['isArchived'] = false;
      db.documents[productPath]!['userId'] = 'other';
      await expectLater(record(), throwsA(isA<ProductException>()));
      db.documents.remove(productPath);
      await expectLater(record(), throwsA(isA<ProductException>()));
      expect(db.documents.containsKey(movementPath), isFalse);
    },
  );
}
