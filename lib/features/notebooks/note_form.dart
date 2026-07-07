import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/note.dart';
import '../../data/models/topic.dart';
import '../../widgets/form_kit.dart';
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
    return FormSheet(
      title: _isEdit ? 'Edit note' : 'New note',
      children: [
        formField(_title, 'Note title', autofocus: !_isEdit),
        const SizedBox(height: 10),
        formField(_content, 'Write your note…', lines: 6),
        const SizedBox(height: 16),
        if (showTopicPicker) ...[
          formLabel('Topic'),
          chipWrap([
            for (final t in widget.topics)
              selChip(t.title, _topicId == t.id,
                  () => setState(() => _topicId = t.id)),
          ]),
          const SizedBox(height: 14),
        ],
        formLabel('Type'),
        chipWrap([
          for (final nt in kNoteTypes)
            selChip(titleCaseWord(nt), _noteType == nt,
                () => setState(() => _noteType = nt)),
        ]),
        const SizedBox(height: 14),
        formLabel('Tags (comma-separated)'),
        formField(_tags, 'e.g. flutter, state, bloc'),
        const SizedBox(height: 20),
        saveButton(_saving, _save, _isEdit ? 'Save changes' : 'Create note'),
        if (_isEdit) ...[
          const SizedBox(height: 6),
          deleteRow(context, 'Delete note', () => _confirmDelete()),
        ],
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final n = widget.note!;
    if (await confirmDelete(context, '“${n.title}” will be removed.')) {
      if (!mounted) return;
      context.read<KnowledgeCubit>().deleteNote(n.id);
      Navigator.of(context).pop();
    }
  }
}
