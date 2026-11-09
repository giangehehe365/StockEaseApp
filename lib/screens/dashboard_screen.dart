import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/product_list_query.dart';
import '../models/stock_movement.dart';
import '../services/product_service.dart';
import '../theme/stock_theme.dart';
import '../widgets/product_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.name,
    required this.storeName,
    required this.products,
    required this.onAdd,
    required this.onProducts,
    required this.onOpen,
    required this.movements,
    required this.onRetryMovements,
    this.onStockIn,
    this.onStockOut,
    this.onHistory,
    this.productStatus,
    this.onProductStats,
    this.onMovementStats,
    this.onRestock,
    this.onReports,
    this.onScanBarcode,
  });

  final String name;
  final String storeName;
  final List<Product> products;
  final VoidCallback? onAdd;
  final VoidCallback onProducts;
  final ValueChanged<Product> onOpen;
  final Widget? productStatus;
  final Stream<List<StockMovement>>? movements;
  final VoidCallback onRetryMovements;
  final VoidCallback? onStockIn;
  final VoidCallback? onStockOut;
  final VoidCallback? onHistory;
  final void Function(ProductStockFilter filter, ProductSort sort)?
  onProductStats;
  final ValueChanged<StockMovementType>? onMovementStats;
  final ValueChanged<Product>? onRestock;
  final VoidCallback? onReports;
  final VoidCallback? onScanBarcode;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<StockMovement>>(
    stream: movements,
    builder: (context, snapshot) => _content(context, snapshot),
  );

  Widget _content(
    BuildContext context,
    AsyncSnapshot<List<StockMovement>> movementSnapshot,
  ) {
    final restock =
        products
            .where((product) => product.isLowStock || product.isOutOfStock)
            .toList()
          ..sort((a, b) => a.quantity.compareTo(b.quantity));
    final outOfStock = restock.where((product) => product.isOutOfStock).length;
    final quantity = products.fold<int>(
      0,
      (sum, product) => sum + product.quantity,
    );
    final colors = Theme.of(context).colorScheme;
    return ListView(
      key: const PageStorageKey('dashboard'),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: colors.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
                const SizedBox(height: 8),
                Text(
                  'Xin chào, $name',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm sản phẩm'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Thao tác nhanh', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.inventory_2_outlined),
              label: const Text('Sản phẩm'),
              onPressed: onProducts,
            ),
            ActionChip(
              avatar: const Icon(
                Icons.move_to_inbox_outlined,
                color: stockSuccess,
              ),
              label: const Text('Nhập kho'),
              onPressed: onStockIn,
            ),
            ActionChip(
              avatar: const Icon(Icons.outbox_outlined, color: stockError),
              label: const Text('Xuất kho'),
              onPressed: onStockOut,
            ),
            ActionChip(
              avatar: const Icon(Icons.history),
              label: const Text('Lịch sử kho'),
              onPressed: onHistory,
            ),
            ActionChip(
              avatar: const Icon(Icons.barcode_reader),
              label: const Text('Scan Barcode'),
              onPressed: onScanBarcode,
            ),
            ActionChip(
              avatar: const Icon(Icons.assessment_outlined),
              label: const Text('Báo cáo kho'),
              onPressed: onReports,
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (productStatus case final status?)
          status
        else ...[
          StatCard(
            Icons.inventory_2_outlined,
            'Tổng sản phẩm',
            products.length,
            stockBlue,
            onTap: onProductStats == null
                ? null
                : () => onProductStats!(
                    ProductStockFilter.all,
                    ProductSort.newest,
                  ),
          ),
          const SizedBox(height: 8),
          StatCard(
            Icons.stacked_bar_chart,
            'Tổng số lượng tồn',
            quantity,
            stockSuccess,
            onTap: onProductStats == null
                ? null
                : () => onProductStats!(
                    ProductStockFilter.all,
                    ProductSort.quantityDescending,
                  ),
          ),
          const SizedBox(height: 8),
          StatCard(
            Icons.warning_amber_outlined,
            'Tồn kho thấp',
            restock.length - outOfStock,
            stockWarning,
            onTap: onProductStats == null
                ? null
                : () => onProductStats!(
                    ProductStockFilter.lowStock,
                    ProductSort.newest,
                  ),
          ),
          const SizedBox(height: 8),
          StatCard(
            Icons.remove_shopping_cart_outlined,
            'Hết hàng',
            outOfStock,
            stockError,
            onTap: onProductStats == null
                ? null
                : () => onProductStats!(
                    ProductStockFilter.outOfStock,
                    ProductSort.newest,
                  ),
          ),
        ],
        if (movements != null) ...[
          const SizedBox(height: 24),
          Text('Giao dịch kho', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final snapshot = movementSnapshot;
              if (snapshot.hasError) {
                return Card(
                  child: ListTile(
                    title: Text(productErrorMessage(snapshot.error!)),
                    subtitle: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onRetryMovements,
                        child: const Text('Thử lại'),
                      ),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final data = snapshot.data!;
              final inbound = data
                  .where((movement) => movement.type.isIn)
                  .length;
              return Column(
                children: [
                  StatCard(
                    Icons.move_to_inbox_outlined,
                    'Giao dịch nhập kho',
                    inbound,
                    stockSuccess,
                    onTap: onMovementStats == null
                        ? null
                        : () => onMovementStats!(StockMovementType.stockIn),
                  ),
                  const SizedBox(height: 8),
                  StatCard(
                    Icons.outbox_outlined,
                    'Giao dịch xuất kho',
                    data.length - inbound,
                    stockError,
                    onTap: onMovementStats == null
                        ? null
                        : () => onMovementStats!(StockMovementType.stockOut),
                  ),
                ],
              );
            },
          ),
        ],
        if (productStatus == null) ...[
          const SizedBox(height: 24),
          Text(
            'Cần bổ sung hàng',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (restock.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Hiện chưa có sản phẩm cần bổ sung.'),
              ),
            ),
          for (final product in restock)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ProductCard(
                product: product,
                onOpen: () => onOpen(product),
                onStockIn: onRestock == null ? null : () => onRestock!(product),
              ),
            ),
        ],
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard(
    this.icon,
    this.label,
    this.value,
    this.color, {
    super.key,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      onTap: onTap,
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .16),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        child: Icon(icon),
      ),
      title: Text(label),
      subtitle: Text(
        '$value',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    ),
  );
}
