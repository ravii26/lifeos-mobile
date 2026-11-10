import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../data/models/task.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';
import '../guide/guide_style.dart';

/// Focus on one to-do: a running clock, backed by /focus sessions.
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
      _sessionId = await _repo.startFocus(
          taskId: widget.task?.id, label: widget.task?.title);
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
    final pct = (_seconds % 1500) / 1500 * 100; // the ring goes round every 25 minutes
    return Scaffold(
      backgroundColor: G.bg,
      appBar: gBar(),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.task?.title ?? 'Just focus',
                style: G.text(34, w: FontWeight.w600, height: 1.1, letterSpacing: -0.8),
              ),
              const Spacer(),
              Center(
                child: Donut(
                  value: pct,
                  size: 240,
                  stroke: 8,
                  color: G.accent,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_fmt, style: G.numeral(60)),
                      const SizedBox(height: 4),
                      Text(_active ? 'Focusing' : 'Ready when you are', style: G.text(16, color: G.muted, height: 1.2)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              GPill(_active ? 'Pause and save' : 'Start', primary: true, onTap: _active ? _stop : _start),
            ],
          ),
        ),
      ),
    );
  }
}
