import 'product.dart';

enum ProductStockFilter {
  all('Tất cả trạng thái'),
  inStock('Còn hàng'),
  lowStock('Tồn kho thấp'),
  outOfStock('Hết hàng');

  const ProductStockFilter(this.label);

  final String label;

  bool matches(Product product) => switch (this) {
    all => true,
    inStock => product.quantity > product.minStock,
    lowStock => product.isLowStock,
    outOfStock => product.isOutOfStock,
  };
}

enum ProductSort {
  newest('Mới nhất'),
  nameAscending('Tên A–Z'),
  nameDescending('Tên Z–A'),
  priceAscending('Giá tăng dần'),
  priceDescending('Giá giảm dần'),
  quantityAscending('Số lượng tăng dần'),
  quantityDescending('Số lượng giảm dần');

  const ProductSort(this.label);

  final String label;

  int compare(Product a, Product b) {
    final result = switch (this) {
      newest => _compareNewest(a, b),
      nameAscending => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      nameDescending => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
      priceAscending => a.price.compareTo(b.price),
      priceDescending => b.price.compareTo(a.price),
      quantityAscending => a.quantity.compareTo(b.quantity),
      quantityDescending => b.quantity.compareTo(a.quantity),
    };
    return result == 0 ? a.id.compareTo(b.id) : result;
  }

  static int _compareNewest(Product a, Product b) {
    final first = a.createdAt;
    final second = b.createdAt;
    if (first == null) return second == null ? 0 : 1;
    if (second == null) return -1;
    return second.compareTo(first);
  }
}

List<Product> queryProducts(
  Iterable<Product> products, {
  String search = '',
  String category = '',
  ProductStockFilter stock = ProductStockFilter.all,
  ProductSort sort = ProductSort.newest,
}) {
  final keyword = search.trim().toLowerCase();
  return products.where((product) {
    return (category.isEmpty || product.category == category) &&
        stock.matches(product) &&
        (keyword.isEmpty ||
            product.name.toLowerCase().contains(keyword) ||
            product.sku.toLowerCase().contains(keyword));
  }).toList()..sort(sort.compare);
}
