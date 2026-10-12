import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';
import 'package:sweetmelon/plugins/qr_scanner/lib/qr_scanner_plugin.dart';

typedef BrowserEventEmitter = Future<void> Function(String event, dynamic data);

class InAppBrowserPlugin extends Plugin {
  final BrowserEventEmitter? eventEmitter;

  InAppBrowserPlugin({this.eventEmitter});

  @override
  String get name => 'inAppBrowser';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'In-app browser for external pages, OAuth, etc.';

  @override
  List<String> get supportedMethods => [
        'open',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'open':
        return _open(args);
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _open(Map<String, dynamic> args) async {
    final url = args['url'] as String;
    final title = args['title'] as String? ?? '';
    final closeOnMatch = args['closeOnUrlMatch'] as String?;
    final showToolbar = args['showToolbar'] as bool? ?? true;

    final context = QrScannerPlugin.navigatorKey?.currentContext;
    if (context == null) {
      throw StateError('No navigator context');
    }

    final completer = Completer<Map<String, dynamic>>();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _InAppBrowserPage(
          url: url,
          title: title,
          showToolbar: showToolbar,
          closeOnUrlMatch: closeOnMatch,
          eventEmitter: eventEmitter,
          onResult: (result) {
            if (!completer.isCompleted) {
              completer.complete(result);
            }
          },
        ),
      ),
    );

    return completer.future;
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    if (method == 'open') {
      final url = args['url'];
      if (url is! String || url.isEmpty) {
        return ValidationResult.invalid('url is required');
      }
    }
    return ValidationResult.valid();
  }
}

class _InAppBrowserPage extends StatefulWidget {
  final String url;
  final String title;
  final bool showToolbar;
  final String? closeOnUrlMatch;
  final BrowserEventEmitter? eventEmitter;
  final void Function(Map<String, dynamic>) onResult;

  const _InAppBrowserPage({
    required this.url,
    required this.title,
    required this.showToolbar,
    required this.closeOnUrlMatch,
    required this.eventEmitter,
    required this.onResult,
  });

  @override
  State<_InAppBrowserPage> createState() => _InAppBrowserPageState();
}

class _InAppBrowserPageState extends State<_InAppBrowserPage> {
  double _progress = 0;
  String _currentUrl = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: widget.showToolbar
          ? AppBar(
              backgroundColor: const Color(0xFF121A2D),
              title: Text(
                widget.title.isNotEmpty ? widget.title : _currentUrl,
                style: const TextStyle(fontSize: 13, color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => _close('user_closed'),
              ),
            )
          : null,
      body: Column(
        children: [
          if (_progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              minHeight: 2,
              color: const Color(0xFF6C63FF),
              backgroundColor: Colors.transparent,
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(widget.url),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
                clearCache: false,
              ),
              onProgressChanged: (controller, progress) {
                setState(() => _progress = progress / 100);
              },
              onLoadStop: (controller, url) {
                setState(() => _currentUrl = url?.toString() ?? '');

                widget.eventEmitter?.call('inAppBrowser.loadStop', {
                  'url': url?.toString(),
                });

                if (widget.closeOnUrlMatch != null &&
                    url != null &&
                    url.toString().contains(widget.closeOnUrlMatch!)) {
                  _close('url_match', url: url.toString());
                }
              },
              onReceivedError: (controller, request, error) {
                widget.eventEmitter?.call('inAppBrowser.error', {
                  'url': request.url.toString(),
                  'code': error.type.toString(),
                  'message': error.description,
                });
              },
              shouldOverrideUrlLoading: (controller, action) async {
                return NavigationActionPolicy.ALLOW;
              },
            ),
          ),
        ],
      ),
    );
  }

  void _close(String reason, {String? url}) {
    widget.onResult({
      'closed': true,
      'reason': reason,
      'lastUrl': url ?? _currentUrl,
    });
    Navigator.of(context).pop();
  }
}
