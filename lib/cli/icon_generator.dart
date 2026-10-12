import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// One PNG to write from the source icon.
class IconFile {
  const IconFile(this.path, this.pixels, {this.opaque = false});

  /// Project-relative path.
  final String path;

  /// Width and height in pixels.
  final int pixels;

  /// iOS icons must not have transparency; these are drawn on white.
  final bool opaque;
}

/// One entry of the iOS AppIcon set.
class IosIconSpec {
  const IosIconSpec(this.size, this.scale, this.idiom);

  /// Point size, e.g. `20x20` or `83.5x83.5`.
  final String size;

  /// `1x`, `2x` or `3x`.
  final String scale;

  /// `iphone`, `ipad` or `ios-marketing`.
  final String idiom;

  int get pixels {
    final points = double.parse(size.split('x').first);
    final factor = int.parse(scale.replaceAll('x', ''));
    return (points * factor).round();
  }

  String get fileName => 'Icon-App-$size@$scale.png';
}

const minIconSourcePixels = 1024;

const iosAppIconDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

const _androidDensities = <(String, int)>[
  ('mdpi', 48),
  ('hdpi', 72),
  ('xhdpi', 96),
  ('xxhdpi', 144),
  ('xxxhdpi', 192),
];

const iosIconSpecs = <IosIconSpec>[
  IosIconSpec('20x20', '2x', 'iphone'),
  IosIconSpec('20x20', '3x', 'iphone'),
  IosIconSpec('29x29', '2x', 'iphone'),
  IosIconSpec('29x29', '3x', 'iphone'),
  IosIconSpec('40x40', '2x', 'iphone'),
  IosIconSpec('40x40', '3x', 'iphone'),
  IosIconSpec('60x60', '2x', 'iphone'),
  IosIconSpec('60x60', '3x', 'iphone'),
  IosIconSpec('20x20', '1x', 'ipad'),
  IosIconSpec('20x20', '2x', 'ipad'),
  IosIconSpec('29x29', '1x', 'ipad'),
  IosIconSpec('29x29', '2x', 'ipad'),
  IosIconSpec('40x40', '1x', 'ipad'),
  IosIconSpec('40x40', '2x', 'ipad'),
  IosIconSpec('76x76', '1x', 'ipad'),
  IosIconSpec('76x76', '2x', 'ipad'),
  IosIconSpec('83.5x83.5', '2x', 'ipad'),
  IosIconSpec('1024x1024', '1x', 'ios-marketing'),
];

/// Every file the icon command writes, each path once.
///
/// Some iOS entries share a file (iPhone and iPad both use the 40x40@2x
/// icon), so the list is de-duplicated by path.
List<IconFile> iconTargets() {
  final all = [
    for (final (density, pixels) in _androidDensities)
      IconFile(
        'android/app/src/main/res/mipmap-$density/ic_launcher.png',
        pixels,
      ),
    for (final spec in iosIconSpecs)
      IconFile('$iosAppIconDir/${spec.fileName}', spec.pixels, opaque: true),
    const IconFile('web/favicon.png', 32),
    const IconFile('web/icons/Icon-192.png', 192),
    const IconFile('web/icons/Icon-512.png', 512),
  ];
  final seen = <String>{};
  return [
    for (final target in all)
      if (seen.add(target.path)) target,
  ];
}

/// `Contents.json` for the iOS AppIcon set.
String iosContentsJson() {
  final images = [
    for (final spec in iosIconSpecs)
      {
        'size': spec.size,
        'idiom': spec.idiom,
        'filename': spec.fileName,
        'scale': spec.scale,
      },
  ];
  final data = {
    'images': images,
    'info': {'author': 'xcode', 'version': 1},
  };
  return '${const JsonEncoder.withIndent('  ').convert(data)}\n';
}

/// File names listed in an existing AppIcon `Contents.json`.
List<String> iosFileNamesIn(String contentsJson) {
  final data = jsonDecode(contentsJson) as Map<String, dynamic>;
  final images = data['images'] as List<dynamic>? ?? const [];
  return [
    for (final item in images)
      if ((item as Map<String, dynamic>)['filename'] != null)
        item['filename'] as String,
  ];
}

/// Checks the source icon. Returns a message when it is not usable.
String? iconSourceProblem(Uint8List bytes) {
  final decoded = img.decodePng(bytes);
  if (decoded == null) return 'the icon must be a PNG file';
  if (decoded.width != decoded.height) {
    return 'the icon must be square, got ${decoded.width}x${decoded.height}';
  }
  if (decoded.width < minIconSourcePixels) {
    return 'the icon must be at least ${minIconSourcePixels}x$minIconSourcePixels '
        'pixels, got ${decoded.width}';
  }
  return null;
}

/// Renders every target from [source]. Returns path -> PNG bytes.
/// Throws [FormatException] when the source is not usable.
Map<String, Uint8List> renderIcons(Uint8List source, List<IconFile> targets) {
  final problem = iconSourceProblem(source);
  if (problem != null) throw FormatException(problem);

  final decoded = img.decodePng(source)!;
  final out = <String, Uint8List>{};
  for (final target in targets) {
    var image = img.copyResize(
      decoded,
      width: target.pixels,
      height: target.pixels,
      interpolation: img.Interpolation.average,
    );
    if (target.opaque) image = _onWhite(image);
    out[target.path] = Uint8List.fromList(img.encodePng(image));
  }
  return out;
}

img.Image _onWhite(img.Image source) {
  final canvas = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 3,
  );
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(canvas, source);
  return canvas;
}
