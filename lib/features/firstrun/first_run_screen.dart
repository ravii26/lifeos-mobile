import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/json.dart';
import '../../data/models/user.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/appearance.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../areas/areas_overview.dart' show AreaMode, loadAreasOverview;
import '../areas/milestones.dart' show MilestoneEditor;
import '../areas/when_picker.dart';
import '../session/focus_session_screen.dart';
import '../talk/voice_input.dart';
import '../week/review_rules.dart' show minutesLabel;
import 'first_run_data.dart';
import 'save_account.dart';

/// First run (ALLY.md 2.1): what you want → sorted into areas → your normal
/// week → a mode for each area → a draft plan and step one → save the account.
/// Every step saves on the phone, so leaving midway loses nothing; with no
/// AI every step still works (sorting and plans fall back to plain rules).
class FirstRunScreen extends StatefulWidget {
  final LifeRepository repo;
  final Claim claim;

  /// Finished: [saved] is the saved account, or null for "Later".
  final void Function(AppUser? saved) onDone;
  final VoiceInput? voice;

  /// For tests: opening step one.
  final Future<FocusOutcome?> Function(BuildContext context, String title, int minutes, String areaName)? startFocus;
  const FirstRunScreen({super.key, required this.repo, required this.claim, required this.onDone, this.voice, this.startFocus});

