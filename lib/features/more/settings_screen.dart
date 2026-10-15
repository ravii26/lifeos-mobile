import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/user.dart';
import '../../data/repositories/life_repository.dart';
import '../appearance/appearance_cubit.dart';
import '../appearance/tweaks_sheet.dart';
import '../auth/bloc/auth_bloc.dart';
import '../guide/guide_style.dart';

class SettingsScreen extends StatelessWidget {
  final AppUser user;
  const SettingsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: G.bg,
      appBar: const GTopBar(
        'Settings',
        subtitle: 'Account & preferences',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: G.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: G.lineSoft, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: G.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: G.accent.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      user.initial,
                      style: G.text(18,
                          w: FontWeight.w700, color: G.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: G.text(16,
                            w: FontWeight.w600, color: G.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: G.label(size: 11, color: G.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: G.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: G.lineSoft, width: 0.5),
            ),
            child: Row(
              children: [
                BlocBuilder<AppearanceCubit, AppearanceState>(
                  builder: (context, s) => Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: s.accent.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appearance & Taste',
                        style: G.text(14,
                            w: FontWeight.w500, color: G.ink),
                      ),
                      Text(
                        'Accent tone, dark mode & font',
                        style: G.label(size: 11, color: G.faint),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    final cubit = context.read<AppearanceCubit>();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => BlocProvider.value(
                        value: cubit,
                        child: const TweaksSheet(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: G.lineSoft, width: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                  child: Text('Adjust',
                      style: G.label(size: 11, color: G.accent)),
                ),
              ],
            ),
          ),
          const GHeading('Your data'),
          GRow('Download your data', 'Everything Ally has, as one file you can save or send', () => _export(context),
              action: 'Download'),
          GRow('Delete account', 'Removes your account and everything in it. Cannot be undone', () => _delete(context),
              action: 'Delete', last: true),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<AuthBloc>().add(const AuthLogoutRequested());
              },
              icon: Icon(Icons.logout_rounded, size: 16, color: G.carried),
              label: Text('Sign out',
                  style: G.text(13.5,
                      w: FontWeight.w500, color: G.carried)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: G.carried.withValues(alpha: 0.35),
                  width: 0.5,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Ally · Personal Assistant · Nocturne Sanctuary',
              style: G.label(size: 10, color: G.faint),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Getting your data…')));
    try {
      final data = await getIt<LifeRepository>().exportData();
      final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
      final name = 'ally-data-${DateTime.now().toIso8601String().substring(0, 10)}.json';
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/json', name: name)],
        fileNameOverrides: [name],
        subject: 'My Ally data',
      ));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't prepare the file. Try again.")));
    }
  }

  // Permanent, so the person types DELETE first.
  Future<void> _delete(BuildContext context) async {
    final typed = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Delete your account?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Everything goes: to-dos, habits, notes, saves, reminders. This cannot be undone. '
                'Download your data first if you want a copy.\n\nType DELETE to confirm.'),
            const SizedBox(height: 12),
            TextField(controller: typed, autofocus: true, onChanged: (_) => setState(() {})),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
            TextButton(
              onPressed: typed.text.trim() == 'DELETE' ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await getIt<LifeRepository>().deleteAccount();
      if (!context.mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      context.read<AuthBloc>().add(const AuthLogoutRequested());
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
