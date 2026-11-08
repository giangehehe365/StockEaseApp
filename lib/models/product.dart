import 'package:cloud_firestore/cloud_firestore.dart';

import 'purchase_price.dart';

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
      purchasePrice = PurchasePrice.fromData(data),
      purchasePriceVnd = _purchaseVnd(data['purchasePriceVnd']),
      isArchived = data['isArchived'] as bool? ?? false,
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
  final PurchasePrice? purchasePrice;
  final int? purchasePriceVnd;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOutOfStock => quantity == 0;
  bool get isLowStock => quantity > 0 && quantity <= minStock;

  String get formattedPrice => formatVnd(price);
}

int? _purchaseVnd(Object? value) =>
    value is int && value >= 0 && value <= PurchasePrice.maxAmount
    ? value
    : null;
