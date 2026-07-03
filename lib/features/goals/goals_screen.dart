import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/area.dart';
import '../../data/models/goal.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';
import '../../widgets/form_kit.dart' show titleCaseWord;
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import '../shell/life_cubit.dart';

/// Only this many goals may be ACTIVE at once (mirrors backend MAX_ACTIVE_GOALS).
const int kMaxActiveGoals = 2;

// ----------------------------------------------------------------- cubit
class GoalsState extends Equatable {
  final LoadStatus status;
  final List<Goal> goals;
  final String? error;

  const GoalsState({
    this.status = LoadStatus.initial,
    this.goals = const [],
    this.error,
  });

  List<Goal> get active => goals.where((g) => g.isActive).toList();
  List<Goal> get parked => goals.where((g) => g.isParked).toList();
  List<Goal> get closed => goals.where((g) => g.isClosed).toList();
  int get slotsRemaining => (kMaxActiveGoals - active.length).clamp(0, kMaxActiveGoals);

  GoalsState copyWith(
          {LoadStatus? status, List<Goal>? goals, String? error}) =>
      GoalsState(
          status: status ?? this.status,
          goals: goals ?? this.goals,
          error: error);

  @override
  List<Object?> get props => [status, goals, error];
}

class GoalsCubit extends Cubit<GoalsState> {
  final LifeRepository _repo;
  GoalsCubit(this._repo) : super(const GoalsState());

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final goals = await _repo.goals(withConfidence: true);
      emit(state.copyWith(status: LoadStatus.ready, goals: goals));
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.error, error: e.message));
    }
  }

  Future<void> create({
    required String title,
    required String areaId,
    String? description,
    String priority = 'MEDIUM',
    DateTime? deadline,
  }) async {
    try {
      await _repo.createGoal(
          title: title,
          areaId: areaId,
          description: description,
          priority: priority,
          deadline: deadline);
      await load();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> update(
    String id, {
    String? title,
    String? description,
    String? areaId,
    String? priority,
    String? status,
    DateTime? deadline,
  }) async {
    try {
      await _repo.updateGoal(id,
          title: title,
          description: description,
          areaId: areaId,
          priority: priority,
          status: status,
          deadline: deadline);
      await load();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> remove(String id) async {
    emit(state.copyWith(goals: state.goals.where((g) => g.id != id).toList()));
    try {
      await _repo.deleteGoal(id);
    } on ApiException catch (_) {
      await load();
    }
  }

  Future<void> activate(String id, {String? parkGoalId}) async {
    try {
      await _repo.activateGoal(id, parkGoalId: parkGoalId);
      await load();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> park(String id) async {
    try {
      await _repo.parkGoal(id);
      await load();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }
}

// ----------------------------------------------------------------- screen
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final areas = context.read<LifeCubit>().state.areas;
    return BlocProvider(
      create: (_) => GoalsCubit(getIt<LifeRepository>())..load(),
      child: _GoalsView(areas: areas),
    );
  }
}

class _GoalsView extends StatelessWidget {
  final List<Area> areas;
  const _GoalsView({required this.areas});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.accentInk,
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('New goal'),
      ),
      body: BlocConsumer<GoalsCubit, GoalsState>(
        listenWhen: (a, b) => b.error != null && a.error != b.error,
        listener: (context, s) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              backgroundColor: AppColors.danger,
              content: Text(s.error!))),
        builder: (context, s) {
          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.surface2,
            onRefresh: () => context.read<GoalsCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                BackHeader(
                    eyebrow: '${s.active.length}/$kMaxActiveGoals in focus',
                    title: 'Goals'),
                if (s.status == LoadStatus.loading && s.goals.isEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accent)))
                else if (s.goals.isEmpty)
                  _empty()
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _section(context, 'In focus', s.active,
                            hint: '${s.slotsRemaining} slot(s) free'),
                        _section(context, 'Parked', s.parked),
                        _section(context, 'Closed', s.closed),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
        child: SurfaceCard(
          padding: const EdgeInsets.all(26),
          child: Center(
              child: Text('No goals yet. Tap “New goal” to set one.',
                  style: TextStyle(color: AppColors.tx4, fontSize: 13))),
        ),
      );

  Widget _section(BuildContext context, String title, List<Goal> goals,
      {String? hint}) {
    if (goals.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SectionHeader(title, link: hint),
        const SizedBox(height: 10),
        for (final g in goals)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: GestureDetector(
              onTap: () => _openForm(context, goal: g),
              child: _GoalCard(goal: g, area: _areaOf(g.areaId)),
            ),
          ),
      ],
    );
  }

  Area? _areaOf(String id) {
    for (final a in areas) {
      if (a.id == id) return a;
    }
    return null;
  }

  void _openForm(BuildContext context, {Goal? goal}) {
    final cubit = context.read<GoalsCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _GoalForm(areas: areas, goal: goal),
      ),
    );
  }
}

