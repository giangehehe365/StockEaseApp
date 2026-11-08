import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockease/models/product.dart';
import 'package:stockease/models/stock_movement.dart';
import 'package:stockease/screens/inventory/product_selection_sheet.dart';
import 'package:stockease/screens/inventory/inventory_history_screen.dart';
import 'package:stockease/services/inventory_service.dart';

Product product(String id, String name, String sku, int quantity) =>
    Product.fromData(id, {
      'userId': 'owner',
      'name': name,
      'sku': sku,
      'category': 'Khác',
      'price': 1,
      'quantity': quantity,
      'minStock': 0,
      'unit': 'box',
    });

StockMovement movement(
  String id, {
  DateTime? transactionDate,
  DateTime? createdAt,
  String name = 'Coca-Cola',
  String sku = '',
  String? note,
  StockMovementType type = StockMovementType.stockIn,
}) => StockMovement.fromData(id, {
  'userId': 'owner',
  'productId': 'p',
  'productName': name,
  'sku': sku,
  'type': type.code,
  'quantity': 3,
  'note': note,
  'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt),
  'transactionDate': transactionDate == null
      ? null
      : Timestamp.fromDate(transactionDate),
});

class HistoryInventory extends Fake implements InventoryService {
  HistoryInventory(this.movements);
  final List<StockMovement> movements;
  @override
  Stream<List<StockMovement>> watchMovements({String? productId}) =>
      Stream.value(movements);
}

void main() {
  testWidgets('selection remains scrollable with a short keyboard viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(viewInsets: const EdgeInsets.only(bottom: 200)),
              child: SizedBox(
                height: 320,
                child: ProductSelectionSheet(
                  products: [
                    product(
                      'a',
                      'Tên sản phẩm dài để kiểm tra giao diện',
                      'BV001',
                      4,
                    ),
                  ],
                  type: StockMovementType.stockOut,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Chỉ còn hàng'));
    await tester.pumpAndSettle();
    expect(find.text('Chỉ còn hàng').hitTestable(), findsOneWidget);
  });

  test('legacy dates, null note and missing timestamps remain safe', () {
    final created = DateTime(2025, 2, 1, 23, 59);
    final legacy = movement('legacy', createdAt: created);
    expect(legacy.effectiveDate, created);
    expect(legacy.note, '');
    expect(legacy.sku, '');
    expect(formatMovementDate(legacy.effectiveDate), '01/02/2025 23:59');
    expect(
      formatMovementDate(movement('pending').effectiveDate),
      'Đang đồng bộ',
    );
  });

  test('history sorts by transaction date with legacy fallback and inclusive day range', () {
    final old = movement(
      'a',
      transactionDate: DateTime(2025, 1, 1),
      createdAt: DateTime(2025, 3, 1),
    );
    final lastMinute = movement(
      'b',
      transactionDate: DateTime(2025, 2, 1, 23, 59),
      sku: 'BV001',
    );
    final legacy = movement(
      'c',
      createdAt: DateTime(2025, 2, 2),
      type: StockMovementType.stockOut,
    );
    final pending = movement('d');
    final data = [old, legacy, pending, lastMinute];
    expect(queryMovements(data), [legacy, lastMinute, old, pending]);
    expect(queryMovements(data, search: ' cOcA '), [
      legacy,
      lastMinute,
      old,
      pending,
    ]);
    expect(queryMovements(data, search: 'bv00'), [lastMinute]);
    expect(queryMovements(data, type: StockMovementType.stockOut), [legacy]);
    expect(
      queryMovements(
        data,
        start: DateTime(2025, 2, 1),
        end: DateTime(2025, 2, 1),
      ),
      [lastMinute],
    );
    expect(data, [old, legacy, pending, lastMinute]);
  });

  testWidgets(
    'selection searches name and SKU, clears and filters positive stock',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final products = [
        product('a', 'Coca-Cola', 'BV001', 4),
        product('b', 'Bánh gạo', 'SN002', 0),
      ];
      Product? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showModalBottomSheet<Product>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    constraints: const BoxConstraints(maxHeight: 650),
                    builder: (_) => ProductSelectionSheet(
                      products: products,
                      type: StockMovementType.stockOut,
                    ),
                  );
                },
                child: const Text('Chọn'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Chọn'));
      await tester.pumpAndSettle();
      final search = find.byType(TextField);
      await tester.enterText(search, ' cOcA ');
      await tester.pumpAndSettle();
      expect(find.text('Coca-Cola'), findsOneWidget);
      expect(find.text('Bánh gạo'), findsNothing);
      await tester.enterText(search, 'sn00');
      await tester.pumpAndSettle();
      expect(find.text('Bánh gạo'), findsOneWidget);
      await tester.tap(find.text('Chỉ còn hàng'));
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy sản phẩm'), findsOneWidget);
      await tester.tap(find.byTooltip('Xóa từ khóa'));
      await tester.pumpAndSettle();
      expect(find.text('Coca-Cola'), findsOneWidget);
      expect(find.text('Bánh gạo'), findsNothing);
      await tester.tap(find.text('Coca-Cola'));
      await tester.pumpAndSettle();
      expect(selected?.id, 'a');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history shows selected date, searches SKU, filters type and opens note',
    (tester) async {
      final stockIn = movement(
        'a',
        transactionDate: DateTime(2025, 2, 1, 9, 30),
        createdAt: DateTime(2025, 3, 1),
        sku: 'BV001',
        note: 'Giao bù hôm trước',
      );
      final stockOut = movement(
        'b',
        name: 'Bánh gạo',
        type: StockMovementType.stockOut,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryHistoryScreen(
            inventory: HistoryInventory([stockIn, stockOut]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('01/02/2025 09:30'), findsOneWidget);
      await tester.tap(find.text('Khoảng ngày'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      final dateFields = find.descendant(
        of: find.byType(DateRangePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dateFields.first, '02/01/2025');
      await tester.enterText(dateFields.last, '02/01/2025');
      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pumpAndSettle();
      expect(find.text('Coca-Cola'), findsOneWidget);
      expect(find.text('Bánh gạo'), findsNothing);
      await tester.tap(find.byTooltip('Xóa khoảng ngày'));
      await tester.pumpAndSettle();
      expect(find.text('Bánh gạo'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'bv001');
      await tester.pumpAndSettle();
      expect(find.text('Coca-Cola'), findsOneWidget);
      expect(find.text('Bánh gạo'), findsNothing);
      await tester.tap(find.text('Coca-Cola'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Giao bù hôm trước'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Thời điểm lưu: 01/03/2025 00:00'),
        findsOneWidget,
      );
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Xuất kho'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có giao dịch phù hợp.'), findsOneWidget);
      await tester.tap(find.text('Xóa bộ lọc'));
      await tester.pumpAndSettle();
      expect(find.text('Bánh gạo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
