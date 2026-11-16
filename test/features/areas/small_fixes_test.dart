import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/design/components.dart';
import 'package:lifeos_mobile/features/areas/area_page.dart';
import 'package:lifeos_mobile/features/areas/areas_overview.dart';
import 'package:lifeos_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:lifeos_mobile/features/splash/splash_screen.dart';

class _Repo implements LifeRepository {
  @override
  Future<Map<String, dynamic>> areasOverview() async => {
        'areas': [
          {
            'id': 'a1',
            'name': 'Writing',
            'mode': 'PUSH',
            'value': 0.3,
            'status': '1h of 3h this week',
            'goals': [],
            'nextSteps': [
              {'id': 's1', 'title': 'Draft the intro', 'minutes': 25},
            ],
            'routines': [],
          },
        ],
        'capacity': {'neededMinutes': 0, 'freeMinutes': 0, 'note': null},
      };

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _AuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('an area page opened with a step id shows that step\'s edit sheet', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearAllTestValues);
    final r = _Repo();
    final area = (await loadAreasOverview(r)).areas.first;
    await t.pumpWidget(MaterialApp(home: AreaPage(area: area, colorIndex: 0, canSetTime: true, repo: r, openStepId: 's1')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Edit step'), findsOneWidget);
  });

  testWidgets('an unknown step id opens nothing extra', (t) async {
    final r = _Repo();
    final area = (await loadAreasOverview(r)).areas.first;
    await t.pumpWidget(MaterialApp(home: AreaPage(area: area, colorIndex: 0, canSetTime: true, repo: r, openStepId: 'nope')));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Edit step'), findsNothing);
  });

  testWidgets('splash: waiting, then an error with Try again, at 320x640 and 1.5x text', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearAllTestValues);
    final bloc = _AuthBloc();
    whenListen(bloc, Stream<AuthState>.value(const AuthState(error: 'Server asleep. Try soon.')), initialState: const AuthState());
    await t.pumpWidget(MaterialApp(home: BlocProvider<AuthBloc>.value(value: bloc, child: const SplashScreen())));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Ally'), findsOneWidget);
    expect(find.text("Can't connect right now."), findsOneWidget);
    expect(find.widgetWithText(AllyButton, 'Try again'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('showAllyToast works above a page with no Ally theme', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Builder(builder: (c) => TextButton(onPressed: () => showAllyToast(c, 'Could not save.'), child: const Text('go'))),
    ));
    await t.tap(find.text('go'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Could not save.'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });
}
