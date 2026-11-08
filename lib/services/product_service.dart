import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';

class ProductException implements Exception {
  const ProductException(this.message);

  final String message;
}

class DuplicateSkuException extends ProductException {
  const DuplicateSkuException() : super('SKU này đã có trong kho.');
}

class ProductService {
  ProductService(this._db, this._userId);

  final FirebaseFirestore _db;
  final String _userId;

  static final skuPattern = RegExp(r'^(?!__.*__$)[a-zA-Z0-9_-]{1,40}$');
  static const maxNumber = 999999999999;

  DocumentReference<Map<String, dynamic>> get _owner =>
      _db.collection('users').doc(_userId);

  CollectionReference<Map<String, dynamic>> get _products =>
      _owner.collection('products');

  DocumentReference<Map<String, dynamic>> _sku(String sku) =>
      _owner.collection('productSkus').doc(sku);

  Stream<List<Product>> watchProducts() {
    return _products.where('isArchived', isEqualTo: false).snapshots().map((
      snapshot,
    ) {
      final products = snapshot.docs.map(Product.fromDocument).toList();
      products.sort((first, second) {
        final byName = first.name.toLowerCase().compareTo(
          second.name.toLowerCase(),
        );
        return byName == 0 ? first.id.compareTo(second.id) : byName;
      });
      return products;
    });
  }

  Stream<Product?> watchProduct(String id) =>
      _products.doc(id).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data()!['isArchived'] == true) {
          return null;
        }
        return Product.fromDocument(snapshot);
      });

  Future<void> save({
    String? id,
    required String name,
    required String sku,
    required String category,
    required int price,
    required int minStock,
    required String unit,
    int? quantity,
  }) async {
    final skuKey = sku.trim().toUpperCase();
    if (!skuPattern.hasMatch(sku.trim())) {
      throw const ProductException('SKU không hợp lệ.');
    }
    final product = id == null ? _products.doc() : _products.doc(id);
    final reservation = _sku(skuKey);
    final changes = <String, dynamic>{
      'name': name.trim(),
      'sku': skuKey,
      'category': category,
      'price': price,
      'minStock': minStock,
      'unit': unit,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _db.runTransaction((transaction) async {
      String? previousSku;
      if (id != null) {
        final data = (await transaction.get(product)).data();
        if (data == null || data['isArchived'] == true) {
          throw const ProductException('Sản phẩm không còn trong kho.');
        }
        previousSku = data['sku'] as String;
      }

      if (previousSku != skuKey) {
        if ((await transaction.get(reservation)).exists) {
          throw const DuplicateSkuException();
        }
        if (previousSku != null) transaction.delete(_sku(previousSku));
        transaction.set(reservation, {'productId': product.id});
      }

      if (id == null) {
        if (quantity == null) {
          throw const ProductException('Hãy nhập số lượng tồn ban đầu.');
        }
        transaction.set(product, {
          ...changes,
          'userId': _userId,
          'quantity': quantity,
          'isArchived': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(product, changes);
      }
    });
  }

  Future<void> archive(String id) async {
    final product = _products.doc(id);
    await _db.runTransaction((transaction) async {
      final data = (await transaction.get(product)).data();
      if (data == null || data['isArchived'] == true) return;
      transaction.delete(_sku(data['sku'] as String));
      transaction.update(product, {
        'isArchived': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

String productErrorMessage(Object error) {
  if (error is ProductException) return error.message;
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'Không có quyền truy cập kho. Hãy kiểm tra phiên và cấu hình Firestore.',
      'unavailable' || 'deadline-exceeded' =>
        'Không thể kết nối Firestore. Hãy kiểm tra mạng và thử lại.',
      _ => 'Không thể truy cập dữ liệu sản phẩm. Hãy thử lại.',
    };
  }
  return 'Đã xảy ra lỗi. Hãy thử lại.';
}
