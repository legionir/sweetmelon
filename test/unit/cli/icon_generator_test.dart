import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sweetmelon/cli/icon_generator.dart';

Uint8List _png(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(200, 40, 40, 255));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('rejects a source smaller than 1024 px', () {
    expect(iconSourceProblem(_png(512, 512)), contains('at least'));
  });

  test('rejects a source that is not square', () {
    expect(iconSourceProblem(_png(1024, 1000)), contains('square'));
  });

  test('accepts a square source of 1024 px', () {
    expect(iconSourceProblem(_png(1024, 1024)), isNull);
  });

  test('rejects bytes that are not a PNG', () {
    expect(iconSourceProblem(Uint8List.fromList([1, 2, 3])), isNotNull);
  });

  test('renders every target at its size', () {
    final targets = iconTargets();
    final out = renderIcons(_png(1024, 1024), targets);

    expect(out.length, targets.length);
    for (final target in targets) {
      final decoded = img.decodePng(out[target.path]!)!;
      expect(decoded.width, target.pixels, reason: target.path);
      expect(decoded.height, target.pixels, reason: target.path);
    }
  });

  test('iOS icons are opaque', () {
    final out = renderIcons(_png(1024, 1024), [
      const IconFile('ios/test.png', 60, opaque: true),
    ]);
    final decoded = img.decodePng(out['ios/test.png']!)!;
    expect(decoded.hasAlpha, isFalse);
  });

  test('Android mipmap sizes match the density table', () {
    final paths = {for (final t in iconTargets()) t.path: t.pixels};
    expect(
      paths['android/app/src/main/res/mipmap-mdpi/ic_launcher.png'],
      48,
    );
    expect(
      paths['android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'],
      192,
    );
  });

  test('Contents.json lists every generated iOS file', () {
    final contents = iosContentsJson();
    for (final spec in iosIconSpecs) {
      expect(contents, contains(spec.fileName));
    }
    expect(iosFileNamesIn(contents).toSet(),
        {for (final spec in iosIconSpecs) spec.fileName});
  });
}
