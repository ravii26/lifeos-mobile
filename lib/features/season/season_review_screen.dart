import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/season.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';
import 'season_setup_cubit.dart' show NextSeason;
import 'season_setup_screen.dart';

/// What the review ended in, for the screen that opened it.
typedef ReviewResult = ({String message, String? undoId});

/// Opens the season-end review (canvas board P1·F). Returns what happened,
/// or null when the person just looked and went back.
Future<ReviewResult?> openSeasonReview(BuildContext context) =>
    Navigator.of(context).push<ReviewResult?>(MaterialPageRoute(builder: (_) => const SeasonReviewScreen()));

/// The next season's picks: parked areas brought back fill free focus slots
/// first, then Keep going; anything past the caps waits in the background.
NextSeason nextWithBroughtBack(SeasonReview r, List<String> broughtBack, {int maxFocus = 2, int maxKeepGoing = 3}) {
  final focus = [...r.nextFocusIds];
  final keep = [...r.nextKeepGoingIds];
  for (final id in broughtBack) {
    if (focus.contains(id) || keep.contains(id)) continue;
    if (focus.length < maxFocus) {
      focus.add(id);
    } else if (keep.length < maxKeepGoing) {
      keep.add(id);
    }
  }
  return (focusIds: focus, keepGoingIds: keep);
}

enum _Step { done, waiting }

/// Two screens, then the usual setup for the next season:
/// 1. What this season did: plain totals; if it had an end event, "did it
///    happen?", and "not yet" offers to carry it on or change the plan.
/// 2. What's waiting: parked areas come back as options, with a light first
///    week if there is a plan to make lighter.
class SeasonReviewScreen extends StatefulWidget {
  const SeasonReviewScreen({super.key});

  @override
  State<SeasonReviewScreen> createState() => _SeasonReviewScreenState();
}

