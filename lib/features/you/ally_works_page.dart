import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'you_page.dart';

/// How Ally works for you: what to help with most, and how to talk. Each
/// choice saves at once, with Undo.
class AllyWorksPage extends StatefulWidget {
  final LifeRepository repo;
  const AllyWorksPage({super.key, required this.repo});

  @override
  State<AllyWorksPage> createState() => _AllyWorksPageState();
}

class _AllyWorksPageState extends State<AllyWorksPage> {
  static const _focus = [
    ('ALL', 'A bit of everything', 'Goals, reminders, notes and what to do now.'),
    ('REMEMBER', 'Just remember and remind', 'No goals, plans or suggestions unless you ask.'),
    ('GOALS', 'My goals', 'Lead with what to do now and what is behind this week.'),
    ('SAVES', 'Turn what I save into steps', 'Videos and posts you keep become one small step.'),
    ('SUPPORT', 'Someone to talk to', 'Listen first. Plans only when you ask.'),
  ];
  static const _tone = [
    ('GENTLE', 'Gentle', 'Suggestions only. Never says "not now".'),
    ('BALANCED', 'Balanced', 'Says so when something is not working, kindly.'),
    ('DIRECT', 'Direct', 'Says it straight, in few words.'),
  ];

  String? _f;
  String? _t;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.repo.allyPreferences();
      if (mounted) {
        setState(() {
          _f = p.focus;
          _t = p.directness;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _set(BuildContext themed, {String? focus, String? tone}) async {
    final before = (_f, _t);
    setState(() {
      _f = focus ?? _f;
      _t = tone ?? _t;
    });
    try {
      await widget.repo.saveAllyPreferences(focus: focus, directness: tone);
      if (!themed.mounted) return;
      showAllyToast(
        themed,
        'Saved.',
        onUndo: () async {
          try {
            await widget.repo.saveAllyPreferences(focus: focus == null ? null : before.$1, directness: tone == null ? null : before.$2);
            if (mounted) {
              setState(() {
                _f = before.$1;
                _t = before.$2;
              });
            }
          } on ApiException catch (e) {
            if (themed.mounted) showAllyToast(themed, e.message);
          }
        },
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _f = before.$1;
          _t = before.$2;
        });
      }
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => YouPage(
    title: 'How Ally works for you',
    sub: 'Change it any time, or just say it in Talk ("be more direct").',
    loading: _f == null && _error == null,
    error: _f == null ? _error : null,
    onRetry: _load,
    children: (themed, c) => [
      _group(themed, c, 'WHAT SHOULD ALLY HELP WITH MOST?', _focus, _f, (v) => _set(themed, focus: v)),
      _group(themed, c, 'HOW SHOULD ALLY TALK TO YOU?', _tone, _t, (v) => _set(themed, tone: v)),
    ],
  );

  Widget _group(
    BuildContext themed,
    AllyColors c,
    String title,
    List<(String, String, String)> options,
    String? value,
    ValueChanged<String> onPick,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: AllyType.eyebrow(color: c.faint)),
      const SizedBox(height: Sp.x2),
      for (final (key, label, sub) in options) ...[
        AllyCard(
          strong: value == key,
          onTap: value == key ? null : () => onPick(key),
          padding: const EdgeInsets.all(Sp.x4),
          child: Semantics(
            selected: value == key,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AllyType.body(color: c.ink, w: FontWeight.w600),
                      ),
                      Text(sub, style: AllyType.small(color: c.muted)),
                    ],
                  ),
                ),
                if (value == key) Icon(Icons.check_rounded, color: c.ink),
              ],
            ),
          ),
        ),
        const SizedBox(height: Sp.x2),
      ],
    ],
  );
}
