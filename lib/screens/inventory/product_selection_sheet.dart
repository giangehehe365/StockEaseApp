import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../models/stock_movement.dart';
import '../../theme/stock_theme.dart';

/// Receives the current user's active products from ProductService.
class ProductSelectionSheet extends StatefulWidget {
  const ProductSelectionSheet({
    super.key,
    required this.products,
    required this.type,
  });

  final List<Product> products;
  final StockMovementType type;

  @override
  State<ProductSelectionSheet> createState() => _ProductSelectionSheetState();
}

class _ProductSelectionSheetState extends State<ProductSelectionSheet> {
  final _search = TextEditingController();
  bool _inStockOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _search.text.trim().toLowerCase();
    final products = widget.products.where((product) {
      return (!_inStockOnly || product.quantity > 0) &&
          (product.name.toLowerCase().contains(keyword) ||
              product.sku.toLowerCase().contains(keyword));
    }).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn sản phẩm để ${widget.type.label.toLowerCase()}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Tìm tên sản phẩm hoặc SKU',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xóa từ khóa',
                            onPressed: () => setState(_search.clear),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${products.length} sản phẩm'),
                    if (!widget.type.isIn)
                      FilterChip(
                        label: const Text('Chỉ còn hàng'),
                        selected: _inStockOnly,
                        onSelected: (value) =>
                            setState(() => _inStockOnly = value),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          if (products.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('Không tìm thấy sản phẩm')),
            )
          else
            SliverList.separated(
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.inventory_2_outlined,
                      color: widget.type.isIn ? stockSuccess : stockError,
                    ),
                    title: Text(product.name),
                    subtitle: Text(
                      '${product.sku} · ${product.unit}\n'
                      'Tồn hiện tại: ${product.quantity} ${product.unit}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, product),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
