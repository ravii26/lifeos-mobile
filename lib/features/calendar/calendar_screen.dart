import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/calendar_block.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import '../shell/life_cubit.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late Future<List<CalendarBlock>> _future;
  static const _rowH = 56.0;
  final _hours = List.generate(15, (i) => i + 7); // 7am–9pm

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    _future = getIt<LifeRepository>()
        .calendar(from: start, to: start.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowH = now.hour + now.minute / 60;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          BackHeader(eyebrow: _dateLabel(now), title: 'Today'),
          Expanded(
            child: FutureBuilder<List<CalendarBlock>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent));
                }
                final blocks = snap.data ?? const [];
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    child: SizedBox(
                      height: _hours.length * _rowH,
                      child: Stack(
                        children: [
                          for (int i = 0; i < _hours.length; i++)
                            Positioned(
                              top: i * _rowH,
                              left: 0,
                              right: 0,
                              child: _hourRow(_hours[i]),
                            ),
                          if (nowH >= 7 && nowH <= 21)
                            Positioned(
                              top: (nowH - 7) * _rowH,
                              left: 44,
                              right: 0,
                              child: Container(
                                  height: 2, color: AppColors.accent),
                            ),
                          for (final b in blocks)
                            if (b.startHour >= 7 && b.startHour <= 21)
                              _blockChip(context, b),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _hourRow(int h) => SizedBox(
        height: _rowH,
        child: Stack(
          children: [
            const Positioned(
                top: 0, left: 44, right: 0, child: Divider(height: 1)),
            Positioned(
              left: 0,
              top: -6,
              child: Text('${h > 12 ? h - 12 : h}${h >= 12 ? 'p' : 'a'}',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: AppColors.tx4)),
            ),
          ],
        ),
      );

  Widget _blockChip(BuildContext context, CalendarBlock b) {
    final color = context.read<LifeCubit>().state.areaById(b.areaId)?.color ??
        AppColors.accent;
    final top = (b.startHour - 7) * _rowH + 2;
    final height = ((b.endHour - b.startHour) * _rowH - 4).clamp(24.0, 800.0);
    return Positioned(
      top: top,
      left: 52,
      right: 4,
      height: height,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(b.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text('${_hr(b.startHour)}–${_hr(b.endHour)}',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 10, color: AppColors.tx3)),
          ],
        ),
      ),
    );
  }

  static String _hr(double h) {
    final hr = h.floor();
    final m = ((h - hr) * 60).round();
    final disp = hr > 12 ? hr - 12 : hr;
    final mm = m == 0 ? '' : ':${m.toString().padLeft(2, '0')}';
    return '$disp$mm${hr >= 12 ? 'pm' : 'am'}';
  }

  static String _dateLabel(DateTime d) => '${const [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun'
      ][d.weekday - 1]} · ${const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][d.month - 1]} ${d.day}';
}
