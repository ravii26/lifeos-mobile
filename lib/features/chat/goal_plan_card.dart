import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../places/now_cubit.dart';
import 'chat_cubit.dart';

/// A goal turned into weekly targets (plan 16, Layer 1). Nothing is saved
/// until Keep. When a Main goal is already tight, Park keeps it for later.
/// To change it, the person asks for a plan again with the change.
class GoalPlanCard extends StatefulWidget {
  final Json proposal;
  const GoalPlanCard({super.key, required this.proposal});

  @override
  State<GoalPlanCard> createState() => _GoalPlanCardState();
}

class _GoalPlanCardState extends State<GoalPlanCard> {
  bool _busy = false;
  String? _done; // receipt after Keep / Park
  String? _undoId;

  // The receipt is kept inside the proposal, which is saved with the chat, so a
  // reopened app shows "Kept" instead of offering Keep a second time.
  @override
  void initState() {
    super.initState();
    final r = widget.proposal['receipt'];
    if (r is Json) {
      _done = asStringOrNull(r['message']);
      _undoId = asStringOrNull(r['activityId']);
    }
  }

  void _remember() {
    widget.proposal['receipt'] = {'message': _done, 'activityId': _undoId};
    if (mounted) context.read<ChatCubit>().saveHistory().ignore();
  }

  Json? get _plan => widget.proposal['plan'] is Json ? widget.proposal['plan'] as Json : null;
  Json? get _caution => widget.proposal['caution'] is Json ? widget.proposal['caution'] as Json : null;
  Json? get _fit => widget.proposal['fit'] is Json ? widget.proposal['fit'] as Json : null;

  static String _date(String key) {
    final d = DateTime.tryParse(key);
    return d == null ? key : DateFormat('d MMM yyyy').format(d);
  }

  static String _amount(Json t) {
    final per = asInt(t['perWeek']);
    if (asString(t['unit']) == 'count') return '$per ${asString(t['countUnit'], 'times')} a week';
    final h = per / 60;
    return per >= 90 ? '${h.toStringAsFixed(1).replaceAll('.0', '')} h a week' : '$per min a week';
  }

  Future<void> _keep({required bool park}) async {
    final plan = _plan;
    if (plan == null) return;
    setState(() => _busy = true);
    try {
      final r = await getIt<LifeRepository>().acceptGoalPlan(plan, park: park, parkUntil: park ? asStringOrNull(_caution?['parkUntil']) : null);
      placesRefresh.value++;
      if (mounted) context.read<NowCubit>().load().ignore();
      setState(() {
        _done = park
            ? 'Parked. I\'ll bring it up ${asStringOrNull(_caution?['parkUntil']) == null ? 'later' : 'on ${_caution!['parkUntil']}'}.'
            : 'Kept. When it\'s time for it, it shows at the top of Now. The whole plan is in Plan.';
        _undoId = asStringOrNull(r['activityId']);
      });
      _remember();
    } on ApiException catch (e) {
      if (mounted) showAllyToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undo() async {
    final id = _undoId;
    if (id == null) return;
    try {
      await getIt<LifeRepository>().undo(id);
      placesRefresh.value++;
      setState(() {
        _done = 'Undone. Nothing from this plan is kept.';
        _undoId = null;
      });
      _remember();
    } on ApiException catch (e) {
      if (mounted) showAllyToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final plan = _plan;
    final targets = ((plan?['targets'] as List?) ?? const []).whereType<Json>().toList();
    if (plan == null || targets.isEmpty) return const SizedBox.shrink();
    final milestones = ((plan['milestones'] as List?) ?? const []).map((e) => e.toString()).toList();
    final steps = ((plan['steps'] as List?) ?? const []).whereType<Json>().toList();
    final deadline = asStringOrNull(plan['deadline']);
    return AllyCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('DRAFT PLAN', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x1),
        Text(asString(plan['title']), style: AllyType.h2(color: c.ink)),
        if (deadline != null) Text('By ${_date(deadline)}', style: AllyType.small(color: c.muted)),
        const SizedBox(height: Sp.x3),
        for (final t in targets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.x1),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: Sp.x2, children: [
                Text(asString(t['title']), style: AllyType.body(color: c.ink)),
                Text(_amount(t), style: AllyType.body(color: c.muted)),
              ]),
              if (asStringOrNull(t['note']) != null) Text(asString(t['note']), style: AllyType.small(color: c.muted)),
            ]),
          ),
        if (milestones.isNotEmpty) ...[
          const SizedBox(height: Sp.x3),
          Text('MILESTONES', style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x1),
          for (var i = 0; i < milestones.length; i++) Text('${i + 1}. ${milestones[i]}', style: AllyType.body(color: c.muted)),
        ],
        if (steps.isNotEmpty) ...[
          const SizedBox(height: Sp.x3),
          Text('FIRST STEPS', style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x1),
          for (final st in steps.take(3))
            Text('${asString(st['title'])}${asInt(st['minutes']) > 0 ? ' · ${asInt(st['minutes'])} min' : ''}', style: AllyType.body(color: c.muted)),
        ],
        if (asStringOrNull(_fit?['message']) != null) ...[
          const SizedBox(height: Sp.x3),
          Text(asString(_fit!['message']), style: AllyType.body(color: c.ink)),
        ],
        if (_caution != null) ...[
          const SizedBox(height: Sp.x3),
          AllyNote(asString(_caution!['message'])),
        ],
        const SizedBox(height: Sp.x3),
        if (_done != null)
          Row(children: [
            Expanded(child: Text(_done!, style: AllyType.small(color: c.muted))),
            if (_undoId != null) AllyButton('Undo', kind: AllyButtonKind.ghost, onPressed: _undo),
          ])
        else
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            AllyButton(_busy ? 'Saving…' : (_caution != null ? 'Start anyway' : 'Keep this plan'), onPressed: _busy ? null : () => _keep(park: false)),
            if (_caution != null) AllyButton('Park it', kind: AllyButtonKind.secondary, onPressed: _busy ? null : () => _keep(park: true)),
          ]),
        if (_done == null) ...[
          const SizedBox(height: Sp.x2),
          Text('Want it different? Just say so, like "make it lighter".', style: AllyType.small(color: c.faint)),
        ],
      ]),
    );
  }
}
