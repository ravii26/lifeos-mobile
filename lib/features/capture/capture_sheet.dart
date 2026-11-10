import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/di/service_locator.dart';
import '../../data/models/capture.dart';
import '../../data/models/topic.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/form_kit.dart' show gFieldStyle;
import '../guide/guide_style.dart';
import '../shell/life_cubit.dart';

/// Quick-capture brain dump — posts to /captures, shows pending inbox with
/// convert/dismiss actions.
///
/// Can be pre-populated from outside its own UI — a shared link/image from
/// the OS share sheet, or a `lifeos://capture?voice=1` deep link from the
/// widget mic button / an assistant shortcut — via `CaptureIntentBus`. See
/// `HomeShell` for where those params get filled in.
class CaptureSheet extends StatefulWidget {
  final String? initialText;
  final String? initialImagePath;
  final String? initialImageMime;
  final bool autoStartVoice;

  const CaptureSheet({
    super.key,
    this.initialText,
    this.initialImagePath,
    this.initialImageMime,
    this.autoStartVoice = false,
  });

  @override
  State<CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends State<CaptureSheet> {
  final _text = TextEditingController();
  final _speech = SpeechToText();
  final _picker = ImagePicker();
  bool _sending = false;
  bool _listening = false;
  // The text already in the field when dictation began; recognised words are
  // appended to it so typing + speaking compose naturally.
  String _dictBase = '';
  // Set when this sheet was opened with an image already supplied (shared in
  // from another app) rather than picked here — shown as an attached
  // thumbnail instead of uploading immediately.
  (String path, String mime)? _pendingImage;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) _text.text = widget.initialText!;
    if (widget.initialImagePath != null) {
      _pendingImage =
          (widget.initialImagePath!, widget.initialImageMime ?? 'image/jpeg');
    }
    if (widget.autoStartVoice) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _toggleDictation());
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _text.dispose();
    super.dispose();
  }

  String? get _caption {
    final t = _text.text.trim();
    return t.isEmpty ? null : t;
  }

  void _removePendingImage() => setState(() => _pendingImage = null);

  Future<void> _send() async {
    final pending = _pendingImage;
    if (pending != null) {
      setState(() => _sending = true);
      await context.read<LifeCubit>().addMediaCapture(
            pending.$1,
            filename: pending.$1.split(RegExp(r'[\\/]')).last,
            mimeType: pending.$2,
            caption: _caption,
          );
      _text.clear();
      if (mounted) {
        setState(() {
          _sending = false;
          _pendingImage = null;
        });
      }
      return;
    }
    final t = _text.text.trim();
    if (t.isEmpty) return;
    setState(() => _sending = true);
    await context.read<LifeCubit>().addCapture(t);
    _text.clear();
    if (mounted) setState(() => _sending = false);
  }

  // ── Voice: on-device dictation (no upload, no API key) ───────────────────
  Future<void> _toggleDictation() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!available) {
      _snack('Speech recognition unavailable on this device', error: true);
      return;
    }
    _dictBase = _text.text.isEmpty ? '' : '${_text.text.trimRight()} ';
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        _text.text = '$_dictBase${r.recognizedWords}';
        _text.selection =
            TextSelection.collapsed(offset: _text.text.length);
      },
      listenFor: const Duration(minutes: 1),
      pauseFor: const Duration(seconds: 4),
      listenOptions: SpeechListenOptions(partialResults: true),
    );
  }

  // ── Image ──────────────────────────────────────────────────────────────
  Future<void> _captureImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: G.bg,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: G.ink),
              title: Text('Take a photo', style: G.text(18, height: 1.3)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: G.ink),
              title: Text('Choose from gallery', style: G.text(18, height: 1.3)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final XFile? img =
        await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 2000);
    if (img == null || !mounted) return;

    setState(() => _sending = true);
    await context.read<LifeCubit>().addMediaCapture(
          img.path,
          filename: img.name,
          mimeType: img.mimeType ?? _mimeFromPath(img.path),
          caption: _caption,
        );
    _text.clear();
    if (mounted) setState(() => _sending = false);
  }

  String _mimeFromPath(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  static const _captureTypes = ['TASK', 'HABIT', 'NOTE', 'RESOURCE', 'VAULT'];

  String _dest(String type) => switch (type) {
        'TASK' => 'To-dos',
        'HABIT' => 'Habits',
        'NOTE' => 'Notes',
        'RESOURCE' => 'Resources',
        'VAULT' => 'the Vault',
        _ => type,
      };

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
    ));
  }

  /// Converts a capture, prompting for the parent area/topic the backend
  /// requires for HABIT (area) and NOTE/RESOURCE (topic) when the AI didn't
  /// already suggest one.
  Future<void> _convert(Capture c) async {
    String? areaId;
    String? topicId;

    if (c.needsArea) {
      areaId = await _pickArea();
      if (areaId == null) return; // cancelled
    }
    if (c.needsTopic) {
      topicId = await _pickTopic();
      if (topicId == null) return; // cancelled
    }
    if (!mounted) return;

    final cubit = context.read<LifeCubit>();
    final type = await cubit.convertCapture(c.id, areaId: areaId, topicId: topicId);
    if (type != null) {
      _snack('Added to ${_dest(type)}');
    } else {
      _snack(cubit.state.error ?? 'Could not convert', error: true);
      cubit.clearError();
    }
  }

  Future<String?> _pickArea() {
    final areas = context.read<LifeCubit>().state.areas;
    if (areas.isEmpty) {
      _snack('Add a part of life first, then file this there.', error: true);
      return Future.value(null);
    }
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: G.bg,
      builder: (ctx) => _PickerSheet(
        title: 'Which part of life?',
        items: [for (final a in areas) (a.id, a.name)],
      ),
    );
  }

  Future<String?> _pickTopic() async {
    List<Topic> topics;
    try {
      topics = await getIt<LifeRepository>().topics();
    } catch (_) {
      _snack('Could not load topics', error: true);
      return null;
    }
    if (!mounted) return null;
    if (topics.isEmpty) {
      _snack('Create a Topic first to file this here', error: true);
      return null;
    }
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: G.bg,
      builder: (ctx) => _PickerSheet(
        title: 'File under which topic?',
        items: [for (final t in topics) (t.id, t.title)],
      ),
    );
  }

  /// Long-press / tap the type chip to fix a wrong AI classification.
  Future<void> _reclassify(Capture c) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: G.bg,
      builder: (ctx) => _PickerSheet(
        title: 'Where should it go?',
        items: [for (final t in _captureTypes) (t, _dest(t))],
        selected: c.type,
      ),
    );
    if (picked != null && picked != c.type && mounted) {
      await context.read<LifeCubit>().reclassifyCapture(c.id, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: G.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: G.surfaceHigh, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Text("What's on your mind?", style: G.text(32, w: FontWeight.w600, height: 1.1, letterSpacing: -0.7)),
            const SizedBox(height: 6),
            Text('Say it or type it. Ally sorts it for you.', style: G.text(17, color: G.muted, height: 1.35)),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              autofocus: true,
              maxLines: 3,
              minLines: 2,
              cursorColor: G.accent,
              style: G.text(18, height: 1.3),
              decoration: gFieldStyle('Anything at all'),
            ),
            if (_pendingImage != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(_pendingImage!.$1),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: G.card,
                        child: Icon(Icons.image_outlined, size: 22, color: G.muted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Image attached', style: G.text(16, color: G.muted, height: 1.3))),
                  IconButton(
                    onPressed: _removePendingImage,
                    icon: Icon(Icons.close_rounded, color: G.ink, size: 24),
                    tooltip: 'Remove image',
                  ),
                ],
              ),
            ],
            if (_listening) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: G.accent, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Listening. Tap the mic to stop.', style: G.text(16, color: G.accent, height: 1.3))),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                _MediaIconButton(
                  icon: Icons.image_outlined,
                  tooltip: 'Add an image',
                  onTap: (_sending || _listening) ? null : _captureImage,
                ),
                const SizedBox(width: 8),
                _MediaIconButton(
                  icon: _listening ? Icons.stop_rounded : Icons.mic_none_rounded,
                  tooltip: _listening ? 'Stop listening' : 'Speak',
                  active: _listening,
                  onTap: _sending ? null : _toggleDictation,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GPill(_sending ? 'Saving…' : 'Keep it', primary: true, onTap: (_sending || _listening) ? null : _send),
                ),
              ],
            ),
            BlocBuilder<LifeCubit, LifeState>(
              builder: (context, s) {
                // Worth-now items float to the top.
                final pending = [...s.pendingCaptures]..sort((a, b) {
                    if (a.isWorthNow != b.isWorthNow) {
                      return a.isWorthNow ? -1 : 1;
                    }
                    return 0;
                  });
                if (pending.isEmpty) return const SizedBox.shrink();
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      const GHeading('Waiting to be sorted'),
                      for (final c in pending) _pendingCard(c),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingCard(Capture c) => GCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          children: [
            if (c.isMedia) ...[
              _CaptureThumb(c),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.text.isNotEmpty ? c.text : (c.mediaType == 'AUDIO' ? 'Voice note' : 'Image'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: G.text(18, color: c.text.isEmpty ? G.muted : G.ink, height: 1.3),
                  ),
                  if (!c.isClassified)
                    Text(c.isMedia ? 'Listening to it…' : 'Sorting…', style: G.text(15, color: G.muted, height: 1.3))
                  else
                    InkWell(
                      onTap: () => _reclassify(c),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 34),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${c.isWorthNow ? 'Worth doing now. ' : ''}Goes to ${_dest(c.type)}. Change',
                            style: G.text(15, color: G.accent, height: 1.3),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: c.isClassified ? () => _convert(c) : null,
              icon: Icon(Icons.check_circle_rounded, color: c.isClassified ? G.accent : G.surfaceHigh, size: 28),
              tooltip: c.isClassified ? 'Add it' : 'Sorting…',
            ),
            IconButton(
              onPressed: () => context.read<LifeCubit>().dismissCapture(c.id),
              icon: Icon(Icons.close_rounded, color: G.ink, size: 24),
              tooltip: 'Remove',
            ),
          ],
        ),
      );
}

