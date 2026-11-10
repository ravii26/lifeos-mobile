import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../core/links/open_link.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';

/// Lists and routines you can tick, people with Call and WhatsApp, the diet, and the
/// Watch later queue (Phase D). Used by the Notes place; the plain notes keep their card.

bool isSpecialNote(Map<String, dynamic> n) {
  final template = '${n['template']}';
  final collection = '${n['collection']}';
  return collection == 'People' || collection == 'Diet' || template == 'LIST' || template == 'ROUTINE';
}

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

/// A 10-digit number with no country code is taken as Indian, like the server does.
String dialNumber(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (!phone.trim().startsWith('+') && digits.length == 10) return '+91$digits';
  return phone.trim().startsWith('+') ? '+$digits' : digits;
}

class SpecialNoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final VoidCallback onChanged;
  const SpecialNoteCard(this.note, {super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if ('${note['collection']}' == 'People') return _PersonCard(note);
    if ('${note['collection']}' == 'Diet') return _DietCard(note);
    return _ChecklistCard(note, onChanged: onChanged);
  }
}

Widget _frame({required Widget child}) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
      width: double.infinity,
      decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(22)),
      child: child,
    );

// ---- a list or routine you tick ------------------------------------------------------------------

class _ChecklistCard extends StatefulWidget {
  final Map<String, dynamic> note;
  final VoidCallback onChanged;
  const _ChecklistCard(this.note, {required this.onChanged});

  @override
  State<_ChecklistCard> createState() => _ChecklistCardState();
}

class _ChecklistCardState extends State<_ChecklistCard> {
  final _repo = getIt<LifeRepository>();
  late List<String> _items;
  late Set<String> _done;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(covariant _ChecklistCard old) {
    super.didUpdateWidget(old);
    _read();
  }

  void _read() {
    _items = [for (final i in (widget.note['items'] as List? ?? const [])) '$i'];
    _done = {for (final i in (widget.note['done'] as List? ?? const [])) '$i'};
  }

  bool get _routine => '${widget.note['template']}' == 'ROUTINE';

  Future<void> _tick(String item) async {
    if (_busy) return;
    final done = !_done.contains(item);
    setState(() {
      _busy = true;
      done ? _done.add(item) : _done.remove(item);
    });
    try {
      await _repo.tickNote('${widget.note['id']}', item, done);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => done ? _done.remove(item) : _done.add(item));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset({required bool clear}) async {
    setState(() => _busy = true);
    try {
      await _repo.resetNote('${widget.note['id']}', clear: clear);
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = _items.where((i) => !_done.contains(i)).length;
    return _frame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${widget.note['title']}', style: G.text(22, w: FontWeight.w600, height: 1.2))),
          Text(_items.isEmpty ? '' : (left == 0 ? 'All done' : '$left to go'), style: G.text(15, color: G.muted, height: 1.2)),
        ]),
        const SizedBox(height: 6),
        if (_items.isEmpty) Text('Nothing on it yet. Tell Ally what to add.', style: G.text(17, color: G.muted, height: 1.35)),
        for (final item in _items)
          InkWell(
            onTap: _busy ? null : () => _tick(item),
            child: Container(
              constraints: const BoxConstraints(minHeight: 50),
              child: Row(children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _done.contains(item) ? G.accent : Colors.transparent,
                    border: _done.contains(item) ? null : Border.all(color: G.faint, width: 2),
                  ),
                  child: _done.contains(item) ? Icon(Icons.check_rounded, size: 17, color: G.onInk) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(item,
                      style: G.text(19, color: _done.contains(item) ? G.faint : G.ink, height: 1.25)
                          .copyWith(decoration: _done.contains(item) ? TextDecoration.lineThrough : null, decorationColor: G.faint)),
                ),
              ]),
            ),
          ),
        if (_done.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : () => _reset(clear: !_routine),
              style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
              child: Text(_routine ? 'Start again' : 'Clear what I got', style: G.text(16, w: FontWeight.w600, color: G.accent, height: 1.2)),
            ),
          ),
      ]),
    );
  }
}

// ---- a person --------------------------------------------------------------------------------------

class _PersonCard extends StatelessWidget {
  final Map<String, dynamic> note;
  const _PersonCard(this.note);

