import 'package:flutter/material.dart';

import '../../core/links/open_link.dart';
import '../guide/guide_style.dart';

/// A reply carrying the helpline is the safety answer, from code or from the AI.
bool isCrisisReply(String text) => text.contains('14416');

/// Real people, right now. Light on purpose: it should not look like the rest of the app.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const paper = Color(0xFFFBF1EC);
    final ink = G.onInk;
    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 24),
                  Text("I'm really glad you told me.", style: G.text(42, w: FontWeight.w600, color: ink, height: 1.08, letterSpacing: -1.2)),
                  const SizedBox(height: 16),
                  Text("Please reach someone right now. You don't have to carry this alone.", style: G.text(21, color: ink, height: 1.38)),
                ]),
              ),
            ),
            SizedBox(
              height: 88,
              child: TextButton(
                onPressed: () => openLink(context, 'tel:14416'),
                style: TextButton.styleFrom(backgroundColor: ink, foregroundColor: paper, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                // Large system text must shrink this, never push the number out of the button.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Call Tele-MANAS 14416', style: G.text(22, w: FontWeight.w600, color: paper, height: 1.2)),
                    Text('Free, 24 hours, India', style: G.text(15, color: paper, height: 1.3)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 62,
              child: OutlinedButton(
                onPressed: () => openLink(context, 'tel:112'),
                style: OutlinedButton.styleFrom(foregroundColor: ink, side: BorderSide(color: ink, width: 1.5), shape: const StadiumBorder()),
                child: Text('In immediate danger: call 112', style: G.text(18, w: FontWeight.w500, color: ink, height: 1.2)),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: ink, minimumSize: const Size(64, 52)),
              child: Text('Keep talking with Ally', style: G.text(17, color: ink, height: 1.2).copyWith(decoration: TextDecoration.underline, decorationColor: ink)),
            ),
          ]),
        ),
      ),
    );
  }
}
