import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../models/product_options.dart';
import '../../services/product_service.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, required this.service, this.product});

  final ProductService service;
  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name);
  late final _sku = TextEditingController(text: widget.product?.sku);
  late final _price = TextEditingController(
    text: widget.product?.price.toString() ?? '0',
  );
  final _quantity = TextEditingController(text: '0');
  late final _minStock = TextEditingController(
    text: widget.product?.minStock.toString() ?? '0',
  );
  late String _category = widget.product?.category ?? productCategories.first;
  late String _unit = widget.product?.unit ?? productUnits.first;
  bool _saving = false;
  bool _dirty = false;
  bool _confirmingExit = false;
  String? _error;

  Future<void> _confirmExit() async {
    if (_saving || !_dirty || _confirmingExit) return;
    _confirmingExit = true;
    final discard = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ thay đổi?'),
        content: const Text('Thông tin bạn vừa nhập chưa được lưu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục sửa'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    _confirmingExit = false;
    if (mounted && discard == true) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _price.dispose();
    _quantity.dispose();
    _minStock.dispose();
    super.dispose();
  }

  String? _validateNumber(String? value) {
    final number = int.tryParse(value?.trim() ?? '', radix: 10);
    if (number == null || number < 0) return 'Hãy nhập số nguyên không âm.';
    if (number > ProductService.maxNumber) return 'Giá trị quá lớn.';
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final product = widget.product;
    try {
      await widget.service.save(
        id: product?.id,
        name: _name.text,
        sku: _sku.text,
        category: _category,
        price: int.parse(_price.text.trim(), radix: 10),
        quantity: product == null
            ? int.parse(_quantity.text.trim(), radix: 10)
            : null,
        minStock: int.parse(_minStock.text.trim(), radix: 10),
        unit: _unit,
      );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = productErrorMessage(error);
      });
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          product == null ? 'Đã thêm sản phẩm.' : 'Đã cập nhật sản phẩm.',
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      validator: _validateNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    return PopScope(
      canPop: !_saving && !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(editing ? 'Sửa sản phẩm' : 'Thêm sản phẩm')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _form,
                onChanged: () {
                  if (!_dirty) setState(() => _dirty = true);
                },
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Thông tin sản phẩm',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _name,
                      enabled: !_saving,
                      maxLength: 120,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Tên sản phẩm',
                        hintText: 'Ví dụ Coca-Cola 330 ml',
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Hãy nhập tên sản phẩm.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sku,
                      enabled: !_saving,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'SKU'),
                      validator: (value) {
                        final sku = value?.trim() ?? '';
                        if (sku.isEmpty) return 'Hãy nhập SKU.';
                        if (!ProductService.skuPattern.hasMatch(sku)) {
                          return 'Dùng tối đa 40 chữ cái, chữ số, dấu - hoặc _. '
                              'Tránh SKU có hai dấu _ ở cả hai đầu.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Danh mục'),
                      items: productCategories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _category = value!),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Giá và tồn kho',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _numberField(_price, 'Giá (VND)'),
                    if (!editing) ...[
                      const SizedBox(height: 16),
                      _numberField(_quantity, 'Số lượng tồn ban đầu'),
                    ],
                    const SizedBox(height: 16),
                    _numberField(_minStock, 'Mức tồn tối thiểu'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _unit,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Đơn vị'),
                      items: productUnits
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _unit = value!),
                    ),
                    if (_error case final error?) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Lưu sản phẩm'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
