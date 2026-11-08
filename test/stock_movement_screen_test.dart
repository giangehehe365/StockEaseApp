import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockease/models/product.dart';
import 'package:stockease/models/stock_movement.dart';
import 'package:stockease/screens/dashboard_screen.dart';
import 'package:stockease/screens/inventory/stock_movement_screen.dart';
import 'package:stockease/services/inventory_service.dart';
import 'package:stockease/services/product_service.dart';

Product testProduct([int quantity = 5]) => Product.fromData('product', {
  'userId': 'owner',
  'name': 'Sản phẩm thử',
  'sku': 'TEST',
  'category': 'Khác',
  'price': 10000,
  'quantity': quantity,
  'minStock': 2,
  'unit': 'piece',
});

StockMovement testMovement(StockMovementType type) =>
    StockMovement.fromData(type.code, {
      'userId': 'owner',
      'productId': 'product',
      'productName': 'Sản phẩm thử',
      'type': type.code,
      'quantity': 5,
      'note': '',
    });

class TestProductService extends Fake implements ProductService {
  TestProductService(this.product);

  final Product product;

  @override
  Stream<Product?> watchProduct(String id) => Stream.value(product);
}

class RecordingInventoryService extends Fake implements InventoryService {
  final pending = Completer<void>();
  final quantities = <int>[];
  final dates = <DateTime>[];

  @override
  String newMovementId() => 'movement';

  @override
  Future<void> record({
    required String movementId,
    required String productId,
    required StockMovementType type,
    required int quantity,
    required String note,
    required DateTime transactionDate,
  }) {
    quantities.add(quantity);
    dates.add(transactionDate);
    return pending.future;
  }
}

void main() {
  testWidgets('stock in picks a past date and time and previews the result', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(450, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final product = testProduct();
    final inventory = RecordingInventoryService();
    await tester.pumpWidget(
      MaterialApp(
        home: StockMovementScreen(
          products: TestProductService(product),
          inventory: inventory,
          product: product,
          type: StockMovementType.stockIn,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '7');
    await tester.pumpAndSettle();
    expect(find.text('12 piece'), findsOneWidget);
    await tester.tap(find.text('Ngày giao dịch'));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    final now = DateTime.now();
    expect(picker.lastDate, DateTime(now.year, now.month, now.day));
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextField),
      ),
      '01/02/2025',
    );
    await tester.tap(find.widgetWithText(TextButton, 'OK'));
    await tester.pumpAndSettle();
    final time = tester
        .widget<TimePickerDialog>(find.byType(TimePickerDialog))
        .initialTime;
    await tester.tap(find.widgetWithText(TextButton, 'OK'));
    await tester.pumpAndSettle();
    final expected = DateTime(2025, 1, 2, time.hour, time.minute);
    expect(find.text(formatMovementDate(expected)), findsOneWidget);
    await tester.tap(find.text('Xác nhận nhập kho'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tồn kho: 5 → 12 piece'), findsOneWidget);
    await tester.tap(find.text('Xác nhận'));
    await tester.pump();
    expect(inventory.quantities, [7]);
    expect(inventory.dates, [expected]);
    inventory.pending.completeError(const ProductException('Thử lỗi kết nối'));
    await tester.pumpAndSettle();
    expect(find.text('Thử lỗi kết nối'), findsOneWidget);
    expect(find.text(formatMovementDate(expected)), findsOneWidget);
  });

  testWidgets('dashboard refreshes stock and movement totals independently', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(450, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final movements = StreamController<List<StockMovement>>();
    addTearDown(movements.close);
    final products = ValueNotifier(testProduct());
    addTearDown(products.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<Product>(
            valueListenable: products,
            builder: (context, product, _) => DashboardScreen(
              name: 'Chủ kho',
              storeName: 'Kho thử',
              products: [product],
              onAdd: null,
              onProducts: () {},
              onOpen: (_) {},
              movements: movements.stream,
              onRetryMovements: () {},
            ),
          ),
        ),
      ),
    );
    Finder stat(String label, int value) => find.byWidgetPredicate(
      (widget) =>
          widget is StatCard && widget.label == label && widget.value == value,
    );
    movements.add([]);
    await tester.pumpAndSettle();
    expect(stat('Tổng số lượng tồn', 5), findsOneWidget);
    expect(stat('Giao dịch xuất kho', 0), findsOneWidget);

    products.value = testProduct(0);
    movements.add([testMovement(StockMovementType.stockOut)]);
    await tester.pumpAndSettle();
    expect(stat('Tổng số lượng tồn', 0), findsOneWidget);
    expect(stat('Tồn kho thấp', 0), findsOneWidget);
    expect(stat('Hết hàng', 1), findsOneWidget);
    expect(stat('Giao dịch xuất kho', 1), findsOneWidget);
  });

  testWidgets('rejects invalid and excessive quantities and submits once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(450, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final product = testProduct();
    final inventory = RecordingInventoryService();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => StockMovementScreen(
                    products: TestProductService(product),
                    inventory: inventory,
                    product: product,
                    type: StockMovementType.stockOut,
                  ),
                ),
              ),
              child: const Text('Mở phiếu'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở phiếu'));
    await tester.pumpAndSettle();
    final quantityField = find.byType(TextFormField).first;
    final submit = find.text('Xác nhận xuất kho');
    for (final invalid in ['-1', '0', 'abc', '1.5', '6']) {
      await tester.enterText(quantityField, invalid);
      await tester.pumpAndSettle();
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận'), findsNothing);
      expect(inventory.quantities, isEmpty);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xác nhận xuất kho'),
            )
            .onPressed,
        isNull,
      );
    }

    await tester.enterText(quantityField, '5');
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    final confirm = find.text('Xác nhận');
    await tester.tap(confirm);
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pump();
    expect(inventory.quantities, [5]);
    final busy = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Đang xử lý…'),
    );
    expect(busy.onPressed, isNull);
    inventory.pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Xuất kho thành công.'), findsOneWidget);
  });
}
