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
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('A week you can keep', style: G.text(16, color: G.accent, height: 1.2)),
        const SizedBox(height: 6),
        Text(asString(plan['title']), style: G.text(25, w: FontWeight.w600, height: 1.12, letterSpacing: -0.4)),
        if (deadline != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text('By ${_date(deadline)}', style: G.text(16, color: G.muted, height: 1.3))),
        const SizedBox(height: 10),
        for (final t in targets)
          Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: G.surfaceHigh))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(asString(t['title']), style: G.text(19, height: 1.25))),
                const SizedBox(width: 10),
                Text(_amount(t), style: G.text(15, color: G.accent, height: 1.25)),
              ]),
              if (asStringOrNull(t['note']) != null) Text(asString(t['note']), style: G.text(15, color: G.muted, height: 1.3)),
            ]),
          ),
        if (milestones.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Stages: ${milestones.join(', then ')}', style: G.text(16, color: G.muted, height: 1.35)),
        ],
        if (asStringOrNull(_fit?['message']) != null) ...[
          const SizedBox(height: 10),
          Text(asString(_fit!['message']), style: G.text(17, height: 1.35)),
        ],
        if (_caution != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: G.surfaceHigh, borderRadius: BorderRadius.circular(18)),
            child: Text(asString(_caution!['message']), style: G.text(17, height: 1.35)),
          ),
        ],
        const SizedBox(height: 14),
        if (_done != null)
          Row(children: [
            Expanded(child: Text(_done!, style: G.text(16, color: G.muted, height: 1.35))),
            if (_undoId != null)
              TextButton(
                onPressed: _undo,
                style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                child: Text('Undo', style: G.text(16, w: FontWeight.w600, color: G.accent, height: 1.2)),
              ),
          ])
        else
          Row(children: [
            Expanded(child: GPill(_busy ? 'Saving…' : (_caution != null ? 'Start anyway' : 'Keep this plan'), primary: true, onTap: _busy ? null : () => _keep(park: false))),
            if (_caution != null) ...[
              const SizedBox(width: 8),
              Expanded(child: GPill('Park it', onTap: _busy ? null : () => _keep(park: true))),
            ],
          ]),
        if (_done == null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Want it different? Just say so, like "make it lighter".', style: G.text(15, color: G.muted, height: 1.3)),
          ),
      ]),
    );
  }
}
