import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';

/// "How should Ally be with you?" Two choices, both saved on the server:
/// what Ally leads with, and how direct it is. The defaults change nothing.
class HowAllyWorksScreen extends StatefulWidget {
  const HowAllyWorksScreen({super.key});

  @override
  State<HowAllyWorksScreen> createState() => _HowAllyWorksScreenState();
}

class _HowAllyWorksScreenState extends State<HowAllyWorksScreen> {
  final _repo = getIt<LifeRepository>();
  String _focus = 'ALL';
  String _directness = 'BALANCED';
  bool _loading = true;
  String? _error;

  static const _focuses = [
    ('ALL', 'A bit of everything', 'Goals, reminders, notes and what to do now.'),
    ('REMEMBER', 'Just remember and remind', 'No goals, plans or suggestions unless you ask.'),
    ('GOALS', 'My goals', 'Lead with what to do now and what is behind this week.'),
    ('SAVES', 'Turn what I save into steps', 'Videos and posts you keep become one small step.'),
    ('SUPPORT', 'Someone to talk to', 'Listen first. Plans only when you ask.'),
  ];

  static const _styles = [
    ('GENTLE', 'Gentle', 'Suggestions only. Never says "not now".'),
    ('BALANCED', 'Balanced', 'Says so when something is not working, kindly.'),
    ('DIRECT', 'Direct', 'Says it straight, in few words.'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _repo.allyPreferences();
      if (!mounted) return;
      setState(() {
        _focus = p.focus;
        _directness = p.directness;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load this. Pull back and try again.";
      });
    }
  }

  // Shows the choice at once, puts it back if the server says no.
  Future<void> _save({String? focus, String? directness}) async {
    final before = (_focus, _directness);
    setState(() {
      _error = null;
      if (focus != null) _focus = focus;
      if (directness != null) _directness = directness;
    });
    try {
      await _repo.saveAllyPreferences(focus: focus, directness: directness);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _focus = before.$1;
        _directness = before.$2;
        _error = "Couldn't save that. Check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: G.bg,
      appBar: const GTopBar('How Ally works for you', subtitle: 'Change it any time', showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                const GHeading('What should Ally help with most?'),
                for (final f in _focuses)
                  _Choice(title: f.$2, sub: f.$3, selected: _focus == f.$1, onTap: () => _save(focus: f.$1)),
                const SizedBox(height: 22),
                const GHeading('How should Ally talk to you?'),
                for (final s in _styles)
                  _Choice(title: s.$2, sub: s.$3, selected: _directness == s.$1, onTap: () => _save(directness: s.$1)),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_error!, style: G.text(13, color: G.muted, height: 1.4)),
                  ),
                const SizedBox(height: 16),
                Text('You can also just tell Ally in chat: "be more direct" or "I only want reminders".',
                    style: G.text(13, color: G.muted, height: 1.4)),
              ],
            ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _Choice({required this.title, required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: G.lineSoft, width: 0.5))),
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20, color: selected ? G.accent : G.faint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: G.text(15, w: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(sub, style: G.text(13, color: G.muted, height: 1.4)),
              ]),
            ),
          ]),
        ),
      );
}
