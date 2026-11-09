import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stockease/models/product.dart';
import 'package:stockease/models/purchase_price.dart';
import 'package:stockease/screens/products/product_form_screen.dart';
import 'package:stockease/services/exchange_rate_service.dart';
import 'package:stockease/services/product_service.dart';
import 'package:stockease/theme/stock_theme.dart';

class CurrencyProducts extends Fake implements ProductService {
  PurchasePrice? saved;
  int? sellingPrice;
  int? initialQuantity;
  int calls = 0;
  @override
  Future<void> save({
    String? id,
    required String name,
    required String sku,
    required String category,
    required int price,
    required int minStock,
    required String unit,
    int? quantity,
    PurchasePrice? purchasePrice,
    String? barcode,
  }) async {
    calls++;
    saved = purchasePrice;
    sellingPrice = price;
    initialQuantity = quantity;
  }
}

Product legacy([PurchasePrice? price]) => Product.fromData('p', {
  'userId': 'owner',
  'name': 'Coca-Cola',
  'sku': 'BV001',
  'category': 'Đồ uống',
  'price': 15000,
  'quantity': 8,
  'minStock': 2,
  'unit': 'box',
  if (price != null) ...price.toData(),
});
http.Response fixture(num rate) => http.Response(
  jsonEncode({
    'date': '2025-01-02',
    'base': 'USD',
    'quote': 'VND',
    'rate': rate,
  }),
  200,
);

