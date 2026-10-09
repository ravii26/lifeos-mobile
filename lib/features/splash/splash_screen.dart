import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/bloc/auth_bloc.dart';
import '../guide/guide_style.dart';

/// Branded launch screen shown while the app boots / resolves auth state.
///
/// Nocturne Sanctuary: calm bedtime threshold mark with subtle fade.
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
              child: Transform.scale(
                scale: _logoScale.value,
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: G.lineSoft, width: 0.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/logo/app_icon.png',
                      width: 108,
                      height: 108,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _textFade,
              child: Column(
                children: [
                  Text(
                    'Ally',
                    style: G.voice(24, color: G.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Always on your side.',
                    style: G.label(size: 11.5, color: G.muted),
                  ),
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
                            "Connecting to server…",
                            textAlign: TextAlign.center,
                            style: G.voice(13.5, color: G.muted),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton(
                            onPressed: () => context
                                .read<AuthBloc>()
                                .add(const AuthStarted()),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: G.lineSoft, width: 0.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 8),
                            ),
                            child: Text('Retry',
                                style: G.label(size: 11, color: G.accent)),
                          ),
                        ],
                      ),
                    );
                  }
                  return SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: G.accent,
                    ),
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
