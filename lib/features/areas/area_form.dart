import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/area.dart';
import '../../widgets/form_kit.dart';
import '../shell/life_cubit.dart';

/// Palette offered for an area's accent colour.
const _palette = <String>[
  '#c5f23f', // chartreuse (accent)
  '#4f8cff', // blue
  '#2dd4a7', // teal
  '#ff6b81', // pink
  '#ffb547', // amber
  '#a78bfa', // violet
  '#ff5d62', // red
  '#38bdf8', // sky
];

/// A small set of named icons the backend stores as strings.
const _icons = <String, IconData>{
  'target': Icons.gps_fixed,
  'heart': Icons.favorite_outline,
  'dumbbell': Icons.fitness_center,
  'book': Icons.menu_book_outlined,
  'briefcase': Icons.work_outline,
  'sparkles': Icons.auto_awesome_outlined,
  'leaf': Icons.eco_outlined,
  'wallet': Icons.account_balance_wallet_outlined,
};

class AreaForm extends StatefulWidget {
  final Area? area;
  const AreaForm({super.key, this.area});

  @override
  State<AreaForm> createState() => _AreaFormState();
}

class _AreaFormState extends State<AreaForm> {
  late final TextEditingController _name;
  String _type = 'PRIMARY';
  late String _color;
  late String _icon;
  bool _saving = false;

  bool get _isEdit => widget.area != null;

  @override
  void initState() {
    super.initState();
    final a = widget.area;
    _name = TextEditingController(text: a?.name ?? '');
    _type = a?.type ?? 'PRIMARY';
    _color = a?.colorHex ?? _palette.first;
    _icon = a?.icon ?? 'target';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await context.read<LifeCubit>().saveArea(
          id: widget.area?.id,
          name: name,
          type: _type,
          color: _color,
          icon: _icon,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Color _hex(String h) {
    var s = h.replaceAll('#', '');
    if (s.length == 6) s = 'FF$s';
    return Color(int.tryParse(s, radix: 16) ?? 0xFFC5F23F);
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: _isEdit ? 'Edit area' : 'New area',
      children: [
        formField(_name, 'Area name', autofocus: !_isEdit),
        const SizedBox(height: 16),
        formLabel('Type'),
        chipWrap([
          for (final t in const ['PRIMARY', 'MAINTENANCE'])
            selChip(titleCaseWord(t), _type == t,
                () => setState(() => _type = t)),
        ]),
        const SizedBox(height: 16),
        formLabel('Colour'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in _palette)
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _hex(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _color == c ? AppColors.tx : Colors.transparent,
                        width: 2.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        formLabel('Icon'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in _icons.entries)
              GestureDetector(
                onTap: () => setState(() => _icon = entry.key),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _icon == entry.key
                        ? _hex(_color).withValues(alpha: 0.18)
                        : AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _icon == entry.key
                            ? _hex(_color)
                            : AppColors.line),
                  ),
                  child: Icon(entry.value,
                      size: 20,
                      color: _icon == entry.key ? _hex(_color) : AppColors.tx2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        saveButton(_saving, _save, _isEdit ? 'Save changes' : 'Create area'),
        if (_isEdit) ...[
          const SizedBox(height: 6),
          deleteRow(context, 'Delete area', () async {
            if (await confirmDelete(context,
                '“${widget.area!.name}” and its score history will be removed.')) {
              if (!context.mounted) return;
              context.read<LifeCubit>().deleteArea(widget.area!.id);
              Navigator.of(context).pop();
            }
          }),
        ],
      ],
    );
  }
}
