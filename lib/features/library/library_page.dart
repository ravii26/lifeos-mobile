import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../core/links/open_link.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../places/now_cubit.dart' show placesRefresh;
import '../talk/talk_screen.dart' show talkPrefill;
import '../you/you_page.dart';
import 'library_words.dart';
import 'save_flow.dart';

enum LibrarySection { notes, people, saved }

/// Opens Talk with words to finish, from any page.
void tellAlly(BuildContext context, String words) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  talkPrefill.value = words;
}

/// Library: Notes (lists, rules, text), People (what they told you, when you
/// last spoke) and Saved (links, waiting, to watch, for a low day).
class LibraryPage extends StatefulWidget {
  final LifeRepository repo;
  final LibrarySection start;
  final DateTime Function()? clock;
  const LibraryPage({super.key, required this.repo, this.start = LibrarySection.notes, this.clock});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late LibrarySection _section = widget.start;
  List<NoteJson>? _notes;
  List<Map<String, dynamic>>? _saves;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([widget.repo.allyNotes(), widget.repo.saves()]);
      if (!mounted) return;
      setState(() {
        _notes = r[0];
        _saves = r[1];
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && _notes == null) setState(() => _error = e.message);
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    await _load();
  }

  Future<void> _decideSave(BuildContext themed, String id) async {
    if (await openSaveFlow(themed, SaveSource(existingId: id), repo: widget.repo)) placesRefresh.value++;
    await _load();
  }

  Future<void> _newSave(BuildContext themed) async {
    if (await openPasteSaveFlow(themed, repo: widget.repo)) placesRefresh.value++;
    await _load();
  }

