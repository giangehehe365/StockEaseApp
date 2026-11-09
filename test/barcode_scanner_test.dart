import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stockease/screens/barcode/barcode_scanner_screen.dart';
import 'package:stockease/screens/products/product_list_screen.dart';
import 'package:stockease/screens/products/product_details_screen.dart';
import 'package:stockease/screens/products/product_form_screen.dart';
import 'package:stockease/screens/inventory/product_selection_sheet.dart';
import 'package:stockease/screens/inventory/stock_movement_screen.dart';
import 'package:stockease/models/stock_movement.dart';
import 'package:stockease/services/product_service.dart';
import 'package:stockease/services/inventory_service.dart';

import 'barcode_service_test.dart' show BarcodeFirestore, data;

class ScannerPlatform extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  final torches = StreamController<TorchState>.broadcast();
  final zooms = StreamController<double>.broadcast();
  bool denied = false;
  bool hasTorch = true;
  int starts = 0, stops = 0, disposals = 0, toggles = 0;
  StartOptions? options;
  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => torches.stream;
  @override
  Stream<double> get zoomScaleStateStream => zooms.stream;
  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    starts++;
    options = startOptions;
    if (denied) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    return MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: hasTorch ? TorchState.off : TorchState.unavailable,
      size: const Size(640, 480),
      numberOfCameras: 1,
    );
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
  @override
  Future<void> toggleTorch() async {
    toggles++;
    torches.add(TorchState.on);
  }

  void detect(String code, [BarcodeFormat format = BarcodeFormat.ean13]) =>
      captures.add(
        BarcodeCapture(
          barcodes: [Barcode(rawValue: code, format: format)],
        ),
      );
  Future<void> close() async {
    await captures.close();
    await torches.close();
    await zooms.close();
  }
}

