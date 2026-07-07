import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/area.dart';
import '../../data/models/note.dart';
import '../../data/models/notebook.dart';
import '../../data/models/topic.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';
import '../../widgets/form_kit.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import '../shell/life_cubit.dart';
import 'knowledge_cubit.dart';
import 'note_form.dart';

class KnowledgeScreen extends StatelessWidget {
  const KnowledgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final areas = context.read<LifeCubit>().state.areas;
    return BlocProvider(
      create: (_) => KnowledgeCubit(getIt<LifeRepository>())..load(),
      child: _KnowledgeView(areas: areas),
    );
  }
}

class _KnowledgeView extends StatelessWidget {
  final List<Area> areas;
  const _KnowledgeView({required this.areas});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: BlocBuilder<KnowledgeCubit, KnowledgeState>(
        builder: (context, s) => FloatingActionButton.extended(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentInk,
          onPressed: () => _addMenu(context, s),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Add'),
        ),
      ),
      body: BlocConsumer<KnowledgeCubit, KnowledgeState>(
        listenWhen: (a, b) => b.error != null && a.error != b.error,
        listener: (context, s) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              backgroundColor: AppColors.danger, content: Text(s.error!))),
        builder: (context, s) {
          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.surface2,
            onRefresh: () => context.read<KnowledgeCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                const BackHeader(eyebrow: 'Knowledge', title: 'Notebooks'),
                if (s.status == LoadStatus.loading && s.topics.isEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accent)))
                else if (s.topics.isEmpty)
                  _emptyTopics(context)
                else ...[
                  _topicFilter(context, s),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (s.visibleNotebooks.isEmpty && s.looseNotes.isEmpty)
                          _emptyContent()
                        else ...[
                          if (s.visibleNotebooks.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            SectionHeader('Notebooks'),
                            const SizedBox(height: 10),
                            for (final nb in s.visibleNotebooks)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 11),
                                child: _NotebookCard(
                                  notebook: nb,
                                  topicTitle:
                                      s.topicById(nb.topicId)?.title ?? '',
                                  count: s.noteCount(nb.id),
                                  onTap: () => _openNotebook(context, nb),
                                ),
                              ),
                          ],
                          if (s.looseNotes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            SectionHeader('Loose notes'),
                            const SizedBox(height: 10),
                            for (final n in s.looseNotes)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: NoteTile(
                                  note: n,
                                  onTap: () => _editNote(context, n),
                                ),
                              ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // --- topic filter row ---
  Widget _topicFilter(BuildContext context, KnowledgeState s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip(context, 'All', s.selectedTopicId == null,
                  () => context.read<KnowledgeCubit>().selectTopic(null)),
              for (final t in s.topics)
                _filterChip(context, t.title, s.selectedTopicId == t.id,
                    () => context.read<KnowledgeCubit>().selectTopic(t.id),
                    onLongPress: () => _editTopic(context, t)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 6),
          child: Text('Long-press a topic to edit',
              style: TextStyle(fontSize: 11, color: AppColors.tx4)),
        ),
      ],
    );
  }

  Widget _filterChip(
      BuildContext context, String label, bool selected, VoidCallback onTap,
      {VoidCallback? onLongPress}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.16)
                : AppColors.surface2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppColors.accent : AppColors.line),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.accent : AppColors.tx2)),
        ),
      ),
    );
  }

  Widget _emptyContent() => Padding(
        padding: const EdgeInsets.only(top: 30),
        child: SurfaceCard(
          padding: const EdgeInsets.all(26),
          child: Center(
              child: Text('Nothing here yet. Tap “Add”.',
                  style: TextStyle(color: AppColors.tx4, fontSize: 13))),
        ),
      );

  Widget _emptyTopics(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
        child: SurfaceCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text('Notebooks & notes live under topics.',
                  style: TextStyle(color: AppColors.tx3, fontSize: 13)),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _newTopic(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create your first topic'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentInk),
              ),
            ],
          ),
        ),
      );

  // --- actions ---
  void _addMenu(BuildContext context, KnowledgeState s) {
    final cubit = context.read<KnowledgeCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _menuRow(context, Icons.note_add_outlined, 'New note',
                enabled: s.topics.isNotEmpty, onTap: () {
              Navigator.of(context).pop();
              _newNote(context, cubit);
            }),
            _menuRow(context, Icons.menu_book_outlined, 'New notebook',
                enabled: s.topics.isNotEmpty, onTap: () {
              Navigator.of(context).pop();
              _newNotebook(context, cubit);
            }),
            _menuRow(context, Icons.topic_outlined, 'New topic', onTap: () {
              Navigator.of(context).pop();
              _newTopic(context);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(BuildContext context, IconData icon, String label,
          {bool enabled = true, required VoidCallback onTap}) =>
      ListTile(
        leading: Icon(icon,
            color: enabled ? AppColors.tx : AppColors.tx4, size: 21),
        title: Text(label,
            style: TextStyle(
                color: enabled ? AppColors.tx : AppColors.tx4,
                fontWeight: FontWeight.w600)),
        subtitle: enabled
            ? null
            : Text('Create a topic first',
                style: TextStyle(color: AppColors.tx4, fontSize: 11)),
        onTap: enabled ? onTap : null,
      );

  void _openNotebook(BuildContext context, Notebook nb) {
    final cubit = context.read<KnowledgeCubit>();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: NotebookDetailScreen(notebookId: nb.id),
      ),
    ));
  }

  void _newNote(BuildContext context, KnowledgeCubit cubit) {
    _sheet(context, cubit, NoteForm(topics: cubit.state.topics));
  }

  void _editNote(BuildContext context, Note n) {
    final cubit = context.read<KnowledgeCubit>();
    _sheet(context, cubit, NoteForm(topics: cubit.state.topics, note: n));
  }

  void _newNotebook(BuildContext context, KnowledgeCubit cubit) {
    _sheet(context, cubit, NotebookForm(topics: cubit.state.topics));
  }

  void _newTopic(BuildContext context) {
    final cubit = context.read<KnowledgeCubit>();
    _sheet(context, cubit, TopicForm(areas: areas));
  }

  void _editTopic(BuildContext context, Topic t) {
    final cubit = context.read<KnowledgeCubit>();
    _sheet(context, cubit, TopicForm(areas: areas, topic: t));
  }

  void _sheet(BuildContext context, KnowledgeCubit cubit, Widget child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(value: cubit, child: child),
    );
  }
}