void main() {
  Future<void> mount(
    WidgetTester tester,
    CurrencyProducts products,
    ExchangeRateService rates, {
    Product? product,
    bool adding = false,
    Size size = const Size(450, 1500),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(rates.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: stockTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductFormScreen(
                    service: products,
                    product: adding ? null : (product ?? legacy()),
                    exchangeRates: rates,
                  ),
                ),
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
  }

  Future<void> visible(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        180,
        scrollable: find
            .descendant(
              of: find.byType(ProductFormScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
  Future<void> expand(WidgetTester tester) async {
    await visible(tester, find.text('Giá nhập (Purchase Price)'));
    await tester.tap(find.text('Giá nhập (Purchase Price)'));
    await tester.pumpAndSettle();
  }

  Future<void> currency(WidgetTester tester, String value) async {
    await visible(tester, find.byKey(const ValueKey('purchaseCurrency')));
    await tester.tap(find.byKey(const ValueKey('purchaseCurrency')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(value).last);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await visible(tester, find.text('Lưu sản phẩm'));
    await tester.tap(find.text('Lưu sản phẩm'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'USD fetches once, recalculates locally, refreshes and saves separate purchase price',
    (tester) async {
      final products = CurrencyProducts();
      var requests = 0;
      final rates = ExchangeRateService(
        client: MockClient(
          (_) async => fixture(++requests == 1 ? 100.25 : 100.75),
        ),
      );
      await mount(tester, products, rates);
      await expand(tester);
      await currency(tester, 'USD');
      await tester.pumpAndSettle();
      expect(requests, 1);
      await tester.enterText(find.byKey(const ValueKey('purchaseAmount')), '2');
      await tester.pumpAndSettle();
      expect(find.text('Giá nhập quy đổi: 201 ₫'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('purchaseAmount')), '3');
      await tester.pumpAndSettle();
      expect(find.text('Giá nhập quy đổi: 301 ₫'), findsOneWidget);
      expect(requests, 1);
      await visible(tester, find.text('Làm mới tỷ giá'));
      await tester.tap(find.text('Làm mới tỷ giá'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.text('Giá nhập quy đổi: 302 ₫'), findsOneWidget);
      await save(tester);
      expect(find.text('Xác nhận giá nhập'), findsOneWidget);
      await tester.tap(find.text('Xác nhận lưu'));
      await tester.pumpAndSettle();
      expect(products.saved!.vnd, 302);
      expect(products.saved!.original, 3);
      expect(products.saved!.rate, 100.75);
      expect(products.saved!.rateDate, '2025-01-02');
      expect(products.sellingPrice, 15000);
      expect(products.initialQuantity, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new VND product saves without API and rejects empty or negative purchase',
    (tester) async {
      final products = CurrencyProducts();
      var requests = 0;
      final rates = ExchangeRateService(
        client: MockClient((_) async {
          requests++;
          return fixture(1);
        }),
      );
      await mount(tester, products, rates, adding: true);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên sản phẩm'),
        'Hàng mới',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'SKU'),
        'NEW01',
      );
      await expand(tester);
      for (final invalid in ['', '-1']) {
        await tester.enterText(
          find.byKey(const ValueKey('purchaseAmount')),
          invalid,
        );
        await tester.pumpAndSettle();
        await visible(tester, find.text('Lưu sản phẩm'));
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Lưu sản phẩm'),
              )
              .onPressed,
          isNull,
        );
        await visible(tester, find.byKey(const ValueKey('purchaseAmount')));
      }
      await tester.enterText(
        find.byKey(const ValueKey('purchaseAmount')),
        '12500',
      );
      await tester.pumpAndSettle();
      await save(tester);
      await tester.tap(find.text('Xác nhận lưu'));
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(products.saved!.vnd, 12500);
      expect(products.saved!.rate, 1);
      expect(products.saved!.rateDate, isNull);
      expect(products.sellingPrice, 0);
      expect(products.initialQuantity, 0);
    },
  );

  testWidgets(
    'API failure permits retry or switching to VND on a small screen',
    (tester) async {
      final products = CurrencyProducts();
      var requests = 0;
      final rates = ExchangeRateService(
        client: MockClient((_) async {
          requests++;
          throw http.ClientException('offline');
        }),
      );
      await mount(tester, products, rates, size: const Size(360, 800));
      await expand(tester);
      await currency(tester, 'USD');
      await tester.pumpAndSettle();
      await visible(tester, find.text('Thử lại tỷ giá'));
      expect(find.textContaining('Không thể kết nối API'), findsOneWidget);
      await tester.tap(find.text('Thử lại tỷ giá'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      await visible(tester, find.text('Lưu sản phẩm'));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Lưu sản phẩm'),
            )
            .onPressed,
        isNull,
      );
      await currency(tester, 'VND');
      await tester.pumpAndSettle();
      await visible(tester, find.byKey(const ValueKey('purchaseAmount')));
      await tester.enterText(
        find.byKey(const ValueKey('purchaseAmount')),
        '9000',
      );
      await tester.pumpAndSettle();
      await save(tester);
      await tester.tap(find.text('Xác nhận lưu'));
      await tester.pumpAndSettle();
      expect(products.saved!.vnd, 9000);
      expect(products.saved!.currency, 'VND');
      expect(requests, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'edit restores saved USD data and keeps its historical rate without fetching',
    (tester) async {
      const purchase = PurchasePrice(
        original: 2,
        currency: 'USD',
        rate: 100.25,
        vnd: 201,
        rateDate: '2025-01-02',
      );
      var requests = 0;
      final products = CurrencyProducts();
      final rates = ExchangeRateService(
        client: MockClient((_) async {
          requests++;
          return fixture(999);
        }),
      );
      await mount(tester, products, rates, product: legacy(purchase));
      expect(find.text('Giá nhập quy đổi: 201 ₫'), findsOneWidget);
      expect(find.text('Ngày tỷ giá: 2025-01-02'), findsOneWidget);
      await save(tester);
      await tester.tap(find.text('Xác nhận lưu'));
      await tester.pumpAndSettle();
      expect(products.saved!.toData(), purchase.toData());
      expect(requests, 0);
    },
  );

  testWidgets('legacy edit keeps purchase fields absent if left blank', (
    tester,
  ) async {
    final products = CurrencyProducts();
    final rates = ExchangeRateService(
      client: MockClient((_) async => throw StateError('VND must not fetch')),
    );
    await mount(tester, products, rates);
    await save(tester);
    expect(products.calls, 1);
    expect(products.saved, isNull);
    expect(products.sellingPrice, 15000);
    expect(products.initialQuantity, isNull);
  });

  testWidgets(
    'late API response after choosing VND cannot replace the selected currency',
    (tester) async {
      final products = CurrencyProducts();
      final response = Completer<http.Response>();
      final rates = ExchangeRateService(
        client: MockClient((_) => response.future),
      );
      await mount(tester, products, rates);
      await expand(tester);
      await currency(tester, 'USD');
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // Close the dropdown animations without waiting on the loading indicator.
      await visible(tester, find.byKey(const ValueKey('purchaseCurrency')));
      await tester.tap(find.byKey(const ValueKey('purchaseCurrency')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('VND').last);
      await tester.pump();
      response.complete(fixture(100.25));
      await tester.pumpAndSettle();
      await visible(tester, find.byKey(const ValueKey('purchaseAmount')));
      await tester.enterText(
        find.byKey(const ValueKey('purchaseAmount')),
        '10',
      );
      await tester.pumpAndSettle();
      expect(find.text('Giá nhập quy đổi: 10 ₫'), findsOneWidget);
      expect(find.textContaining('1 USD ='), findsNothing);
    },
  );
}
