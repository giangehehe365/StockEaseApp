import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  Product.fromDocument(DocumentSnapshot<Map<String, dynamic>> document)
    : this.fromData(document.id, document.data()!);

  Product.fromData(this.id, Map<String, dynamic> data)
    : userId = data['userId'] as String,
      name = data['name'] as String,
      sku = data['sku'] as String,
      category = data['category'] as String,
      price = data['price'] as int,
      quantity = data['quantity'] as int,
      minStock = data['minStock'] as int,
      unit = data['unit'] as String,
      createdAt = (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

  final String id;
  final String userId;
  final String name;
  final String sku;
  final String category;
  final int price;
  final int quantity;
  final int minStock;
  final String unit;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOutOfStock => quantity == 0;
  bool get isLowStock => quantity > 0 && quantity <= minStock;

  String get formattedPrice {
    final digits = price.toString();
    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      groups.add(digits.substring(end > 3 ? end - 3 : 0, end));
    }
    return '${groups.reversed.join('.')} ₫';
  }
}
