import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';
import 'package:sweetmelon/packages/security/lib/security.dart' as sec;

class PermissionPlugin extends Plugin {
  final sec.PermissionManager permissionManager;

  PermissionPlugin({
    required this.permissionManager,
  });

  static const List<String> _knownPermissions = [
    'camera',
    'storage',
    'manageExternalStorage',
    'location',
    'locationAlways',
    'microphone',
    'photos',
    'notification',
    'contacts',
    'bluetooth',
  ];

  @override
  String get name => 'permission';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Permission bridge for JS';

  @override
  List<String> get supportedMethods => [
        'check',
        'request',
        'checkMany',
        'requestMany',
        'openSettings',
        'getKnownPermissions',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'check':
        return _check(args);
      case 'request':
        return _request(args);
      case 'checkMany':
        return _checkMany(args);
      case 'requestMany':
        return _requestMany(args);
      case 'openSettings':
        return _openSettings();
      case 'getKnownPermissions':
        return {'permissions': _knownPermissions};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _check(Map<String, dynamic> args) async {
    final permission = args['permission'] as String;
    final status = await permissionManager.checkStatus(permission);
    return _statusPayload(permission, status);
  }

  Future<Map<String, dynamic>> _request(Map<String, dynamic> args) async {
    final permission = args['permission'] as String;
    final status = await permissionManager.requestStatus(permission);
    return _statusPayload(permission, status);
  }

  Future<Map<String, dynamic>> _checkMany(Map<String, dynamic> args) async {
    final permissions = List<String>.from(args['permissions'] as List);
    final statuses = await permissionManager.checkManyStatuses(permissions);

    return {
      'results': statuses.map(
        (key, value) => MapEntry(
          key,
          {
            'status': value.name,
            'granted': value == sec.PermissionStatus.granted,
          },
        ),
      ),
    };
  }

  Future<Map<String, dynamic>> _requestMany(Map<String, dynamic> args) async {
    final permissions = List<String>.from(args['permissions'] as List);
    final statuses = await permissionManager.requestManyStatuses(permissions);

    return {
      'results': statuses.map(
        (key, value) => MapEntry(
          key,
          {
            'status': value.name,
            'granted': value == sec.PermissionStatus.granted,
          },
        ),
      ),
    };
  }

  Future<Map<String, dynamic>> _openSettings() async {
    final opened = await permissionManager.openSettings();
    return {'opened': opened};
  }

  Map<String, dynamic> _statusPayload(
    String permission,
    sec.PermissionStatus status,
  ) {
    return {
      'permission': permission,
      'status': status.name,
      'granted': status == sec.PermissionStatus.granted,
      'permanentlyDenied': status == sec.PermissionStatus.permanentlyDenied,
    };
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'check':
      case 'request':
        final permission = args['permission'];
        if (permission is! String || permission.isEmpty) {
          return ValidationResult.invalid(
            'permission is required and must be a non-empty string',
          );
        }
        return ValidationResult.valid();

      case 'checkMany':
      case 'requestMany':
        final permissions = args['permissions'];
        if (permissions is! List || permissions.isEmpty) {
          return ValidationResult.invalid(
            'permissions is required and must be a non-empty list',
          );
        }
        if (permissions.any((e) => e is! String || e.isEmpty)) {
          return ValidationResult.invalid(
            'all permissions must be non-empty strings',
          );
        }
        return ValidationResult.valid();

      default:
        return ValidationResult.valid();
    }
  }
}
