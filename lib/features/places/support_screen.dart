import 'package:flutter/material.dart';

import '../../core/links/open_link.dart';
import '../../design/type.dart';

/// A reply carrying the helpline is the safety answer, from code or from the AI.
bool isCrisisReply(String text) => text.contains('14416');

/// Real people, right now. New type, but a warm light page in both themes on
/// purpose: it should not look like the rest of the app.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const _paper = Color(0xFFFBF1EC);
  static const _ink = Color(0xFF2A1F1B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 24),
                  Text("I'm really glad you told me.", style: AllyType.h1(color: _ink).copyWith(fontSize: 38)),
                  const SizedBox(height: 16),
                  Text("Please reach someone right now. You don't have to carry this alone.",
                      style: AllyType.body(color: _ink).copyWith(fontSize: 20, height: 1.4)),
                ]),
              ),
            ),
            SizedBox(
              height: 88,
              child: TextButton(
                onPressed: () => openLink(context, 'tel:14416'),
                style: TextButton.styleFrom(backgroundColor: _ink, foregroundColor: _paper, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                // Large system text must shrink this, never push the number out of the button.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Call Tele-MANAS 14416', style: AllyType.h2(color: _paper)),
                    Text('Free, 24 hours, India', style: AllyType.small(color: _paper)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 62,
              child: OutlinedButton(
                onPressed: () => openLink(context, 'tel:112'),
                style: OutlinedButton.styleFrom(foregroundColor: _ink, side: const BorderSide(color: _ink, width: 1.5), shape: const StadiumBorder()),
                child: Text('In immediate danger: call 112', style: AllyType.body(color: _ink, w: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: _ink, minimumSize: const Size(64, 52)),
              child: Text('Keep talking with Ally', style: AllyType.body(color: _ink).copyWith(decoration: TextDecoration.underline, decorationColor: _ink)),
            ),
          ]),
        ),
      ),
    );
  }
}
