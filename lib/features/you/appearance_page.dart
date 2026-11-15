import 'package:flutter/material.dart';

import '../../design/appearance.dart';
import '../../design/components.dart';
import '../../design/rings.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'you_page.dart';

/// Appearance: theme, larger text, reduce motion. Kept on this phone and
/// applied at once everywhere in the new look.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppearancePrefs>(
        valueListenable: AllyAppearance.prefs,
        builder: (context, p, _) => YouPage(
          title: 'Appearance',
          sub: 'Saved on this phone. Pages not rebuilt yet stay dark for now.',
          children: (themed, c) => [
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('THEME', style: AllyType.eyebrow(color: c.faint)),
              const SizedBox(height: Sp.x2),
              AllySegmented<String>(
                options: const {'SYSTEM': 'Match phone', 'LIGHT': 'Light', 'DARK': 'Dark'},
                value: p.theme,
                onChanged: (v) => AllyAppearance.set(p.copyWith(theme: v)),
              ),
            ]),
            _switch(c, 'Larger text', 'A little larger than your phone\'s own text size.', p.largerText,
                (v) => AllyAppearance.set(p.copyWith(largerText: v))),
            _switch(c, 'Reduce motion', 'Things appear without moving. Your phone\'s own setting is always followed too.', p.reduceMotion,
                (v) => AllyAppearance.set(p.copyWith(reduceMotion: v))),
            AllyCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('PREVIEW', style: AllyType.eyebrow(color: c.faint)),
                const SizedBox(height: Sp.x2),
                Row(children: [
                  ProgressRing(value: 0.6, color: c.area(0), semanticLabel: 'Sample'),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Read 10 pages', style: AllyType.body(color: c.ink, w: FontWeight.w500)),
                      Text('3 of 5 this week', style: AllyType.small(color: c.faint)),
                    ]),
                  ),
                ]),
                const SizedBox(height: Sp.x3),
                AllyButton('Start', kind: AllyButtonKind.free, icon: Icons.play_arrow_rounded, onPressed: () {}),
              ]),
            ),
          ],
        ),
      );

  Widget _switch(AllyColors c, String title, String sub, bool value, ValueChanged<bool> onChanged) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AllyType.body(color: c.ink, w: FontWeight.w500)),
            Text(sub, style: AllyType.small(color: c.faint)),
          ]),
        ),
        AllySwitch(value: value, semanticLabel: title, onChanged: onChanged),
      ]);
}
