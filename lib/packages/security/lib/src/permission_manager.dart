import 'dart:async';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

enum PermissionStatus {
  granted,
  denied,
  pending,
  notDetermined,
  permanentlyDenied,
}

abstract class PermissionProvider {
  Future<PermissionStatus> checkPermission(String permission);
  Future<PermissionStatus> requestPermission(String permission);
}

class StaticPermissionProvider implements PermissionProvider {
  final Map<String, PermissionStatus> grants;
  final PermissionStatus defaultStatus;

  const StaticPermissionProvider({
    required this.grants,
    this.defaultStatus = PermissionStatus.denied,
  });

  @override
  Future<PermissionStatus> checkPermission(String permission) async {
    return grants[permission] ?? defaultStatus;
  }

  @override
  Future<PermissionStatus> requestPermission(String permission) async {
    return grants[permission] ?? defaultStatus;
  }
}

class NativePermissionProvider implements PermissionProvider {
  final PermissionStatus fallbackStatus;

  const NativePermissionProvider({
    this.fallbackStatus = PermissionStatus.denied,
  });

  @override
  Future<PermissionStatus> checkPermission(String permission) async {
    final phPermission = _mapPermission(permission);
    if (phPermission == null) return fallbackStatus;

    final status = await phPermission.status;
    return _mapStatus(status);
  }

  @override
  Future<PermissionStatus> requestPermission(String permission) async {
    final phPermission = _mapPermission(permission);
    if (phPermission == null) return fallbackStatus;

    final status = await phPermission.request();
    return _mapStatus(status);
  }

  ph.Permission? _mapPermission(String permission) {
    switch (permission) {
      case 'camera':
        return ph.Permission.camera;
      case 'storage':
        return ph.Permission.storage;
      case 'manageExternalStorage':
        return ph.Permission.manageExternalStorage;
      case 'location':
        return ph.Permission.locationWhenInUse;
      case 'locationAlways':
        return ph.Permission.locationAlways;
      case 'microphone':
        return ph.Permission.microphone;
      case 'photos':
        return ph.Permission.photos;
      case 'notification':
        return ph.Permission.notification;
      case 'contacts':
        return ph.Permission.contacts;
      case 'bluetooth':
        return ph.Permission.bluetooth;
      default:
        BridgeLogger.warn(
          'PermissionProvider',
          'Unknown permission: $permission',
        );
        return null;
    }
  }

  PermissionStatus _mapStatus(ph.PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return PermissionStatus.granted;
    } else if (status.isPermanentlyDenied) {
      return PermissionStatus.permanentlyDenied;
    } else if (status.isDenied) {
      return PermissionStatus.denied;
    } else if (status.isRestricted) {
      return PermissionStatus.denied;
    }
    return PermissionStatus.notDetermined;
  }
}

class PermissionManager {
  final Map<String, PermissionPolicy> _policies = {};
  final Map<String, PermissionStatus> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  PermissionProvider? _provider;

  final Duration cacheTtl;

  PermissionManager({
    this.cacheTtl = const Duration(minutes: 5),
  });

  void setProvider(PermissionProvider provider) {
    _provider = provider;
    _cache.clear();
    _cacheTimestamps.clear();
  }

  void addPolicy(String plugin, PermissionPolicy policy) {
    _policies[plugin] = policy;
  }

  Future<bool> check(String permission) async {
    final status = await checkStatus(permission);
    return status == PermissionStatus.granted;
  }

  Future<bool> request(String permission) async {
    final status = await requestStatus(permission);
    return status == PermissionStatus.granted;
  }

  Future<PermissionStatus> checkStatus(String permission) async {
    if (_cache.containsKey(permission)) {
      final timestamp = _cacheTimestamps[permission];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < cacheTtl) {
        final cached = _cache[permission]!;
        BridgeLogger.debug(
          'PermissionManager',
          'Permission "$permission" (cached): ${cached.name}',
        );
        return cached;
      } else {
        _cache.remove(permission);
        _cacheTimestamps.remove(permission);
      }
    }

    if (_provider == null) {
      BridgeLogger.warn(
        'PermissionManager',
        'No provider set, denying permission: $permission',
      );
      return PermissionStatus.denied;
    }

    final status = await _provider!.checkPermission(permission);
    _cache[permission] = status;
    _cacheTimestamps[permission] = DateTime.now();

    BridgeLogger.debug(
      'PermissionManager',
      'Permission "$permission": ${status.name}',
    );

    return status;
  }

  Future<PermissionStatus> requestStatus(String permission) async {
    if (_provider == null) {
      BridgeLogger.warn(
        'PermissionManager',
        'No provider set, cannot request: $permission',
      );
      return PermissionStatus.denied;
    }

    final status = await _provider!.requestPermission(permission);
    _cache[permission] = status;
    _cacheTimestamps[permission] = DateTime.now();

    BridgeLogger.info(
      'PermissionManager',
      'Permission requested "$permission": ${status.name}',
    );

    return status;
  }

  Future<Map<String, bool>> checkAll(List<String> permissions) async {
    final results = <String, bool>{};
    for (final permission in permissions) {
      results[permission] = await check(permission);
    }
    return results;
  }

  Future<Map<String, PermissionStatus>> checkManyStatuses(
    List<String> permissions,
  ) async {
    final results = <String, PermissionStatus>{};
    for (final permission in permissions) {
      results[permission] = await checkStatus(permission);
    }
    return results;
  }

  Future<Map<String, PermissionStatus>> requestManyStatuses(
    List<String> permissions,
  ) async {
    final results = <String, PermissionStatus>{};
    for (final permission in permissions) {
      results[permission] = await requestStatus(permission);
    }
    return results;
  }

  Future<bool> checkPlugin(String pluginName) async {
    final policy = _policies[pluginName];
    if (policy == null) return true;

    for (final permission in policy.required) {
      final granted = await check(permission);
      if (!granted) return false;
    }
    return true;
  }

  Future<bool> openSettings() async {
    return ph.openAppSettings();
  }

  void invalidateCache([String? permission]) {
    if (permission != null) {
      _cache.remove(permission);
      _cacheTimestamps.remove(permission);
    } else {
      _cache.clear();
      _cacheTimestamps.clear();
    }
  }

  Map<String, PermissionStatus> get currentStatus => Map.unmodifiable(_cache);

  bool get hasProvider => _provider != null;
}

class PermissionPolicy {
  final List<String> required;
  final List<String> optional;

  const PermissionPolicy({
    required this.required,
    this.optional = const [],
  });

  factory PermissionPolicy.fromJson(Map<String, dynamic> json) {
    return PermissionPolicy(
      required: List<String>.from(json['required'] as List? ?? []),
      optional: List<String>.from(json['optional'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'required': required,
        'optional': optional,
      };
}
