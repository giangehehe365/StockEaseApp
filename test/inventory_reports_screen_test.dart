import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockease/models/product.dart';
import 'package:stockease/models/stock_movement.dart';
import 'package:stockease/screens/inventory/inventory_reports_screen.dart';
import 'package:stockease/services/product_service.dart';
import 'package:stockease/services/inventory_service.dart';
import 'package:stockease/services/inventory_report_calculator.dart';
import 'package:stockease/widgets/stock_movement_chart.dart';
import 'package:stockease/theme/stock_theme.dart';

class ReportProducts extends Fake implements ProductService {
  final controller = StreamController<List<Product>>.broadcast();
  int subscriptions = 0;
  @override
  Stream<List<Product>> watchProducts() {
    subscriptions++;
    return controller.stream.map((value) => value);
  }
}

class ReportInventory extends Fake implements InventoryService {
  final controller = StreamController<List<StockMovement>>.broadcast();
  @override
  Stream<List<StockMovement>> watchMovements({String? productId}) =>
      controller.stream.map((value) => value);
}

void main() {
  testWidgets(
    'loading and errors never appear as a fabricated zero report, retry and refresh recover',
    (tester) async {
      final products = ReportProducts();
      final inventory = ReportInventory();
      addTearDown(products.controller.close);
      addTearDown(inventory.controller.close);
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: stockTheme(Brightness.light),
          home: InventoryReportsScreen(
            userId: 'u',
            products: products,
            inventory: inventory,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      expect(find.text('Giá trị tồn kho'), findsNothing);
      products.controller.addError(const ProductException('Lỗi tải sản phẩm'));
      inventory.controller.add([]);
      await tester.pumpAndSettle();
      expect(find.text('Lỗi tải sản phẩm'), findsOneWidget);
      expect(find.text('Giá trị tồn kho'), findsNothing);
      await tester.ensureVisible(find.text('Thử lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thử lại'));
      await tester.pump();
      products.controller.add([]);
      await tester.pumpAndSettle();
      expect(products.subscriptions, 2);
      expect(find.text('Kho chưa có sản phẩm đang hoạt động.'), findsOneWidget);
      expect(find.text('Giá trị tồn kho'), findsOneWidget);
      expect(
        find.text('Chưa có giao dịch trong khoảng ngày đã chọn.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Làm mới báo cáo'));
      await tester.pump();
      products.controller.add([]);
      inventory.controller.addError(
        const ProductException('Lỗi tải giao dịch'),
      );
      await tester.pumpAndSettle();
      expect(products.subscriptions, 3);
      expect(find.text('Giá trị tồn kho'), findsOneWidget);
      expect(find.text('Lỗi tải giao dịch'), findsOneWidget);
      expect(find.text('Biến động ròng'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chart bar heights represent actual quantities and remain usable with large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final day = DateTime(2025, 1, 1);
      StockMovement movement(String id, int qty, String type, DateTime date) =>
          StockMovement.fromData(id, {
            'userId': 'u',
            'productId': 'p',
            'productName': 'Hàng',
            'type': type,
            'quantity': qty,
            'transactionDate': Timestamp.fromDate(date),
          });
      final report = const InventoryReportCalculator('u').movements([
        movement('in', 10, 'IN', day),
        movement('out', 5, 'OUT', DateTime(2025, 1, 2)),
      ], ReportDateRange(day, DateTime(2025, 1, 3)));
      await tester.pumpWidget(
        MaterialApp(
          theme: stockTheme(Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.8)),
                child: StockMovementChart(report: report),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bars = find.byType(MovementReportBar);
      expect(
        tester.widgetList<MovementReportBar>(bars).map((b) => b.quantity),
        [10, 0, 0, 5, 0, 0],
      );
      expect(tester.getSize(bars.at(0)).height, 180);
      expect(tester.getSize(bars.at(3)).height, 90);
      expect(find.text('01/01'), findsOneWidget);
      expect(find.text('Nhập kho'), findsOneWidget);
      expect(find.text('Xuất kho'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