void main() {
  late ScannerPlatform platform;
  late MobileScannerPlatform previous;
  setUp(() {
    previous = MobileScannerPlatform.instance;
    platform = ScannerPlatform();
    MobileScannerPlatform.instance = platform;
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });
  tearDown(() async {
    MobileScannerPlatform.instance = previous;
    await platform.close();
  });
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<void> manual(WidgetTester tester, String code) async {
    await tester.tap(find.text('Nhập mã thủ công'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Barcode'), code);
    await tester.tap(find.text('Dùng mã này'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'camera starts with four formats; duplicate captures pop once and dispose',
    (tester) async {
      final results = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  results.add(
                    await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BarcodeScannerScreen(),
                      ),
                    ),
                  );
                },
                child: const Text('Scan'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      expect(platform.starts, 1);
      expect(
        platform.options!.formats,
        containsAll([
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.code128,
        ]),
      );
      platform.detect('0012345678905');
      platform.detect('0012345678905');
      await tester.pumpAndSettle();
      expect(results, ['0012345678905']);
      expect(platform.stops, greaterThanOrEqualTo(1));
      expect(platform.disposals, 1);
      await unmount(tester);
    },
  );
  testWidgets(
    'permission denial offers manual input without crashing on small screen',
    (tester) async {
      platform.denied = true;
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BarcodeScannerScreen(),
                    ),
                  );
                },
                child: const Text('Scan'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa có quyền camera'), findsWidgets);
      await manual(tester, '00001234');
      expect(result, '00001234');
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );
  testWidgets('torch support and background lifecycle stop/resume camera', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BarcodeScannerScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bật đèn flash'));
    await tester.pumpAndSettle();
    expect(platform.toggles, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(platform.stops, greaterThanOrEqualTo(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(platform.starts, 2);
    await unmount(tester);
  });
  testWidgets(
    'unsupported torch is disabled; unknown code opens prefilled form without writing',
    (tester) async {
      platform.hasTorch = false;
      final db = BarcodeFirestore();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductListScreen(
              service: ProductService(db, 'owner'),
              inventory: InventoryService(db, 'owner'),
              products: const [],
              onAdd: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Scan Barcode'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('Bật đèn flash'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await manual(tester, '00001234');
      expect(find.text('Product not found'), findsOneWidget);
      expect(db.documents, isEmpty);
      await tester.tap(find.text('Thêm sản phẩm với barcode này'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductFormScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('productBarcode')),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ProductFormScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final field = tester.widget<TextFormField>(
        find.byKey(const ValueKey('productBarcode')),
      );
      expect(field.controller!.text, '00001234');
      expect(db.documents, isEmpty);
      await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Tên sản phẩm'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên sản phẩm'),
        'New barcode product',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'SKU'),
        'SEPARATE-SKU',
      );
      final formScroll = find
          .descendant(
            of: find.byType(ProductFormScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Lưu sản phẩm'),
        250,
        scrollable: formScroll,
      );
      await tester.tap(find.text('Lưu sản phẩm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận lưu'));
      await tester.pumpAndSettle();
      expect(db.documents['users/owner/products/new']!['barcode'], '00001234');
      expect(db.documents['users/owner/products/new']!['sku'], 'SEPARATE-SKU');
      expect(find.byType(ProductDetailsScreen), findsOneWidget);
      expect(
        db.documents.keys.where((k) => k.contains('stockMovements')),
        isEmpty,
      );
      await unmount(tester);
      await db.changes.close();
    },
  );
  testWidgets('scanner error layout fits landscape and large text', (
    tester,
  ) async {
    platform.denied = true;
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: const BarcodeScannerScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Chưa có quyền camera'), findsWidgets);
    await unmount(tester);
  });
  testWidgets('matching barcode opens details in current user only', (
    tester,
  ) async {
    final db = BarcodeFirestore();
    db.documents['users/owner/products/p'] = data(
      'owner',
      'SKU',
      '0012345678905',
    );
    db.documents['users/other/products/p'] = data(
      'other',
      'OTHER',
      '0012345678905',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductListScreen(
            service: ProductService(db, 'owner'),
            inventory: InventoryService(db, 'owner'),
            products: const [],
            onAdd: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Scan Barcode'));
    await tester.pumpAndSettle();
    platform.detect('0012345678905');
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailsScreen), findsOneWidget);
    expect(find.text('SKU'), findsWidgets);
    expect(find.text('OTHER'), findsNothing);
    expect(
      db.documents.keys.where((k) => k.contains('stockMovements')),
      isEmpty,
    );
    await unmount(tester);
    await db.changes.close();
  });
  testWidgets(
    'network failure is an error, never not-found, and retry recovers',
    (tester) async {
      final db = BarcodeFirestore()..failGet = true;
      db.documents['users/owner/products/p'] = data(
        'owner',
        'SKU',
        '0012345678905',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductListScreen(
              service: ProductService(db, 'owner'),
              inventory: InventoryService(db, 'owner'),
              products: const [],
              onAdd: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Scan Barcode'));
      await tester.pumpAndSettle();
      platform.detect('0012345678905');
      await tester.pumpAndSettle();
      expect(find.text('Product not found'), findsNothing);
      expect(find.text('Thêm sản phẩm với barcode này'), findsNothing);
      expect(find.textContaining('kiểm tra mạng'), findsOneWidget);
      db.failGet = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductDetailsScreen), findsOneWidget);
      await unmount(tester);
      await db.changes.close();
    },
  );
  for (final type in StockMovementType.values) {
    testWidgets(
      'barcode selects ${type.code}; only confirmation records inventory',
      (tester) async {
        final db = BarcodeFirestore();
        db.documents['users/owner/products/p'] = data(
          'owner',
          'SKU',
          '0012345678905',
        );
        final products = ProductService(db, 'owner');
        final inventory = InventoryService(db, 'owner');
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    final product = await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ProductSelectionSheet(
                        products: const [],
                        type: type,
                        service: products,
                      ),
                    );
                    if (context.mounted && product != null) {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StockMovementScreen(
                            products: products,
                            inventory: inventory,
                            product: product,
                            type: type,
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Choose'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Choose'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Scan Barcode'));
        await tester.pumpAndSettle();
        platform.detect('0012345678905');
        platform.detect('0012345678905');
        await tester.pumpAndSettle();
        expect(find.byType(StockMovementScreen), findsOneWidget);
        expect(
          db.documents.keys.where((k) => k.contains('stockMovements')),
          isEmpty,
        );
        await tester.enterText(find.byType(TextFormField).first, '2');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.widgetWithText(
            FilledButton,
            'Xác nhận ${type.label.toLowerCase()}',
          ),
          150,
          scrollable: find
              .descendant(
                of: find.byType(StockMovementScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(
          find.widgetWithText(
            FilledButton,
            'Xác nhận ${type.label.toLowerCase()}',
          ),
        );
        await tester.pumpAndSettle();
        expect(
          db.documents.keys.where((k) => k.contains('stockMovements')),
          isEmpty,
        );
        await tester.tap(find.text('Xác nhận'));
        await tester.pumpAndSettle();
        expect(
          db.documents['users/owner/products/p']!['quantity'],
          type.isIn ? 12 : 8,
        );
        expect(
          db.documents.keys.where((k) => k.contains('stockMovements')),
          hasLength(1),
        );
        await unmount(tester);
        await db.changes.close();
      },
    );
  }
}
