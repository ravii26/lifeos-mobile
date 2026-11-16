import 'package:flutter/material.dart';

import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// What the edit sheet asks for.
sealed class EditAnswer {
  const EditAnswer();
}

class EditRename extends EditAnswer {
  final String name;
  const EditRename(this.name);
}

class EditLetGo extends EditAnswer {
  const EditLetGo();
}

/// Edit an area or a goal: change its name, or let it go. Pops with an
/// [EditAnswer], or null when closed or nothing changed.
class RenameSheet extends StatefulWidget {
  /// "Edit area", "Edit goal".
  final String heading;
  final String name;

  /// "Let this area go".
  final String letGoLabel;

  /// What letting go does, said plainly.
  final String letGoNote;

  const RenameSheet({super.key, required this.heading, required this.name, required this.letGoLabel, required this.letGoNote});

  @override
  State<RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<RenameSheet> {
  late final _name = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _changed => _name.text.trim().isNotEmpty && _name.text.trim() != widget.name;

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.heading, style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x3),
        Text('NAME', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x2),
        TextField(
          controller: _name,
          maxLength: 100,
          textCapitalization: TextCapitalization.sentences,
          style: AllyType.body(color: c.ink),
          decoration: const InputDecoration(hintText: 'Name', counterText: ''),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (_changed) Navigator.of(context).pop<EditAnswer>(EditRename(_name.text.trim()));
          },
        ),
        const SizedBox(height: Sp.x4),
        AllyButton('Save', wide: true, onPressed: _changed ? () => Navigator.of(context).pop<EditAnswer>(EditRename(_name.text.trim())) : null),
        const SizedBox(height: Sp.x4),
        Text(widget.letGoNote, style: AllyType.small(color: c.faint)),
        const SizedBox(height: Sp.x2),
        AllyButton(widget.letGoLabel, kind: AllyButtonKind.ghost, wide: true, onPressed: () => Navigator.of(context).pop<EditAnswer>(const EditLetGo())),
      ],
    );
  }
}
