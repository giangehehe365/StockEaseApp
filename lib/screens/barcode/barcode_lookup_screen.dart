import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/product_service.dart';
import '../products/product_form_screen.dart';
import 'barcode_scanner_screen.dart';

Future<Product?> pickProductByBarcode(
  BuildContext context,
  ProductService service,
) => Navigator.of(context).push<Product>(
  MaterialPageRoute(builder: (_) => BarcodeLookupScreen(service: service)),
);

/// Only returns a selection. Inventory mutations remain in StockMovementScreen.
class BarcodeLookupScreen extends StatefulWidget {
  const BarcodeLookupScreen({super.key, required this.service});
  final ProductService service;
  @override
  State<BarcodeLookupScreen> createState() => _BarcodeLookupScreenState();
}

class _BarcodeLookupScreenState extends State<BarcodeLookupScreen> {
  String? _code;
  String? _error;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted) return;
    if (code == null) {
      Navigator.pop(context);
      return;
    }
    _code = code;
    await _lookup();
  }

  Future<void> _lookup() async {
    if (_loading || _code == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final product = await widget.service.findByBarcode(_code!);
      if (!mounted) return;
      if (product != null) {
        Navigator.pop(context, product);
        return;
      }
    } on Exception catch (error) {
      if (!mounted) return;
      _error = productErrorMessage(error);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ProductFormScreen(service: widget.service, initialBarcode: _code),
      ),
    );
    if (mounted) await _lookup();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tìm sản phẩm bằng barcode')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Đang tìm trong kho của bạn…'),
            ] else ...[
              Icon(
                _error == null ? Icons.search_off : Icons.cloud_off_outlined,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Product not found',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(_code ?? '', textAlign: TextAlign.center),
              if (_error == null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Chưa có sản phẩm đang hoạt động với barcode này trong kho của bạn.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm sản phẩm với barcode này'),
                ),
              ] else
                TextButton(onPressed: _lookup, child: const Text('Thử lại')),
              TextButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.barcode_reader),
                label: const Text('Quét mã khác'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
