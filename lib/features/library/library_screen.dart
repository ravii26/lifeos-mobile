import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/document.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';
import '../../widgets/screen_header.dart';
import '../shell/life_cubit.dart';
import 'library_cubit.dart';

/// Library — paste a big guide once, then ask questions of it and let the AI
/// mine it for Habits/Goals/Tasks you confirm into your system.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LibraryCubit(getIt<LifeRepository>())..load(),
      child: const _LibraryView(),
    );
  }
}

class _LibraryView extends StatefulWidget {
  const _LibraryView();

  @override
  State<_LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<_LibraryView> {
  final _question = TextEditingController();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _question.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.surface4,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _ask() async {
    final q = _question.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    await context.read<LibraryCubit>().ask(q);
  }

  Future<void> _add() async {
    final text = _body.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _adding = true);
    final err = await context.read<LibraryCubit>().addDocument(
          title: _title.text.trim().isEmpty ? null : _title.text.trim(),
          text: text,
        );
    if (!mounted) return;
    setState(() => _adding = false);
    if (err != null) {
      _snack(err, error: true);
    } else {
      _title.clear();
      _body.clear();
      _snack('Added — indexing in the background…');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: BlocBuilder<LibraryCubit, LibraryState>(
        builder: (context, s) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              BackHeader(
                  eyebrow: 'Knowledge · ask',
                  title: 'Library',
                  color: AppColors.accent),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _askCard(context, s),
                    const SizedBox(height: 14),
                    _addCard(context, s),
                    const SizedBox(height: 20),
                    SectionHeader('Documents'),
                    const SizedBox(height: 10),
                    if (s.status == LoadStatus.loading && s.documents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.accent)),
                      )
                    else if (s.status == LoadStatus.error && s.documents.isEmpty)
                      _emptyNote(s.error ?? 'Could not load documents.')
                    else if (s.documents.isEmpty)
                      _emptyNote(
                          'No documents yet — paste a guide above to start asking.')
                    else
                      for (final d in s.documents) _documentCard(context, s, d),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Ask ────────────────────────────────────────────────────────────────────

  Widget _askCard(BuildContext context, LibraryState s) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('Ask your library'),
          const SizedBox(height: 10),
          _inputBox(
            child: TextField(
              controller: _question,
              minLines: 1,
              maxLines: 3,
              style: TextStyle(fontSize: 14.5, color: AppColors.tx),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: 'e.g. how much protein should I eat daily?',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: s.asking ? null : _ask,
              icon: s.asking
                  ? SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accentInk))
                  : const Icon(Icons.search, size: 17),
              label: Text(s.asking ? 'Thinking…' : 'Ask'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.accentInk,
              ),
            ),
          ),
          if (s.askError != null) ...[
            const SizedBox(height: 8),
            Text(s.askError!,
                style: TextStyle(fontSize: 12.5, color: AppColors.danger)),
          ],
          if (s.answer != null) ...[
            const SizedBox(height: 12),
            Divider(color: AppColors.line, height: 1),
            const SizedBox(height: 12),
            Text(s.answer!.answer,
                style: TextStyle(
                    fontSize: 13.5, height: 1.5, color: AppColors.tx)),
            if (!s.answer!.usedAi && s.answer!.sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('AI unavailable — showing the closest passage.',
                  style: TextStyle(fontSize: 11, color: AppColors.tx4)),
            ],
            if (s.answer!.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              Eyebrow('Sources'),
              const SizedBox(height: 6),
              for (final src in s.answer!.sources) _sourceRow(src),
            ],
          ],
        ],
      ),
    );
  }

  Widget _sourceRow(AskSource src) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.inset,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(_sourceTypeLabel(src.sourceType),
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.4,
                          color: AppColors.tx4)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(src.heading ?? src.sourceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Text(src.score.toStringAsFixed(2),
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 10, color: AppColors.tx4)),
              ],
            ),
            const SizedBox(height: 4),
            Text(src.snippet,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, height: 1.4, color: AppColors.tx3)),
          ],
        ),
      );

  String _sourceTypeLabel(String sourceType) {
    switch (sourceType) {
      case 'NOTE':
        return 'NOTE';
      case 'RESOURCE':
        return 'RESOURCE';
      default:
        return 'DOCUMENT';
    }
  }

  // ── Add document ────────────────────────────────────────────────────────────

  Widget _addCard(BuildContext context, LibraryState s) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('Add a document'),
          const SizedBox(height: 10),
          _inputBox(
            child: TextField(
              controller: _title,
              style: TextStyle(fontSize: 14, color: AppColors.tx),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: 'Title (optional)',
              ),
            ),
          ),
          const SizedBox(height: 8),
          _inputBox(
            child: TextField(
              controller: _body,
              minLines: 4,
              maxLines: 8,
              style: TextStyle(fontSize: 14, color: AppColors.tx),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: 'Paste a guide, notes, a handbook…',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _adding ? null : _add,
              icon: _adding
                  ? SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accentInk))
                  : const Icon(Icons.add, size: 18),
              label: Text(_adding ? 'Adding…' : 'Add document'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.accentInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Document card ───────────────────────────────────────────────────────────

  Widget _documentCard(BuildContext context, LibraryState s, LibraryDocument d) {
    final expanded = s.expanded.contains(d.id);
    final extracting = s.extracting.contains(d.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    _statusLine(d),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _confirmDelete(context, d),
                icon: Icon(Icons.delete_outline,
                    size: 19, color: AppColors.tx4),
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (d.isReady) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: extracting
                      ? null
                      : () => context.read<LibraryCubit>().extract(d.id),
                  icon: extracting
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent))
                      : Icon(Icons.auto_awesome_outlined,
                          size: 15, color: AppColors.accent),
                  label: Text(extracting ? 'Extracting…' : 'Extract actions',
                      style: TextStyle(fontSize: 12.5, color: AppColors.tx)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.line2),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () =>
                      context.read<LibraryCubit>().toggleExpand(d.id),
                  icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.tx3),
                  tooltip: expanded ? 'Hide actions' : 'Show actions',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
          if (expanded && d.isReady) _suggestionsPanel(context, s, d.id),
        ],
      ),
    );
  }

  Widget _statusLine(LibraryDocument d) {
    if (d.isPending) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
                strokeWidth: 1.8, color: AppColors.tx4)),
        const SizedBox(width: 7),
        Text('Indexing…',
            style: TextStyle(fontSize: 12, color: AppColors.tx4)),
      ]);
    }
    if (d.isFailed) {
      return Text(d.error ?? 'Indexing failed',
          style: TextStyle(fontSize: 12, color: AppColors.danger));
    }
    return Text('${d.chunkCount} sections indexed',
        style: TextStyle(fontSize: 12, color: AppColors.tx4));
  }

  // ── Suggestions ─────────────────────────────────────────────────────────────

  Widget _suggestionsPanel(BuildContext context, LibraryState s, String docId) {
    final list = s.suggestions[docId];
    if (list == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text('Loading actions…',
            style: TextStyle(fontSize: 12, color: AppColors.tx4)),
      );
    }
    final pending = list.where((x) => x.isPending).toList();
    final accepted = list.where((x) => x.isAccepted).toList();
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text('No actions extracted yet — tap “Extract actions”.',
            style: TextStyle(fontSize: 12, color: AppColors.tx4)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.line, height: 1),
          const SizedBox(height: 10),
          for (final sug in pending) _suggestionRow(context, s, sug),
          if (pending.isEmpty)
            Text('All suggestions handled.',
                style: TextStyle(fontSize: 12, color: AppColors.tx4)),
          if (accepted.isNotEmpty) ...[
            const SizedBox(height: 6),
            Eyebrow('Added (${accepted.length})'),
            const SizedBox(height: 4),
            for (final a in accepted)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Icon(Icons.check, size: 13, color: AppColors.ok),
                  const SizedBox(width: 6),
                  Text('${_typeLabel(a.itemType)} · ',
                      style: TextStyle(fontSize: 12, color: AppColors.tx4)),
                  Expanded(
                    child: Text(a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.tx3)),
                  ),
                ]),
              ),
          ],
        ],
      ),
    );
  }

  Widget _suggestionRow(
      BuildContext context, LibraryState s, DocumentSuggestion sug) {
    final busy = s.busySuggestions.contains(sug.id);
    final color = _typeColor(sug.itemType);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inset,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip3(_typeLabel(sug.itemType),
                  color: color, bg: color.withValues(alpha: 0.12)),
              if (sug.frequency != null)
                Chip3(sug.frequency!.toLowerCase()),
              if (sug.suggestedAreaName != null)
                Chip3('→ ${sug.suggestedAreaName}'),
              Text('${sug.confidencePct}%',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: AppColors.tx4)),
            ],
          ),
          const SizedBox(height: 6),
          Text(sug.title,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          if (sug.detail != null) ...[
            const SizedBox(height: 3),
            Text(sug.detail!,
                style: TextStyle(
                    fontSize: 12, height: 1.4, color: AppColors.tx3)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.icon(
                onPressed: busy ? null : () => _accept(context, sug),
                icon: busy
                    ? SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accentInk))
                    : const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentInk,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed:
                    busy ? null : () => context.read<LibraryCubit>().dismiss(sug),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.tx4,
                    visualDensity: VisualDensity.compact),
                child: const Text('Dismiss', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _accept(BuildContext context, DocumentSuggestion sug) async {
    final cubit = context.read<LibraryCubit>();
    String? areaId = sug.suggestedAreaId;
    if (sug.needsArea) {
      // Confirm/choose the area (habits & goals require one).
      areaId = await _pickArea(context, preselect: areaId);
      if (areaId == null) return; // cancelled
    }
    final err = await cubit.accept(sug, areaId: areaId);
    if (err != null) {
      _snack(err, error: true);
    } else {
      _snack('Added ${_typeLabel(sug.itemType).toLowerCase()}: ${sug.title}');
    }
  }

  Future<String?> _pickArea(BuildContext context, {String? preselect}) {
    final areas = context.read<LifeCubit>().state.areas;
    if (areas.isEmpty) {
      _snack('Create an Area first to add habits or goals', error: true);
      return Future.value(null);
    }
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface1,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text('Add to which area?',
                  style: GoogleFonts.hankenGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tx)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final a in areas)
                    ListTile(
                      title: Text(a.name,
                          style:
                              TextStyle(color: AppColors.tx, fontSize: 15)),
                      trailing: a.id == preselect
                          ? Icon(Icons.check, color: AppColors.accent, size: 20)
                          : null,
                      onTap: () => Navigator.of(ctx).pop(a.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, LibraryDocument d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('Delete this document?'),
        content: Text(
            '“${d.title}” and everything indexed from it will be removed.',
            style: TextStyle(color: AppColors.tx2)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<LibraryCubit>().deleteDocument(d.id);
    }
  }

  // ── Bits ────────────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      );

  Widget _inputBox({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.inset,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line2),
        ),
        child: child,
      );

  Widget _emptyNote(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 13, color: AppColors.tx3)),
      );

  Color _typeColor(String t) => switch (t) {
        'HABIT' => AppColors.health,
        'GOAL' => AppColors.career,
        _ => AppColors.warn,
      };

  String _typeLabel(String t) => switch (t) {
        'HABIT' => 'Habit',
        'GOAL' => 'Goal',
        'TASK' => 'Task',
        _ => t,
      };
}
