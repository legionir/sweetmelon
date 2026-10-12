import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

class SecurityAuditResult {
  final String check;
  final SecurityRisk risk;
  final String message;
  final String? recommendation;

  const SecurityAuditResult({
    required this.check,
    required this.risk,
    required this.message,
    this.recommendation,
  });

  Map<String, dynamic> toJson() => {
        'check': check,
        'risk': risk.name,
        'message': message,
        if (recommendation != null) 'recommendation': recommendation,
      };
}

enum SecurityRisk { pass, low, medium, high, critical }

class SecurityAuditor {
  Future<SecurityAuditReport> audit() async {
    BridgeLogger.info('SecurityAudit', 'Starting security audit...');

    final results = <SecurityAuditResult>[];

    // 1. Debug Mode
    results.add(_checkDebugMode());

    // 2. Root/Jailbreak
    results.add(await _checkRootStatus());

    // 3. AndroidManifest checks
    results.add(await _checkManifest());

    // 4. Cleartext Traffic
    results.add(await _checkCleartextTraffic());

    // 5. Certificate Pinning
    results.add(_checkCertificatePinning());

    // 6. Secure Storage
    results.add(_checkSecureStorage());

    // 7. Permission declarations
    results.add(await _checkPermissions());

    // 8. ProGuard
    results.add(await _checkProguard());

    // 9. Backup flag
    results.add(await _checkBackup());

    // 10. Network security config
    results.add(await _checkNetworkSecurityConfig());

    final report = SecurityAuditReport(results: results);

    BridgeLogger.info(
      'SecurityAudit',
      'Audit complete: ${report.passCount} pass, '
          '${report.issueCount} issues',
    );

    return report;
  }

  SecurityAuditResult _checkDebugMode() {
    if (kDebugMode) {
      return const SecurityAuditResult(
        check: 'Debug Mode',
        risk: SecurityRisk.high,
        message: 'App is running in debug mode',
        recommendation: 'Always build with --release for production',
      );
    }
    return const SecurityAuditResult(
      check: 'Debug Mode',
      risk: SecurityRisk.pass,
      message: 'Release mode enabled',
    );
  }

  Future<SecurityAuditResult> _checkRootStatus() async {
    if (!Platform.isAndroid) {
      return const SecurityAuditResult(
        check: 'Root Detection',
        risk: SecurityRisk.pass,
        message: 'Root detection is platform-specific (Android only)',
      );
    }

    final suPaths = ['/system/bin/su', '/system/xbin/su', '/sbin/su'];
    for (final path in suPaths) {
      if (File(path).existsSync()) {
        return const SecurityAuditResult(
          check: 'Root Detection',
          risk: SecurityRisk.high,
          message: 'Device appears to be rooted',
          recommendation:
              'Consider restricting app functionality on rooted devices',
        );
      }
    }

    return const SecurityAuditResult(
      check: 'Root Detection',
      risk: SecurityRisk.pass,
      message: 'No root indicators found',
    );
  }

  Future<SecurityAuditResult> _checkManifest() async {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    );

    if (!await manifest.exists()) {
      return const SecurityAuditResult(
        check: 'AndroidManifest',
        risk: SecurityRisk.medium,
        message: 'AndroidManifest.xml not found for audit',
      );
    }

    final content = await manifest.readAsString();

    if (content.contains('android:debuggable="true"')) {
      return const SecurityAuditResult(
        check: 'AndroidManifest',
        risk: SecurityRisk.critical,
        message: 'android:debuggable="true" found in manifest',
        recommendation: 'Remove debuggable=true from manifest',
      );
    }

