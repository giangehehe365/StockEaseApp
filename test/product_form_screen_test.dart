import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockease/screens/products/product_form_screen.dart';
import 'package:stockease/services/product_service.dart';

class UnusedProductService extends Fake implements ProductService {}

void main() {
  testWidgets('form asks before leaving unsaved product changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProductFormScreen(service: UnusedProductService()),
                ),
              ),
              child: const Text('Mở form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở form'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Sản phẩm mới');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi?'), findsOneWidget);

    await tester.tap(find.text('Tiếp tục sửa'));
    await tester.pumpAndSettle();
    expect(find.text('Sản phẩm mới'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Mở form'), findsOneWidget);
  });
}
