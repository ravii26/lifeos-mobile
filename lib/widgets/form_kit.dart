import 'package:flutter/material.dart';

import '../features/guide/guide_style.dart';

/// Bottom sheet shared by the create and edit forms.
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
          color: G.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: G.surfaceHigh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: G.text(32, w: FontWeight.w600, height: 1.1, letterSpacing: -0.7),
              ),
              const SizedBox(height: 18),
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
      child: Text(t, style: G.text(16, color: G.muted, height: 1.25)),
    );

Widget formField(TextEditingController c, String hint,
        {int lines = 1, bool autofocus = false, TextInputType? keyboard}) =>
    TextField(
      controller: c,
      autofocus: autofocus,
      maxLines: lines,
      keyboardType: keyboard,
      cursorColor: G.accent,
      style: G.text(18, height: 1.3),
      decoration: gFieldStyle(hint),
    );

/// The look of every text box: a soft filled shape, peach when you are in it.
InputDecoration gFieldStyle(String hint, {Color? fill}) => InputDecoration(
      hintText: hint,
      hintStyle: G.text(18, color: G.faint, height: 1.3),
      filled: true,
      fillColor: fill ?? G.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: G.accent, width: 1.5)),
    );

Widget chipWrap(List<Widget> chips) =>
    Wrap(spacing: 8, runSpacing: 8, children: chips);

/// A choice pill. [color] adds a small dot, for things that have their own colour.
Widget selChip(String label, bool selected, VoidCallback onTap, {Color? color}) {
  return Material(
    color: selected ? G.accent : G.card,
    shape: const StadiumBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46, maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: G.text(16, w: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? G.onInk : G.ink, height: 1.2),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A small filled button for picking a date or time inside a form.
Widget formPick(IconData icon, String label, VoidCallback onTap) => SizedBox(
      height: 48,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: G.ink),
        label: Text(label, style: G.text(16, height: 1.2)),
        style: TextButton.styleFrom(backgroundColor: G.card, foregroundColor: G.ink, padding: const EdgeInsets.symmetric(horizontal: 18), shape: const StadiumBorder()),
      ),
    );

/// The quiet "take it away" button next to a [formPick].
Widget formClear(VoidCallback onTap) => TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: G.ink, minimumSize: const Size(56, 48)),
      child: Text('Clear', style: G.text(16, height: 1.2)),
    );

Widget saveButton(bool saving, VoidCallback onTap, String label) => SizedBox(
      width: double.infinity,
      child: GPill(saving ? 'Saving…' : label, primary: true, onTap: saving ? null : onTap),
    );

Widget deleteRow(BuildContext context, String label, VoidCallback onTap) =>
    Center(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: G.ink, minimumSize: const Size(64, 48)),
        child: Text(label, style: G.text(17, height: 1.2)),
      ),
    );

/// A plain confirm dialog in the app's look. Returns true if confirmed.
Future<bool> gConfirm(BuildContext context, {required String title, required String message, required String yes, String no = 'Cancel'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dctx) => AlertDialog(
      backgroundColor: G.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(title, style: G.text(26, w: FontWeight.w600, height: 1.15)),
      content: Text(message, style: G.text(17, color: G.muted, height: 1.35)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dctx).pop(false),
          style: TextButton.styleFrom(foregroundColor: G.ink, minimumSize: const Size(64, 48)),
          child: Text(no, style: G.text(17, height: 1.2)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: G.accent, minimumSize: const Size(64, 48)),
          child: Text(yes, style: G.text(17, w: FontWeight.w600, color: G.accent, height: 1.2)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Standard confirm-delete dialog. Returns true if confirmed.
Future<bool> confirmDelete(BuildContext context, String message) =>
    gConfirm(context, title: 'Delete this?', message: message, yes: 'Delete');

String titleCaseWord(String s) =>
    s.isEmpty ? s : s[0] + s.substring(1).toLowerCase();