/// Round icon button for the image and voice actions.
class _MediaIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  const _MediaIconButton({required this.icon, required this.tooltip, this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      iconSize: 26,
      style: IconButton.styleFrom(
        backgroundColor: active ? G.accent : G.card,
        disabledBackgroundColor: G.card.withValues(alpha: 0.5),
        foregroundColor: active ? G.onInk : G.ink,
        minimumSize: const Size(58, 58),
      ),
      icon: Icon(icon),
    );
  }
}

/// Small leading thumbnail for a media capture: the stored image, or a sound
/// glyph for a voice note.
class _CaptureThumb extends StatelessWidget {
  final Capture capture;
  const _CaptureThumb(this.capture);

  @override
  Widget build(BuildContext context) {
    if (capture.mediaType == 'IMAGE' && capture.mediaUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          capture.mediaUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _glyph(Icons.image_outlined),
        ),
      );
    }
    return _glyph(Icons.graphic_eq_rounded);
  }

  Widget _glyph(IconData icon) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: G.surfaceHigh, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, size: 24, color: G.muted),
      );
}

/// Simple single-select list sheet: returns the picked id via Navigator.pop.
class _PickerSheet extends StatelessWidget {
  final String title;
  final List<(String, String)> items; // (id, label)
  final String? selected;
  const _PickerSheet({
    required this.title,
    required this.items,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
            child: Text(title, style: G.text(26, w: FontWeight.w600, height: 1.15)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final (id, label) in items)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 22),
                    minTileHeight: 56,
                    title: Text(label, style: G.text(19, height: 1.25)),
                    trailing: id == selected ? Icon(Icons.check_rounded, color: G.accent, size: 24) : null,
                    onTap: () => Navigator.of(context).pop(id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
