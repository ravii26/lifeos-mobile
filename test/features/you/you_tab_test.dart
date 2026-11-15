import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/data/models/user.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/you/you_tab.dart';

class _Repo implements LifeRepository {
  final List<String> calls = [];
  String level = 'NORMAL';

  @override
  Future<String> proactivity() async => level;

  @override
  Future<void> setProactivity(String level) async {
    calls.add('level:$level');
    this.level = level;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

AppUser _user() => AppUser.fromJson({'id': 'u1', 'name': 'Sam Rivera', 'email': 'sam@example.com'});

Future<_Repo> _open(WidgetTester t, {Size size = const Size(360, 800), double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  final repo = _Repo();
  await t.pumpWidget(MaterialApp(home: Scaffold(body: YouTab(user: _user(), repo: repo))));
  await t.pump();
  await t.pump(const Duration(seconds: 2));
  return repo;
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('You lists every place My life reached, grouped', (t) async {
    await _open(t);
    expect(find.text('Sam Rivera'), findsOneWidget);
    for (final s in [
      'Library', 'Reminders', 'Log', 'Parked', 'Plans and check-ins',
      'What Ally remembers', 'How much Ally speaks up', 'How Ally works for you', 'Your normal day', "Ally's voice",
      'Appearance', 'Account and privacy', 'Help me decide', 'Sign out',
    ]) {
      await t.scrollUntilVisible(find.text(s), 200);
      expect(find.text(s), findsOneWidget, reason: s);
    }
  });

  testWidgets('how much Ally speaks up: pick, saved, with Undo', (t) async {
    final repo = await _open(t);
    await t.ensureVisible(find.text('How much Ally speaks up'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('How much Ally speaks up'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    await t.tap(find.text('Quieter'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    expect(repo.calls.single, 'level:QUIETER');
    expect(find.text('Quieter from now on.'), findsOneWidget);
    await t.tap(find.text('Undo'));
    await t.pump(const Duration(milliseconds: 700));
    expect(repo.calls.last, 'level:NORMAL');
  });

  testWidgets('fits a small phone at large text', (t) async {
    await _open(t, size: const Size(320, 640), textScale: 1.5);
    for (var i = 0; i < 8; i++) {
      await t.drag(find.byType(ListView), const Offset(0, -400));
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(t.takeException(), isNull);
  });
}
