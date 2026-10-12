import 'dart:async';
import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import '../protocol/message_protocol.dart';
import '../utils/logger.dart';

typedef MessageHandler = Future<PluginResponse> Function(PluginRequest request);
typedef BatchHandler = Future<List<PluginResponse>> Function(
  List<PluginRequest> requests,
  BatchOptions options,
);

class MessageBridge {
  WebViewController? _webViewController;
  MessageHandler? _messageHandler;
  BatchHandler? _batchHandler;

  final _messageStreamController = StreamController<BridgeMessage>.broadcast();

  Stream<BridgeMessage> get messageStream => _messageStreamController.stream;

  bool _isReady = false;
  final List<String> _pendingJsMessages = [];
  static const int _maxPendingMessages = 200;

  bool _disposed = false;

  void setWebViewController(WebViewController controller) {
    _webViewController = controller;
  }

  void setMessageHandler(MessageHandler handler) {
    _messageHandler = handler;
  }

  void setBatchHandler(BatchHandler handler) {
    _batchHandler = handler;
  }

  /// وقتی صفحه جدید load می‌شود، bridge را reset کن
  void resetBridgeState() {
    _isReady = false;
    _pendingJsMessages.clear();
  }

  void onBridgeReady() {
    _isReady = true;
    BridgeLogger.info('Bridge',
        'JS Bridge is ready, flushing ${_pendingJsMessages.length} pending messages');

    final messages = List<String>.from(_pendingJsMessages);
    _pendingJsMessages.clear();

    for (final message in messages) {
      _runJsDirect(message);
    }
  }

  WebViewController get _controller {
    if (_webViewController == null) {
      throw StateError('WebViewController not set');
    }
    return _webViewController!;
  }

  Future<void> handleIncomingMessage(Map<String, dynamic> json) async {
    if (_disposed) return;

    final startTime = DateTime.now();

    try {
      // تشخیص نوع پیام
      final type = json['type'] as String?;

      if (type == 'batch') {
        await _handleBatchRequest(json);
        return;
      }

      // بررسی فیلدهای ضروری قبل از parse
      if (!json.containsKey('plugin') || !json.containsKey('method')) {
        final requestId = json['requestId'] as String? ?? 'unknown';
        await _sendError(
          requestId,
          const PluginError(
            code: PluginErrorCode.invalidArgs,
            message: 'Missing required fields: plugin, method',
          ),
        );
        return;
      }

      final request = PluginRequest.fromJson(json);

      if (!_messageStreamController.isClosed) {
        _messageStreamController.add(BridgeMessage.incoming(request));
      }

      BridgeLogger.info(
        'Bridge',
        'Incoming: ${request.plugin}.${request.method} [${request.requestId}]',
      );

      if (_messageHandler == null) {
        await _sendError(
          request.requestId,
          const PluginError(
            code: PluginErrorCode.executionError,
            message: 'No message handler registered',
          ),
        );
        return;
      }

      final response = await _messageHandler!(request);

      final processingTime =
          DateTime.now().difference(startTime).inMilliseconds;

      final responseWithMeta = PluginResponse(
        requestId: response.requestId,
        timestamp: response.timestamp,
        success: response.success,
        data: response.data,
        error: response.error,
        metadata: ResponseMetadata(
          processingTimeMs: processingTime,
          pluginVersion: response.metadata.pluginVersion,
          fromCache: response.metadata.fromCache,
        ),
      );

      await _sendResponse(responseWithMeta);

      if (!_messageStreamController.isClosed) {
        _messageStreamController.add(BridgeMessage.outgoing(responseWithMeta));
      }
    } catch (e, stackTrace) {
      BridgeLogger.error('Bridge', 'Error handling message: $e');

      final requestId = json['requestId'] as String? ?? 'unknown';
      await _sendError(
        requestId,
        PluginError(
          code: PluginErrorCode.executionError,
          message: e.toString(),
          stackTrace: stackTrace.toString(),
        ),
      );
    }
  }

