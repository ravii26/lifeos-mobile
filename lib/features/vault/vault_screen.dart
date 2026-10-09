import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../data/models/vault_item.dart';
import '../../data/repositories/life_repository.dart';
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
  static const _icons = {
    'REFLECTION': Icons.format_quote,
    'MEMORY': Icons.trending_up,
    'MOTIVATION': Icons.gps_fixed,
    'RECOVERY': Icons.sticky_note_2_outlined,
  };
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: G.text(13.5, color: G.ink)),
      backgroundColor: G.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: G.lineSoft, width: 0.5),
      ),
    ));
  }

  Future<void> _markUsed(VaultItem v) async {
    try {
      await getIt<LifeRepository>().markVaultUsed(v.id);
      _snack('Pulled from the vault');
      _reload();
    } catch (_) {
      _snack('Could not record that');
    }
  }

  Future<void> _markHelpful(VaultItem v) async {
    try {
      await getIt<LifeRepository>().markVaultHelpful(v.id);
      _snack('Glad it helped');
      _reload();
    } catch (_) {
      _snack('Could not record that');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: G.bg,
      appBar: GTopBar(
        'Vault',
        subtitle: 'Support & hard-days reservoir',
        showBack: true,
        trailing: IconButton(
          icon: Icon(Icons.add, size: 20, color: G.accent),
          onPressed: () => _openForm(),
        ),
      ),
      body: FutureBuilder<List<VaultItem>>(
        future: _future,
        builder: (context, snap) {
          final all = snap.data ?? const [];
          final list = _filter == 'All'
              ? all
              : all.where((v) => v.vaultType.toUpperCase() == _filter).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: G.inset,
                  border: Border.all(color: G.lineSoft, width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.bookmark_border_rounded,
                        size: 16, color: G.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your reservoir of wins, quotes and protocols — pull from it when you need fuel.',
                        style: G.voice(13.5, color: G.muted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _kinds.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final k = _kinds[i];
                    final on = _filter == k;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = k),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: on ? G.accent.withValues(alpha: 0.15) : G.card,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: on ? G.accent : G.lineSoft,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          _label(k),
                          style: G.text(
                            12.5,
                            w: on ? FontWeight.w600 : FontWeight.w400,
                            color: on ? G.accent : G.muted,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (snap.connectionState != ConnectionState.done)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: G.accent,
                      strokeWidth: 1.5,
                    ),
                  ),
                )
              else if (list.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: G.card,
                    border: Border.all(color: G.lineSoft, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      'Nothing in the vault yet.\nSave words, wins or protocols here for when you have a hard day.',
                      textAlign: TextAlign.center,
                      style: G.voice(14, color: G.muted),
                    ),
                  ),
                )
              else
                for (final v in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => _openForm(item: v),
                      child: _card(v),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _card(VaultItem v) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: G.card,
          border: Border.all(color: G.lineSoft, width: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: G.accent.withValues(alpha: 0.12),
                        border: Border.all(
                            color: G.accent.withValues(alpha: 0.3), width: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _icons[v.vaultType.toUpperCase()] ??
                                Icons.sticky_note_2_outlined,
                            size: 11,
                            color: G.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _label(v.vaultType),
                            style: G.label(size: 10, color: G.accent),
                          ),
                        ],
                      ),
                    ),
                    if (_mediaIcons.containsKey(v.mediaType.toUpperCase())) ...[
                      const SizedBox(width: 6),
                      Icon(_mediaIcons[v.mediaType.toUpperCase()],
                          size: 13, color: G.faint),
                    ],
                  ],
                ),
                Text(
                  'used ${v.usedCount}×${v.helpfulCount > 0 ? ' · helped ${v.helpfulCount}×' : ''}',
                  style: G.label(size: 10, color: G.faint),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              v.title,
              style: G.text(15, w: FontWeight.w600, color: G.ink),
            ),
            if (v.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: G.lineSoft,
                      width: 1.5,
                    ),
                  ),
                ),
                child: Text(
                  v.content,
                  style: G.voice(13.5, color: G.muted),
                ),
              ),
            ],
            if (v.triggerTags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final t in v.triggerTags)
                    Text(
                      '#$t',
                      style: G.label(size: 11, color: G.faint),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _vaultAction(
                  Icons.bolt_outlined,
                  'Used it',
                  () => _markUsed(v),
                ),
                const SizedBox(width: 8),
                _vaultAction(
                  Icons.favorite_outline,
                  'This helped',
                  () => _markHelpful(v),
                  accent: true,
                ),
              ],
            ),
          ],
        ),
      );

  Widget _vaultAction(IconData icon, String label, VoidCallback onTap,
      {bool accent = false}) {
    final fg = accent ? G.good : G.muted;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: fg),
      label: Text(
        label,
        style: G.text(12, w: FontWeight.w500, color: fg),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        minimumSize: const Size(0, 30),
        side: BorderSide(
          color: accent ? G.good.withValues(alpha: 0.4) : G.lineSoft,
          width: 0.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  static String _label(String k) =>
      k == 'All' ? 'All' : k[0] + k.substring(1).toLowerCase();
}
