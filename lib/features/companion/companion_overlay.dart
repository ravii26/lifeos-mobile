import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/decision.dart';
import '../now/decisions_cubit.dart';
import 'assistant_chat_sheet.dart';
import 'avatar_3d_webview.dart';

/// A persistent, real-time-3D "coach" companion that floats above every
/// screen and roams the app on its own (not drag-positioned — it moves
/// itself, on a timer, between a small set of resting spots).
///
/// Tap it and it fetches the current GET /decisions/now payload, shows a glass
/// speech bubble, and speaks the briefing aloud via on-device TTS. Long-press
/// it to open a real chat sheet (see [showAssistantChatSheet]) — the same
/// unified `/assistant/ask` persona the web overlay talks to. The character
/// itself is the same cel-shaded Three.js toon body as the web app, hosted in
/// a transparent WebView ([Avatar3DWebView]) — Flutter has no mature native
/// 3D renderer, so this reuses the web character wholesale rather than
/// building/maintaining a second one.
///
/// Mount it once, high in the tree (see main.dart) so it survives route pushes.
class CompanionOverlay extends StatefulWidget {
  const CompanionOverlay({super.key});

  @override
  State<CompanionOverlay> createState() => _CompanionState();
}

enum _Mode { idle, thinking, talking }

class _CompanionState extends State<CompanionOverlay> {
  final _tts = FlutterTts();

  _Mode _mode = _Mode.idle;
  DecisionResult? _result;
  bool _bubbleOpen = false;

  // Track the friendly-formatted texts
  String _friendlyHeadline = '';
  String _friendlyBriefing = '';
  String _friendlySpeech = '';

