import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef SocialLoginEventEmitter = Future<void> Function(
  String event,
  dynamic data,
);

class SocialLoginPlugin extends Plugin {
  final SocialLoginEventEmitter? eventEmitter;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  SocialLoginPlugin({this.eventEmitter});

  @override
  String get name => 'socialLogin';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Social login (Google, phone, anonymous)';

  @override
  List<String> get supportedMethods => [
        'signInWithGoogle',
        'signInWithPhone',
        'verifyPhoneCode',
        'signInAnonymously',
        'linkWithGoogle',
        'linkWithPhone',
        'signOut',
        'getCurrentUser',
        'isSignedIn',
        'getProviders',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'signInWithGoogle':
        return _signInWithGoogle();
      case 'signInWithPhone':
        return _signInWithPhone(args);
      case 'verifyPhoneCode':
        return _verifyPhoneCode(args);
      case 'signInAnonymously':
        return _signInAnonymously();
      case 'linkWithGoogle':
        return _linkWithGoogle();
      case 'linkWithPhone':
        return _linkWithPhone(args);
      case 'signOut':
        return _signOut();
      case 'getCurrentUser':
        return _getCurrentUser();
      case 'isSignedIn':
        return {'signedIn': FirebaseAuth.instance.currentUser != null};
      case 'getProviders':
        return _getProviders();
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return {'success': false, 'reason': 'cancelled'};
      }

      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = _userToMap(result.user);

      eventEmitter?.call('socialLogin.signedIn', {
        'provider': 'google',
        'user': user,
      });

      return {
        'success': true,
        'provider': 'google',
        'user': user,
        'isNewUser': result.additionalUserInfo?.isNewUser ?? false,
        'googleUser': {
          'email': account.email,
          'displayName': account.displayName,
          'photoUrl': account.photoUrl,
        },
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  String? _verificationId;

  Future<Map<String, dynamic>> _signInWithPhone(
    Map<String, dynamic> args,
  ) async {
    final phoneNumber = args['phoneNumber'] as String;
    final completer = Completer<Map<String, dynamic>>();

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          final result =
              await FirebaseAuth.instance.signInWithCredential(credential);

          if (!completer.isCompleted) {
            completer.complete({
              'success': true,
              'provider': 'phone',
              'autoVerified': true,
              'user': _userToMap(result.user),
            });
          }
        },
        verificationFailed: (e) {
          if (!completer.isCompleted) {
            completer.complete({
              'success': false,
              'errorCode': e.code,
              'errorMessage': e.message,
            });
          }
        },
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete({
              'success': true,
              'codeSent': true,
              'verificationId': verificationId,
              'message': 'SMS code sent to $phoneNumber',
            });
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete({
          'success': false,
          'error': e.toString(),
        });
      }
    }

    return completer.future;
  }

  Future<Map<String, dynamic>> _verifyPhoneCode(
    Map<String, dynamic> args,
  ) async {
    final code = args['code'] as String;
    final verificationId = args['verificationId'] as String? ?? _verificationId;

    if (verificationId == null) {
      return {'success': false, 'reason': 'no_verification_id'};
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );

      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);

      eventEmitter?.call('socialLogin.signedIn', {
        'provider': 'phone',
        'user': _userToMap(result.user),
      });

      return {
        'success': true,
        'provider': 'phone',
        'user': _userToMap(result.user),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _signInAnonymously() async {
    try {
      final result = await FirebaseAuth.instance.signInAnonymously();
      return {
        'success': true,
        'provider': 'anonymous',
        'user': _userToMap(result.user),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _linkWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return {'success': false, 'reason': 'cancelled'};
      }

      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);

      return {'success': true, 'linked': 'google'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _linkWithPhone(
    Map<String, dynamic> args,
  ) async {
    return _signInWithPhone(args);
  }

  Future<Map<String, dynamic>> _signOut() async {
    try {
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();

      eventEmitter?.call('socialLogin.signedOut', {
        'timestamp': DateTime.now().toIso8601String(),
      });

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _getCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'user': null, 'signedIn': false};
    return {'user': _userToMap(user), 'signedIn': true};
  }

  Map<String, dynamic> _getProviders() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'providers': <dynamic>[]};
    return {
      'providers': user.providerData.map((p) => p.providerId).toList(),
    };
  }

  Map<String, dynamic>? _userToMap(User? user) {
    if (user == null) return null;
    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'phoneNumber': user.phoneNumber,
      'emailVerified': user.emailVerified,
      'isAnonymous': user.isAnonymous,
    };
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'signInWithPhone':
      case 'linkWithPhone':
        if (args['phoneNumber'] is! String) {
          return ValidationResult.invalid('phoneNumber is required');
        }
        return ValidationResult.valid();
      case 'verifyPhoneCode':
        if (args['code'] is! String) {
          return ValidationResult.invalid('code is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
