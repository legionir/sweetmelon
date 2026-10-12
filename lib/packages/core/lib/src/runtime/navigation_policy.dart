// ============================================================
// NAVIGATION POLICY — which URLs a bridge-enabled WebView may load
// ============================================================
//
// Default: deny. The application's own content is loaded as `about:blank`
// (loadHtmlString). Remote http(s) documents are only allowed for hosts in
// [allowedHosts]. Every other scheme (file:, javascript:, data:, intent:,
// content:, ...) is always blocked. The same rules apply to main-frame and
// sub-frame navigations, because a sub-frame is a further trust boundary.

/// Result of evaluating a navigation request.
class NavigationVerdict {
  final bool allowed;
  final String reason;

  const NavigationVerdict._(this.allowed, this.reason);

  static const NavigationVerdict allow = NavigationVerdict._(true, 'allowed');

  factory NavigationVerdict.block(String reason) =>
      NavigationVerdict._(false, reason);
}

class NavigationPolicy {
  /// Lower-case host names that may be navigated to over https (and http when
  /// [allowInsecureHttp] is true).
  final Set<String> allowedHosts;

  /// Permits plain http for allowed hosts. Only enable in development.
  final bool allowInsecureHttp;

  const NavigationPolicy({
    this.allowedHosts = const {},
    this.allowInsecureHttp = false,
  });

  NavigationVerdict evaluate(String url, {required bool isMainFrame}) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return NavigationVerdict.block('malformed URL');
    }

    final scheme = uri.scheme.toLowerCase();

    if (scheme == 'about') {
      // Only the blank document used for application-owned HTML.
      return url == 'about:blank'
          ? NavigationVerdict.allow
          : NavigationVerdict.block('about: URL other than about:blank');
    }

    if (scheme == 'http' || scheme == 'https') {
      if (scheme == 'http' && !allowInsecureHttp) {
        return NavigationVerdict.block('insecure http is not allowed');
      }
      final host = uri.host.toLowerCase();
      if (host.isEmpty) {
        return NavigationVerdict.block('URL has no host');
      }
      if (!allowedHosts.contains(host)) {
        return NavigationVerdict.block(
          isMainFrame ? 'host not in allow-list' : 'sub-frame host not allowed',
        );
      }
      return NavigationVerdict.allow;
    }

    return NavigationVerdict.block('scheme "$scheme" is not allowed');
  }
}
