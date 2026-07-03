import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/review.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/form_kit.dart';

/// Bottom-sheet form to edit (or delete) a saved review's text fields.
/// Mirrors web's ReviewDetailPage edit form (summary/highlights/
/// improvements/userNote), built on the same [FormSheet] kit as
/// [VaultForm]/[ResourceForm].
class ReviewEditSheet extends StatefulWidget {
  final Review review;
  const ReviewEditSheet({super.key, required this.review});

  @override
  State<ReviewEditSheet> createState() => _ReviewEditSheetState();
}

class _ReviewEditSheetState extends State<ReviewEditSheet> {
  late final TextEditingController _summary;
  late final TextEditingController _highlights;
  late final TextEditingController _improvements;
  late final TextEditingController _userNote;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.review;
    _summary = TextEditingController(text: r.summary ?? '');
    _highlights = TextEditingController(text: r.highlights ?? '');
    _improvements = TextEditingController(text: r.improvements ?? '');
    _userNote = TextEditingController(text: r.userNote ?? '');
  }

  @override
  void dispose() {
    _summary.dispose();
    _highlights.dispose();
    _improvements.dispose();
    _userNote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = getIt<LifeRepository>();
    try {
      await repo.updateReview(
        widget.review.id,
        summary: _summary.text.trim(),
        highlights: _highlights.text.trim(),
        improvements: _improvements.text.trim(),
        userNote: _userNote.text.trim(),
      );
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
      title: 'Edit review',
      children: [
        formLabel('Summary'),
        formField(_summary, 'How did the period go?', lines: 3),
        const SizedBox(height: 14),
        formLabel('Highlights'),
        formField(_highlights, 'What went well?', lines: 3),
        const SizedBox(height: 14),
        formLabel('Improvements'),
        formField(_improvements, 'What would you change?', lines: 3),
        const SizedBox(height: 14),
        formLabel('Personal note'),
        formField(_userNote, 'Anything else to remember…', lines: 3),
        const SizedBox(height: 22),
        saveButton(_saving, _save, 'Save changes'),
        const SizedBox(height: 6),
        deleteRow(context, 'Delete review', () async {
          if (await confirmDelete(
              context, 'This review and its insights will be removed.')) {
            await getIt<LifeRepository>().deleteReview(widget.review.id);
            if (context.mounted) Navigator.of(context).pop(true);
          }
        }),
      ],
    );
  }
}
