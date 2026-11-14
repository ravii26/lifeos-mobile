import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'type.dart';

/// Shrinks a little while pressed, so every tap is acknowledged.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final String? semanticLabel;
  final bool? selected;

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.97,
    this.semanticLabel,
    this.selected,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: Motion.of(context, Motion.d1),
          curve: Motion.ease,
          child: widget.child,
        ),
      ),
    );
  }
}

enum AllyButtonKind {
  /// The main action on a screen: ink on background.
  main,

  /// Start, for free time. Marigold. Use nowhere else.
  free,
  secondary,
  ghost,
  danger,
}

class AllyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AllyButtonKind kind;
  final IconData? icon;

  /// Fill the available width.
  final bool wide;

  /// What a screen reader says instead of [label], when the label alone is
  /// not enough ("+1" → "Add one: Water").
  final String? semanticLabel;

  const AllyButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = AllyButtonKind.main,
    this.icon,
    this.wide = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final (Color bg, Color fg, Color border) = switch (kind) {
      AllyButtonKind.main => (c.ink, c.bg, Colors.transparent),
      AllyButtonKind.free => (c.free, c.onFree, Colors.transparent),
      AllyButtonKind.secondary => (c.surface, c.ink, c.line),
      AllyButtonKind.ghost => (Colors.transparent, c.muted, Colors.transparent),
      AllyButtonKind.danger => (c.warnSoft, c.warn, c.warn),
    };
    final ghost = kind == AllyButtonKind.ghost;
    final strong = kind == AllyButtonKind.main ||
        kind == AllyButtonKind.free ||
        kind == AllyButtonKind.danger;
    final content = Row(
      mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: Sp.x2),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AllyType.body(
                color: fg, w: strong ? FontWeight.w600 : FontWeight.w500),
          ),
        ),
      ],
    );
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Pressable(
        onTap: onPressed,
        semanticLabel: semanticLabel,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.d2),
          curve: Motion.ease,
          constraints: BoxConstraints(minHeight: ghost ? 44 : 50),
          padding: EdgeInsets.symmetric(horizontal: ghost ? 11 : 20),
          alignment: wide ? Alignment.center : null,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Rad.button),
            border: Border.all(color: border),
          ),
          child: ExcludeSemantics(
            excluding: semanticLabel != null,
            child: wide ? content : Center(widthFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}

/// A card. Every card has a 1 px line so it reads in both themes.
class AllyCard extends StatelessWidget {
  final Widget child;

  /// The free-time card: marigold tint and border.
  final bool free;

  /// The one card that matters right now: ink border.
  final bool strong;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const AllyCard({
    super.key,
    required this.child,
    this.free = false,
    this.strong = false,
    this.onTap,
    this.padding = const EdgeInsets.all(Sp.side),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final box = AnimatedContainer(
      duration: Motion.of(context, Motion.d2),
      curve: Motion.ease,
      padding: padding,
      decoration: BoxDecoration(
        color: free ? c.freeSoft : c.surface,
        borderRadius: BorderRadius.circular(Rad.card),
        border: Border.all(
            color: free ? c.free : (strong ? c.ink : c.line)),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Pressable(onTap: onTap, scale: 0.985, child: box);
  }
}

/// A choice you can turn on or off.
class AllyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const AllyChip(this.label,
      {super.key, this.selected = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      selected: selected,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.d2),
        curve: Motion.ease,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: selected ? c.ink : c.surface,
          borderRadius: BorderRadius.circular(Rad.chip),
          border: Border.all(color: selected ? c.ink : c.line),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(label,
              style: AllyType.body(
                  color: selected ? c.bg : c.ink,
                  w: selected ? FontWeight.w500 : FontWeight.w400)),
        ),
      ),
    );
  }
}

/// Pick one of a few options, side by side.
class AllySegmented<T> extends StatelessWidget {
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  const AllySegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: c.raised, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        for (final e in options.entries)
          Expanded(
            child: Pressable(
              onTap: () => onChanged(e.key),
              selected: e.key == value,
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.d2),
                curve: Motion.ease,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: e.key == value ? c.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color: e.key == value ? c.line : Colors.transparent),
                ),
                child: Text(e.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AllyType.small(
                        color: e.key == value ? c.ink : c.muted,
                        w: FontWeight.w500)),
              ),
            ),
          ),
      ]),
    );
  }
}

class AllySwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  const AllySwitch(
      {super.key, required this.value, required this.onChanged, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              },
        // 48 high so the tap target meets the minimum.
        child: SizedBox(
          width: 52,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.d2),
              curve: Motion.ease,
              width: 48,
              height: 29,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value ? c.ink : c.raised,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: value ? c.ink : c.line),
              ),
              child: AnimatedAlign(
                duration: Motion.of(context, Motion.d3),
                curve: Motion.spring,
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                      color: value ? c.bg : c.faint, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The round tick. Green is used here and nowhere else.
class AllyCheck extends StatelessWidget {
  final bool done;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const AllyCheck(
      {super.key, required this.done, required this.onTap, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Semantics(
      checked: done,
      label: semanticLabel,
      child: Pressable(
        scale: 0.85,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.d2),
              curve: Motion.ease,
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: done ? c.done : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: done ? c.done : c.faint, width: 2),
              ),
              child: AnimatedScale(
                scale: done ? 1 : 0.4,
                duration: Motion.of(context, Motion.d2),
                curve: Motion.spring,
                child: AnimatedOpacity(
                  opacity: done ? 1 : 0,
                  duration: Motion.of(context, Motion.d1),
                  child: Icon(Icons.check_rounded, size: 19, color: c.bg),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A coloured dot and the area's name. Colour is never shown alone.
class AreaLabel extends StatelessWidget {
  final String name;
  final Color color;

  const AreaLabel(this.name, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 7),
      Flexible(
        child: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AllyType.small(color: context.ac.muted, w: FontWeight.w500)),
      ),
    ]);
  }
}

/// Push, Maintain, Explore or Rest.
class ModeTag extends StatelessWidget {
  final String mode;
  const ModeTag(this.mode, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Rad.tag),
          border: Border.all(color: c.line)),
      child: Text(mode,
          style: AllyType.eyebrow(color: c.muted).copyWith(letterSpacing: 0)),
    );
  }
}

