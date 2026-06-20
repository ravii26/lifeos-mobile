import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/area.dart';
import '../../data/models/goal.dart';
import '../../data/models/project.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import '../shell/life_cubit.dart';

// ----------------------------------------------------------------- cubit
class ProjectsState extends Equatable {
  final LoadStatus status;
  final List<Project> projects;
  final List<Goal> goals; // for the "link to goal" picker
  final String? error;

  const ProjectsState({
    this.status = LoadStatus.initial,
    this.projects = const [],
    this.goals = const [],
    this.error,
  });

  List<Project> get active => projects.where((p) => p.isActive).toList();
  List<Project> get closed => projects.where((p) => p.isClosed).toList();

  ProjectsState copyWith({
    LoadStatus? status,
    List<Project>? projects,
    List<Goal>? goals,
    String? error,
  }) =>
      ProjectsState(
        status: status ?? this.status,
        projects: projects ?? this.projects,
        goals: goals ?? this.goals,
        error: error,
      );

  @override
  List<Object?> get props => [status, projects, goals, error];
}

class ProjectsCubit extends Cubit<ProjectsState> {
  final LifeRepository _repo;
  ProjectsCubit(this._repo) : super(const ProjectsState());

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final results = await Future.wait([
        _repo.projects(),
        _repo.goals(withConfidence: false),
      ]);
      emit(state.copyWith(
        status: LoadStatus.ready,
        projects: results[0] as List<Project>,
        goals: results[1] as List<Goal>,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.error, error: e.message));
    }
  }

  Future<void> create({
    required String title,
    required String areaId,
    String? description,
    String? goalId,
    DateTime? deadline,
  }) async {
    try {
      await _repo.createProject(
          title: title,
          areaId: areaId,
          description: description,
          goalId: goalId,
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
    String? goalId,
    String? status,
    DateTime? deadline,
  }) async {
    try {
      await _repo.updateProject(id,
          title: title,
          description: description,
          areaId: areaId,
          goalId: goalId,
          status: status,
          deadline: deadline);
      await load();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> remove(String id) async {
    emit(state.copyWith(
        projects: state.projects.where((p) => p.id != id).toList()));
    try {
      await _repo.deleteProject(id);
    } on ApiException catch (_) {
      await load();
    }
  }
}

// ----------------------------------------------------------------- screen
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final areas = context.read<LifeCubit>().state.areas;
    return BlocProvider(
      create: (_) => ProjectsCubit(getIt<LifeRepository>())..load(),
      child: _ProjectsView(areas: areas),
    );
  }
}

class _ProjectsView extends StatelessWidget {
  final List<Area> areas;
  const _ProjectsView({required this.areas});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.accentInk,
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('New project'),
      ),
      body: BlocConsumer<ProjectsCubit, ProjectsState>(
        listenWhen: (a, b) => b.error != null && a.error != b.error,
        listener: (context, s) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              backgroundColor: AppColors.danger, content: Text(s.error!))),
        builder: (context, s) {
          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.surface2,
            onRefresh: () => context.read<ProjectsCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                BackHeader(
                    eyebrow: '${s.active.length} active', title: 'Projects'),
                if (s.status == LoadStatus.loading && s.projects.isEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accent)))
                else if (s.projects.isEmpty)
                  _empty()
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _section(context, 'Active', s.active, s.goals),
                        _section(context, 'Closed', s.closed, s.goals),
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
              child: Text('No projects yet. Tap “New project” to add one.',
                  style: TextStyle(color: AppColors.tx4, fontSize: 13))),
        ),
      );

  Widget _section(BuildContext context, String title, List<Project> projects,
      List<Goal> goals) {
    if (projects.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SectionHeader(title),
        const SizedBox(height: 10),
        for (final p in projects)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: GestureDetector(
              onTap: () => _openForm(context, project: p),
              child: _ProjectCard(
                project: p,
                area: _areaOf(p.areaId),
                goalTitle: _goalTitle(goals, p.goalId),
              ),
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

  String? _goalTitle(List<Goal> goals, String? goalId) {
    if (goalId == null) return null;
    for (final g in goals) {
      if (g.id == goalId) return g.title;
    }
    return null;
  }

  void _openForm(BuildContext context, {Project? project}) {
    final cubit = context.read<ProjectsCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _ProjectForm(
            areas: areas, goals: cubit.state.goals, project: project),
      ),
    );
  }
}

