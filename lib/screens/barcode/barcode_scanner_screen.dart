import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/product_barcode.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key, this.controller});

  /// Optional controller allows hardware-free lifecycle/permission tests.
  final MobileScannerController? controller;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  late final _camera =
      widget.controller ??
      MobileScannerController(
        autoStart: false,
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.code128,
        ],
      );
  StreamSubscription<BarcodeCapture>? _detections;
  bool _completed = false;
  bool _manualOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detections = _camera.barcodes.listen(
      (capture) {
        for (final barcode in capture.barcodes) {
          if (!const [
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
            BarcodeFormat.upcA,
            BarcodeFormat.code128,
          ].contains(barcode.format)) {
            continue;
          }
          final value = normalizeBarcode(barcode.rawValue ?? '');
          if (value.isNotEmpty && validBarcode(value)) {
            unawaited(_complete(value));
            break;
          }
        }
      },
      onError: (Object error) {
        if (mounted && !_completed) {
          setState(
            () => _error = 'Không đọc được mã. Hãy thử lại hoặc nhập thủ công.',
          );
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  Future<void> _start() async {
    if (!mounted ||
        _completed ||
        _manualOpen ||
        _camera.value.isStarting ||
        _camera.value.isRunning) {
      return;
    }
    try {
      setState(() => _error = null);
      await _camera.start();
      if (!mounted ||
          _completed ||
          _manualOpen ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        await _stop();
      }
    } on MobileScannerException catch (error) {
      if (mounted) setState(() => _error = _cameraError(error));
    } on Exception {
      if (mounted) {
        setState(
          () => _error = 'Không mở được camera. Bạn có thể nhập mã thủ công.',
        );
      }
    }
  }

  String _cameraError(MobileScannerException error) =>
      error.errorCode == MobileScannerErrorCode.permissionDenied
      ? 'Chưa có quyền camera. Cho phép Camera trong Cài đặt ứng dụng rồi thử lại, hoặc nhập mã thủ công.'
      : 'Camera không khả dụng. Hãy thử lại hoặc nhập mã thủ công.';

  Future<void> _stop() async {
    try {
      await _camera.stop();
    } on Exception {
      /* Still allow manual input/exit. */
    }
  }

  Future<void> _complete(String code) async {
    if (_completed || !mounted) return;
    _completed = true; // Lock synchronously, before stopping the camera.
    await _stop();
    if (mounted) Navigator.of(context).pop(code);
  }

  Future<void> _manual() async {
    if (_manualOpen || _completed) return;
    _manualOpen = true;
    await _stop();
    if (!mounted) return;
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualBarcodeDialog(),
    );
    _manualOpen = false;
    if (!mounted) return;
    if (code != null) {
      await _complete(code);
    } else {
      await _start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // A permission dialog can resume before start() has finished.
      if (_camera.value.hasCameraPermission) unawaited(_start());
    } else {
      unawaited(_stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_detections?.cancel());
    unawaited(_camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Quét barcode'),
      actions: [
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: _camera,
          builder: (context, state, _) => IconButton(
            tooltip: state.torchState == TorchState.on
                ? 'Tắt đèn flash'
                : 'Bật đèn flash',
            onPressed:
                !state.isRunning || state.torchState == TorchState.unavailable
                ? null
                : () async {
                    try {
                      await _camera.toggleTorch();
                    } on Exception {
                      if (mounted) {
                        setState(
                          () => _error = 'Không bật được đèn flash. Bạn vẫn có thể nhập mã.',
                        );
                      }
                    }
                  },
            icon: Icon(
              state.torchState == TorchState.on
                  ? Icons.flash_on
                  : Icons.flash_off,
            ),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, layout) => Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  final scanWindow = Rect.fromCenter(
                    center: size.center(Offset.zero),
                    width: size.width * .85,
                    height: (size.height * .45).clamp(0.0, 190.0),
                  );
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _camera,
                        useAppLifecycleState: false,
                        scanWindow: scanWindow,
                        tapToFocus: true,
                        placeholderBuilder: (_) =>
                            const Center(child: CircularProgressIndicator()),
                        errorBuilder: (_, error) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _cameraError(error),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: Center(
                          child: Container(
                            width: scanWindow.width,
                            height: scanWindow.height,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: layout.maxHeight * .6),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Đặt một mã vạch trong khung, giữ máy ổn định.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'EAN-13 · EAN-8 · UPC-A · Code 128',
                        textAlign: TextAlign.center,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          onPressed: _start,
                          child: const Text('Thử lại camera'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _manual,
                        icon: const Icon(Icons.keyboard_outlined),
                        label: const Text('Nhập mã thủ công'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ManualBarcodeDialog extends StatefulWidget {
  const _ManualBarcodeDialog();
  @override
  State<_ManualBarcodeDialog> createState() => _ManualBarcodeDialogState();
}

class _ManualBarcodeDialogState extends State<_ManualBarcodeDialog> {
  final _form = GlobalKey<FormState>();
  final _input = TextEditingController();
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nhập barcode thủ công'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: TextFormField(
          controller: _input,
          autofocus: true,
          maxLength: 128,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Barcode',
            helperText: 'Giữ nguyên số 0 ở đầu. Barcode khác với SKU.',
            helperMaxLines: 2,
          ),
          validator: (value) {
            final code = normalizeBarcode(value ?? '');
            return code.isEmpty || !validBarcode(code)
                ? 'Nhập barcode hợp lệ (tối đa 128 ký tự ASCII).'
                : null;
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, normalizeBarcode(_input.text));
          }
        },
        child: const Text('Dùng mã này'),
      ),
    ],
  );
}
