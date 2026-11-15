import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/ally_theme.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// One match from `GET /search`.
class SearchHit {
  final String kind; // NOTE | TASK | SAVE | PROJECT | MEMORY
  final String id;
  final String title;
  final String snippet;
  const SearchHit(this.kind, this.id, this.title, this.snippet);

  factory SearchHit.fromJson(Json j) => SearchHit(asString(j['kind']), asString(j['id']), asString(j['title']), asString(j['snippet']));

  String get label => switch (kind) {
        'NOTE' => 'Note',
        'TASK' => 'To-do',
        'SAVE' => 'Saved',
        'PROJECT' => 'Goal',
        'MEMORY' => 'Ally remembers',
        _ => '',
      };

  IconData get icon => switch (kind) {
        'NOTE' => Icons.sticky_note_2_outlined,
        'TASK' => Icons.check_circle_outline_rounded,
        'SAVE' => Icons.play_circle_outline_rounded,
        'PROJECT' => Icons.flag_outlined,
        'MEMORY' => Icons.auto_awesome_outlined,
        _ => Icons.search_rounded,
      };
}

/// Search: one box across notes, to-dos, saves, goals and what Ally remembers.
class SearchPage extends StatefulWidget {
  final LifeRepository repo;

  /// Opens a match; the page passes what was tapped.
  final void Function(SearchHit hit)? onOpen;
  const SearchPage({super.key, required this.repo, this.onOpen});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _q = TextEditingController();
  Timer? _wait;
  List<SearchHit>? _hits;
  bool _loading = false;
  String? _error;
  int _asked = 0;

  @override
  void dispose() {
    _wait?.cancel();
    _q.dispose();
    super.dispose();
  }

  // A short pause after typing, so each letter is not a request.
  void _changed(String v) {
    _wait?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        _hits = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    _wait = Timer(const Duration(milliseconds: 350), () => _search(v.trim()));
  }

  Future<void> _search(String q) async {
    final asking = ++_asked;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = (await widget.repo.search(q)).map(SearchHit.fromJson).toList();
      if (!mounted || asking != _asked) return;
      setState(() {
        _hits = r;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || asking != _asked) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(data: AllyTheme.dark(), child: Builder(builder: _page));

  Widget _page(BuildContext themed) {
    final c = themed.ac;
    final hits = _hits;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: Sp.side),
          child: TextField(
            controller: _q,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: AllyType.body(color: c.ink),
            decoration: const InputDecoration(hintText: 'Search notes, to-dos, saves, goals', prefixIcon: Icon(Icons.search_rounded)),
            onChanged: _changed,
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) _search(v.trim());
            },
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x3, Sp.side, Sp.x6),
        children: [
          if (_loading)
            const Column(children: [AllySkeleton(height: 60, radius: Rad.card), SizedBox(height: Sp.x2), AllySkeleton(height: 60, radius: Rad.card)])
          else if (_error != null)
            AllyNote(_error!, actionLabel: 'Try again', onAction: () => _search(_q.text.trim()))
          else if (hits == null)
            Text('Find anything you told Ally or saved. Words or meaning both work.', style: AllyType.body(color: c.muted))
          else if (hits.isEmpty)
            Text('Nothing matches "${_q.text.trim()}".', style: AllyType.body(color: c.muted))
          else
            for (final h in hits) ...[
              AllyCard(
                onTap: widget.onOpen == null ? null : () => widget.onOpen!(h),
                padding: const EdgeInsets.all(Sp.x4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(h.icon, color: c.muted, size: 20),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(h.label.toUpperCase(), style: AllyType.eyebrow(color: c.faint)),
                      const SizedBox(height: 2),
                      Text(h.title, style: AllyType.body(color: c.ink, w: FontWeight.w500)),
                      if (h.snippet.isNotEmpty && h.snippet != h.title)
                        Text(h.snippet, maxLines: 2, overflow: TextOverflow.ellipsis, style: AllyType.small(color: c.muted)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: Sp.x2),
            ],
        ],
      ),
    );
  }
}