// ----------------------------------------------------------------- cards
class _NotebookCard extends StatelessWidget {
  final Notebook notebook;
  final String topicTitle;
  final int count;
  final VoidCallback onTap;
  const _NotebookCard({
    required this.notebook,
    required this.topicTitle,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.menu_book_outlined,
                  size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notebook.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      '$topicTitle · $count note${count == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: AppColors.tx3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.tx4),
          ],
        ),
      ),
    );
  }
}

/// Reused on the main screen (loose notes) and inside a notebook.
class NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  const NoteTile({super.key, required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                  child: Text(note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Chip3(titleCaseWord(note.noteType)),
              ],
            ),
            const SizedBox(height: 6),
            Text(note.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.tx3, height: 1.4)),
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in note.tags) Chip3('#$t'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- detail
class NotebookDetailScreen extends StatelessWidget {
  final String notebookId;
  const NotebookDetailScreen({super.key, required this.notebookId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: BlocBuilder<KnowledgeCubit, KnowledgeState>(
        builder: (context, s) {
          final nb = _find(s.notebooks, notebookId);
          if (nb == null) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.accentInk,
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => BlocProvider.value(
                value: context.read<KnowledgeCubit>(),
                child: NoteForm(
                  topics: s.topics,
                  fixedTopicId: nb.topicId,
                  fixedNotebookId: nb.id,
                ),
              ),
            ),
            icon: const Icon(Icons.note_add_outlined, size: 19),
            label: const Text('Add note'),
          );
        },
      ),
      body: BlocBuilder<KnowledgeCubit, KnowledgeState>(
        builder: (context, s) {
          final nb = _find(s.notebooks, notebookId);
          if (nb == null) {
            return const Center(child: Text('Notebook removed'));
          }
          final notes = s.notesIn(nb.id);
          return ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              BackHeader(
                  eyebrow: s.topicById(nb.topicId)?.title ?? 'Notebook',
                  title: nb.title),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              nb.description?.isNotEmpty == true
                                  ? nb.description!
                                  : '${notes.length} note${notes.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.tx3)),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              size: 19, color: AppColors.tx3),
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => BlocProvider.value(
                              value: context.read<KnowledgeCubit>(),
                              child:
                                  NotebookForm(topics: s.topics, notebook: nb),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (notes.isEmpty)
                      SurfaceCard(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                            child: Text('No notes yet. Tap “Add note”.',
                                style: TextStyle(
                                    color: AppColors.tx4, fontSize: 13))),
                      )
                    else
                      for (final n in notes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: NoteTile(
                            note: n,
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => BlocProvider.value(
                                value: context.read<KnowledgeCubit>(),
                                child: NoteForm(topics: s.topics, note: n),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Notebook? _find(List<Notebook> list, String id) {
    for (final n in list) {
      if (n.id == id) return n;
    }
    return null;
  }
}

// ----------------------------------------------------------------- forms
class NotebookForm extends StatefulWidget {
  final List<Topic> topics;
  final Notebook? notebook;
  const NotebookForm({super.key, required this.topics, this.notebook});

  @override
  State<NotebookForm> createState() => _NotebookFormState();
}

class _NotebookFormState extends State<NotebookForm> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _tags;
  String? _topicId;
  bool _saving = false;

  bool get _isEdit => widget.notebook != null;

  @override
  void initState() {
    super.initState();
    final nb = widget.notebook;
    _title = TextEditingController(text: nb?.title ?? '');
    _desc = TextEditingController(text: nb?.description ?? '');
    _tags = TextEditingController(text: (nb?.tags ?? const []).join(', '));
    _topicId = nb?.topicId ??
        (widget.topics.isNotEmpty ? widget.topics.first.id : null);
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
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
    if (title.isEmpty || _topicId == null) return;
    setState(() => _saving = true);
    final cubit = context.read<KnowledgeCubit>();
    if (_isEdit) {
      await cubit.updateNotebook(widget.notebook!.id,
          title: title, description: _desc.text.trim(), tags: _tagList);
    } else {
      await cubit.createNotebook(
          title: title,
          topicId: _topicId!,
          description: _desc.text.trim(),
          tags: _tagList);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: _isEdit ? 'Edit notebook' : 'New notebook',
      children: [
        formField(_title, 'Notebook title', autofocus: !_isEdit),
        const SizedBox(height: 10),
        formField(_desc, 'Description (optional)', lines: 2),
        const SizedBox(height: 16),
        if (!_isEdit) ...[
          formLabel('Topic'),
          chipWrap([
            for (final t in widget.topics)
              selChip(t.title, _topicId == t.id,
                  () => setState(() => _topicId = t.id)),
          ]),
          const SizedBox(height: 14),
        ],
        formLabel('Tags (comma-separated)'),
        formField(_tags, 'e.g. reference, deep-dive'),
        const SizedBox(height: 20),
        saveButton(
            _saving, _save, _isEdit ? 'Save changes' : 'Create notebook'),
        if (_isEdit) ...[
          const SizedBox(height: 6),
          deleteRow(context, 'Delete notebook', _confirmDelete),
        ],
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final nb = widget.notebook!;
    if (await confirmDelete(
        context, 'Notes inside “${nb.title}” are kept but unfiled.')) {
      if (!mounted) return;
      context.read<KnowledgeCubit>().deleteNotebook(nb.id);
      Navigator.of(context).pop();
      Navigator.of(context).maybePop();
    }
  }
}

class TopicForm extends StatefulWidget {
  final List<Area> areas;
  final Topic? topic;
  const TopicForm({super.key, required this.areas, this.topic});

  @override
  State<TopicForm> createState() => _TopicFormState();
}

class _TopicFormState extends State<TopicForm> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  String? _areaId;
  bool _saving = false;

  bool get _isEdit => widget.topic != null;

  @override
  void initState() {
    super.initState();
    final t = widget.topic;
    _title = TextEditingController(text: t?.title ?? '');
    _desc = TextEditingController(text: t?.description ?? '');
    _areaId = t?.areaId ??
        (widget.areas.isNotEmpty ? widget.areas.first.id : null);
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _areaId == null) return;
    setState(() => _saving = true);
    final cubit = context.read<KnowledgeCubit>();
    if (_isEdit) {
      await cubit.updateTopic(widget.topic!.id,
          title: title, description: _desc.text.trim(), areaId: _areaId!);
    } else {
      await cubit.createTopic(
          title: title, areaId: _areaId!, description: _desc.text.trim());
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final t = widget.topic!;
    if (await confirmDelete(context,
        'Notebooks and notes under “${t.title}” may be affected.')) {
      if (!mounted) return;
      context.read<KnowledgeCubit>().deleteTopic(t.id);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: _isEdit ? 'Edit topic' : 'New topic',
      children: [
        formField(_title, 'Topic title', autofocus: !_isEdit),
        const SizedBox(height: 10),
        formField(_desc, 'Description (optional)', lines: 2),
        const SizedBox(height: 16),
        formLabel('Area'),
        chipWrap([
          for (final a in widget.areas)
            selChip(a.name, _areaId == a.id,
                () => setState(() => _areaId = a.id),
                color: a.color),
        ]),
        const SizedBox(height: 20),
        saveButton(_saving, _save, _isEdit ? 'Save changes' : 'Create topic'),
        if (_isEdit) ...[
          const SizedBox(height: 6),
          deleteRow(context, 'Delete topic', _confirmDelete),
        ],
      ],
    );
  }
}