  @override
  State<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends State<FirstRunScreen> {
  FirstRunDraft? _d;
  final _text = TextEditingController();
  late final VoiceInput _voice = widget.voice ?? PhoneVoiceInput();
  bool _listening = false;
  bool _busy = false;
  String? _error;

  // Your normal week.
  int _days = 0, _hours = 0, _wake = 1, _sleep = 1;
  bool _weekSet = false;

  // The draft plan.
  Json? _plan;
  String? _planAreaId, _planAreaName;
  bool _planTried = false;

  @override
  void initState() {
    super.initState();
    FirstRunDraft.load().then((d) {
      if (!mounted) return;
      setState(() {
        _d = d;
        _text.text = d.text;
        _weekSet = d.freeMinutes > 0;
      });
      if (d.step == 4) _draftPlan();
    });
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _voice.cancel();
    _text.dispose();
    super.dispose();
  }

  FirstRunDraft get d => _d!;

  Future<void> _go(int step) async {
    setState(() {
      d.step = step;
      _error = null;
    });
    await d.save();
    if (step == 4) await _draftPlan();
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await job();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- step 1: everything you want ----

  Future<void> _sort() => _run(() async {
        if (_listening) await _stopListening();
        d.text = _text.text.trim();
        await d.save();
        d.takeSort(await widget.repo.firstRunSort(d.text));
        await _go(1);
      });

  Future<void> _listen() async {
    final base = _text.text.trim().isEmpty ? '' : '${_text.text.trimRight()} ';
    setState(() => _listening = true);
    final lang = await VoiceLang.load();
    final ok = await _voice.dictate(
      locale: lang.locale,
      onWords: (w) {
        _text.text = '$base$w';
        _text.selection = TextSelection.collapsed(offset: _text.text.length);
      },
      onEnd: () {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!ok && mounted) {
      setState(() {
        _listening = false;
        _error = 'Voice typing is not available on this phone. Typing works.';
      });
    }
  }

  Future<void> _stopListening() async {
    await _voice.stop();
    if (mounted) setState(() => _listening = false);
  }

  // ---- step 3: your normal week ----

  Future<void> _setWeek() => _run(() async {
        final (_, days) = workDayChoices[_days];
        final (_, start, end) = workHourChoices[_hours];
        await widget.repo.setDayBasics(
          wake: wakeChoices[_wake].$2,
          sleep: sleepChoices[_sleep].$2,
          officeDays: start == null ? const [] : days,
          officeStart: days.isEmpty ? null : start,
          officeEnd: days.isEmpty ? null : end,
        );
        final o = await loadAreasOverview(widget.repo);
        d.freeMinutes = o.freeMinutes;
        await d.save();
        setState(() => _weekSet = true);
      });

  // ---- step 4: a mode for each area → apply ----

  Future<void> _apply() => _run(() async {
        final r = await widget.repo.firstRunApply(
          areas: [for (final a in d.areas) {'name': a.name, 'mode': a.mode}],
          items: [for (final i in d.kept) i.toApply()],
        );
        d.applied = r;
        await _go(4);
      });

  // ---- step 5: the draft plan for the first Push goal ----

  Future<void> _draftPlan() async {
    final applied = d.applied;
    if (applied == null || _planTried) return;
    _planTried = true;
    final areas = ((applied['areas'] as List?) ?? const []).whereType<Json>().toList();
    final goals = ((applied['goals'] as List?) ?? const []).whereType<Json>().toList();
    final pushIds = {for (final a in areas) if (asString(a['mode']) == 'PUSH') asString(a['id'])};
    final goal = goals.where((g) => pushIds.contains(asString(g['areaId']))).firstOrNull ?? goals.firstOrNull;
    if (goal == null) return;
    _planAreaId = asString(goal['areaId']);
    _planAreaName = asString(areas.where((a) => asString(a['id']) == _planAreaId).firstOrNull?['name']);
    await _run(() async {
      final p = await widget.repo.proposeGoalPlan(asString(goal['title']), weeklyMinutes: 180);
      if (mounted) setState(() => _plan = p['plan'] is Json ? p['plan'] as Json : null);
    });
  }

  Future<void> _keepPlan({required bool startNow}) => _run(() async {
        final plan = _plan!;
        final r = await widget.repo.acceptGoalPlan(plan, areaId: _planAreaId);
        final first = r['firstStep'] is Json ? r['firstStep'] as Json : null;
        if (startNow && first != null && mounted) {
          final title = asString(first['title']);
          final minutes = asInt(first['minutes'], 15);
          final open = widget.startFocus ??
              (ctx, t, m, a) => Navigator.of(ctx).push<FocusOutcome>(MaterialPageRoute(builder: (_) => FocusSessionScreen(title: t, minutes: m, areaName: a)));
          final outcome = await open(context, title, minutes, _planAreaName ?? '');
          if (outcome?.end == FocusEnd.done) {
            try {
              await widget.repo.respondNow('TASK', asString(first['id']), 'DONE');
            } on ApiException catch (_) {
              // It stays as a step; nothing is lost.
            }
          }
        }
        await _go(5);
      });

  Future<void> _finish(AppUser? saved) async {
    await FirstRunDraft.clear();
    widget.onDone(saved);
  }

  // ---- screens ----

  @override
  Widget build(BuildContext context) => Theme(data: AllyAppearance.themeOf(context), child: Builder(builder: _page));

  Widget _page(BuildContext themed) {
    final c = themed.ac;
    final draft = _d;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: draft == null
            ? const Center(child: AllySkeleton(height: 120, width: 240, radius: Rad.card))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _top(c),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x4, Sp.side, Sp.x4),
                    children: [
                      Stagger(key: ValueKey('${draft.step}-$_busy-$_weekSet-${_plan != null}'), gap: Sp.x4, children: _content(themed, c)),
                    ],
                  ),
                ),
                if (_bottom(c) case final b?) Padding(padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x2, Sp.side, Sp.x4), child: b),
              ]),
      ),
    );
  }

  Widget _top(AllyColors c) {
    final step = d.step;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.x2, Sp.x1, Sp.side, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (step > 0 && step < 4 && !_busy)
            AllyButton('Back', kind: AllyButtonKind.ghost, icon: Icons.arrow_back_rounded, onPressed: () => _go(step - 1))
          else
            const SizedBox(height: 48),
          const Spacer(),
          if (step < 5) Text('${step + 1} / 5', style: AllyType.num(color: c.faint)),
        ]),
        if (step < 5)
          Padding(
            padding: const EdgeInsets.only(left: Sp.x3),
            child: Row(children: [
              for (var i = 0; i < 5; i++) ...[
                if (i > 0) const SizedBox(width: Sp.x1),
                Expanded(
                  child: Container(height: 4, decoration: BoxDecoration(color: i <= step ? c.ink : c.raised, borderRadius: BorderRadius.circular(2))),
                ),
              ],
            ]),
          ),
      ]),
    );
  }

  List<Widget> _content(BuildContext themed, AllyColors c) {
    final err = _error == null ? null : AllyNote(_error!);
    return switch (d.step) {
      0 => [
          Text('What do you want in your life right now?', style: AllyType.h1(color: c.ink)),
          Text('Everything: goals, half-ideas, chores. Messy is fine. Speak or type.', style: AllyType.body(color: c.muted)),
          if (_busy) ...[
            Text('Reading what you said…', style: AllyType.h2(color: c.ink)),
            const AllySkeleton(height: 160, radius: Rad.card),
          ] else ...[
            TextField(
              controller: _text,
              minLines: 6,
              maxLines: 12,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              style: AllyType.body(color: c.ink),
              decoration: const InputDecoration(
                hintText: 'For example: get a new job in 3 months, lose some weight, call family more, pay the card bill, maybe learn guitar',
                counterText: '',
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: AllyButton(_listening ? 'Stop' : 'Speak instead', kind: AllyButtonKind.secondary, icon: _listening ? Icons.stop_rounded : Icons.mic_rounded,
                  onPressed: _listening ? _stopListening : _listen),
            ),
          ],
          ?err,
        ],
      1 => _heard(themed, c, err),
      2 => _week(c, err),
      3 => _modes(themed, c, err),
      4 => _planStep(c, err),
      _ => [
          SaveAccountForm(
            claim: widget.claim,
            onSaved: (u) => _finish(u),
            onLater: () => _finish(null),
          ),
        ],
    };
  }

  Widget? _bottom(AllyColors c) => switch (d.step) {
        0 => _busy ? null : AllyButton('Sort it for me', wide: true, onPressed: _text.text.trim().length < 3 ? null : _sort),
        1 => AllyButton('Continue', wide: true, onPressed: d.kept.isEmpty ? null : () => _go(2)),
        2 => _weekSet
            ? AllyButton('Continue', wide: true, onPressed: () => _go(3))
            : AllyButton(_busy ? 'Working it out…' : 'This is my week', wide: true, onPressed: _busy ? null : _setWeek),
        3 => AllyButton(_busy ? 'Setting up…' : 'Set up my areas', wide: true, onPressed: _busy ? null : _apply),
        _ => null,
      };

  // ---- step 2: here's what I heard ----

  List<Widget> _heard(BuildContext themed, AllyColors c, Widget? err) => [
        Text("Here's what I heard", style: AllyType.h1(color: c.ink)),
        Text(
            d.byCode
                ? 'Sorted without AI this time, by plain words. Tap anything to change it.'
                : d.items.any((i) => i.isIdea)
                    ? "Each one says where it came from. Tap anything to change it, and untick any of Ally's ideas you don't want."
                    : 'Each one says where it came from. Tap anything to change it.',
            style: AllyType.body(color: c.muted)),
        for (var k = 0; k < d.areas.length; k++)
          AllyCard(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x2, Sp.x2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Pressable(
                onTap: () => _renameArea(themed, d.areas[k]),
                semanticLabel: 'Rename ${d.areas[k].name}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Sp.x2),
                  child: Row(children: [
                    Expanded(child: AreaLabel(d.areas[k].name, color: c.area(k))),
                    Icon(Icons.edit_outlined, size: 18, color: c.faint),
                  ]),
                ),
              ),
              for (final i in d.items.where((i) => i.areaName == d.areas[k].name))
                Pressable(
                  scale: 0.985,
                  onTap: () => _editItem(themed, i),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Sp.x2),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(i.title, style: AllyType.body(color: i.on ? c.ink : c.faint)),
                            if (_source(i) case final from?) Text(from, style: AllyType.small(color: c.faint)),
                            if (i.isIdea && i.reason != null) Text(i.reason!, style: AllyType.small(color: c.muted)),
                          ]),
                        ),
                        const SizedBox(width: Sp.x2),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(kindLabel(i.kind), style: AllyType.small(color: c.faint)),
                          if (_whenOf(i).words(DateTime.now()) case final w? when i.kind == 'TASK') Text(w, style: AllyType.small(color: c.muted)),
                        ]),
                        // Ally's ideas come ticked: one tap leaves an idea out.
                        if (i.isIdea)
                          AllyCheck(
                            done: i.on,
                            semanticLabel: "Keep Ally's idea: ${i.title}",
                            onTap: () {
                              setState(() => i.on = !i.on);
                              d.save();
                            },
                          ),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ?err,
      ];

  Future<void> _renameArea(BuildContext themed, FrArea a) async {
    // A plain value, not a controller: the sheet is still closing when this returns.
    var typed = a.name;
    final name = await showAllySheet<String>(
      themed,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Rename this area', style: AllyType.h2(color: ctx.ac.ink)),
        const SizedBox(height: Sp.x3),
        TextFormField(
          initialValue: a.name,
          autofocus: true,
          maxLength: 60,
          style: AllyType.body(color: ctx.ac.ink),
          decoration: const InputDecoration(counterText: ''),
          onChanged: (v) => typed = v,
        ),
        const SizedBox(height: Sp.x3),
        AllyButton('Save', wide: true, onPressed: () => Navigator.of(ctx).pop(typed)),
      ]),
    );
    if (name == null) return;
    setState(() => d.renameArea(a.name, name));
    await d.save();
  }

  /// Where an item came from, said plainly; null when nothing is known (an older draft).
  static String? _source(FrItem i) {
    if (i.isIdea) return i.ideaFor == null ? "Ally's idea" : "Ally's idea for \u201c${i.ideaFor}\u201d";
    return i.said == null ? null : 'From what you said: \u201c${i.said}\u201d';
  }

  static StepWhen _whenOf(FrItem i) => StepWhen(kind: i.due == null ? null : (i.dueKind ?? 'ON'), day: i.due, from: i.windowFrom, to: i.windowTo);

  /// Change anything about an item before it is saved: its name, what kind of
  /// thing it is, when it happens (a to-do), and its area; or remove it.
  Future<void> _editItem(BuildContext themed, FrItem item) async {
    var title = item.title, kind = item.kind, area = item.areaName, newArea = '';
    var when = _whenOf(item), whenOk = true;
    final result = await showAllySheet<String>(
      themed,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Edit', style: AllyType.h2(color: ctx.ac.ink)),
          if (_source(item) case final from?) Text(from, style: AllyType.small(color: ctx.ac.faint)),
          const SizedBox(height: Sp.x3),
          TextFormField(
            initialValue: item.title,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            style: AllyType.body(color: ctx.ac.ink),
            decoration: const InputDecoration(hintText: 'What it is', counterText: ''),
            onChanged: (v) => set(() => title = v),
          ),
          const SizedBox(height: Sp.x3),
          AllySegmented<String>(
            options: const {'GOAL': 'Goal', 'TASK': 'To-do', 'HABIT': 'Routine'},
            value: kind,
            onChanged: (k) => set(() => kind = k),
          ),
          if (kind == 'TASK') ...[
            const SizedBox(height: Sp.x4),
            WhenPicker(
              initial: when,
              onChanged: (w, ok) => set(() {
                when = w;
                whenOk = ok;
              }),
            ),
          ],
          const SizedBox(height: Sp.x4),
          Text('AREA', style: AllyType.eyebrow(color: ctx.ac.faint)),
          const SizedBox(height: Sp.x2),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            for (final a in d.areas) AllyChip(a.name, selected: a.name == area, onTap: () => set(() => area = a.name)),
          ]),
          const SizedBox(height: Sp.x3),
          Row(children: [
            Expanded(
              child: TextField(
                maxLength: 60,
                style: AllyType.body(color: ctx.ac.ink),
                decoration: const InputDecoration(hintText: 'Or a new area', counterText: ''),
                onChanged: (v) => newArea = v,
              ),
            ),
            IconButton(
                tooltip: 'Move to the new area',
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: () {
                  if (newArea.trim().isNotEmpty) area = newArea.trim();
                  Navigator.of(ctx).pop('done');
                }),
          ]),
          const SizedBox(height: Sp.x3),
          AllyButton('Done', wide: true, onPressed: title.trim().isEmpty || !whenOk ? null : () => Navigator.of(ctx).pop('done')),
          AllyButton('Remove', kind: AllyButtonKind.ghost, wide: true, onPressed: () => Navigator.of(ctx).pop('remove')),
        ]),
      ),
    );
    if (result == null) return;
    setState(() {
      if (result == 'remove') {
        d.removeItem(item);
        return;
      }
      if (title.trim().isNotEmpty) item.title = title.trim();
      item.kind = kind;
      if (kind == 'TASK') {
        item
          ..due = when.day
          ..dueKind = when.day == null ? null : when.kind
          ..windowFrom = when.from
          ..windowTo = when.to;
      }
      if (area != item.areaName) d.moveItem(item, area);
    });
    await d.save();
  }

  // ---- step 3: your normal week ----

  List<Widget> _week(AllyColors c, Widget? err) {
    Widget group(String label, List<String> options, int value, ValueChanged<int> onPick) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(label, style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x2),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            for (var i = 0; i < options.length; i++)
              AllyChip(options[i], selected: value == i, onTap: () => setState(() {
                    onPick(i);
                    _weekSet = false;
                  })),
          ]),
        ]);
    final noWork = workDayChoices[_days].$2.isEmpty;
    return [
      Text('Your normal week', style: AllyType.h1(color: c.ink)),
      Text('So Ally only plans into time that is really yours.', style: AllyType.body(color: c.muted)),
      group('WORK DAYS', [for (final x in workDayChoices) x.$1], _days, (i) => _days = i),
      if (!noWork) group('WORK HOURS, INCLUDING TRAVEL', [for (final x in workHourChoices) x.$1], _hours, (i) => _hours = i),
      group('YOU WAKE AROUND', [for (final x in wakeChoices) x.$1], _wake, (i) => _wake = i),
      group('YOU SLEEP AROUND', [for (final x in sleepChoices) x.$1], _sleep, (i) => _sleep = i),
      if (_weekSet && d.freeMinutes > 0)
        AllyCard(
          strong: true,
          child: Text('That leaves about ${minutesLabel(d.freeMinutes)} a week that is yours.', style: AllyType.h2(color: c.ink)),
        ),
      ?err,
    ];
  }

  // ---- step 4: a mode for each area ----

  List<Widget> _modes(BuildContext themed, AllyColors c, Widget? err) {
    final need = neededMinutes(d.areas);
    final free = d.freeMinutes;
    return [
      Text('A mode for each area', style: AllyType.h1(color: c.ink)),
      Text("Ally's suggestion. Change anything; modes change any time.", style: AllyType.body(color: c.muted)),
      AllyCard(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x1),
        child: Column(children: [
          for (var k = 0; k < d.areas.length; k++) ...[
            if (k > 0) Divider(color: c.line, height: 1),
            Pressable(
              scale: 0.985,
              onTap: () => _pickMode(themed, d.areas[k]),
              semanticLabel: '${d.areas[k].name}: ${AreaMode.fromName(d.areas[k].mode).label}. Change',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.x3),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AreaLabel(d.areas[k].name, color: c.area(k)),
                      const SizedBox(height: 2),
                      Text(d.areas[k].reason, style: AllyType.small(color: c.muted)),
                    ]),
                  ),
                  const SizedBox(width: Sp.x2),
                  ModeTag(AreaMode.fromName(d.areas[k].mode).label),
                ]),
              ),
            ),
          ],
        ]),
      ),
      Text(
        free > 0 ? 'About ${minutesLabel(need)} a week to start, of about ${minutesLabel(free)} free.' : 'About ${minutesLabel(need)} a week to start.',
        style: AllyType.body(color: c.ink),
      ),
      if (free > 0 && need > free) const AllyNote('That is more than your free time. Fine to start; Ally keeps the rest light and you can rest an area any time.'),
      ?err,
    ];
  }

  Future<void> _pickMode(BuildContext themed, FrArea a) async {
    final pushes = d.areas.where((x) => x.mode == 'PUSH' && x != a).length;
    final m = await showAllySheet<AreaMode>(
      themed,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(a.name, style: AllyType.h2(color: ctx.ac.ink)),
        const SizedBox(height: Sp.x3),
        for (final mode in AreaMode.values) ...[
          AllyCard(
            strong: mode.name.toUpperCase() == a.mode,
            onTap: () => Navigator.of(ctx).pop(mode),
            padding: const EdgeInsets.all(Sp.x4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mode.label, style: AllyType.body(color: ctx.ac.ink, w: FontWeight.w600)),
              Text(mode == AreaMode.push && pushes >= maxPush ? '${mode.meaning} Two areas already push; one moves to Maintain.' : mode.meaning,
                  style: AllyType.small(color: ctx.ac.muted)),
            ]),
          ),
          const SizedBox(height: Sp.x2),
        ],
      ]),
    );
    if (m == null) return;
    setState(() {
      final to = m.name.toUpperCase();
      // Push holds two at a time: the oldest other Push steps down to Maintain.
      if (to == 'PUSH' && pushes >= maxPush) d.areas.firstWhere((x) => x.mode == 'PUSH' && x != a).mode = 'MAINTAIN';
      a.mode = to;
      a.reason = m.meaning;
    });
    await d.save();
  }

  // ---- step 5: draft plan and step one ----

  List<Widget> _planStep(AllyColors c, Widget? err) {
    final plan = _plan;
    if (plan == null && (_busy || !_planTried)) {
      return [Text('Drafting your first plan…', style: AllyType.h1(color: c.ink)), const AllySkeleton(height: 200, radius: Rad.card)];
    }
    if (plan == null) {
      return [
        Text('Your areas are set', style: AllyType.h1(color: c.ink)),
        Text('Open any area to make a goal concrete when you are ready.', style: AllyType.body(color: c.muted)),
        ?err,
        AllyButton('Continue', wide: true, onPressed: () => _go(5)),
      ];
    }
    final milestones = ((plan['milestones'] as List?) ?? const []).map((e) => '$e').where((e) => e.isNotEmpty).toList();
    final steps = ((plan['steps'] as List?) ?? const []).whereType<Json>().toList();
    final first = steps.firstOrNull;
    return [
      Text('${_planAreaName ?? 'Your goal'} · draft 1', style: AllyType.h1(color: c.ink)),
      Text('Good enough to start. It gets better as you go.', style: AllyType.body(color: c.muted)),
      Text(asString(plan['title']), style: AllyType.h2(color: c.ink)),
      if (milestones.isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('MILESTONES', style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x1),
          Text('Small goals of one to four weeks. Change any of them; step one is for the first.', style: AllyType.small(color: c.muted)),
          const SizedBox(height: Sp.x2),
          // Keyed by the draft; what is saved is what is shown here.
          MilestoneEditor(key: ObjectKey(plan), initial: milestones, onChanged: (m) => plan['milestones'] = m),
        ]),
      if (first != null)
        AllyCard(
          strong: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('STEP ONE · ${asInt(first['minutes'], 15)} MIN', style: AllyType.eyebrow(color: c.faint)),
            const SizedBox(height: Sp.x1),
            Text(asString(first['title']), style: AllyType.h2(color: c.ink)),
          ]),
        ),
      ?err,
      AllyButton('Start step one now', wide: true, onPressed: _busy ? null : () => _keepPlan(startNow: true)),
      AllyButton('Keep it, start later', kind: AllyButtonKind.secondary, wide: true, onPressed: _busy ? null : () => _keepPlan(startNow: false)),
    ];
  }
}
