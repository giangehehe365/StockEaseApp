import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../models/product_list_query.dart';
import '../../models/purchase_price.dart';
import '../../models/stock_movement.dart';
import '../../services/inventory_report_calculator.dart';
import '../../services/inventory_service.dart';
import '../../services/product_service.dart';
import '../../theme/stock_theme.dart';
import '../../widgets/product_card.dart';
import '../../widgets/stock_movement_chart.dart';
import '../products/product_details_screen.dart';
import '../products/product_form_screen.dart';
import '../products/product_list_screen.dart';
import 'inventory_history_screen.dart';
import 'stock_movement_screen.dart';

class InventoryReportsScreen extends StatefulWidget {
  const InventoryReportsScreen({
    super.key,
    required this.userId,
    required this.products,
    required this.inventory,
  });
  final String userId;
  final ProductService products;
  final InventoryService inventory;
  @override
  State<InventoryReportsScreen> createState() => _InventoryReportsScreenState();
}

class _InventoryReportsScreenState extends State<InventoryReportsScreen> {
  late var _products = widget.products.watchProducts();
  late var _movements = widget.inventory.watchMovements();
  late final _calculator = InventoryReportCalculator(widget.userId);
  ReportPeriod _period = ReportPeriod.thisMonth;
  ReportDateRange _range = reportRange(ReportPeriod.thisMonth, DateTime.now());
  final _search = TextEditingController();
  String _category = '';
  InventoryReportSort _sort = InventoryReportSort.quantityDescending;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async => setState(() {
    _products = widget.products.watchProducts();
    _movements = widget.inventory.watchMovements();
  });

