import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/service_locator.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/life_repository.dart';
import '../auth/bloc/auth_bloc.dart';
import 'first_run_data.dart';
import 'first_run_screen.dart';

/// A guest account goes through first run once; after that (saved or
/// "Later"), the app opens as normal. A saved account never sees it again.
class FirstRunGate extends StatefulWidget {
  final AppUser user;
  final Widget child;
  const FirstRunGate({super.key, required this.user, required this.child});

  @override
  State<FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends State<FirstRunGate> {
  bool? _done;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    var done = !widget.user.guest;
    if (!done) {
      try {
        done = (await SharedPreferences.getInstance()).getBool(FirstRunDraft.doneKey(widget.user.id)) ?? false;
      } catch (_) {}
    }
    if (mounted) setState(() => _done = done);
  }

  Future<void> _finished(AppUser? saved) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(FirstRunDraft.doneKey(widget.user.id), true);
    } catch (_) {}
    if (saved != null && mounted) context.read<AuthBloc>().add(AuthUserUpdated(saved));
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    if (done == null) return const SizedBox.shrink();
    if (done) return widget.child;
    final auth = getIt<AuthRepository>();
    return FirstRunScreen(repo: getIt<LifeRepository>(), claim: auth.claim, onDone: _finished);
  }
}
