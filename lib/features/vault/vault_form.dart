import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/vault_item.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/form_kit.dart';

/// Backend vaultType enum.
const _vaultTypes = ['REFLECTION', 'MEMORY', 'MOTIVATION', 'RECOVERY'];

/// Backend mediaType enum. Icons mirror web's constants.tsx: text -> sticky
/// note, quote -> format_quote, video -> videocam, audio -> mic, image ->
/// image. Not currently rendered here (selChip is text-only) but kept for
/// any future icon-chip usage / the vault screen's secondary badge.
const _mediaTypes = ['TEXT', 'QUOTE', 'VIDEO', 'AUDIO', 'IMAGE'];

class VaultForm extends StatefulWidget {
  final VaultItem? item;
  const VaultForm({super.key, this.item});

  @override
  State<VaultForm> createState() => _VaultFormState();
}

class _VaultFormState extends State<VaultForm> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _url;
  late final TextEditingController _tags;
  String _type = 'MOTIVATION';
  String _mediaType = 'TEXT';
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final v = widget.item;
    _title = TextEditingController(text: v?.title ?? '');
    _content = TextEditingController(text: v?.content ?? '');
    _url = TextEditingController(text: v?.url ?? '');
    _tags = TextEditingController(text: (v?.triggerTags ?? const []).join(', '));
    if (v != null && _vaultTypes.contains(v.vaultType.toUpperCase())) {
      _type = v.vaultType.toUpperCase();
    }
    if (v != null && _mediaTypes.contains(v.mediaType.toUpperCase())) {
      _mediaType = v.mediaType.toUpperCase();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _url.dispose();
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
    if (title.isEmpty || content.isEmpty) return;
    setState(() => _saving = true);
    final repo = getIt<LifeRepository>();
    try {
      if (_isEdit) {
        await repo.updateVaultItem(widget.item!.id,
            title: title,
            content: content,
            vaultType: _type,
            mediaType: _mediaType,
            url: _url.text.trim(),
            triggerTags: _tagList);
      } else {
        await repo.createVaultItem(
            title: title,
            content: content,
            vaultType: _type,
            mediaType: _mediaType,
            url: _url.text.trim(),
            triggerTags: _tagList);
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
      title: _isEdit ? 'Edit vault item' : 'New vault item',
      children: [
        formField(_title, 'Title', autofocus: !_isEdit),
        const SizedBox(height: 10),
        formField(_content, 'Content — the quote, win or protocol…', lines: 4),
        const SizedBox(height: 16),
        formLabel('Type'),
        chipWrap([
          for (final t in _vaultTypes)
            selChip(titleCaseWord(t), _type == t,
                () => setState(() => _type = t)),
        ]),
        const SizedBox(height: 14),
        formLabel('Media'),
        chipWrap([
          for (final m in _mediaTypes)
            selChip(
                titleCaseWord(m), _mediaType == m,
                () => setState(() => _mediaType = m)),
        ]),
        const SizedBox(height: 14),
        formLabel('Link (optional)'),
        formField(_url, 'https://…', keyboard: TextInputType.url),
        const SizedBox(height: 14),
        formLabel('Trigger tags (comma-separated)'),
        formField(_tags, 'e.g. low-energy, doubt'),
        const SizedBox(height: 22),
        saveButton(_saving, _save, _isEdit ? 'Save changes' : 'Add to vault'),
        if (_isEdit) ...[
          const SizedBox(height: 6),
          deleteRow(context, 'Delete item', () async {
            if (await confirmDelete(
                context, '“${widget.item!.title}” will be removed.')) {
              await getIt<LifeRepository>().deleteVaultItem(widget.item!.id);
              if (context.mounted) Navigator.of(context).pop(true);
            }
          }),
        ],
      ],
    );
  }
}
