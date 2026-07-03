import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/resource.dart';
import '../../data/models/topic.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/form_kit.dart';

/// Backend ResourceType / ResourceStatus enums.
const kResourceTypes = [
  'BOOK', 'COURSE', 'VIDEO', 'ARTICLE', 'PODCAST', 'DOCUMENTATION', 'OTHER',
];
const kResourceStatuses = ['NOT_STARTED', 'IN_PROGRESS', 'COMPLETED'];

class ResourceForm extends StatefulWidget {
  final Resource? item;
  const ResourceForm({super.key, this.item});

  @override
  State<ResourceForm> createState() => _ResourceFormState();
}

class _ResourceFormState extends State<ResourceForm> {
  late final TextEditingController _title;
  late final TextEditingController _platform;
  late final TextEditingController _url;
  late final TextEditingController _notes;
  String _type = 'COURSE';
  String _status = 'NOT_STARTED';
  String? _topicId;
  bool _saving = false;
  late final Future<List<Topic>> _topicsFuture;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final r = widget.item;
    _title = TextEditingController(text: r?.title ?? '');
    _platform = TextEditingController(text: r?.platform ?? '');
    _url = TextEditingController(text: r?.url ?? '');
    _notes = TextEditingController(text: r?.notes ?? '');
    if (r != null && kResourceTypes.contains(r.resourceType.toUpperCase())) {
      _type = r.resourceType.toUpperCase();
    }
    if (r != null && kResourceStatuses.contains(r.status.toUpperCase())) {
      _status = r.status.toUpperCase();
    }
    _topicId = r?.topicId;
    _topicsFuture = getIt<LifeRepository>().topics();
  }

  @override
  void dispose() {
    _title.dispose();
    _platform.dispose();
    _url.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || (_topicId == null && !_isEdit)) return;
    setState(() => _saving = true);
    final repo = getIt<LifeRepository>();
    try {
      if (_isEdit) {
        await repo.updateResource(widget.item!.id,
            title: title,
            resourceType: _type,
            platform: _platform.text.trim(),
            url: _url.text.trim(),
            notes: _notes.text.trim(),
            status: _status);
      } else {
        await repo.createResource(
            title: title,
            topicId: _topicId!,
            resourceType: _type,
            platform: _platform.text.trim(),
            url: _url.text.trim(),
            notes: _notes.text.trim(),
            status: _status);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: _isEdit ? 'Edit resource' : 'New resource',
      children: [
        formField(_title, 'Title', autofocus: !_isEdit),
        const SizedBox(height: 14),
        formLabel('Type'),
        chipWrap([
          for (final t in kResourceTypes)
            selChip(titleCaseWord(t), _type == t, () => setState(() => _type = t)),
        ]),
        const SizedBox(height: 14),
        formLabel('Status'),
        chipWrap([
          for (final s in kResourceStatuses)
            selChip(titleCaseWord(s.replaceAll('_', ' ')), _status == s,
                () => setState(() => _status = s)),
        ]),
        if (!_isEdit) ...[
          const SizedBox(height: 14),
          formLabel('Topic'),
          FutureBuilder<List<Topic>>(
            future: _topicsFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              final topics = snap.data ?? const [];
              if (topics.isEmpty) {
                return Text('Create a topic first.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.tx4));
              }
              _topicId ??= topics.first.id;
              return chipWrap([
                for (final t in topics)
                  selChip(t.title, _topicId == t.id,
                      () => setState(() => _topicId = t.id)),
              ]);
            },
          ),
        ],
        const SizedBox(height: 14),
        formLabel('Platform (optional)'),
        formField(_platform, 'e.g. Udemy, YouTube'),
        const SizedBox(height: 14),
        formLabel('Link (optional)'),
        formField(_url, 'https://…', keyboard: TextInputType.url),
        const SizedBox(height: 14),
        formLabel('Notes (optional)'),
        formField(_notes, 'Why this resource, what to focus on…', lines: 3),
        const SizedBox(height: 22),
        saveButton(_saving, _save, _isEdit ? 'Save changes' : 'Add resource'),
        if (_isEdit) ...[
          const SizedBox(height: 6),
          deleteRow(context, 'Delete resource', () async {
            if (await confirmDelete(
                context, '“${widget.item!.title}” will be removed.')) {
              await getIt<LifeRepository>().deleteResource(widget.item!.id);
              if (context.mounted) Navigator.of(context).pop(true);
            }
          }),
        ],
      ],
    );
  }
}
