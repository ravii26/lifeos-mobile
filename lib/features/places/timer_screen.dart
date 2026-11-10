import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../guide/guide_style.dart';

/// How the timer was left. Null (closing it) changes nothing and costs nothing.
enum TimerResult { finished, stuck }

/// 24:18. Never negative: when the time is up the clock just rests at 00:00.
String clockText(Duration left) {
  final seconds = math.max(0, left.inSeconds);
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}

/// The screen after Start: one thing, a ring, and a way out at every moment.
/// It counts by the clock on the wall, so it stays right while the phone is in a pocket.
class TimerScreen extends StatefulWidget {
  final String title;
  final int minutes;
  final String? firstStep;
  const TimerScreen({super.key, required this.title, required this.minutes, this.firstStep});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  late final Duration _total = Duration(minutes: widget.minutes);
  late Duration _left = _total;
  DateTime? _endsAt;
  Timer? _tick;

  bool get _running => _endsAt != null;
  bool get _timeUp => _left <= Duration.zero;

  @override
  void initState() {
    super.initState();
    _resume();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _resume() {
    _endsAt = DateTime.now().add(_left);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _pause() {
    _tick?.cancel();
    _endsAt = null;
  }

  void _update() {
    final ends = _endsAt;
    if (ends == null || !mounted) return;
    final left = ends.difference(DateTime.now());
    setState(() {
      _left = left.isNegative ? Duration.zero : left;
      if (_timeUp) {
        _pause();
        HapticFeedback.mediumImpact();
      }
    });
  }

  void _togglePause() => setState(() => _running ? _pause() : _resume());

  @override
  Widget build(BuildContext context) {
    final progress = _total.inSeconds == 0 ? 1.0 : 1 - _left.inSeconds / _total.inSeconds;
    final encouragement = _timeUp ? "Time's up. Nicely done." : "You've started. That's the hard part.";
    return Scaffold(
      backgroundColor: G.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Leave the timer',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: G.ink),
              ),
            ),
            Text(encouragement, textAlign: TextAlign.center, style: G.text(18, color: G.accent, height: 1.3)),
            const SizedBox(height: 10),
            Text(widget.title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: G.text(30, w: FontWeight.w600, height: 1.12, letterSpacing: -0.6)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
                      child: CustomPaint(
                        painter: _RingPainter(progress: progress, track: G.card, value: G.accent),
                        child: Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.68,
                            child: FittedBox(
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text(clockText(_left), style: G.text(74, w: FontWeight.w600, height: 1, letterSpacing: -3)),
                                const SizedBox(height: 6),
                                Text(_running || _timeUp ? 'minutes left' : 'paused', style: G.text(17, color: G.muted, height: 1.2)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.firstStep != null) ...[
              Text('Start with: ${widget.firstStep}',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: G.text(18, color: G.muted, height: 1.34)),
              const SizedBox(height: 18),
            ],
            SizedBox(
              width: double.infinity,
              child: GPill('Finished', primary: true, onTap: () => Navigator.of(context).pop(TimerResult.finished)),
            ),
            const SizedBox(height: 10),
            Row(children: [
              if (!_timeUp) ...[
                Expanded(child: GPill(_running ? 'Pause' : 'Resume', onTap: _togglePause)),
                const SizedBox(width: 10),
              ],
              Expanded(child: GPill("I'm stuck", onTap: () => Navigator.of(context).pop(TimerResult.stuck))),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color value;
  const _RingPainter({required this.progress, required this.track, required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - stroke / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, paint..color = track);
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, sweep, false, paint..color = value);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.track != track || old.value != value;
}