  // Position of the character's centre, as a fraction of the screen — driven
  // by [_roam], not drag. Starts at a predictable home corner.
  Offset _pos = const Offset(0.82, 0.8);
  Timer? _roamTimer;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRoaming());
  }

  // Wanders to a random point most of the time, occasionally resting back at
  // the home corner — same "ambient presence" idea as the web overlay, minus
  // the card-anchored peek states (mobile's Home tab has no single persistent
  // "What Now" card the way the web dashboard does, so there's nothing
  // stable to tuck behind/perch on here).
  void _startRoaming() {
    _reducedMotion = MediaQuery.of(context).disableAnimations;
    if (_reducedMotion) return; // stays at the initial home corner
    _scheduleNextRoam();
  }

  void _scheduleNextRoam() {
    _roamTimer = Timer(
      Duration(milliseconds: 4500 + math.Random().nextInt(3500)),
      () {
        if (!mounted || _bubbleOpen) {
          _scheduleNextRoam();
          return;
        }
        setState(() {
          _pos = math.Random().nextDouble() < 0.25
              ? const Offset(0.82, 0.8) // home corner
              : Offset(
                  0.12 + math.Random().nextDouble() * 0.76,
                  0.18 + math.Random().nextDouble() * 0.55,
                );
        });
        _scheduleNextRoam();
      },
    );
  }

  Future<void> _initTts() async {
    await _tts.setSpeechRate(0.50); // Faster, more energetic kid-like speed
    await _tts.setPitch(1.30); // Higher child-like pitch baseline
    await _tts.setVolume(1.0);
    _tts.setStartHandler(() {
      if (mounted) setState(() => _mode = _Mode.talking);
    });
    _tts.setCompletionHandler(_stopTalking);
    _tts.setCancelHandler(_stopTalking);
  }

  void _stopTalking() {
    if (mounted) setState(() => _mode = _Mode.idle);
  }

  @override
  void dispose() {
    _roamTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  // ── interaction ──────────────────────────────────────────────────────────
  Future<void> _onTap() async {
    // If it's talking, a tap silences it.
    if (_mode == _Mode.talking) {
      await _tts.stop();
      setState(() => _bubbleOpen = false);
      return;
    }
    // If a bubble is already open, tapping dismisses it.
    if (_bubbleOpen) {
      setState(() => _bubbleOpen = false);
      return;
    }
    await _speakNow();
  }

  Future<void> _speakNow() async {
    setState(() {
      _mode = _Mode.thinking;
      _bubbleOpen = true;
      _friendlyHeadline = '';
      _friendlyBriefing = '';
      _friendlySpeech = '';
    });
    try {
      await context.read<DecisionsCubit>().refresh();
      if (!mounted) return;
      final r = context.read<DecisionsCubit>().state.result;
      if (r == null) throw StateError('No decision result');

      final formatted = _formatKidFriendly(r);
      setState(() {
        _result = r;
        _friendlyHeadline = formatted.headline;
        _friendlyBriefing = formatted.briefing;
        _friendlySpeech = formatted.speechText;
      });
      await _tts.setPitch(_pitchFor(r.tone));
      await _tts.speak(_friendlySpeech);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mode = _Mode.idle;
        _result = null;
      });
    }
  }

  _FriendlyText _formatKidFriendly(DecisionResult r) {
    final tone = r.tone.toLowerCase();
    
    String intro = '';
    String outro = '';
    String actionPrompt = '';

    final rand = math.Random();

    if (tone == 'celebratory') {
      final intros = [
        'Woohoo! 🎉 ',
        'Yay, check us out! 🥳 ',
        'Oh my gosh, we did it! 🌟 ',
        'High five! 🙌 ',
      ];
      final outros = [
        ' You are the absolute best! 🚀',
        ' I\'m so, so proud of us! 🥰',
        ' We are totally crushing this! Let\'s go!',
      ];
      intro = intros[rand.nextInt(intros.length)];
      outro = outros[rand.nextInt(outros.length)];
      if (r.primaryAction != null) {
        actionPrompt = 'Next up, let\'s try: ${r.primaryAction!.title}!';
      }
    } else if (tone == 'encouraging') {
      final intros = [
        'Hey friend! ⭐ ',
        'Hi there! I believe in you! 💖 ',
        'Psst, you\'re doing amazing! ',
        'You\'ve got this! 🌈 ',
      ];
      final outros = [
        ' One step at a time, okay?',
        ' I\'m right here cheering you on! 📣',
        ' Let\'s make today super awesome!',
      ];
      intro = intros[rand.nextInt(intros.length)];
      outro = outros[rand.nextInt(outros.length)];
      if (r.primaryAction != null) {
        actionPrompt = 'How about we do this: ${r.primaryAction!.title}?';
      }
    } else if (tone == 'firm') {
      final intros = [
        'Listen up, buddy! ⏰ ',
        'Ahem, pay attention! 🧐 ',
        'Hey! Let\'s stay focused, okay? ',
        'No slacking off, my friend! 💪 ',
      ];
      final outros = [
        ' No procrastinating! Let\'s go!',
        ' Don\'t give up now, you can do it!',
        ' Let\'s cross this off the list together!',
      ];
      intro = intros[rand.nextInt(intros.length)];
      outro = outros[rand.nextInt(outros.length)];
      if (r.primaryAction != null) {
        actionPrompt = 'We really need to do this: ${r.primaryAction!.title}!';
      }
    } else {
      final intros = [
        'Hey buddy! 👋 ',
        'Hi! Check this out! ',
        'Look, look! 👀 ',
        'Here\'s what\'s up: ',
      ];
      final outros = [
        ' Let\'s do it!',
        ' Ready when you are! 🚀',
        ' Let\'s make some progress!',
      ];
      intro = intros[rand.nextInt(intros.length)];
      outro = outros[rand.nextInt(outros.length)];
      if (r.primaryAction != null) {
        actionPrompt = 'Let\'s do: ${r.primaryAction!.title}!';
      }
    }

    final headline = '$intro${r.headline.isEmpty ? 'Here\'s our plan!' : r.headline}';
    final briefing = r.briefing;
    
    final speechParts = <String>[
      headline,
      if (briefing.isNotEmpty) briefing,
      if (actionPrompt.isNotEmpty) actionPrompt,
      outro,
    ];

    return _FriendlyText(
      headline: headline,
      briefing: briefing,
      speechText: speechParts.join(' '),
    );
  }

  double _pitchFor(String tone) => switch (tone.toLowerCase()) {
        'celebratory' => 1.45,
        'encouraging' => 1.38,
        'firm' => 1.22,
        _ => 1.30,
      };

  Color _toneColor(String tone) => switch (tone) {
        'celebratory' => AppColors.accent,
        'encouraging' => AppColors.accent2,
        'firm' => const Color(0xFFFF8A65),
        _ => AppColors.tx3,
      };

  // ── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    const mascot = 112.0; // matches the web character's footprint — a real presence, not a corner badge

    final cx = (_pos.dx * size.width).clamp(mascot, size.width - mascot);
    final cy = (_pos.dy * size.height)
        .clamp(pad.top + mascot, size.height - pad.bottom - mascot);

    return Stack(
      children: [
        if (_bubbleOpen)
          _SpeechBubble(
            anchor: Offset(cx, cy),
            mascotRadius: mascot / 2,
            screen: size,
            mode: _mode,
            result: _result,
            friendlyHeadline: _friendlyHeadline,
            friendlyBriefing: _friendlyBriefing,
            toneColor: _result == null
                ? AppColors.tx3
                : _toneColor(_result!.tone),
            onClose: () => setState(() {
              _bubbleOpen = false;
              _tts.stop();
            }),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 1800),
          curve: Curves.easeInOut,
          left: cx - mascot / 2,
          top: cy - mascot / 2,
          width: mascot,
          height: mascot,
          child: AvatarTapListener(
            onTap: _onTap,
            onLongPress: () {
              if (_mode == _Mode.talking) _tts.stop();
              setState(() => _bubbleOpen = false);
              showAssistantChatSheet(context);
            },
            child: Avatar3DWebView(
              size: mascot,
              talking: _mode == _Mode.talking,
              thinking: _mode == _Mode.thinking,
              accent: _result == null
                  ? AppColors.accent
                  : _toneColor(_result!.tone),
            ),
          ),
        ),
      ],
    );
  }
}

