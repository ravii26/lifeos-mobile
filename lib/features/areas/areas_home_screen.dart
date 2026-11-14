import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/ally_theme.dart';
import '../../design/components.dart';
import '../../design/rings.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../chat/starters.dart' show talkRequest;
import '../places/now_cubit.dart' show placesRefresh;
import '../today/day_shape.dart' show duration;
import 'area_page.dart';
import 'areas_overview.dart';

/// Areas: every part of the person's life on one wheel, and where each
/// stands this week. One screen should answer "where am I with everything?".
class AreasHomeScreen extends StatefulWidget {
  /// For tests.
  final LifeRepository? repo;
  const AreasHomeScreen({super.key, this.repo});

  @override
  State<AreasHomeScreen> createState() => _AreasHomeScreenState();
}

class _AreasHomeScreenState extends State<AreasHomeScreen> {
  late final LifeRepository _repo = widget.repo ?? getIt<LifeRepository>();
  AreasOverview? _data;
  String? _error;
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    placesRefresh.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    placesRefresh.removeListener(_load);
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await loadAreasOverview(_repo);
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && _data == null) setState(() => _error = e.message);
    }
  }

  Future<void> _open(BuildContext themed, int index) async {
    final data = _data;
    if (data == null) return;
    await Navigator.of(themed).push(MaterialPageRoute<void>(
      builder: (_) => AreaPage(area: data.areas[index], colorIndex: index, canSetTime: data.full, repo: _repo),
    ));
    _load();
  }

  Future<void> _add(BuildContext themed) async {
    _name.clear();
    final name = await showAllySheet<String>(
      themed,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add an area', style: AllyType.h2(color: ctx.ac.ink)),
          const SizedBox(height: Sp.x1),
          Text('A part of your life you want to keep an eye on.', style: AllyType.body(color: ctx.ac.muted)),
          const SizedBox(height: Sp.x3),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 40,
            style: AllyType.body(color: ctx.ac.ink),
            decoration: const InputDecoration(hintText: 'For example: Health', counterText: ''),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          const SizedBox(height: Sp.x3),
          AllyButton('Add', wide: true, onPressed: () => Navigator.of(ctx).pop(_name.text)),
        ],
      ),
    );
    final clean = name?.trim() ?? '';
    if (clean.isEmpty || !themed.mounted) return;
    try {
      // The server keeps a colour per area; the app colours by position, so any value does.
      await _repo.createArea(name: clean, color: '#8B909C', tier: AreaMode.maintain.tier);
      placesRefresh.value++;
      if (themed.mounted) showAllyToast(themed, '$clean added. It starts in Maintain.');
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: AllyTheme.dark(), child: Builder(builder: _page));
  }

  Widget _page(BuildContext themed) {
    final c = themed.ac;
    final data = _data;
    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.ink,
          backgroundColor: c.raised,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x4, Sp.side, Sp.x6),
            children: [
              if (data == null && _error == null)
                const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AllySkeleton(height: 34, width: 180),
                  SizedBox(height: Sp.x5),
                  Center(child: AllySkeleton(height: 220, width: 220, radius: 110)),
                  SizedBox(height: Sp.x5),
                  AllySkeleton(height: 210, radius: Rad.card),
                ])
              else if (data == null)
                AllyCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Couldn't load your areas", style: AllyType.h2(color: c.ink)),
                    const SizedBox(height: Sp.x1),
                    Text(_error!, style: AllyType.body(color: c.muted)),
                    const SizedBox(height: Sp.x4),
                    AllyButton('Try again', onPressed: _load),
                  ]),
                )
              else
                Stagger(children: _content(themed, c, data)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext themed, AllyColors c, AreasOverview data) {
    final header = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('THIS WEEK', style: AllyType.eyebrow(color: c.faint)),
      const SizedBox(height: Sp.x1),
      Text('Your areas', style: AllyType.h1(color: c.ink)),
    ]);
    if (data.areas.isEmpty) {
      return [
        header,
        AllyCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nothing here yet', style: AllyType.h2(color: c.ink)),
            const SizedBox(height: Sp.x1),
            Text('Add the parts of your life you want to keep moving: work, health, a skill, people. Ally tracks each one.',
                style: AllyType.body(color: c.muted)),
            const SizedBox(height: Sp.x4),
            AllyButton('Add an area', wide: true, onPressed: () => _add(themed)),
            const SizedBox(height: Sp.x1),
            AllyButton('Tell Ally instead', kind: AllyButtonKind.ghost, wide: true, onPressed: () => talkRequest.value++),
          ]),
        ),
      ];
    }
    final active = data.areas.where((a) => a.mode != AreaMode.rest).length;
    return [
      header,
      LifeWheel(
        spokes: [for (var i = 0; i < data.areas.length; i++) WheelSpoke(data.areas[i].name, c.area(i), data.areas[i].value)],
        onTap: (i) => _open(themed, i),
        child: Text('$active', style: AllyType.h2(color: c.ink)),
      ),
      if (data.capacityNote != null)
        AllyBanner(data.capacityNote!, icon: Icons.balance_rounded)
      else if (data.full && data.neededMinutes > 0 && data.freeMinutes > 0)
        Text('This week asks for ${duration(data.neededMinutes)}. You have about ${duration(data.freeMinutes)} free.',
            textAlign: TextAlign.center, style: AllyType.small(color: c.faint)),
      AllyCard(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x1),
        child: Column(children: [
          for (var i = 0; i < data.areas.length; i++) ...[
            if (i > 0) Divider(color: c.line, height: 1),
            _row(themed, c, data.areas[i], i),
          ],
        ]),
      ),
      AllyButton('Add an area', kind: AllyButtonKind.secondary, icon: Icons.add_rounded, wide: true, onPressed: () => _add(themed)),
    ];
  }

  Widget _row(BuildContext themed, AllyColors c, AreaStanding a, int i) => Pressable(
        scale: 0.985,
        semanticLabel: '${a.name}, ${a.mode.label}, ${a.status}',
        onTap: () => _open(themed, i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.x3),
          child: Row(children: [
            ExcludeSemantics(child: ProgressRing(value: a.value, color: c.area(i))),
            const SizedBox(width: Sp.x3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: Sp.x2, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(a.name, style: AllyType.body(color: c.ink, w: FontWeight.w500)),
                  ModeTag(a.mode.label),
                ]),
                Text(a.status, style: AllyType.small(color: c.faint)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: c.faint),
          ]),
        ),
      );
}
