import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/haptic/lib/haptic_plugin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('HapticPlugin', () {
    late HapticPlugin plugin;

    setUp(() async {
      plugin = HapticPlugin();
      await plugin.initialize();
    });

    const feedbackTypes = {
      'lightImpact': 'light',
      'mediumImpact': 'medium',
      'heavyImpact': 'heavy',
      'selectionClick': 'selection',
      'vibrate': 'vibrate',
    };

    for (final entry in feedbackTypes.entries) {
      test('${entry.key} triggers platform feedback', () async {
        final result = await plugin.onCall(entry.key, {});

        expect(result, {'type': entry.value, 'triggered': true});
        expect(
          calls.map((call) => call.method),
          contains('HapticFeedback.vibrate'),
        );
      });
    }

    test('getInfo lists every supported feedback type', () async {
      final result = await plugin.onCall('getInfo', {});

      expect(result['name'], 'haptic');
      expect(result['version'], '1.0.0');
      expect(result['supportedTypes'], [
        'lightImpact',
        'mediumImpact',
        'heavyImpact',
        'selectionClick',
        'vibrate',
      ]);
    });

    test('unknown methods throw UnsupportedError', () async {
      await expectLater(plugin.onCall('shock', {}), throwsUnsupportedError);
    });
  });
}
