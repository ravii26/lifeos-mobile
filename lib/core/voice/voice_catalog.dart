/// The offline voices Ally can download. Each is a sherpa-onnx package (a model plus the
/// pronunciation data it needs), fetched once over Wi-Fi and then used with no internet.
enum VoiceKind { piper, kokoro }

class VoiceOption {
  final String id;
  final String label;
  final String blurb;
  final VoiceKind kind;
  final String pkg; // the archive and folder name
  final String model; // the model file inside the folder
  final int mb; // approximate download size
  final int speaker;
  const VoiceOption({
    required this.id,
    required this.label,
    required this.blurb,
    required this.kind,
    required this.pkg,
    required this.model,
    required this.mb,
    this.speaker = 0,
  });

  String get url => 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/$pkg.tar.bz2';

  /// Files that must exist for the voice to count as installed.
  List<String> get requiredFiles => [model, 'tokens.txt', if (kind == VoiceKind.kokoro) 'voices.bin'];
}

const voiceOptions = <VoiceOption>[
  VoiceOption(
    id: 'lessac',
    label: 'Lessac',
    blurb: 'American English, female. Clear and steady.',
    kind: VoiceKind.piper,
    pkg: 'vits-piper-en_US-lessac-medium',
    model: 'en_US-lessac-medium.onnx',
    mb: 67,
  ),
  VoiceOption(
    id: 'ryan',
    label: 'Ryan',
    blurb: 'American English, male. Warm.',
    kind: VoiceKind.piper,
    pkg: 'vits-piper-en_US-ryan-medium',
    model: 'en_US-ryan-medium.onnx',
    mb: 67,
  ),
  VoiceOption(
    id: 'jenny',
    label: 'Jenny',
    blurb: 'British English, female. Friendly.',
    kind: VoiceKind.piper,
    pkg: 'vits-piper-en_GB-jenny_dioco-medium',
    model: 'en_GB-jenny_dioco-medium.onnx',
    mb: 67,
  ),
  VoiceOption(
    id: 'alan',
    label: 'Alan',
    blurb: 'British English, male. Calm.',
    kind: VoiceKind.piper,
    pkg: 'vits-piper-en_GB-alan-medium',
    model: 'en_GB-alan-medium.onnx',
    mb: 67,
  ),
];

VoiceOption? voiceById(String? id) {
  for (final v in voiceOptions) {
    if (v.id == id) return v;
  }
  return null;
}
