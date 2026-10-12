import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef A11yEventEmitter = Future<void> Function(String event, dynamic data);

class AccessibilityPlugin extends Plugin {
  final A11yEventEmitter? eventEmitter;

  AccessibilityPlugin({this.eventEmitter});

  @override
  String get name => 'accessibility';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Accessibility and screen reader plugin';

  @override
  List<String> get supportedMethods => [
        'isScreenReaderEnabled',
        'announce',
        'isBoldTextEnabled',
        'isReduceMotionEnabled',
        'isHighContrastEnabled',
        'getSettings',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'isScreenReaderEnabled':
        return _isScreenReaderEnabled();
      case 'announce':
        return _announce(args);
      case 'isBoldTextEnabled':
        return _isBoldTextEnabled();
      case 'isReduceMotionEnabled':
        return _isReduceMotionEnabled();
      case 'isHighContrastEnabled':
        return _isHighContrastEnabled();
      case 'getSettings':
        return _getSettings();
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _isScreenReaderEnabled() async {
    final binding = SemanticsBinding.instance;
    final enabled = binding.platformDispatcher.semanticsEnabled;

    return {'enabled': enabled};
  }

  Future<Map<String, dynamic>> _announce(Map<String, dynamic> args) async {
    final message = args['message'] as String;
    final assertiveness = args['assertiveness'] as String? ?? 'polite';

    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      await SemanticsService.sendAnnouncement(
        view,
        message,
        TextDirection.ltr,
        assertiveness: assertiveness == 'assertive'
            ? Assertiveness.assertive
            : Assertiveness.polite,
      );

      BridgeLogger.info('Accessibility', 'Announced: $message');

      return {'announced': true, 'message': message};
    } catch (e) {
      return {'announced': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _isBoldTextEnabled() async {
    final binding = SemanticsBinding.instance;
    final boldText = binding.platformDispatcher.accessibilityFeatures.boldText;
    return {'enabled': boldText};
  }

  Future<Map<String, dynamic>> _isReduceMotionEnabled() async {
    final binding = SemanticsBinding.instance;
    final reduceMotion =
        binding.platformDispatcher.accessibilityFeatures.reduceMotion;
    return {'enabled': reduceMotion};
  }

  Future<Map<String, dynamic>> _isHighContrastEnabled() async {
    final binding = SemanticsBinding.instance;
    final highContrast =
        binding.platformDispatcher.accessibilityFeatures.highContrast;
    return {'enabled': highContrast};
  }

  Future<Map<String, dynamic>> _getSettings() async {
    final binding = SemanticsBinding.instance;
    final features = binding.platformDispatcher.accessibilityFeatures;
    final semanticsEnabled = binding.platformDispatcher.semanticsEnabled;

    return {
      'screenReaderEnabled': semanticsEnabled,
      'boldText': features.boldText,
      'reduceMotion': features.reduceMotion,
      'highContrast': features.highContrast,
      'invertColors': features.invertColors,
      'disableAnimations': features.disableAnimations,
      'onOffSwitchLabels': features.onOffSwitchLabels,
    };
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'announce') {
      final message = args['message'];
      if (message is! String || message.isEmpty) {
        return ValidationResult.invalid('message is required');
      }
    }
    return ValidationResult.valid();
  }
}
