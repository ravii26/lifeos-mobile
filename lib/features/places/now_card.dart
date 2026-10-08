import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../guide/guide_style.dart';
import 'now_cubit.dart';

/// The right thing for right now, at the top of Now. One thing, sized for the
/// time you have, and three plain answers. Nothing here counts or scolds.
class NowCard extends StatelessWidget {
  const NowCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NowCubit, NowState>(
      listenWhen: (a, b) => b.error != null && a.error != b.error,
      listener: (context, s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.error!))),
      builder: (context, s) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _body(context, s),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, NowState s) {
    if (s.status == NowStatus.loading) {
      return Text('Looking at your day…', style: G.voice(16));
    }
    if (s.status == NowStatus.error) {
      return Text("I can't reach the server right now. Chat still works, and I'll have your day when it's back.",
          style: G.text(14, color: G.muted));
    }
    final cubit = context.read<NowCubit>();
    final o = s.current;
    final children = <Widget>[];

    if (s.prep.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text("Tonight's prep: ${s.prep.join('; ')}.", style: G.voice(15)),
      ));
    }

    if (o == null || s.kind != 'PICK') {
      // Rest, or nothing waiting: Ally says so in a sentence. No list, no count.
      children.add(Text(s.options.isEmpty ? s.message : "That's all I'd suggest right now. Rest is fine too.", style: G.voice(18, color: G.ink)));
      if (s.note != null) children.add(_note(s.note!));
      if (s.undoId != null) children.add(_UndoLine(onUndo: cubit.undo));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
    }

    final shown = o.smaller ? o.minimum.replaceAll(RegExp(r'\.$'), '') : o.title;
    children.addAll([
      Text(shown, style: G.display(26, w: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(
        [if (o.minutes > 0) '${o.minutes} min', if (o.why.isNotEmpty) o.why].join(' · '),
        style: G.text(14, color: G.muted),
      ),
      if (o.smaller && o.title != shown) ...[
        const SizedBox(height: 2),
        Text('The small version of: ${o.title}', style: G.text(13, color: G.muted)),
      ],
      const SizedBox(height: 10),
      Row(children: [
        _Answer('Done', strong: true, onTap: s.busy ? null : cubit.done),
        const SizedBox(width: 22),
        _Answer('Smaller', onTap: s.busy ? null : cubit.smaller),
        const SizedBox(width: 22),
        _Answer('Not now', onTap: s.busy ? null : cubit.notNow),
      ]),
    ]);
    if (s.later.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text('Then: ${s.later.map((l) => l.title).join(' · ')}', style: G.text(13, color: G.muted)),
      ));
    }
    if (s.note != null) children.add(_note(s.note!));
    if (s.undoId != null) children.add(_UndoLine(onUndo: cubit.undo));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _note(String text) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(text, style: G.text(13, color: G.muted)));
}

class _Answer extends StatelessWidget {
  final String label;
  final bool strong;
  final VoidCallback? onTap;
  const _Answer(this.label, {this.strong = false, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(label,
              style: strong
                  ? G.text(17, w: FontWeight.w800, color: onTap == null ? G.muted : G.ink).copyWith(decoration: TextDecoration.underline)
                  : G.text(16, w: FontWeight.w600, color: G.muted)),
        ),
      );
}

class _UndoLine extends StatelessWidget {
  final VoidCallback onUndo;
  const _UndoLine({required this.onUndo});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Text('Logged. ', style: G.text(13, color: G.muted)),
          InkWell(onTap: onUndo, child: Text('Undo', style: G.text(13, w: FontWeight.w700))),
        ]),
      );
}
