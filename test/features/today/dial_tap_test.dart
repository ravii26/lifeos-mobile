import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/design/components.dart';
import 'package:lifeos_mobile/design/rings.dart';
import 'package:lifeos_mobile/features/places/now_cubit.dart';
import 'package:lifeos_mobile/features/today/day_shape.dart';
import 'package:lifeos_mobile/features/today/today_screen.dart';

// A weekday with an office job: an hour free in the morning, two in the evening.
const _parts = [
  DayPart(390, 570, DayPartKind.free), // 06:30–09:30
  DayPart(570, 1080, DayPartKind.fixed), // work
  DayPart(1110, 1380, DayPartKind.free), // 18:30–23:00
];

const _side = 300.0;
const _size = Size(_side, _side);

/// Where minute [m] of the day sits on a dial of [side], [off] from the ring.
Offset _at(int m, {double side = _side, double off = 0}) {
  final a = -math.pi / 2 + 2 * math.pi * m / 1440;
  final r = side / 2 - 9 - 8 + off;
  return Offset(side / 2, side / 2) + Offset(math.cos(a), math.sin(a)) * r;
}

class _Repo implements LifeRepository {
  @override
  bool get showingSaved => false;

  @override
  Future<Map<String, dynamic>?> nowSaved({bool smallest = false}) async => null;

  @override
  Future<Map<String, dynamic>> now({bool smallest = false, int? minutes}) async =>
      const {'kind': 'EMPTY', 'message': '', 'options': []};

  @override
  Future<List<Map<String, dynamic>>> daySchedule() async => [
        for (var d = 0; d < 7; d++)
          {
            'weekday': d,
            'blocks': [
              {'block': 'MORNING', 'start': '06:30', 'end': '09:30', 'freeMinutes': 60},
              {'block': 'OFFICE', 'start': '09:30', 'end': '18:00', 'freeMinutes': 0},
              {'block': 'EVENING', 'start': '18:30', 'end': '23:00', 'freeMinutes': 120},
            ],
          },
      ];

  @override
  Future<Map<String, dynamic>> plan() async => const {'today': {'blocks': []}};

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('which part was tapped', () {
    test('a tap on the evening part of the ring finds it', () {
      final p = freePartAt(_parts, 14 * 60, _at(19 * 60), _size)!;
      expect(p.start, 1110);
    });

    test('a finger slightly off the ring still counts; the middle does not', () {
      expect(freePartAt(_parts, 14 * 60, _at(19 * 60, off: 18), _size), isNotNull);
      expect(freePartAt(_parts, 14 * 60, _at(19 * 60, off: -18), _size), isNotNull);
      expect(freePartAt(_parts, 14 * 60, const Offset(_side / 2, _side / 2), _size), isNull);
    });

    test('work time and free time that is over do not open anything', () {
      expect(freePartAt(_parts, 14 * 60, _at(12 * 60), _size), isNull);
      expect(freePartAt(_parts, 14 * 60, _at(8 * 60), _size), isNull); // this morning, gone
    });

    test('the next free part: the one you are in, else the soonest ahead', () {
      expect(nextFreePart(_parts, 8 * 60)!.start, 390);
      expect(nextFreePart(_parts, 14 * 60)!.start, 1110);
      expect(nextFreePart(_parts, 23 * 60 + 30), isNull);
    });
  });

  group('how long a tapped part offers', () {
    const blocks = [
      DayBlockInfo('MORNING', 390, 570, 60),
      DayBlockInfo('OFFICE', 570, 1080, 0),
      DayBlockInfo('EVENING', 1110, 1380, 120),
    ];
    test('ahead: what that part allows', () {
      expect(freeMinutesIn(blocks, 1110, 1380, 14 * 60), 120);
    });
    test('begun: what is left, never more than it allows', () {
      expect(freeMinutesIn(blocks, 1110, 1380, 22 * 60), 60);
      expect(freeMinutesIn(blocks, 1110, 1380, 19 * 60), 120);
    });
    test('not a free part, or over: nothing', () {
      expect(freeMinutesIn(blocks, 570, 1080, 600), isNull);
      expect(freeMinutesIn(blocks, 390, 570, 600), isNull);
    });
  });

  testWidgets('tapping the glowing evening opens I\'ve got time with its length', (t) async {
    t.view.physicalSize = const Size(360, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final repo = _Repo();
    final cubit = NowCubit(repo);
    addTearDown(cubit.close);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BlocProvider.value(
          value: cubit,
          child: TodayScreen(firstName: '', repo: repo, clock: () => DateTime(2026, 11, 16, 14)),
        ),
      ),
    ));
    await cubit.load();
    await t.pump(const Duration(seconds: 2));

    final dial = find.descendant(of: find.byType(DayDial), matching: find.byType(AspectRatio));
    final box = t.getRect(dial);
    await t.tapAt(box.topLeft + _at(19 * 60, side: box.width));
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));

    expect(find.text('How long do you have?'), findsOneWidget);
    // 2 hours free: the longest length offered is picked.
    expect(t.widget<AllyChip>(find.widgetWithText(AllyChip, '1h 30')).selected, isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('a screen reader can do the same from the dial', (t) async {
    final handle = t.ensureSemantics();
    DayPart? opened;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _side,
            child: DayDial(
              now: 14 * 60,
              parts: _parts,
              semanticLabel: 'Your day',
              tapHint: "Opens I've got time",
              onTapFree: (p) => opened = p,
            ),
          ),
        ),
      ),
    ));
    await t.pump(const Duration(seconds: 1));
    final node = t.getSemantics(find.bySemanticsLabel('Your day'));
    expect(node.hint, "Opens I've got time");
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    t.semantics.tap(find.semantics.byLabel('Your day'));
    await t.pump();
    expect(opened!.start, 1110);
    handle.dispose();
  });
}
