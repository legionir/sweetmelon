import 'package:flutter/material.dart';

/// Context Provider مرکزی — جایگزین QrScannerPlugin.navigatorKey
/// همه پلاگین‌ها از این استفاده می‌کنن
class AppContext {
  static final AppContext _instance = AppContext._();
  factory AppContext() => _instance;
  AppContext._();

  GlobalKey<NavigatorState>? _navigatorKey;
  GlobalKey<ScaffoldMessengerState>? _scaffoldKey;

  /// ست شدن توسط BridgeApp
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  void setScaffoldKey(GlobalKey<ScaffoldMessengerState> key) {
    _scaffoldKey = key;
  }

  /// Clears the app-owned keys. This is useful when a test or an embedding
  /// replaces the Flutter application tree.
  void reset() {
    _navigatorKey = null;
    _scaffoldKey = null;
  }

  /// دسترسی به navigator key
  GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;

  /// دسترسی به BuildContext فعلی
  BuildContext? get context => _navigatorKey?.currentContext;

  /// دسترسی به ScaffoldMessenger
  ScaffoldMessengerState? get scaffoldMessenger => _scaffoldKey?.currentState;

  /// آیا context در دسترس هست؟
  bool get hasContext => context != null;

  /// نمایش overlay (مثل scanner, browser)
  Future<T?> pushPage<T>(Widget page) {
    final ctx = context;
    if (ctx == null) {
      throw StateError('No navigator context available');
    }
    return Navigator.of(ctx).push<T>(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  /// بستن overlay
  void popPage<T>([T? result]) {
    final ctx = context;
    if (ctx != null) {
      try {
        Navigator.of(ctx).pop(result);
      } catch (_) {}
    }
  }

  /// نمایش dialog
  Future<T?> showAppDialog<T>(Widget dialog) {
    final ctx = context;
    if (ctx == null) {
      throw StateError('No navigator context available');
    }
    return showDialog<T>(context: ctx, builder: (_) => dialog);
  }

  /// نمایش bottom sheet
  Future<T?> showAppBottomSheet<T>(Widget sheet) {
    final ctx = context;
    if (ctx == null) {
      throw StateError('No navigator context available');
    }
    return showModalBottomSheet<T>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }

  /// نمایش snackbar
  void showSnackBar(SnackBar snackBar) {
    final messenger = scaffoldMessenger;
    if (messenger != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(snackBar);
    } else {
      final ctx = context;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx)
          ..hideCurrentSnackBar()
          ..showSnackBar(snackBar);
      }
    }
  }

  /// MediaQuery
  MediaQueryData? get mediaQuery {
    final ctx = context;
    if (ctx == null) return null;
    return MediaQuery.of(ctx);
  }
}
