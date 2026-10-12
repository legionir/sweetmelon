import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../bridge/message_bridge.dart';
import '../utils/logger.dart';
import 'asset_server.dart';

class WebViewHost extends StatefulWidget {
  /// بارگذاری از URL خارجی
  final String? initialUrl;

  /// بارگذاری HTML inline
  final String? initialHtml;

  /// بارگذاری از assets/www/ با local HTTP server
  final bool loadFromAssets;

  final WebViewHostConfig config;
  final AssetServerConfig assetConfig;
  final MessageBridge bridge;
  final VoidCallback? onPageLoaded;
  final Function(String error)? onError;

  const WebViewHost({
    super.key,
    this.initialUrl,
    this.initialHtml,
    this.loadFromAssets = false,
    required this.config,
    required this.assetConfig,
    required this.bridge,
    this.onPageLoaded,
    this.onError,
  });

  @override
  State<WebViewHost> createState() => _WebViewHostState();
}

class _WebViewHostState extends State<WebViewHost> with WidgetsBindingObserver {
  late final WebViewController _controller;
  AssetServer? _assetServer;
  bool _isReady = false;
  bool _bridgeInjected = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
    _loadContent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _assetServer?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // WebView pause
    } else if (state == AppLifecycleState.resumed) {
      // WebView resume
    }
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(_buildNavigationDelegate())
      ..addJavaScriptChannel(
        'flutterBridge',
        onMessageReceived: _onJsMessage,
      )
      ..addJavaScriptChannel(
        '__bridgeInternal',
        onMessageReceived: _onInternalMessage,
      )
      ..setBackgroundColor(const Color(0xFF0A0A1A));

    // Apply config
    if (widget.config.enableDebugging) {
      // Android debugging
      // WebViewController اجازه setWebContentsDebuggingEnabled رو نمی‌ده مستقیم
      // ولی از طریق platform specific settings قابل تنظیمه
    }

    // On Android a WebView does not open <input type="file"> pickers by
    // itself; the app has to handle the request. Without this, the web
    // fallback for attachments and camera/gallery silently does nothing.
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setOnShowFileSelector(_onShowFileSelector);
    }

    widget.bridge.setWebViewController(_controller);
  }

  /// Handles file inputs requested by the page (attachments, camera capture).
  /// Returns URIs understood by the WebView; an empty list means cancelled.
  Future<List<String>> _onShowFileSelector(FileSelectorParams params) async {
    try {
      final acceptTypes =
          params.acceptTypes.map((t) => t.toLowerCase()).toList();
      final multiple = params.mode == FileSelectorMode.openMultiple;
      final imageOnly = acceptTypes.isNotEmpty &&
          acceptTypes.every((t) => t.startsWith('image/') || t == 'image/*');

      if (imageOnly) {
        final picker = ImagePicker();
        if (params.isCaptureEnabled) {
          final photo = await picker.pickImage(source: ImageSource.camera);
          return photo == null ? <String>[] : [Uri.file(photo.path).toString()];
        }
        if (multiple) {
          final images = await picker.pickMultiImage();
          return images.map((f) => Uri.file(f.path).toString()).toList();
        }
        final image = await picker.pickImage(source: ImageSource.gallery);
        return image == null ? <String>[] : [Uri.file(image.path).toString()];
      }

      final result = await fp.FilePicker.platform.pickFiles(
        allowMultiple: multiple,
        type: fp.FileType.any,
      );
      if (result == null) return <String>[];
      return result.files
          .where((f) => f.path != null)
          .map((f) => Uri.file(f.path!).toString())
          .toList();
    } catch (e) {
      BridgeLogger.error('WebView', 'File selection failed: $e');
      return <String>[];
    }
  }

  Future<void> _loadContent() async {
    try {
      if (widget.loadFromAssets) {
        await _loadFromAssetServer();
      } else if (widget.initialHtml != null) {
        await _controller.loadHtmlString(widget.initialHtml!);
      } else if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
        await _controller.loadRequest(Uri.parse(widget.initialUrl!));
      }
    } catch (e) {
      BridgeLogger.error('WebView', 'Failed to load content: $e');
      if (mounted) {
        setState(() => _loadError = e.toString());
      }
      widget.onError?.call(e.toString());
    }
  }

  /// شروع AssetServer و load کردن index.html
  Future<void> _loadFromAssetServer() async {
    BridgeLogger.info('WebView', 'Starting asset server...');

    _assetServer = AssetServer(config: widget.assetConfig);
    final url = await _assetServer!.start();

    BridgeLogger.info('WebView', 'Loading from: $url');
    await _controller.loadRequest(Uri.parse(url));
  }

  NavigationDelegate _buildNavigationDelegate() {
    return NavigationDelegate(
      onPageStarted: (url) {
        BridgeLogger.info('WebView', 'Page started: $url');

        // Reset bridge state وقتی صفحه جدید load می‌شود
        widget.bridge.resetBridgeState();
        _bridgeInjected = false;

        if (mounted) {
          setState(() {
            _isReady = false;
            _loadError = null;
          });
        }
      },
      onPageFinished: (url) async {
        BridgeLogger.info('WebView', 'Page finished: $url');
        await _injectBridgeScript();
        if (mounted) {
          setState(() => _isReady = true);
        }
        widget.onPageLoaded?.call();
      },
      onWebResourceError: (error) {
        BridgeLogger.error(
          'WebView',
          'Resource error [${error.errorCode}]: ${error.description}',
        );
        // فقط main frame error رو نشون بده
        if (error.isForMainFrame ?? false) {
          if (mounted) {
            setState(() => _loadError = error.description);
          }
          widget.onError?.call(error.description);
        }
      },
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);

        // اجازه localhost (asset server)
        if (uri != null && uri.host == 'localhost') {
          return NavigationDecision.navigate;
        }

        // اجازه file URIs
        if (uri != null && uri.scheme == 'file') {
          return NavigationDecision.navigate;
        }

        // اجازه data URIs
        if (uri != null && uri.scheme == 'data') {
          return NavigationDecision.navigate;
        }

        // اجازه about:blank
        if (request.url == 'about:blank') {
          return NavigationDecision.navigate;
        }

        // بررسی allowed hosts
        if (widget.config.allowedHosts.isNotEmpty) {
          if (uri != null &&
              uri.host.isNotEmpty &&
              !widget.config.allowedHosts.contains(uri.host) &&
              uri.host != 'localhost') {
            BridgeLogger.warn(
              'WebView',
              'Blocked navigation to: ${request.url}',
            );
            return NavigationDecision.prevent;
          }
        }

        return NavigationDecision.navigate;
      },
    );
  }

  Future<void> _injectBridgeScript() async {
    if (_bridgeInjected) return;
    _bridgeInjected = true;

    const script = r'''
      (function() {
        'use strict';
        if (window.__NativeBridgeInitialized) return;
        window.__NativeBridgeInitialized = true;
        
        window.__pending = {};
        window.__eventListeners = {};
        window.__requestCount = 0;
        
        function generateId() {
          if (typeof crypto !== 'undefined' && crypto.randomUUID) {
            return crypto.randomUUID();
          }
          return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(
            /[xy]/g,
            function(c) {
              var r = Math.random() * 16 | 0;
              var v = c === 'x' ? r : (r & 0x3 | 0x8);
              return v.toString(16);
            }
          );
        }
        
        window.Native = {
          call: function(options) {
            var plugin = options.plugin;
            var method = options.method;
            var args = options.args || {};
            var version = options.version || '1.0.0';
            var timeout = options.timeout != null ? options.timeout : 30000;

            return new Promise(function(resolve, reject) {
              var id = generateId();
              var timeoutHandle = null;
              
              if (timeout > 0) {
                timeoutHandle = setTimeout(function() {
                  if (window.__pending[id]) {
                    delete window.__pending[id];
                    reject({
                      code: 'TIMEOUT',
                      message: 'Request timed out after ' + timeout + 'ms',
                      requestId: id
                    });
                  }
                }, timeout);
              }
              
              window.__pending[id] = {
                resolve: function(data) {
                  if (timeoutHandle) clearTimeout(timeoutHandle);
                  resolve(data);
                },
                reject: function(error) {
                  if (timeoutHandle) clearTimeout(timeoutHandle);
                  reject(error);
                }
              };
              
              var message = JSON.stringify({
                requestId: id,
                plugin: plugin,
                version: version,
                method: method,
                args: args,
                timestamp: new Date().toISOString(),
                metadata: { headers: {} }
              });
              
              try {
                window.flutterBridge.postMessage(message);
                window.__requestCount++;
              } catch (e) {
                delete window.__pending[id];
                if (timeoutHandle) clearTimeout(timeoutHandle);
                reject({
                  code: 'BRIDGE_ERROR',
                  message: 'Failed to send message: ' + e.message
                });
              }
            });
          },

          batch: function(requests, options) {
            options = options || {};
            var batchId = generateId();

            var mappedRequests = requests.map(function(r) {
              return {
                requestId: generateId(),
                plugin: r.plugin,
                method: r.method,
                args: r.args || {},
                version: r.version || '1.0.0',
                timestamp: new Date().toISOString(),
                metadata: { headers: {} }
              };
            });

            var timeout = options.timeout || 60000;

            return new Promise(function(resolve, reject) {
              var timeoutHandle = setTimeout(function() {
                if (window.__pending[batchId]) {
                  delete window.__pending[batchId];
                  reject({
                    code: 'TIMEOUT',
                    message: 'Batch request timed out'
                  });
                }
              }, timeout);

              window.__pending[batchId] = {
                resolve: function(data) {
                  clearTimeout(timeoutHandle);
                  resolve(data);
                },
                reject: function(error) {
                  clearTimeout(timeoutHandle);
                  reject(error);
                }
              };

              var batchMessage = JSON.stringify({
                type: 'batch',
                batchId: batchId,
                requests: mappedRequests,
                options: {
                  parallel: options.parallel !== false,
                  stopOnError: options.stopOnError || false,
                  timeoutMs: options.timeout
                }
              });

              try {
                window.flutterBridge.postMessage(batchMessage);
              } catch (e) {
                delete window.__pending[batchId];
                clearTimeout(timeoutHandle);
                reject({
                  code: 'BRIDGE_ERROR',
                  message: 'Failed to send batch: ' + e.message
                });
              }
            });
          },

          on: function(event, callback) {
            if (!window.__eventListeners[event]) {
              window.__eventListeners[event] = [];
            }
            window.__eventListeners[event].push(callback);

            return function() {
              window.Native.off(event, callback);
            };
          },

          off: function(event, callback) {
            if (!window.__eventListeners[event]) return;
            window.__eventListeners[event] = 
              window.__eventListeners[event].filter(function(cb) {
                return cb !== callback;
              });
          },
          
          info: function() {
            return {
              initialized: true,
              pendingRequests: Object.keys(window.__pending).length,
              totalRequests: window.__requestCount,
              version: '1.0.0'
            };
          },

          ready: function() {
            return new Promise(function(resolve) {
              if (window.__NativeBridgeInitialized) {
                resolve(window.Native.info());
              } else {
                var check = setInterval(function() {
                  if (window.__NativeBridgeInitialized) {
                    clearInterval(check);
                    resolve(window.Native.info());
                  }
                }, 50);
                setTimeout(function() {
                  clearInterval(check);
                  resolve(null);
                }, 5000);
              }
            });
          }
        };
        
        window.__resolveCall = function(requestId, responseJson) {
          var response;
          try {
            response = typeof responseJson === 'string' 
              ? JSON.parse(responseJson) 
              : responseJson;
          } catch (e) {
            console.error('[Bridge] Failed to parse response:', e);
            return;
          }
            
          var pending = window.__pending[requestId];
          
          if (!pending) {
            console.warn('[Bridge] No pending request for:', requestId);
            return;
          }
          
          delete window.__pending[requestId];
          
          if (response.success) {
            pending.resolve(response.data);
          } else {
            pending.reject(response.error || {
              code: 'UNKNOWN',
              message: 'Unknown error'
            });
          }
        };
        
        window.__resolveBatch = function(batchId, responseJson) {
          var response;
          try {
            response = typeof responseJson === 'string'
              ? JSON.parse(responseJson)
              : responseJson;
          } catch (e) {
            console.error('[Bridge] Failed to parse batch response:', e);
            return;
          }
            
          var pending = window.__pending[batchId];
          if (!pending) return;
          
          delete window.__pending[batchId];
          pending.resolve(response.results);
        };
        
        window.__emitEvent = function(event, dataJson) {
          var data;
          try {
            data = typeof dataJson === 'string'
              ? JSON.parse(dataJson)
              : dataJson;
          } catch (e) {
            console.error('[Bridge] Failed to parse event data:', e);
            return;
          }
            
          var listeners = window.__eventListeners[event] || [];
          listeners.forEach(function(cb) {
            try {
              cb(data);
            } catch (e) {
              console.error('[Bridge] Event listener error:', e);
            }
          });
        };

        window.__bridgeDebug = {
          getPending: function() { return Object.keys(window.__pending); },
          getStats: function() {
            return {
              pending: Object.keys(window.__pending).length,
              total: window.__requestCount,
              listeners: Object.keys(window.__eventListeners)
            };
          },
          clearPending: function() {
            var ids = Object.keys(window.__pending);
            ids.forEach(function(id) {
              if (window.__pending[id] && window.__pending[id].reject) {
                window.__pending[id].reject({
                  code: 'CLEARED',
                  message: 'Pending request cleared manually'
                });
              }
            });
            window.__pending = {};
          }
        };
        
        try {
          window.__bridgeInternal.postMessage(JSON.stringify({
            type: 'bridge_ready',
            timestamp: new Date().toISOString()
          }));
        } catch (e) {
          console.error('[Bridge] Failed to signal ready:', e);
        }
        
        console.log('[NativeBridge] SDK initialized successfully');
      })();
    ''';

    try {
      await _controller.runJavaScript(script);
      BridgeLogger.info('WebView', 'Bridge script injected');
    } catch (e) {
      BridgeLogger.error('WebView', 'Failed to inject bridge script: $e');
    }
  }

  void _onJsMessage(JavaScriptMessage message) {
    try {
      final json = jsonDecode(message.message) as Map<String, dynamic>;
      widget.bridge.handleIncomingMessage(json);
    } catch (e) {
      BridgeLogger.error('WebView', 'Failed to parse JS message: $e');
    }
  }

  void _onInternalMessage(JavaScriptMessage message) {
    try {
      final json = jsonDecode(message.message) as Map<String, dynamic>;
      if (json['type'] == 'bridge_ready') {
        BridgeLogger.info('WebView', 'JS Bridge is ready');
        widget.bridge.onBridgeReady();
      }
    } catch (e) {
      BridgeLogger.error('WebView', 'Internal message error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),

        // Loading overlay
        if (!_isReady && _loadError == null)
          Container(
            color: const Color(0xFF0A0A1A),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF6C63FF),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Error overlay
        if (_loadError != null)
          Container(
            color: const Color(0xFF0A0A1A),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _loadError = null);
                        _loadContent();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class WebViewHostConfig {
  final bool enableDebugging;
  final bool allowFileAccess;
  final int defaultTimeoutMs;
  final List<String> allowedHosts;

  const WebViewHostConfig({
    this.enableDebugging = false,
    this.allowFileAccess = false,
    this.defaultTimeoutMs = 30000,
    this.allowedHosts = const [],
  });

  factory WebViewHostConfig.development() => const WebViewHostConfig(
        enableDebugging: true,
        allowFileAccess: true,
        defaultTimeoutMs: 60000,
      );

  factory WebViewHostConfig.production() => const WebViewHostConfig(
        enableDebugging: false,
        allowFileAccess: false,
        defaultTimeoutMs: 30000,
      );
}
