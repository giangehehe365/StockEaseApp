import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockease/models/product.dart';
import 'package:stockease/models/stock_movement.dart';
import 'package:stockease/models/product_list_query.dart';
import 'package:stockease/screens/products/product_list_screen.dart';
import 'package:stockease/services/inventory_service.dart';
import 'package:stockease/services/product_service.dart';

Product product(
  String id,
  String name,
  String sku, {
  String category = 'Đồ uống',
  int price = 10000,
  int quantity = 8,
  int? created,
}) => Product.fromData(id, {
  'userId': 'owner',
  'name': name,
  'sku': sku,
  'category': category,
  'price': price,
  'quantity': quantity,
  'minStock': 5,
  'unit': 'piece',
  'createdAt': created == null ? null : Timestamp(created, 0),
});

class ListProductService extends Fake implements ProductService {
  ListProductService(this.product);

  final Product product;

  @override
  Stream<Product?> watchProduct(String id) => Stream.value(product);
}

class UnusedInventory extends Fake implements InventoryService {
  @override
  Stream<List<StockMovement>> watchMovements({String? productId}) =>
      Stream.value([]);
}

void main() {
  final coca = product('a', 'Coca-Cola', 'BV001', created: 100);
  final cocaZero = product(
    'b',
    'Coca-Cola Zero',
    'BV002',
    price: 14000,
    quantity: 0,
    created: 200,
  );
  final cocaSnack = product(
    'c',
    'Bánh Coca',
    'SN001',
    category: 'Đồ ăn vặt',
    price: 9000,
    quantity: 4,
    created: 300,
  );
  final low = product(
    'd',
    'Coca-Cola Chai',
    'BV003',
    price: 12000,
    quantity: 5,
  );
  final products = [low, cocaZero, coca, cocaSnack];

  test(
    'partial search matches names and SKUs regardless of case or outer spaces',
    () {
      expect(queryProducts(products, search: '  cOcA-CoLa  '), [
        cocaZero,
        coca,
        low,
      ]);
      expect(queryProducts(products, search: ' bv002 '), [cocaZero]);
      expect(queryProducts(products, search: 'không có'), isEmpty);
      expect(queryProducts([]), isEmpty);
    },
  );

  test(
    'category and stock filters compose and keep zero separate from low stock',
    () {
      expect(queryProducts(products, category: 'Đồ ăn vặt'), [cocaSnack]);
      expect(queryProducts(products, stock: ProductStockFilter.outOfStock), [
        cocaZero,
      ]);
      expect(queryProducts(products, stock: ProductStockFilter.lowStock), [
        cocaSnack,
        low,
      ]);
      expect(queryProducts(products, stock: ProductStockFilter.inStock), [
        coca,
      ]);
      expect(
        queryProducts(
          products,
          search: 'coca',
          category: 'Đồ uống',
          stock: ProductStockFilter.lowStock,
          sort: ProductSort.quantityAscending,
        ),
        [low],
      );
      final updated = product('d', 'Coca-Cola Chai', 'BV003', quantity: 0);
      expect(
        queryProducts([updated], stock: ProductStockFilter.lowStock),
        isEmpty,
      );
      expect(queryProducts([updated], stock: ProductStockFilter.outOfStock), [
        updated,
      ]);
    },
  );

  test('sorts by all seven options without mutating the input', () {
    final expected = {
      ProductSort.newest: [cocaSnack, cocaZero, coca, low],
      ProductSort.nameAscending: [cocaSnack, coca, low, cocaZero],
      ProductSort.nameDescending: [cocaZero, low, coca, cocaSnack],
      ProductSort.priceAscending: [cocaSnack, coca, low, cocaZero],
      ProductSort.priceDescending: [cocaZero, low, coca, cocaSnack],
      ProductSort.quantityAscending: [cocaZero, cocaSnack, low, coca],
      ProductSort.quantityDescending: [coca, low, cocaSnack, cocaZero],
    };
    for (final entry in expected.entries) {
      expect(queryProducts(products, sort: entry.key), entry.value);
    }
    expect(products, [low, cocaZero, coca, cocaSnack]);
  });

  testWidgets(
    'clears search and all filters and preserves search after details',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductListScreen(
              service: ListProductService(cocaZero),
              inventory: UnusedInventory(),
              products: products,
              onAdd: () {},
            ),
          ),
        ),
      );
      final search = find.byType(TextField);
      await tester.enterText(search, 'BV002');
      await tester.pumpAndSettle();
      expect(find.text('Hiển thị 1 sản phẩm'), findsOneWidget);
      await tester.tap(find.text('Coca-Cola Zero'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết sản phẩm'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('BV002'), findsOneWidget);
      await tester.tap(find.byTooltip('Xóa từ khóa'));
      await tester.pumpAndSettle();
      expect(find.text('Hiển thị 4 sản phẩm'), findsOneWidget);

      await tester.tap(find.text('Bộ lọc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tất cả danh mục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồ uống').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tất cả trạng thái'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hết hàng').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();
      expect(find.text('Hiển thị 1 sản phẩm'), findsOneWidget);
      await tester.tap(find.text('Mới nhất'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giá tăng dần').last);
      await tester.pumpAndSettle();
      await tester.enterText(search, 'không có');
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy sản phẩm'), findsOneWidget);
      await tester.tap(find.text('Xóa bộ lọc'));
      await tester.pumpAndSettle();
      expect(find.text('Hiển thị 4 sản phẩm'), findsOneWidget);
      expect(find.text('Mới nhất'), findsOneWidget);
      expect(find.text('Bộ lọc'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
