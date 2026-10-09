import 'package:flutter/material.dart';

import '../features/guide/guide_style.dart';

/// Nocturne Sanctuary bottom-sheet scaffold shared by the create/edit forms.
class FormSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const FormSheet({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: G.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(
            top: BorderSide(color: G.lineSoft, width: 0.5),
            left: BorderSide(color: G.lineSoft, width: 0.5),
            right: BorderSide(color: G.lineSoft, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: G.lineSoft,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: G.voice(18, color: G.ink),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

Widget formLabel(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        t.toUpperCase(),
        style: G.label(size: 10.5, color: G.faint),
      ),
    );

Widget formField(TextEditingController c, String hint,
        {int lines = 1, bool autofocus = false, TextInputType? keyboard}) =>
    TextField(
      controller: c,
      autofocus: autofocus,
      maxLines: lines,
      keyboardType: keyboard,
      style: G.text(14.5, color: G.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: G.text(14, color: G.faint),
        filled: true,
        fillColor: G.inset,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: G.lineSoft, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: G.lineSoft, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: G.accent, width: 0.8),
        ),
      ),
    );

Widget chipWrap(List<Widget> chips) =>
    Wrap(spacing: 6, runSpacing: 6, children: chips);

Widget selChip(String label, bool selected, VoidCallback onTap, {Color? color}) {
  final c = color ?? G.accent;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: selected ? c.withValues(alpha: 0.15) : G.inset,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: selected ? c : G.lineSoft,
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: G.text(
          12.5,
          w: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? c : G.muted,
        ),
      ),
    ),
  );
}

Widget saveButton(bool saving, VoidCallback onTap, String label) => SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: saving ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: G.accent.withValues(alpha: 0.12),
          side: BorderSide(color: G.accent.withValues(alpha: 0.4), width: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: saving
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: G.accent,
                ))
            : Text(
                label,
                style: G.text(14, w: FontWeight.w500, color: G.accent),
              ),
      ),
    );

Widget deleteRow(BuildContext context, String label, VoidCallback onTap) =>
    Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.delete_outline, size: 16, color: G.carried),
        label: Text(label, style: G.label(size: 12, color: G.carried)),
      ),
    );

/// Standard confirm-delete dialog. Returns true if confirmed.
Future<bool> confirmDelete(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dctx) => AlertDialog(
      backgroundColor: G.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: G.lineSoft, width: 0.5),
      ),
      title: Text('Delete?', style: G.voice(16, color: G.ink)),
      content: Text(message, style: G.text(13.5, color: G.muted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dctx).pop(false),
          child: Text('Cancel', style: G.label(size: 12, color: G.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dctx).pop(true),
          child: Text('Delete', style: G.label(size: 12, color: G.carried)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

String titleCaseWord(String s) =>
    s.isEmpty ? s : s[0] + s.substring(1).toLowerCase();
