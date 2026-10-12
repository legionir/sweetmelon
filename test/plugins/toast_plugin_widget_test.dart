import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/plugins/toast/lib/toast_plugin.dart';

/// Exercises [ToastPlugin._show] against a mounted widget tree, since the
/// toast needs a real [ScaffoldMessenger] to render.
void main() {
  late ToastPlugin plugin;
  late GlobalKey<NavigatorState> navigatorKey;

  setUp(() async {
    plugin = ToastPlugin();
    await plugin.initialize();
    navigatorKey = GlobalKey<NavigatorState>();
    AppContext().setNavigatorKey(navigatorKey);
  });

  tearDown(() {
    AppContext().reset();
  });

  Future<void> pumpHost(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('host')),
      ),
    );
  }

  testWidgets('show renders a long top toast with custom colors',
      (tester) async {
    await pumpHost(tester);

    final result = await plugin.onCall('show', {
      'text': 'hello-toast',
      'duration': 'long',
      'position': 'top',
      'backgroundColor': '#FF0000',
      'textColor': '80112233',
    });
    await tester.pump();

    expect(result, {'shown': true, 'duration': 'long'});
    expect(find.text('hello-toast'), findsOneWidget);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.duration, const Duration(seconds: 4));
    expect(snackBar.backgroundColor, const Color(0xFFFF0000));

    final text = tester.widget<Text>(find.text('hello-toast'));
    expect(text.style?.color, const Color(0x80112233));

    // Let the snack bar hide timer expire so no timer is left pending. The
    // hide timer is only scheduled once the entrance animation completes, so
    // pump once past the entrance, then past the hide deadline.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('show defaults to a short bottom toast', (tester) async {
    await pumpHost(tester);

    final result = await plugin.onCall('show', {'text': 'default-toast'});
    await tester.pump();

    expect(result, {'shown': true, 'duration': 'short'});

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, const Duration(seconds: 2));
    expect(snackBar.backgroundColor, const Color(0xFF323232));

    // Let the snack bar hide timer expire so no timer is left pending. The
    // hide timer is only scheduled once the entrance animation completes, so
    // pump once past the entrance, then past the hide deadline.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('show falls back to defaults for unparseable colors',
      (tester) async {
    await pumpHost(tester);

    final result = await plugin.onCall('show', {
      'text': 'invalid-colors',
      'backgroundColor': 'not-a-color',
      'textColor': '#12345',
    });
    await tester.pump();

    expect(result, {'shown': true, 'duration': 'short'});

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, const Color(0xFF323232));

    final text = tester.widget<Text>(find.text('invalid-colors'));
    expect(text.style?.color, Colors.white);

    // Let the snack bar hide timer expire so no timer is left pending. The
    // hide timer is only scheduled once the entrance animation completes, so
    // pump once past the entrance, then past the hide deadline.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  test('show reports no_context when the navigator key is missing', () async {
    AppContext().reset();

    final result = await plugin.onCall('show', {'text': 'never shown'});

    expect(result, {'shown': false, 'reason': 'no_context'});
  });

  test('getInfo returns the plugin metadata', () async {
    final result = await plugin.onCall('getInfo', {});

    expect(result, {'name': 'toast', 'version': '1.0.0'});
  });

  test('unknown methods throw UnsupportedError', () async {
    await expectLater(plugin.onCall('explode', {}), throwsUnsupportedError);
  });
}
