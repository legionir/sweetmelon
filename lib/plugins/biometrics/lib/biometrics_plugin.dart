import 'dart:io';

import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class BiometricsPlugin extends Plugin {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  String get name => 'biometrics';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Biometric authentication plugin (fingerprint / face)';

  @override
  List<String> get supportedMethods => [
        'isAvailable',
        'getAvailableBiometrics',
        'authenticate',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'isAvailable':
        return _isAvailable();
      case 'getAvailableBiometrics':
        return _getAvailableBiometrics();
      case 'authenticate':
        return _authenticate(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'platform': Platform.operatingSystem,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _isAvailable() async {
    final canAuth = await _auth.canCheckBiometrics;
    final isDeviceSupported = await _auth.isDeviceSupported();

    return {
      'canCheckBiometrics': canAuth,
      'isDeviceSupported': isDeviceSupported,
      'available': canAuth && isDeviceSupported,
    };
  }

  Future<Map<String, dynamic>> _getAvailableBiometrics() async {
    final biometrics = await _auth.getAvailableBiometrics();

    return {
      'biometrics': biometrics.map((b) => b.name).toList(),
      'hasFingerprint': biometrics.contains(BiometricType.fingerprint),
      'hasFace': biometrics.contains(BiometricType.face),
      'hasIris': biometrics.contains(BiometricType.iris),
      'hasStrong': biometrics.contains(BiometricType.strong),
      'hasWeak': biometrics.contains(BiometricType.weak),
    };
  }

  Future<Map<String, dynamic>> _authenticate(Map<String, dynamic> args) async {
    final reason = args['reason'] as String? ?? 'Please authenticate';
    final biometricOnly = args['biometricOnly'] as bool? ?? false;
    final stickyAuth = args['stickyAuth'] as bool? ?? true;
    final sensitiveTransaction = args['sensitiveTransaction'] as bool? ?? true;

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: stickyAuth,
          sensitiveTransaction: sensitiveTransaction,
          useErrorDialogs: true,
        ),
      );

      return {
        'authenticated': authenticated,
        'method': 'biometric',
      };
    } catch (e) {
      String errorCode = 'unknown';
      String errorMessage = e.toString();

      if (e.toString().contains(auth_error.notAvailable)) {
        errorCode = 'not_available';
        errorMessage = 'Biometric authentication not available';
      } else if (e.toString().contains(auth_error.notEnrolled)) {
        errorCode = 'not_enrolled';
        errorMessage = 'No biometrics enrolled on device';
      } else if (e.toString().contains(auth_error.lockedOut)) {
        errorCode = 'locked_out';
        errorMessage = 'Too many attempts, locked out';
      } else if (e.toString().contains(auth_error.permanentlyLockedOut)) {
        errorCode = 'permanently_locked_out';
        errorMessage = 'Permanently locked out';
      }

      BridgeLogger.error(
          'Biometrics', 'Auth error: $errorCode — $errorMessage');

      return {
        'authenticated': false,
        'errorCode': errorCode,
        'errorMessage': errorMessage,
      };
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'authenticate') {
      final reason = args['reason'];
      if (reason != null && reason is! String) {
        return ValidationResult.invalid('reason must be a string');
      }
    }
    return ValidationResult.valid();
  }
}
