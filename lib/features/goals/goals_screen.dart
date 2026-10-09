import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/area.dart';
import '../../data/models/goal.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/form_kit.dart';
import '../guide/guide_style.dart';
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
  int get slotsRemaining =>
      (kMaxActiveGoals - active.length).clamp(0, kMaxActiveGoals);

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
    emit(state.copyWith(
        goals: state.goals.where((g) => g.id != id).toList()));
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
    return BlocConsumer<GoalsCubit, GoalsState>(
      listenWhen: (a, b) => b.error != null && a.error != b.error,
      listener: (context, s) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          backgroundColor: G.card,
          content: Text(s.error!, style: G.text(13, color: G.carried)),
        )),
      builder: (context, s) {
        return Scaffold(
          backgroundColor: G.bg,
          appBar: GTopBar(
            'Goals & Outcomes',
            subtitle: '${s.active.length}/$kMaxActiveGoals active focus',
            showBack: true,
            trailing: IconButton(
              icon: Icon(Icons.add, size: 20, color: G.accent),
              onPressed: () => _openForm(context),
            ),
          ),
          body: RefreshIndicator(
            color: G.accent,
            backgroundColor: G.card,
            onRefresh: () => context.read<GoalsCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: G.inset,
                    border: Border.all(color: G.lineSoft, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.flag_outlined, size: 16, color: G.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Max $kMaxActiveGoals goals in active focus at once to prevent divided energy and overwhelmed days.',
                          style: G.voice(13.5, color: G.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (s.status == LoadStatus.loading && s.goals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: G.accent,
                        strokeWidth: 1.5,
                      ),
                    ),
                  )
                else if (s.goals.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: G.card,
                      border: Border.all(color: G.lineSoft, width: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        'No outcomes set yet.\nDefine a project or goal to tie your daily actions together.',
                        textAlign: TextAlign.center,
                        style: G.voice(14, color: G.muted),
                      ),
                    ),
                  )
                else ...[
                  _section(context, 'IN FOCUS', s.active,
                      hint: '${s.slotsRemaining} slot(s) free'),
                  _section(context, 'PARKED', s.parked),
                  _section(context, 'CLOSED', s.closed),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _section(BuildContext context, String title, List<Goal> goals,
      {String? hint}) {
    if (goals.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: G.label(size: 11, color: G.faint)),
            if (hint != null)
              Text(hint, style: G.label(size: 11, color: G.accent)),
          ],
        ),
        const SizedBox(height: 8),
        for (final g in goals)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
    final accent = area?.color ?? G.accent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: G.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: G.lineSoft, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  goal.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: G.text(15, w: FontWeight.w600, color: G.ink),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: G.inset,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: G.lineSoft, width: 0.5),
                ),
                child: Text(
                  _priorityTag(goal.priority),
                  style: G.label(size: 9.5, color: G.faint),
                ),
              ),
            ],
          ),
          if (goal.description != null && goal.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              goal.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: G.voice(13, color: G.muted),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                area?.name ?? 'General',
                style: G.label(size: 11, color: accent),
              ),
              if (goal.deadline != null) ...[
                Text(' · ', style: G.label(size: 11, color: G.faint)),
                Text(
                  'Due ${_fmtDate(goal.deadline!)}',
                  style: G.label(size: 11, color: G.muted),
                ),
              ],
              const Spacer(),
              if (goal.confidence != null)
                Text(
                  '${goal.confidence}% trajectory',
                  style: G.label(
                    size: 10.5,
                    color: goal.confidence! >= 70
                        ? G.good
                        : (goal.confidence! >= 40 ? G.accent : G.carried),
                  ),
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
    _areaId =
        g?.areaId ?? (widget.areas.isNotEmpty ? widget.areas.first.id : null);
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
    return FormSheet(
      title: _isEdit ? 'Edit goal' : 'New goal',
      children: [
        formField(_title, 'Goal title', autofocus: !_isEdit),
        const SizedBox(height: 10),
        formField(_desc, 'Why does this matter? (optional)', lines: 3),
        const SizedBox(height: 16),
        formLabel('Area'),
        chipWrap([
          for (final a in widget.areas)
            selChip(a.name, _areaId == a.id,
                () => setState(() => _areaId = a.id),
                color: a.color),
        ]),
        const SizedBox(height: 14),
        formLabel('Priority'),
        chipWrap([
          for (final p in const ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'])
            selChip(titleCaseWord(p), _priority == p,
                () => setState(() => _priority = p)),
        ]),
        if (_isEdit) ...[
          const SizedBox(height: 14),
          formLabel('Status'),
          chipWrap([
            for (final st in const [
              'ACTIVE',
              'PARKED',
              'COMPLETED',
              'PAUSED',
              'ABANDONED'
            ])
              selChip(titleCaseWord(st), _status == st,
                  () => setState(() => _status = st)),
          ]),
        ],
        const SizedBox(height: 14),
        formLabel('Deadline'),
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
              icon: Icon(Icons.calendar_today_outlined,
                  size: 14, color: G.faint),
              label: Text(
                _deadline == null ? 'Set date' : _fmtDate(_deadline!),
                style: G.label(size: 11.5, color: G.muted),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: G.lineSoft, width: 0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            if (_deadline != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _deadline = null),
                child:
                    Text('Clear', style: G.label(size: 11, color: G.faint)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        if (canFocus) ...[
          _focusButton(g),
          const SizedBox(height: 10),
        ],
        saveButton(_saving, _save, _isEdit ? 'Save changes' : 'Create goal'),
        if (_isEdit) ...[
          const SizedBox(height: 6),
          deleteRow(context, 'Delete goal', () => _confirmDelete(g!)),
        ],
      ],
    );
  }

  Widget _focusButton(Goal g) => SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton.icon(
          onPressed: () => _activate(g),
          icon: Icon(Icons.center_focus_strong, size: 16, color: G.accent),
          label: Text('Move into focus',
              style: G.text(13, w: FontWeight.w500, color: G.accent)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
                color: G.accent.withValues(alpha: 0.4), width: 0.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
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
        backgroundColor: G.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: G.lineSoft, width: 0.5),
        ),
        title: Text('Focus is full', style: G.voice(16, color: G.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pick a goal to park to make room for this one:',
                style: G.text(13, color: G.muted)),
            const SizedBox(height: 12),
            for (final a in active)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(a.title,
                    style: G.text(14, w: FontWeight.w500, color: G.ink)),
                onTap: () => Navigator.of(context).pop(a.id),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Goal g) async {
    if (await confirmDelete(context, '“${g.title}” will be removed.')) {
      if (!mounted) return;
      context.read<GoalsCubit>().remove(g.id);
      Navigator.of(context).pop();
    }
  }
}
