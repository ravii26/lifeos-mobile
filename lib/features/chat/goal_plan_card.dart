import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final targets = ((plan?['targets'] as List?) ?? const []).whereType<Json>().toList();
    if (plan == null || targets.isEmpty) return const SizedBox.shrink();
    final milestones = ((plan['milestones'] as List?) ?? const []).map((e) => e.toString()).toList();
    final deadline = asStringOrNull(plan['deadline']);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: G.card, border: Border.all(color: G.lineSoft, width: 0.5), borderRadius: BorderRadius.circular(4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(asString(plan['title']), style: G.text(16, w: FontWeight.w600)),
        if (deadline != null) Text('By ${_date(deadline)}', style: G.label(size: 11, color: G.faint)),
        const SizedBox(height: 10),
        for (final t in targets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(asString(t['title']), style: G.text(14.5, w: FontWeight.w500))),
                Text(_amount(t), style: G.label(size: 12, color: G.muted)),
              ]),
              if (asStringOrNull(t['note']) != null) Text(asString(t['note']), style: G.text(12.5, color: G.faint)),
            ]),
          ),
        if (milestones.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Stages: ${milestones.join(' → ')}', style: G.text(12.5, color: G.muted, height: 1.4)),
        ],
        if (asStringOrNull(_fit?['message']) != null) ...[
          const SizedBox(height: 10),
          Text(asString(_fit!['message']), style: G.text(13, color: G.muted, height: 1.4)),
        ],
        if (_caution != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(color: G.inset, border: Border(left: BorderSide(color: G.carried, width: 2))),
            child: Text(asString(_caution!['message']), style: G.text(13, color: G.ink, height: 1.4)),
          ),
        ],
        const SizedBox(height: 12),
        if (_done != null)
          Row(children: [
            Expanded(child: Text(_done!, style: G.text(13, color: G.muted))),
            if (_undoId != null) TextButton(onPressed: _undo, child: Text('Undo', style: G.label(size: 12, color: G.accent, w: FontWeight.w600))),
          ])
        else
          Row(children: [
            Expanded(child: GButton(_busy ? 'Saving…' : (_caution != null ? 'Start anyway' : 'Keep it'), onTap: _busy ? null : () => _keep(park: false))),
            if (_caution != null) ...[
              const SizedBox(width: 8),
              Expanded(child: GButton('Park it', primary: false, onTap: _busy ? null : () => _keep(park: true))),
            ],
          ]),
        if (_done == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Want it different? Just say so, like "make it 3 evenings a week".',
                style: G.label(size: 11, color: G.faint)),
          ),
      ]),
    );
  }
}