class _SeasonReviewScreenState extends State<SeasonReviewScreen> {
  final _repo = getIt<LifeRepository>();
  SeasonReview? _review;
  String? _error;
  bool _busy = false;
  _Step _step = _Step.done;
  bool? _happened; // the end event: null = not answered
  final _brought = <String>[];
  bool _lightWeek = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await _repo.seasonReview();
      if (mounted) setState(() => _review = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _carryOn() async {
    setState(() => _busy = true);
    try {
      final r = await _repo.extendSeason(4);
      if (!mounted) return;
      Navigator.of(context).pop<ReviewResult>((message: 'Carried on: 4 more weeks, same plan.', undoId: r.activityId));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickNext() async {
    final r = _review!;
    final undoId = await openSeasonSetup(context, next: nextWithBroughtBack(r, _brought));
    if (!mounted || undoId == null) return;
    var message = 'Season ${r.nextNumber} started.';
    if (_lightWeek) {
      try {
        final light = await _repo.restartPlan(lightWeek: true);
        message = '$message ${light.message}';
      } on ApiException {
        message = "$message I couldn't make this week lighter, so the plan stays as it was.";
      }
    }
    if (mounted) Navigator.of(context).pop<ReviewResult>((message: message, undoId: undoId.isEmpty ? null : undoId));
  }

  @override
  Widget build(BuildContext context) {
    final r = _review;
    Widget body;
    if (_error != null) {
      body = _Center(text: "I can't open the review right now.\n$_error", action: 'Try again', onAction: _load);
    } else if (r == null) {
      body = _Center(text: 'Adding up your season…');
    } else {
      body = _step == _Step.done ? _done(r) : _waiting(r);
    }
    return Scaffold(
      backgroundColor: G.bg,
      appBar: AppBar(
        backgroundColor: G.bg,
        surfaceTintColor: G.bg,
        foregroundColor: G.ink,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _step == _Step.waiting ? setState(() => _step = _Step.done) : Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(top: false, child: body),
    );
  }

  Widget _done(SeasonReview r) {
    final s = r.season;
    final event = (s.endEvent ?? '').trim();
    final focus = r.areas.where((a) => a.place == 'FOCUS').toList();
    final keep = r.areas.where((a) => a.place != 'FOCUS').toList();
    return ListView(padding: const EdgeInsets.fromLTRB(22, 4, 22, 24), children: [
      Text(s.over ? '${s.title} is over' : 'Wrapping up ${s.title}', style: G.text(32, w: FontWeight.w600, height: 1.1, letterSpacing: -0.6)),
      const SizedBox(height: 6),
      Text(s.over ? 'Week ${s.weeks} of ${s.weeks}' : 'Week ${s.week} of ${s.weeks}. Ending early is fine.', style: G.text(16, color: G.muted)),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(color: G.accent, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WHAT THIS SEASON DID', style: G.text(12, w: FontWeight.w600, color: G.onInk, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          for (final l in r.lines) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l, style: G.text(18, color: G.onInk, height: 1.35))),
        ]),
      ),
      if (focus.isNotEmpty || keep.isNotEmpty) ...[
        const SizedBox(height: 14),
        for (final a in [...focus, ...keep])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(child: Text(a.name, style: G.text(17, color: a.place == 'FOCUS' ? G.ink : G.muted))),
              Text(a.done == 0 ? 'nothing logged' : '${a.done} done', style: G.text(15, color: G.muted)),
            ]),
          ),
      ],
      const SizedBox(height: 18),
      if (event.isNotEmpty && _happened == null) ...[
        Text('Did this happen: "$event"?', style: G.text(19, w: FontWeight.w600, height: 1.3)),
        const SizedBox(height: 12),
        GPill('Yes, it happened', primary: true, onTap: () => setState(() => _step = _Step.waiting)),
        const SizedBox(height: 8),
        GPill('Not yet', onTap: () => setState(() => _happened = false)),
      ] else if (_happened == false || (event.isEmpty && s.over)) ...[
        Text(_happened == false ? 'Not yet. Carry it on, or change the plan?' : 'Carry it on, or start the next season?', style: G.text(19, w: FontWeight.w600, height: 1.3)),
        const SizedBox(height: 12),
        GPill(_busy ? 'Saving…' : 'Carry it on: 4 more weeks', primary: true, onTap: _busy ? null : _carryOn),
        const SizedBox(height: 8),
        GPill(_happened == false ? 'Change the plan' : 'Start the next season', onTap: () => setState(() => _step = _Step.waiting)),
      ] else
        GPill("What's waiting", primary: true, onTap: () => setState(() => _step = _Step.waiting)),
    ]);
  }

  Widget _waiting(SeasonReview r) {
    return ListView(padding: const EdgeInsets.fromLTRB(22, 4, 22, 24), children: [
      Text("What's waiting", style: G.text(32, w: FontWeight.w600, height: 1.1, letterSpacing: -0.6)),
      const SizedBox(height: 6),
      Text(
        r.parked.isEmpty ? 'Nothing is parked. Next you pick what Season ${r.nextNumber} is about.' : 'Parked areas can come back now. Tap any you want in Season ${r.nextNumber}.',
        style: G.text(16, color: G.muted, height: 1.35),
      ),
      const SizedBox(height: 16),
      for (final p in r.parked)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: _brought.contains(p.id) ? G.accent : G.card,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _brought.contains(p.id) ? _brought.remove(p.id) : _brought.add(p.id)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: G.text(17, w: FontWeight.w600, color: _brought.contains(p.id) ? G.onInk : G.ink)),
                      Text(p.why, style: G.text(14, color: _brought.contains(p.id) ? G.onInk : G.muted)),
                    ]),
                  ),
                  Text(_brought.contains(p.id) ? 'Bring back ✓' : 'Bring back', style: G.text(14, w: FontWeight.w600, color: _brought.contains(p.id) ? G.onInk : G.accent)),
                ]),
              ),
            ),
          ),
        ),
      if (r.canLightWeek) ...[
        const SizedBox(height: 8),
        Material(
          color: G.card,
          borderRadius: BorderRadius.circular(18),
          child: SwitchListTile(
            value: _lightWeek,
            onChanged: (v) => setState(() => _lightWeek = v),
            title: Text('Start with a light week', style: G.text(17)),
            subtitle: Text('Shorter sessions, fewer days, then back to normal.', style: G.text(14, color: G.muted)),
          ),
        ),
      ],
      const SizedBox(height: 10),
      Text('Anything still in focus with a plan carries on where it is. It never starts over.', style: G.text(14, color: G.faint, height: 1.35)),
      const SizedBox(height: 18),
      GPill('Pick Season ${r.nextNumber}', primary: true, onTap: _pickNext),
    ]);
  }
}

class _Center extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const _Center({required this.text, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(text, textAlign: TextAlign.center, style: G.text(20, color: G.muted, height: 1.4)),
          if (action != null) ...[const SizedBox(height: 20), GPill(action!, primary: true, onTap: onAction)],
        ]),
      );
}
