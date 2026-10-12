import 'dart:async';
import 'dart:convert';

import 'package:sweetmelon/packages/core/lib/core.dart';

/// مدیریت داده‌های بزرگ از طریق chunked streaming
class StreamHandler {
  static const int defaultChunkSize = 64 * 1024; // 64KB
  static const int maxConcurrentStreams = 10;

  final Map<String, StreamSession> _activeSessions = {};
  final Future<void> Function(String js) _jsRunner;

  StreamHandler({required Future<void> Function(String js) jsRunner})
      : _jsRunner = jsRunner;

  /// ارسال داده بزرگ به JS به صورت chunked
  Future<void> sendLargeData(
    String streamId,
    List<int> data, {
    int chunkSize = defaultChunkSize,
    String dataType = 'binary',
  }) async {
    if (_activeSessions.length >= maxConcurrentStreams) {
      throw StateError('Max concurrent streams reached');
    }

    final totalChunks = (data.length / chunkSize).ceil();
    final session = StreamSession(
      id: streamId,
      totalBytes: data.length,
      totalChunks: totalChunks,
      dataType: dataType,
    );

    _activeSessions[streamId] = session;

    BridgeLogger.debug(
      'StreamHandler',
      'Starting stream $streamId: ${data.length} bytes in $totalChunks chunks',
    );

    // ارسال start event
    await _jsRunner(
      'window.__streamStart("$streamId", ${jsonEncode({
            "totalBytes": data.length,
            "totalChunks": totalChunks,
            "chunkSize": chunkSize,
            "dataType": dataType,
          })});',
    );

    // ارسال chunk‌ها
    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize).clamp(0, data.length);
      final chunk = data.sublist(start, end);
      final chunkB64 = base64Encode(chunk);

      await _jsRunner(
        'window.__streamChunk("$streamId", $i, "$chunkB64");',
      );

      session.sentChunks++;
      session.sentBytes += chunk.length;

      // yield به event loop تا UI block نشه
      await Future.delayed(Duration.zero);
    }

    // ارسال end event
    await _jsRunner(
      'window.__streamEnd("$streamId");',
    );

    _activeSessions.remove(streamId);
    BridgeLogger.debug('StreamHandler', 'Stream $streamId completed');
  }

  /// ارسال text data به صورت chunked
  Future<void> sendLargeText(
    String streamId,
    String text, {
    int chunkSize = defaultChunkSize,
  }) async {
    final bytes = utf8.encode(text);
    await sendLargeData(
      streamId,
      bytes,
      chunkSize: chunkSize,
      dataType: 'text',
    );
  }

  /// لغو یک stream
  Future<void> cancelStream(String streamId) async {
    _activeSessions.remove(streamId);
    await _jsRunner('window.__streamCancel("$streamId");');
  }

  Map<String, dynamic> get stats => {
        'activeSessions': _activeSessions.length,
        'sessions': _activeSessions.values.map((s) => s.toJson()).toList(),
      };

  /// JS code برای inject در WebView
  static String get jsStreamingCode => r'''
    (function() {
      window.__streams = {};
      
      window.__streamStart = function(streamId, meta) {
        window.__streams[streamId] = {
          id: streamId,
          chunks: [],
          receivedChunks: 0,
          totalChunks: meta.totalChunks,
          totalBytes: meta.totalBytes,
          dataType: meta.dataType,
          startTime: Date.now()
        };
        
        if (window.__streamListeners && window.__streamListeners[streamId]) {
          window.__streamListeners[streamId].onStart && 
            window.__streamListeners[streamId].onStart(meta);
        }
      };
      
      window.__streamChunk = function(streamId, index, chunkB64) {
        var stream = window.__streams[streamId];
        if (!stream) return;
        
        stream.chunks[index] = chunkB64;
        stream.receivedChunks++;
        
        var progress = stream.receivedChunks / stream.totalChunks;
        
        if (window.__streamListeners && window.__streamListeners[streamId]) {
          window.__streamListeners[streamId].onProgress && 
            window.__streamListeners[streamId].onProgress(progress, index);
        }
      };
      
      window.__streamEnd = function(streamId) {
        var stream = window.__streams[streamId];
        if (!stream) return;
        
        try {
          var combined = stream.chunks.join('');
          var result;
          
          if (stream.dataType === 'text') {
            var bytes = atob(combined);
            result = decodeURIComponent(escape(bytes));
          } else {
            result = combined;
          }
          
          var duration = Date.now() - stream.startTime;
          
          if (window.__streamListeners && window.__streamListeners[streamId]) {
            window.__streamListeners[streamId].onComplete && 
              window.__streamListeners[streamId].onComplete(result, {
                duration: duration,
                totalBytes: stream.totalBytes
              });
          }
        } finally {
          delete window.__streams[streamId];
          delete window.__streamListeners[streamId];
        }
      };
      
      window.__streamCancel = function(streamId) {
        if (window.__streamListeners && window.__streamListeners[streamId]) {
          window.__streamListeners[streamId].onCancel && 
            window.__streamListeners[streamId].onCancel();
        }
        delete window.__streams[streamId];
        delete window.__streamListeners[streamId];
      };
      
      // API برای JS
      window.NativeStream = {
        listen: function(streamId, callbacks) {
          if (!window.__streamListeners) window.__streamListeners = {};
          window.__streamListeners[streamId] = callbacks;
        },
        
        promise: function(streamId) {
          return new Promise(function(resolve, reject) {
            window.NativeStream.listen(streamId, {
              onComplete: resolve,
              onCancel: function() { reject(new Error('Stream cancelled')); }
            });
          });
        }
      };
    })();
  ''';
}

class StreamSession {
  final String id;
  final int totalBytes;
  final int totalChunks;
  final String dataType;
  int sentChunks = 0;
  int sentBytes = 0;
  final DateTime startedAt = DateTime.now();

  StreamSession({
    required this.id,
    required this.totalBytes,
    required this.totalChunks,
    required this.dataType,
  });

  double get progress => totalChunks > 0 ? sentChunks / totalChunks : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'totalBytes': totalBytes,
        'totalChunks': totalChunks,
        'sentChunks': sentChunks,
        'sentBytes': sentBytes,
        'progress': progress,
        'dataType': dataType,
        'ageMs': DateTime.now().difference(startedAt).inMilliseconds,
      };
}