  @override
  Widget build(BuildContext context) {
    final meta = note['meta'] is Json ? note['meta'] as Json : const <String, dynamic>{};
    final phone = asStringOrNull(meta['phone']);
    final b = meta['birthday'] is Json ? meta['birthday'] as Json : null;
    final birthday = b == null ? null : '${asInt(b['day'])} ${_months[(asInt(b['month']) - 1).clamp(0, 11)]}';
    return _frame(
      child: Row(children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: G.surfaceHigh,
          child: Text('${note['title']}'.isEmpty ? '?' : '${note['title']}'.substring(0, 1).toUpperCase(), style: G.text(18, height: 1.2)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${note['title']}', style: G.text(19, height: 1.25)),
            Text(birthday == null ? (phone == null ? 'Nothing saved yet' : 'Number saved') : 'Birthday $birthday',
                style: G.text(15, color: G.muted, height: 1.25)),
          ]),
        ),
        if (phone != null) ...[
          IconButton(
            tooltip: 'Call',
            onPressed: () => openLink(context, 'tel:${dialNumber(phone)}'),
            icon: Icon(Icons.call_outlined, color: G.accent),
          ),
          IconButton(
            tooltip: 'WhatsApp',
            onPressed: () => openLink(context, 'https://wa.me/${dialNumber(phone).replaceAll(RegExp(r'\D'), '')}'),
            icon: Icon(Icons.chat_outlined, color: G.accent),
          ),
        ],
      ]),
    );
  }
}

// ---- the diet --------------------------------------------------------------------------------------

class _DietCard extends StatelessWidget {
  final Map<String, dynamic> note;
  const _DietCard(this.note);

  static const _order = ['all', '1', '2', '3', '4', '5', '6', '0'];

  @override
  Widget build(BuildContext context) {
    final meta = note['meta'] is Json ? note['meta'] as Json : const <String, dynamic>{};
    final days = meta['days'] is Json ? meta['days'] as Json : const <String, dynamic>{};
    final lines = <(String, String)>[];
    for (final k in _order) {
      final day = days[k];
      if (day is! Json || day.isEmpty) continue;
      final parts = [for (final m in const ['breakfast', 'lunch', 'snack', 'dinner']) if (day[m] != null) '$m ${day[m]}'];
      lines.add((k == 'all' ? 'Every day' : _weekdays[int.parse(k)], parts.join('; ')));
    }
    return _frame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (lines.isEmpty) Text('Say "Monday diet: oats and eggs for breakfast".', style: G.text(17, color: G.muted, height: 1.35)),
        for (final (day, meals) in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(day, style: G.text(19, w: FontWeight.w500, height: 1.25)),
              const SizedBox(height: 2),
              Text(meals, style: G.text(16, color: G.muted, height: 1.35)),
            ]),
          ),
      ]),
    );
  }
}

// ---- Watch later -------------------------------------------------------------------------------------

class WatchLaterSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback onChanged;
  const WatchLaterSection({super.key, required this.items, required this.onChanged});

  static String length(Object? minutes) {
    final m = minutes is num ? minutes.toInt() : null;
    if (m == null) return 'length unknown';
    return m < 60 ? '$m min' : '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60} min'}';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final repo = getIt<LifeRepository>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Watch later (${items.length})', style: G.text(16, w: FontWeight.w600)),
      const SizedBox(height: 2),
      Text('Ally brings one up when you have time.', style: G.label(size: 12, color: G.faint)),
      const SizedBox(height: 10),
      for (final s in items)
        _frame(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s['title']}', style: G.text(15, w: FontWeight.w600, height: 1.3)),
            const SizedBox(height: 2),
            Text(length(s['minutes']), style: G.label(size: 11, color: G.faint)),
            Row(children: [
              if (s['url'] != null)
                TextButton(
                  onPressed: () => openLink(context, '${s['url']}'),
                  child: Text('Open', style: G.label(size: 12, color: G.accent, w: FontWeight.w600)),
                ),
              TextButton(
                onPressed: () async {
                  try {
                    await repo.markSaveWatched('${s['id']}');
                    onChanged();
                  } on ApiException catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                },
                child: Text('Watched', style: G.label(size: 12, color: G.accent, w: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await repo.decideSave('${s['id']}', choice: 'DROP');
                    onChanged();
                  } on ApiException catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                },
                child: Text('Take it out', style: G.label(size: 12, color: G.muted, w: FontWeight.w600)),
              ),
            ]),
          ]),
        ),
      const SizedBox(height: 14),
    ]);
  }
}
