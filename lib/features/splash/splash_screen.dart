import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../design/appearance.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../auth/bloc/auth_bloc.dart';

/// Shown for a moment while the app starts and checks who is signed in.
/// New look: the name, one line, and a quiet wait; an error with Try again.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  bool _started = false;

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: AllyAppearance.themeOf(context), child: Builder(builder: _page));
  }

  Widget _page(BuildContext themed) {
    final c = themed.ac;
    if (!_started) {
      _started = true;
      Motion.reduced(themed) ? _intro.value = 1 : _intro.forward();
    }
    final fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: fade,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Ally', style: AllyType.h1(color: c.ink).copyWith(fontSize: 44)),
                  const SizedBox(height: Sp.x1),
                  Text('Plan less. Do more.', style: AllyType.body(color: c.muted)),
                  const SizedBox(height: Sp.x6),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      if (state.error != null) {
                        return Column(mainAxisSize: MainAxisSize.min, children: [
                          Text("Can't connect right now.", textAlign: TextAlign.center, style: AllyType.body(color: c.ink)),
                          const SizedBox(height: Sp.x1),
                          Text(state.error!,
                              textAlign: TextAlign.center,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: AllyType.small(color: c.faint)),
                          const SizedBox(height: Sp.x3),
                          AllyButton('Try again',
                              kind: AllyButtonKind.secondary, onPressed: () => context.read<AuthBloc>().add(const AuthStarted())),
                        ]);
                      }
                      return SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: c.muted));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
