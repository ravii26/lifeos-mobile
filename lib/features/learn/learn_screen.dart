import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/resource.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late Future<List<Resource>> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<LifeRepository>().resources();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FutureBuilder<List<Resource>>(
        future: _future,
        builder: (context, snap) {
          final all = snap.data ?? const [];
          final active = all.where((r) => r.progress < 1).toList();
          final cont = active.isNotEmpty ? active.first : null;
          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const BackHeader(eyebrow: 'Insights', title: 'Learn'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (snap.connectionState != ConnectionState.done)
                      Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.accent)),
                      )
                    else if (all.isEmpty)
                      SurfaceCard(
                        padding: EdgeInsets.all(26),
                        child: Center(
                            child: Text('No learning resources yet.',
                                style: TextStyle(
                                    color: AppColors.tx4, fontSize: 13))),
                      )
                    else ...[
                      if (cont != null) ...[
                        SectionHeader('Continue'),
                        const SizedBox(height: 10),
                        _continueCard(cont),
                        const SizedBox(height: 14),
                      ],
                      SectionHeader('All resources'),
                      const SizedBox(height: 10),
                      for (final r in all)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _resourceTile(r),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _continueCard(Resource r) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip3(r.platform ?? r.resourceType),
            const SizedBox(height: 10),
            Text(r.title,
                style: GoogleFonts.hankenGrotesk(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
                '${r.lessonsCompleted}/${r.totalLessons} lessons · ${(r.minutesConsumed / 60).round()}h',
                style: TextStyle(fontSize: 12, color: AppColors.tx3)),
            const SizedBox(height: 12),
            ProgressBar(r.progress),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.play_arrow, size: 16),
                label: Text('Resume lesson ${r.lessonsCompleted + 1}'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentInk,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _resourceTile(Resource r) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ProgressBar(r.progress),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('${(r.progress * 100).round()}%',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 11, color: AppColors.tx3)),
          ],
        ),
      );
}