  Future<void> _selectPeriod(ReportPeriod period) async {
    if (period != ReportPeriod.custom) {
      setState(() {
        _period = period;
        _range = reportRange(period, DateTime.now());
      });
      return;
    }
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _range.start, end: _range.end),
      helpText: 'Khoảng ngày giao dịch',
    );
    if (range != null && mounted) {
      setState(() {
        _period = period;
        _range = ReportDateRange(range.start, range.end);
      });
    }
  }

  void _openProduct(Product product) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ProductDetailsScreen(
        service: widget.products,
        inventory: widget.inventory,
        productId: product.id,
      ),
    ),
  );

  void _stockIn(Product product) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => StockMovementScreen(
        products: widget.products,
        inventory: widget.inventory,
        product: product,
        type: StockMovementType.stockIn,
      ),
    ),
  );

  void _openProducts(ProductStockFilter filter, {bool quantity = false}) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ProductListScreen(
            service: widget.products,
            inventory: widget.inventory,
            title: filter == ProductStockFilter.all
                ? 'Tồn kho hiện tại'
                : filter.label,
            initialStockFilter: filter,
            initialSort: quantity
                ? ProductSort.quantityDescending
                : ProductSort.newest,
            showStockSummary: quantity,
            onAdd: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ProductFormScreen(service: widget.products),
              ),
            ),
          ),
        ),
      );

  void _openHistory([StockMovementType? type]) => Navigator.of(context)
      .push<void>(
        MaterialPageRoute(
          builder: (_) => InventoryHistoryScreen(
            inventory: widget.inventory,
            initialFilter: type,
            initialDateRange: DateTimeRange(
              start: _range.start,
              end: _range.end,
            ),
          ),
        ),
      );

  Widget _title(String text, {String? note}) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: Theme.of(context).textTheme.titleLarge),
        if (note != null) ...[const SizedBox(height: 4), Text(note)],
      ],
    ),
  );

  Widget _state<T>(AsyncSnapshot<T> snapshot, VoidCallback retry) {
    if (snapshot.hasError) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                productErrorMessage(snapshot.error!),
                textAlign: TextAlign.center,
              ),
              TextButton(onPressed: retry, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _overview(InventoryOverview data) => _metrics([
    _ReportMetric(
      title: 'Tổng sản phẩm',
      value: '${data.totalProducts}',
      color: stockBlue,
      onTap: () => _openProducts(ProductStockFilter.all),
    ),
    _ReportMetric(
      title: 'Tổng số lượng tồn',
      value: '${data.totalQuantity}',
      color: stockBlue,
      note: 'Cộng số lượng theo đơn vị riêng của từng sản phẩm.',
      onTap: () => _openProducts(ProductStockFilter.all, quantity: true),
    ),
    _ReportMetric(
      title: 'Giá trị tồn kho',
      value: formatInventoryValue(data.totalValue),
      color: stockSuccess,
      note:
          '${data.totalProducts - data.missingPurchasePrices}/${data.totalProducts} sản phẩm có giá nhập hợp lệ. '
          '${data.missingPurchasePrices} sản phẩm thiếu giá nhập được loại khỏi giá trị; không dùng giá bán.',
    ),
    _ReportMetric(
      title: 'Tồn thấp / Hết hàng',
      value: '${data.lowStock} / ${data.outOfStock}',
      color: stockWarning,
      note: 'Hai nhóm riêng biệt, không đếm trùng.',
      footer: Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: () => _openProducts(ProductStockFilter.lowStock),
            child: const Text('Xem tồn thấp'),
          ),
          TextButton(
            onPressed: () => _openProducts(ProductStockFilter.outOfStock),
            child: const Text('Xem hết hàng'),
          ),
        ],
      ),
    ),
  ]);

  Widget _metrics(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 520 ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );

  Widget _movementStats(StockMovementReport data) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _metrics([
        _ReportMetric(
          title: 'Tổng số lượng nhập',
          value: '${data.inQuantity}',
          color: stockSuccess,
          onTap: () => _openHistory(StockMovementType.stockIn),
        ),
        _ReportMetric(
          title: 'Tổng số lượng xuất',
          value: '${data.outQuantity}',
          color: stockError,
          onTap: () => _openHistory(StockMovementType.stockOut),
        ),
        _ReportMetric(
          title: 'Số giao dịch nhập',
          value: '${data.inTransactions}',
          color: stockSuccess,
          onTap: () => _openHistory(StockMovementType.stockIn),
        ),
        _ReportMetric(
          title: 'Số giao dịch xuất',
          value: '${data.outTransactions}',
          color: stockError,
          onTap: () => _openHistory(StockMovementType.stockOut),
        ),
        _ReportMetric(
          title: 'Biến động ròng',
          value: '${data.net >= 0 ? '+' : ''}${data.net}',
          color: stockBlue,
          note: 'Số lượng nhập − xuất trong kỳ; không phải tồn kho hiện tại.',
          onTap: () => _openHistory(),
        ),
      ]),
      if (data.missingDates > 0)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            '${data.missingDates} giao dịch chưa có ngày giao dịch hoặc ngày tạo, chưa thể đưa vào báo cáo theo thời gian.',
          ),
        ),
      const SizedBox(height: 16),
      StockMovementChart(report: data),
    ],
  );

  Widget _productFilters(InventoryOverview overview) {
    final categories =
        overview.products.map((product) => product.category).toSet().toList()
          ..sort();
    if (_category.isNotEmpty && !categories.contains(_category)) {
      categories.add(_category);
    }
    return Column(
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Tìm tên hoặc SKU trong báo cáo',
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
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _category,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Danh mục báo cáo'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Tất cả danh mục')),
            for (final category in categories)
              DropdownMenuItem(value: category, child: Text(category)),
          ],
          onChanged: (value) => setState(() => _category = value!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<InventoryReportSort>(
          initialValue: _sort,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sắp xếp báo cáo'),
          items: [
            for (final sort in InventoryReportSort.values)
              DropdownMenuItem(value: sort, child: Text(sort.label)),
          ],
          onChanged: (value) => setState(() => _sort = value!),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Inventory Reports'),
      actions: [
        IconButton(
          tooltip: 'Làm mới báo cáo',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: StreamBuilder<List<Product>>(
        stream: _products,
        builder: (context, products) => StreamBuilder<List<StockMovement>>(
          stream: _movements,
          builder: (context, movements) {
            final overview = products.hasData && !products.hasError
                ? _calculator.overview(products.data!)
                : null;
            final report = movements.hasData && !movements.hasError
                ? _calculator.movements(movements.data!, _range)
                : null;
            final visible = overview == null
                ? <Product>[]
                : _calculator.products(
                    overview,
                    search: _search.text,
                    category: _category,
                    sort: _sort,
                  );
            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _title('Khoảng ngày giao dịch'),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final period in ReportPeriod.values)
                                ChoiceChip(
                                  label: Text(period.label),
                                  selected: _period == period,
                                  onSelected: (_) => _selectPeriod(period),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _range.label,
                            key: const ValueKey('reportRange'),
                          ),
                          const Text(
                            'Theo ngày giờ địa phương. Bộ lọc này chỉ áp dụng cho giao dịch.',
                          ),
                          _title(
                            'Tổng quan tồn kho hiện tại',
                            note: 'Không thay đổi theo khoảng ngày giao dịch.',
                          ),
                          if (overview == null)
                            _state(
                              products,
                              () => setState(
                                () =>
                                    _products = widget.products.watchProducts(),
                              ),
                            )
                          else ...[
                            _overview(overview),
                            if (overview.products.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text(
                                  'Kho chưa có sản phẩm đang hoạt động.',
                                ),
                              ),
                          ],
                          _title(
                            'Nhập / xuất trong kỳ',
                            note: 'Số lượng hàng và số lần giao dịch là hai chỉ số riêng.',
                          ),
                          if (report == null)
                            _state(
                              movements,
                              () => setState(
                                () => _movements = widget.inventory
                                    .watchMovements(),
                              ),
                            )
                          else
                            _movementStats(report),
                          _title(
                            'Sản phẩm cần nhập thêm',
                            note: 'Đề xuất = max(0, mức tồn tối thiểu − tồn hiện tại). Chỉ để đạt ngưỡng, không phải dự báo.',
                          ),
                          if (overview != null && overview.restock.isEmpty)
                            const Text('Chưa có sản phẩm cần nhập thêm.'),
                        ],
                      ),
                    ),
                  ),
                  if (overview != null)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.separated(
                        itemCount: overview.restock.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final product = overview.restock[index];
                          return _ReportProduct(
                            product: product,
                            onOpen: () => _openProduct(product),
                            onStockIn: () => _stockIn(product),
                            restock: true,
                          );
                        },
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _title(
                            'Báo cáo tồn kho theo sản phẩm',
                            note: 'Dữ liệu tồn kho hiện tại, giá trị theo giá nhập VND đã lưu.',
                          ),
                          if (overview != null) ...[
                            _productFilters(overview),
                            Text(
                              'Hiển thị ${visible.length}/${overview.totalProducts} sản phẩm',
                            ),
                            const SizedBox(height: 12),
                            if (visible.isEmpty)
                              const Text('Không có sản phẩm phù hợp.'),
                          ] else
                            const Text(
                              'Chưa có dữ liệu sản phẩm để lập báo cáo.',
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _ReportProduct(
                        product: visible[index],
                        onOpen: () => _openProduct(visible[index]),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.title,
    required this.value,
    required this.color,
    this.note,
    this.onTap,
    this.footer,
  });
  final String title;
  final String value;
  final Color color;
  final String? note;
  final VoidCallback? onTap;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title)),
                if (onTap != null) const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
            if (note != null) ...[const SizedBox(height: 6), Text(note!)],
            ?footer,
          ],
        ),
      ),
    ),
  );
}

