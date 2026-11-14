import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/intents/capture_intent_bus.dart';
import '../../core/notifications/agenda_sync.dart';
import '../../core/notifications/notification_service.dart';
import '../../data/models/user.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/tokens.dart';
import '../areas/areas_home_screen.dart';
import '../capture/capture_sheet.dart';
import '../chat/chat_cubit.dart';
import '../chat/chat_screen.dart';
import '../chat/starters.dart';
import '../guide/guide_style.dart';
import '../guide/save_sheet.dart';
import '../guide/tonight_cubit.dart';
import '../places/now_cubit.dart';
import '../places/now_screen.dart';
import '../places/you_screen.dart';
import '../today/today_screen.dart';
import 'life_cubit.dart';

// Where Ally lives: Now and My life, with Talk one tap from either.
const _nowPlace = 0;
const _lifePlace = 1;
const _talkPlace = 2;
const _areasPlace = 3;

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
  StreamSubscription<String>? _openedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // No permission pop-up here: notifications are asked for when the first
    // reminder is set, with the reason (doc 17).
    // Behaviour signal: the app was opened (once per session, on shell mount).
    getIt<LifeRepository>().recordBehavior('APP_OPEN').ignore();

    starterRequest.addListener(_toTalk);
    talkRequest.addListener(_openTalk);
    // What Ally says on its own follows every change (debounced), and a tapped
    // notification opens the right place (ADR 0027).
    placesRefresh.addListener(AgendaSync.soon);
    _openedSub = NotificationService.instance.opened.listen(_onNotificationOpened);
    NotificationService.instance.launchKind().then((k) {
      if (k != null) WidgetsBinding.instance.addPostFrameCallback((_) => _onNotificationOpened(k));
    }).ignore();

    final bus = getIt<CaptureIntentBus>();
    _captureIntentSub = bus.stream.listen(_handleCaptureIntent);
    final pending = bus.pending;
    if (pending != null) {
      bus.consumePending();
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _handleCaptureIntent(pending));
    }
  }

  /// The Sunday review opens the week in Talk; anything else opens Now.
  void _onNotificationOpened(String kind) {
    if (!mounted) return;
    final ctx = _cubitContext;
    final review = kind == 'WEEKLY_REVIEW' && ctx != null && ctx.mounted;
    setState(() => _index = review ? _talkPlace : _nowPlace);
    if (review) ctx.read<ChatCubit>().send('How was my week?').ignore();
  }

  void _openTalk() => setState(() => _index = _talkPlace);

  // A starter tapped on any screen: leave pages opened from My life and go to Talk.
  void _toTalk() {
    if (starterRequest.value == null) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (_index != _talkPlace) setState(() => _index = _talkPlace);
  }

  @override
  void dispose() {
    starterRequest.removeListener(_toTalk);
    talkRequest.removeListener(_openTalk);
    placesRefresh.removeListener(AgendaSync.soon);
    _openedSub?.cancel();
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
    AgendaSync.now();
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
        return PopScope(
          // Back from My life or Talk returns to Now; back on Now leaves the app.
          canPop: _index == _nowPlace,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setState(() => _index = _nowPlace);
          },
          child: Scaffold(
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
                  // Today replaces Now. The previous screen stays one tap away
                  // until its extras (counts, routine, meal, watch later) are rebuilt.
                  TodayScreen(
                    firstName: widget.user.firstName,
                    onOpenPrevious: () => _openPreviousNow(context),
                  ),
                  YouScreen(user: widget.user),
                  ChatScreen(onBack: () => setState(() => _index = _nowPlace)),
                  const AreasHomeScreen(),
                ],
              ),
            ),
            bottomNavigationBar: _index == _talkPlace
                ? null
                : _BottomNav(
                    index: _index,
                    onTalk: () => setState(() => _index = _talkPlace),
                    onTap: (i) {
                      setState(() => _index = i);
                      // Looking at a place again always shows what is true now.
                      placesRefresh.value++;
                    },
                  ),
          ),
        );
      }),
    );
  }

  void _openPreviousNow(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<LifeCubit>()),
          BlocProvider.value(value: context.read<TonightCubit>()),
          BlocProvider.value(value: context.read<NowCubit>()),
          BlocProvider.value(value: context.read<ChatCubit>()),
        ],
        child: Scaffold(
          backgroundColor: G.bg,
          appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0),
          body: const NowScreen(),
        ),
      ),
    ));
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

/// Today, Areas, the way to talk to Ally, and My life.
/// Today and Areas are in the new design; My life is still Plum until it is
/// rebuilt, so the bar takes the colours of the place it is showing.
class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onTalk;
  const _BottomNav({required this.index, required this.onTap, required this.onTalk});

  bool get _newLook => index == _nowPlace || index == _areasPlace;

  Widget _place(String label, int place) {
    const ally = AllyColors.dark;
    final on = index == place;
    final color = _newLook ? (on ? ally.ink : ally.muted) : (on ? G.ink : G.muted);
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(place),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: G.text(16, w: on ? FontWeight.w600 : FontWeight.w400, color: color, height: 1.2),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const ally = AllyColors.dark;
    return ColoredBox(
      color: _newLook ? ally.bg : G.bg,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(children: [
            _place('Today', _nowPlace),
            _place('Areas', _areasPlace),
            Expanded(
              child: Center(
                child: Material(
                  color: _newLook ? ally.raised : G.surfaceHigh,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTalk,
                    child: Semantics(
                      label: 'Talk to Ally',
                      button: true,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(Icons.mic_none_rounded, size: 25, color: _newLook ? ally.ink : G.ink),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _place('My life', _lifePlace),
          ]),
        ),
      ),
    );
  }
}
