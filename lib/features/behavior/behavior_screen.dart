import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/behavior_log.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';

const _eventMeta = <String, (String, IconData)>{
  'APP_OPEN': ('App open', Icons.smartphone),
  'TASK_COMPLETED': ('Task done', Icons.check_circle_outline),
  'TASK_DEFERRED': ('Task deferred', Icons.update),
  'HABIT_LOGGED': ('Habit logged', Icons.local_fire_department),
  'CAPTURE_CREATED': ('Captured', Icons.bolt),
  'VAULT_ACCESSED': ('Vault opened', Icons.lock_open),
  'FOCUS_STARTED': ('Focus started', Icons.play_arrow),
  'FOCUS_COMPLETED': ('Focus done', Icons.timer),
  'FOCUS_ABANDONED': ('Focus dropped', Icons.stop_circle_outlined),
  'AREA_VIEWED': ('Area viewed', Icons.donut_large),
  'REVIEW_OPENED': ('Review opened', Icons.refresh),
};

class BehaviorScreen extends StatefulWidget {
  const BehaviorScreen({super.key});

  @override
  State<BehaviorScreen> createState() => _BehaviorScreenState();
}

class _BehaviorScreenState extends State<BehaviorScreen> {
  late Future<List<BehaviorLog>> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<LifeRepository>().behaviorLogs();
  }

  Future<void> _reload() async =>
      setState(() => _future = getIt<LifeRepository>().behaviorLogs());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surface2,
        onRefresh: _reload,
        child: FutureBuilder<List<BehaviorLog>>(
          future: _future,
          builder: (context, snap) {
            final logs = snap.data ?? const [];
            final counts = <String, int>{};
            for (final l in logs) {
              counts[l.eventType] = (counts[l.eventType] ?? 0) + 1;
            }
            final ranked = counts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final maxCount =
                ranked.isEmpty ? 1 : ranked.first.value;

            return ListView(
              padding: const EdgeInsets.only(bottom: 60),
              children: [
                BackHeader(eyebrow: 'Signals', title: 'Behaviour'),
                if (snap.connectionState != ConnectionState.done)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accent)),
                  )
                else if (logs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                    child: SurfaceCard(
                      padding: const EdgeInsets.all(26),
                      child: Center(
                          child: Text('No activity recorded yet.',
                              style: TextStyle(
                                  color: AppColors.tx4, fontSize: 13))),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${logs.length} events tracked',
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.tx3)),
                        const SizedBox(height: 14),
                        SectionHeader('By type'),
                        const SizedBox(height: 10),
                        GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              for (final e in ranked)
                                _bar(e.key, e.value, maxCount),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        SectionHeader('Recent'),
                        const SizedBox(height: 10),
                        for (final l in logs.take(40)) _logRow(l),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bar(String type, int count, int max) {
    final meta = _eventMeta[type] ?? (type, Icons.circle);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(meta.$2, size: 15, color: AppColors.tx3),
          const SizedBox(width: 9),
          SizedBox(
            width: 96,
            child: Text(meta.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: count / max,
                minHeight: 7,
                backgroundColor: AppColors.surface3,
                valueColor:
                    AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$count',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, color: AppColors.tx3)),
        ],
      ),
    );
  }

  Widget _logRow(BehaviorLog l) {
    final meta = _eventMeta[l.eventType] ?? (l.eventType, Icons.circle);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(meta.$2, size: 16, color: AppColors.tx2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(meta.$1,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w500)),
          ),
          Text(_ago(l.createdAt),
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5, color: AppColors.tx4)),
        ],
      ),
    );
  }

  static String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}