/// Glass speech bubble that renders the coaching text near the mascot.
class _SpeechBubble extends StatelessWidget {
  final Offset anchor;
  final double mascotRadius;
  final Size screen;
  final _Mode mode;
  final DecisionResult? result;
  final String friendlyHeadline;
  final String friendlyBriefing;
  final Color toneColor;
  final VoidCallback onClose;

  const _SpeechBubble({
    required this.anchor,
    required this.mascotRadius,
    required this.screen,
    required this.mode,
    required this.result,
    required this.friendlyHeadline,
    required this.friendlyBriefing,
    required this.toneColor,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const width = 250.0;
    final left = (anchor.dx - width + mascotRadius)
        .clamp(12.0, screen.width - width - 12.0);
    final bottom = screen.height - (anchor.dy - mascotRadius - 10);

    return Positioned(
      left: left,
      bottom: bottom.clamp(80.0, screen.height - 120.0),
      width: width,
      child: Material(
        color: Colors.transparent,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Container(
            key: ValueKey(mode == _Mode.thinking),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
            decoration: BoxDecoration(
              color: AppColors.glassBg2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: toneColor.withValues(alpha: 0.45)),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black54,
                    blurRadius: 24,
                    offset: Offset(0, 10)),
              ],
            ),
            child: mode == _Mode.thinking || result == null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: toneColor),
                      ),
                      const SizedBox(width: 10),
                      Text('Thinking…',
                          style: TextStyle(
                              color: AppColors.tx3,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              friendlyHeadline.isEmpty
                                  ? 'Here\'s your read'
                                  : friendlyHeadline,
                              style: TextStyle(
                                  color: toneColor,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2),
                            ),
                          ),
                          GestureDetector(
                            onTap: onClose,
                            child: Icon(Icons.close_rounded,
                                size: 16, color: AppColors.tx4),
                          ),
                        ],
                      ),
                      if (friendlyBriefing.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(friendlyBriefing,
                            style: TextStyle(
                                color: AppColors.tx,
                                fontSize: 12.5,
                                height: 1.35)),
                      ],
                      if (result!.primaryAction != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: toneColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.bolt, size: 14, color: toneColor),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(
                                    result!.primaryAction!.title,
                                    style: TextStyle(
                                        color: AppColors.tx,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700),
                                  ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _FriendlyText {
  final String headline;
  final String briefing;
  final String speechText;

  const _FriendlyText({
    required this.headline,
    required this.briefing,
    required this.speechText,
  });
}
