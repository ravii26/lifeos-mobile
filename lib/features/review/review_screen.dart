import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/review.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import 'review_compose_screen.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Future<List<Review>> _future;
  final _repo = getIt<LifeRepository>();

  @override
  void initState() {
    super.initState();
    _future = _repo.reviews();
    // Behaviour signal — lets the coach nudge stale reviews.
    _repo.recordBehavior('REVIEW_OPENED').ignore();
  }

  void _reload() => setState(() => _future = _repo.reviews());

  Future<void> _compose() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ReviewComposeScreen()),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.accentInk,
        onPressed: _compose,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('New review'),
      ),
      body: FutureBuilder<List<Review>>(
        future: _future,
        builder: (context, snap) {
          final reviews = snap.data ?? const [];
          final latest = reviews.isNotEmpty ? reviews.first : null;
          final insights = latest?.insights
                  .where((i) => i.status == 'PENDING')
                  .toList() ??
              const [];
          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const BackHeader(eyebrow: 'Insights', title: 'Weekly Review'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Eyebrow('Week of ${_weekLabel()}'),
                          const SizedBox(height: 6),
                          Text(
                              insights.isNotEmpty
                                  ? '${insights.length} insights to integrate'
                                  : 'All caught up',
                              style: GoogleFonts.hankenGrotesk(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                              'Reflect on each, then mark it implemented to lock it into your system.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12.5, color: AppColors.tx3)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (snap.connectionState != ConnectionState.done)
                      Padding(
                        padding: EdgeInsets.only(top: 30),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.accent)),
                      )
                    else if (insights.isEmpty)
                      const GlassCard(
                        padding: EdgeInsets.all(30),
                        child: Column(children: [
                          Text('✓', style: TextStyle(fontSize: 30)),
                          SizedBox(height: 6),
                          Text('Review complete',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                      )
                    else
                      for (final ins in insights)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _InsightCard(
                            insight: ins,
                            onResolved: _reload,
                            repo: _repo,
                          ),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _weekLabel() {
    final d = DateTime.now();
    return '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.day}';
  }
}

class _InsightCard extends StatefulWidget {
  final ReviewInsight insight;
  final VoidCallback onResolved;
  final LifeRepository repo;
  const _InsightCard(
      {required this.insight, required this.onResolved, required this.repo});

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard> {
  bool _open = false;
  bool _busy = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _resolve(String status) async {
    setState(() => _busy = true);
    await widget.repo.updateInsight(widget.insight.id,
        status: status, userNote: _note.text.trim());
    widget.onResolved();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.insight.text,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, height: 1.35)),
          const SizedBox(height: 12),
          if (!_open)
            OutlinedButton.icon(
              onPressed: () => setState(() => _open = true),
              icon: const Icon(Icons.edit_note, size: 16),
              label: const Text('Reflect'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                foregroundColor: AppColors.tx,
                side: BorderSide(color: AppColors.line2),
              ),
            )
          else ...[
            TextField(
              controller: _note,
              maxLines: 3,
              autofocus: true,
              style: TextStyle(fontSize: 14, color: AppColors.tx),
              decoration: const InputDecoration(
                  hintText: 'What will you change?'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _busy ? null : () => _resolve('STILL_WORKING'),
                    child: const Text('Note only'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _resolve('IMPLEMENTED'),
                    icon: const Icon(Icons.check, size: 15),
                    label: const Text('Implemented'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentInk,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
