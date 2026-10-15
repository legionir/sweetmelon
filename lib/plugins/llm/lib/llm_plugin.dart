import 'dart:async';

import 'package:llamadart/llamadart.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef LlmEventEmitter = Future<void> Function(String event, dynamic data);

/// Chat with a GGUF language model on the device (llama.cpp, through the
/// `llamadart` package). No server and no internet once the model is there.
///
/// Models come from the `modelManager` plugin (kind `llm`): the user imports a
/// `.gguf` (and, for image input, its `mmproj` projector) from their own files.
/// This plugin only opens files inside the models folder.
///
/// Generation streams: `chat` returns at once and the answer arrives as
/// `llm.token` events, then `llm.done`.
class LlmPlugin extends Plugin {
  LlmPlugin({this.eventEmitter, ModelStore? store}) : _store = store;

  final LlmEventEmitter? eventEmitter;
  ModelStore? _store;

  LlamaEngine? _engine;
  ChatSession? _session;
  String? _modelId;
  bool _vision = false;
  bool _loading = false;
  bool _generating = false;
  int _sequence = 0;

  @override
  String get name => 'llm';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'On-device chat with GGUF language models';

  // Nothing here needs a permission: the model files are the app's own.
  @override
  List<String> get requiredPermissions => const [];

  @override
  List<String> get supportedMethods => [
        'load',
        'unload',
        'chat',
        'stop',
        'reset',
        'setSystemPrompt',
        'getHistory',
        'countTokens',
        'status',
        'getInfo',
      ];

  Future<ModelStore> _getStore() async => _store ??= await ModelStore.forApp();