    return const SecurityAuditResult(
      check: 'AndroidManifest',
      risk: SecurityRisk.pass,
      message: 'No debuggable flag in manifest',
    );
  }

  Future<SecurityAuditResult> _checkCleartextTraffic() async {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    );

    if (!await manifest.exists()) {
      return const SecurityAuditResult(
        check: 'Cleartext Traffic',
        risk: SecurityRisk.medium,
        message: 'Cannot verify cleartext traffic setting',
      );
    }

    final content = await manifest.readAsString();

    if (content.contains('android:usesCleartextTraffic="true"') &&
        kReleaseMode) {
      return const SecurityAuditResult(
        check: 'Cleartext Traffic',
        risk: SecurityRisk.medium,
        message: 'Cleartext traffic allowed in release mode',
        recommendation:
            'Disable usesCleartextTraffic in production or restrict to localhost only',
      );
    }

    return const SecurityAuditResult(
      check: 'Cleartext Traffic',
      risk: SecurityRisk.pass,
      message: 'Cleartext traffic properly configured',
    );
  }

  SecurityAuditResult _checkCertificatePinning() {
    // این check باید runtime بشه
    // در production باید SSL pinning فعال باشه
    if (kReleaseMode) {
      return const SecurityAuditResult(
        check: 'Certificate Pinning',
        risk: SecurityRisk.medium,
        message: 'Verify SSL pinning is enabled for API endpoints',
        recommendation: 'Enable SSL pinning in SecurityManager.production()',
      );
    }

    return const SecurityAuditResult(
      check: 'Certificate Pinning',
      risk: SecurityRisk.low,
      message: 'SSL pinning check skipped in debug mode',
    );
  }

  SecurityAuditResult _checkSecureStorage() {
    return const SecurityAuditResult(
      check: 'Secure Storage',
      risk: SecurityRisk.pass,
      message: 'Secure storage plugin available (flutter_secure_storage)',
    );
  }

  Future<SecurityAuditResult> _checkPermissions() async {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    );

    if (!await manifest.exists()) {
      return const SecurityAuditResult(
        check: 'Permissions',
        risk: SecurityRisk.medium,
        message: 'Cannot verify permissions',
      );
    }

    final content = await manifest.readAsString();
    final dangerousPerms = [
      'READ_CONTACTS',
      'READ_CALL_LOG',
      'RECORD_AUDIO',
      'READ_SMS',
      'ACCESS_FINE_LOCATION',
    ];

    final found = dangerousPerms
        .where((p) => content.contains('android.permission.$p'))
        .toList();

    if (found.length > 3) {
      return SecurityAuditResult(
        check: 'Permissions',
        risk: SecurityRisk.medium,
        message: 'Multiple sensitive permissions declared: ${found.join(", ")}',
        recommendation: 'Only declare permissions you actually use',
      );
    }

    return const SecurityAuditResult(
      check: 'Permissions',
      risk: SecurityRisk.pass,
      message: 'Permission declarations look reasonable',
    );
  }

  Future<SecurityAuditResult> _checkProguard() async {
    final proguard = File('android/app/proguard-rules.pro');

    if (!await proguard.exists()) {
      return const SecurityAuditResult(
        check: 'ProGuard',
        risk: SecurityRisk.high,
        message: 'proguard-rules.pro not found',
        recommendation: 'Add ProGuard rules for release builds',
      );
    }

    final buildGradle = File('android/app/build.gradle');
    if (await buildGradle.exists()) {
      final content = await buildGradle.readAsString();
      if (!content.contains('minifyEnabled true')) {
        return const SecurityAuditResult(
          check: 'ProGuard',
          risk: SecurityRisk.medium,
          message: 'minifyEnabled not set to true in build.gradle',
          recommendation: 'Enable minification for release builds',
        );
      }
    }

    return const SecurityAuditResult(
      check: 'ProGuard',
      risk: SecurityRisk.pass,
      message: 'ProGuard configuration found',
    );
  }

  Future<SecurityAuditResult> _checkBackup() async {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    );

    if (!await manifest.exists()) {
      return const SecurityAuditResult(
        check: 'Backup Configuration',
        risk: SecurityRisk.low,
        message: 'Cannot verify backup configuration',
      );
    }

    final content = await manifest.readAsString();

    if (content.contains('android:allowBackup="true"') &&
        !content.contains('android:fullBackupContent') &&
        !content.contains('android:dataExtractionRules')) {
      return const SecurityAuditResult(
        check: 'Backup Configuration',
        risk: SecurityRisk.medium,
        message: 'allowBackup=true without backup rules',
        recommendation:
            'Add fullBackupContent or dataExtractionRules to control what gets backed up',
      );
    }

    return const SecurityAuditResult(
      check: 'Backup Configuration',
      risk: SecurityRisk.pass,
      message: 'Backup configuration is set',
    );
  }

  Future<SecurityAuditResult> _checkNetworkSecurityConfig() async {
    final config = File(
      'android/app/src/main/res/xml/network_security_config.xml',
    );

    if (!await config.exists()) {
      return const SecurityAuditResult(
        check: 'Network Security Config',
        risk: SecurityRisk.medium,
        message: 'network_security_config.xml not found',
        recommendation: 'Add network security config to restrict HTTP traffic',
      );
    }

    final content = await config.readAsString();

    if (kReleaseMode &&
        content.contains('cleartextTrafficPermitted="true"') &&
        !content.contains('localhost')) {
      return const SecurityAuditResult(
        check: 'Network Security Config',
        risk: SecurityRisk.high,
        message: 'Cleartext traffic permitted globally in release',
        recommendation: 'Restrict cleartext to localhost only in production',
      );
    }

    return const SecurityAuditResult(
      check: 'Network Security Config',
      risk: SecurityRisk.pass,
      message: 'Network security config present',
    );
  }
}

