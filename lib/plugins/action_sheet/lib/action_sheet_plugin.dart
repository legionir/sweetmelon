import 'package:flutter/material.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';
import 'package:sweetmelon/plugins/qr_scanner/lib/qr_scanner_plugin.dart';

class ActionSheetPlugin extends Plugin {
  @override
  String get name => 'actionSheet';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Bottom sheet action selector plugin';

  @override
  List<String> get supportedMethods => [
        'show',
        'getInfo',
      ];

  BuildContext? get _context => QrScannerPlugin.navigatorKey?.currentContext;

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'show':
        return _show(args);
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _show(Map<String, dynamic> args) async {
    final context = _context;
    if (context == null) {
      return {'selected': false, 'reason': 'no_context'};
    }

    final title = args['title'] as String?;
    final message = args['message'] as String?;
    final options = List<Map<String, dynamic>>.from(
      (args['options'] as List).map(
        (o) => o is String ? {'title': o} : Map<String, dynamic>.from(o as Map),
      ),
    );
    final cancelText = args['cancelText'] as String? ?? 'Cancel';
    final destructiveIndex = (args['destructiveIndex'] as num?)?.toInt();

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ActionSheetWidget(
        title: title,
        message: message,
        options: options,
        cancelText: cancelText,
        destructiveIndex: destructiveIndex,
      ),
    );

    if (result == null) {
      return {'selected': false, 'reason': 'cancelled'};
    }

    return {
      'selected': true,
      'index': result,
      'value': options[result]['title'],
      'option': options[result],
    };
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'show') {
      final options = args['options'];
      if (options is! List || options.isEmpty) {
        return ValidationResult.invalid('options (non-empty list) is required');
      }
    }
    return ValidationResult.valid();
  }
}

class _ActionSheetWidget extends StatelessWidget {
  final String? title;
  final String? message;
  final List<Map<String, dynamic>> options;
  final String cancelText;
  final int? destructiveIndex;

  const _ActionSheetWidget({
    this.title,
    this.message,
    required this.options,
    required this.cancelText,
    this.destructiveIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title / Message
            if (title != null || message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          message!,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),

            const Divider(color: Colors.white12, height: 1),

            // Options
            ...options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isDestructive = index == destructiveIndex;
              final icon = option['icon'] as String?;

              return InkWell(
                onTap: () => Navigator.of(context).pop(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white12, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Icon(
                          _parseIcon(icon),
                          color: isDestructive ? Colors.red : Colors.white70,
                          size: 22,
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Text(
                          option['title'] as String? ?? '',
                          style: TextStyle(
                            color: isDestructive ? Colors.red : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (option['subtitle'] != null)
                        Text(
                          option['subtitle'] as String,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),

            // Cancel
            InkWell(
              onTap: () => Navigator.of(context).pop(null),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                width: double.infinity,
                child: Text(
                  cancelText,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _parseIcon(String name) {
    switch (name) {
      case 'delete':
        return Icons.delete_outline;
      case 'edit':
        return Icons.edit_outlined;
      case 'share':
        return Icons.share_outlined;
      case 'copy':
        return Icons.copy_outlined;
      case 'camera':
        return Icons.camera_alt_outlined;
      case 'photo':
        return Icons.photo_outlined;
      case 'file':
        return Icons.attach_file;
      case 'download':
        return Icons.download_outlined;
      case 'upload':
        return Icons.upload_outlined;
      case 'settings':
        return Icons.settings_outlined;
      case 'info':
        return Icons.info_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}
