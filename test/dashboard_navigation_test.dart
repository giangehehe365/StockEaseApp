// Test doubles stand in for SDK types only within this test.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockease/models/product.dart';
import 'package:stockease/models/product_list_query.dart';
import 'package:stockease/models/stock_movement.dart';
import 'package:stockease/screens/dashboard_screen.dart';
import 'package:stockease/screens/stock_shell.dart';
import 'package:stockease/screens/products/product_list_screen.dart';
import 'package:stockease/screens/products/product_details_screen.dart';
import 'package:stockease/screens/inventory/inventory_history_screen.dart';
import 'package:stockease/screens/inventory/stock_movement_screen.dart';
import 'package:stockease/screens/inventory/inventory_reports_screen.dart';
import 'package:stockease/widgets/stock_movement_chart.dart';
import 'package:stockease/services/auth_service.dart';
import 'package:stockease/services/product_service.dart';
import 'package:stockease/services/inventory_service.dart';
import 'package:stockease/theme/stock_theme.dart';
import 'package:stockease/widgets/product_card.dart';

class NavigationFirestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  final changes = StreamController<void>.broadcast();
  final paths = <String>[];
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      NavigationCollection(this, path);
  void publish() => changes.add(null);
}

class NavigationCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  NavigationCollection(this.db, this.path, [this.filters = const []]);
  final NavigationFirestore db;
  @override
  final String path;
  final List<(Object, Object?)> filters;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      NavigationDocument(db, '${this.path}/${path ?? 'newMovement'}');
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
  }) => NavigationCollection(db, path, [...filters, (field, isEqualTo)]);
  QuerySnapshot<Map<String, dynamic>> current() => NavigationQuerySnapshot([
    for (final entry in db.documents.entries)
      if (entry.key.startsWith('$path/') &&
          !entry.key.substring(path.length + 1).contains('/') &&
          filters.every((filter) => entry.value[filter.$1] == filter.$2))
        NavigationQueryDocument(entry.key.split('/').last, Map.of(entry.value)),
  ]);
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.multi((controller) {
    db.paths.add(path);
    controller.add(current());
    final subscription = db.changes.stream.listen(
      (_) => controller.add(current()),
    );
    controller.onCancel = subscription.cancel;
  }, isBroadcast: true);
}

class NavigationDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  NavigationDocument(this.db, this.path);
  final NavigationFirestore db;
  @override
  final String path;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      NavigationCollection(db, '$path/$collectionPath');
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.multi((controller) {
    db.paths.add(path);
    controller.add(NavigationDocumentSnapshot(db.documents[path]));
    final subscription = db.changes.stream.listen(
      (_) => controller.add(NavigationDocumentSnapshot(db.documents[path])),
    );
    controller.onCancel = subscription.cancel;
  }, isBroadcast: true);
}

class NavigationDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  NavigationDocumentSnapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  Map<String, dynamic>? data() => value == null ? null : Map.of(value!);
  @override
  bool get exists => value != null;
}

class NavigationQueryDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  NavigationQueryDocument(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}

class NavigationQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  NavigationQuerySnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class NavigationAuth extends Fake implements AuthService {}

class PendingProducts extends Fake implements ProductService {
  final stream = StreamController<List<Product>>.broadcast();
  @override
  Stream<List<Product>> watchProducts() => stream.stream;
}

class UnusedInventory extends Fake implements InventoryService {}

