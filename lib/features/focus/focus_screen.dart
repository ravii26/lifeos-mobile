import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/task.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';

/// Immersive focus mode — donut timer + start/pause, backed by /focus sessions.
class FocusScreen extends StatefulWidget {
  final Task? task;
  final Color? accentColor;
  const FocusScreen({super.key, this.task, this.accentColor});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final _repo = getIt<LifeRepository>();
  Timer? _timer;
  int _seconds = 0;
  bool _active = false;
  String? _sessionId;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _active = true);
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() => _seconds++));
    try {
      _sessionId = await _repo.startFocus(taskId: widget.task?.id);
    } catch (_) {
      // Session logging is best-effort; the timer still runs locally.
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    setState(() => _active = false);
    if (_sessionId != null) {
      try {
        await _repo.stopFocus(_sessionId!);
      } catch (_) {}
      _sessionId = null;
    }
  }

  String get _fmt {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppColors.accent;
    final pct = (_seconds % 1500) / 1500 * 100; // 25-min pomodoro ring
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.5),
            radius: 1.1,
            colors: [accent.withOpacity(0.10), AppColors.bg],
            stops: const [0, 0.7],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.keyboard_arrow_down,
                          color: AppColors.tx2, size: 26),
                    ),
                    Eyebrow('Immersive focus'),
                    const SizedBox(width: 40),
                  ],
                ),
                const Spacer(),
                Donut(
                  value: pct,
                  size: 244,
                  stroke: 6,
                  color: accent,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_fmt,
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 54,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -2,
                              color: _active ? accent : AppColors.tx)),
                      const SizedBox(height: 4),
                      Eyebrow(_active ? 'In session' : 'Paused'),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                if (widget.task != null)
                  Text(widget.task!.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.hankenGrotesk(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          height: 1.25))
                else
                  Text('Free focus session',
                      style: TextStyle(color: AppColors.tx3)),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _active ? _stop : _start,
                    icon: Icon(_active ? Icons.pause : Icons.play_arrow,
                        size: 20),
                    label: Text(_active ? 'Pause & log' : 'Start focus'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          _active ? AppColors.surface3 : accent,
                      foregroundColor:
                          _active ? AppColors.tx : AppColors.accentInk,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