  Future<void> _handleBatchRequest(Map<String, dynamic> json) async {
    final batchId = json['batchId'] as String;
    final requestsJson = json['requests'] as List<dynamic>;
    final optionsJson = json['options'] as Map<String, dynamic>?;

    final requests = requestsJson
        .map((r) => PluginRequest.fromJson(r as Map<String, dynamic>))
        .toList();

    final options = optionsJson != null
        ? BatchOptions(
            parallel: optionsJson['parallel'] as bool? ?? true,
            stopOnError: optionsJson['stopOnError'] as bool? ?? false,
            timeoutMs: optionsJson['timeoutMs'] as int?,
          )
        : BatchOptions.defaults();

    BridgeLogger.info(
      'Bridge',
      'Batch request: $batchId (${requests.length} requests)',
    );

    List<PluginResponse> responses;

    if (_batchHandler != null) {
      responses = await _batchHandler!(requests, options);
    } else {
      responses = [];
      for (final request in requests) {
        if (_messageHandler != null) {
          try {
            final response = await _messageHandler!(request);
            responses.add(response);
            if (options.stopOnError && !response.success) break;
          } catch (e) {
            responses.add(
              PluginResponse.failure(
                requestId: request.requestId,
                error: PluginError(
                  code: PluginErrorCode.executionError,
                  message: e.toString(),
                ),
              ),
            );
            if (options.stopOnError) break;
          }
        }
      }
    }

    await _sendBatchResponse(batchId, responses);
  }

  Future<void> _sendResponse(PluginResponse response) async {
    final responseJson = jsonEncode(response.toJson());
    final escapedId = _escapeJsString(response.requestId);
    final js = 'window.__resolveCall("$escapedId", $responseJson);';
    await _runJs(js);
  }

  Future<void> _sendError(String requestId, PluginError error) async {
    final response = PluginResponse.failure(
      requestId: requestId,
      error: error,
    );
    await _sendResponse(response);
  }

  Future<void> _sendBatchResponse(
    String batchId,
    List<PluginResponse> responses,
  ) async {
    final escapedId = _escapeJsString(batchId);
    final resultsJson = jsonEncode({
      'results': responses.map((r) => r.toJson()).toList(),
    });
    final js = 'window.__resolveBatch("$escapedId", $resultsJson);';
    await _runJs(js);
  }

  Future<void> emitEvent(String event, dynamic data) async {
    if (_disposed) return;
    final escapedEvent = _escapeJsString(event);
    final dataJson = _sanitizeJsonForJs(jsonEncode(data));
    final js = 'window.__emitEvent("$escapedEvent", $dataJson);';
    await _runJs(js);
  }

  /// Sanitize JSON string for safe embedding in JS
  String _sanitizeJsonForJs(String json) {
    return json
        .replaceAll('</script>', '<\\/script>')
        .replaceAll('<!--', '<\\!--');
  }

  String _escapeJsString(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  Future<void> _runJs(String script) async {
    if (_disposed) return;

    if (!_isReady) {
      if (_pendingJsMessages.length >= _maxPendingMessages) {
        BridgeLogger.warn(
          'Bridge',
          'Pending message queue full (${_pendingJsMessages.length}), dropping oldest',
        );
        _pendingJsMessages.removeAt(0);
      }
      _pendingJsMessages.add(script);
      return;
    }
    await _runJsDirect(script);
  }

  Future<void> _runJsDirect(String script) async {
    try {
      await _controller.runJavaScript(script);
    } catch (e) {
      BridgeLogger.error('Bridge', 'JS execution error: $e');
    }
  }

  void dispose() {
    _disposed = true;
    _pendingJsMessages.clear();
    if (!_messageStreamController.isClosed) {
      _messageStreamController.close();
    }
  }
}

enum BridgeMessageDirection { incoming, outgoing }

class BridgeMessage {
  final BridgeMessageDirection direction;
  final BaseMessage message;
  final DateTime timestamp;

  const BridgeMessage({
    required this.direction,
    required this.message,
    required this.timestamp,
  });

  factory BridgeMessage.incoming(BaseMessage message) => BridgeMessage(
        direction: BridgeMessageDirection.incoming,
        message: message,
        timestamp: DateTime.now(),
      );

  factory BridgeMessage.outgoing(BaseMessage message) => BridgeMessage(
        direction: BridgeMessageDirection.outgoing,
        message: message,
        timestamp: DateTime.now(),
      );
}
