import 'package:cloud_firestore/cloud_firestore.dart';

enum StockMovementType {
  stockIn('IN', 'Nhập kho'),
  stockOut('OUT', 'Xuất kho');

  const StockMovementType(this.code, this.label);

  final String code;
  final String label;

  bool get isIn => this == stockIn;
}

class StockMovement {
  StockMovement.fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc)
    : this.fromData(doc.id, doc.data());

  StockMovement.fromData(this.id, Map<String, dynamic> data)
    : userId = data['userId'] as String,
      productId = data['productId'] as String,
      productName = data['productName'] as String,
      type = StockMovementType.values.firstWhere(
        (type) => type.code == data['type'],
      ),
      quantity = data['quantity'] as int,
      sku = data['sku'] as String? ?? '',
      note = data['note'] as String? ?? '',
      transactionDate = (data['transactionDate'] as Timestamp?)?.toDate(),
      createdAt = (data['createdAt'] as Timestamp?)?.toDate();

  final String id;
  final String userId;
  final String productId;
  final String productName;
  final StockMovementType type;
  final int quantity;
  final String note;
  final String sku;
  final DateTime? transactionDate;
  final DateTime? createdAt;

  DateTime? get effectiveDate => transactionDate ?? createdAt;
}

String formatMovementDate(DateTime? date) {
  if (date == null) return 'Đang đồng bộ';
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

List<StockMovement> queryMovements(
  List<StockMovement> movements, {
  String search = '',
  StockMovementType? type,
  DateTime? start,
  DateTime? end,
}) {
  final keyword = search.trim().toLowerCase();
  final endExclusive = end == null
      ? null
      : DateTime(end.year, end.month, end.day + 1);
  final startDay = start == null
      ? null
      : DateTime(start.year, start.month, start.day);
  return movements.where((movement) {
    final date = movement.effectiveDate;
    return (type == null || movement.type == type) &&
        (movement.productName.toLowerCase().contains(keyword) ||
            movement.sku.toLowerCase().contains(keyword)) &&
        (startDay == null || (date != null && !date.isBefore(startDay))) &&
        (endExclusive == null || (date != null && date.isBefore(endExclusive)));
  }).toList()..sort((a, b) {
    final byTime = (b.effectiveDate?.microsecondsSinceEpoch ?? 0).compareTo(
      a.effectiveDate?.microsecondsSinceEpoch ?? 0,
    );
    return byTime == 0 ? b.id.compareTo(a.id) : byTime;
  });
}
