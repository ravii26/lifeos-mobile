import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/models/user.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/design/appearance.dart';
import 'package:lifeos_mobile/design/components.dart';
import 'package:lifeos_mobile/design/tokens.dart';
import 'package:lifeos_mobile/features/you/account_page.dart';
import 'package:lifeos_mobile/features/you/appearance_page.dart';
import 'package:lifeos_mobile/features/you/decide_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo implements LifeRepository {
  final List<String> calls = [];
  bool oldServer = false;
  String pick = 'B';

  @override
  Future<Map<String, dynamic>> exportData() async => {'areas': []};

  @override
  Future<void> deleteAccount() async => calls.add('delete');

  @override
  Future<Map<String, dynamic>> decide(String a, String b, {List<String> hard = const [], String? note}) async {
    if (oldServer) throw const ApiException('Not found', statusCode: 404);
    calls.add('decide:$a|$b|${hard.join(",")}');
    return {'pick': pick, 'why': 'It fits your evenings.', 'firstStep': 'Book one trial class.', 'checkInDays': 14, 'byCode': false};
  }

  @override
  Future<({String message, String? activityId})> chooseDecision(String choice, int checkInDays) async {
    calls.add('choose:$choice:$checkInDays');
    return (message: 'Going with "$choice".', activityId: 'act-choose');
  }

  @override
  Future<void> undo(String activityId) async => calls.add('undo:$activityId');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _size(WidgetTester t, {Size size = const Size(360, 800), double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

/// An app root like the real one: appearance applied to everything.
Widget _app(Widget home, {GlobalKey<NavigatorState>? key}) => ValueListenableBuilder<AppearancePrefs>(
      valueListenable: AllyAppearance.prefs,
      builder: (context, _, _) => MaterialApp(
        navigatorKey: key,
        builder: (context, child) => AllyAppearance.apply(context, child!),
        home: home,
      ),
    );

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AllyAppearance.prefs.value = const AppearancePrefs();
  });

  group('appearance', () {
    testWidgets('dark by default; light switches every new-look page at once', (t) async {
      await _size(t);
      await t.pumpWidget(_app(const AppearancePage()));
      await t.pump(const Duration(seconds: 1));
      Color bg() => t.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor!;
      expect(bg(), AllyColors.dark.bg);
      await _tap(t, find.text('Light'));
      expect(AllyAppearance.prefs.value.theme, 'LIGHT');
      expect(bg(), AllyColors.light.bg);
      expect((await SharedPreferences.getInstance()).getString('ally_theme'), 'LIGHT');
    });

    testWidgets('match phone follows the phone', (t) async {
      await _size(t);
      t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      AllyAppearance.prefs.value = const AppearancePrefs(theme: 'SYSTEM');
      await t.pumpWidget(_app(const AppearancePage()));
      await t.pump(const Duration(seconds: 1));
      expect(t.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor, AllyColors.light.bg);
    });

    testWidgets('larger text is on top of the phone size; reduce motion switches animation off', (t) async {
      await _size(t, textScale: 1.2);
      await t.pumpWidget(_app(const AppearancePage()));
      await t.pump(const Duration(seconds: 1));
      double scale() => MediaQuery.textScalerOf(t.element(find.byType(AppearancePage))).scale(10) / 10;
      expect(scale(), closeTo(1.2, 0.001));
      await _tap(t, find.bySemanticsLabel('Larger text'));
      expect(scale(), closeTo(1.2 * AllyAppearance.largerBy, 0.001));
      expect(MediaQuery.disableAnimationsOf(t.element(find.byType(AppearancePage))), isFalse);
      await _tap(t, find.bySemanticsLabel('Reduce motion'));
      expect(MediaQuery.disableAnimationsOf(t.element(find.byType(AppearancePage))), isTrue);
    });
  });

  group('account and privacy', () {
    AppUser user() => AppUser.fromJson({'id': 'u', 'name': 'Sam Rivera', 'email': 'sam@example.com'});

    testWidgets('says plainly what goes to AI and what does not', (t) async {
      await _size(t);
      await t.pumpWidget(_app(AccountPage(user: user(), repo: _Repo(), onSignOut: () {})));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('WHAT GOES TO AI'), findsOneWidget);
      expect(find.textContaining('without AI'), findsOneWidget);
      expect(find.textContaining('mark private'), findsOneWidget);
    });

    testWidgets('download hands a file to share; delete needs DELETE typed', (t) async {
      await _size(t);
      final repo = _Repo();
      String? shared;
      var signedOut = false;
      await t.pumpWidget(_app(AccountPage(user: user(), repo: repo, onSignOut: () => signedOut = true, share: (b, name) async => shared = name)));
      await t.pump(const Duration(seconds: 1));
      await _tap(t, find.text('Download my data'));
      await t.pump(const Duration(seconds: 1));
      expect(shared, startsWith('ally-data-'));

      await _tap(t, find.text('Delete my account'));
      expect(t.widget<AllyButton>(find.widgetWithText(AllyButton, 'Delete forever')).onPressed, isNull);
      await t.enterText(find.byType(TextField), 'DELETE');
      await t.pump();
      await _tap(t, find.text('Delete forever'));
      await t.pump(const Duration(seconds: 1));
      expect(repo.calls, ['delete']);
      expect(signedOut, isTrue);
      await t.pump(const Duration(seconds: 5));
    });
  });

  group('help me decide', () {
    testWidgets('two options and what is hard → a suggestion; going with one sets a check-in with Undo', (t) async {
      await _size(t);
      final repo = _Repo();
      final key = GlobalKey<NavigatorState>();
      await t.pumpWidget(_app(const SizedBox(), key: key));
      key.currentState!.push(MaterialPageRoute<void>(builder: (_) => DecideScreen(repo: repo)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 700));
      expect(t.widget<AllyButton>(find.widgetWithText(AllyButton, 'Help me decide')).onPressed, isNull);
      await t.enterText(find.byType(TextField).at(0), 'Gym');
      await t.enterText(find.byType(TextField).at(1), 'Swimming');
      await t.pump();
      await _tap(t, find.text('Time'));
      await _tap(t, find.widgetWithText(AllyButton, 'Help me decide'));
      expect(repo.calls.single, 'decide:Gym|Swimming|TIME');
      expect(find.text('ALLY SUGGESTS'), findsOneWidget);
      expect(find.text('Book one trial class.'), findsOneWidget);
      expect(find.text('Ally checks in after 14 days.'), findsOneWidget);
      await _tap(t, find.text('Go with "Swimming"'));
      expect(repo.calls.last, 'choose:Swimming:14');
      expect(find.text('Going with "Swimming".'), findsOneWidget);
      await _tap(t, find.text('Undo'));
      expect(repo.calls.last, 'undo:act-choose');
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('either can work, said plainly', (t) async {
      await _size(t);
      await t.pumpWidget(_app(DecideScreen(repo: _Repo()..pick = 'EITHER')));
      await t.pump(const Duration(milliseconds: 700));
      await t.enterText(find.byType(TextField).at(0), 'A');
      await t.enterText(find.byType(TextField).at(1), 'B');
      await t.pump();
      await _tap(t, find.widgetWithText(AllyButton, 'Help me decide'));
      expect(find.text('Either can work'), findsOneWidget);
      expect(find.text('ALLY SAYS'), findsOneWidget);
    });

    testWidgets('a server without it says what is needed', (t) async {
      await _size(t);
      await t.pumpWidget(_app(DecideScreen(repo: _Repo()..oldServer = true)));
      await t.pump(const Duration(milliseconds: 700));
      await t.enterText(find.byType(TextField).at(0), 'A');
      await t.enterText(find.byType(TextField).at(1), 'B');
      await t.pump();
      await _tap(t, find.widgetWithText(AllyButton, 'Help me decide'));
      expect(find.textContaining('needs the latest server'), findsOneWidget);
    });

    testWidgets('fits a small phone at large text', (t) async {
      await _size(t, size: const Size(320, 640), textScale: 1.5);
      await t.pumpWidget(_app(DecideScreen(repo: _Repo())));
      await t.pump(const Duration(milliseconds: 700));
      await t.enterText(find.byType(TextField).at(0), 'Join the evening class at the community centre');
      await t.enterText(find.byType(TextField).at(1), 'Learn at home with videos');
      await t.pump();
      await t.scrollUntilVisible(find.widgetWithText(AllyButton, 'Help me decide'), 200, scrollable: find.byType(Scrollable).first);
      await _tap(t, find.widgetWithText(AllyButton, 'Help me decide'));
      await t.drag(find.byType(ListView), const Offset(0, -1500));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
    });
  });
}
