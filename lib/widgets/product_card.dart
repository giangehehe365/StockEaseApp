import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/stock_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final (label, color) = product.isOutOfStock
        ? ('Hết hàng', stockError)
        : product.isLowStock
        ? ('Tồn kho thấp', stockWarning)
        : ('Còn hàng', stockSuccess);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? .2 : .13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: dark ? Colors.white : stockNavy,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onOpen,
    this.onEdit,
    this.onDelete,
    this.onStockIn,
  });

  final Product product;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onStockIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('${product.sku} • ${product.category}'),
                    if (product.isLowStock || product.isOutOfStock)
                      Text(
                        'Mức tồn tối thiểu: ${product.minStock} ${product.unit}',
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(product.formattedPrice),
                        Text('Tồn ${product.quantity} ${product.unit}'),
                        StatusBadge(product: product),
                      ],
                    ),
                    if (onStockIn != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: onStockIn,
                        icon: const Icon(Icons.move_to_inbox_outlined),
                        label: const Text('Nhập thêm hàng'),
                      ),
                    ],
                  ],
                ),
              ),
              if (onEdit != null && onDelete != null)
                PopupMenuButton<bool>(
                  tooltip: 'Thao tác sản phẩm',
                  onSelected: (edit) => edit ? onEdit!() : onDelete!(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: true, child: Text('Chỉnh sửa')),
                    PopupMenuItem(value: false, child: Text('Xóa')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