  /// The weekly clean-up: keep the two newest waiting saves, the rest go to
  /// watch later. Nothing is deleted, and one Undo puts them all back.
  Future<void> _tidy(BuildContext themed, List<Map<String, dynamic>> rest) async {
    try {
      final r = await widget.repo.decideManySaves([for (final s in rest) '${s['id']}'], 'LATER');
      await _load();
      final undo = r.activityId;
      final repo = widget.repo;
      if (themed.mounted) {
        showAllyToast(themed, '${r.count} moved to watch later.', onUndo: undo == null ? null : () async {
          try {
            await repo.undo(undo);
            await _load();
          } on ApiException catch (_) {}
        });
      }
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  Future<void> _watched(BuildContext themed, Map<String, dynamic> s) async {
    try {
      await widget.repo.markSaveWatched('${s['id']}');
      await _load();
      if (themed.mounted) showAllyToast(themed, 'Off the watch-later list.');
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => YouPage(
        title: 'Library',
        loading: _notes == null && _error == null,
        error: _notes == null ? _error : null,
        onRetry: _load,
        onRefresh: _load,
        children: (themed, c) => [
          AllySegmented<LibrarySection>(
            options: const {LibrarySection.notes: 'Notes', LibrarySection.people: 'People', LibrarySection.saved: 'Saved'},
            value: _section,
            onChanged: (s) => setState(() => _section = s),
          ),
          ...switch (_section) {
            LibrarySection.notes => _notesList(themed, c),
            LibrarySection.people => _peopleList(themed, c),
            LibrarySection.saved => _savedList(themed, c),
          },
        ],
      );

  Widget _row(AllyColors c, {required String title, required String tag, Widget? lead, VoidCallback? onTap, Widget? trail}) => Pressable(
        scale: 0.985,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.x3),
            child: Row(children: [
              if (lead != null) ...[lead, const SizedBox(width: Sp.x3)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: AllyType.body(color: c.ink)),
                  Text(tag, maxLines: 2, overflow: TextOverflow.ellipsis, style: AllyType.small(color: c.faint)),
                ]),
              ),
              trail ?? (onTap == null ? const SizedBox.shrink() : Icon(Icons.chevron_right_rounded, color: c.faint)),
            ]),
          ),
        ),
      );

  List<Widget> _notesList(BuildContext themed, AllyColors c) {
    final notes = _notes!.where((n) => !isPerson(n)).toList();
    return [
      if (notes.isEmpty)
        Text('No notes yet. Tell Ally things like "my breakfast options are poha, eggs, oats" and they land here.', style: AllyType.body(color: c.muted))
      else
        youRows(c, [
          for (final n in notes)
            _row(c, title: '${n['title']}', tag: noteTag(n), onTap: () => _open(NotePage(note: n, repo: widget.repo))),
        ]),
      AllyButton('New note: just tell Ally', kind: AllyButtonKind.secondary, icon: Icons.add_rounded, wide: true,
          onPressed: () => tellAlly(context, 'Remember this as a note: ')),
    ];
  }

  List<Widget> _peopleList(BuildContext themed, AllyColors c) {
    final people = _notes!.where(isPerson).toList();
    final now = (widget.clock ?? DateTime.now)();
    return [
      if (people.isEmpty)
        Text('Nobody here yet. Tell Ally things like "Asha\'s birthday is 12 March" or "Ravi told me he moved to Pune".', style: AllyType.body(color: c.muted))
      else
        youRows(c, [
          for (final p in people)
            _row(c,
                title: '${p['title']}',
                tag: personLine(p, now),
                lead: _Initial('${p['title']}'),
                onTap: () => _open(PersonPage(person: p, repo: widget.repo, clock: widget.clock))),
        ]),
      Text('Private. Nothing here is shown on the lock screen.', style: AllyType.small(color: c.faint)),
    ];
  }

  List<Widget> _savedList(BuildContext themed, AllyColors c) {
    final saves = _saves ?? const [];
    final waiting = saves.where((s) => s['shelved'] != true && s['later'] != true).toList();
    final later = saves.where((s) => s['later'] == true).toList();
    final low = saves.where((s) => s['shelved'] == true).toList();
    String title(Map<String, dynamic> s) => asString(s['title']).isEmpty ? asString(s['url'], 'Saved link') : asString(s['title']);
    Widget group(String head, List<Widget> rows) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(head, style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x2),
          youRows(c, rows),
        ]);
    return [
      if (saves.isEmpty) Text('Nothing saved yet.', style: AllyType.body(color: c.muted)),
      if (waiting.length > 3)
        AllyCard(
          strong: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${waiting.length} waiting for a decision', style: AllyType.h2(color: c.ink)),
            const SizedBox(height: Sp.x1),
            Text('Keep the two newest to decide now, and put the rest in watch later? Nothing is deleted.', style: AllyType.body(color: c.muted)),
            const SizedBox(height: Sp.x3),
            Align(
              alignment: Alignment.centerLeft,
              child: AllyButton('Move ${waiting.length - 2} to watch later', kind: AllyButtonKind.secondary, onPressed: () => _tidy(themed, waiting.skip(2).toList())),
            ),
          ]),
        ),
      if (waiting.isNotEmpty)
        group('WAITING FOR A DECISION', [
          for (final s in waiting) _row(c, title: title(s), tag: 'Decide what it is for', onTap: () => _decideSave(themed, '${s['id']}')),
        ]),
      if (later.isNotEmpty)
        group('TO WATCH', [
          for (final s in later)
            _row(c,
                title: title(s),
                tag: [asStringOrNull(s['platform']), if (s['minutes'] != null) '${asInt(s['minutes'])} min'].whereType<String>().join(' · '),
                trail: AllyButton('Watched', kind: AllyButtonKind.ghost, semanticLabel: 'Watched: ${title(s)}', onPressed: () => _watched(themed, s))),
        ]),
      if (low.isNotEmpty)
        group('FOR A LOW DAY', [
          for (final s in low) _row(c, title: title(s), tag: 'Shown when you tap "I\'m feeling…"'),
        ]),
      AllyButton('Save a link', kind: AllyButtonKind.secondary, icon: Icons.add_rounded, wide: true, onPressed: () => _newSave(themed)),
      Text('In the app you are watching, tap Share and pick Ally.', style: AllyType.small(color: c.faint)),
    ];
  }
}

class _Initial extends StatelessWidget {
  final String name;
  final double size;
  const _Initial(this.name, {this.size = 40});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.raised, shape: BoxShape.circle),
        child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(), style: AllyType.body(color: c.ink, w: FontWeight.w600)),
      ),
    );
  }
}

/// One note, as what it is: a list with ticks, rules read in order, or text.
class NotePage extends StatefulWidget {
  final NoteJson note;
  final LifeRepository repo;
  const NotePage({super.key, required this.note, required this.repo});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  late final Set<String> _done = doneOf(widget.note);
  late bool _whenNeeded = whenNeededOf(widget.note);

