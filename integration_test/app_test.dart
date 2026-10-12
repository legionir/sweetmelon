// On-device end-to-end checks. Run on an Android emulator or device:
//   flutter test integration_test/app_test.dart -d <device-id>

// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sweetmelon/app.dart';
import 'package:sweetmelon/di/service_locator.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ServiceLocator.init();
  });

  tearDownAll(() async {
    await ServiceLocator.dispose();
  });

  testWidgets('app boots into the home screen with the WebView host',
      (tester) async {
    await tester.pumpWidget(const BridgeApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(WebViewHost), findsOneWidget);
    expect(tester.takeException(), isNull);
    print('E2E_OK: app boots into the home screen with the WebView host');
  });

  testWidgets('storage round-trip works through the real engine',
      (tester) async {
    final manager = sl<PluginManager>();
    final set = await manager.execute(PluginRequest.fromJson({
      'requestId': 'e2e-set',
      'plugin': 'storage',
      'method': 'set',
      'args': {'key': 'e2e', 'value': 'ok'},
    }));
    expect(set.success, isTrue, reason: set.error?.message);

    final get = await manager.execute(PluginRequest.fromJson({
      'requestId': 'e2e-get',
      'plugin': 'storage',
      'method': 'get',
      'args': {'key': 'e2e'},
    }));
    expect(get.success, isTrue);
    expect(get.data, 'ok');

    final traversal = await manager.execute(PluginRequest.fromJson({
      'requestId': 'e2e-trav',
      'plugin': 'storage',
      'method': 'readFile',
      'args': {'path': '../../../etc/hosts'},
    }));
    expect(traversal.success, isFalse);
    print('E2E_OK: storage round-trip and traversal rejection');
  });
}
