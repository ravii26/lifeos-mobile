import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/user.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/form_kit.dart' show gFieldStyle;
import '../auth/bloc/auth_bloc.dart';
import '../design_preview/design_preview_screen.dart';
import '../guide/guide_style.dart';

class SettingsScreen extends StatelessWidget {
  final AppUser user;
  const SettingsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: G.bg,
      appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
        children: [
          Text('Your data, your choice', style: G.text(42, w: FontWeight.w600, height: 1.06, letterSpacing: -1.2)),
          const SizedBox(height: 20),
          Row(children: [
            CircleAvatar(radius: 26, backgroundColor: G.accent, child: Text(user.initial, style: G.text(21, w: FontWeight.w600, color: G.onInk, height: 1.2))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.name, style: G.text(20, w: FontWeight.w500, height: 1.25)),
                Text(user.email, overflow: TextOverflow.ellipsis, style: G.text(16, color: G.muted, height: 1.25)),
              ]),
            ),
          ]),
          const SizedBox(height: 26),
          GPill('Download my data', primary: true, onTap: () => _export(context)),
          const SizedBox(height: 10),
          GPill('Sign out', onTap: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            context.read<AuthBloc>().add(const AuthLogoutRequested());
          }),
          const SizedBox(height: 10),
          // Temporary: lets the new design system be judged on a phone. Removed before launch.
          GPill('Preview the new design', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DesignPreviewScreen()))),
          const SizedBox(height: 34),
          Text('Deleting removes your goals, notes, memories and history. It cannot be undone.', style: G.text(17, color: G.muted, height: 1.4)),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: () => _delete(context),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFFB4A8), side: const BorderSide(color: Color(0xFFFFB4A8), width: 1.5), shape: const StadiumBorder()),
              child: Text('Delete my account', style: G.text(18, w: FontWeight.w500, color: const Color(0xFFFFB4A8), height: 1.2)),
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

  Future<void> _delete(BuildContext context) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (ctx) => DeleteAccountScreen(onDownload: () => _export(ctx)),
    ));
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

const _dangerColor = Color(0xFFFFB4A8);

/// Deleting is permanent, so the person types DELETE first. Pops true to go ahead.
class DeleteAccountScreen extends StatefulWidget {
  final VoidCallback onDownload;
  const DeleteAccountScreen({super.key, required this.onDownload});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _typed.text.trim() == 'DELETE';
    return Scaffold(
      backgroundColor: G.bg,
      appBar: gBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
        children: [
          const GTitle('Delete my account?', sub: "Deleting removes your goals, notes, memories and history. It can't be undone."),
          GPill('Download my data first', onTap: widget.onDownload),
          const SizedBox(height: 26),
          Text('Type DELETE to confirm', style: G.text(17, color: G.muted, height: 1.3)),
          const SizedBox(height: 10),
          TextField(
            controller: _typed,
            cursorColor: G.accent,
            textCapitalization: TextCapitalization.characters,
            style: G.text(20, height: 1.3),
            onChanged: (_) => setState(() {}),
            decoration: gFieldStyle('DELETE'),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 58,
            child: OutlinedButton(
              onPressed: ready ? () => Navigator.pop(context, true) : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: _dangerColor,
                side: BorderSide(color: _dangerColor.withValues(alpha: ready ? 1 : 0.35), width: 1.5),
                shape: const StadiumBorder(),
              ),
              child: Text('Delete forever', style: G.text(18, w: FontWeight.w500, color: _dangerColor.withValues(alpha: ready ? 1 : 0.5), height: 1.2)),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: G.ink, minimumSize: const Size(64, 48)),
            child: Text('Keep my account', style: G.text(18, height: 1.2)),
          ),
        ],
      ),
    );
  }
}
