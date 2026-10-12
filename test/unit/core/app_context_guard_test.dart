import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

/// Guard behaviour of [AppContext] when no navigator is registered at all.
///
/// This file intentionally never sets a navigator or scaffold key, so every
/// lookup short-circuits on a null key instead of touching an unmounted one.
void main() {
  group('AppContext without any registered keys', () {
    test('presentation methods throw StateError without a navigator', () {
      final appContext = AppContext();

      expect(
        () => appContext.pushPage<void>(const SizedBox()),
        throwsStateError,
      );
      expect(
        () => appContext.showAppDialog<void>(const SizedBox()),
        throwsStateError,
      );
      expect(
        () => appContext.showAppBottomSheet<void>(const SizedBox()),
        throwsStateError,
      );
    });

    test('popPage and showSnackBar are silent no-ops', () {
      final appContext = AppContext();

      expect(() => appContext.popPage<int>(7), returnsNormally);
      expect(
        () => appContext.showSnackBar(
          const SnackBar(content: Text('never shown')),
        ),
        returnsNormally,
      );
    });

    test('context getters report an unavailable UI', () {
      final appContext = AppContext();

      expect(appContext.hasContext, false);
      expect(appContext.context, isNull);
      expect(appContext.scaffoldMessenger, isNull);
      expect(appContext.mediaQuery, isNull);
    });
  });
}
