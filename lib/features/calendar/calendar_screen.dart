import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/calendar_block.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/form_kit.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import '../shell/life_cubit.dart';
import 'block_form.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late Future<List<CalendarBlock>> _future;
  static const _rowH = 56.0;
  final _hours = List.generate(15, (i) => i + 7); // 7am–9pm

  DateTime get _dayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Set<String> _conflictIds = {};

  void _load() {
    final start = _dayStart;
    final end = start.add(const Duration(days: 1));
    final repo = getIt<LifeRepository>();
    _future = repo.calendar(from: start, to: end);
    // Best-effort conflict highlighting; failures just leave nothing flagged.
    repo.calendarConflicts(from: start, to: end).then((pairs) {
      if (!mounted) return;
      final ids = <String>{};
      for (final p in pairs) {
        if (p is Map) {
          final a = p['a'], b = p['b'];
          if (a is Map && a['occurrenceId'] != null) {
            ids.add('${a['occurrenceId']}');
          }
          if (b is Map && b['occurrenceId'] != null) {
            ids.add('${b['occurrenceId']}');
          }
        }
      }
      setState(() => _conflictIds = ids);
    }).catchError((_) {});
  }

  void _reload() => setState(_load);

  Future<void> _openForm(
      {CalendarBlock? block, EditScope scope = EditScope.single}) async {
    final areas = context.read<LifeCubit>().state.areas;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          BlockForm(block: block, areas: areas, day: _dayStart, scope: scope),
    );
    if (changed == true) _reload();
  }

  /// Recurring occurrences need a scope choice; one-offs open straight to edit.
  Future<void> _onBlockTap(CalendarBlock b) async {
    if (!b.isOccurrence) {
      _openForm(block: b);
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _sheetRow(Icons.event, 'Edit this occurrence', 'occurrence'),
            _sheetRow(Icons.fast_forward, 'Edit this & following', 'following'),
            _sheetRow(Icons.repeat, 'Edit whole series', 'series'),
            _sheetRow(Icons.block, 'Skip this occurrence', 'skip',
                color: AppColors.warn),
            _sheetRow(Icons.delete_outline, 'Delete series', 'deleteSeries',
                color: AppColors.danger),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'occurrence':
        _openForm(block: b, scope: EditScope.occurrence);
      case 'following':
        _openForm(block: b, scope: EditScope.following);
      case 'series':
        _openForm(block: b, scope: EditScope.series);
      case 'skip':
        await getIt<LifeRepository>().upsertException(b.seriesId,
            occurrenceDate: b.occurrenceDate!, isCancelled: true);
        _reload();
      case 'deleteSeries':
        if (await confirmDelete(
            context, 'The entire “${b.title}” series will be removed.')) {
          await getIt<LifeRepository>().deleteBlock(b.seriesId);
          _reload();
        }
    }
  }

  Widget _sheetRow(IconData icon, String label, String value, {Color? color}) =>
      ListTile(
        leading: Icon(icon, color: color ?? AppColors.tx, size: 21),
        title: Text(label,
            style: TextStyle(
                color: color ?? AppColors.tx, fontWeight: FontWeight.w600)),
        onTap: () => Navigator.of(context).pop(value),
      );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowH = now.hour + now.minute / 60;
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.accentInk,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Block'),
      ),
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
      child: GestureDetector(
        onTap: () => _onBlockTap(b),
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
            Row(
              children: [
                Expanded(
                  child: Text(b.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                if (_conflictIds.contains(b.id))
                  Icon(Icons.warning_amber_rounded,
                      size: 13, color: AppColors.warn),
                if (b.isRecurring)
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child:
                        Icon(Icons.repeat, size: 12, color: AppColors.tx3),
                  ),
              ],
            ),
            Text('${_hr(b.startHour)}–${_hr(b.endHour)}',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 10, color: AppColors.tx3)),
          ],
        ),
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
