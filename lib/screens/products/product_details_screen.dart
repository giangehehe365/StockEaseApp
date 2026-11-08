import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../models/stock_movement.dart';
import '../../models/purchase_price.dart';
import '../../services/inventory_service.dart';
import '../../services/product_service.dart';
import '../../widgets/confirm_product_delete.dart';
import '../../widgets/product_card.dart';
import '../inventory/inventory_history_screen.dart';
import '../inventory/stock_movement_screen.dart';
import 'product_form_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.service,
    required this.inventory,
    required this.productId,
  });

  final ProductService service;
  final InventoryService inventory;
  final String productId;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late Stream<Product?> _product = widget.service.watchProduct(
    widget.productId,
  );
  bool _deleting = false;
  late var _movements = widget.inventory.watchMovements(
    productId: widget.productId,
  );

  Future<void> _delete(Product product) async {
    final confirmed = await confirmProductDelete(context, product.name);
    if (!mounted || confirmed != true || _deleting) return;
    setState(() => _deleting = true);
    try {
      await widget.service.archive(product.id);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(productErrorMessage(error))));
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Đã xóa sản phẩm.')));
  }

  String _date(DateTime? date) {
    if (date == null) return 'Đang đồng bộ';
    return MaterialLocalizations.of(context).formatMediumDate(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_deleting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Chi tiết sản phẩm')),
        body: SafeArea(
          child: StreamBuilder<Product?>(
            stream: _product,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          productErrorMessage(snapshot.error!),
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _product = widget.service.watchProduct(
                              widget.productId,
                            );
                          }),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting ||
                  _deleting) {
                return const Center(child: CircularProgressIndicator());
              }
              final product = snapshot.data;
              if (product == null) {
                return const Center(
                  child: Text('Sản phẩm không còn trong kho.'),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(product: product),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        _ProductField('SKU', product.sku),
                        _ProductField('Danh mục', product.category),
                        _ProductField('Giá bán', product.formattedPrice),
                        _ProductField(
                          'Giá nhập',
                          product.purchasePrice == null
                              ? 'Chưa khai báo'
                              : formatVnd(product.purchasePrice!.vnd),
                        ),
                        if (product.purchasePrice case final purchase?) ...[
                          _ProductField(
                            'Giá nhập gốc',
                            '${purchase.original} ${purchase.currency}',
                          ),
                          if (purchase.currency == 'USD') ...[
                            _ProductField(
                              'Tỷ giá đã dùng',
                              '1 USD = ${purchase.rate} VND',
                            ),
                            _ProductField('Ngày tỷ giá', purchase.rateDate!),
                          ],
                        ],
                        _ProductField('Số lượng tồn', '${product.quantity}'),
                        _ProductField(
                          'Mức tồn tối thiểu',
                          '${product.minStock}',
                        ),
                        _ProductField('Đơn vị', product.unit),
                        _ProductField('Ngày tạo', _date(product.createdAt)),
                        _ProductField('Cập nhật', _date(product.updatedAt)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Giao dịch kho gần đây',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<StockMovement>>(
                    stream: _movements,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Column(
                          children: [
                            Text(productErrorMessage(snapshot.error!)),
                            TextButton(
                              onPressed: () => setState(() {
                                _movements = widget.inventory.watchMovements(
                                  productId: widget.productId,
                                );
                              }),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        );
                      }
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator();
                      }
                      final recent = queryMovements(snapshot.data!).take(3);
                      if (recent.isEmpty) {
                        return const Text(
                          'Chưa có giao dịch cho sản phẩm này.',
                        );
                      }
                      return Column(
                        children: [
                          for (final movement in recent)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: MovementCard(movement),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in StockMovementType.values)
                        FilledButton.tonalIcon(
                          onPressed: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => StockMovementScreen(
                                products: widget.service,
                                inventory: widget.inventory,
                                product: product,
                                type: type,
                              ),
                            ),
                          ),
                          icon: Icon(
                            type.isIn
                                ? Icons.move_to_inbox_outlined
                                : Icons.outbox_outlined,
                          ),
                          label: Text(type.label),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => InventoryHistoryScreen(
                              inventory: widget.inventory,
                              productId: product.id,
                              productName: product.name,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.history),
                        label: const Text('Lịch sử sản phẩm'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => ProductFormScreen(
                              service: widget.service,
                              product: product,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Chỉnh sửa'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _delete(product),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Xóa'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProductField extends StatelessWidget {
  const _ProductField(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) =>
      ListTile(title: Text(label), subtitle: Text(value));
}
