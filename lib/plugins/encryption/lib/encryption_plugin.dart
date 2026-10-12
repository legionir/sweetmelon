import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class EncryptionPlugin extends Plugin {
  @override
  String get name => 'encryption';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'AES/RSA encryption and hashing plugin';

  @override
  List<String> get supportedMethods => [
        'aesEncrypt',
        'aesDecrypt',
        'generateAesKey',
        'hashSha256',
        'hashSha512',
        'hashMd5',
        'hmacSha256',
        'generateRandomBytes',
        'base64Encode',
        'base64Decode',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'aesEncrypt':
        return _aesEncrypt(args);
      case 'aesDecrypt':
        return _aesDecrypt(args);
      case 'generateAesKey':
        return _generateAesKey(args);
      case 'hashSha256':
        return _hash(args, 'SHA-256');
      case 'hashSha512':
        return _hash(args, 'SHA-512');
      case 'hashMd5':
        return _hash(args, 'MD5');
      case 'hmacSha256':
        return _hmac(args);
      case 'generateRandomBytes':
        return _generateRandomBytes(args);
      case 'base64Encode':
        return _base64Encode(args);
      case 'base64Decode':
        return _base64Decode(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'algorithms': ['AES-CBC', 'SHA-256', 'SHA-512', 'MD5', 'HMAC-SHA256'],
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Map<String, dynamic> _aesEncrypt(Map<String, dynamic> args) {
    final plaintext = args['data'] as String;
    final keyBase64 = args['key'] as String;
    final ivBase64 = args['iv'] as String?;

    final key = enc.Key.fromBase64(keyBase64);
    final iv = ivBase64 != null
        ? enc.IV.fromBase64(ivBase64)
        : enc.IV.fromSecureRandom(16);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    return {
      'encrypted': encrypted.base64,
      'iv': iv.base64,
      'algorithm': 'AES-CBC',
    };
  }

  Map<String, dynamic> _aesDecrypt(Map<String, dynamic> args) {
    final encryptedBase64 = args['data'] as String;
    final keyBase64 = args['key'] as String;
    final ivBase64 = args['iv'] as String;

    final key = enc.Key.fromBase64(keyBase64);
    final iv = enc.IV.fromBase64(ivBase64);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decrypt64(encryptedBase64, iv: iv);

    return {
      'decrypted': decrypted,
      'algorithm': 'AES-CBC',
    };
  }

  Map<String, dynamic> _generateAesKey(Map<String, dynamic> args) {
    final bits = (args['bits'] as num?)?.toInt() ?? 256;
    final bytes = bits ~/ 8;

    final random = Random.secure();
    final keyBytes = Uint8List(bytes);
    for (var i = 0; i < bytes; i++) {
      keyBytes[i] = random.nextInt(256);
    }

    final ivBytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      ivBytes[i] = random.nextInt(256);
    }

    return {
      'key': base64Encode(keyBytes),
      'iv': base64Encode(ivBytes),
      'bits': bits,
    };
  }

  Map<String, dynamic> _hash(Map<String, dynamic> args, String algorithm) {
    final data = args['data'] as String;
    final bytes = utf8.encode(data);

    Digest digest;

    switch (algorithm) {
      case 'SHA-256':
        digest = SHA256Digest();
        break;
      case 'SHA-512':
        digest = SHA512Digest();
        break;
      case 'MD5':
        digest = MD5Digest();
        break;
      default:
        throw ArgumentError('Unsupported algorithm: $algorithm');
    }

    final result = digest.process(Uint8List.fromList(bytes));
    final hex = result.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return {
      'hash': hex,
      'base64': base64Encode(result),
      'algorithm': algorithm,
    };
  }

  Map<String, dynamic> _hmac(Map<String, dynamic> args) {
    final data = args['data'] as String;
    final keyStr = args['key'] as String;

    final keyBytes = utf8.encode(keyStr);
    final dataBytes = utf8.encode(data);

    final hmac = HMac(SHA256Digest(), 64);
    hmac.init(KeyParameter(Uint8List.fromList(keyBytes)));

    final result = hmac.process(Uint8List.fromList(dataBytes));
    final hex = result.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return {
      'hmac': hex,
      'base64': base64Encode(result),
      'algorithm': 'HMAC-SHA256',
    };
  }

  Map<String, dynamic> _generateRandomBytes(Map<String, dynamic> args) {
    final length = (args['length'] as num?)?.toInt() ?? 32;
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return {
      'hex': hex,
      'base64': base64Encode(bytes),
      'length': length,
    };
  }

  Map<String, dynamic> _base64Encode(Map<String, dynamic> args) {
    final data = args['data'] as String;
    return {'encoded': base64Encode(utf8.encode(data))};
  }

  Map<String, dynamic> _base64Decode(Map<String, dynamic> args) {
    final encoded = args['data'] as String;
    return {'decoded': utf8.decode(base64Decode(encoded))};
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'aesEncrypt':
        if (args['data'] is! String) {
          return ValidationResult.invalid('data is required');
        }
        if (args['key'] is! String) {
          return ValidationResult.invalid('key (base64) is required');
        }
        return ValidationResult.valid();

      case 'aesDecrypt':
        if (args['data'] is! String) {
          return ValidationResult.invalid(
              'data (encrypted base64) is required');
        }
        if (args['key'] is! String) {
          return ValidationResult.invalid('key (base64) is required');
        }
        if (args['iv'] is! String) {
          return ValidationResult.invalid('iv (base64) is required');
        }
        return ValidationResult.valid();

      case 'hashSha256':
      case 'hashSha512':
      case 'hashMd5':
      case 'base64Encode':
      case 'base64Decode':
        if (args['data'] is! String) {
          return ValidationResult.invalid('data is required');
        }
        return ValidationResult.valid();

      case 'hmacSha256':
        if (args['data'] is! String) {
          return ValidationResult.invalid('data is required');
        }
        if (args['key'] is! String) {
          return ValidationResult.invalid('key is required');
        }
        return ValidationResult.valid();

      default:
        return ValidationResult.valid();
    }
  }
}
