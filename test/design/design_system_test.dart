import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/design/ally_theme.dart';
import 'package:lifeos_mobile/design/components.dart';
import 'package:lifeos_mobile/design/rings.dart';
import 'package:lifeos_mobile/design/tokens.dart';
import 'package:lifeos_mobile/features/design_preview/design_preview_screen.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Widget _app(Widget child, {bool dark = true, bool calm = false}) => MaterialApp(
      theme: dark ? AllyTheme.dark() : AllyTheme.light(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: calm),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('colour', () {
    for (final (name, c) in [('dark', AllyColors.dark), ('light', AllyColors.light)]) {
      test('$name: text reads on every surface', () {
        for (final s in [c.bg, c.surface, c.raised]) {
          expect(_contrast(c.ink, s), greaterThanOrEqualTo(7));
          expect(_contrast(c.muted, s), greaterThanOrEqualTo(4.5));
        }
        expect(_contrast(c.faint, c.bg), greaterThanOrEqualTo(4.5));
        expect(_contrast(c.onFree, c.free), greaterThanOrEqualTo(4.5));
        expect(_contrast(c.freeInk, c.bg), greaterThanOrEqualTo(4.5));
        expect(_contrast(c.bg, c.ink), greaterThanOrEqualTo(7));
      });

      test('$name: area colours stand out from the background', () {
        for (final a in c.areas) {
          expect(_contrast(a, c.bg), greaterThanOrEqualTo(3));
        }
      });
    }

    test('an area colour comes from its position, for any number of areas', () {
      const c = AllyColors.dark;
      expect(c.area(0), c.areas.first);
      expect(c.area(c.areas.length), c.areas.first);
      expect(c.area(23), c.areas[23 % c.areas.length]);
    });
  });

  testWidgets('a button taps, and a disabled one does not', (t) async {
    var taps = 0;
    await t.pumpWidget(_app(Column(mainAxisSize: MainAxisSize.min, children: [
      AllyButton('Start', kind: AllyButtonKind.free, onPressed: () => taps++),
      const AllyButton('Off', onPressed: null),
    ])));
    await t.tap(find.text('Start'));
    await t.tap(find.text('Off'));
    await t.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('the tick and the switch are at least 48 high to tap', (t) async {
    await t.pumpWidget(_app(Row(mainAxisSize: MainAxisSize.min, children: [
      AllyCheck(done: false, onTap: () {}),
      AllySwitch(value: false, onChanged: (_) {}),
    ])));
    expect(t.getSize(find.byType(AllyCheck)).height, greaterThanOrEqualTo(48));
    expect(t.getSize(find.byType(AllySwitch)).height, greaterThanOrEqualTo(48));
  });

  testWidgets('a toast shows, offers Undo, and goes away', (t) async {
    var undone = false;
    await t.pumpWidget(_app(Builder(
      builder: (context) => AllyButton('Go',
          onPressed: () =>
              showAllyToast(context, 'Saved', onUndo: () => undone = true)),
    )));
    await t.tap(find.text('Go'));
    await t.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(undone, isTrue);
    expect(find.text('Saved'), findsNothing);

    await t.tap(find.text('Go'));
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('the life wheel reports which area was tapped', (t) async {
    int? tapped;
    await t.pumpWidget(_app(SizedBox(
      width: 240,
      child: LifeWheel(
        spokes: const [
          WheelSpoke('A', Colors.red, 0.5),
          WheelSpoke('B', Colors.green, 0.5),
          WheelSpoke('C', Colors.blue, 0.5),
          WheelSpoke('D', Colors.yellow, 0.5),
        ],
        onTap: (i) => tapped = i,
      ),
    )));
    await t.pumpAndSettle();
    final centre = t.getCenter(find.byType(LifeWheel));
    await t.tapAt(centre + const Offset(0, -80)); // top
    expect(tapped, 0);
    await t.tapAt(centre + const Offset(80, 0)); // right
    expect(tapped, 1);
    await t.tapAt(centre + const Offset(0, 80)); // bottom
    expect(tapped, 2);
    await t.tapAt(centre + const Offset(-80, 0)); // left
    expect(tapped, 3);
  });

  testWidgets('with less motion asked for, nothing keeps animating', (t) async {
    await t.pumpWidget(_app(
      const Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: 200,
            child: DayDial(now: 600, parts: [DayPart(660, 720, DayPartKind.free)])),
        AllySkeleton(width: 100),
      ]),
      calm: true,
    ));
    await t.pump();
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  for (final dark in [true, false]) {
    testWidgets(
        'the preview fits a small phone at large text (${dark ? 'dark' : 'light'})',
        (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearAllTestValues);

      await t.pumpWidget(const MaterialApp(home: DesignPreviewScreen()));
      await t.pump(const Duration(seconds: 2));
      if (!dark) {
        await t.tap(find.byTooltip('Switch to light'));
        await t.pump(const Duration(seconds: 2));
      }
      // Scroll the whole page so every section is built and laid out.
      for (var i = 0; i < 12; i++) {
        await t.drag(find.byType(ListView), const Offset(0, -500));
        await t.pump(const Duration(milliseconds: 400));
      }
      expect(t.takeException(), isNull);
    });
  }
}
