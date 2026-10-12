import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class CameraPlugin extends Plugin {
  final ImagePicker _picker = ImagePicker();

  @override
  String get name => 'camera';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Camera and image picker plugin';

  @override
  bool get cacheable => false;

  @override
  List<String> get supportedMethods => [
        'takePhoto',
        'pickFromGallery',
        'recordVideo',
        'getInfo',
      ];

  // Permissions are requested per method (see _takePhoto). Gallery access
  // uses the system picker, which needs no storage permission on Android 13+.
  @override
  List<String> get requiredPermissions => const [];

  @override
  Future<void> onInitialize() async {}

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'takePhoto':
        return _takePhoto(args);
      case 'pickFromGallery':
        return _pickFromGallery(args);
      case 'recordVideo':
        return _recordVideo(args);
      case 'getInfo':
        return _getInfo();
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _takePhoto(Map<String, dynamic> args) async {
    final quality = (args['quality'] as num?)?.toInt() ?? 80;
    final maxWidth = (args['maxWidth'] as num?)?.toDouble();
    final maxHeight = (args['maxHeight'] as num?)?.toDouble();

    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      throw Exception('Camera permission denied');
    }

    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: quality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );

    if (image == null) throw Exception('User cancelled photo capture');
    return _xFileToMap(image);
  }

  Future<Map<String, dynamic>> _pickFromGallery(
    Map<String, dynamic> args,
  ) async {
    final multiple = args['multiple'] as bool? ?? false;

    if (multiple) {
      final images = await _picker.pickMultiImage();
      if (images.isEmpty) throw Exception('No images selected');

      final imageList = <Map<String, dynamic>>[];
      for (final img in images) {
        imageList.add(await _xFileToMap(img));
      }
      return {'images': imageList};
    } else {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: (args['quality'] as num?)?.toInt() ?? 85,
        maxWidth: (args['maxWidth'] as num?)?.toDouble() ?? 2048,
        maxHeight: (args['maxHeight'] as num?)?.toDouble() ?? 2048,
      );
      if (image == null) throw Exception('User cancelled');
      return _xFileToMap(image);
    }
  }

  Future<Map<String, dynamic>> _recordVideo(
    Map<String, dynamic> args,
  ) async {
    final maxDuration = args['maxDurationSeconds'] as int?;

    final video = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: maxDuration != null ? Duration(seconds: maxDuration) : null,
    );

    if (video == null) throw Exception('User cancelled');

    final file = File(video.path);
    final stat = await file.stat();

    return {
      'path': video.path,
      'name': video.name,
      'size': stat.size,
      'mimeType': 'video/mp4',
    };
  }

  Map<String, dynamic> _getInfo() {
    return {
      'name': name,
      'version': version,
      'supportedMethods': supportedMethods,
      'platform': Platform.operatingSystem,
    };
  }

  /// Converts a picked image to a map. The image bytes are included as
  /// `base64` so the WebView can display it directly; the file path is kept
  /// for callers that need the file itself.
  Future<Map<String, dynamic>> _xFileToMap(XFile xFile) async {
    final file = File(xFile.path);
    final bytes = await file.readAsBytes();
    return {
      'path': xFile.path,
      'name': xFile.name,
      'size': bytes.length,
      'mimeType': xFile.mimeType ?? 'image/jpeg',
      'base64': base64Encode(bytes),
    };
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'takePhoto':
        return _validateTakePhoto(args);
      case 'pickFromGallery':
        return _validatePickFromGallery(args);
      case 'recordVideo':
        return _validateRecordVideo(args);
      default:
        return ValidationResult.valid();
    }
  }

  ValidationResult _validateTakePhoto(Map<String, dynamic> args) {
    final quality = args['quality'];
    if (quality != null) {
      if (quality is! num) {
        return ValidationResult.invalid('quality must be a number');
      }
      if (quality < 0 || quality > 100) {
        return ValidationResult.invalid(
          'quality must be between 0 and 100',
        );
      }
    }
    for (final key in ['maxWidth', 'maxHeight']) {
      final dim = args[key];
      if (dim != null) {
        if (dim is! num) {
          return ValidationResult.invalid('$key must be a number');
        }
        if (dim < 1 || dim > 10000) {
          return ValidationResult.invalid(
            '$key must be between 1 and 10000',
          );
        }
      }
    }
    return ValidationResult.valid();
  }

  ValidationResult _validatePickFromGallery(Map<String, dynamic> args) {
    final multiple = args['multiple'];
    if (multiple != null && multiple is! bool) {
      return ValidationResult.invalid('multiple must be a boolean');
    }
    return ValidationResult.valid();
  }

  ValidationResult _validateRecordVideo(Map<String, dynamic> args) {
    final maxDuration = args['maxDurationSeconds'];
    if (maxDuration != null) {
      if (maxDuration is! int) {
        return ValidationResult.invalid(
          'maxDurationSeconds must be an integer',
        );
      }
      if (maxDuration <= 0 || maxDuration > 3600) {
        return ValidationResult.invalid(
          'maxDurationSeconds must be between 1 and 3600',
        );
      }
    }
    return ValidationResult.valid();
  }
}
