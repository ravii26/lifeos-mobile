import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/user.dart';
import '../../data/repositories/life_repository.dart';
import '../areas/areas_screen.dart';
import '../auth/bloc/auth_bloc.dart';
import '../guide/guide_setup_sheet.dart';
import '../guide/guide_style.dart';
import '../more/settings_screen.dart';
import '../more/where_you_stand_screen.dart';
import '../shell/life_cubit.dart';
import 'now_cubit.dart';

/// You screen: where you stand, mode switcher, kept promises, identity evidence, and areas.
/// Styled according to Nocturne Sanctuary (ally_you_progress_where_you_stand design specification).
class YouScreen extends StatefulWidget {
  final AppUser user;
  const YouScreen({super.key, required this.user});

  @override
  State<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends State<YouScreen> {
  final _repo = getIt<LifeRepository>();
  List<Map<String, dynamic>> _projects = const [];
  String _mode = 'NORMAL';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    placesRefresh.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    placesRefresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repo.progress(),
        _repo.mode(),
      ]);
      if (!mounted) return;
      setState(() {
        _projects = results[0] as List<Map<String, dynamic>>;
        _mode = results[1] as String;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _changeMode(String mode) async {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    try {
      await _repo.setMode(mode);
      placesRefresh.value++;
    } catch (_) {}
  }

  void _push(Widget page, {String? title}) {
    final life = context.read<LifeCubit>();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: life,
        child: title == null
            ? page
            : Scaffold(
                backgroundColor: G.bg,
                appBar: AppBar(
                  backgroundColor: G.bg,
                  surfaceTintColor: G.bg,
                  foregroundColor: G.ink,
                  elevation: 0,
                  title: Text(title, style: G.voice(16, color: G.ink)),
                ),
                body: page,
              ),
      ),
    )).then((_) => _load());
  }

  // The weekly card is only ever shown when asked for.
  Future<void> _week() async {
    setState(() => _loading = true);
    String text;
    try {
      text = await _repo.weekCard();
    } on ApiException catch (e) {
      text = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: G.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: G.lineSoft, width: 0.5),
        ),
        title: Text('Your week', style: G.voice(20, color: G.ink)),
        content: Text(text, style: G.text(14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: G.label(size: 12, color: G.accent, w: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: G.bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
            children: [
              // Nocturne Top Bar
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Icon(Icons.bedtime_outlined, size: 20, color: G.accent),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('You', style: G.voice(16, color: G.ink)),
                    Text('Where you stand & personal trajectory', style: G.label(size: 11, color: G.faint)),
                  ]),
                ]),
              ]),
              const SizedBox(height: 14),

              // SECTION 1: MODE SELECTOR BANNER
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _ModePill(
                    label: 'Normal mode',
                    active: _mode == 'NORMAL',
                    onTap: () => _changeMode('NORMAL'),
                  ),
                  const SizedBox(width: 6),
                  _ModePill(
                    label: 'Busy week',
                    active: _mode == 'BUSY',
                    onTap: () => _changeMode('BUSY'),
                  ),
                  const SizedBox(width: 6),
                  _ModePill(
                    label: 'Sick / Rest',
                    active: _mode == 'SICK',
                    onTap: () => _changeMode('SICK'),
                  ),
                  const SizedBox(width: 6),
                  _ModePill(
                    label: 'Travel',
                    active: _mode == 'TRAVEL',
                    onTap: () => _changeMode('TRAVEL'),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  _mode == 'SICK'
                      ? 'Sick mode pauses all prompts instantly. Rest only, zero reminders.'
                      : _mode == 'BUSY'
                          ? 'Busy mode switches habits & to-dos to 2-minute smallest versions.'
                          : 'Normal quiet pacing active.',
                  style: G.label(size: 11, color: G.faint),
                ),
              ),
              const SizedBox(height: 16),
              Container(height: 0.5, color: G.lineSoft),
              const SizedBox(height: 14),

              // SECTION 2: KEPT PROMISES THIS WEEK (Headline Metric)
              Text('NO GUILT ACCUMULATOR', style: G.label(size: 10, color: G.accent, w: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('19', style: G.numeral(36, color: G.ink)),
                const SizedBox(width: 8),
                Text('kept promises', style: G.text(18, w: FontWeight.w500, color: G.ink)),
              ]),
              const SizedBox(height: 4),
              Text(
                'Morning routines · Focused work blocks · Evening wind-downs.',
                style: G.text(13, color: G.muted),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                decoration: BoxDecoration(
                  color: G.inset,
                  border: Border(left: BorderSide(color: G.accent, width: 2)),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
                ),
                child: Text(
                  '“Days without action do not subtract. Progress only accumulates.”',
                  style: G.voice(13, color: G.muted),
                ),
              ),
              const SizedBox(height: 18),
              Container(height: 0.5, color: G.lineSoft),
              const SizedBox(height: 14),

              // SECTION 3: WHERE YOU STAND (Linear Trajectories)
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Where you stand', style: G.text(16, w: FontWeight.w600)),
                Text('Paced linearity', style: G.label(size: 11, color: G.faint)),
              ]),
              const SizedBox(height: 10),

              if (_error != null)
                Text(_error!, style: G.label(size: 12, color: Colors.redAccent)),

              if (_projects.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: G.card,
                    border: Border.all(color: G.lineSoft, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'No active project trajectories yet. Tell Ally a goal in chat to track stages.',
                    style: G.voice(14, color: G.muted),
                  ),
                ),

              for (final p in _projects) ...[
                _ProjectProgressCard(project: p),
                const SizedBox(height: 10),
              ],

              const SizedBox(height: 14),
              Container(height: 0.5, color: G.lineSoft),
              const SizedBox(height: 14),

              // SECTION 4: IDENTITY EVIDENCE
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Identity Evidence', style: G.text(16, w: FontWeight.w600)),
                Text('Quiet proof', style: G.label(size: 11, color: G.faint)),
              ]),
              const SizedBox(height: 4),
              Text(
                'Quiet proof of who you are already becoming.',
                style: G.label(size: 11, color: G.faint),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: G.card,
                  border: Border.all(color: G.lineSoft, width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.edit_note_rounded, size: 18, color: G.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '“Showing up consistently across days without forced streaks.”',
                      style: G.voice(13.5, color: G.ink),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: G.card,
                  border: Border.all(color: G.lineSoft, width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.verified_outlined, size: 18, color: G.good),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '“18 gym sessions logged. No forced streaks, just showing up.”',
                      style: G.voice(13.5, color: G.ink),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Container(height: 0.5, color: G.lineSoft),
              const SizedBox(height: 14),

              // SECTION 5: LIFE AREAS & TIERS
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Life Areas & Tiers', style: G.text(16, w: FontWeight.w600)),
                InkWell(
                  onTap: () => _push(AreasScreen(onOpenMore: () {}), title: 'Areas'),
                  child: Text('Edit areas', style: G.label(size: 11, color: G.accent, w: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: G.card,
                  border: Border.all(color: G.lineSoft, width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(children: [
                  _AreaRow(label: 'Career', tier: 'Main tier · Signal accent', color: G.accent),
                  Container(height: 0.5, color: G.lineSoft),
                  _AreaRow(label: 'Health & Fitness', tier: 'Secondary', color: G.good),
                  Container(height: 0.5, color: G.lineSoft),
                  _AreaRow(label: 'Personal Finance & Investing', tier: 'Maintain', color: G.faint),
                ]),
              ),
              const SizedBox(height: 18),
              Container(height: 0.5, color: G.lineSoft),
              const SizedBox(height: 14),

              // SECTION 6: ACTIONS & SETTINGS
              Text('ACTIONS & SETTINGS', style: G.label(size: 10, color: G.faint, w: FontWeight.w600)),
              const SizedBox(height: 8),
              _NavActionRow(
                icon: Icons.auto_graph_rounded,
                title: 'Where you stand (Full view)',
                sub: 'Stage, trend and pace on each goal',
                onTap: () => _push(const WhereYouStandScreen()),
              ),
              _NavActionRow(
                icon: Icons.calendar_view_week_rounded,
                title: _loading ? 'Loading week…' : 'Your week card',
                sub: 'Only when you ask. Never on a schedule',
                onTap: _week,
              ),
              _NavActionRow(
                icon: Icons.notifications_none_rounded,
                title: 'Goals and nudges',
                sub: 'Set up what Ally may remind you about',
                onTap: () => openGuideSetup(context),
              ),
              _NavActionRow(
                icon: Icons.settings_outlined,
                title: 'Settings',
                sub: 'Profile and preferences',
                onTap: () => _push(SettingsScreen(user: widget.user)),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Icon(Icons.logout_rounded, size: 16, color: G.faint),
                    const SizedBox(width: 8),
                    Text('Sign out', style: G.label(size: 12, color: G.faint)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModePill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? G.surfaceHigh : G.card,
            border: Border.all(color: active ? G.accent.withValues(alpha: 0.6) : G.lineSoft, width: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(children: [
            if (active) ...[
              Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: G.accent)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: G.label(
                size: 11,
                color: active ? G.ink : G.muted,
                w: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ]),
        ),
      );
}

class _ProjectProgressCard extends StatelessWidget {
  final Map<String, dynamic> project;
  const _ProjectProgressCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final title = '${project['title']}';
    final kind = '${project['kind'] ?? 'MILESTONE'}';
    final message = '${project['message'] ?? ''}';
    final status = project['status'] == 'PAUSED';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: G.card,
        border: Border.all(color: G.lineSoft, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(kind == 'OUTCOME' ? 'OUTCOME PROJECT' : 'MILESTONE PROJECT',
              style: G.label(size: 10, color: G.accent, w: FontWeight.w600)),
          if (status)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: G.inset,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('Paused', style: G.label(size: 10, color: G.faint)),
            ),
        ]),
        const SizedBox(height: 6),
        Text(title, style: G.text(15, w: FontWeight.w600, height: 1.3)),
        const SizedBox(height: 6),
        if (message.isNotEmpty)
          Text(message, style: G.text(13, color: G.muted, height: 1.4)),
        const SizedBox(height: 10),
        // Flat Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 3,
            color: G.inset,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.42,
                child: Container(color: G.accent),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _AreaRow extends StatelessWidget {
  final String label;
  final String tier;
  final Color color;
  const _AreaRow({required this.label, required this.tier, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            const SizedBox(width: 10),
            Text(label, style: G.text(14, w: FontWeight.w500)),
          ]),
          Text(tier, style: G.label(size: 11, color: G.faint)),
        ]),
      );
}

class _NavActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _NavActionRow({required this.icon, required this.title, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            Icon(icon, size: 18, color: G.faint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: G.text(14, w: FontWeight.w500)),
                Text(sub, style: G.label(size: 11, color: G.faint)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: G.faint),
          ]),
        ),
      );
}
