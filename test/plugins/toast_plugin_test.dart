import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/toast/lib/toast_plugin.dart';

void main() {
  group('ToastPlugin', () {
    late ToastPlugin plugin;

    setUp(() async {
      plugin = ToastPlugin();
      await plugin.initialize();
    });

    test('validates show requires text', () async {
      final r = await plugin.validateArgs('show', {});
      expect(r.isValid, false);

      final r2 = await plugin.validateArgs('show', {'text': 'Hello'});
      expect(r2.isValid, true);
    });
  });
}
