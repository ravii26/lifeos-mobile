import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/note.dart';
import '../../data/models/topic.dart';
import '../../widgets/form_kit.dart' show titleCaseWord;
import 'knowledge_cubit.dart';

const kNoteTypes = ['CONCEPT', 'INSIGHT', 'SUMMARY', 'QUOTE', 'OTHER'];

/// Bottom-sheet form to create or edit a Note. When opened from inside a
/// notebook, [fixedNotebookId] and [fixedTopicId] are supplied so the note
/// is filed there automatically.
class NoteForm extends StatefulWidget {
  final List<Topic> topics;
  final Note? note;
  final String? fixedTopicId;
  final String? fixedNotebookId;
  const NoteForm({
    super.key,
    required this.topics,
    this.note,
    this.fixedTopicId,
    this.fixedNotebookId,
  });

  @override
  State<NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<NoteForm> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _tags;
  String? _topicId;
  String _noteType = 'CONCEPT';
  bool _saving = false;

  bool get _isEdit => widget.note != null;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _title = TextEditingController(text: n?.title ?? '');
    _content = TextEditingController(text: n?.content ?? '');
    _tags = TextEditingController(text: (n?.tags ?? const []).join(', '));
    _topicId = n?.topicId ??
        widget.fixedTopicId ??
        (widget.topics.isNotEmpty ? widget.topics.first.id : null);
    _noteType = n?.noteType ?? 'CONCEPT';
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _tags.dispose();
    super.dispose();
  }

  List<String> get _tagList => _tags.text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty || content.isEmpty || _topicId == null) return;
    setState(() => _saving = true);
    final cubit = context.read<KnowledgeCubit>();
    if (_isEdit) {
      await cubit.updateNote(widget.note!.id,
          title: title,
          content: content,
          noteType: _noteType,
          tags: _tagList);
    } else {
      await cubit.createNote(
          title: title,
          content: content,
          topicId: _topicId!,
          notebookId: widget.fixedNotebookId,
          noteType: _noteType,
          tags: _tagList);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final showTopicPicker = widget.fixedTopicId == null && !_isEdit;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: SingleChildScrollView(
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
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              Text(_isEdit ? 'Edit note' : 'New note',
                  style: GoogleFonts.hankenGrotesk(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _field(_title, 'Note title', autofocus: !_isEdit),
              const SizedBox(height: 10),
              _field(_content, 'Write your note…', lines: 6),
              const SizedBox(height: 16),
              if (showTopicPicker) ...[
                _label('Topic'),
                _chipWrap([
                  for (final t in widget.topics)
                    _selChip(t.title, _topicId == t.id,
                        () => setState(() => _topicId = t.id)),
                ]),
                const SizedBox(height: 14),
              ],
              _label('Type'),
              _chipWrap([
                for (final nt in kNoteTypes)
                  _selChip(titleCaseWord(nt), _noteType == nt,
                      () => setState(() => _noteType = nt)),
              ]),
              const SizedBox(height: 14),
              _label('Tags (comma-separated)'),
              _field(_tags, 'e.g. flutter, state, bloc'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentInk,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEdit ? 'Save changes' : 'Create note'),
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _confirmDelete(),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppColors.danger),
                    label: const Text('Delete note',
                        style: TextStyle(color: AppColors.danger)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    final n = widget.note!;
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('Delete note?', style: TextStyle(fontSize: 16)),
        content: Text('“${n.title}” will be removed.',
            style: TextStyle(fontSize: 13, color: AppColors.tx3)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<KnowledgeCubit>().deleteNote(n.id);
              Navigator.of(dctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(t,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.tx3)),
      );

  Widget _field(TextEditingController c, String hint,
          {int lines = 1, bool autofocus = false}) =>
      TextField(
        controller: c,
        autofocus: autofocus,
        maxLines: lines,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.tx4),
          filled: true,
          fillColor: AppColors.surface2,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.accentLine),
          ),
        ),
      );

  Widget _chipWrap(List<Widget> chips) =>
      Wrap(spacing: 8, runSpacing: 8, children: chips);

  Widget _selChip(String label, bool selected, VoidCallback onTap) {
    final c = AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.16) : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? c : AppColors.line, width: selected ? 1.3 : 1),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? c : AppColors.tx2)),
      ),
    );
  }
}
