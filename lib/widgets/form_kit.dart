import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

/// Glass bottom-sheet scaffold shared by the create/edit forms.
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
              Text(title,
                  style: GoogleFonts.hankenGrotesk(
                      fontSize: 20, fontWeight: FontWeight.w700)),
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
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(t,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.tx3)),
    );

Widget formField(TextEditingController c, String hint,
        {int lines = 1, bool autofocus = false, TextInputType? keyboard}) =>
    TextField(
      controller: c,
      autofocus: autofocus,
      maxLines: lines,
      keyboardType: keyboard,
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

Widget chipWrap(List<Widget> chips) =>
    Wrap(spacing: 8, runSpacing: 8, children: chips);

Widget selChip(String label, bool selected, VoidCallback onTap, {Color? color}) {
  final c = color ?? AppColors.accent;
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

Widget saveButton(bool saving, VoidCallback onTap, String label) => SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: saving ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentInk,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        child: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label),
      ),
    );

Widget deleteRow(BuildContext context, String label, VoidCallback onTap) =>
    Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
        label: Text(label, style: const TextStyle(color: AppColors.danger)),
      ),
    );

/// Standard confirm-delete dialog. Returns true if confirmed.
Future<bool> confirmDelete(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dctx) => AlertDialog(
      backgroundColor: AppColors.surface2,
      title: const Text('Delete?', style: TextStyle(fontSize: 16)),
      content: Text(message,
          style: TextStyle(fontSize: 13, color: AppColors.tx3)),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger))),
      ],
    ),
  );
  return ok ?? false;
}

String titleCaseWord(String s) =>
    s.isEmpty ? s : s[0] + s.substring(1).toLowerCase();
