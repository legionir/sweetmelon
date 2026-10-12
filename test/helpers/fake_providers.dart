import 'dart:async';

import 'package:sweetmelon/packages/security/lib/security.dart';

/// Provider که permission خاصی رو deny می‌کنه
class SelectivePermissionProvider implements PermissionProvider {
  final Set<String> deniedPermissions;

  const SelectivePermissionProvider({
    this.deniedPermissions = const {},
  });

  @override
  Future<PermissionStatus> checkPermission(String permission) async {
    if (deniedPermissions.contains(permission)) {
      return PermissionStatus.denied;
    }
    return PermissionStatus.granted;
  }

  @override
  Future<PermissionStatus> requestPermission(String permission) async {
    return checkPermission(permission);
  }
}

/// Provider که بعد از n بار request، grant می‌کنه
class DelayedGrantProvider implements PermissionProvider {
  final int grantAfterAttempts;
  final Map<String, int> _attempts = {};

  DelayedGrantProvider({this.grantAfterAttempts = 2});

  @override
  Future<PermissionStatus> checkPermission(String permission) async {
    final count = _attempts[permission] ?? 0;
    return count >= grantAfterAttempts
        ? PermissionStatus.granted
        : PermissionStatus.denied;
  }

  @override
  Future<PermissionStatus> requestPermission(String permission) async {
    _attempts[permission] = (_attempts[permission] ?? 0) + 1;
    return checkPermission(permission);
  }
}
