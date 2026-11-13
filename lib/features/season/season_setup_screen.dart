import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';
import '../shrink/shrink_cubit.dart' show hoursText;
import 'season_setup_cubit.dart';

/// Opens season setup. Returns the Undo id when a season was started.
Future<String?> openSeasonSetup(BuildContext context) => Navigator.of(context).push<String?>(MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => SeasonSetupCubit(getIt<LifeRepository>())..load(),
        child: const SeasonSetupScreen(),
      ),
    ));

const _placeLabel = {
  Place.focus: 'Focus',
  Place.keepGoing: 'Keep going',
  Place.background: 'Background',
  Place.parked: 'Parked',
};

const _placeHelp = {
  Place.focus: 'Gets your real time and the Now card',
  Place.keepGoing: 'Smallest versions only',
  Place.background: 'Only when there is room',
  Place.parked: 'Saved, never shown until you bring it back',
};

class SeasonSetupScreen extends StatelessWidget {
  const SeasonSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SeasonSetupCubit, SeasonSetupState>(
      listenWhen: (a, b) => a.status != b.status || (b.error != null && a.error != b.error),
      listener: (context, s) {
        if (s.status == SetupStatus.started) Navigator.of(context).pop(s.undoId ?? '');
        if (s.error != null && s.status == SetupStatus.ready) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.error!)));
        }
      },
      builder: (context, s) {
        final cubit = context.read<SeasonSetupCubit>();
        Widget body;
        if (s.status == SetupStatus.loading) {
          body = Center(child: Text('Adding up your week…', style: G.text(22, color: G.muted)));
        } else if (s.status == SetupStatus.error) {
          body = _Message(title: "I can't reach your areas right now.", body: s.error ?? '', action: 'Try again', onAction: cubit.load);
        } else if ((s.data?.areas ?? const []).isEmpty) {
          body = const _Message(
            title: 'No areas yet.',
            body: 'Tell Ally what matters to you first (a goal, a habit, anything). Your areas fill in from that, then you can pick a season.',
          );
        } else {
          body = switch (s.step) {
            SetupStep.explain => _Explain(onNext: () => cubit.go(SetupStep.areas)),
            SetupStep.areas => _Areas(state: s),
            SetupStep.pick => _Pick(state: s),
            SetupStep.name => _Name(state: s),
          };
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
              onPressed: () {
                final back = {SetupStep.pick: SetupStep.areas, SetupStep.name: SetupStep.pick}[s.step];
                if (back != null && s.status == SetupStatus.ready) {
                  cubit.go(back);
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
            title: Text('Season', style: G.text(20, w: FontWeight.w500, height: 1.2)),
          ),
          body: SafeArea(top: false, child: body),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  const _Message({required this.title, required this.body, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(22, 30, 22, 24), children: [
        Text(title, style: G.text(34, w: FontWeight.w600, height: 1.1, letterSpacing: -0.8)),
        const SizedBox(height: 12),
        Text(body, style: G.text(18, color: G.muted, height: 1.4)),
        if (action != null) ...[const SizedBox(height: 26), GPill(action!, primary: true, onTap: onAction)],
      ]);
}

class _Explain extends StatelessWidget {
  final VoidCallback onNext;
  const _Explain({required this.onNext});

  Widget _row(String n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: G.accent, shape: BoxShape.circle),
            child: Text(n, style: G.text(16, w: FontWeight.w600, color: G.onInk)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: G.text(18, height: 1.3))),
        ]),
      );

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 24), children: [
        Text('Too much at once?', style: G.text(38, w: FontWeight.w600, height: 1.08, letterSpacing: -1)),
        const SizedBox(height: 12),
        Text("Let's pick what this chapter of your life is about. Like a semester: a few subjects now, the rest later.",
            style: G.text(19, color: G.muted, height: 1.4)),
        const SizedBox(height: 26),
        _row('2', 'things get your real time'),
        _row('3', 'stay alive in small doses'),
        _row('∞', 'everything else waits, safely saved'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: G.accent, borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nothing is deleted', style: G.text(18, w: FontWeight.w600, color: G.onInk)),
            const SizedBox(height: 6),
            Text('When the chapter ends, you look back and pick the next one. Parked things come back as choices.',
                style: G.text(16, color: G.onInk, height: 1.35)),
          ]),
        ),
        const SizedBox(height: 26),
        GPill("Let's do it (2 min)", primary: true, onTap: onNext),
      ]);
}