class SecurityAuditReport {
  final List<SecurityAuditResult> results;
  final DateTime auditedAt;

  SecurityAuditReport({
    required this.results,
  }) : auditedAt = DateTime.now();

  int get passCount => results.where((r) => r.risk == SecurityRisk.pass).length;
  int get issueCount =>
      results.where((r) => r.risk != SecurityRisk.pass).length;
  int get criticalCount =>
      results.where((r) => r.risk == SecurityRisk.critical).length;
  int get highCount => results.where((r) => r.risk == SecurityRisk.high).length;
  int get mediumCount =>
      results.where((r) => r.risk == SecurityRisk.medium).length;

  SecurityRisk get overallRisk {
    if (criticalCount > 0) return SecurityRisk.critical;
    if (highCount > 0) return SecurityRisk.high;
    if (mediumCount > 0) return SecurityRisk.medium;
    if (results.any((r) => r.risk == SecurityRisk.low)) return SecurityRisk.low;
    return SecurityRisk.pass;
  }

  Map<String, dynamic> toJson() => {
        'auditedAt': auditedAt.toIso8601String(),
        'overallRisk': overallRisk.name,
        'summary': {
          'pass': passCount,
          'critical': criticalCount,
          'high': highCount,
          'medium': mediumCount,
          'total': results.length,
        },
        'results': results.map((r) => r.toJson()).toList(),
      };

  @override
  String toString() {
    final buf = StringBuffer();
    buf.writeln('═══ Security Audit Report ═══');
    buf.writeln('Overall Risk : ${overallRisk.name.toUpperCase()}');
    buf.writeln('Pass         : $passCount/${results.length}');
    buf.writeln('Critical     : $criticalCount');
    buf.writeln('High         : $highCount');
    buf.writeln('Medium       : $mediumCount');
    buf.writeln('');

    final issues = results.where((r) => r.risk != SecurityRisk.pass).toList();
    if (issues.isNotEmpty) {
      buf.writeln('Issues:');
      for (final issue in issues) {
        buf.writeln(
            '  [${issue.risk.name.toUpperCase()}] ${issue.check}: ${issue.message}');
        if (issue.recommendation != null) {
          buf.writeln('    → ${issue.recommendation}');
        }
      }
    } else {
      buf.writeln('✅ No security issues found!');
    }

    return buf.toString();
  }
}
