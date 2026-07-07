import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/api/api_client.dart';
import 'core/deeplink/deep_link_service.dart';
import 'core/di/service_locator.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widget/widget_sync_service.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/life_repository.dart';
import 'features/appearance/appearance_cubit.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/login_screen.dart';
import 'features/companion/companion_overlay.dart';
import 'features/now/decisions_cubit.dart';
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
  await getIt<WidgetSyncService>().init();
  runApp(const LifeOSApp());
  // Deferred to after the first frame so `rootNavigatorKey.currentState` is
  // attached before a cold-start `lifeos://` link tries to push a route.
  WidgetsBinding.instance
      .addPostFrameCallback((_) => DeepLinkService(rootNavigatorKey).init());
}

/// Used by [DeepLinkService] to push routes (e.g. the focus screen) from
/// outside the widget tree when the app is opened via a `lifeos://` link.
final rootNavigatorKey = GlobalKey<NavigatorState>();

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
        BlocProvider(
            create: (_) => DecisionsCubit(getIt<LifeRepository>())),
      ],
      child: Builder(builder: (context) {
        // Sign the user out when any API call returns 401.
        getIt<ApiClient>().onUnauthorized =
            () => context.read<AuthBloc>().add(const AuthLogoutRequested());

        return BlocListener<AuthBloc, AuthState>(
          listenWhen: (prev, curr) => prev.status != curr.status,
          listener: (context, auth) {
            // Reset cached appearance/module prefs on sign-out, and reload
            // for whichever user just signed in, so a shared device never
            // shows one user's settings while another is briefly active.
            final appearance = context.read<AppearanceCubit>();
            final decisions = context.read<DecisionsCubit>();
            if (auth.status == AuthStatus.authenticated) {
              appearance.load();
              decisions.refresh();
            } else if (auth.status == AuthStatus.unauthenticated) {
              appearance.reset();
              decisions.reset();
              getIt<WidgetSyncService>().clear();
            }
          },
          child: BlocBuilder<AppearanceCubit, AppearanceState>(
            builder: (context, appearance) => MaterialApp(
              navigatorKey: rootNavigatorKey,
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
                  // Float the coach companion above every route, but only once
                  // the user is signed in.
                  child: Stack(
                    children: [
                      child!,
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, auth) =>
                            auth.status == AuthStatus.authenticated
                                ? const CompanionOverlay()
                                : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              },
              home: const _Root(),
            ),
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
