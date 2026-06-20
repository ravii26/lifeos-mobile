import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    setState(() => _sending = true);
    await context.read<LifeCubit>().addCapture(t);
    _text.clear();
    if (mounted) setState(() => _sending = false);
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _send,
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
                const SizedBox(height: 18),
                BlocBuilder<LifeCubit, LifeState>(
                  builder: (context, s) {
                    final pending = s.pendingCaptures;
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
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(c.text,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 13.5)),
                                          const SizedBox(height: 5),
                                          GestureDetector(
                                            onTap: () => _reclassify(c),
                                            child: Chip3(
                                                '${c.type} · ${c.confidencePct}% ▾'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _convert(c),
                                      icon: Icon(Icons.check_circle,
                                          color: AppColors.accent, size: 22),
                                      tooltip: 'Convert',
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
