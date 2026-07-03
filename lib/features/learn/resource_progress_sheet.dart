import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/resource.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/form_kit.dart';

/// Bottom sheet to log lesson/minute progress on a [Resource] (B8).
class ResourceProgressSheet extends StatefulWidget {
  final Resource resource;
  const ResourceProgressSheet({super.key, required this.resource});

  @override
  State<ResourceProgressSheet> createState() => _ResourceProgressSheetState();
}

class _ResourceProgressSheetState extends State<ResourceProgressSheet> {
  late final TextEditingController _lessons;
  late final TextEditingController _total;
  late final TextEditingController _minutes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.resource;
    _lessons = TextEditingController(text: '${r.lessonsCompleted + 1}');
    _total = TextEditingController(
        text: r.totalLessons > 0 ? '${r.totalLessons}' : '');
    _minutes = TextEditingController();
  }

  @override
  void dispose() {
    _lessons.dispose();
    _total.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await getIt<LifeRepository>().updateResourceProgress(
        widget.resource.id,
        lessonsCompleted: int.tryParse(_lessons.text.trim()),
        totalLessons: int.tryParse(_total.text.trim()),
        minutesConsumed: int.tryParse(_minutes.text.trim()) ?? 0,
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
      title: 'Log progress · ${widget.resource.title}',
      children: [
        formLabel('Lessons completed'),
        formField(_lessons, 'e.g. 4', keyboard: TextInputType.number),
        const SizedBox(height: 14),
        formLabel('Total lessons (optional)'),
        formField(_total, 'e.g. 12', keyboard: TextInputType.number),
        const SizedBox(height: 14),
        formLabel('Minutes spent this session'),
        formField(_minutes, 'e.g. 25', keyboard: TextInputType.number),
        const SizedBox(height: 22),
        saveButton(_saving, _save, 'Save progress'),
      ],
    );
  }
}