class _ReportProduct extends StatelessWidget {
  const _ReportProduct({
    required this.product,
    required this.onOpen,
    this.onStockIn,
    this.restock = false,
  });
  final Product product;
  final VoidCallback onOpen;
  final VoidCallback? onStockIn;
  final bool restock;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: Theme.of(context).textTheme.titleMedium),
            Text('${product.sku} · ${product.category}'),
            const SizedBox(height: 8),
            Text('Tồn hiện tại: ${product.quantity} ${product.unit}'),
            if (restock) ...[
              Text('Mức tồn tối thiểu: ${product.minStock} ${product.unit}'),
              Text(
                'Bổ sung tối thiểu: ${suggestedRestock(product)} ${product.unit}',
              ),
              if (product.quantity == product.minStock)
                const Text('Đã đạt ngưỡng tối thiểu; đề xuất bổ sung bằng 0.'),
            ] else ...[
              Text(
                product.purchasePriceVnd == null
                    ? 'Chưa có giá nhập'
                    : 'Giá nhập: ${formatVnd(product.purchasePriceVnd!)}',
              ),
              Text(
                productInventoryValue(product) == null
                    ? 'Giá trị tồn: chưa xác định'
                    : 'Giá trị tồn: ${formatInventoryValue(productInventoryValue(product)!)}',
              ),
            ],
            const SizedBox(height: 8),
            StatusBadge(product: product),
            if (onStockIn != null)
              TextButton.icon(
                onPressed: onStockIn,
                icon: const Icon(Icons.move_to_inbox_outlined),
                label: const Text('Nhập thêm hàng'),
              ),
          ],
        ),
      ),
    ),
  );
}
