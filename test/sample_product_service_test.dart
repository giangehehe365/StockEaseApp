import 'package:flutter_test/flutter_test.dart';
import 'package:stockease/services/product_service.dart';
import 'package:stockease/services/sample_product_service.dart';

class SampleProductRepository extends Fake implements ProductService {
  final names = {'BV001': 'Sản phẩm thật'};
  final quantities = <(int, int)>[];
  final categories = <String>{};

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
  }) async {
    if (names.containsKey(sku)) throw const DuplicateSkuException();
    names[sku] = name;
    categories.add(category);
    quantities.add((quantity!, minStock));
  }
}

void main() {
  test('sample import skips existing SKUs and can be retried', () async {
    final products = SampleProductRepository();
    expect(await seedSampleProducts(products), (
      added: 19,
      existing: 1,
      failed: 0,
    ));
    expect(products.names['BV001'], 'Sản phẩm thật');
    expect(products.categories, hasLength(6));
    expect(products.quantities.where((item) => item.$1 == 0), hasLength(2));
    expect(
      products.quantities.where((item) => item.$1 > 0 && item.$1 <= item.$2),
      hasLength(5),
    );
    expect(await seedSampleProducts(products), (
      added: 0,
      existing: 20,
      failed: 0,
    ));
  });
}
