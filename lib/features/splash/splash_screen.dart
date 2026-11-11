import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/bloc/auth_bloc.dart';
import '../guide/guide_style.dart';

/// Shown for a moment while the app starts and checks who is signed in.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _logoFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: G.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Spacer(flex: 5),
            FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(scale: _logoScale, child: const AllyOrb(size: 112)),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _textFade,
              child: Column(
                children: [
                  Text('Ally', style: G.text(44, w: FontWeight.w600, height: 1.05, letterSpacing: -1.3)),
                  const SizedBox(height: 6),
                  Text('Always on your side.', style: G.text(18, color: G.muted, height: 1.3)),
                ],
              ),
            ),
            const Spacer(flex: 5),
            FadeTransition(
              opacity: _textFade,
              child: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  if (state.error != null) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Can't connect right now.",
                            textAlign: TextAlign.center,
                            style: G.text(17, color: G.muted, height: 1.35),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            state.error!,
                            textAlign: TextAlign.center,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: G.text(15, color: G.faint, height: 1.3),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: 180,
                            child: GPill('Try again', onTap: () => context.read<AuthBloc>().add(const AuthStarted())),
                          ),
                        ],
                      ),
                    );
                  }
                  return SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: G.accent),
                  );
                },
              ),
            ),
            const SizedBox(height: 56),
          ],
        ),
      ),
    );
  }
}