class _Areas extends StatelessWidget {
  final SeasonSetupState state;
  const _Areas({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SeasonSetupCubit>();
    final areas = state.data!.areas;
    final need = state.neededMinutes, free = state.freeMinutes;
    final over = need > free;
    final most = need > free ? need : free;
    Widget bar(String label, int minutes, Color color) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(label, style: G.text(15, color: G.muted))),
              Text(hoursText(minutes), style: G.text(15, w: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: most == 0 ? 0 : minutes / most,
                minHeight: 10,
                backgroundColor: G.card,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ]),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(22, 8, 22, 24), children: [
      Text('You have ${areas.length} area${areas.length == 1 ? '' : 's'}. All of them need about ${hoursText(need)} a week.',
          style: G.text(28, w: FontWeight.w600, height: 1.15, letterSpacing: -0.5)),
      const SizedBox(height: 8),
      Text(over ? 'Not lazy, just too much at once. Let\'s choose.' : 'It fits, but let\'s make sure your time goes to what matters most.',
          style: G.text(17, color: G.muted, height: 1.35)),
      const SizedBox(height: 18),
      bar('What it would take', need, G.accent),
      bar('Your free time in a week', free, G.ink),
      const SizedBox(height: 8),
      for (final a in areas)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.name, style: G.text(17, height: 1.25)),
                if (state.guessed.contains(a.id)) Text('my guess: nothing planned yet', style: G.text(13, color: G.faint)),
              ]),
            ),
            IconButton(
              tooltip: 'Less time for ${a.name}',
              onPressed: () => cubit.setMinutes(a.id, -30),
              icon: Icon(Icons.remove_rounded, color: G.ink),
            ),
            SizedBox(width: 62, child: Text(hoursText(state.minutes[a.id] ?? 0).replaceAll(' hours', ' h').replaceAll(' hour', ' h'), textAlign: TextAlign.center, style: G.text(15, w: FontWeight.w600))),
            IconButton(
              tooltip: 'More time for ${a.name}',
              onPressed: () => cubit.setMinutes(a.id, 30),
              icon: Icon(Icons.add_rounded, color: G.ink),
            ),
          ]),
        ),
      const SizedBox(height: 6),
      Text('These are estimates from your goals, habits and to-dos. Change any of them.', style: G.text(14, color: G.faint, height: 1.35)),
      const SizedBox(height: 20),
      GPill('Choose what matters now', primary: true, onTap: () => cubit.go(SetupStep.pick)),
    ]);
  }
}

class _Pick extends StatelessWidget {
  final SeasonSetupState state;
  const _Pick({required this.state});

  Future<void> _choose(BuildContext context, String id) async {
    final cubit = context.read<SeasonSetupCubit>();
    final to = await showModalBottomSheet<Place>(
      context: context,
      backgroundColor: G.inset,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(state.nameOf(id), style: G.text(24, w: FontWeight.w600, height: 1.15)),
            const SizedBox(height: 12),
            for (final p in Place.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_placeLabel[p]!, style: G.text(18, w: FontWeight.w500)),
                subtitle: Text(_placeHelp[p]!, style: G.text(14, color: G.muted)),
                trailing: state.places[id] == p ? Icon(Icons.check_rounded, color: G.accent) : null,
                onTap: () => Navigator.of(context).pop(p),
              ),
          ]),
        ),
      ),
    );
    if (to != null) cubit.place(id, to);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SeasonSetupCubit>();
    final s = state;
    final focusCount = s.idsIn(Place.focus).length;
    return ListView(padding: const EdgeInsets.fromLTRB(22, 8, 22, 24), children: [
      Text('Which ${s.data!.maxFocus} get your real time this season?', style: G.text(28, w: FontWeight.w600, height: 1.15, letterSpacing: -0.5)),
      const SizedBox(height: 8),
      Text('I picked these. Tap any area to move it.', style: G.text(17, color: G.muted, height: 1.35)),
      const SizedBox(height: 16),
      if (s.swapFor != null) ...[
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: G.accent, borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.swapPlace == Place.focus ? 'Max ${s.data!.maxFocus} in focus' : 'Max ${s.data!.maxKeepGoing} kept going',
                style: G.text(18, w: FontWeight.w600, color: G.onInk)),
            const SizedBox(height: 6),
            Text('To add ${s.nameOf(s.swapFor!)}, which one makes room? It ${s.swapPlace == Place.focus ? 'gets parked' : 'moves to the background'}, not deleted.',
                style: G.text(16, color: G.onInk, height: 1.35)),
            const SizedBox(height: 12),
            for (final id in s.idsIn(s.swapPlace!))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => cubit.swap(id),
                    style: TextButton.styleFrom(backgroundColor: G.onInk, foregroundColor: G.ink, padding: const EdgeInsets.symmetric(vertical: 14), shape: const StadiumBorder()),
                    child: Text('Move ${s.nameOf(id)} out', style: G.text(16, w: FontWeight.w600)),
                  ),
                ),
              ),
            TextButton(onPressed: cubit.cancelSwap, child: Text('Keep as is', style: G.text(16, color: G.onInk))),
          ]),
        ),
        const SizedBox(height: 16),
      ],
      for (final p in Place.values) ...[
        if (s.idsIn(p).isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(_placeLabel[p]!.toUpperCase(), style: G.text(13, color: G.faint, letterSpacing: 0.8)),
          ),
          for (final id in s.idsIn(p))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: p == Place.focus ? G.surfaceHigh : G.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: p == Place.focus ? BorderSide(color: G.accent, width: 2) : BorderSide.none,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _choose(context, id),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                    child: Row(children: [
                      Expanded(child: Text(s.nameOf(id), style: G.text(17, height: 1.25))),
                      Text(hoursText(s.minutes[id] ?? 0), style: G.text(14, color: G.muted)),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded, color: G.faint),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ],
      const SizedBox(height: 14),
      GPill(focusCount == 0 ? 'Pick at least 1 focus' : 'Looks right', primary: true, onTap: focusCount == 0 ? null : () => cubit.go(SetupStep.name)),
    ]);
  }
}

