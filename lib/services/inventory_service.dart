import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/stock_movement.dart';
import 'product_service.dart';

class InventoryService {
  InventoryService(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;
  static const maxNoteLength = 300;

  DocumentReference<Map<String, dynamic>> get _owner =>
      _db.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _movements =>
      _owner.collection('stockMovements');

  String newMovementId() => _movements.doc().id;

  Stream<List<StockMovement>> watchMovements({String? productId}) {
    final query = productId == null
        ? _movements
        : _movements.where('productId', isEqualTo: productId);
    return query.snapshots().map((snapshot) {
      return queryMovements(
        snapshot.docs.map(StockMovement.fromDocument).toList(),
      );
    });
  }

  Future<void> record({
    required String movementId,
    required String productId,
    required StockMovementType type,
    required int quantity,
    required String note,
    required DateTime transactionDate,
  }) async {
    final cleanNote = note.trim();
    if (quantity <= 0 || quantity > ProductService.maxNumber) {
      throw const ProductException('Hãy nhập số nguyên dương hợp lệ.');
    }
    if (cleanNote.length > maxNoteLength) {
      throw const ProductException('Ghi chú tối đa 300 ký tự.');
    }
    if (transactionDate.isAfter(DateTime.now())) {
      throw const ProductException('Ngày giao dịch không được ở tương lai.');
    }
    final date = Timestamp.fromDate(transactionDate);
    final product = _owner.collection('products').doc(productId);
    final movement = _movements.doc(movementId);

    await _db.runTransaction((transaction) async {
      final existing = (await transaction.get(movement)).data();
      if (existing != null) {
        if (existing['productId'] == productId &&
            existing['type'] == type.code &&
            existing['quantity'] == quantity &&
            existing['note'] == cleanNote &&
            existing['transactionDate'] == date) {
          return;
        }
        throw const ProductException(
          'Giao dịch trước đã được ghi. Hãy mở lại form để tạo giao dịch mới.',
        );
      }
      final data = (await transaction.get(product)).data();
      if (data == null ||
          data['isArchived'] == true ||
          data['userId'] != _uid) {
        throw const ProductException('Sản phẩm không còn trong kho.');
      }
      final current = data['quantity'] as int;
      final next = type.isIn ? current + quantity : current - quantity;
      if (next < 0) {
        throw ProductException('Không đủ tồn kho. Hiện còn $current.');
      }
      if (next > ProductService.maxNumber) {
        throw const ProductException('Số lượng tồn sau khi nhập quá lớn.');
      }

      transaction.update(product, {
        'quantity': next,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMovementId': movementId,
      });
      transaction.set(movement, {
        'movementId': movementId,
        'userId': _uid,
        'productId': productId,
        'productName': data['name'] as String,
        'sku': data['sku'] as String,
        'type': type.code,
        'quantity': quantity,
        'note': cleanNote,
        'createdAt': FieldValue.serverTimestamp(),
        'transactionDate': date,
      });
    });
  }
}
