import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/product_list_query.dart';
import '../models/stock_movement.dart';
import '../services/auth_service.dart';
import '../services/inventory_service.dart';
import '../services/product_service.dart';
import '../services/store_profile_service.dart';
import 'dashboard_screen.dart';
import 'inventory/inventory_history_screen.dart';
import 'inventory/product_selection_sheet.dart';
import 'inventory/stock_movement_screen.dart';
import 'products/product_details_screen.dart';
import 'products/product_form_screen.dart';
import 'products/product_list_screen.dart';
import 'profile_screen.dart';

class StockShell extends StatefulWidget {
  const StockShell({
    super.key,
    required this.uid,
    required this.email,
    required this.displayName,
    required this.auth,
    required this.firestore,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final AuthService auth;
  final FirebaseFirestore? firestore;

  @override
  State<StockShell> createState() => _StockShellState();
}

class _StockShellState extends State<StockShell> {
  late final _products = widget.firestore == null
      ? null
      : ProductService(widget.firestore!, widget.uid);
  late final _profiles = widget.firestore == null
      ? null
      : StoreProfileService(widget.firestore!, widget.uid);
  late final _inventory = widget.firestore == null
      ? null
      : InventoryService(widget.firestore!, widget.uid);
  late var _movementStream = _inventory?.watchMovements();
  late final _profileStream = _profiles?.watch();
  late var _productStream = _products?.watchProducts();
  int _tab = 0;

  void _select(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tab = index);
  }

  void _add() => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => ProductFormScreen(service: _products!)),
  );

  void _open(Product product) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ProductDetailsScreen(
        service: _products!,
        inventory: _inventory!,
        productId: product.id,
      ),
    ),
  );

  void _openHistory({StockMovementType? type}) => Navigator.of(context)
      .push<void>(
        MaterialPageRoute(
          builder: (_) => InventoryHistoryScreen(
            inventory: _inventory!,
            initialFilter: type,
          ),
        ),
      );

  void _openProductStats(ProductStockFilter filter, ProductSort sort) {
    final stockSummary = sort == ProductSort.quantityDescending;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProductListScreen(
          service: _products!,
          inventory: _inventory!,
          onAdd: _add,
          title: stockSummary
              ? 'Tồn kho'
              : switch (filter) {
                  ProductStockFilter.lowStock => 'Sản phẩm tồn kho thấp',
                  ProductStockFilter.outOfStock => 'Sản phẩm hết hàng',
                  _ => 'Tất cả sản phẩm',
                },
          initialStockFilter: filter,
          initialSort: sort,
          showStockSummary: stockSummary,
        ),
      ),
    );
  }

  Future<void> _stock(Product product, StockMovementType type) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => StockMovementScreen(
            products: _products!,
            inventory: _inventory!,
            product: product,
            type: type,
          ),
        ),
      );

  Future<void> _pickProduct(
    List<Product> products,
    StockMovementType type,
  ) async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      builder: (context) =>
          ProductSelectionSheet(products: products, type: type),
    );
    if (!mounted || product == null) return;
    await _stock(product, type);
  }

  Widget? _status(AsyncSnapshot<List<Product>> snapshot) {
    if (_products == null) return const Text('Chưa kết nối Firestore.');
    if (snapshot.hasError) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                productErrorMessage(snapshot.error!),
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _productStream = _products.watchProducts()),
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
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tab != 0) _select(0);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(const ['StockEase', 'Sản phẩm', 'Hồ sơ'][_tab]),
        ),
        floatingActionButton: _tab == 1 && _products != null
            ? FloatingActionButton.extended(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Thêm sản phẩm'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Sản phẩm',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Hồ sơ',
            ),
          ],
        ),
        body: SafeArea(
          child: StreamBuilder<StoreProfile?>(
            stream: _profileStream,
            builder: (context, profileSnapshot) {
              final displayName = widget.displayName?.trim() ?? '';
              final emailName = widget.email?.split('@').first.trim() ?? '';
              final profile =
                  profileSnapshot.data ??
                  (
                    name: displayName.isNotEmpty
                        ? displayName
                        : (emailName.isNotEmpty ? emailName : 'Chủ kho'),
                    storeName: 'Kho StockEase',
                  );
              return StreamBuilder<List<Product>>(
                stream: _productStream,
                builder: (context, snapshot) {
                  final products = snapshot.data ?? const <Product>[];
                  final status = _status(snapshot);
                  return IndexedStack(
                    index: _tab,
                    children: [
                      DashboardScreen(
                        name: profile.name,
                        storeName: profile.storeName,
                        products: products,
                        onAdd: _products == null ? null : _add,
                        onProducts: () => _select(1),
                        onOpen: _open,
                        onProductStats: _products == null
                            ? null
                            : _openProductStats,
                        onMovementStats: _inventory == null
                            ? null
                            : (type) => _openHistory(type: type),
                        onRestock: _products == null
                            ? null
                            : (product) =>
                                  _stock(product, StockMovementType.stockIn),
                        productStatus: status,
                        movements: _movementStream,
                        onRetryMovements: () => setState(() {
                          _movementStream = _inventory?.watchMovements();
                        }),
                        onHistory: _inventory == null ? null : _openHistory,
                        onStockIn: products.isEmpty
                            ? null
                            : () => _pickProduct(
                                products,
                                StockMovementType.stockIn,
                              ),
                        onStockOut: products.isEmpty
                            ? null
                            : () => _pickProduct(
                                products,
                                StockMovementType.stockOut,
                              ),
                      ),
                      if (status != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: status,
                          ),
                        )
                      else
                        ProductListScreen(
                          service: _products!,
                          inventory: _inventory!,
                          products: products,
                          onAdd: _add,
                        ),
                      ProfileScreen(
                        email: widget.email,
                        profile: profile,
                        auth: widget.auth,
                        profiles: _profiles,
                        products: _products,
                        profileUnavailable: profileSnapshot.hasError,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
