import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../chat/memories_screen.dart';
import '../guide/guide_style.dart';
import '../guide/save_sheet.dart';
import '../more/taught_notes_screen.dart';
import '../more/your_day_screen.dart';
import '../shell/life_cubit.dart';
import '../vault/vault_screen.dart';
import 'now_cubit.dart';

/// Notes: what you taught Ally, what you saved, and what Ally knows about you.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _repo = getIt<LifeRepository>();
  List<Json> _saves = const [];
  int _taught = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    placesRefresh.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    placesRefresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_repo.saves(), _repo.allyNotes()]);
      if (!mounted) return;
      setState(() {
        _saves = results[0];
        _taught = results[1].length;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _push(Widget page) {
    final life = context.read<LifeCubit>();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BlocProvider.value(value: life, child: page))).then((_) => _load());
  }

  Future<void> _openSave(Json s) async {
    final changed = await openSaveSheet(context, SaveSource(existingId: '${s['id']}'));
    if (changed) placesRefresh.value++;
    _load();
  }

  Widget _row(String title, String sub, VoidCallback onTap, {String action = 'Open', bool last = false}) =>
      GRow(title, sub, onTap, action: action, last: last);

  Widget _heading(String text) => GHeading(text);

  @override
  Widget build(BuildContext context) {
    final waiting = _saves.where((s) => s['shelved'] != true).toList();
    final shelf = _saves.where((s) => s['shelved'] == true).length;
    return ColoredBox(
      color: G.bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 40),
            children: [
              Text('Notes', style: G.display(36)),
              const SizedBox(height: 6),
              Text('What you taught me, what you saved, and what I know about you.', style: G.voice(17)),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: G.text(14, color: G.muted))),
              _heading('Taught to Ally'),
              _row('Notes you taught', _taught == 0 ? 'Lists, routines and info I answer from' : '$_taught saved', () => _push(const TaughtNotesScreen()), last: true),
              _heading('Saves'),
              if (waiting.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Nothing waiting. Share a video or reel to Ally and I will work out what it is for.', style: G.text(14, color: G.muted, height: 1.5))),
              for (final s in waiting) _row('${s['title']}', 'To learn. Tap to choose what to do with it.', () => _openSave(s)),
              _row('Kept for hard days', shelf == 0 ? 'Videos and quotes that help when a day is heavy' : '$shelf waiting for the day you need them', () => _push(const VaultScreen()), last: true),
              _heading('About you'),
              _row('Your day', 'How I think your days run, and your mode', () => _push(const YourDayScreen())),
              _row('What Ally remembers', 'See, mark private, or forget anything', () => _push(const MemoriesScreen()), last: true),
            ],
          ),
        ),
      ),
    );
  }
}
