import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/user.dart';
import '../../data/repositories/life_repository.dart';
import '../areas/areas_screen.dart';
import '../auth/bloc/auth_bloc.dart';
import '../goals/goals_screen.dart';
import '../guide/guide_setup_sheet.dart';
import '../guide/guide_style.dart';
import '../more/settings_screen.dart';
import '../more/where_you_stand_screen.dart';
import '../shell/life_cubit.dart';

/// You: where you stand, what matters now, your week on request, and settings.
class YouScreen extends StatelessWidget {
  final AppUser user;
  const YouScreen({super.key, required this.user});

  void _push(BuildContext context, Widget page, {String? title}) {
    final life = context.read<LifeCubit>();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: life,
        child: title == null
            ? page
            : Scaffold(
                backgroundColor: G.bg,
                appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0, title: Text(title, style: G.text(17, w: FontWeight.w700))),
                body: page,
              ),
      ),
    ));
  }

  // The weekly card is only ever shown when asked for.
  Future<void> _week(BuildContext context) async {
    final repo = getIt<LifeRepository>();
    String text;
    try {
      text = await repo.weekCard();
    } on ApiException catch (e) {
      text = e.message;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Your week', style: G.voice(24, color: G.ink)),
        content: Text(text, style: G.text(15, height: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Widget _row(String title, String sub, VoidCallback onTap, {bool last = false}) => GRow(title, sub, onTap, last: last);

  Widget _heading(String text) => GHeading(text);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: G.bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 40),
          children: [
            Text('You', style: G.display(36)),
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(user.name.isNotEmpty ? user.name : user.email, style: G.text(13, color: G.muted))),
            _heading('How you are doing'),
            _row('Where you stand', 'Stage, trend and pace on each goal', () => _push(context, const WhereYouStandScreen())),
            _row('Your week', 'Only when you ask. Never on a schedule', () => _week(context), last: true),
            _heading('What matters now'),
            _row('Areas', 'Main, Secondary, Maintain, Later', () => _push(context, AreasScreen(onOpenMore: () {}), title: 'Areas')),
            _row('Goals', 'What you are aiming at', () => _push(context, const GoalsScreen())),
            _row('Goals and nudges', 'Set up what Ally may remind you about', () => openGuideSetup(context), last: true),
            _heading('Settings'),
            _row('Settings', 'Profile and preferences', () => _push(context, SettingsScreen(user: user)), last: true),
            InkWell(
              onTap: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Text('Sign out', style: G.text(14, color: G.muted))),
            ),
          ],
        ),
      ),
    );
  }
}
