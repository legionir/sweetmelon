import 'model_store.dart';

/// Works out which file of a model folder does what, from the file names.
///
/// People get models from different places (Hugging Face, the sherpa-onnx
/// releases) and name files differently, so the rules are loose: they look at
/// the words in the name, not an exact name.

/// The files of a GGUF language model.
class LlmFiles {
  const LlmFiles({required this.model, this.mmproj});

  /// The language model (the largest `.gguf` that is not a projector).
  final ModelFile model;

  /// The multimodal projector (`mmproj*.gguf`), when the folder has one.
  final ModelFile? mmproj;
}

LlmFiles? detectLlmFiles(List<ModelFile> files) {
  final ggufs = files.where((f) => f.name.toLowerCase().endsWith('.gguf'));
  final projectors =
      ggufs.where((f) => f.name.toLowerCase().contains('mmproj')).toList();
  final models = ggufs
      .where((f) => !f.name.toLowerCase().contains('mmproj'))
      .toList()
    ..sort((a, b) => b.size.compareTo(a.size));
  if (models.isEmpty) return null;
  projectors.sort((a, b) => b.size.compareTo(a.size));
  return LlmFiles(
    model: models.first,
    mmproj: projectors.isEmpty ? null : projectors.first,
  );
}

enum AsrType { whisper, transducer, senseVoice, paraformer }

AsrType? asrTypeFromName(String? name) {
  switch (name) {
    case 'whisper':
      return AsrType.whisper;
    case 'transducer':
      return AsrType.transducer;
    case 'sense_voice':
      return AsrType.senseVoice;
    case 'paraformer':
      return AsrType.paraformer;
    default:
      return null;
  }
}

String asrTypeName(AsrType type) {
  switch (type) {
    case AsrType.whisper:
      return 'whisper';
    case AsrType.transducer:
      return 'transducer';
    case AsrType.senseVoice:
      return 'sense_voice';
    case AsrType.paraformer:
      return 'paraformer';
  }
}

/// The files of a speech recognition model.
class AsrFiles {
  const AsrFiles({
    required this.type,
    required this.tokens,
    this.encoder,
    this.decoder,
    this.joiner,
    this.model,
  });

  final AsrType type;
  final ModelFile tokens;

  /// Whisper and transducer models.
  final ModelFile? encoder;
  final ModelFile? decoder;

  /// Transducer models only.
  final ModelFile? joiner;

  /// SenseVoice and Paraformer models (one file).
  final ModelFile? model;
}

/// [requested] is the type the caller asked for; null or `auto` means "decide
/// from the files": encoder + decoder + joiner is a transducer, encoder +
/// decoder is Whisper, a single model file is SenseVoice (Paraformer needs to
/// be named, the files look the same).
AsrFiles? detectAsrFiles(List<ModelFile> files, {AsrType? requested}) {
  final tokens = _tokensFile(files);
  if (tokens == null) return null;

  final onnx = files.where((f) => f.name.toLowerCase().endsWith('.onnx'));
  final encoder = _pick(onnx, 'encoder');
  final decoder = _pick(onnx, 'decoder');
  final joiner = _pick(onnx, 'joiner');

  final type = requested ??
      (encoder != null && decoder != null && joiner != null
          ? AsrType.transducer
          : encoder != null && decoder != null
              ? AsrType.whisper
              : AsrType.senseVoice);

  switch (type) {
    case AsrType.whisper:
      if (encoder == null || decoder == null) return null;
      return AsrFiles(
          type: type, tokens: tokens, encoder: encoder, decoder: decoder);
    case AsrType.transducer:
      if (encoder == null || decoder == null || joiner == null) return null;
      return AsrFiles(
        type: type,
        tokens: tokens,
        encoder: encoder,
        decoder: decoder,
        joiner: joiner,
      );
    case AsrType.senseVoice:
    case AsrType.paraformer:
      final model = _singleModel(onnx);
      if (model == null) return null;
      return AsrFiles(type: type, tokens: tokens, model: model);
  }
}

enum TtsType { vits, kokoro }

TtsType? ttsTypeFromName(String? name) {
  switch (name) {
    case 'vits':
      return TtsType.vits;
    case 'kokoro':
      return TtsType.kokoro;
    default:
      return null;
  }
}

String ttsTypeName(TtsType type) => type == TtsType.kokoro ? 'kokoro' : 'vits';

/// The files of a speech synthesis model.
class TtsFiles {
  const TtsFiles({
    required this.type,
    required this.model,
    required this.tokens,
    this.lexicon,
    this.voices,
    this.dataDir,
  });

  final TtsType type;
  final ModelFile model;
  final ModelFile tokens;
  final ModelFile? lexicon;

  /// Kokoro voices (`voices.bin`).
  final ModelFile? voices;

  /// Absolute path of the `espeak-ng-data` folder, when the model has one.
  final String? dataDir;
}

/// A Piper/VITS voice is a model, `tokens.txt` and usually `espeak-ng-data`.
/// A Kokoro model also has `voices.bin`.
TtsFiles? detectTtsFiles(
  List<ModelFile> files,
  List<String> directories,
  String dir, {
  TtsType? requested,
}) {
  final tokens = _tokensFile(files);
  if (tokens == null) return null;
  final onnx = files.where((f) => f.name.toLowerCase().endsWith('.onnx'));
  final model = _singleModel(onnx);
  if (model == null) return null;

  ModelFile? lexicon;
  ModelFile? voices;
  for (final file in files) {
    final lower = file.name.toLowerCase();
    if (lower.startsWith('lexicon') && lower.endsWith('.txt')) lexicon = file;
    if (lower == 'voices.bin' || lower.startsWith('voices')) voices = file;
  }

  String? dataDir;
  for (final name in directories) {
    if (name == 'espeak-ng-data') dataDir = '$dir/$name';
  }

  final type = requested ?? (voices != null ? TtsType.kokoro : TtsType.vits);
  if (type == TtsType.kokoro && voices == null) return null;

  return TtsFiles(
    type: type,
    model: model,
    tokens: tokens,
    lexicon: lexicon,
    voices: voices,
    dataDir: dataDir,
  );
}

/// `tokens.txt`, `tiny-tokens.txt`, `base.en-tokens.txt`...
ModelFile? _tokensFile(List<ModelFile> files) {
  ModelFile? found;
  for (final file in files) {
    final lower = file.name.toLowerCase();
    if (lower == 'tokens.txt') return file;
    if (lower.endsWith('tokens.txt')) found ??= file;
  }
  return found;
}

/// The `.onnx` file whose name has [word]; the quantised (`int8`) one wins
/// because it is smaller and faster.
ModelFile? _pick(Iterable<ModelFile> onnx, String word) {
  ModelFile? plain;
  ModelFile? int8;
  for (final file in onnx) {
    final lower = file.name.toLowerCase();
    if (!lower.contains(word)) continue;
    if (lower.contains('int8')) {
      int8 ??= file;
    } else {
      plain ??= file;
    }
  }
  return int8 ?? plain;
}

/// The one acoustic/recogniser model of a folder: the quantised file when
/// there is one, else the largest. Vocoders are not models of their own.
ModelFile? _singleModel(Iterable<ModelFile> onnx) {
  final candidates =
      onnx.where((f) => !f.name.toLowerCase().contains('vocoder')).toList();
  if (candidates.isEmpty) return null;
  final int8 =
      candidates.where((f) => f.name.toLowerCase().contains('int8')).toList();
  final pool = int8.isNotEmpty ? int8 : candidates;
  pool.sort((a, b) => b.size.compareTo(a.size));
  return pool.first;
}