class _Name extends StatefulWidget {
  final SeasonSetupState state;
  const _Name({required this.state});

  @override
  State<_Name> createState() => _NameState();
}

class _NameState extends State<_Name> {
  late final _name = TextEditingController(text: context.read<SeasonSetupCubit>().name);
  late final _event = TextEditingController(text: context.read<SeasonSetupCubit>().endEvent);

  @override
  void dispose() {
    _name.dispose();
    _event.dispose();
    super.dispose();
  }

  Widget _place(String title, List<String> ids, Color bg, Color fg, {bool dashed = false}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: dashed ? Border.all(color: G.faint) : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: G.text(12, w: FontWeight.w600, color: fg, letterSpacing: 0.6)),
          const SizedBox(height: 4),
          Text(ids.isEmpty ? 'Nothing' : ids.map(widget.state.nameOf).join(' · '), style: G.text(16, color: fg, height: 1.35)),
        ]),
      );

  InputDecoration _field(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: G.text(16, color: G.faint),
        filled: true,
        fillColor: G.inset,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: G.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: G.line)),
      );

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SeasonSetupCubit>();
    final s = widget.state;
    final number = (s.data?.season?.number ?? 0) + 1;
    return ListView(padding: const EdgeInsets.fromLTRB(22, 8, 22, 24), children: [
      Text('Season $number · name it (optional)', style: G.text(15, color: G.muted)),
      const SizedBox(height: 8),
      TextField(
        controller: _name,
        maxLength: 60,
        style: G.text(20, w: FontWeight.w600),
        decoration: _field('e.g. Switch & Shape'),
        onChanged: (v) => cubit.name = v,
      ),
      Text('Ends in 10 weeks, or earlier when this happens:', style: G.text(15, color: G.muted)),
      const SizedBox(height: 8),
      TextField(
        controller: _event,
        maxLength: 120,
        style: G.text(17),
        decoration: _field('e.g. when I switch jobs (optional)'),
        onChanged: (v) => cubit.endEvent = v,
      ),
      const SizedBox(height: 4),
      _place('Focus · most of your time', s.idsIn(Place.focus), G.accent, G.onInk),
      _place('Keep going · small versions', s.idsIn(Place.keepGoing), G.surfaceHigh, G.ink),
      if (s.idsIn(Place.background).isNotEmpty) _place('In the background', s.idsIn(Place.background), G.card, G.ink),
      _place('Parked · saved, never shown', s.idsIn(Place.parked), G.inset, G.muted, dashed: true),
      const SizedBox(height: 8),
      Text('Bills, birthdays and reminders keep running whatever you pick.', style: G.text(14, color: G.faint, height: 1.35)),
      const SizedBox(height: 20),
      GPill(s.status == SetupStatus.saving ? 'Starting…' : 'Start Season $number',
          primary: true, onTap: s.status == SetupStatus.saving ? null : cubit.start),
    ]);
  }
}
