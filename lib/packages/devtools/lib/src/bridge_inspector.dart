import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class BridgeInspector {
  final MessageBridge bridge;
  final PluginManager manager;

  final List<InspectorEntry> _log = [];
  final _logController = StreamController<InspectorEntry>.broadcast();

  StreamSubscription<BridgeMessage>? _bridgeSub;
  StreamSubscription<PluginTrace>? _traceSub;

  bool _disposed = false;

  Stream<InspectorEntry> get logStream => _logController.stream;
  List<InspectorEntry> get log => List.unmodifiable(_log);

  BridgeInspector({
    required this.bridge,
    required this.manager,
  }) {
    _attachListeners();
  }

  void _attachListeners() {
    _bridgeSub = bridge.messageStream.listen((message) {
      if (_disposed) return;

      final entry = InspectorEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        direction: message.direction == BridgeMessageDirection.incoming
            ? EntryDirection.jsToFlutter
            : EntryDirection.flutterToJs,
        timestamp: message.timestamp,
        content: message.message.toJson(),
      );

      _log.add(entry);
      if (_log.length > 500) _log.removeAt(0);

      if (!_logController.isClosed) {
        _logController.add(entry);
      }
    });

    _traceSub = manager.traces.listen((trace) {
      if (_disposed) return;

      BridgeLogger.debug(
        'Inspector',
        '${trace.plugin}.${trace.method} — '
            '${trace.processingTimeMs}ms '
            '${trace.success ? "OK" : "FAIL"}',
      );
    });
  }

  void clear() => _log.clear();

  Map<String, dynamic> getReport() {
    final stats = manager.stats;
    return {
      'totalRequests': _log.length,
      'pluginStats': stats.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'recentErrors':
          _log.where((e) => e.isError).take(10).map((e) => e.toJson()).toList(),
    };
  }

  void dispose() {
    _disposed = true;
    _bridgeSub?.cancel();
    _traceSub?.cancel();
    if (!_logController.isClosed) {
      _logController.close();
    }
  }
}

enum EntryDirection { jsToFlutter, flutterToJs }

class InspectorEntry {
  final String id;
  final EntryDirection direction;
  final DateTime timestamp;
  final Map<String, dynamic> content;

  const InspectorEntry({
    required this.id,
    required this.direction,
    required this.timestamp,
    required this.content,
  });

  bool get isError => content['success'] == false;

  String get summary {
    final plugin = content['plugin'] as String?;
    final method = content['method'] as String?;
    if (plugin != null && method != null) return '$plugin.$method';
    if (content['success'] == true) return 'response (ok)';
    if (content['success'] == false) return 'response (error)';
    return 'message';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'direction': direction.name,
        'timestamp': timestamp.toIso8601String(),
        'content': content,
        'isError': isError,
      };
}

class BridgeInspectorWidget extends StatefulWidget {
  final BridgeInspector inspector;

  const BridgeInspectorWidget({
    super.key,
    required this.inspector,
  });

  @override
  State<BridgeInspectorWidget> createState() => _BridgeInspectorWidgetState();
}

class _BridgeInspectorWidgetState extends State<BridgeInspectorWidget> {
  final List<InspectorEntry> _entries = [];
  StreamSubscription<InspectorEntry>? _sub;
  String _filter = '';
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _entries.addAll(widget.inspector.log);
    _sub = widget.inspector.logStream.listen((entry) {
      if (mounted) {
        setState(() => _entries.insert(0, entry));
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<InspectorEntry> get _filteredEntries {
    var list = List<InspectorEntry>.from(_entries);
    if (_showErrors) {
      list = list.where((e) => e.isError).toList();
    }
    if (_filter.isNotEmpty) {
      final lowerFilter = _filter.toLowerCase();
      list = list.where((e) {
        final content = jsonEncode(e.content).toLowerCase();
        return content.contains(lowerFilter);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Bridge Inspector',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontSize: 16,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.white),
            tooltip: 'Clear log',
            onPressed: () {
              widget.inspector.clear();
              setState(() => _entries.clear());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(child: _buildList()),
          _buildStats(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF16213E),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Filter...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 16,
                  color: Colors.white38,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Errors', style: TextStyle(fontSize: 11)),
            selected: _showErrors,
            onSelected: (v) => setState(() => _showErrors = v),
            backgroundColor: Colors.transparent,
            selectedColor: Colors.red.withValues(alpha: 0.3),
            side: BorderSide(
              color: _showErrors ? Colors.red : Colors.white24,
            ),
            labelStyle: TextStyle(
              color: _showErrors ? Colors.red : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final entries = _filteredEntries;

    if (entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, color: Colors.white24, size: 48),
            SizedBox(height: 8),
            Text('No messages', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: entries.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (ctx, i) => _EntryTile(entry: entries[i]),
    );
  }

  Widget _buildStats() {
    final errorCount = _entries.where((e) => e.isError).length;

    return Container(
      color: const Color(0xFF0F3460),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Total: ${_entries.length}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Errors: $errorCount',
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          Text(
            'Filtered: ${_filteredEntries.length}',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatefulWidget {
  final InspectorEntry entry;
  const _EntryTile({required this.entry});

  @override
  State<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<_EntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isIncoming = widget.entry.direction == EntryDirection.jsToFlutter;
    final isError = widget.entry.isError;

    final borderColor = isError
        ? Colors.red.withValues(alpha: 0.5)
        : isIncoming
            ? Colors.blue.withValues(alpha: 0.3)
            : Colors.green.withValues(alpha: 0.3);

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(
                    isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 14,
                    color: isIncoming ? Colors.blue : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.entry.summary,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isError)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'ERR',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(widget.entry.timestamp),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
            if (_expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.black26,
                child: SelectableText(
                  const JsonEncoder.withIndent('  ')
                      .convert(widget.entry.content),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}
