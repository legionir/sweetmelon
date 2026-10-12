import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef QrEventEmitter = Future<void> Function(String event, dynamic data);

class QrScannerPlugin extends Plugin {
  final QrEventEmitter? eventEmitter;

  /// نگه‌داشتن context برای نمایش scanner overlay
  static GlobalKey<NavigatorState>? navigatorKey;

  QrScannerPlugin({this.eventEmitter});

  @override
  String get name => 'qrScanner';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'QR and barcode scanner plugin';

  @override
  List<String> get requiredPermissions => ['camera'];

  @override
  List<String> get supportedMethods => [
        'scan',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'scan':
        return _scan(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'supportedFormats': [
            'qr',
            'ean13',
            'ean8',
            'code128',
            'code39',
            'code93',
            'upcA',
            'upcE',
            'itf',
            'pdf417',
            'aztec',
            'dataMatrix',
            'codabar',
          ],
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _scan(Map<String, dynamic> args) async {
    final completer = Completer<Map<String, dynamic>>();
    final timeoutMs = (args['timeoutMs'] as num?)?.toInt() ?? 60000;

    Timer? timeoutTimer;

    if (timeoutMs > 0) {
      timeoutTimer = Timer(Duration(milliseconds: timeoutMs), () {
        if (!completer.isCompleted) {
          completer.complete({
            'scanned': false,
            'reason': 'timeout',
          });
          _closeScannerOverlay();
        }
      });
    }

    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    bool scanProcessed = false;

    void onDetect(BarcodeCapture capture) {
      if (scanProcessed) return;
      if (capture.barcodes.isEmpty) return;

      final barcode = capture.barcodes.first;

      if (barcode.rawValue == null || barcode.rawValue!.isEmpty) return;

      scanProcessed = true;
      timeoutTimer?.cancel();

      final result = {
        'scanned': true,
        'value': barcode.rawValue,
        'format': barcode.format.name,
        'type': _classifyContent(barcode.rawValue!),
        'timestamp': DateTime.now().toIso8601String(),
      };

      controller.dispose();
      _closeScannerOverlay();

      if (!completer.isCompleted) {
        completer.complete(result);
      }

      if (eventEmitter != null) {
        eventEmitter!('qrScanner.scanned', result);
      }
    }

    // Scanner overlay نمایش بده
    _showScannerOverlay(
      controller: controller,
      onDetect: onDetect,
      onCancel: () {
        timeoutTimer?.cancel();
        controller.dispose();
        if (!completer.isCompleted) {
          completer.complete({
            'scanned': false,
            'reason': 'cancelled',
          });
        }
      },
    );

    return completer.future;
  }

  String _classifyContent(String value) {
    final lower = value.toLowerCase();

    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return 'url';
    }
    if (lower.startsWith('tel:')) return 'phone';
    if (lower.startsWith('mailto:')) return 'email';
    if (lower.startsWith('smsto:') || lower.startsWith('sms:')) return 'sms';
    if (lower.startsWith('wifi:')) return 'wifi';
    if (lower.startsWith('geo:')) return 'geo';
    if (lower.startsWith('begin:vcard')) return 'vcard';

    return 'text';
  }

  void _showScannerOverlay({
    required MobileScannerController controller,
    required void Function(BarcodeCapture) onDetect,
    required VoidCallback onCancel,
  }) {
    final context = navigatorKey?.currentContext;
    if (context == null) {
      BridgeLogger.error('QrScanner', 'No navigator context available');
      onCancel();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ScannerOverlayPage(
          controller: controller,
          onDetect: onDetect,
          onCancel: onCancel,
        ),
      ),
    );
  }

  void _closeScannerOverlay() {
    final context = navigatorKey?.currentContext;
    if (context != null) {
      try {
        Navigator.of(context).pop();
      } catch (_) {}
    }
  }
}

class _ScannerOverlayPage extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onCancel;

  const _ScannerOverlayPage({
    required this.controller,
    required this.onDetect,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            onCancel();
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Scan QR / Barcode',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