// ----------------------------------------------------------------- card
class _ProjectCard extends StatelessWidget {
  final Project project;
  final Area? area;
  final String? goalTitle;
  const _ProjectCard({required this.project, this.area, this.goalTitle});

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
                child: Text(project.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (project.description != null &&
              project.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(project.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: AppColors.tx3)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Chip3(area?.name ?? 'Area', color: accent),
              if (goalTitle != null)
                Chip3(goalTitle!, icon: Icons.flag_outlined),
              if (project.deadline != null)
                Chip3(_fmtDate(project.deadline!),
                    icon: Icons.calendar_today_outlined),
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

String _titleCase(String s) =>
    s.isEmpty ? s : s[0] + s.substring(1).toLowerCase();

// ----------------------------------------------------------------- form
class _ProjectForm extends StatefulWidget {
  final List<Area> areas;
  final List<Goal> goals;
  final Project? project;
  const _ProjectForm({required this.areas, required this.goals, this.project});

  @override
  State<_ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<_ProjectForm> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  String? _areaId;
  String? _goalId;
  String _status = 'ACTIVE';
  DateTime? _deadline;
  bool _saving = false;

  bool get _isEdit => widget.project != null;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _title = TextEditingController(text: p?.title ?? '');
    _desc = TextEditingController(text: p?.description ?? '');
    _areaId =
        p?.areaId ?? (widget.areas.isNotEmpty ? widget.areas.first.id : null);
    _goalId = p?.goalId;
    _status = p?.status ?? 'ACTIVE';
    _deadline = p?.deadline;
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
    final cubit = context.read<ProjectsCubit>();
    final desc = _desc.text.trim();
    if (_isEdit) {
      await cubit.update(widget.project!.id,
          title: title,
          description: desc,
          areaId: _areaId,
          goalId: _goalId,
          status: _status,
          deadline: _deadline);
    } else {
      await cubit.create(
          title: title,
          areaId: _areaId!,
          description: desc,
          goalId: _goalId,
          deadline: _deadline);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Only goals in the chosen area make sense to link.
    final linkableGoals = widget.goals
        .where((g) => _areaId == null || g.areaId == _areaId)
        .toList();
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              Text(_isEdit ? 'Edit project' : 'New project',
                  style: GoogleFonts.hankenGrotesk(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _field(_title, 'Project title', autofocus: !_isEdit),
              const SizedBox(height: 10),
              _field(_desc, 'Notes (optional)', lines: 3),
              const SizedBox(height: 16),
              _label('Area'),
              _chipWrap([
                for (final a in widget.areas)
                  _selChip(a.name, _areaId == a.id, () {
                    setState(() {
                      _areaId = a.id;
                      // Drop a goal link that no longer matches the area.
                      if (_goalId != null &&
                          !widget.goals.any(
                              (g) => g.id == _goalId && g.areaId == a.id)) {
                        _goalId = null;
                      }
                    });
                  }, color: a.color),
              ]),
              if (linkableGoals.isNotEmpty) ...[
                const SizedBox(height: 14),
                _label('Linked goal (optional)'),
                _chipWrap([
                  _selChip('None', _goalId == null,
                      () => setState(() => _goalId = null)),
                  for (final g in linkableGoals)
                    _selChip(g.title, _goalId == g.id,
                        () => setState(() => _goalId = g.id)),
                ]),
              ],
              if (_isEdit) ...[
                const SizedBox(height: 14),
                _label('Status'),
                _chipWrap([
                  for (final st in const [
                    'ACTIVE',
                    'COMPLETED',
                    'PAUSED',
                    'ABANDONED'
                  ])
                    _selChip(_titleCase(st), _status == st,
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
                    label: Text(
                        _deadline == null ? 'Set date' : _fmtDate(_deadline!)),
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
                      : Text(_isEdit ? 'Save changes' : 'Create project'),
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _confirmDelete(widget.project!),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppColors.danger),
                    label: const Text('Delete project',
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

  void _confirmDelete(Project p) {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('Delete project?', style: TextStyle(fontSize: 16)),
        content: Text('“${p.title}” will be removed.',
            style: TextStyle(fontSize: 13, color: AppColors.tx3)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<ProjectsCubit>().remove(p.id);
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

  // --- shared form helpers ---
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
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.16) : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? c : AppColors.line, width: selected ? 1.3 : 1),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? c : AppColors.tx2)),
      ),
    );
  }
}
