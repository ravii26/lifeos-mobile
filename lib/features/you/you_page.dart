import 'package:flutter/material.dart';

import '../../design/appearance.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// The frame every You page shares: the new look, a title, loading, an error
/// with Try again, and the content once it is there.
class YouPage extends StatelessWidget {
  final String title;
  final String? sub;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final Future<void> Function()? onRefresh;
  final List<Widget> Function(BuildContext themed, AllyColors c) children;

  const YouPage({
    super.key,
    required this.title,
    this.sub,
    this.loading = false,
    this.error,
    this.onRetry,
    this.onRefresh,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Theme(data: AllyAppearance.themeOf(context), child: Builder(builder: _page));

  Widget _page(BuildContext themed) {
    final c = themed.ac;
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(Sp.side, 0, Sp.side, Sp.x6),
      children: [
        Text(title, style: AllyType.h1(color: c.ink)),
        if (sub != null) ...[const SizedBox(height: Sp.x1), Text(sub!, style: AllyType.body(color: c.muted))],
        const SizedBox(height: Sp.x5),
        if (loading)
          const Column(children: [AllySkeleton(height: 64, radius: Rad.card), SizedBox(height: Sp.x2), AllySkeleton(height: 64, radius: Rad.card)])
        else if (error != null)
          AllyNote(error!, actionLabel: onRetry == null ? null : 'Try again', onAction: onRetry)
        else
          Stagger(gap: Sp.x4, children: children(themed, c)),
      ],
    );
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(),
      body: onRefresh == null ? list : RefreshIndicator(color: c.ink, backgroundColor: c.raised, onRefresh: onRefresh!, child: list),
    );
  }
}

/// A card of rows separated by lines.
Widget youRows(AllyColors c, List<Widget> rows) => AllyCard(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x1),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(color: c.line, height: 1),
          rows[i],
        ],
      ]),
    );

/// "Today", "Yesterday", "Mon 16 Nov".
String dayHeading(DateTime d, DateTime now) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final a = DateTime(d.year, d.month, d.day), b = DateTime(now.year, now.month, now.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff == -1) return 'Tomorrow';
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
}

/// "18:30"
String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
