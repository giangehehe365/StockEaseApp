import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../models/product_list_query.dart';
import '../../models/product_options.dart';
import '../../models/stock_movement.dart';
import '../../services/inventory_service.dart';
import '../../services/product_service.dart';
import '../../widgets/confirm_product_delete.dart';
import '../../widgets/product_card.dart';
import '../inventory/stock_movement_screen.dart';
import 'product_details_screen.dart';
import 'product_form_screen.dart';
import '../barcode/barcode_lookup_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({
    super.key,
    required this.service,
    required this.inventory,
    this.products,
    required this.onAdd,
    this.title,
    this.initialStockFilter = ProductStockFilter.all,
    this.initialSort = ProductSort.newest,
    this.showStockSummary = false,
  });

  final ProductService service;
  final InventoryService inventory;

  /// Embedded lists receive the shell's live data; routes load the same service.
  final List<Product>? products;
  final VoidCallback onAdd;
  final String? title;
  final ProductStockFilter initialStockFilter;
  final ProductSort initialSort;
  final bool showStockSummary;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _search = TextEditingController();
  String _category = '';
  late ProductStockFilter _stock = widget.initialStockFilter;
  late ProductSort _sort = widget.initialSort;
  late var _products = widget.products == null
      ? widget.service.watchProducts()
      : null;
  bool _deleting = false;
  bool _scanning = false;

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    final product = await pickProductByBarcode(context, widget.service);
    if (!mounted) return;
    setState(() => _scanning = false);
    if (product == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(
          service: widget.service,
          inventory: widget.inventory,
          productId: product.id,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _search.clear();
      _category = '';
      _stock = ProductStockFilter.all;
      _sort = ProductSort.newest;
    });
  }

  void _showFilters(Set<String> categories) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bộ lọc sản phẩm',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Danh mục'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Tất cả danh mục'),
                  ),
                  for (final category in categories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: (value) => setState(() => _category = value ?? ''),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ProductStockFilter>(
                initialValue: _stock,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Trạng thái tồn kho',
                ),
                items: [
                  for (final option in ProductStockFilter.values)
                    DropdownMenuItem(value: option, child: Text(option.label)),
                ],
                onChanged: (value) =>
                    setState(() => _stock = value ?? ProductStockFilter.all),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Xong'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(Product product) async {
    if (_deleting) return;
    setState(() => _deleting = true);
    try {
      if (!await confirmProductDelete(context, product.name) || !mounted) {
        return;
      }
      await widget.service.archive(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã xóa sản phẩm.')));
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(productErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.products != null
        ? _buildList(context, widget.products!)
        : StreamBuilder<List<Product>>(
            stream: _products,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: SingleChildScrollView(
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
                            _products = widget.service.watchProducts();
                          }),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildList(context, snapshot.data!);
            },
          );
    return widget.title == null
        ? body
        : Scaffold(
            appBar: AppBar(title: Text(widget.title!)),
            body: SafeArea(child: body),
          );
  }

  Widget _buildList(BuildContext context, List<Product> products) {
    final visible = queryProducts(
      products,
      search: _search.text,
      category: _category,
      stock: _stock,
      sort: _sort,
    );
    final categories = {
      ...productCategories,
      ...products.map((p) => p.category),
      if (_category.isNotEmpty) _category,
    };
    final activeFilters = [
      if (_category.isNotEmpty) _category,
      if (_stock != ProductStockFilter.all) _stock.label,
    ];
    final canClear =
        _search.text.isNotEmpty ||
        activeFilters.isNotEmpty ||
        _sort != ProductSort.newest;
    final header = <Widget>[
      if (widget.title != null) ...[
        Text(
          'Tổng ${products.length} sản phẩm',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
      ],
      if (widget.showStockSummary) ...[
        Card(
          child: ListTile(
            leading: const Icon(Icons.stacked_bar_chart),
            title: const Text('Tổng số lượng tồn'),
            subtitle: Text(
              '${visible.fold<int>(0, (total, product) => total + product.quantity)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      TextField(
        controller: _search,
        decoration: InputDecoration(
          labelText: 'Tìm tên hoặc SKU',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Xóa từ khóa',
                  onPressed: () => setState(_search.clear),
                  icon: const Icon(Icons.close),
                ),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _scanning ? null : _scan,
        icon: const Icon(Icons.barcode_reader),
        label: const Text('Scan Barcode'),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () => _showFilters(categories),
            icon: const Icon(Icons.tune),
            label: Text(
              activeFilters.isEmpty
                  ? 'Bộ lọc'
                  : 'Bộ lọc (${activeFilters.length})',
            ),
          ),
          for (final label in activeFilters) Chip(label: Text(label)),
          if (canClear)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Xóa bộ lọc'),
            ),
        ],
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<ProductSort>(
        key: ValueKey(_sort),
        initialValue: _sort,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Sắp xếp'),
        items: [
          for (final option in ProductSort.values)
            DropdownMenuItem(value: option, child: Text(option.label)),
        ],
        onChanged: (value) =>
            setState(() => _sort = value ?? ProductSort.newest),
      ),
      const SizedBox(height: 12),
      Text(
        'Hiển thị ${visible.length} sản phẩm',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 16),
      if (visible.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 40),
                const SizedBox(height: 12),
                Text(
                  products.isEmpty
                      ? 'Kho chưa có sản phẩm'
                      : 'Không tìm thấy sản phẩm',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  products.isEmpty
                      ? 'Thêm sản phẩm đầu tiên để quản lý kho.'
                      : 'Thử đổi từ khóa hoặc xóa bộ lọc.',
                  textAlign: TextAlign.center,
                ),
                if (products.isEmpty)
                  TextButton(
                    onPressed: widget.onAdd,
                    child: const Text('Thêm sản phẩm'),
                  ),
              ],
            ),
          ),
        ),
    ];
    return ListView.builder(
      key: const PageStorageKey('products'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: header.length + visible.length,
      itemBuilder: (context, index) {
        if (index < header.length) return header[index];
        final product = visible[index - header.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ProductCard(
            product: product,
            onStockIn: product.isLowStock || product.isOutOfStock
                ? () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => StockMovementScreen(
                        products: widget.service,
                        inventory: widget.inventory,
                        product: product,
                        type: StockMovementType.stockIn,
                      ),
                    ),
                  )
                : null,
            onOpen: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ProductDetailsScreen(
                  service: widget.service,
                  inventory: widget.inventory,
                  productId: product.id,
                ),
              ),
            ),
            onEdit: _deleting
                ? null
                : () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ProductFormScreen(
                        service: widget.service,
                        product: product,
                      ),
                    ),
                  ),
            onDelete: _deleting ? null : () => _delete(product),
          ),
        );
      },
    );
  }
}
