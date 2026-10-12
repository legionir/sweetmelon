import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/devtools/lib/devtools.dart';

import '../di/service_locator.dart';

// ============================================================
// HOME SCREEN
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showInspector = false;

  @override
  Widget build(BuildContext context) {
    final bridge = sl<MessageBridge>();
    final config = sl<WebViewHostConfig>();
    final assetConfig = sl<AssetServerConfig>();
    final inspector = sl<BridgeInspector>();

    return Scaffold(
      body: Stack(
        children: [
          WebViewHost(
            loadFromAssets: true,
            config: config,
            assetConfig: assetConfig,
            bridge: bridge,
            onPageLoaded: () {
              debugPrint('Page loaded successfully');
            },
          ),
          if (kDebugMode && _showInspector)
            DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.2,
              maxChildSize: 0.9,
              builder: (ctx, controller) => Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: BridgeInspectorWidget(inspector: inspector),
              ),
            ),
        ],
      ),
      // The inspector shows bridge traffic; it is never offered in release.
      floatingActionButton: kDebugMode
          ? FloatingActionButton.small(
              onPressed: () => setState(() => _showInspector = !_showInspector),
              backgroundColor: const Color(0xFF6C63FF),
              child: Icon(
                _showInspector ? Icons.close : Icons.bug_report,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}
