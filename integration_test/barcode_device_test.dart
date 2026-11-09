import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stockease/screens/barcode/barcode_scanner_screen.dart';
import 'package:stockease/models/product_barcode.dart';

import 'barcode_fixtures.dart';

/// Isolated harness: never initializes Firebase or writes warehouse data.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real Android camera, torch, manual input and native decoding', (
    tester,
  ) async {
    final controller = MobileScannerController(
      autoStart: false,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.code128,
      ],
    );
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BarcodeScannerScreen(controller: controller),
                  ),
                );
              },
              child: const Text('Open scanner'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open scanner'));
    for (var i = 0; i < 60 && !controller.value.isRunning; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(
      controller.value.isRunning,
      isTrue,
      reason: 'Android camera must start after permission grant',
    );
    expect(controller.value.hasCameraPermission, isTrue);
    if (controller.value.torchState != TorchState.unavailable) {
      await tester.tap(find.byTooltip('Bật đèn flash'));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.value.torchState, TorchState.on);
      await tester.tap(find.byTooltip('Tắt đèn flash'));
      await tester.pump(const Duration(seconds: 1));
    }
    final expected = {
      'EAN13': '5901234123457',
      'EAN8': '96385074',
      'UPCA': '036000291452',
      'Code128': 'StockEase/001',
    };
    final dir = await Directory.systemTemp.createTemp(
      'stockease-barcode-test-',
    );
    try {
      for (final fixture in barcodeFixtures.entries) {
        final file = File('${dir.path}/${fixture.key}.png');
        await file.writeAsBytes(base64Decode(fixture.value));
        final capture = await controller.analyzeImage(
          file.path,
          formats: const [
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
            BarcodeFormat.upcA,
            BarcodeFormat.code128,
          ],
        );
        expect(
          capture,
          isNotNull,
          reason: 'Native ML Kit must decode ${fixture.key}',
        );
        expect(
          capture!.barcodes.any(
            (b) =>
                barcodeIdentity(b.rawValue ?? '') ==
                barcodeIdentity(expected[fixture.key]!),
          ),
          isTrue,
          reason:
              'Native decoded value must match synthetic ${fixture.key} fixture',
        );
      }
    } finally {
      await dir.delete(recursive: true);
    }
    await tester.tap(find.text('Nhập mã thủ công'));
    await tester.pumpAndSettle();
    expect(controller.value.isRunning, isFalse);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Barcode'),
      '00001234',
    );
    await tester.tap(find.text('Dùng mã này'));
    await tester.pumpAndSettle();
    expect(selected, '00001234');
    expect(find.byType(BarcodeScannerScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