  Future<void> _setWhenNeeded(BuildContext themed, bool on) async {
    setState(() => _whenNeeded = on);
    try {
      final undo = await widget.repo.setWhenNeeded('${widget.note['id']}', on);
      final repo = widget.repo;
      if (!themed.mounted) return;
      showAllyToast(themed, on ? 'Ally shows these before a matching event.' : 'Shown only here now.', onUndo: undo == null
          ? null
          : () async {
              try {
                await repo.undo(undo);
                if (mounted) setState(() => _whenNeeded = !on);
              } on ApiException catch (_) {}
            });
    } on ApiException catch (e) {
      if (mounted) setState(() => _whenNeeded = !on);
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  Future<void> _tick(BuildContext themed, String item) async {
    final now = !_done.contains(item);
    setState(() => now ? _done.add(item) : _done.remove(item));
    try {
      await widget.repo.tickNote('${widget.note['id']}', item, now);
    } on ApiException catch (e) {
      if (mounted) setState(() => now ? _done.remove(item) : _done.add(item));
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  Future<void> _delete(BuildContext themed) async {
    try {
      final undoId = await widget.repo.deleteAllyNote('${widget.note['id']}');
      if (!themed.mounted) return;
      final repo = widget.repo;
      showAllyToast(themed, 'Note deleted.', onUndo: undoId == null ? null : () => repo.undo(undoId).catchError((_) {}));
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    final items = itemsOf(n);
    final text = textOf(n);
    return YouPage(
      title: '${n['title']}',
      sub: noteTag(n),
      children: (themed, c) => [
        if (isDiet(n))
          youRows(c, [
            for (final (day, meals) in dietLines(n))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.x3),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(day, style: AllyType.body(color: c.ink, w: FontWeight.w600)),
                  Text(meals, style: AllyType.small(color: c.muted)),
                ]),
              ),
          ])
        else if (items.isNotEmpty)
          youRows(c, [
            for (var i = 0; i < items.length; i++)
              hasTicks(n)
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: Sp.x2),
                      child: Row(children: [
                        Expanded(
                          child: Text(items[i],
                              style: AllyType.body(color: _done.contains(items[i]) ? c.faint : c.ink)
                                  .copyWith(decoration: _done.contains(items[i]) ? TextDecoration.lineThrough : null)),
                        ),
                        AllyCheck(done: _done.contains(items[i]), semanticLabel: 'Tick ${items[i]}', onTap: () => _tick(themed, items[i])),
                      ]),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: Sp.x3),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 28, child: Text('${i + 1}', style: AllyType.num(color: c.faint))),
                        Expanded(child: Text(items[i], style: AllyType.body(color: c.ink))),
                      ]),
                    ),
          ]),
        if (text != null) AllyCard(child: Text(text, style: AllyType.body(color: c.ink))),
        if (items.isNotEmpty && !hasTicks(n) && !isDiet(n))
          AllyCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Show me these when I need them', style: AllyType.body(color: c.ink, w: FontWeight.w600)),
                  Text('Before something on your day that matches, like a party or an interview.', style: AllyType.small(color: c.muted)),
                ]),
              ),
              const SizedBox(width: Sp.x2),
              AllySwitch(value: _whenNeeded, semanticLabel: 'Show me these when I need them', onChanged: (v) => _setWhenNeeded(themed, v)),
            ]),
          ),
        if (items.isEmpty && text == null && !isDiet(n)) Text('Nothing in this note yet.', style: AllyType.body(color: c.muted)),
        Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
          AllyButton('Add to this note', kind: AllyButtonKind.secondary, onPressed: () => tellAlly(context, 'Add to my "${n['title']}" note: ')),
          AllyButton('Delete', kind: AllyButtonKind.ghost, onPressed: () => _delete(themed)),
        ]),
      ],
    );
  }
}

/// One person: what they told you, when you last spoke, and a way to get in touch.
class PersonPage extends StatelessWidget {
  final NoteJson person;
  final LifeRepository repo;
  final DateTime Function()? clock;

  /// For tests: opening a call or WhatsApp.
  final void Function(BuildContext context, String url)? open;
  const PersonPage({super.key, required this.person, required this.repo, this.clock, this.open});

