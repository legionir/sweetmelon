import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef CameraPreviewEventEmitter = Future<void> Function(
  String event,
  dynamic data,
);

class CameraPreviewPlugin extends Plugin {
  final CameraPreviewEventEmitter? eventEmitter;

  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _initialized = false;
  bool _recording = false;
  int _currentCameraIndex = 0;
  String? _lastPhotoPath;

  CameraPreviewPlugin({this.eventEmitter});

  @override
  String get name => 'cameraPreview';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Native camera preview with custom controls';

  @override
  List<String> get requiredPermissions => ['camera', 'microphone'];

  @override
  List<String> get supportedMethods => [
        'start',
        'stop',
        'takePhoto',
        'startRecording',
        'stopRecording',
        'switchCamera',
        'setFlashMode',
        'setZoomLevel',
        'getMinZoomLevel',
        'getMaxZoomLevel',
        'setFocusPoint',
        'setExposureMode',
        'getAvailableCameras',
        'getState',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    try {
      _cameras = await availableCameras();
      BridgeLogger.info(
        'CameraPreview',
        'Found ${_cameras?.length ?? 0} cameras',
      );
    } catch (e) {
      BridgeLogger.error('CameraPreview', 'Init failed: $e');
    }
  }

  @override
  Future<void> onDispose() async {
    await _stopController();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'start':
        return _start(args);
      case 'stop':
        return _stop();
      case 'takePhoto':
        return _takePhoto(args);
      case 'startRecording':
        return _startRecording(args);
      case 'stopRecording':
        return _stopRecording();
      case 'switchCamera':
        return _switchCamera();
      case 'setFlashMode':
        return _setFlashMode(args);
      case 'setZoomLevel':
        return _setZoomLevel(args);
      case 'getMinZoomLevel':
        return _getMinZoomLevel();
      case 'getMaxZoomLevel':
        return _getMaxZoomLevel();
      case 'setFocusPoint':
        return _setFocusPoint(args);
      case 'setExposureMode':
        return _setExposureMode(args);
      case 'getAvailableCameras':
        return _getAvailableCameras();
      case 'getState':
        return _getState();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'camerasCount': _cameras?.length ?? 0,
          'initialized': _initialized,
          'recording': _recording,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _start(Map<String, dynamic> args) async {
    if (_cameras == null || _cameras!.isEmpty) {
      return {'started': false, 'reason': 'no_cameras'};
    }

    final cameraIndex = (args['cameraIndex'] as num?)?.toInt() ?? 0;
    final resolutionStr = args['resolution'] as String? ?? 'high';
    final enableAudio = args['enableAudio'] as bool? ?? true;

    _currentCameraIndex = cameraIndex.clamp(0, _cameras!.length - 1);
    final camera = _cameras![_currentCameraIndex];
    final resolution = _parseResolution(resolutionStr);

    try {
      await _stopController();

      _controller = CameraController(
        camera,
        resolution,
        enableAudio: enableAudio,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _initialized = true;

      BridgeLogger.info('CameraPreview', 'Started: ${camera.name}');

      eventEmitter?.call('cameraPreview.started', {
        'cameraIndex': _currentCameraIndex,
        'cameraName': camera.name,
        'lensDirection': camera.lensDirection.name,
        'resolution': resolutionStr,
      });

      return {
        'started': true,
        'cameraIndex': _currentCameraIndex,
        'cameraName': camera.name,
        'lensDirection': camera.lensDirection.name,
        'sensorOrientation': camera.sensorOrientation,
      };
    } catch (e) {
      BridgeLogger.error('CameraPreview', 'Start failed: $e');
      return {'started': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _stop() async {
    await _stopController();

    eventEmitter?.call('cameraPreview.stopped', {
      'timestamp': DateTime.now().toIso8601String(),
    });

    return {'stopped': true};
  }

  Future<void> _stopController() async {
    if (_recording) {
      try {
        await _controller?.stopVideoRecording();
      } catch (_) {}
      _recording = false;
    }
    await _controller?.dispose();
    _controller = null;
    _initialized = false;
  }

  Future<Map<String, dynamic>> _takePhoto(Map<String, dynamic> args) async {
    if (!_initialized || _controller == null) {
      return {'captured': false, 'reason': 'not_initialized'};
    }

    final fileName = args['fileName'] as String? ??
        'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      final xFile = await _controller!.takePicture();

      final dir = await getApplicationDocumentsDirectory();
      final photoDir = Directory(p.join(dir.path, 'camera'));
      await photoDir.create(recursive: true);

      final targetPath = p.join(photoDir.path, fileName);
      final file = File(xFile.path);
      await file.copy(targetPath);
      await file.delete();

      final stat = await File(targetPath).stat();
      _lastPhotoPath = targetPath;

      BridgeLogger.info('CameraPreview', 'Photo taken: $targetPath');

      eventEmitter?.call('cameraPreview.photoTaken', {
        'path': targetPath,
        'fileName': fileName,
        'size': stat.size,
      });

      return {
        'captured': true,
        'path': targetPath,
        'fileName': fileName,
        'size': stat.size,
      };
    } catch (e) {
      return {'captured': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _startRecording(
    Map<String, dynamic> args,
  ) async {
    if (!_initialized || _controller == null) {
      return {'started': false, 'reason': 'not_initialized'};
    }
    if (_recording) {
      return {'started': false, 'reason': 'already_recording'};
    }

    try {
      await _controller!.startVideoRecording();
      _recording = true;

      eventEmitter?.call('cameraPreview.recordingStarted', {
        'timestamp': DateTime.now().toIso8601String(),
      });

      return {'started': true};
    } catch (e) {
      return {'started': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _stopRecording() async {
    if (!_recording || _controller == null) {
      return {'stopped': false, 'reason': 'not_recording'};
    }

    try {
      final xFile = await _controller!.stopVideoRecording();
      _recording = false;

      final dir = await getApplicationDocumentsDirectory();
      final videoDir = Directory(p.join(dir.path, 'camera'));
      await videoDir.create(recursive: true);

      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final targetPath = p.join(videoDir.path, fileName);
      final file = File(xFile.path);
      await file.copy(targetPath);
      await file.delete();

      final stat = await File(targetPath).stat();

      eventEmitter?.call('cameraPreview.recordingStopped', {
        'path': targetPath,
        'size': stat.size,
      });

      return {
        'stopped': true,
        'path': targetPath,
        'fileName': fileName,
        'size': stat.size,
      };
    } catch (e) {
      _recording = false;
      return {'stopped': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      return {'switched': false, 'reason': 'no_other_camera'};
    }

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras!.length;

    await _stop();
    final result = await _start({
      'cameraIndex': _currentCameraIndex,
    });

    return {
      'switched': true,
      'cameraIndex': _currentCameraIndex,
      'lensDirection': _cameras![_currentCameraIndex].lensDirection.name,
      ...result,
    };
  }

  Future<Map<String, dynamic>> _setFlashMode(
    Map<String, dynamic> args,
  ) async {
    if (_controller == null) {
      return {'set': false, 'reason': 'not_initialized'};
    }

    final mode = _parseFlashMode(args['mode'] as String? ?? 'auto');

    try {
      await _controller!.setFlashMode(mode);
      return {'set': true, 'mode': mode.name};
    } catch (e) {
      return {'set': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _setZoomLevel(
    Map<String, dynamic> args,
  ) async {
    if (_controller == null) {
      return {'set': false, 'reason': 'not_initialized'};
    }

    final zoom = (args['zoom'] as num).toDouble();

    try {
      await _controller!.setZoomLevel(zoom);
      return {'set': true, 'zoom': zoom};
    } catch (e) {
      return {'set': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getMinZoomLevel() async {
    if (_controller == null) return {'level': 1.0};
    final min = await _controller!.getMinZoomLevel();
    return {'level': min};
  }

  Future<Map<String, dynamic>> _getMaxZoomLevel() async {
    if (_controller == null) return {'level': 1.0};
    final max = await _controller!.getMaxZoomLevel();
    return {'level': max};
  }

  Future<Map<String, dynamic>> _setFocusPoint(
    Map<String, dynamic> args,
  ) async {
    if (_controller == null) {
      return {'set': false, 'reason': 'not_initialized'};
    }

    final x = (args['x'] as num).toDouble();
    final y = (args['y'] as num).toDouble();

    try {
      await _controller!.setFocusPoint(Offset(x, y));
      return {'set': true, 'x': x, 'y': y};
    } catch (e) {
      return {'set': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _setExposureMode(
    Map<String, dynamic> args,
  ) async {
    if (_controller == null) {
      return {'set': false, 'reason': 'not_initialized'};
    }

    final mode = args['mode'] as String? ?? 'auto';

    try {
      await _controller!.setExposureMode(
        mode == 'locked' ? ExposureMode.locked : ExposureMode.auto,
      );
      return {'set': true, 'mode': mode};
    } catch (e) {
      return {'set': false, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _getAvailableCameras() {
    return {
      'cameras': _cameras
              ?.map((c) => {
                    'name': c.name,
                    'lensDirection': c.lensDirection.name,
                    'sensorOrientation': c.sensorOrientation,
                  })
              .toList() ??
          [],
      'count': _cameras?.length ?? 0,
    };
  }

  Map<String, dynamic> _getState() {
    return {
      'initialized': _initialized,
      'recording': _recording,
      'currentCameraIndex': _currentCameraIndex,
      'lastPhotoPath': _lastPhotoPath,
      'hasController': _controller != null,
    };
  }

  ResolutionPreset _parseResolution(String resolution) {
    switch (resolution) {
      case 'low':
        return ResolutionPreset.low;
      case 'medium':
        return ResolutionPreset.medium;
      case 'high':
        return ResolutionPreset.high;
      case 'veryHigh':
        return ResolutionPreset.veryHigh;
      case 'ultraHigh':
        return ResolutionPreset.ultraHigh;
      case 'max':
        return ResolutionPreset.max;
      default:
        return ResolutionPreset.high;
    }
  }

  FlashMode _parseFlashMode(String mode) {
    switch (mode) {
      case 'off':
        return FlashMode.off;
      case 'auto':
        return FlashMode.auto;
      case 'always':
        return FlashMode.always;
      case 'torch':
        return FlashMode.torch;
      default:
        return FlashMode.auto;
    }
  }
}
