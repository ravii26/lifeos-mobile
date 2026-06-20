import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/vault_item.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  late Future<List<VaultItem>> _future;
  String _filter = 'All';
  static const _kinds = ['All', 'QUOTE', 'WIN', 'PROTOCOL', 'NOTE'];
  static const _icons = {
    'QUOTE': Icons.format_quote,
    'WIN': Icons.trending_up,
    'PROTOCOL': Icons.gps_fixed,
    'NOTE': Icons.sticky_note_2_outlined,
  };

  @override
  void initState() {
    super.initState();
    _future = getIt<LifeRepository>().vault();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FutureBuilder<List<VaultItem>>(
        future: _future,
        builder: (context, snap) {
          final all = snap.data ?? const [];
          final list = _filter == 'All'
              ? all
              : all.where((v) => v.vaultType.toUpperCase() == _filter).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const BackHeader(eyebrow: 'Support', title: 'Vault'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Your reservoir of wins, quotes and protocols — pull from it when you need fuel.',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.tx3, height: 1.5)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _kinds.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final k = _kinds[i];
                          final on = _filter == k;
                          return GestureDetector(
                            onTap: () => setState(() => _filter = k),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    on ? AppColors.accent : AppColors.surface2,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: on
                                        ? Colors.transparent
                                        : AppColors.line),
                              ),
                              child: Text(_label(k),
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: on
                                          ? AppColors.accentInk
                                          : AppColors.tx2)),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (snap.connectionState != ConnectionState.done)
                      Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.accent)),
                      )
                    else if (list.isEmpty)
                      SurfaceCard(
                        padding: EdgeInsets.all(26),
                        child: Center(
                            child: Text('Nothing in the vault yet.',
                                style: TextStyle(
                                    color: AppColors.tx4, fontSize: 13))),
                      )
                    else
                      for (final v in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 11),
                          child: _card(v),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card(VaultItem v) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip3(_label(v.vaultType),
                    icon: _icons[v.vaultType.toUpperCase()] ??
                        Icons.sticky_note_2_outlined,
                    color: AppColors.accent,
                    bg: AppColors.accentSoft),
                Text('used ${v.usedCount}×',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 10, color: AppColors.tx4)),
              ],
            ),
            const SizedBox(height: 11),
            Text(v.title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            if (v.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(v.content,
                  style: TextStyle(
                      fontSize: 13.5, color: AppColors.tx2, height: 1.55)),
            ],
            if (v.triggerTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final t in v.triggerTags) Chip3('#$t')],
              ),
            ],
          ],
        ),
      );

  static String _label(String k) =>
      k == 'All' ? 'All' : k[0] + k.substring(1).toLowerCase();
}