/// A quiet message across the top: offline, saved on this phone, and so on.
class AllyBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  const AllyBanner(this.text, {super.key, this.icon = Icons.cloud_off_rounded});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: c.raised, borderRadius: BorderRadius.circular(Rad.chip)),
      child: Row(children: [
        Icon(icon, size: 18, color: c.muted),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AllyType.small(color: c.muted))),
      ]),
    );
  }
}

/// Something needs attention: a missed reminder, a failed save.
class AllyNote extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AllyNote(this.text, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: BoxDecoration(
        color: c.warnSoft,
        borderRadius: BorderRadius.circular(Rad.button),
        border: Border.all(color: c.warn),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text, style: AllyType.body(color: c.ink)),
        if (actionLabel != null) ...[
          const SizedBox(height: Sp.x2),
          AllyButton(actionLabel!,
              kind: AllyButtonKind.secondary, onPressed: onAction),
        ],
      ]),
    );
  }
}

/// A grey block that shimmers while content loads.
class AllySkeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;

  const AllySkeleton(
      {super.key, this.height = 20, this.width, this.radius = 16});

  @override
  State<AllySkeleton> createState() => _AllySkeletonState();
}

class _AllySkeletonState extends State<AllySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-3 + 4 * _c.value, 0),
              end: Alignment(-1 + 4 * _c.value, 0),
              colors: [c.raised, c.line, c.raised],
            ),
          ),
        ),
      ),
    );
  }
}

/// Children fade up one after another when the screen arrives.
class Stagger extends StatefulWidget {
  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;

  const Stagger({
    super.key,
    required this.children,
    this.gap = Sp.side,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  State<Stagger> createState() => _StaggerState();
}

class _StaggerState extends State<Stagger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  // Only the first few children are delayed, so a long page never waits.
  static const _maxSteps = 8;

  @override
  void initState() {
    super.initState();
    final steps = widget.children.length.clamp(1, _maxSteps);
    _c = AnimationController(
        vsync: this, duration: Motion.d3 + Motion.stagger * (steps - 1));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _c.duration!.inMilliseconds;
    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      children: [
        for (var i = 0; i < widget.children.length; i++) ...[
          if (i > 0) SizedBox(height: widget.gap),
          _item(i, total),
        ],
      ],
    );
  }

  Widget _item(int i, int total) {
    final step = i.clamp(0, _maxSteps - 1);
    final start = (Motion.stagger.inMilliseconds * step) / total;
    final end =
        (start + Motion.d3.inMilliseconds / total).clamp(0.0, 1.0).toDouble();
    final anim = CurvedAnimation(
        parent: _c, curve: Interval(start, end, curve: Motion.ease));
    return FadeTransition(
      opacity: anim,
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, child) => Transform.translate(
            offset: Offset(0, 12 * (1 - anim.value)), child: child),
        child: widget.children[i],
      ),
    );
  }
}

/// A short message above the navigation, with an optional Undo.
/// Returns a function that removes it early.
VoidCallback showAllyToast(
  BuildContext context,
  String message, {
  VoidCallback? onUndo,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final theme = Theme.of(context);
  late OverlayEntry entry;
  Timer? timer;
  var removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    timer?.cancel();
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (ctx) => Theme(
      data: theme,
      child: _Toast(
        message: message,
        onUndo: onUndo == null
            ? null
            : () {
                remove();
                onUndo();
              },
      ),
    ),
  );
  overlay.insert(entry);
  timer = Timer(duration, remove);
  return remove;
}

class _Toast extends StatelessWidget {
  final String message;
  final VoidCallback? onUndo;
  const _Toast({required this.message, this.onUndo});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final bottom = MediaQuery.viewPaddingOf(context).bottom + 88;
    return Positioned(
      left: 14,
      right: 14,
      bottom: bottom,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.of(context, Motion.d3),
        curve: Motion.spring,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0, 1).toDouble(),
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(17, 6, 6, 6),
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(
                  color: c.ink, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                Expanded(
                    child: Text(message, style: AllyType.body(color: c.bg))),
                if (onUndo != null)
                  TextButton(
                    onPressed: onUndo,
                    style: TextButton.styleFrom(
                        foregroundColor: c.bg,
                        minimumSize: const Size(64, 44)),
                    child: Text('Undo',
                        style: AllyType.body(color: c.bg, w: FontWeight.w700)
                            .copyWith(decoration: TextDecoration.underline)),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bottom sheet in the Ally style, with the grab handle.
Future<T?> showAllySheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final theme = Theme.of(context);
  final c = context.ac;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.bg,
    barrierColor: const Color(0x8C040508),
    shape: RoundedRectangleBorder(
      side: BorderSide(color: c.line),
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(Rad.sheet)),
    ),
    builder: (ctx) => Theme(
      data: theme,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(Sp.side, Sp.x3, Sp.side,
              Sp.x5 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                        color: c.line,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: Sp.x4),
                builder(ctx),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