  void _contact(BuildContext context, String phone, {required bool whatsApp}) {
    final url = whatsApp ? 'https://wa.me/${dialable(phone).replaceAll(RegExp(r'\D'), '')}' : 'tel:${dialable(phone)}';
    (open ?? openLink)(context, url);
    // So Ally knows when you last spoke.
    repo.personContacted('${person['id']}').catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final name = '${person['title']}';
    final told = itemsOf(person);
    final phone = phoneOfNote(person);
    return YouPage(
      title: name,
      sub: personLine(person, (clock ?? DateTime.now)()),
      children: (themed, c) => [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('THINGS THEY TOLD YOU', style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x2),
          if (told.isEmpty)
            Text('Nothing yet. Tell Ally, for example "$name told me about a new job".', style: AllyType.body(color: c.muted))
          else
            youRows(c, [
              for (final t in told) Padding(padding: const EdgeInsets.symmetric(vertical: Sp.x3), child: Text(t, style: AllyType.body(color: c.ink))),
            ]),
          if (textOf(person) != null) ...[
            const SizedBox(height: Sp.x3),
            AllyCard(child: Text(textOf(person)!, style: AllyType.body(color: c.ink))),
          ],
        ]),
        _DraftCard(person: person, repo: repo, phone: phone, open: open),
        if (phone != null)
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            AllyButton('Call', icon: Icons.call_outlined, kind: AllyButtonKind.secondary, onPressed: () => _contact(context, phone, whatsApp: false)),
            AllyButton('WhatsApp', icon: Icons.chat_outlined, kind: AllyButtonKind.secondary, onPressed: () => _contact(context, phone, whatsApp: true)),
          ]),
        AllyButton('Add something about $name', kind: AllyButtonKind.ghost, onPressed: () => tellAlly(context, 'About $name: ')),
        Text('Private. Nothing here is shown on the lock screen.', style: AllyType.small(color: c.faint)),
      ],
    );
  }
}

/// A message Ally drafts for this person (ALLY.md 5.2 #17). Ally never sends
/// it: Copy, or open WhatsApp with it filled in, and the person sends it.
class _DraftCard extends StatefulWidget {
  final NoteJson person;
  final LifeRepository repo;
  final String? phone;
  final void Function(BuildContext context, String url)? open;
  const _DraftCard({required this.person, required this.repo, this.phone, this.open});

  @override
  State<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<_DraftCard> {
  String? _draft;
  bool _byCode = false;
  bool _busy = false;

  Future<void> _write() async {
    setState(() => _busy = true);
    try {
      final r = await widget.repo.draftForPerson('${widget.person['id']}');
      if (mounted) {
        setState(() {
          _draft = r.message;
          _byCode = r.byCode;
          _busy = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _busy = false);
      if (mounted) showAllyToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final draft = _draft;
    if (draft == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: AllyButton(_busy ? 'Writing…' : 'Draft a message', kind: AllyButtonKind.secondary, icon: Icons.edit_note_rounded, onPressed: _busy ? null : _write),
      );
    }
    return AllyCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text("ALLY'S DRAFT · YOU SEND IT", style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x2),
        Text(draft, style: AllyType.body(color: c.ink)),
        if (_byCode) ...[const SizedBox(height: Sp.x1), Text('A plain opener, written without AI.', style: AllyType.small(color: c.faint))],
        const SizedBox(height: Sp.x3),
        Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
          AllyButton('Copy', kind: AllyButtonKind.secondary, icon: Icons.copy_rounded, onPressed: () async {
            await Clipboard.setData(ClipboardData(text: draft));
            if (context.mounted) showAllyToast(context, 'Copied. Ally never sends messages for you.');
          }),
          if (widget.phone != null)
            AllyButton('Open in WhatsApp', kind: AllyButtonKind.secondary, onPressed: () {
              final number = dialable(widget.phone!).replaceAll(RegExp(r'\D'), '');
              (widget.open ?? openLink)(context, 'https://wa.me/$number?text=${Uri.encodeComponent(draft)}');
              widget.repo.personContacted('${widget.person['id']}').catchError((_) {});
            }),
          AllyButton('Another', kind: AllyButtonKind.ghost, onPressed: _busy ? null : _write),
        ]),
      ]),
    );
  }
}
