import 'package:flutter/material.dart';

import '../../models/stock_movement.dart';
import '../../services/inventory_service.dart';
import '../../services/product_service.dart';
import '../../theme/stock_theme.dart';

class InventoryHistoryScreen extends StatefulWidget {
  const InventoryHistoryScreen({
    super.key,
    required this.inventory,
    this.productId,
    this.productName,
    this.initialFilter,
    this.initialDateRange,
  });

  final InventoryService inventory;
  final String? productId;
  final String? productName;
  final StockMovementType? initialFilter;
  final DateTimeRange? initialDateRange;

  @override
  State<InventoryHistoryScreen> createState() => _InventoryHistoryScreenState();
}

class _InventoryHistoryScreenState extends State<InventoryHistoryScreen> {
  late var _history = widget.inventory.watchMovements(
    productId: widget.productId,
  );
  final _search = TextEditingController();
  late StockMovementType? _filter = widget.initialFilter;
  late DateTimeRange? _range = widget.initialDateRange;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      helpText: 'Khoảng ngày giao dịch',
    );
    if (mounted && range != null) setState(() => _range = range);
  }

  Widget _filters() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.productName case final name?) ...[
        Text(name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
      ],
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
        spacing: 8,
        children: [
          for (final type in [null, ...StockMovementType.values])
            ChoiceChip(
              label: Text(type?.label ?? 'Tất cả'),
              selected: type == _filter,
              onSelected: (_) => setState(() => _filter = type),
            ),
        ],
      ),
      Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
            label: Text(
              _range == null
                  ? 'Khoảng ngày'
                  : '${formatMovementDate(_range!.start).split(' ').first} – '
                        '${formatMovementDate(_range!.end).split(' ').first}',
            ),
          ),
          if (_range != null)
            IconButton(
              tooltip: 'Xóa khoảng ngày',
              onPressed: () => setState(() => _range = null),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      const SizedBox(height: 12),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _filter == null
            ? 'Lịch sử kho'
            : 'Lịch sử ${_filter!.label.toLowerCase()}',
      ),
    ),
    body: SafeArea(
      child: StreamBuilder<List<StockMovement>>(
        stream: _history,
        builder: (context, snapshot) {
          final movements = queryMovements(
            snapshot.data ?? [],
            search: _search.text,
            type: _filter,
            start: _range?.start,
            end: _range?.end,
          );
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(child: _filters()),
              ),
              if (snapshot.hasData && !snapshot.hasError)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: Text('Hiển thị ${movements.length} giao dịch'),
                  ),
                ),
              if (snapshot.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          productErrorMessage(snapshot.error!),
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _history = widget.inventory.watchMovements(
                              productId: widget.productId,
                            );
                          }),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (!snapshot.hasData)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (movements.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _search.text.trim().isEmpty &&
                                  _range == null &&
                                  _filter != null
                              ? 'Chưa có giao dịch ${_filter!.label.toLowerCase()}'
                              : 'Chưa có giao dịch phù hợp.',
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _search.clear();
                            _filter = null;
                            _range = null;
                          }),
                          child: const Text('Xóa bộ lọc'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList.separated(
                    itemCount: movements.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        MovementCard(movements[index]),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class MovementCard extends StatelessWidget {
  const MovementCard(this.movement, {super.key});

  final StockMovement movement;

  void _showDetails(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(movement.type.label),
      content: SingleChildScrollView(
        child: Text(
          '${movement.productName}\n'
          '${movement.sku.isEmpty ? '' : 'SKU: ${movement.sku}\n'}'
          'Số lượng: ${movement.type.isIn ? '+' : '−'}${movement.quantity}\n'
          'Ngày giao dịch: ${formatMovementDate(movement.effectiveDate)}\n'
          'Thời điểm lưu: ${formatMovementDate(movement.createdAt)}\n'
          'Ghi chú: ${movement.note.isEmpty ? 'Không có' : movement.note}\n'
          'Mã giao dịch: ${movement.id}',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final inbound = movement.type.isIn;
    final color = inbound ? stockSuccess : stockError;
    return Card(
      child: ListTile(
        onTap: () => _showDetails(context),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .1),
          child: Icon(
            inbound ? Icons.move_to_inbox_outlined : Icons.outbox_outlined,
            color: color,
          ),
        ),
        title: Text(movement.productName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (movement.sku.isNotEmpty) Text(movement.sku),
            Text(
              '${movement.type.label} · ${inbound ? '+' : '−'}${movement.quantity}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            Text(formatMovementDate(movement.effectiveDate)),
            if (movement.note.isNotEmpty)
              Text(movement.note, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
