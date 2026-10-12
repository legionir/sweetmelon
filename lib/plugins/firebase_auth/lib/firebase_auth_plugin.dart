import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef AuthEventEmitter = Future<void> Function(String event, dynamic data);

class FirebaseAuthPlugin extends Plugin {
  final AuthEventEmitter? eventEmitter;

  FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;
  StreamSubscription<User?>? _authStateSub;

  FirebaseAuthPlugin({this.eventEmitter});

  @override
  String get name => 'firebaseAuth';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Firebase Authentication plugin';

  @override
  List<String> get supportedMethods => [
        'getCurrentUser',
        'signInWithEmail',
        'signUpWithEmail',
        'signInWithGoogle',
        'signInAnonymously',
        'signOut',
        'sendPasswordResetEmail',
        'updatePassword',
        'updateEmail',
        'updateProfile',
        'deleteAccount',
        'reloadUser',
        'sendEmailVerification',
        'signInWithCustomToken',
        'getIdToken',
        'isSignedIn',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    try {
      _auth = FirebaseAuth.instance;
      _googleSignIn = GoogleSignIn();

      _authStateSub = _auth?.authStateChanges().listen((user) {
        if (eventEmitter != null) {
          eventEmitter!(
            'auth.stateChanged',
            {
              'user': user != null ? _userToMap(user) : null,
              'signedIn': user != null,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
      });

      BridgeLogger.info('FirebaseAuth', 'Initialized');
    } catch (e) {
      BridgeLogger.error('FirebaseAuth', 'Init failed: $e');
    }
  }

  @override
  Future<void> onDispose() async {
    await _authStateSub?.cancel();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'getCurrentUser':
        return _getCurrentUser();
      case 'signInWithEmail':
        return _signInWithEmail(args);
      case 'signUpWithEmail':
        return _signUpWithEmail(args);
      case 'signInWithGoogle':
        return _signInWithGoogle();
      case 'signInAnonymously':
        return _signInAnonymously();
      case 'signOut':
        return _signOut();
      case 'sendPasswordResetEmail':
        return _sendPasswordResetEmail(args);
      case 'updatePassword':
        return _updatePassword(args);
      case 'updateEmail':
        return _updateEmail(args);
      case 'updateProfile':
        return _updateProfile(args);
      case 'deleteAccount':
        return _deleteAccount();
      case 'reloadUser':
        return _reloadUser();
      case 'sendEmailVerification':
        return _sendEmailVerification();
      case 'signInWithCustomToken':
        return _signInWithCustomToken(args);
      case 'getIdToken':
        return _getIdToken(args);
      case 'isSignedIn':
        return {'signedIn': _auth?.currentUser != null};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'initialized': _auth != null,
          'signedIn': _auth?.currentUser != null,
          'userId': _auth?.currentUser?.uid,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Map<String, dynamic> _getCurrentUser() {
    final user = _auth?.currentUser;
    if (user == null) {
      return {'user': null, 'signedIn': false};
    }
    return {'user': _userToMap(user), 'signedIn': true};
  }

  Future<Map<String, dynamic>> _signInWithEmail(
    Map<String, dynamic> args,
  ) async {
    final email = args['email'] as String;
    final password = args['password'] as String;

    try {
      final credential = await _auth?.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      BridgeLogger.info(
          'FirebaseAuth', 'Signed in: ${credential?.user?.email}');

      return {
        'success': true,
        'user': credential?.user != null ? _userToMap(credential!.user!) : null,
        'isNewUser': credential?.additionalUserInfo?.isNewUser ?? false,
      };
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    }
  }

  Future<Map<String, dynamic>> _signUpWithEmail(
    Map<String, dynamic> args,
  ) async {
    final email = args['email'] as String;
    final password = args['password'] as String;
    final displayName = args['displayName'] as String?;

    try {
      final credential = await _auth?.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (displayName != null && credential?.user != null) {
        await credential!.user!.updateDisplayName(displayName);
        await credential.user!.reload();
      }

      await credential?.user?.sendEmailVerification();

      return {
        'success': true,
        'user': credential?.user != null ? _userToMap(credential!.user!) : null,
        'isNewUser': true,
      };
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    }
  }

  Future<Map<String, dynamic>> _signInWithGoogle() async {
    try {
      final googleAccount = await _googleSignIn?.signIn();
      if (googleAccount == null) {
        return {'success': false, 'reason': 'cancelled'};
      }

      final googleAuth = await googleAccount.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth?.signInWithCredential(credential);

      return {
        'success': true,
        'user': result?.user != null ? _userToMap(result!.user!) : null,
        'isNewUser': result?.additionalUserInfo?.isNewUser ?? false,
        'provider': 'google',
      };
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _signInAnonymously() async {
    try {
      final credential = await _auth?.signInAnonymously();
      return {
        'success': true,
        'user': credential?.user != null ? _userToMap(credential!.user!) : null,
        'isAnonymous': true,
      };
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    }
  }

  Future<Map<String, dynamic>> _signOut() async {
    await _googleSignIn?.signOut();
    await _auth?.signOut();
    BridgeLogger.info('FirebaseAuth', 'Signed out');
    return {'success': true};
  }

  Future<Map<String, dynamic>> _sendPasswordResetEmail(
    Map<String, dynamic> args,
  ) async {
    final email = args['email'] as String;
    try {
      await _auth?.sendPasswordResetEmail(email: email);
      return {'success': true, 'email': email};
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    }
  }

  Future<Map<String, dynamic>> _updatePassword(
    Map<String, dynamic> args,
  ) async {
    final newPassword = args['newPassword'] as String;
    try {
      await _auth?.currentUser?.updatePassword(newPassword);
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    }
  }

  Future<Map<String, dynamic>> _updateEmail(
    Map<String, dynamic> args,
  ) async {
    final newEmail = args['newEmail'] as String;
    try {
      await _auth?.currentUser?.verifyBeforeUpdateEmail(newEmail);
      return {'success': true, 'pendingVerification': true};
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    }
  }

  Future<Map<String, dynamic>> _updateProfile(
    Map<String, dynamic> args,
  ) async {
    final displayName = args['displayName'] as String?;
    final photoURL = args['photoURL'] as String?;

    try {
      if (displayName != null) {
        await _auth?.currentUser?.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await _auth?.currentUser?.updatePhotoURL(photoURL);
      }
      await _auth?.currentUser?.reload();
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _deleteAccount() async {
    try {
      await _auth?.currentUser?.delete();
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    }
  }

  Future<Map<String, dynamic>> _reloadUser() async {
    await _auth?.currentUser?.reload();
    return _getCurrentUser();
  }

  Future<Map<String, dynamic>> _sendEmailVerification() async {
    try {
      await _auth?.currentUser?.sendEmailVerification();
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    }
  }

  Future<Map<String, dynamic>> _signInWithCustomToken(
    Map<String, dynamic> args,
  ) async {
    final token = args['token'] as String;
    try {
      final credential = await _auth?.signInWithCustomToken(token);
      return {
        'success': true,
        'user': credential?.user != null ? _userToMap(credential!.user!) : null,
      };
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    }
  }

  Future<Map<String, dynamic>> _getIdToken(Map<String, dynamic> args) async {
    final forceRefresh = args['forceRefresh'] as bool? ?? false;
    try {
      final token = await _auth?.currentUser?.getIdToken(forceRefresh);
      return {'token': token};
    } catch (e) {
      return {'token': null, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _userToMap(User user) {
    return {
      'uid': user.uid,
      'email': user.email,
      'emailVerified': user.emailVerified,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'phoneNumber': user.phoneNumber,
      'isAnonymous': user.isAnonymous,
      'creationTime': user.metadata.creationTime?.toIso8601String(),
      'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
      'providerData': user.providerData
          .map((p) => {
                'uid': p.uid,
                'email': p.email,
                'displayName': p.displayName,
                'photoURL': p.photoURL,
                'providerId': p.providerId,
                'phoneNumber': p.phoneNumber,
              })
          .toList(),
    };
  }

  Map<String, dynamic> _authError(FirebaseAuthException e) {
    return {
      'success': false,
      'errorCode': e.code,
      'errorMessage': _localizeError(e.code),
      'originalMessage': e.message,
    };
  }

  String _localizeError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'requires-recent-login':
        return 'Please sign in again to perform this action.';
      case 'invalid-credential':
        return 'Invalid credentials.';
      default:
        return 'Authentication error: $code';
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'signInWithEmail':
      case 'signUpWithEmail':
        if (args['email'] is! String || (args['email'] as String).isEmpty) {
          return ValidationResult.invalid('email is required');
        }
        if (args['password'] is! String ||
            (args['password'] as String).isEmpty) {
          return ValidationResult.invalid('password is required');
        }
        return ValidationResult.valid();
      case 'sendPasswordResetEmail':
        if (args['email'] is! String) {
          return ValidationResult.invalid('email is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
