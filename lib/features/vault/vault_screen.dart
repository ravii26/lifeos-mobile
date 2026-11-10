import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../data/models/vault_item.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/form_kit.dart' show selChip;
import '../guide/guide_style.dart';
import 'vault_form.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  late Future<List<VaultItem>> _future;
  String _filter = 'All';
  static const _kinds = ['All', 'REFLECTION', 'MEMORY', 'MOTIVATION', 'RECOVERY'];
  static const _mediaIcons = {
    'QUOTE': Icons.format_quote,
    'VIDEO': Icons.videocam_outlined,
    'AUDIO': Icons.mic_outlined,
    'IMAGE': Icons.image_outlined,
  };

  @override
  void initState() {
    super.initState();
    _future = getIt<LifeRepository>().vault();
  }

  void _reload() => setState(() => _future = getIt<LifeRepository>().vault());

  Future<void> _openForm({VaultItem? item}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VaultForm(item: item),
    );
    if (changed == true) _reload();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _markUsed(VaultItem v) async {
    try {
      await getIt<LifeRepository>().markVaultUsed(v.id);
      _snack('Noted');
      _reload();
    } catch (_) {
      _snack("Couldn't save that. Try again.");
    }
  }

  Future<void> _markHelpful(VaultItem v) async {
    try {
      await getIt<LifeRepository>().markVaultHelpful(v.id);
      _snack('Glad it helped');
      _reload();
    } catch (_) {
      _snack("Couldn't save that. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: G.bg,
      appBar: gBar(actions: [
        IconButton(
          tooltip: 'Add to the Vault',
          icon: Icon(Icons.add_rounded, size: 28, color: G.accent),
          onPressed: () => _openForm(),
        ),
      ]),
      body: FutureBuilder<List<VaultItem>>(
        future: _future,
        builder: (context, snap) {
          final all = snap.data ?? const [];
          final list = _filter == 'All'
              ? all
              : all.where((v) => v.vaultType.toUpperCase() == _filter).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
            children: [
              const GTitle('Vault', sub: 'Words and wins to come back to on a hard day.'),
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _kinds.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => selChip(_label(_kinds[i]), _filter == _kinds[i], () => setState(() => _filter = _kinds[i])),
                ),
              ),
              const SizedBox(height: 14),
              if (snap.connectionState != ConnectionState.done)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator(color: G.accent, strokeWidth: 2)),
                )
              else if (list.isEmpty)
                const GEmpty('Nothing here yet. Keep the words or wins you want to find on a hard day.')
              else
                for (final v in list) _card(v),
            ],
          );
        },
      ),
    );
  }

  Widget _card(VaultItem v) {
    final mediaIcon = _mediaIcons[v.mediaType.toUpperCase()];
    final uses = [
      if (v.usedCount > 0) 'Used ${v.usedCount} ${v.usedCount == 1 ? 'time' : 'times'}',
      if (v.helpfulCount > 0) 'helped ${v.helpfulCount} ${v.helpfulCount == 1 ? 'time' : 'times'}',
    ].join(', ');
    return GCard(
      onTap: () => _openForm(item: v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(_label(v.vaultType), style: G.text(16, color: G.accent, height: 1.2)),
            if (mediaIcon != null) ...[
              const SizedBox(width: 8),
              Icon(mediaIcon, size: 18, color: G.accent),
            ],
          ]),
          const SizedBox(height: 6),
          Text(v.title, style: G.text(23, w: FontWeight.w500, height: 1.2)),
          if (v.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(v.content, style: G.text(17, color: G.muted, height: 1.4)),
          ],
          if (v.triggerTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('For when: ${v.triggerTags.join(', ')}', style: G.text(15, color: G.muted, height: 1.3)),
          ],
          if (uses.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('$uses.', style: G.text(15, color: G.muted, height: 1.3)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _action('Used it', () => _markUsed(v))),
              const SizedBox(width: 8),
              Expanded(child: _action('This helped', () => _markHelpful(v))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action(String label, VoidCallback onTap) => SizedBox(
        height: 48,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(backgroundColor: G.surfaceHigh, foregroundColor: G.ink, shape: const StadiumBorder()),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: G.text(16, height: 1.2))),
        ),
      );

  static String _label(String k) =>
      k == 'All' ? 'All' : k[0] + k.substring(1).toLowerCase();
}
