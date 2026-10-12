import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// تشخیص تغییر در فایل‌های www
class AntiTampering {
  final Map<String, String> _expectedHashes = {};
  bool _verified = false;
  bool _enabled = false;

  /// فعال کردن
  void enable() {
    _enabled = true;
  }

  /// غیرفعال کردن
  void disable() {
    _enabled = false;
  }

  /// ثبت hash مورد انتظار برای یک فایل
  void registerHash(String filePath, String sha256Hash) {
    _expectedHashes[filePath] = sha256Hash.toLowerCase();
  }

  /// ثبت چندین hash از یک manifest
  void registerManifest(Map<String, String> manifest) {
    manifest.forEach((path, hash) {
      _expectedHashes[path] = hash.toLowerCase();
    });
  }

  /// بارگذاری manifest از asset
  Future<void> loadManifestFromAsset(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      final manifest = Map<String, String>.from(
        jsonDecode(content) as Map,
      );
      registerManifest(manifest);

      BridgeLogger.info(
        'AntiTampering',
        'Loaded manifest: ${manifest.length} entries',
      );
    } catch (e) {
      BridgeLogger.error('AntiTampering', 'Failed to load manifest: $e');
    }
  }

  /// اعتبارسنجی یک فایل
  ///
  /// [lookupKey] کلید ثبت‌شده در manifest است (برای lookup hash);
  /// [filePath] مسیر resolve‌شده برای خواندن فایل.
  Future<FileVerification> verifyFile(String filePath,
      {String? lookupKey}) async {
    if (!_enabled) {
      return const FileVerification(
        path: '',
        valid: true,
        reason: 'tampering_check_disabled',
      );
    }

    final expectedHash = _expectedHashes[lookupKey ?? filePath];
    if (expectedHash == null) {
      return FileVerification(
        path: filePath,
        valid: true,
        reason: 'no_hash_registered',
      );
    }

    try {
      final file = File(filePath);

      if (!await file.exists()) {
        return FileVerification(
          path: filePath,
          valid: false,
          reason: 'file_not_found',
        );
      }

      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString().toLowerCase();

      final valid = hash == expectedHash;

      if (!valid) {
        BridgeLogger.error(
          'AntiTampering',
          'File tampered: $filePath\n'
              '  Expected: $expectedHash\n'
              '  Got: $hash',
        );
      }

      return FileVerification(
        path: filePath,
        valid: valid,
        expectedHash: expectedHash,
        actualHash: hash,
        reason: valid ? 'match' : 'hash_mismatch',
      );
    } catch (e) {
      return FileVerification(
        path: filePath,
        valid: false,
        reason: 'verification_error: $e',
      );
    }
  }

  /// اعتبارسنجی همه فایل‌های ثبت‌شده
  Future<TamperingReport> verifyAll(String baseDir) async {
    if (!_enabled) {
      return const TamperingReport(
        verified: true,
        totalFiles: 0,
        validFiles: 0,
        invalidFiles: 0,
        results: [],
      );
    }

    final results = <FileVerification>[];
    int valid = 0;
    int invalid = 0;

    for (final entry in _expectedHashes.entries) {
      final fullPath = '$baseDir/${entry.key}';
      final result = await verifyFile(fullPath, lookupKey: entry.key);
      results.add(result);

      if (result.valid) {
        valid++;
      } else {
        invalid++;
      }
    }

    final allValid = invalid == 0;

    if (!allValid) {
      BridgeLogger.error(
        'AntiTampering',
        'Verification FAILED: $invalid of ${results.length} files tampered',
      );
    } else {
      BridgeLogger.info(
        'AntiTampering',
        'Verification passed: ${results.length} files OK',
      );
    }

    _verified = allValid;

    return TamperingReport(
      verified: allValid,
      totalFiles: results.length,
      validFiles: valid,
      invalidFiles: invalid,
      results: results,
    );
  }

  /// محاسبه hash یک فایل
  static Future<String> computeFileHash(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString().toLowerCase();
  }

  /// تولید manifest برای یک دایرکتوری
  static Future<Map<String, String>> generateManifest(
    String directory,
  ) async {
    final manifest = <String, String>{};
    final dir = Directory(directory);

    if (!await dir.exists()) return manifest;

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = entity.path
            .replaceFirst(directory, '')
            .replaceFirst(RegExp(r'^[/\\]'), '');

        final bytes = await entity.readAsBytes();
        final hash = sha256.convert(bytes).toString().toLowerCase();

        manifest[relativePath] = hash;
      }
    }

    return manifest;
  }

  bool get isVerified => _verified;
  bool get isEnabled => _enabled;

  Map<String, dynamic> get stats => {
        'enabled': _enabled,
        'verified': _verified,
        'registeredFiles': _expectedHashes.length,
      };
}

class FileVerification {
  final String path;
  final bool valid;
  final String? expectedHash;
  final String? actualHash;
  final String? reason;

  const FileVerification({
    required this.path,
    required this.valid,
    this.expectedHash,
    this.actualHash,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'valid': valid,
        if (expectedHash != null) 'expectedHash': expectedHash,
        if (actualHash != null) 'actualHash': actualHash,
        if (reason != null) 'reason': reason,
      };
}

class TamperingReport {
  final bool verified;
  final int totalFiles;
  final int validFiles;
  final int invalidFiles;
  final List<FileVerification> results;

  const TamperingReport({
    required this.verified,
    required this.totalFiles,
    required this.validFiles,
    required this.invalidFiles,
    required this.results,
  });

  Map<String, dynamic> toJson() => {
        'verified': verified,
        'totalFiles': totalFiles,
        'validFiles': validFiles,
        'invalidFiles': invalidFiles,
        'results': results.map((r) => r.toJson()).toList(),
      };
}
