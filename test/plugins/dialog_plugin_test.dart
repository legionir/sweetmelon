import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/dialog/lib/dialog_plugin.dart';

void main() {
  group('DialogPlugin', () {
    late DialogPlugin plugin;

    setUp(() async {
      plugin = DialogPlugin();
      await plugin.initialize();
    });

    test('validates alert requires message', () async {
      final r = await plugin.validateArgs('alert', {});
      expect(r.isValid, false);

      final r2 = await plugin.validateArgs('alert', {'message': 'Hello'});
      expect(r2.isValid, true);
    });

    test('validates confirm requires message', () async {
      final r = await plugin.validateArgs('confirm', {});
      expect(r.isValid, false);
    });

    test('prompt accepts empty args', () async {
      final r = await plugin.validateArgs('prompt', {});
      expect(r.isValid, true);
    });

    test('getInfo returns plugin info', () async {
      final r = await plugin.onCall('getInfo', {});
      expect(r['name'], 'dialog');
      expect(r['version'], '1.0.0');
    });
  });
}
