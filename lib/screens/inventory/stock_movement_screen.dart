import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../models/stock_movement.dart';
import '../../services/inventory_service.dart';
import '../../services/product_service.dart';
import '../../theme/stock_theme.dart';

class StockMovementScreen extends StatefulWidget {
  const StockMovementScreen({
    super.key,
    required this.products,
    required this.inventory,
    required this.product,
    required this.type,
  });

  final ProductService products;
  final InventoryService inventory;
  final Product product;
  final StockMovementType type;

  @override
  State<StockMovementScreen> createState() => _StockMovementScreenState();
}

class _StockMovementScreenState extends State<StockMovementScreen> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  late final _product = widget.products.watchProduct(widget.product.id);
  late final _movementId = widget.inventory.newMovementId();
  bool _busy = false;
  bool _confirming = false;
  DateTime _transactionDate = DateTime.now();

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(1970),
      lastDate: now,
      helpText: 'Ngày giao dịch',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_transactionDate),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Giờ giao dịch',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ngày giao dịch không được ở tương lai.')),
      );
      return;
    }
    setState(() => _transactionDate = selected);
  }

  bool _valid(Product product) {
    final quantity = _parseQuantity(_quantity.text);
    if (quantity == null ||
        _note.text.length > InventoryService.maxNoteLength) {
      return false;
    }
    final next = widget.type.isIn
        ? product.quantity + quantity
        : product.quantity - quantity;
    return next >= 0 &&
        next <= ProductService.maxNumber &&
        !_transactionDate.isAfter(DateTime.now());
  }

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  int? _parseQuantity(String? input) {
    final value = input?.trim() ?? '';
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) return null;
    final quantity = int.tryParse(value, radix: 10);
    return quantity != null &&
            quantity > 0 &&
            quantity <= ProductService.maxNumber
        ? quantity
        : null;
  }

  Future<void> _submit(Product product) async {
    if (_busy ||
        _confirming ||
        !_form.currentState!.validate() ||
        !_valid(product)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final quantity = _parseQuantity(_quantity.text)!;
    final note = _note.text;
    final transactionDate = _transactionDate;
    final action = widget.type.label;
    setState(() => _confirming = true);
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận ${action.toLowerCase()}'),
        content: SingleChildScrollView(
          child: Text(
            '$action $quantity ${product.unit} cho “${product.name}”?\n'
            'SKU: ${product.sku}\n'
            'Ngày giao dịch: ${formatMovementDate(transactionDate)}\n'
            'Tồn kho: ${product.quantity} → ${widget.type.isIn ? product.quantity + quantity : product.quantity - quantity} ${product.unit}'
            '${note.trim().isEmpty ? '' : '\nGhi chú: ${note.trim()}'}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed != true) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.inventory.record(
        movementId: _movementId,
        productId: product.id,
        type: widget.type,
        quantity: quantity,
        note: note,
        transactionDate: transactionDate,
      );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(productErrorMessage(error))),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text('$action thành công.')));
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final color = type.isIn ? stockSuccess : stockError;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(type.label)),
        body: SafeArea(
          child: StreamBuilder<Product?>(
            stream: _product,
            initialData: widget.product,
            builder: (context, snapshot) {
              final product = snapshot.data;
              if (snapshot.hasError || product == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      snapshot.hasError
                          ? productErrorMessage(snapshot.error!)
                          : 'Sản phẩm không còn trong kho.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return Form(
                key: _form,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Card(
                      color: color.withValues(alpha: .08),
                      child: ListTile(
                        leading: Icon(
                          type.isIn
                              ? Icons.move_to_inbox_outlined
                              : Icons.outbox_outlined,
                          color: color,
                        ),
                        title: Text(product.name),
                        subtitle: Text(
                          '${product.sku} · ${product.unit}\n'
                          'Barcode: ${product.barcode.isEmpty ? 'Chưa khai báo' : product.barcode}\n'
                          'Tồn hiện tại: ${product.quantity} ${product.unit}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _quantity,
                      enabled: !_busy,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: type.isIn
                            ? 'Số lượng nhập'
                            : 'Số lượng xuất',
                      ),
                      validator: (input) {
                        final quantity = _parseQuantity(input);
                        if (quantity == null) {
                          return 'Hãy nhập số nguyên dương hợp lệ.';
                        }
                        if (!type.isIn && quantity > product.quantity) {
                          return 'Không đủ tồn kho. Hiện còn ${product.quantity}.';
                        }
                        if (type.isIn &&
                            product.quantity + quantity >
                                ProductService.maxNumber) {
                          return 'Số lượng tồn sau khi nhập quá lớn.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.event_outlined),
                        title: const Text('Ngày giao dịch'),
                        subtitle: Text(formatMovementDate(_transactionDate)),
                        trailing: const Icon(Icons.edit_calendar_outlined),
                        onTap: _busy || _confirming ? null : _pickDate,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Chọn cả ngày và giờ; không chọn thời điểm tương lai.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _note,
                      enabled: !_busy,
                      onChanged: (_) => setState(() {}),
                      maxLength: InventoryService.maxNoteLength,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (không bắt buộc)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        title: const Text('Tồn kho dự kiến sau giao dịch'),
                        subtitle: Text(
                          _valid(product)
                              ? '${type.isIn ? product.quantity + _parseQuantity(_quantity.text)! : product.quantity - _parseQuantity(_quantity.text)!} ${product.unit}'
                              : 'Nhập số lượng hợp lệ để xem dự kiến',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: type.isIn
                            ? const Color(0xFF15803D)
                            : stockError,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _busy || _confirming || !_valid(product)
                          ? null
                          : () => _submit(product),
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _busy
                            ? 'Đang xử lý…'
                            : 'Xác nhận ${type.label.toLowerCase()}',
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
}
