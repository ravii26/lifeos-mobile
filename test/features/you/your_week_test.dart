import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/design/components.dart';
import 'package:lifeos_mobile/features/you/your_week_page.dart';

class _Repo implements LifeRepository {
  final List<String> calls = [];

  @override
  Future<void> setDayBasics({required String wake, required String sleep, List<int> officeDays = const [], String? officeStart, String? officeEnd}) async =>
      calls.add('$wake $sleep $officeDays $officeStart-$officeEnd');

  @override
  Future<Map<String, dynamic>> areasOverview() async => {'areas': [], 'capacity': {'neededMinutes': 0, 'freeMinutes': 780, 'note': null}};

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('nothing is saved until every choice is made; then it saves and shows free time', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearAllTestValues);
    final repo = _Repo();
    await t.pumpWidget(MaterialApp(home: YourWeekPage(repo: repo)));
    await t.pump(const Duration(seconds: 1));
    AllyButton save() => t.widget<AllyButton>(find.widgetWithText(AllyButton, 'Save'));
    expect(save().onPressed, isNull);
    await _tap(t, find.text('Mon to Fri'));
    await _tap(t, find.text('9 to 6'));
    await _tap(t, find.text('7 am'));
    expect(save().onPressed, isNull);
    await _tap(t, find.text('11 pm'));
    expect(save().onPressed, isNotNull);
    await _tap(t, find.text('Save'));
    expect(repo.calls.single, '07:00 23:00 [1, 2, 3, 4, 5] 09:00-18:00');
    expect(find.textContaining('That leaves about'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('no fixed work days needs no hours', (t) async {
    final repo = _Repo();
    await t.pumpWidget(MaterialApp(home: YourWeekPage(repo: repo)));
    await t.pump(const Duration(seconds: 1));
    await _tap(t, find.text('No fixed work days'));
    expect(find.text('9 to 6'), findsNothing);
    await _tap(t, find.text('6 am'));
    await _tap(t, find.text('10 pm'));
    await _tap(t, find.text('Save'));
    expect(repo.calls.single, '06:00 22:00 [] null-null');
    await t.pump(const Duration(seconds: 5));
  });
}
