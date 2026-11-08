import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockease/models/product.dart';
import 'package:stockease/models/stock_movement.dart';
import 'package:stockease/services/inventory_report_calculator.dart';

Product product(
  String id,
  int quantity, {
  int minStock = 3,
  Object? cost,
  int sellingPrice = 999999,
  String owner = 'u',
  bool archived = false,
  String category = 'Đồ uống',
}) => Product.fromData(id, {
  'userId': owner,
  'name': 'Sản phẩm $id',
  'sku': id.toUpperCase(),
  'category': category,
  'price': sellingPrice,
  'quantity': quantity,
  'unit': 'box',
  'minStock': minStock,
  'isArchived': archived,
  'purchasePriceVnd': ?cost,
});
StockMovement movement(
  String id,
  int quantity,
  DateTime? date, {
  bool inbound = true,
  DateTime? created,
  String owner = 'u',
}) => StockMovement.fromData(id, {
  'userId': owner,
  'productId': 'archived-product',
  'productName': 'Hàng đã ẩn',
  'type': inbound ? 'IN' : 'OUT',
  'quantity': quantity,
  if (date != null) 'transactionDate': Timestamp.fromDate(date),
  if (created != null) 'createdAt': Timestamp.fromDate(created),
});

void main() {
  const calculator = InventoryReportCalculator('u');
  test('overview excludes archived and foreign products, deduplicates and never uses selling price', () {
    final a = product('a', 10, cost: 500);
    final overview = calculator.overview([
      a,
      a,
      product('b', 2, cost: 100),
      product('c', 0),
      product('equal', 3, cost: 0),
      product('archived', 100, cost: 99999, archived: true),
      product('foreign', 100, cost: 99999, owner: 'other'),
    ]);
    expect(overview.totalProducts, 4);
    expect(overview.totalQuantity, 15);
    expect(overview.totalValue, BigInt.from(5200));
    expect(overview.missingPurchasePrices, 1);
    expect(overview.lowStock, 2);
    expect(overview.outOfStock, 1);
    expect(overview.restock.map((p) => p.id), ['c', 'b', 'equal']);
    expect(suggestedRestock(overview.restock[0]), 3);
    expect(suggestedRestock(overview.restock[1]), 1);
    expect(suggestedRestock(overview.restock[2]), 0);
  });
  test('purchase values distinguish unknown and valid zero with exact large integer totals', () {
    final zero = product('zero', 9, cost: 0);
    final missing = product('missing', 9);
    expect(productInventoryValue(zero), BigInt.zero);
    expect(productInventoryValue(missing), isNull);
    expect(productInventoryValue(product('negative', 1, cost: -1)), isNull);
    expect(productInventoryValue(product('decimal', 1, cost: 1.5)), isNull);
    final large = product('large', 999999999999, cost: 999999999999);
    expect(
      productInventoryValue(large),
      BigInt.parse('999999999998000000000001'),
    );
    expect(
      formatInventoryValue(productInventoryValue(large)!),
      '999.999.999.998.000.000.000.001 ₫',
    );
  });
  test(
    'presets use local calendar boundaries and reject reversed custom ranges',
    () {
      final now = DateTime(2026, 11, 8, 19, 45);
      expect(
        reportRange(ReportPeriod.thisMonth, now).label,
        '01/11/2026 – 08/11/2026',
      );
      expect(
        reportRange(ReportPeriod.last7Days, now).start,
        DateTime(2026, 11, 2),
      );
      expect(
        reportRange(ReportPeriod.today, now).endExclusive,
        DateTime(2026, 11, 9),
      );
      expect(
        () => ReportDateRange(DateTime(2025, 2, 2), DateTime(2025, 2, 1)),
        throwsArgumentError,
      );
    },
  );
  test('movement counts differ from quantities and respect inclusive dates with legacy fallback', () {
    final range = ReportDateRange(DateTime(2025, 2, 1), DateTime(2025, 2, 2));
    final first = movement('first', 10, DateTime(2025, 2, 1));
    final result = calculator.movements([
      first,
      first,
      movement('last', 5, DateTime(2025, 2, 2, 23, 59, 59, 999)),
      movement(
        'legacy',
        3,
        null,
        created: DateTime(2025, 2, 2),
        inbound: false,
      ),
      movement('before', 100, DateTime(2025, 1, 31, 23, 59, 59)),
      movement('after', 100, DateTime(2025, 2, 3)),
      movement(
        'precedence',
        100,
        DateTime(2025, 2, 3),
        created: DateTime(2025, 2, 1),
      ),
      movement('unknown', 100, null),
      movement('foreign', 100, DateTime(2025, 2, 1), owner: 'other'),
    ], range);
    expect(result.inQuantity, 15);
    expect(result.outQuantity, 3);
    expect(result.inTransactions, 2);
    expect(result.outTransactions, 1);
    expect(result.net, 12);
    expect(result.missingDates, 1);
    expect(result.buckets.map((b) => b.stockIn), [10, 5]);
    expect(result.buckets.map((b) => b.stockOut), [0, 3]);
    expect(result.buckets.map((b) => b.label), ['01/02', '02/02']);
  });
  test('UTC timestamps group on the corresponding local calendar day', () {
    final local = DateTime(2025, 2, 2, 0, 15);
    final result = calculator.movements([
      movement('utc', 7, local.toUtc()),
    ], ReportDateRange(local, local));
    expect(result.inQuantity, 7);
    expect(result.buckets.single.stockIn, 7);
  });
  test('chart fills empty days and long ranges group chronologically into at most 24 buckets', () {
    final daily = calculator.movements([
      movement('d', 2, DateTime(2025, 1, 2)),
    ], ReportDateRange(DateTime(2025), DateTime(2025, 1, 3)));
    expect(daily.buckets.map((b) => b.stockIn), [0, 2, 0]);
    final monthly = calculator.movements([
      movement('m', 2, DateTime(2025, 3, 3)),
    ], ReportDateRange(DateTime(2025), DateTime(2025, 4, 1)));
    expect(monthly.groupLabel, 'Theo tháng');
    expect(monthly.buckets.map((b) => b.stockIn), [0, 0, 2, 0]);
    final long = calculator.movements([
      movement('long', 11, DateTime(2026, 11, 8)),
    ], ReportDateRange(DateTime(1970), DateTime(2026, 11, 8)));
    expect(long.buckets.length, lessThanOrEqualTo(24));
    expect(long.buckets.fold<int>(0, (total, b) => total + b.stockIn), 11);
    for (var i = 1; i < long.buckets.length; i++) {
      expect(long.buckets[i].start.isAfter(long.buckets[i - 1].start), isTrue);
    }
  });
  test('current stock never gets recalculated from movement totals or date filters', () {
    final source = [product('p', 20, cost: 100)];
    final movements = [movement('in', 5, DateTime(2025, 1, 2))];
    final before = calculator.overview(source);
    calculator.movements(
      movements,
      ReportDateRange(DateTime(2025), DateTime(2025, 1, 3)),
    );
    calculator.movements(
      movements,
      ReportDateRange(DateTime(2024), DateTime(2024, 1, 3)),
    );
    expect(calculator.overview(source).totalQuantity, before.totalQuantity);
    expect(calculator.overview(source).totalValue, BigInt.from(2000));
  });
  test(
    'report products search, category and value sorts keep unknown values last',
    () {
      final overview = calculator.overview([
        product('high', 2, cost: 100),
        product('low', 4, cost: 10),
        product('unknown', 20),
        product('zero', 1, cost: 0, category: 'Khác'),
      ]);
      expect(
        calculator
            .products(overview, sort: InventoryReportSort.valueDescending)
            .map((p) => p.id),
        ['high', 'low', 'zero', 'unknown'],
      );
      expect(
        calculator
            .products(overview, sort: InventoryReportSort.valueAscending)
            .map((p) => p.id),
        ['zero', 'low', 'high', 'unknown'],
      );
      expect(calculator.products(overview, search: ' HIGH ').map((p) => p.id), [
        'high',
      ]);
      expect(
        calculator
            .products(overview, search: 'sẢn phẩm', category: 'Khác')
            .map((p) => p.id),
        ['zero'],
      );
      expect(
        calculator
            .products(overview, sort: InventoryReportSort.quantityAscending)
            .map((p) => p.id),
        ['zero', 'high', 'low', 'unknown'],
      );
    },
  );
  test('empty reports have zero metrics and a dated zero-filled chart, without fake movements', () {
    final report = calculator.movements(
      [],
      ReportDateRange(DateTime(2025), DateTime(2025)),
    );
    expect(report.movements, isEmpty);
    expect(report.inQuantity, 0);
    expect(report.net, 0);
    expect(report.buckets.single.stockOut, 0);
    expect(calculator.overview([]).missingPurchasePrices, 0);
    expect(calculator.overview([]).totalValue, BigInt.zero);
  });
}
