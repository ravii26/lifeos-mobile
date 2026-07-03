import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/decision.dart';
import '../now/decisions_cubit.dart';

/// A persistent, draggable "coach" companion that floats above every screen.
///
/// Tap it and it fetches the current GET /decisions/now payload, shows a glass
/// speech bubble, and speaks the briefing aloud via on-device TTS. The mascot
/// itself is drawn with a [CustomPainter] (no external asset), so it runs out
/// of the box. To swap in a real Rive 2.5D character later, replace the
/// [_Mascot] widget with a `RiveAnimation.asset(...)` and drive its state
/// machine from [_CompanionState.mode] — nothing else needs to change.
///
/// Mount it once, high in the tree (see main.dart) so it survives route pushes.
class CompanionOverlay extends StatefulWidget {
  const CompanionOverlay({super.key});

  @override
  State<CompanionOverlay> createState() => _CompanionState();
}

enum _Mode { idle, thinking, talking }

class _CompanionState extends State<CompanionOverlay>
    with TickerProviderStateMixin {
  final _tts = FlutterTts();
  late final AnimationController _idle; // bob + blink loop
  late final AnimationController _mouth; // drives talking mouth

  _Mode _mode = _Mode.idle;
  DecisionResult? _result;
  bool _bubbleOpen = false;

  // Track the friendly-formatted texts
  String _friendlyHeadline = '';
  String _friendlyBriefing = '';
  String _friendlySpeech = '';

  // Position of the mascot's centre, as a fraction of the screen (draggable).
  Offset _pos = const Offset(0.86, 0.78);

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
    _mouth = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setSpeechRate(0.50); // Faster, more energetic kid-like speed
    await _tts.setPitch(1.30); // Higher child-like pitch baseline
    await _tts.setVolume(1.0);
    _tts.setStartHandler(() {
      if (mounted) setState(() => _mode = _Mode.talking);
      _mouth.repeat(reverse: true);
    });
    _tts.setCompletionHandler(_stopTalking);
    _tts.setCancelHandler(_stopTalking);
  }

  void _stopTalking() {
    _mouth.stop();
    _mouth.value = 0;
    if (mounted) setState(() => _mode = _Mode.idle);
  }

  @override
  void dispose() {
    _idle.dispose();
    _mouth.dispose();
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
    const mascot = 64.0;

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
        Positioned(
          left: cx - mascot / 2,
          top: cy - mascot / 2,
          width: mascot,
          height: mascot,
          child: GestureDetector(
            onTap: _onTap,
            onPanUpdate: (d) => setState(() {
              _pos = Offset(
                (cx + d.delta.dx) / size.width,
                (cy + d.delta.dy) / size.height,
              );
            }),
            child: _Mascot(
              idle: _idle,
              mouth: _mouth,
              mode: _mode,
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

/// The mascot itself — a glowing orb with ears, sprout, rosy cheeks, and expressive animations.
class _Mascot extends StatelessWidget {
  final Animation<double> idle;
  final Animation<double> mouth;
  final _Mode mode;
  final Color accent;
  const _Mascot({
    required this.idle,
    required this.mouth,
    required this.mode,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([idle, mouth]),
      builder: (context, _) {
        final phase = idle.value * 2 * math.pi;
        // Bouncy floating animation
        final bob = math.sin(phase) * 4.0;
        
        // Squash and stretch animations (squashes when bobbing reverses direction)
        final scaleY = 1.0 + math.cos(phase * 2) * 0.05;
        final scaleX = 1.0 - math.cos(phase * 2) * 0.05;
        
        // Gentle rotation sway that is out of phase with bobbing
        final tilt = math.sin(phase - math.pi / 4) * 0.06;

        // Blink logic: eyes closed at the end of the idle animation loop
        final blink = idle.value > 0.93 ? 1.0 : 0.0;
        final mouthOpen = mode == _Mode.talking ? mouth.value : 0.0;

        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: tilt,
            child: Transform.scale(
              scaleX: scaleX,
              scaleY: scaleY,
              alignment: Alignment.center,
              child: CustomPaint(
                painter: _MascotPainter(
                  accent: accent,
                  blink: blink,
                  mouthOpen: mouthOpen,
                  thinking: mode == _Mode.thinking,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MascotPainter extends CustomPainter {
  final Color accent;
  final double blink; // 0 open, 1 closed
  final double mouthOpen; // 0..1
  final bool thinking;
  _MascotPainter({
    required this.accent,
    required this.blink,
    required this.mouthOpen,
    required this.thinking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8; // slightly smaller to give ears/sprout space

    // 1. Outer body glow
    canvas.drawCircle(
      c,
      r + 4,
      Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // 2. Cute rounded helper ears (drawn behind body)
    final leftEarCenter = Offset(c.dx - r * 0.75, c.dy - r * 0.75);
    final rightEarCenter = Offset(c.dx + r * 0.75, c.dy - r * 0.75);
    final earRadius = r * 0.38;

    final earPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, AppColors.surface2],
      ).createShader(Rect.fromCircle(center: c, radius: r));

    canvas.drawCircle(leftEarCenter, earRadius, earPaint);
    canvas.drawCircle(rightEarCenter, earRadius, earPaint);

    // Translucent pink inner ear centers
    final innerEarPaint = Paint()..color = const Color(0xFFFF8A80).withValues(alpha: 0.4);
    canvas.drawCircle(leftEarCenter, earRadius * 0.55, innerEarPaint);
    canvas.drawCircle(rightEarCenter, earRadius * 0.55, innerEarPaint);

    final earStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawCircle(leftEarCenter, earRadius, earStroke);
    canvas.drawCircle(rightEarCenter, earRadius, earStroke);

    // 3. Cute feet nubbins (drawn behind body)
    final leftFootCenter = Offset(c.dx - r * 0.45, c.dy + r * 0.85);
    final rightFootCenter = Offset(c.dx + r * 0.45, c.dy + r * 0.85);
    final footRadius = r * 0.25;
    final footPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accent, AppColors.surface3],
      ).createShader(Rect.fromCircle(center: leftFootCenter, radius: footRadius));

    canvas.drawCircle(leftFootCenter, footRadius, footPaint);
    canvas.drawCircle(rightFootCenter, footRadius, footPaint);

    final footStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawCircle(leftFootCenter, footRadius, footStroke);
    canvas.drawCircle(rightFootCenter, footRadius, footStroke);

    // 4. Main body gradient
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, AppColors.surface2],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, bodyPaint);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    // 5. Cute plant sprout on top of head
    final stemStart = Offset(c.dx, c.dy - r + 1);
    final stemPath = Path()
      ..moveTo(stemStart.dx, stemStart.dy)
      ..quadraticBezierTo(c.dx - 1.0, c.dy - r - 3, c.dx, c.dy - r - 6);
    
    canvas.drawPath(
      stemPath,
      Paint()
        ..color = const Color(0xFF81C784)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    final leafCenter = Offset(c.dx, c.dy - r - 6);
    final leafPaint = Paint()
      ..color = const Color(0xFFC8E6C9)
      ..style = PaintingStyle.fill;
    final leafStroke = Paint()
      ..color = const Color(0xFF388E3C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Left leaf
    final leafLeft = Path()
      ..moveTo(leafCenter.dx, leafCenter.dy)
      ..quadraticBezierTo(leafCenter.dx - 5.5, leafCenter.dy - 3.5, leafCenter.dx - 7.5, leafCenter.dy)
      ..quadraticBezierTo(leafCenter.dx - 3.5, leafCenter.dy + 2.5, leafCenter.dx, leafCenter.dy)
      ..close();
    canvas.drawPath(leafLeft, leafPaint);
    canvas.drawPath(leafLeft, leafStroke);

    // Right leaf
    final leafRight = Path()
      ..moveTo(leafCenter.dx, leafCenter.dy)
      ..quadraticBezierTo(leafCenter.dx + 5.5, leafCenter.dy - 3.5, leafCenter.dx + 7.5, leafCenter.dy)
      ..quadraticBezierTo(leafCenter.dx + 3.5, leafCenter.dy + 2.5, leafCenter.dx, leafCenter.dy)
      ..close();
    canvas.drawPath(leafRight, leafPaint);
    canvas.drawPath(leafRight, leafStroke);

    // 6. Face features
    final ink = Paint()..color = AppColors.accentInk;
    final eyeY = c.dy - r * 0.15;
    final eyeDx = r * 0.35;

    // Rosy cheeks (cute blush circles under the eyes)
    final cheekPaint = Paint()
      ..color = const Color(0xFFFF8A80).withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(c.dx - eyeDx - 3, eyeY + 5), 4.5, cheekPaint);
    canvas.drawCircle(Offset(c.dx + eyeDx + 3, eyeY + 5), 4.5, cheekPaint);

    // Tiny cute nose
    canvas.drawCircle(Offset(c.dx, eyeY + 2.5), 1.5, Paint()..color = ink.color.withValues(alpha: 0.5));

    // Eyes
    if (thinking) {
      // Look up-and-to-the-right with curious eyes
      for (final dx in [-eyeDx, eyeDx]) {
        final eyeCenter = Offset(c.dx + dx + 1.2, eyeY - 1.8);
        canvas.drawCircle(eyeCenter, 4.5, ink);
        canvas.drawCircle(Offset(eyeCenter.dx + 1.0, eyeCenter.dy - 1.0), 1.2,
            Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
    } else if (blink > 0.5) {
      // Happy arch-curved blinks
      final p = Paint()
        ..color = ink.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (final dx in [-eyeDx, eyeDx]) {
        final eyePath = Path()
          ..moveTo(c.dx + dx - 3.5, eyeY - 0.5)
          ..quadraticBezierTo(c.dx + dx, eyeY + 1.5, c.dx + dx + 3.5, eyeY - 0.5);
        canvas.drawPath(eyePath, p);
      }
    } else {
      // Sparkly friendly eyes (anime-style double highlights)
      for (final dx in [-eyeDx, eyeDx]) {
        final eyeCenter = Offset(c.dx + dx, eyeY);
        canvas.drawCircle(eyeCenter, 5.0, ink);
        // Primary spark
        canvas.drawCircle(Offset(eyeCenter.dx - 1.4, eyeCenter.dy - 1.4), 1.6,
            Paint()..color = Colors.white);
        // Secondary spark
        canvas.drawCircle(Offset(eyeCenter.dx + 1.4, eyeCenter.dy + 1.4), 0.7,
            Paint()..color = Colors.white.withValues(alpha: 0.8));
      }
    }

    // Mouth
    final mouthCenterY = c.dy + r * 0.32;
    if (thinking) {
      // Cute wave mouth
      final wavePaint = Paint()
        ..color = ink.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      final wavePath = Path()
        ..moveTo(c.dx - 5.0, mouthCenterY)
        ..quadraticBezierTo(c.dx - 2.5, mouthCenterY - 1.8, c.dx, mouthCenterY)
        ..quadraticBezierTo(c.dx + 2.5, mouthCenterY + 1.8, c.dx + 5.0, mouthCenterY);
      canvas.drawPath(wavePath, wavePaint);
    } else if (mouthOpen > 0.0) {
      // Animated mouth that opens with a little pink tongue inside
      final openMouthHeight = 3.0 + mouthOpen * 9.5;
      final openMouthWidth = 11.5;
      final mouthRect = Rect.fromCenter(
        center: Offset(c.dx, mouthCenterY),
        width: openMouthWidth,
        height: openMouthHeight,
      );

      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(mouthRect, Radius.circular(openMouthHeight / 2)));
      canvas.drawPaint(Paint()..color = ink.color);
      // Tongue at bottom
      canvas.drawCircle(
        Offset(c.dx, mouthRect.bottom),
        openMouthWidth * 0.42,
        Paint()..color = const Color(0xFFFF8A80),
      );
      canvas.restore();

      // Outer mouth border
      canvas.drawRRect(
        RRect.fromRectAndRadius(mouthRect, Radius.circular(openMouthHeight / 2)),
        Paint()
          ..color = ink.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    } else {
      // Friendly smile
      final smilePaint = Paint()
        ..color = ink.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      final smilePath = Path()
        ..moveTo(c.dx - 5.0, mouthCenterY - 0.8)
        ..quadraticBezierTo(c.dx, mouthCenterY + 2.2, c.dx + 5.0, mouthCenterY - 0.8);
      canvas.drawPath(smilePath, smilePaint);
    }
  }

  @override
  bool shouldRepaint(_MascotPainter old) =>
      old.blink != blink ||
      old.mouthOpen != mouthOpen ||
      old.thinking != thinking ||
      old.accent != accent;
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
