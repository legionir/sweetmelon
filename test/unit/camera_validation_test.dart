// regression: BUG-009 — malformed camera arguments are rejected before the
// native picker opens, with a message that names the field.
import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';
import 'package:sweetmelon/plugins/camera/lib/camera_plugin.dart';

void main() {
  late CameraPlugin plugin;
  setUp(() => plugin = CameraPlugin());

  Future<ValidationResult> validate(String method, Map<String, dynamic> args) =>
      plugin.validateArgs(method, args);

  group('takePhoto', () {
    test('accepts absent and in-range options', () async {
      expect((await validate('takePhoto', {})).isValid, isTrue);
      expect((await validate('takePhoto', {'quality': 80})).isValid, isTrue);
      expect((await validate('takePhoto', {'maxWidth': 1024})).isValid, isTrue);
    });

    test('rejects a non-numeric quality with a named message', () async {
      final r = await validate('takePhoto', {'quality': 'high'});
      expect(r.isValid, isFalse);
      expect(r.errorMessage, 'quality must be a number');
    });

    test('rejects quality outside 0..100', () async {
      expect((await validate('takePhoto', {'quality': 101})).isValid, isFalse);
      expect((await validate('takePhoto', {'quality': -1})).isValid, isFalse);
    });

    test('rejects non-positive and oversized dimensions', () async {
      expect((await validate('takePhoto', {'maxWidth': 0})).isValid, isFalse);
      expect(
          (await validate('takePhoto', {'maxHeight': 10001})).isValid, isFalse);
      expect(
          (await validate('takePhoto', {'maxHeight': 'big'})).isValid, isFalse);
    });
  });

  group('pickFromGallery and recordVideo', () {
    test('multiple must be a boolean when present', () async {
      expect((await validate('pickFromGallery', {'multiple': true})).isValid,
          isTrue);
      expect((await validate('pickFromGallery', {'multiple': 'yes'})).isValid,
          isFalse);
    });

    test('maxDurationSeconds must be an integer between 1 and 3600', () async {
      expect(
          (await validate('recordVideo', {'maxDurationSeconds': 60})).isValid,
          isTrue);
      expect((await validate('recordVideo', {'maxDurationSeconds': 0})).isValid,
          isFalse);
      expect(
          (await validate('recordVideo', {'maxDurationSeconds': 3601})).isValid,
          isFalse);
      expect(
          (await validate('recordVideo', {'maxDurationSeconds': 2.5})).isValid,
          isFalse);
    });
  });
}
