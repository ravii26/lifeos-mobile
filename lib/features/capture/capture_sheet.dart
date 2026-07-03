import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/capture.dart';
import '../../data/models/topic.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';
import '../shell/life_cubit.dart';

/// Quick-capture brain dump — posts to /captures, shows pending inbox with
/// convert/dismiss actions.
class CaptureSheet extends StatefulWidget {
  const CaptureSheet({super.key});

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

  Future<void> _send() async {
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
      backgroundColor: AppColors.surface1,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: AppColors.tx),
              title: Text('Take a photo', style: TextStyle(color: AppColors.tx)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: AppColors.tx),
              title: Text('Choose from gallery', style: TextStyle(color: AppColors.tx)),
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
        'TASK' => 'Tasks',
        'HABIT' => 'Habits',
        'NOTE' => 'a Notebook',
        'RESOURCE' => 'Resources',
        'VAULT' => 'the Vault',
        _ => type,
      };

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.surface4,
      behavior: SnackBarBehavior.floating,
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
      _snack('Added to ${_dest(type)} ✓');
    } else {
      _snack(cubit.state.error ?? 'Could not convert', error: true);
      cubit.clearError();
    }
  }

  Future<String?> _pickArea() {
    final areas = context.read<LifeCubit>().state.areas;
    if (areas.isEmpty) {
      _snack('Create an Area first to file this here', error: true);
      return Future.value(null);
    }
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface1,
      builder: (ctx) => _PickerSheet(
        title: 'File under which area?',
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
      backgroundColor: AppColors.surface1,
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
      backgroundColor: AppColors.surface1,
      builder: (ctx) => _PickerSheet(
        title: 'Reclassify as…',
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
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassBg2,
              border: Border(top: BorderSide(color: AppColors.glassBorder)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.line3,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.bolt, color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Text('Brain dump',
                        style: GoogleFonts.hankenGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tx)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    'Capture anything — LifeOS classifies it for you.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.tx3)),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.inset,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line2),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    controller: _text,
                    autofocus: true,
                    maxLines: 3,
                    minLines: 2,
                    style: TextStyle(fontSize: 15, color: AppColors.tx),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      hintText: "What's on your mind?",
                    ),
                  ),
                ),
                if (_listening) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Listening — speak now, tap mic to stop',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent)),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Image capture
                    _MediaIconButton(
                      icon: Icons.image_outlined,
                      onTap: (_sending || _listening) ? null : _captureImage,
                    ),
                    const SizedBox(width: 8),
                    // Voice → on-device dictation
                    _MediaIconButton(
                      icon: _listening ? Icons.stop_rounded : Icons.mic_none_rounded,
                      active: _listening,
                      onTap: _sending ? null : _toggleDictation,
                    ),
                    const SizedBox(width: 8),
                    // Text capture
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: (_sending || _listening) ? null : _send,
                          icon: _sending
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: AppColors.accentInk))
                              : const Icon(Icons.send_rounded, size: 17),
                          label: const Text('Capture'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.accentInk,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                BlocBuilder<LifeCubit, LifeState>(
                  builder: (context, s) {
                    // Worth-now items float to the top of the inbox.
                    final pending = [...s.pendingCaptures]..sort((a, b) {
                        if (a.isWorthNow != b.isWorthNow) {
                          return a.isWorthNow ? -1 : 1;
                        }
                        return 0;
                      });
                    if (pending.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Inbox zero ✓',
                            style:
                                TextStyle(color: AppColors.tx4, fontSize: 13)),
                      );
                    }
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                          maxHeight:
                              MediaQuery.of(context).size.height * 0.3),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Eyebrow('Inbox · ${pending.length}'),
                          ),
                          for (final c in pending)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: Row(
                                  children: [
                                    if (c.isMedia) ...[
                                      _CaptureThumb(c),
                                      const SizedBox(width: 10),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              c.text.isNotEmpty
                                                  ? c.text
                                                  : (c.mediaType == 'AUDIO'
                                                      ? 'Voice note'
                                                      : 'Image'),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontStyle: c.text.isEmpty
                                                      ? FontStyle.italic
                                                      : FontStyle.normal,
                                                  color: c.text.isEmpty
                                                      ? AppColors.tx3
                                                      : AppColors.tx)),
                                          const SizedBox(height: 5),
                                          if (!c.isClassified)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 11,
                                                  height: 11,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 1.8,
                                                          color:
                                                              AppColors.tx4),
                                                ),
                                                const SizedBox(width: 7),
                                                Text(
                                                    c.isMedia
                                                        ? 'Transcribing…'
                                                        : 'Sorting…',
                                                    style: TextStyle(
                                                        fontSize: 11.5,
                                                        color: AppColors.tx4)),
                                              ],
                                            )
                                          else
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                GestureDetector(
                                                  onTap: () => _reclassify(c),
                                                  child: Chip3(
                                                      '${c.type} · ${c.confidencePct}% ▾'),
                                                ),
                                                if (c.isWorthNow)
                                                  Chip3('Worth now',
                                                      icon: Icons.bolt,
                                                      color: AppColors.accent,
                                                      bg: AppColors.accentSoft),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed:
                                          c.isClassified ? () => _convert(c) : null,
                                      icon: Icon(Icons.check_circle,
                                          color: c.isClassified
                                              ? AppColors.accent
                                              : AppColors.tx4,
                                          size: 22),
                                      tooltip: c.isClassified
                                          ? 'Convert'
                                          : 'Sorting…',
                                    ),
                                    IconButton(
                                      onPressed: () => context
                                          .read<LifeCubit>()
                                          .dismissCapture(c.id),
                                      icon: Icon(Icons.close,
                                          color: AppColors.tx4, size: 20),
                                      tooltip: 'Dismiss',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Square icon button used for the image / voice capture actions.
class _MediaIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  const _MediaIconButton({required this.icon, this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Material(
        color: active ? AppColors.accent : AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Icon(
            icon,
            size: 20,
            color: active
                ? AppColors.accentInk
                : (onTap == null ? AppColors.tx4 : AppColors.tx2),
          ),
        ),
      ),
    );
  }
}

/// Small leading thumbnail for a media capture in the inbox: the stored image,
/// or a mic glyph for a voice note.
class _CaptureThumb extends StatelessWidget {
  final Capture capture;
  const _CaptureThumb(this.capture);

  @override
  Widget build(BuildContext context) {
    if (capture.mediaType == 'IMAGE' && capture.mediaUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          capture.mediaUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _glyph(Icons.image_outlined),
        ),
      );
    }
    return _glyph(Icons.graphic_eq_rounded);
  }

  Widget _glyph(IconData icon) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface3,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppColors.tx3),
      );
}

/// Simple single-select list sheet — returns the picked id via Navigator.pop.
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
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(title,
                style: GoogleFonts.hankenGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tx)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final (id, label) in items)
                  ListTile(
                    title: Text(label,
                        style: TextStyle(color: AppColors.tx, fontSize: 15)),
                    trailing: id == selected
                        ? Icon(Icons.check, color: AppColors.accent, size: 20)
                        : null,
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
