import '../utils/logger.dart';

/// Content Security Policy for WebView
class ContentSecurityPolicy {
  ContentSecurityPolicy();

  final Set<String> _allowedOrigins = {'localhost'};
  final Set<String> _blockedOrigins = {};
  final Set<String> _allowedSchemes = {'http', 'https', 'file', 'data', 'blob'};
  final Set<String> _blockedSchemes = {};
  bool _allowInlineScripts = true;
  bool _allowEval = false;
  int _maxPayloadSize = 10 * 1024 * 1024; // 10MB
  final Set<String> _allowedPlugins = {};
  final Set<String> _blockedPlugins = {};
  bool _allowAllPlugins = true;

  /// اجازه یک origin
  void allowOrigin(String origin) {
    _allowedOrigins.add(origin.toLowerCase());
  }

  /// بلاک کردن یک origin
  void blockOrigin(String origin) {
    _blockedOrigins.add(origin.toLowerCase());
  }

  /// اجازه یک scheme
  void allowScheme(String scheme) {
    _allowedSchemes.add(scheme.toLowerCase());
  }

  /// بلاک کردن scheme
  void blockScheme(String scheme) {
    _blockedSchemes.add(scheme.toLowerCase());
  }

  /// فقط پلاگین‌های خاص مجاز باشن
  void setAllowedPlugins(List<String> plugins) {
    _allowAllPlugins = false;
    _allowedPlugins.clear();
    _allowedPlugins.addAll(plugins);
  }

  /// بلاک کردن پلاگین‌های خاص
  void blockPlugins(List<String> plugins) {
    _blockedPlugins.addAll(plugins);
  }

  /// ست کردن حداکثر سایز payload
  void setMaxPayloadSize(int bytes) {
    _maxPayloadSize = bytes;
  }

  /// اعتبارسنجی یک درخواست URL
  bool isUrlAllowed(String url) {
    try {
      final uri = Uri.parse(url);

      // بررسی scheme
      if (_blockedSchemes.contains(uri.scheme.toLowerCase())) {
        BridgeLogger.warn('CSP', 'Blocked scheme: ${uri.scheme}');
        return false;
      }

      if (_allowedSchemes.isNotEmpty &&
          uri.scheme.isNotEmpty &&
          !_allowedSchemes.contains(uri.scheme.toLowerCase())) {
        BridgeLogger.warn('CSP', 'Unknown scheme: ${uri.scheme}');
        return false;
      }

      // بررسی origin
      if (uri.host.isNotEmpty) {
        final host = uri.host.toLowerCase();

        if (_blockedOrigins.contains(host)) {
          BridgeLogger.warn('CSP', 'Blocked origin: $host');
          return false;
        }
      }

      return true;
    } catch (e) {
      BridgeLogger.error('CSP', 'URL parse error: $e');
      return false;
    }
  }

  /// اعتبارسنجی دسترسی به پلاگین
  bool isPluginAllowed(String pluginName) {
    if (_blockedPlugins.contains(pluginName)) {
      BridgeLogger.warn('CSP', 'Blocked plugin: $pluginName');
      return false;
    }

    if (!_allowAllPlugins && !_allowedPlugins.contains(pluginName)) {
      BridgeLogger.warn('CSP', 'Plugin not in whitelist: $pluginName');
      return false;
    }

    return true;
  }

  /// اعتبارسنجی سایز payload
  bool isPayloadSizeAllowed(int bytes) {
    if (bytes > _maxPayloadSize) {
      BridgeLogger.warn(
        'CSP',
        'Payload too large: $bytes bytes (max: $_maxPayloadSize)',
      );
      return false;
    }
    return true;
  }

  /// تولید CSP meta tag برای inject در HTML
  String generateMetaTag() {
    final parts = <String>[];

    parts.add("default-src 'self'");

    final scriptSrc = <String>["'self'"];
    if (_allowInlineScripts) scriptSrc.add("'unsafe-inline'");
    if (_allowEval) scriptSrc.add("'unsafe-eval'");
    parts.add('script-src ${scriptSrc.join(' ')}');

    parts.add("style-src 'self' 'unsafe-inline'");
    parts.add("img-src 'self' data: blob: https:");
    parts.add("font-src 'self' data:");
    parts.add("connect-src 'self' https: wss: ws:");
    parts.add("media-src 'self' blob:");

    return parts.join('; ');
  }

  /// تنظیمات production
  factory ContentSecurityPolicy.production() {
    final csp = ContentSecurityPolicy();
    csp._allowEval = false;
    csp._allowInlineScripts = false;
    csp._maxPayloadSize = 5 * 1024 * 1024;
    return csp;
  }

  /// تنظیمات development
  factory ContentSecurityPolicy.development() {
    final csp = ContentSecurityPolicy();
    csp._allowEval = true;
    csp._allowInlineScripts = true;
    csp._maxPayloadSize = 50 * 1024 * 1024;
    return csp;
  }

  Map<String, dynamic> get stats => {
        'allowedOrigins': _allowedOrigins.toList(),
        'blockedOrigins': _blockedOrigins.toList(),
        'allowedSchemes': _allowedSchemes.toList(),
        'allowInlineScripts': _allowInlineScripts,
        'allowEval': _allowEval,
        'maxPayloadSizeMB': _maxPayloadSize / (1024 * 1024),
        'allowAllPlugins': _allowAllPlugins,
        'allowedPlugins': _allowedPlugins.toList(),
        'blockedPlugins': _blockedPlugins.toList(),
      };
}
