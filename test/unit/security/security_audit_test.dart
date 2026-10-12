import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('SecurityAuditor', () {
    late SecurityAuditor auditor;

    setUp(() {
      auditor = SecurityAuditor();
    });

    test('audit returns results', () async {
      final report = await auditor.audit();
      expect(report.results, isNotEmpty);
      expect(report.auditedAt, isNotNull);
    });

    test('report has correct counts', () async {
      final report = await auditor.audit();
      expect(
        report.passCount + report.issueCount,
        report.results.length,
      );
    });

    test('toJson returns valid map', () async {
      final report = await auditor.audit();
      final json = report.toJson();
      expect(json['auditedAt'], isNotNull);
      expect(json['overallRisk'], isNotNull);
      expect(json['summary'], isA<Map>());
      expect(json['results'], isA<List>());
    });

    test('toString is human readable', () async {
      final report = await auditor.audit();
      final str = report.toString();
      expect(str, contains('Security Audit Report'));
      expect(str, contains('Overall Risk'));
    });

    test('debug mode check works', () async {
      final report = await auditor.audit();
      final debugCheck = report.results.firstWhere(
        (r) => r.check == 'Debug Mode',
      );
      // در test mode، debug mode فعاله
      expect(debugCheck.risk, isNotNull);
    });
  });
}