void main() {
  testWidgets('product route handles loading, errors, retry and empty stock', (
    tester,
  ) async {
    final products = PendingProducts();
    addTearDown(products.stream.close);
    await tester.pumpWidget(
      MaterialApp(
        home: ProductListScreen(
          service: products,
          inventory: UnusedInventory(),
          onAdd: () {},
          title: 'Sản phẩm hết hàng',
          initialStockFilter: ProductStockFilter.outOfStock,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    products.stream.addError(const ProductException('Không thể tải kho'));
    await tester.pumpAndSettle();
    expect(find.text('Không thể tải kho'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    products.stream.add([]);
    await tester.pumpAndSettle();
    expect(find.text('Kho chưa có sản phẩm'), findsOneWidget);
    expect(find.text('Hiển thị 0 sản phẩm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  late NavigationFirestore db;
  setUp(() {
    db = NavigationFirestore();
    void product(
      String id,
      String name,
      int quantity, {
      bool archived = false,
      String owner = 'owner',
    }) {
      db.documents['users/$owner/products/$id'] = {
        'userId': owner,
        'name': name,
        'sku': id.toUpperCase(),
        'quantity': quantity,
        'category': 'Khác',
        'unit': 'box',
        'price': 10000,
        'minStock': 3,
        'isArchived': archived,
      };
    }

    product('healthy', 'Nước khoáng', 10);
    product('low', 'Bánh gạo', 2);
    product('zero', 'Coca-Cola', 0);
    product('archived', 'Sản phẩm đã ẩn', 99, archived: true);
    product('foreign', 'Kho khác', 100, owner: 'other');
    for (final type in StockMovementType.values) {
      db.documents['users/owner/stockMovements/${type.code}'] = {
        'userId': 'owner',
        'productId': 'healthy',
        'productName': type.isIn ? 'Phiếu nhập' : 'Phiếu xuất',
        'type': type.code,
        'quantity': 1,
        'note': 'Ghi chú ${type.code}',
        'transactionDate': Timestamp.fromDate(DateTime(2025, 1, 1)),
      };
    }
    db.documents['users/other/stockMovements/foreign'] = {
      'userId': 'other',
      'productId': 'foreign',
      'productName': 'Giao dịch kho khác',
      'type': 'IN',
      'quantity': 100,
      'note': '',
    };
  });
  tearDown(() => db.changes.close());
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(450, 1600),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: stockTheme(Brightness.light),
        home: StockShell(
          uid: 'owner',
          email: 'owner@example.com',
          displayName: 'Chủ kho',
          auth: NavigationAuth(),
          firestore: db,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder stat(String label) => find.byWidgetPredicate(
    (widget) => widget is StatCard && widget.label == label,
  );
  Future<void> openStat(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      stat(label),
      250,
      scrollable: find
          .descendant(
            of: find.byType(DashboardScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(stat(label));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  }

  Future<void> openReports(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Báo cáo kho'));
    await tester.tap(find.text('Báo cáo kho'));
    await tester.pumpAndSettle();
    expect(find.byType(InventoryReportsScreen), findsOneWidget);
  }

  Finder reportMetric(String title, String value) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(Card)).first,
    matching: find.text(value),
  );

  testWidgets(
    'reports opens from Dashboard, separates current stock from date filter and drills into History',
    (tester) async {
      db.documents['users/owner/products/healthy']!['purchasePriceVnd'] = 500;
      db.documents['users/owner/products/low']!['purchasePriceVnd'] = 100;
      final now = DateTime.now();
      db.documents['users/owner/stockMovements/IN']!['transactionDate'] =
          Timestamp.fromDate(now);
      db.documents['users/owner/stockMovements/OUT']!['transactionDate'] =
          Timestamp.fromDate(now);
      await mount(tester);
      await openReports(tester);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tháng này'))
            .selected,
        isTrue,
      );
      expect(reportMetric('Tổng sản phẩm', '3'), findsOneWidget);
      expect(reportMetric('Tổng số lượng tồn', '12'), findsOneWidget);
      expect(reportMetric('Giá trị tồn kho', '5.200 ₫'), findsOneWidget);
      expect(reportMetric('Tồn thấp / Hết hàng', '1 / 1'), findsOneWidget);
      expect(find.textContaining('1 sản phẩm thiếu giá nhập'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hôm nay'));
      await tester.pumpAndSettle();
      expect(reportMetric('Giá trị tồn kho', '5.200 ₫'), findsOneWidget);
      final chart = tester.widget<StockMovementChart>(
        find.byType(StockMovementChart),
      );
      expect(chart.report.buckets.length, 1);
      expect(chart.report.buckets.single.stockIn, 1);
      expect(chart.report.buckets.single.stockOut, 1);
      await tester.ensureVisible(find.text('Tổng số lượng nhập'));
      await tester.tap(find.text('Tổng số lượng nhập'));
      await tester.pumpAndSettle();
      final history = tester.widget<InventoryHistoryScreen>(
        find.byType(InventoryHistoryScreen),
      );
      expect(history.initialFilter, StockMovementType.stockIn);
      expect(
        history.initialDateRange!.start,
        DateTime(now.year, now.month, now.day),
      );
      expect(find.text('Phiếu nhập'), findsOneWidget);
      expect(find.text('Phiếu xuất'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(db.paths.every((path) => path.startsWith('users/owner/')), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reports custom dates show old movements while live stock changes update overview',
    (tester) async {
      await mount(tester);
      await openReports(tester);
      expect(
        find.text('Chưa có giao dịch trong khoảng ngày đã chọn.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tùy chọn'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      final dates = find.descendant(
        of: find.byType(DateRangePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dates.first, '01/01/2025');
      await tester.enterText(dates.last, '01/01/2025');
      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pumpAndSettle();
      final chart = tester.widget<StockMovementChart>(
        find.byType(StockMovementChart),
      );
      expect(chart.report.inQuantity, 1);
      expect(chart.report.outQuantity, 1);
      expect(find.text('01/01/2025 – 01/01/2025'), findsOneWidget);
      db.documents['users/owner/products/zero']!['quantity'] = 6;
      db.publish();
      await tester.pumpAndSettle();
      expect(reportMetric('Tổng số lượng tồn', '18'), findsOneWidget);
      expect(reportMetric('Tồn thấp / Hết hàng', '1 / 0'), findsOneWidget);
      expect(find.text('01/01/2025 – 01/01/2025'), findsOneWidget);
      expect(
        tester
            .widget<StockMovementChart>(find.byType(StockMovementChart))
            .report
            .inQuantity,
        1,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openReports(tester);
      expect(reportMetric('Tổng số lượng tồn', '18'), findsOneWidget);
    },
  );

  testWidgets(
    'report product filters, sorting, details and restock work on a small screen',
    (tester) async {
      await mount(tester, size: const Size(360, 800));
      await openReports(tester);
      final scroll = find
          .descendant(
            of: find.byType(InventoryReportsScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Bổ sung tối thiểu: 3 box'),
        350,
        scrollable: scroll,
      );
      final restockCard = find.ancestor(
        of: find.text('Bổ sung tối thiểu: 3 box'),
        matching: find.byType(Card),
      );
      await tester.ensureVisible(
        find.descendant(of: restockCard, matching: find.text('Nhập thêm hàng')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: restockCard, matching: find.text('Nhập thêm hàng')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StockMovementScreen>(find.byType(StockMovementScreen))
            .product
            .id,
        'zero',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      final search = find.widgetWithText(
        TextField,
        'Tìm tên hoặc SKU trong báo cáo',
      );
      await tester.scrollUntilVisible(search, 350, scrollable: scroll);
      await tester.enterText(search, 'low');
      await tester.pumpAndSettle();
      expect(find.text('Hiển thị 1/3 sản phẩm'), findsOneWidget);
      await tester.ensureVisible(find.text('Số lượng giảm dần'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Số lượng giảm dần'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giá trị tồn tăng dần').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Giá trị tồn: chưa xác định'),
        150,
        scrollable: scroll,
      );
      // Legacy products have an unknown purchase value, not a fabricated zero.
      expect(find.text('Chưa có giá nhập'), findsWidgets);
      final card = find.ancestor(
        of: find.text('Giá trị tồn: chưa xác định'),
        matching: find.byType(Card),
      );
      await tester.ensureVisible(
        find.descendant(of: card, matching: find.text('Bánh gạo')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: card, matching: find.text('Bánh gạo')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProductDetailsScreen>(find.byType(ProductDetailsScreen))
            .productId,
        'low',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all four product stats open reused routes with correct filters and Back',
    (tester) async {
      await mount(tester);
      for (final (label, filter, sort, count) in [
        ('Tổng sản phẩm', ProductStockFilter.all, ProductSort.newest, 3),
        (
          'Tổng số lượng tồn',
          ProductStockFilter.all,
          ProductSort.quantityDescending,
          3,
        ),
        ('Tồn kho thấp', ProductStockFilter.lowStock, ProductSort.newest, 1),
        ('Hết hàng', ProductStockFilter.outOfStock, ProductSort.newest, 1),
      ]) {
        await openStat(tester, label);
        final list = tester.widget<ProductListScreen>(
          find.byType(ProductListScreen),
        );
        expect(list.initialStockFilter, filter);
        expect(list.initialSort, sort);
        expect(find.text('Hiển thị $count sản phẩm'), findsOneWidget);
        expect(find.text('Sản phẩm đã ẩn'), findsNothing);
        expect(find.text('Kho khác'), findsNothing);
        if (filter == ProductStockFilter.lowStock) {
          expect(find.text('Bánh gạo'), findsOneWidget);
          expect(find.text('Coca-Cola'), findsNothing);
          await tester.tap(find.text('Xóa bộ lọc'));
          await tester.pumpAndSettle();
          expect(find.text('Hiển thị 3 sản phẩm'), findsOneWidget);
        }
        if (filter == ProductStockFilter.outOfStock) {
          expect(find.text('Coca-Cola'), findsOneWidget);
          expect(find.text('Nhập thêm hàng'), findsOneWidget);
          await tester.tap(find.text('Nhập thêm hàng'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<StockMovementScreen>(find.byType(StockMovementScreen))
                .product
                .id,
            'zero',
          );
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        if (sort == ProductSort.quantityDescending) {
          expect(find.text('12'), findsOneWidget);
          expect(
            tester
                .widgetList<ProductCard>(find.byType(ProductCard))
                .map((card) => card.product.id),
            ['healthy', 'low', 'zero'],
          );
          await tester.enterText(find.byType(TextField), 'LOW');
          await tester.pumpAndSettle();
          expect(find.text('Hiển thị 1 sản phẩm'), findsOneWidget);
          expect(find.text('2'), findsOneWidget);
        }
        await back(tester);
      }
      expect(db.paths.every((path) => path.startsWith('users/owner/')), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'transaction stats apply IN/OUT immediately and expose details and empty state',
    (tester) async {
      await mount(tester);
      for (final type in StockMovementType.values) {
        await openStat(
          tester,
          type.isIn ? 'Giao dịch nhập kho' : 'Giao dịch xuất kho',
        );
        expect(
          tester
              .widget<InventoryHistoryScreen>(
                find.byType(InventoryHistoryScreen),
              )
              .initialFilter,
          type,
        );
        expect(
          find.text(type.isIn ? 'Phiếu nhập' : 'Phiếu xuất'),
          findsOneWidget,
        );
        expect(
          find.text(type.isIn ? 'Phiếu xuất' : 'Phiếu nhập'),
          findsNothing,
        );
        await tester.tap(find.text(type.isIn ? 'Phiếu nhập' : 'Phiếu xuất'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Đóng'));
        await tester.pumpAndSettle();
        if (!type.isIn) {
          db.documents.remove('users/owner/stockMovements/OUT');
          db.publish();
          await tester.pumpAndSettle();
          expect(find.text('Chưa có giao dịch xuất kho'), findsOneWidget);
        }
        await back(tester);
      }
      expect(find.text('Giao dịch kho khác'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'live stock changes update filtered list and dashboard without resetting filters',
    (tester) async {
      await mount(tester);
      await openStat(tester, 'Hết hàng');
      db.documents['users/owner/products/zero']!['quantity'] = 8;
      db.publish();
      await tester.pumpAndSettle();
      expect(find.text('Coca-Cola'), findsNothing);
      expect(find.text('Hiển thị 0 sản phẩm'), findsOneWidget);
      await back(tester);
      expect(tester.widget<StatCard>(stat('Hết hàng')).value, 0);
      expect(tester.widget<StatCard>(stat('Tổng số lượng tồn')).value, 20);
      expect(tester.widget<StatCard>(stat('Tồn kho thấp')).value, 1);
    },
  );

  testWidgets(
    'restock opens the correct product and stock-in form on a small screen',
    (tester) async {
      await mount(tester, size: const Size(360, 800));
      final dashboardScroll = find
          .descendant(
            of: find.byType(DashboardScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Coca-Cola'),
        250,
        scrollable: dashboardScroll,
      );
      await tester.tap(find.text('Coca-Cola'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProductDetailsScreen>(find.byType(ProductDetailsScreen))
            .productId,
        'zero',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      final zeroCard = find.byWidgetPredicate(
        (widget) => widget is ProductCard && widget.product.id == 'zero',
      );
      final restock = find.descendant(
        of: zeroCard,
        matching: find.text('Nhập thêm hàng'),
      );
      await tester.ensureVisible(restock);
      await tester.tap(restock);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StockMovementScreen>(find.byType(StockMovementScreen))
            .product
            .id,
        'zero',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dashboard routes preserve the existing Products tab search', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byIcon(Icons.inventory_2_outlined).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'healthy');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    await openStat(tester, 'Tồn kho thấp');
    await back(tester);
    await tester.tap(find.byIcon(Icons.inventory_2_outlined).last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'healthy',
    );
    expect(find.text('Hiển thị 1 sản phẩm'), findsOneWidget);
    expect(find.text('Nước khoáng'), findsOneWidget);
  });
}
