import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/intents/capture_intent_bus.dart';
import '../../core/notifications/notification_service.dart';
import '../../data/models/user.dart';
import '../../data/repositories/life_repository.dart';
import '../capture/capture_sheet.dart';
import '../chat/chat_cubit.dart';
import '../chat/chat_screen.dart';
import '../guide/guide_style.dart';
import '../guide/save_sheet.dart';
import '../guide/tonight_cubit.dart';
import '../places/notes_screen.dart';
import '../places/now_cubit.dart';
import '../places/plan_screen.dart';
import '../places/you_screen.dart';
import 'life_cubit.dart';

/// The four places Ally lives in (plan §5). Plain text labels on purpose:
/// the look is decided in the design step, the structure is decided here.
const _tabLabels = ['Now', 'Plan', 'Notes', 'You'];

class HomeShell extends StatefulWidget {
  final AppUser user;
  const HomeShell({super.key, required this.user});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  // The `LifeCubit`-scoped context, captured each build — needed so a
  // capture intent (share/voice) that arrives outside the widget tree's own
  // event handlers can still open the Capture sheet with the Cubit in scope.
  BuildContext? _cubitContext;
  StreamSubscription<PendingCaptureIntent>? _captureIntentSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.requestPermission();
    // Behaviour signal: the app was opened (once per session, on shell mount).
    getIt<LifeRepository>().recordBehavior('APP_OPEN').ignore();

    final bus = getIt<CaptureIntentBus>();
    _captureIntentSub = bus.stream.listen(_handleCaptureIntent);
    final pending = bus.pending;
    if (pending != null) {
      bus.consumePending();
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _handleCaptureIntent(pending));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _captureIntentSub?.cancel();
    super.dispose();
  }

  /// Back in the app: send anything done offline, then refresh the card and
  /// answer chat messages written without a connection.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final context = _cubitContext;
    getIt<LifeRepository>().syncOffline().then((_) {
      if (context == null || !context.mounted) return;
      context.read<TonightCubit>().load();
      context.read<NowCubit>().load();
      context.read<ChatCubit>().retryPending();
      placesRefresh.value++;
    }).ignore();
  }

  void _handleCaptureIntent(PendingCaptureIntent intent) {
    getIt<CaptureIntentBus>().consumePending();
    final context = _cubitContext;
    if (context == null || !context.mounted) return;
    // A shared link or screenshot is a save: turn it into an action instead
    // of filing it. Plain shared text stays a normal capture.
    final isSave = intent.fromShare &&
        (intent.imagePath != null ||
            RegExp(r'https?://').hasMatch(intent.text ?? ''));
    if (isSave) {
      final tonight = context.read<TonightCubit>();
      final now = context.read<NowCubit>();
      openSaveSheet(
        context,
        SaveSource(
            text: intent.text,
            imagePath: intent.imagePath,
            imageMime: intent.imageMime),
      ).then((changed) {
        if (changed) {
          tonight.load();
          now.load();
          placesRefresh.value++;
        }
      });
      return;
    }
    _openCapture(context, pending: intent);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LifeCubit(getIt<LifeRepository>())..load()),
        // Still loaded: it schedules the nightly nudge and answers it from the notification.
        BlocProvider(create: (_) => TonightCubit(getIt<LifeRepository>())..load()),
        BlocProvider(create: (_) => NowCubit(getIt<LifeRepository>())..load()),
        BlocProvider(create: (_) => ChatCubit(getIt<LifeRepository>())),
      ],
      child: Builder(builder: (context) {
        _cubitContext = context;
        return Scaffold(
          backgroundColor: G.bg,
          body: BlocListener<LifeCubit, LifeState>(
            listenWhen: (prev, curr) => curr.error != null && curr.error != prev.error,
            listener: (context, state) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.error!)));
              context.read<LifeCubit>().clearError();
            },
            child: IndexedStack(
              index: _index,
              children: [
                const ChatScreen(),
                const PlanScreen(),
                const NotesScreen(),
                YouScreen(user: widget.user),
              ],
            ),
          ),
          bottomNavigationBar: _BottomNav(
            index: _index,
            onTap: (i) {
              setState(() => _index = i);
              // Looking at a place again always shows what is true now.
              placesRefresh.value++;
            },
          ),
        );
      }),
    );
  }

  void _openCapture(BuildContext context, {PendingCaptureIntent? pending}) {
    final cubit = context.read<LifeCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: CaptureSheet(
          initialText: pending?.text,
          initialImagePath: pending?.imagePath,
          initialImageMime: pending?.imageMime,
          autoStartVoice: pending?.startVoice ?? false,
        ),
      ),
    );
  }
}

/// Bottom navigation — Nocturne design: icon + label, active tab in primary
/// accent with a small dot indicator below, inactive in muted tone.
/// Icons: nightlight (Now), calendar_today (Plan), edit_note (Notes), person (You).
class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  static const _icons = [
    Icons.bedtime_outlined,        // Now  — matches reference "nightlight"
    Icons.calendar_today_outlined, // Plan — calendar_today
    Icons.edit_note_outlined,      // Notes — stylus_note
    Icons.person_outline_rounded,  // You  — person
  ];

  static const _iconsFilled = [
    Icons.bedtime_rounded,
    Icons.calendar_today_rounded,
    Icons.edit_note_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: G.bg,
        border: Border(top: BorderSide(color: G.lineSoft, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < _tabLabels.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          index == i ? _iconsFilled[i] : _icons[i],
                          size: 22,
                          color: index == i ? G.accent : G.faint,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _tabLabels[i],
                          style: G.label(
                            size: 11,
                            color: index == i ? G.accent : G.faint,
                            w: index == i ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Active dot indicator below the label
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: index == i ? 4 : 0,
                          height: index == i ? 4 : 0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: G.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