  @override
  Future<void> onDispose() async {
    _engine?.cancelGeneration();
    await _engine?.dispose();
    _engine = null;
    _session = null;
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'load':
        return _load(args);
      case 'unload':
        return _unload();
      case 'chat':
        return _chat(args);
      case 'stop':
        _engine?.cancelGeneration();
        return {'stopped': true};
      case 'reset':
        _session?.reset(
            keepSystemPrompt: args['keepSystemPrompt'] as bool? ?? true);
        return {'reset': true};
      case 'setSystemPrompt':
        _session?.systemPrompt = args['text'] as String?;
        return {'set': true};
      case 'getHistory':
        return _history();
      case 'countTokens':
        return _countTokens(args);
      case 'status':
      case 'getInfo':
        return _status();
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<void> _emit(String event, Map<String, dynamic> data) async {
    await eventEmitter?.call(event, data);
  }

  Map<String, dynamic> _status() => {
        'name': name,
        'version': version,
        'loaded': _engine != null && !_loading,
        'loading': _loading,
        'generating': _generating,
        'modelId': _modelId,
        'vision': _vision,
      };

  /// Loads a model. Either `modelId` (a model of the `modelManager`) or `path`
  /// (a file inside the models folder, plus an optional `mmproj`).
  Future<Map<String, dynamic>> _load(Map<String, dynamic> args) async {
    if (_loading) return {'loaded': false, 'reason': 'busy'};
    _loading = true;
    await _emit('llm.state', {'state': 'loading'});

    try {
      final store = await _getStore();
      String modelPath;
      String? mmprojPath;
      String? modelId;

      final id = args['modelId'] as String?;
      if (id != null) {
        final entry = await store.get(id);
        if (entry == null) throw ArgumentError('Model "$id" not found');
        final files = detectLlmFiles(entry.files);
        if (files == null) {
          throw ArgumentError('Model "$id" has no .gguf file');
        }
        modelPath = files.model.path;
        mmprojPath = files.mmproj?.path;
        modelId = id;
      } else {
        modelPath = store.requireInside(args['path'] as String);
        final mmproj = args['mmproj'] as String?;
        mmprojPath = mmproj == null ? null : store.requireInside(mmproj);
      }
      if (args['withProjector'] == false) mmprojPath = null;

      await _releaseEngine();

      final engine = await LlamaEngine.load(
        LlamaModel(
          ModelSource.path(modelPath),
          projector: mmprojPath == null ? null : ModelSource.path(mmprojPath),
        ),
        params: _modelParams(args),
      );

      final capabilities = await engine.capabilities;
      _engine = engine;
      _session = ChatSession(
        engine,
        systemPrompt: args['systemPrompt'] as String?,
        maxContextTokens: _intOf(args['maxContextTokens']),
      );
      _modelId = modelId;
      _vision = capabilities.supportsVision;

      final info = {
        'loaded': true,
        'modelId': modelId,
        'path': modelPath,
        'contextSize': await engine.getContextSize(),
        'backend': await engine.getBackendName(),
        'vision': _vision,
      };
      await _emit('llm.state', {'state': 'ready', ...info});
      return info;
    } catch (e) {
      BridgeLogger.error('LLM', 'Load failed: $e');
      await _emit('llm.state', {'state': 'error', 'message': e.toString()});
      rethrow;
    } finally {
      _loading = false;
    }
  }

  ModelParams _modelParams(Map<String, dynamic> args) {
    return ModelParams(
      contextSize: _intOf(args['contextSize']) ?? 4096,
      device: _device(args['device'] as String?),
      gpuLayers: _intOf(args['gpuLayers']) ?? ModelParams.maxGpuLayers,
      numberOfThreads: _intOf(args['threads']) ?? 0,
      numberOfThreadsBatch: _intOf(args['threadsBatch']) ?? 0,
      batchSize: _intOf(args['batchSize']) ?? 0,
      microBatchSize: _intOf(args['microBatchSize']) ?? 0,
      useMmap: args['useMmap'] as bool? ?? true,
      useMlock: args['useMlock'] as bool? ?? false,
      flashAttention: _flashAttention(args['flashAttention'] as String?),
      cacheTypeK: _kvCache(args['kvCacheType'] as String?),
      cacheTypeV: _kvCache(args['kvCacheType'] as String?),
      chatTemplate: _nonEmpty(args['chatTemplate'] as String?),
      ropeFrequencyBase: (args['ropeFrequencyBase'] as num?)?.toDouble(),
      ropeFrequencyScale: (args['ropeFrequencyScale'] as num?)?.toDouble(),
    );
  }

  Future<Map<String, dynamic>> _unload() async {
    await _releaseEngine();
    await _emit('llm.state', {'state': 'unloaded'});
    return {'unloaded': true};
  }

  Future<void> _releaseEngine() async {
    final engine = _engine;
    if (engine == null) return;
    engine.cancelGeneration();
    _engine = null;
    _session = null;
    _modelId = null;
    _vision = false;
    await engine.dispose();
  }

  /// Starts a reply. The text arrives as `llm.token` events
  /// (`{requestId, text, thinking}`), the end as `llm.done`
  /// (`{requestId, text, thinking, usage, stopped}`) or `llm.error`.
  Future<Map<String, dynamic>> _chat(Map<String, dynamic> args) async {
    final session = _session;
    if (session == null) {
      return {'started': false, 'reason': 'not_loaded'};
    }
    if (_generating) return {'started': false, 'reason': 'busy'};

    final text = args['text'] as String;
    final images = (args['images'] as List?)?.cast<String>() ?? const [];
    if (images.isNotEmpty && !_vision) {
      return {'started': false, 'reason': 'no_vision'};
    }
    for (final image in images) {
      await _requireAppPath(image);
    }

    final systemPrompt = args['systemPrompt'] as String?;
    if (systemPrompt != null) session.systemPrompt = systemPrompt;

    final requestId = (args['requestId'] as String?) ?? 'r${++_sequence}';
    final params = _generationParams(
        (args['params'] as Map?)?.cast<String, dynamic>() ?? const {});
    final enableThinking =
        (args['params'] as Map?)?['enableThinking'] as bool? ?? true;

    final parts = <LlamaContentPart>[
      for (final image in images) LlamaImageContent(path: image),
      LlamaTextContent(text),
    ];

    _generating = true;
    unawaited(_run(session, parts, params, enableThinking, requestId));
    return {'started': true, 'requestId': requestId};
  }

  Future<void> _run(
    ChatSession session,
    List<LlamaContentPart> parts,
    GenerationParams params,
    bool enableThinking,
    String requestId,
  ) async {
    final answer = StringBuffer();
    final thinking = StringBuffer();
    LlamaGenerationUsage? usage;
    var tokens = 0;
    var cancelled = false;

    try {
      await for (final chunk in session.create(
        parts,
        params: params,
        enableThinking: enableThinking,
      )) {
        final delta = chunk.text;
        final thought = chunk.thinking;
        if (chunk.usage != null) usage = chunk.usage;
        if (delta.isEmpty && thought.isEmpty) continue;
        answer.write(delta);
        thinking.write(thought);
        tokens++;
        await _emit('llm.token', {
          'requestId': requestId,
          'text': delta,
          'thinking': thought,
          'index': tokens,
        });
      }
    } on LlamaException catch (e) {
      // A cancelled generation ends the stream with an exception on some
      // backends; report it as a stop, not as a failure.
      if (_isCancel(e)) {
        cancelled = true;
      } else {
        BridgeLogger.error('LLM', 'Generation failed: $e');
        _generating = false;
        await _emit(
            'llm.error', {'requestId': requestId, 'message': e.toString()});
        return;
      }
    } catch (e) {
      BridgeLogger.error('LLM', 'Generation failed: $e');
      _generating = false;
      await _emit(
          'llm.error', {'requestId': requestId, 'message': e.toString()});
      return;
    }

    _generating = false;
    await _emit('llm.done', {
      'requestId': requestId,
      'text': answer.toString(),
      'thinking': thinking.toString(),
      'stopped': cancelled,
      'usage': usage == null
          ? null
          : {
              'promptTokens': usage.promptTokens,
              'completionTokens': usage.completionTokens,
              'timeToFirstTokenMs': usage.timeToFirstToken?.inMilliseconds,
              'durationMs': usage.duration?.inMilliseconds,
            },
    });
  }

  static bool _isCancel(LlamaException e) =>
      e.toString().toLowerCase().contains('cancel');

  GenerationParams _generationParams(Map<String, dynamic> a) {
    final thinkingBudget = _intOf(a['thinkingBudget']);
    return GenerationParams(
      maxTokens: _intOf(a['maxTokens']) ?? 1024,
      temp: (a['temperature'] as num?)?.toDouble() ?? 0.8,
      topK: _intOf(a['topK']) ?? 40,
      topP: (a['topP'] as num?)?.toDouble() ?? 0.9,
      minP: (a['minP'] as num?)?.toDouble() ?? 0.0,
      penalty: (a['repeatPenalty'] as num?)?.toDouble() ?? 1.1,
      presencePenalty: (a['presencePenalty'] as num?)?.toDouble() ?? 0.0,
      seed: _intOf(a['seed']),
      stopSequences: (a['stop'] as List?)?.cast<String>() ?? const [],
      thinkingBudget: thinkingBudget == null
          ? null
          : ThinkingBudget(maxTokens: thinkingBudget),
      streamBatchTokenThreshold: _intOf(a['streamBatchTokens']) ?? 1,
    );
  }

  Map<String, dynamic> _history() {
    final session = _session;
    if (session == null) return {'messages': <dynamic>[]};
    return {
      'systemPrompt': session.systemPrompt,
      'messages': [
        for (final message in session.history)
          {'role': message.role.name, 'text': message.content},
      ],
    };
  }

  Future<Map<String, dynamic>> _countTokens(Map<String, dynamic> args) async {
    final engine = _engine;
    if (engine == null) return {'tokens': 0, 'reason': 'not_loaded'};
    return {'tokens': await engine.getTokenCount(args['text'] as String)};
  }

  /// Images for a multimodal question come from the user's pick (the app's
  /// cache) or the camera: only the app's own folders are readable.
  Future<void> _requireAppPath(String path) async {
    final roots = <String>[
      (await getTemporaryDirectory()).path,
      (await getApplicationCacheDirectory()).path,
      (await getApplicationDocumentsDirectory()).path,
      (await getApplicationSupportDirectory()).path,
    ];
    final normalized = p.normalize(path);
    final inside = p.isAbsolute(normalized) &&
        roots.any((root) => p.isWithin(root, normalized));
    if (!inside) {
      throw ArgumentError('Image is not inside the app folders: $path');
    }
  }

  static int? _intOf(dynamic value) => (value as num?)?.toInt();

  static String? _nonEmpty(String? value) =>
      value == null || value.trim().isEmpty ? null : value;

  static ComputeDevice _device(String? name) {
    switch (name) {
      case 'cpu':
        return ComputeDevice.cpu;
      case 'gpu':
        return ComputeDevice.gpu;
      default:
        return ComputeDevice.auto;
    }
  }

  static FlashAttention _flashAttention(String? name) {
    switch (name) {
      case 'on':
        return FlashAttention.enabled;
      case 'off':
        return FlashAttention.disabled;
      default:
        return FlashAttention.auto;
    }
  }

  static KvCacheType _kvCache(String? name) {
    switch (name) {
      case 'q8_0':
        return KvCacheType.q8_0;
      case 'q4_0':
        return KvCacheType.q4_0;
      default:
        return KvCacheType.f16;
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'load':
        if (args['modelId'] is! String && args['path'] is! String) {
          return ValidationResult.invalid('modelId or path is required');
        }
        return ValidationResult.valid();
      case 'chat':
        if (args['text'] is! String || (args['text'] as String).isEmpty) {
          return ValidationResult.invalid('text is required');
        }
        final images = args['images'];
        if (images != null &&
            (images is! List || images.any((e) => e is! String))) {
          return ValidationResult.invalid(
              'images must be a list of file paths');
        }
        return ValidationResult.valid();
      case 'countTokens':
        if (args['text'] is! String) {
          return ValidationResult.invalid('text is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
