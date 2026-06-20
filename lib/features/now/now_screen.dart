import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/decision.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import '../shell/life_cubit.dart';

class NowScreen extends StatefulWidget {
  const NowScreen({super.key});

  @override
  State<NowScreen> createState() => _NowScreenState();
}

class _NowScreenState extends State<NowScreen> {
  late Future<DecisionResult> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<LifeRepository>().decisionsNow();
  }

  void _reload() =>
      setState(() => _future = getIt<LifeRepository>().decisionsNow());

  /// Light-touch actions: complete a task or log a habit, then refresh.
  Future<void> _act(String type, String? refId) async {
    if (refId == null) return;
    final life = context.read<LifeCubit>();
    if (type == 'TASK') {
      await life.completeTask(refId);
    } else if (type == 'HABIT') {
      final h = life.state.habits.where((x) => x.id == refId);
      if (h.isNotEmpty) await life.logHabit(h.first);
    } else {
      return;
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surface2,
        onRefresh: () async => _reload(),
        child: FutureBuilder<DecisionResult>(
          future: _future,
          builder: (context, snap) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 60),
              children: [
                BackHeader(
                    eyebrow: 'Decision engine',
                    title: 'What now',
                    color: AppColors.accent),
                if (snap.connectionState != ConnectionState.done)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accent)),
                  )
                else if (snap.hasError)
                  _error(snap.error.toString())
                else
                  ..._content(snap.data!),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _error(String msg) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
        child: SurfaceCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Text('Could not load your briefing.',
                  style: TextStyle(color: AppColors.tx2, fontSize: 14)),
              const SizedBox(height: 6),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.tx4, fontSize: 12)),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _reload,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentInk),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  List<Widget> _content(DecisionResult d) {
    final tone = _tone(d.tone);
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Headline + tone emoji
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tone.$2, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(d.headline,
                      style: GoogleFonts.hankenGrotesk(
                          fontSize: 22,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tx)),
                ),
              ],
            ),
            if (d.briefing.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(d.briefing,
                  style: TextStyle(
                      fontSize: 13.5, height: 1.5, color: AppColors.tx2)),
            ],
            const SizedBox(height: 16),

            // Hero primary action
            if (d.primaryAction != null) _primaryCard(d.primaryAction!, tone.$1),

            // Streak alerts
            if (d.streakAlerts.isNotEmpty) ...[
              const SizedBox(height: 18),
              SectionHeader('Streaks at risk'),
              const SizedBox(height: 8),
              for (final s in d.streakAlerts) _streakCard(s),
            ],

            // Neglected area
            if (d.neglectedArea != null) ...[
              const SizedBox(height: 18),
              _neglectedCard(d.neglectedArea!),
            ],

            // Ranked suggestions
            if (d.suggestions.isNotEmpty) ...[
              const SizedBox(height: 18),
              SectionHeader('Then consider'),
              const SizedBox(height: 8),
              for (final s in d.suggestions) _suggestionCard(s),
            ],

            // Coaching notes
            const SizedBox(height: 8),
            _infoRow(Icons.center_focus_strong, "Today's focus", d.todayFocus),
            _infoRow(Icons.insights, 'Behaviour', d.behaviorInsight),
            _infoRow(Icons.calendar_view_week, 'Weekly pattern', d.weeklyPattern),

            const SizedBox(height: 16),
            Center(
              child: Text(
                  d.source == 'ai' ? 'Generated by AI' : 'Heuristic briefing',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: AppColors.tx4)),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _primaryCard(PrimaryAction a, Color tone) {
    final actionable = a.refId != null && (a.type == 'TASK' || a.type == 'HABIT');
    return GlassCard(
      padding: const EdgeInsets.all(18),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tone.withValues(alpha: 0.16), AppColors.glassBg],
      ),
      borderColor: tone.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Eyebrow('The one thing'),
              const Spacer(),
              if (a.estimatedMinutes != null)
                Chip3('~${a.estimatedMinutes}m', icon: Icons.schedule),
            ],
          ),
          const SizedBox(height: 10),
          Text(a.title,
              style: GoogleFonts.hankenGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700, height: 1.2)),
          if (a.why.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(a.why,
                style: TextStyle(
                    fontSize: 13, height: 1.45, color: AppColors.tx2)),
          ],
          if (actionable) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _act(a.type, a.refId),
                icon: Icon(a.type == 'TASK' ? Icons.check : Icons.add, size: 18),
                label: Text(a.type == 'TASK' ? 'Mark done' : 'Log it'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentInk,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _streakCard(StreakAlert s) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0x1FFFB547),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x40FFB547)),
        ),
        child: Row(
          children: [
            Icon(Icons.local_fire_department, color: AppColors.warn, size: 20),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.title} · ${s.streakDays}d',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(s.message,
                      style: TextStyle(fontSize: 12, color: AppColors.tx2)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _neglectedCard(NeglectedArea n) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Donut(
                value: n.score.toDouble(),
                size: 54,
                stroke: 5,
                color: AppColors.danger,
                center: Text('${n.score}',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 14, fontWeight: FontWeight.w600))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Eyebrow('Needs attention'),
                  ]),
                  const SizedBox(height: 3),
                  Text(n.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(n.insight,
                      style: TextStyle(
                          fontSize: 12.5, height: 1.4, color: AppColors.tx2)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _suggestionCard(Suggestion s) {
    final actionable = s.refId != null && (s.type == 'TASK' || s.type == 'HABIT');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.title,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              _urgencyTag(s.urgency),
            ],
          ),
          if (s.reason.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(s.reason,
                style: TextStyle(
                    fontSize: 12.5, height: 1.45, color: AppColors.tx2)),
          ],
          if (s.actionableSteps.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final step in s.actionableSteps)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5, right: 8),
                      child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle)),
                    ),
                    Expanded(
                      child: Text(step,
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: AppColors.tx3)),
                    ),
                  ],
                ),
              ),
          ],
          if (actionable) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _act(s.type, s.refId),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.accent,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                icon: Icon(s.type == 'TASK' ? Icons.check : Icons.add, size: 16),
                label: Text(s.type == 'TASK' ? 'Mark done' : 'Log it',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _urgencyTag(String u) {
    final (fg, bg, label) = switch (u) {
      'HIGH' => (const Color(0xFFFF8A8A), const Color(0x29FF5D62), 'High'),
      'MEDIUM' => (AppColors.warn, const Color(0x29FFB547), 'Medium'),
      _ => (AppColors.tx3, AppColors.surface3, 'Low'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: GoogleFonts.jetBrainsMono(
              fontSize: 9.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.tx4),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        letterSpacing: 0.6,
                        color: AppColors.tx4)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 13, height: 1.45, color: AppColors.tx2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tone → (accent colour, emoji).
  (Color, String) _tone(String tone) => switch (tone) {
        'firm' => (AppColors.danger, '🎯'),
        'celebratory' => (AppColors.accent, '🎉'),
        'encouraging' => (AppColors.health, '💪'),
        _ => (AppColors.career, '🧭'),
      };
}
