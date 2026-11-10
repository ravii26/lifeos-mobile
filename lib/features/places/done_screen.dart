import 'package:flutter/material.dart';

import '../guide/guide_style.dart';

/// What the person wants after finishing. Null (the back button) means what's next.
enum DoneChoice { finishedForToday, undo }

/// The moment after Done: it counted, and there is no rush to do the next thing.
class DoneScreen extends StatelessWidget {
  final String title;
  final bool canUndo;
  const DoneScreen({super.key, required this.title, required this.canUndo});

  @override
  Widget build(BuildContext context) {
    final ink = G.onInk;
    return Scaffold(
      backgroundColor: G.accent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(top: 96),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: ink),
                      child: Icon(Icons.check_rounded, size: 46, color: G.accent),
                    ),
                    const SizedBox(height: 28),
                    Text('That counts.', style: G.text(58, w: FontWeight.w600, color: ink, height: 1, letterSpacing: -2)),
                    const SizedBox(height: 16),
                    Text('$title is done.', style: G.text(21, color: ink, height: 1.34)),
                  ]),
                ),
              ),
            ),
            SizedBox(
              height: 66,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: G.ink,
                  shape: const StadiumBorder(),
                ),
                child: Text("What's next?", style: G.text(20, w: FontWeight.w600, color: G.ink, height: 1.2)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 54,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(DoneChoice.finishedForToday),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ink,
                  side: BorderSide(color: ink, width: 1.5),
                  shape: const StadiumBorder(),
                ),
                child: Text("I'm finished for today", style: G.text(17, w: FontWeight.w500, color: ink, height: 1.2)),
              ),
            ),
            if (canUndo)
              TextButton(
                onPressed: () => Navigator.of(context).pop(DoneChoice.undo),
                style: TextButton.styleFrom(foregroundColor: ink, minimumSize: const Size(64, 48)),
                child: Text('Undo',
                    style: G.text(16, color: ink, height: 1.2).copyWith(decoration: TextDecoration.underline, decorationColor: ink)),
              ),
          ]),
        ),
      ),
    );
  }
}
