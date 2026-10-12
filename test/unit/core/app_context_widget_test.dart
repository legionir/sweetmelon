import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

/// Behavioural tests for [AppContext] against a real, mounted widget tree.
///
/// These run as widget tests because the context getters resolve through
/// [GlobalKey.currentContext], which needs a mounted element tree.
void main() {
  late GlobalKey<NavigatorState> navigatorKey;

  setUp(() {
    navigatorKey = GlobalKey<NavigatorState>();
    AppContext().setNavigatorKey(navigatorKey);
  });

  Future<void> pumpApp(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
      ),
    );
  }

  testWidgets('showSnackBar uses the build context fallback', (tester) async {
    // Runs first on purpose: no scaffold key has been registered yet, so the
    // messenger lookup returns null and the ScaffoldMessenger.of(context)
    // fallback path is exercised.
    await pumpApp(tester);

    AppContext().showSnackBar(
      const SnackBar(
        content: Text('fallback-snack'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
    await tester.pump();

    expect(find.text('fallback-snack'), findsOneWidget);

    // Let the snack bar hide timer expire so no timer is left pending. The
    // hide timer is only scheduled once the entrance animation completes, so
    // pump once past the entrance, then past the hide deadline.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('fallback-snack'), findsNothing);
  });

  testWidgets('exposes mounted context and media query', (tester) async {
    final scaffoldKey = GlobalKey<ScaffoldMessengerState>();
    AppContext().setScaffoldKey(scaffoldKey);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldKey,
        home: const Scaffold(body: Text('home')),
      ),
    );

    final appContext = AppContext();
    expect(appContext.hasContext, true);
    expect(appContext.context, isNotNull);
    expect(appContext.navigatorKey, same(navigatorKey));
    expect(appContext.scaffoldMessenger, isNotNull);
    expect(appContext.mediaQuery, isNotNull);
    expect(appContext.mediaQuery!.size.width, greaterThan(0));
  });

  testWidgets('pushPage opens the page and popPage closes it', (tester) async {
    await pumpApp(tester);

    final pushed = AppContext().pushPage<void>(
      const Scaffold(body: Text('second-page')),
    );
    await tester.pumpAndSettle();
    expect(find.text('second-page'), findsOneWidget);
    expect(find.text('home'), findsNothing);

    AppContext().popPage<void>();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('second-page'), findsNothing);

    await pushed;
  });

  testWidgets('showAppDialog presents and dismisses a dialog', (tester) async {
    await pumpApp(tester);

    final shown = AppContext().showAppDialog<void>(
      const AlertDialog(content: Text('dialog-body')),
    );
    await tester.pumpAndSettle();
    expect(find.text('dialog-body'), findsOneWidget);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('dialog-body'), findsNothing);

    await shown;
  });

  testWidgets('showAppBottomSheet presents and dismisses a sheet',
      (tester) async {
    await pumpApp(tester);

    final shown = AppContext().showAppBottomSheet<void>(
      Container(
        height: 120,
        color: const Color(0xFF112233),
        child: const Text('sheet-body'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('sheet-body'), findsOneWidget);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('sheet-body'), findsNothing);

    await shown;
  });

  testWidgets('showSnackBar uses the registered messenger', (tester) async {
    final scaffoldKey = GlobalKey<ScaffoldMessengerState>();
    AppContext().setScaffoldKey(scaffoldKey);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldKey,
        home: const Scaffold(body: Text('home')),
      ),
    );

    AppContext().showSnackBar(
      const SnackBar(
        content: Text('direct-snack'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
    await tester.pump();

    expect(find.text('direct-snack'), findsOneWidget);

    // Let the snack bar hide timer expire so no timer is left pending. The
    // hide timer is only scheduled once the entrance animation completes, so
    // pump once past the entrance, then past the hide deadline.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('direct-snack'), findsNothing);
  });
}