// ----------------------------------------------------------------- card
Color _confidenceColor(String? label) => switch (label) {
      'ON_TRACK' => AppColors.health,
      'AT_RISK' => AppColors.warn,
      'OFF_TRACK' => AppColors.danger,
      _ => AppColors.tx3,
    };

String _priorityTag(String p) => switch (p) {
      'CRITICAL' || 'HIGH' => 'P1',
      'MEDIUM' => 'P2',
      _ => 'P3',
    };

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final Area? area;
  const _GoalCard({required this.goal, this.area});

  @override
  Widget build(BuildContext context) {
    final accent = area?.color ?? AppColors.accent;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AreaDot(accent, size: 9),
              const SizedBox(width: 8),
              Expanded(
                child: Text(goal.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              PriorityTag(_priorityTag(goal.priority)),
            ],
          ),
          if (goal.description != null && goal.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(goal.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: AppColors.tx3)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Chip3(area?.name ?? 'Area', color: accent),
              const SizedBox(width: 8),
              if (goal.deadline != null)
                Chip3(_fmtDate(goal.deadline!),
                    icon: Icons.flag_outlined),
              const Spacer(),
              if (goal.confidence != null)
                Row(
                  children: [
                    Text('${goal.confidence}%',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _confidenceColor(goal.confidenceLabel))),
                    const SizedBox(width: 6),
                    AreaDot(_confidenceColor(goal.confidenceLabel), size: 7),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${m[d.month - 1]} ${d.day}';
}

// ----------------------------------------------------------------- form
class _GoalForm extends StatefulWidget {
  final List<Area> areas;
  final Goal? goal;
  const _GoalForm({required this.areas, this.goal});

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  String? _areaId;
  String _priority = 'MEDIUM';
  String _status = 'ACTIVE';
  DateTime? _deadline;
  bool _saving = false;

  bool get _isEdit => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _title = TextEditingController(text: g?.title ?? '');
    _desc = TextEditingController(text: g?.description ?? '');
    _areaId = g?.areaId ?? (widget.areas.isNotEmpty ? widget.areas.first.id : null);
    _priority = g?.priority ?? 'MEDIUM';
    _status = g?.status ?? 'ACTIVE';
    _deadline = g?.deadline;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _areaId == null) return;
    setState(() => _saving = true);
    final cubit = context.read<GoalsCubit>();
    final desc = _desc.text.trim();
    if (_isEdit) {
      await cubit.update(widget.goal!.id,
          title: title,
          description: desc,
          areaId: _areaId,
          priority: _priority,
          status: _status,
          deadline: _deadline);
    } else {
      await cubit.create(
          title: title,
          areaId: _areaId!,
          description: desc,
          priority: _priority,
          deadline: _deadline);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    final canFocus = g != null && !g.isActive;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                      color: AppColors.line3,
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              Text(_isEdit ? 'Edit goal' : 'New goal',
                  style: GoogleFonts.hankenGrotesk(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _field(_title, 'Goal title', autofocus: !_isEdit),
              const SizedBox(height: 10),
              _field(_desc, 'Why does this matter? (optional)', lines: 3),
              const SizedBox(height: 16),
              _label('Area'),
              _chipWrap([
                for (final a in widget.areas)
                  _selChip(a.name, _areaId == a.id,
                      () => setState(() => _areaId = a.id),
                      color: a.color),
              ]),
              const SizedBox(height: 14),
              _label('Priority'),
              _chipWrap([
                for (final p in const ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'])
                  _selChip(titleCaseWord(p), _priority == p,
                      () => setState(() => _priority = p)),
              ]),
              if (_isEdit) ...[
                const SizedBox(height: 14),
                _label('Status'),
                _chipWrap([
                  for (final st in const [
                    'ACTIVE',
                    'PARKED',
                    'COMPLETED',
                    'PAUSED',
                    'ABANDONED'
                  ])
                    _selChip(titleCaseWord(st), _status == st,
                        () => setState(() => _status = st)),
                ]),
              ],
              const SizedBox(height: 14),
              _label('Deadline'),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _deadline ?? now,
                        firstDate: now.subtract(const Duration(days: 1)),
                        lastDate: DateTime(now.year + 6),
                      );
                      if (picked != null) setState(() => _deadline = picked);
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 15),
                    label: Text(_deadline == null
                        ? 'Set date'
                        : _fmtDate(_deadline!)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.tx2,
                        side: BorderSide(color: AppColors.line2)),
                  ),
                  if (_deadline != null)
                    TextButton(
                        onPressed: () => setState(() => _deadline = null),
                        child: const Text('Clear')),
                ],
              ),
              const SizedBox(height: 20),
              if (canFocus) ...[
                _focusButton(g),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentInk,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEdit ? 'Save changes' : 'Create goal'),
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _confirmDelete(g!),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppColors.danger),
                    label: const Text('Delete goal',
                        style: TextStyle(color: AppColors.danger)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _focusButton(Goal g) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _activate(g),
          icon: const Icon(Icons.center_focus_strong, size: 17),
          label: const Text('Move into focus'),
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accentLine),
              padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      );

  Future<void> _activate(Goal g) async {
    final cubit = context.read<GoalsCubit>();
    final st = cubit.state;
    String? parkId;
    if (st.slotsRemaining <= 0) {
      parkId = await _pickGoalToPark(st.active);
      if (parkId == null) return; // cancelled
    }
    await cubit.activate(g.id, parkGoalId: parkId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<String?> _pickGoalToPark(List<Goal> active) {
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('Focus is full',
            style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pick a goal to park to make room:',
                style: TextStyle(fontSize: 13, color: AppColors.tx3)),
            const SizedBox(height: 8),
            for (final a in active)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(a.title, style: const TextStyle(fontSize: 14)),
                onTap: () => Navigator.of(context).pop(a.id),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Goal g) {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('Delete goal?', style: TextStyle(fontSize: 16)),
        content: Text('“${g.title}” will be removed.',
            style: TextStyle(fontSize: 13, color: AppColors.tx3)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<GoalsCubit>().remove(g.id);
              Navigator.of(dctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  // --- small form helpers ---
  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(t,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.tx3)),
      );

  Widget _field(TextEditingController c, String hint,
          {int lines = 1, bool autofocus = false}) =>
      TextField(
        controller: c,
        autofocus: autofocus,
        maxLines: lines,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.tx4),
          filled: true,
          fillColor: AppColors.surface2,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.accentLine),
          ),
        ),
      );

  Widget _chipWrap(List<Widget> chips) =>
      Wrap(spacing: 8, runSpacing: 8, children: chips);

  Widget _selChip(String label, bool selected, VoidCallback onTap,
      {Color? color}) {
    final c = color ?? AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.16) : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? c : AppColors.line, width: selected ? 1.3 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? c : AppColors.tx2)),
      ),
    );
  }
}
