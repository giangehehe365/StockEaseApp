import '../models/product.dart';
import '../models/product_list_query.dart';
import '../models/stock_movement.dart';

enum ReportPeriod {
  today('Hôm nay'),
  last7Days('7 ngày qua'),
  thisMonth('Tháng này'),
  custom('Tùy chọn');

  const ReportPeriod(this.label);
  final String label;
}

/// Local calendar days. The end is inclusive; filtering uses next-day midnight.
class ReportDateRange {
  ReportDateRange(DateTime first, DateTime last)
    : start = _day(first),
      end = _day(last) {
    if (end.isBefore(start)) {
      throw ArgumentError('Ngày kết thúc trước ngày bắt đầu');
    }
  }
  final DateTime start;
  final DateTime end;
  DateTime get endExclusive => DateTime(end.year, end.month, end.day + 1);
  String get label => '${reportDay(start)} – ${reportDay(end)}';
  static DateTime _day(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

ReportDateRange reportRange(ReportPeriod period, DateTime now) {
  final today = ReportDateRange._day(now);
  return switch (period) {
    ReportPeriod.today => ReportDateRange(today, today),
    ReportPeriod.last7Days => ReportDateRange(
      DateTime(today.year, today.month, today.day - 6),
      today,
    ),
    ReportPeriod.thisMonth => ReportDateRange(
      DateTime(today.year, today.month),
      today,
    ),
    ReportPeriod.custom => throw ArgumentError(
      'Cần chọn khoảng ngày tùy chỉnh',
    ),
  };
}

String reportDay(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

BigInt? productInventoryValue(Product product) =>
    product.purchasePriceVnd == null
    ? null
    : BigInt.from(product.quantity) * BigInt.from(product.purchasePriceVnd!);

String formatInventoryValue(BigInt value) =>
    '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.')} ₫';

int suggestedRestock(Product product) => product.minStock > product.quantity
    ? product.minStock - product.quantity
    : 0;

class InventoryOverview {
  InventoryOverview(this.products);
  final List<Product> products;
  int get totalProducts => products.length;
  int get totalQuantity =>
      products.fold(0, (sum, product) => sum + product.quantity);
  int get missingPurchasePrices =>
      products.where((product) => product.purchasePriceVnd == null).length;
  BigInt get totalValue => products.fold(
    BigInt.zero,
    (sum, product) => sum + (productInventoryValue(product) ?? BigInt.zero),
  );
  int get lowStock => products.where((product) => product.isLowStock).length;
  int get outOfStock =>
      products.where((product) => product.isOutOfStock).length;
  List<Product> get restock =>
      products
          .where((product) => product.isLowStock || product.isOutOfStock)
          .toList()
        ..sort((a, b) {
          final byStock = a.quantity.compareTo(b.quantity);
          return byStock == 0 ? a.id.compareTo(b.id) : byStock;
        });
}

class MovementBucket {
  MovementBucket({
    required this.start,
    required this.endExclusive,
    required this.label,
  });
  final DateTime start;
  final DateTime endExclusive;
  final String label;
  int stockIn = 0;
  int stockOut = 0;
}

class StockMovementReport {
  StockMovementReport({
    required this.movements,
    required this.buckets,
    required this.groupLabel,
    required this.missingDates,
  });
  final List<StockMovement> movements;
  final List<MovementBucket> buckets;
  final String groupLabel;
  final int missingDates;
  int get inQuantity =>
      movements.where((m) => m.type.isIn).fold(0, (sum, m) => sum + m.quantity);
  int get outQuantity => movements
      .where((m) => !m.type.isIn)
      .fold(0, (sum, m) => sum + m.quantity);
  int get inTransactions => movements.where((m) => m.type.isIn).length;
  int get outTransactions => movements.length - inTransactions;
  int get net => inQuantity - outQuantity;
}

enum InventoryReportSort {
  quantityDescending('Số lượng giảm dần'),
  quantityAscending('Số lượng tăng dần'),
  valueDescending('Giá trị tồn giảm dần'),
  valueAscending('Giá trị tồn tăng dần');

  const InventoryReportSort(this.label);
  final String label;
}

class InventoryReportCalculator {
  const InventoryReportCalculator(this.userId);
  final String userId;

  InventoryOverview overview(Iterable<Product> products) => InventoryOverview(
    {
      for (final product in products)
        if (product.userId == userId && !product.isArchived)
          product.id: product,
    }.values.toList(),
  );

  StockMovementReport movements(
    Iterable<StockMovement> source,
    ReportDateRange range,
  ) {
    final unique = {
      for (final m in source)
        if (m.userId == userId) m.id: m,
    }.values.toList();
    final selected = queryMovements(unique, start: range.start, end: range.end);
    final days =
        DateTime.utc(range.end.year, range.end.month, range.end.day)
            .difference(
              DateTime.utc(
                range.start.year,
                range.start.month,
                range.start.day,
              ),
            )
            .inDays +
        1;
    final monthCount =
        (range.end.year - range.start.year) * 12 +
        range.end.month -
        range.start.month +
        1;
    final monthStep = (monthCount / 24).ceil();
    final buckets = <MovementBucket>[];
    if (days <= 62) {
      for (
        var day = range.start;
        day.isBefore(range.endExclusive);
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        buckets.add(
          MovementBucket(
            start: day,
            endExclusive: DateTime(day.year, day.month, day.day + 1),
            label:
                '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}',
          ),
        );
      }
    } else {
      for (var offset = 0; offset < monthCount; offset += monthStep) {
        final first = DateTime(range.start.year, range.start.month + offset);
        final next = DateTime(first.year, first.month + monthStep);
        buckets.add(
          MovementBucket(
            start: first.isBefore(range.start) ? range.start : first,
            endExclusive: next.isAfter(range.endExclusive)
                ? range.endExclusive
                : next,
            label: '${first.month.toString().padLeft(2, '0')}/${first.year}',
          ),
        );
      }
    }
    for (final movement in selected) {
      final date = movement.effectiveDate!.toLocal();
      final bucket = buckets.firstWhere(
        (b) => !date.isBefore(b.start) && date.isBefore(b.endExclusive),
      );
      if (movement.type.isIn) {
        bucket.stockIn += movement.quantity;
      } else {
        bucket.stockOut += movement.quantity;
      }
    }
    return StockMovementReport(
      movements: selected,
      buckets: buckets,
      groupLabel: days <= 62
          ? 'Theo ngày'
          : (monthStep == 1 ? 'Theo tháng' : 'Theo nhóm $monthStep tháng'),
      missingDates: unique.where((m) => m.effectiveDate == null).length,
    );
  }

  List<Product> products(
    InventoryOverview overview, {
    String search = '',
    String category = '',
    InventoryReportSort sort = InventoryReportSort.quantityDescending,
  }) {
    final result = queryProducts(
      overview.products,
      search: search,
      category: category,
    );
    result.sort((a, b) {
      int comparison;
      if (sort == InventoryReportSort.quantityAscending ||
          sort == InventoryReportSort.quantityDescending) {
        comparison = sort == InventoryReportSort.quantityAscending
            ? a.quantity.compareTo(b.quantity)
            : b.quantity.compareTo(a.quantity);
      } else {
        final first = productInventoryValue(a);
        final second = productInventoryValue(b);
        // Unknown values always follow known values, including a valid zero.
        comparison = first == null
            ? (second == null ? 0 : 1)
            : second == null
            ? -1
            : (sort == InventoryReportSort.valueAscending
                  ? first.compareTo(second)
                  : second.compareTo(first));
      }
      return comparison == 0 ? a.id.compareTo(b.id) : comparison;
    });
    return result;
  }
}
