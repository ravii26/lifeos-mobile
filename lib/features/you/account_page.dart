import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/user.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/appearance.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'you_page.dart';

/// Account and privacy: who is signed in, plainly what goes to AI, your data
/// to download, sign out, and deleting the account (typed to confirm).
class AccountPage extends StatelessWidget {
  final AppUser user;
  final LifeRepository repo;
  final VoidCallback onSignOut;

  /// The design preview, for building only; null hides it.
  final VoidCallback? onDesignPreview;

  /// Hands the export file to the phone's share sheet. Replaceable in tests.
  final Future<void> Function(List<int> bytes, String name)? share;

  const AccountPage({super.key, required this.user, required this.repo, required this.onSignOut, this.onDesignPreview, this.share});

  Future<void> _export(BuildContext themed) async {
    showAllyToast(themed, 'Getting your data…');
    try {
      final data = await repo.exportData();
      final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
      final name = 'ally-data-${DateTime.now().toIso8601String().substring(0, 10)}.json';
      if (share != null) {
        await share!(bytes, name);
      } else {
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/json', name: name)],
          fileNameOverrides: [name],
          subject: 'My Ally data',
        ));
      }
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    } catch (_) {
      if (themed.mounted) showAllyToast(themed, "Couldn't prepare the file. Try again.");
    }
  }

  Future<void> _delete(BuildContext themed) async {
    final ok = await Navigator.of(themed).push<bool>(MaterialPageRoute(builder: (_) => _DeleteScreen(onDownload: () => _export(themed))));
    if (ok != true || !themed.mounted) return;
    try {
      await repo.deleteAccount();
      if (!themed.mounted) return;
      Navigator.of(themed).popUntil((r) => r.isFirst);
      onSignOut();
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => YouPage(
        title: 'Account and privacy',
        children: (themed, c) => [
          AllyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.name, style: AllyType.h2(color: c.ink)),
              Text(user.email, style: AllyType.body(color: c.muted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('WHAT GOES TO AI', style: AllyType.eyebrow(color: c.faint)),
            const SizedBox(height: Sp.x2),
            AllyCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _line(c, Icons.cloud_upload_outlined,
                    'When you talk to Ally, save a link or photo, or ask for a draft plan, three tastes or help deciding: what you wrote or said, and the parts of your life needed to answer (like your areas and things Ally remembers).'),
                _line(c, Icons.rule_rounded,
                    "Worked out by rules on Ally's server, without AI: today's one thing, free time, your areas and week, reminders, routines and tracked numbers."),
                _line(c, Icons.lock_outline_rounded, "Memories you mark private aren't brought up unless you raise them."),
              ]),
            ),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('YOUR DATA', style: AllyType.eyebrow(color: c.faint)),
            const SizedBox(height: Sp.x2),
            AllyButton('Download my data', kind: AllyButtonKind.secondary, icon: Icons.download_rounded, wide: true, onPressed: () => _export(themed)),
            const SizedBox(height: Sp.x2),
            AllyButton('Sign out', kind: AllyButtonKind.secondary, wide: true, onPressed: onSignOut),
            const SizedBox(height: Sp.x2),
            AllyButton('Delete my account', kind: AllyButtonKind.danger, wide: true, onPressed: () => _delete(themed)),
          ]),
          if (onDesignPreview != null)
            AllyButton('Preview the design (for building)', kind: AllyButtonKind.ghost, wide: true, onPressed: onDesignPreview),
        ],
      );

  Widget _line(AllyColors c, IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.x2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: c.muted),
          const SizedBox(width: Sp.x3),
          Expanded(child: Text(text, style: AllyType.body(color: c.ink))),
        ]),
      );
}

/// Deleting is permanent, so DELETE is typed first. Pops true to go ahead.
class _DeleteScreen extends StatefulWidget {
  final VoidCallback onDownload;
  const _DeleteScreen({required this.onDownload});

  @override
  State<_DeleteScreen> createState() => _DeleteScreenState();
}

class _DeleteScreenState extends State<_DeleteScreen> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(data: AllyAppearance.themeOf(context), child: Builder(builder: _page));

  Widget _page(BuildContext themed) {
    final c = themed.ac;
    final ready = _typed.text.trim() == 'DELETE';
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.side, 0, Sp.side, Sp.x6), children: [
        Text('Delete your account?', style: AllyType.h1(color: c.ink)),
        const SizedBox(height: Sp.x2),
        Text("This removes your areas, goals, steps, routines, notes, memories and history. It can't be undone.",
            style: AllyType.body(color: c.muted)),
        const SizedBox(height: Sp.x4),
        AllyButton('Download my data first', kind: AllyButtonKind.secondary, wide: true, onPressed: widget.onDownload),
        const SizedBox(height: Sp.x5),
        Text('Type DELETE to confirm', style: AllyType.body(color: c.ink)),
        const SizedBox(height: Sp.x2),
        TextField(
          controller: _typed,
          textCapitalization: TextCapitalization.characters,
          style: AllyType.h2(color: c.ink),
          decoration: const InputDecoration(hintText: 'DELETE'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Sp.x4),
        AllyButton('Delete forever', kind: AllyButtonKind.danger, wide: true, onPressed: ready ? () => Navigator.of(context).pop(true) : null),
        AllyButton('Keep my account', kind: AllyButtonKind.ghost, wide: true, onPressed: () => Navigator.of(context).pop(false)),
      ]),
    );
  }
}
