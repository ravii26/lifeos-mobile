import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/user.dart';
import '../../data/repositories/life_repository.dart';
import '../areas/areas_screen.dart';
import '../auth/bloc/auth_bloc.dart';
import '../chat/memories_screen.dart';
import '../chat/starters.dart';
import '../guide/guide_setup_sheet.dart';
import '../guide/guide_style.dart';
import '../more/reminders_check_screen.dart';
import '../more/settings_screen.dart';
import '../more/your_day_screen.dart';
import '../more/where_you_stand_screen.dart';
import '../shell/life_cubit.dart';
import 'now_cubit.dart';

/// You: how this week is going, your goals, what you keep doing, parts of your
/// life and settings. Sections appear only when they have something real in them.
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
  int? _kept;
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
        _repo.keptThisWeek(),
      ]);
      if (!mounted) return;
      setState(() {
        _projects = results[0] as List<Map<String, dynamic>>;
        _mode = results[1] as String;
        _kept = results[2] as int;
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
                    Text('Your goals, your week, your settings', style: G.label(size: 11, color: G.faint)),
                  ]),
                ]),
              ]),
              const SizedBox(height: 14),

              // How this week is going: changes how much Ally asks of you.
              Text("How's this week?", style: G.text(15, w: FontWeight.w600)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final (mode, label) in const [('NORMAL', 'Normal'), ('BUSY', 'Busy'), ('SICK', 'Sick'), ('TRAVEL', 'Travelling')]) ...[
                    _ModePill(label: label, active: _mode == mode, onTap: () => _changeMode(mode)),
                    const SizedBox(width: 6),
                  ],
                ]),
              ),
              const SizedBox(height: 6),
              Text(
                switch (_mode) {
                  'SICK' => 'No reminders or suggestions. Just rest.',
                  'BUSY' => 'Only the smallest version of each thing until you switch back.',
                  'TRAVEL' || 'HOLIDAY' => 'Reminders and suggestions are paused while you are away.',
                  _ => 'Ally suggests things as usual.',
                },
                style: G.text(12.5, color: G.muted),
              ),
              const SizedBox(height: 16),
              Container(height: 0.5, color: G.lineSoft),
              const SizedBox(height: 14),

              if (_error != null) Text(_error!, style: G.label(size: 12, color: Colors.redAccent)),

              // This week: only once something was done. Nothing to lose here, it only adds up.
              if ((_kept ?? 0) > 0) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text('$_kept', style: G.numeral(36, color: G.ink)),
                  const SizedBox(width: 8),
                  Text(_kept == 1 ? 'thing done this week' : 'things done this week',
                      style: G.text(18, w: FontWeight.w500, color: G.ink)),
                ]),
                Text('Every Done, small version and habit counts.', style: G.text(13, color: G.muted)),
                const SizedBox(height: 18),
                Container(height: 0.5, color: G.lineSoft),
                const SizedBox(height: 14),
              ],

              // Your goals, or one way to start one.
              Text('Your goals', style: G.text(16, w: FontWeight.w600)),
              const SizedBox(height: 10),
              if (_projects.isEmpty) ...[
                Text('Your goals and how far along you are show up here.', style: G.text(13.5, color: G.muted)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => starterRequest.value = Starter.goal,
                    style: TextButton.styleFrom(minimumSize: const Size(0, 44), padding: EdgeInsets.zero),
                    icon: Icon(Icons.flag_outlined, size: 18, color: G.accent),
                    label: Text('Plan a goal', style: G.text(15, w: FontWeight.w600, color: G.accent)),
                  ),
                ),
              ],
              for (final p in _projects) ...[
                _ProjectProgressCard(project: p),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 14),
              Container(height: 0.5, color: G.lineSoft),
              const SizedBox(height: 14),

              // Habits you keep: only what the logs show, and only once there is something.
              BlocBuilder<LifeCubit, LifeState>(
                builder: (context, life) {
                  final proof = [
                    for (final h in life.habits)
                      if (h.history.where((d) => d).isNotEmpty) (h.title, h.history.where((d) => d).length, h.history.length),
                  ]..sort((a, b) => b.$2.compareTo(a.$2));
                  if (proof.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Habits you keep', style: G.text(16, w: FontWeight.w600)),
                    const SizedBox(height: 10),
                    for (final (title, done, days) in proof.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.check_circle_outline_rounded, size: 18, color: G.good),
                          const SizedBox(width: 10),
                          Expanded(child: Text('$title: done on $done of the last $days days.', style: G.text(14))),
                        ]),
                      ),
                    const SizedBox(height: 10),
                    Container(height: 0.5, color: G.lineSoft),
                    const SizedBox(height: 14),
                  ]);
                },
              ),

              // Parts of your life, most important first. Hidden until there are any.
              BlocBuilder<LifeCubit, LifeState>(
                builder: (context, life) {
                  const order = {'MAIN': 0, 'SECONDARY': 1, 'MAINTAIN': 2, 'LATER': 3};
                  final areas = life.areas.where((a) => a.isActive).toList()
                    ..sort((a, b) => (order[a.tier] ?? 9).compareTo(order[b.tier] ?? 9));
                  if (areas.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Parts of your life', style: G.text(16, w: FontWeight.w600)),
                      InkWell(
                        onTap: () => _push(AreasScreen(onOpenMore: () {}), title: 'Parts of your life'),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('Change', style: G.label(size: 12, color: G.accent, w: FontWeight.w600)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: G.card,
                        border: Border.all(color: G.lineSoft, width: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(children: [
                        for (var i = 0; i < areas.length; i++) ...[
                          if (i > 0) Container(height: 0.5, color: G.lineSoft),
                          _AreaRow(label: areas[i].name, tier: tierName(areas[i].tier), color: areas[i].color),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Container(height: 0.5, color: G.lineSoft),
                    const SizedBox(height: 14),
                  ]);
                },
              ),

              // Settings, in plain words.
              Text('Settings', style: G.text(16, w: FontWeight.w600)),
              const SizedBox(height: 4),
              if (_projects.isNotEmpty)
                _NavActionRow(
                  icon: Icons.auto_graph_rounded,
                  title: 'Goals in detail',
                  sub: 'How far along each goal is, and the pace',
                  onTap: () => _push(const WhereYouStandScreen()),
                ),
              _NavActionRow(
                icon: Icons.calendar_view_week_rounded,
                title: _loading ? 'Loading your week…' : 'Your week',
                sub: 'A short look back at the week, when you want it',
                onTap: _week,
              ),
              _NavActionRow(
                icon: Icons.schedule_rounded,
                title: 'Your day',
                sub: 'When you wake, work and sleep',
                onTap: () => _push(const YourDayScreen()),
              ),
              _NavActionRow(
                icon: Icons.psychology_outlined,
                title: 'What Ally remembers',
                sub: 'See, change or delete what you told Ally',
                onTap: () => _push(const MemoriesScreen()),
              ),
              _NavActionRow(
                icon: Icons.alarm_on_outlined,
                title: 'Reminders',
                sub: 'Check they arrive on time, or send a test',
                onTap: () => _push(const RemindersCheckScreen()),
              ),
              _NavActionRow(
                icon: Icons.notifications_none_rounded,
                title: 'Check-ins',
                sub: 'A short message from Ally at night or in the morning, if you want one',
                onTap: () => openGuideSetup(context),
              ),
              _NavActionRow(
                icon: Icons.settings_outlined,
                title: 'Account and data',
                sub: 'Profile, export or delete your data',
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
          Expanded(child: Text(title, style: G.text(15, w: FontWeight.w600, height: 1.3))),
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
        if (message.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(message, style: G.text(13, color: G.muted, height: 1.4)),
        ],
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

/// Area tiers in plain words (doc 17).
String tierName(String tier) => switch (tier) {
      'MAIN' => 'Most important',
      'SECONDARY' => 'Important',
      'MAINTAIN' => 'Keep going',
      'LATER' => 'Later',
      _ => tier,
    };
