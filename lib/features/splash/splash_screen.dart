import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../auth/bloc/auth_bloc.dart';

/// Branded launch screen shown while the app boots / resolves auth state.
///
/// Mirrors the native splash (same logo on the same background) so the hand-off
/// from the OS splash to Flutter is seamless, then animates the mark in with a
/// soft accent glow and a quiet loading hint.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _pulse;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _logoFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );

    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Spacer(flex: 5),
            // Logo with breathing accent glow.
            AnimatedBuilder(
              animation: Listenable.merge([_intro, _pulse]),
              builder: (context, child) {
                final glow = 0.45 + (_pulse.value * 0.55);
                return FadeTransition(
                  opacity: _logoFade,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentGlow
                                .withValues(alpha: AppColors.accentGlow.a * glow),
                            blurRadius: 48 + (_pulse.value * 16),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/logo/app_icon.png',
                  width: 116,
                  height: 116,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: _textFade,
              child: Column(
                children: [
                  Text(
                    'LifeOS',
                    style: TextStyle(
                      color: AppColors.tx,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your life, in command.',
                    style: TextStyle(
                      color: AppColors.tx3,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
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
                            "Having trouble reaching the server — this can "
                            "take up to a minute if it's been asleep.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.tx3,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton(
                            onPressed: () => context
                                .read<AuthBloc>()
                                .add(const AuthStarted()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.tx,
                              side: BorderSide(color: AppColors.line2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  return SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
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
