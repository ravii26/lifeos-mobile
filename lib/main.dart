import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/api/api_client.dart';
import 'core/di/service_locator.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/life_repository.dart';
import 'features/appearance/appearance_cubit.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await setupLocator();
  await NotificationService.instance.init();
  runApp(const LifeOSApp());
}

class LifeOSApp extends StatelessWidget {
  const LifeOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (_) =>
                AuthBloc(getIt<AuthRepository>())..add(const AuthStarted())),
        BlocProvider(
            create: (_) => AppearanceCubit(getIt<LifeRepository>())..load()),
      ],
      child: Builder(builder: (context) {
        // Sign the user out when any API call returns 401.
        getIt<ApiClient>().onUnauthorized =
            () => context.read<AuthBloc>().add(const AuthLogoutRequested());

        return BlocBuilder<AppearanceCubit, AppearanceState>(
          builder: (context, appearance) => MaterialApp(
            title: 'LifeOS',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(
                accent: appearance.accent,
                font: appearance.font,
                light: appearance.light),
            builder: (context, child) {
              // Status bar icons follow the theme; density scales text app-wide.
              SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: appearance.light
                    ? Brightness.dark
                    : Brightness.light,
              ));
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                    textScaler: TextScaler.linear(appearance.textScale)),
                child: child!,
              );
            },
            home: const _Root(),
          ),
        );
      }),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return switch (state.status) {
          AuthStatus.authenticated => HomeShell(user: state.user!),
          AuthStatus.unauthenticated ||
          AuthStatus.authenticating =>
            const LoginScreen(),
          AuthStatus.unknown => const SplashScreen(),
        };
      },
    );
  }
}
