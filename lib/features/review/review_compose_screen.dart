import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/review.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';

/// Create a review. "Generate draft" pulls a pre-filled draft from the period's
/// real data (completed tasks, habit check-ins, focus minutes, area scores,
/// goal confidence) plus an AI narrative, which the user edits before saving.
class ReviewComposeScreen extends StatefulWidget {
  const ReviewComposeScreen({super.key});

  @override
  State<ReviewComposeScreen> createState() => _ReviewComposeScreenState();
}

class _ReviewComposeScreenState extends State<ReviewComposeScreen> {
  final _repo = getIt<LifeRepository>();
  static const _types = ['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'];

  String _type = 'WEEKLY';
  bool _drafting = false;
  bool _saving = false;
  ReviewDraft? _draft;

  final _summary = TextEditingController();
  final _highlights = TextEditingController();
  final _improvements = TextEditingController();

  @override
  void dispose() {
    _summary.dispose();
    _highlights.dispose();
    _improvements.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.surface4,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _generate() async {
    setState(() => _drafting = true);
    try {
      final d = await _repo.reviewDraft(_type);
      if (!mounted) return;
      setState(() {
        _draft = d;
        _summary.text = d.suggestedSummary;
        _highlights.text = d.suggestedHighlights;
        _improvements.text = d.suggestedImprovements;
      });
    } catch (_) {
      _snack('Could not generate a draft', error: true);
    } finally {
      if (mounted) setState(() => _drafting = false);
    }
  }

  ({DateTime start, DateTime end}) _period() {
    final d = _draft;
    if (d != null && d.periodStart != null && d.periodEnd != null) {
      return (start: d.periodStart!, end: d.periodEnd!);
    }
    // Fallback window mirroring the server (covers `days` incl. today).
    const days = {'DAILY': 1, 'WEEKLY': 7, 'MONTHLY': 30, 'YEARLY': 365};
    final end = DateTime.now();
    final start = DateTime(end.year, end.month, end.day)
        .subtract(Duration(days: (days[_type] ?? 7) - 1));
    return (start: start, end: end);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final p = _period();
      await _repo.createReview(
        reviewType: _type,
        periodStart: p.start,
        periodEnd: p.end,
        summary: _summary.text.trim(),
        highlights: _highlights.text.trim(),
        improvements: _improvements.text.trim(),
        // Persist the AI narrative exactly as generated.
        aiInsights: _draft?.aiInsightsRaw,
      );
      if (!mounted) return;
      _snack('Review saved ✓');
      Navigator.of(context).pop(true);
    } catch (_) {
      _snack('Could not save the review', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = _draft?.aiInsights;
    final stats = _draft?.stats;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const BackHeader(eyebrow: 'Reflect', title: 'New review'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period selector
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _types.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final t = _types[i];
                      final on = _type == t;
                      return GestureDetector(
                        onTap: () => setState(() => _type = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: on ? AppColors.accent : AppColors.surface2,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    on ? Colors.transparent : AppColors.line),
                          ),
                          child: Text(_label(t),
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: on
                                      ? AppColors.accentInk
                                      : AppColors.tx2)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _drafting ? null : _generate,
                    icon: _drafting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.accent))
                        : const Icon(Icons.auto_awesome, size: 17),
                    label: Text(_draft == null
                        ? 'Generate draft from your data'
                        : 'Regenerate draft'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: BorderSide(color: AppColors.accentSoft),
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                ),

                // Stats strip + AI narrative
                if (stats != null) ...[
                  const SizedBox(height: 14),
                  _statsCard(stats),
                ],
                if (ai != null && ai.narrative.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _aiCard(ai),
                ],

                const SizedBox(height: 18),
                _field('Summary', _summary, hint: 'How did the period go?'),
                const SizedBox(height: 14),
                _field('Highlights', _highlights,
                    hint: 'Wins worth remembering'),
                const SizedBox(height: 14),
                _field('Improvements', _improvements,
                    hint: 'What to adjust next period'),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: AppColors.accentInk))
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Save review'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentInk,
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsCard(ReviewStats s) => SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow('This period'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip3('${s.tasksCompleted} tasks', icon: Icons.check_circle),
                Chip3('${s.habitsLogged} check-ins', icon: Icons.repeat),
                if (s.focusMinutes > 0)
                  Chip3('${s.focusMinutes}m focus', icon: Icons.timer_outlined),
                for (final st in s.topStreaks)
                  if (st.streak > 0)
                    Chip3('${st.title} ${st.streak}d',
                        icon: Icons.local_fire_department),
              ],
            ),
          ],
        ),
      );

  Widget _aiCard(ReviewAiInsights ai) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.auto_awesome, size: 15, color: AppColors.accent),
              const SizedBox(width: 7),
              Eyebrow(ai.source == 'ai' ? 'Coach reflection' : 'Reflection'),
            ]),
            const SizedBox(height: 8),
            Text(ai.narrative,
                style: TextStyle(
                    fontSize: 13.5, height: 1.5, color: AppColors.tx2)),
            if (ai.observations.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final o in ai.observations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle)),
                      ),
                      Expanded(
                        child: Text(o,
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: AppColors.tx3)),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );

  Widget _field(String label, TextEditingController c, {required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5, letterSpacing: 0.6, color: AppColors.tx4)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.inset,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            controller: c,
            maxLines: null,
            minLines: 2,
            style: TextStyle(fontSize: 14.5, color: AppColors.tx, height: 1.4),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              hintText: hint,
            ),
          ),
        ),
      ],
    );
  }

  static String _label(String t) => t[0] + t.substring(1).toLowerCase();
}
