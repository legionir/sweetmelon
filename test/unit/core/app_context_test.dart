import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('AppContext', () {
    test('singleton instance', () {
      final a = AppContext();
      final b = AppContext();
      expect(identical(a, b), true);
    });

    test('hasContext is false initially', () {
      expect(AppContext().hasContext, false);
    });

    test('context is null initially', () {
      expect(AppContext().context, isNull);
    });
  });
}
