import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../models/product_options.dart';
import '../../models/exchange_rate.dart';
import '../../models/purchase_price.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/product_service.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({
    super.key,
    required this.service,
    this.product,
    this.exchangeRates,
  });

  final ProductService service;
  final Product? product;
  final ExchangeRateService? exchangeRates;

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
  late final _purchase = TextEditingController(
    text:
        widget.product?.purchasePrice?.original.toString() ??
        (widget.product == null ? '0' : ''),
  );
  late String _currency = widget.product?.purchasePrice?.currency ?? 'VND';
  late ExchangeRate? _rate = widget.product?.purchasePrice?.currency == 'USD'
      ? ExchangeRate(
          rate: widget.product!.purchasePrice!.rate,
          date: widget.product!.purchasePrice!.rateDate!,
        )
      : null;
  late final _exchangeRates = widget.exchangeRates ?? ExchangeRateService();
  bool _loadingRate = false;
  bool _confirmingPrice = false;
  String? _rateError;
  int _rateRequest = 0;
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
    _purchase.dispose();
    _rateRequest++;
    if (widget.exchangeRates == null) _exchangeRates.close();
    super.dispose();
  }

  bool get _legacyWithoutPurchase =>
      widget.product != null &&
      widget.product!.purchasePrice == null &&
      _purchase.text.trim().isEmpty &&
      _currency == 'VND';

  PurchasePrice? get _purchasePrice {
    final amount = parsePurchaseAmount(_purchase.text, _currency);
    if (amount == null ||
        (_currency == 'USD' &&
            (_loadingRate || _rate == null || _rateError != null))) {
      return null;
    }
    final rate = _currency == 'VND' ? 1.0 : _rate!.rate;
    final converted = amount * rate;
    if (!converted.isFinite || converted >= PurchasePrice.maxAmount + .5) {
      return null;
    }
    final purchase = PurchasePrice(
      original: amount,
      currency: _currency,
      rate: rate,
      vnd: converted.round(),
      rateDate: _currency == 'USD' ? _rate!.date : null,
    );
    return purchase.isValid ? purchase : null;
  }

  Future<void> _loadRate() async {
    final request = ++_rateRequest;
    setState(() {
      _loadingRate = true;
      _rateError = null;
      _rate = null;
    });
    try {
      final rate = await _exchangeRates.getUsdVnd();
      if (!mounted || request != _rateRequest || _currency != 'USD') return;
      setState(() {
        _rate = rate;
        _loadingRate = false;
        _dirty = true;
      });
    } on ExchangeRateException catch (error) {
      if (!mounted || request != _rateRequest || _currency != 'USD') return;
      setState(() {
        _rateError = error.message;
        _loadingRate = false;
      });
    }
  }

  void _changeCurrency(String currency) {
    setState(() {
      _currency = currency;
      if (currency == 'VND') {
        final amount = num.tryParse(_purchase.text.trim().replaceAll(',', '.'));
        if (amount != null &&
            amount.isFinite &&
            amount == amount.roundToDouble()) {
          _purchase.text = amount.toInt().toString();
        }
      }
      _dirty = true;
      _rateError = null;
      if (currency == 'VND') {
        _rateRequest++;
        _loadingRate = false;
      }
    });
    if (currency == 'USD' && _rate == null) _loadRate();
  }

  Widget _purchaseSection() => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      initiallyExpanded: widget.product?.purchasePrice != null,
      title: const Text('Giá nhập (Purchase Price)'),
      subtitle: Text(
        _purchasePrice == null
            ? 'VND hoặc USD'
            : formatVnd(_purchasePrice!.vnd),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        TextFormField(
          key: const ValueKey('purchaseAmount'),
          controller: _purchase,
          enabled: !_saving && !_confirmingPrice,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            labelText: 'Giá nhập gốc ($_currency)',
            helperText: _currency == 'USD'
                ? 'Tối đa 2 số lẻ; dùng dấu chấm hoặc phẩy.'
                : (widget.product != null &&
                          widget.product!.purchasePrice == null
                      ? 'Có thể để trống với sản phẩm cũ.'
                      : 'Số nguyên VND, không nhập dấu phân cách nghìn.'),
            helperMaxLines: 2,
          ),
          onChanged: (_) => setState(() {}),
          validator: (_) {
            if (_legacyWithoutPurchase) return null;
            if (parsePurchaseAmount(_purchase.text, _currency) == null) {
              return 'Hãy nhập giá nhập không âm hợp lệ.';
            }
            if (!_loadingRate &&
                (_currency == 'VND' || _rate != null) &&
                _purchasePrice == null) {
              return 'Giá nhập quy đổi quá lớn.';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const ValueKey('purchaseCurrency'),
          initialValue: _currency,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tiền tệ'),
          items: const [
            DropdownMenuItem(value: 'VND', child: Text('VND')),
            DropdownMenuItem(value: 'USD', child: Text('USD')),
          ],
          onChanged: _saving || _confirmingPrice
              ? null
              : (value) => _changeCurrency(value!),
        ),
        if (_currency == 'USD') ...[
          const SizedBox(height: 12),
          if (_loadingRate) const LinearProgressIndicator(),
          if (_rate != null) ...[
            Text('1 USD = ${_rate!.rate} VND'),
            Text('Ngày tỷ giá: ${_rate!.date}'),
          ],
          if (_rateError != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _rateError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextButton.icon(
            onPressed: _loadingRate || _saving || _confirmingPrice
                ? null
                : _loadRate,
            icon: const Icon(Icons.refresh),
            label: Text(
              _loadingRate
                  ? 'Đang lấy tỷ giá…'
                  : (_rateError == null ? 'Làm mới tỷ giá' : 'Thử lại tỷ giá'),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          _purchasePrice == null
              ? 'Chưa có giá nhập quy đổi hợp lệ'
              : 'Giá nhập quy đổi: ${formatVnd(_purchasePrice!.vnd)}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    ),
  );

  String? _validateNumber(String? value) {
    final number = int.tryParse(value?.trim() ?? '', radix: 10);
    if (number == null || number < 0) return 'Hãy nhập số nguyên không âm.';
    if (number > ProductService.maxNumber) return 'Giá trị quá lớn.';
    return null;
  }

  Future<void> _save() async {
    if (_saving || _confirmingPrice || !_form.currentState!.validate()) return;
    final purchase = _purchasePrice;
    if (purchase == null && !_legacyWithoutPurchase) return;
    FocusScope.of(context).unfocus();
    if (purchase != null) {
      setState(() => _confirmingPrice = true);
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận giá nhập'),
          content: SingleChildScrollView(
            child: Text(
              '${purchase.original} ${purchase.currency}\n'
              '${purchase.currency == 'USD' ? '1 USD = ${purchase.rate} VND\nNgày tỷ giá: ${purchase.rateDate}\n' : ''}'
              'Giá nhập lưu: ${formatVnd(purchase.vnd)}\nGiá bán: ${formatVnd(int.parse(_price.text.trim()))}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận lưu'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() => _confirmingPrice = false);
      if (confirmed != true) return;
    }
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
        purchasePrice: purchase,
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
                    _numberField(_price, 'Giá bán (VND)'),
                    const SizedBox(height: 16),
                    _purchaseSection(),
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
                      onPressed:
                          _saving ||
                              _confirmingPrice ||
                              (!_legacyWithoutPurchase &&
                                  _purchasePrice == null)
                          ? null
                          : _save,
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
