import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/design/rings.dart';
import 'package:lifeos_mobile/features/session/focus_session_screen.dart';

// A step with a brief. [old] is a server from before briefs existed.
class _Repo implements LifeRepository {
  final List<String> calls = [];
  bool old = false;
  String? clearer = 'Write three sentences for the intro';

  @override
  Future<Map<String, dynamic>> stepBrief(String id) async {
    calls.add('brief:$id');
    if (old) throw const ApiException('Not found', statusCode: 404);
    return {
      'title': 'Draft the intro',
      'minutes': 25,
      'smaller': null,
      'begin': 'Open the document and write one rough sentence.',
      'done': 'Three paragraphs that say what the piece is about.',
      'byCode': false,
      'from': {'goal': 'Finish the first draft', 'why': 'I want to send it to an editor', 'area': 'Writing'},
    };
  }

  @override
  Future<String?> clearerStep(String id) async => clearer;

  @override
  Future<({String message, String? activityId})> editStep(String id,
      {String? title, int? minutes, bool clearMinutes = false, String? energy, String? smaller, Map<String, dynamic>? when}) async {
    calls.add('edit:$id:$title');
    return (message: 'Saved.', activityId: 'act-edit');
  }

  @override
  Future<({String message, String? activityId})> letGoStep(String id) async {
    calls.add('letgo:$id');
    return (message: 'Let go.', activityId: 'act-letgo');
  }

  @override
  Future<void> undo(String activityId) async => calls.add('undo:$activityId');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

FocusOutcome? _result;
bool _closed = false;

Future<_Repo> _open(WidgetTester t, {_Repo? repo, Size size = const Size(360, 760), double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  _result = null;
  _closed = false;
  final r = repo ?? _Repo();
  final key = GlobalKey<NavigatorState>();
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(MaterialApp(navigatorKey: key, home: const Scaffold(body: SizedBox())));
  key.currentState!
      .push<FocusOutcome>(MaterialPageRoute(
          builder: (_) => FocusSessionScreen(title: 'Draft the intro', minutes: 25, areaName: 'Writing', stepId: 's1', repo: r)))
      .then((o) {
    _result = o;
    _closed = true;
  });
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  return r;
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

  testWidgets('a step says what it is part of, how to begin and what done looks like', (t) async {
    await _open(t);
    expect(find.text('Draft the intro'), findsOneWidget);
    expect(find.text('Part of: Finish the first draft'), findsOneWidget);
    expect(find.text('Why: I want to send it to an editor'), findsOneWidget);
    expect(find.text('HOW TO BEGIN'), findsOneWidget);
    expect(find.text('Open the document and write one rough sentence.'), findsOneWidget);
    expect(find.text('DONE LOOKS LIKE'), findsOneWidget);
    expect(find.text('Three paragraphs that say what the piece is about.'), findsOneWidget);
    // The timer is there only when asked for.
    expect(find.byType(ProgressRing), findsNothing);
    await _tap(t, find.text('Show timer'));
    expect(find.byType(ProgressRing), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    await _tap(t, find.text('Hide timer'));
    await _tap(t, find.text('Done'));
    expect(_result?.end, FocusEnd.done);
    expect(_result?.smaller, isFalse);
    expect(_result!.minutes, greaterThanOrEqualTo(1));
  });

  testWidgets('Smaller turns it into the first move; done then counts without finishing the step', (t) async {
    await _open(t);
    await _tap(t, find.text('Smaller'));
    expect(find.text('Open the document and write one rough sentence.'), findsOneWidget);
    expect(find.text('The small version of: Draft the intro'), findsOneWidget);
    expect(find.text('Just that. Two minutes on it counts.'), findsOneWidget);
    expect(find.text('Smaller'), findsNothing);
    await _tap(t, find.text('Done'));
    expect(_result?.end, FocusEnd.done);
    expect(_result?.smaller, isTrue);
  });

  testWidgets('Later closes and says so; closing logs nothing', (t) async {
    await _open(t);
    await _tap(t, find.text('Later'));
    expect(_result?.end, FocusEnd.later);

    await _open(t);
    await _tap(t, find.byTooltip('Stop without logging'));
    expect(_result?.end, FocusEnd.stopped);
  });

  testWidgets('not clear: Ally offers a wording, it can be changed, saved with Undo', (t) async {
    final repo = await _open(t);
    await _tap(t, find.text('Not clear what to do?'));
    expect(find.text('Make it clear'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Write three sentences for the intro'), findsOneWidget);
    await _tap(t, find.text('Use this'));
    expect(repo.calls, contains('edit:s1:Write three sentences for the intro'));
    expect(find.text('Write three sentences for the intro'), findsOneWidget);
    expect(find.text('Step reworded.'), findsOneWidget);
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'undo:act-edit');
    expect(find.text('Draft the intro'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('not clear: without a suggestion they write it their own way, or let it go', (t) async {
    final repo = _Repo()..clearer = null;
    await _open(t, repo: repo);
    await _tap(t, find.text('Not clear what to do?'));
    expect(find.text('Say it the way you would actually do it.'), findsOneWidget);
    await _tap(t, find.text('Let this step go'));
    expect(repo.calls.last, 'letgo:s1');
    expect(_result?.end, FocusEnd.letGo);
    expect(_result?.undoId, 'act-letgo');
  });

  testWidgets('on a server without briefs, or offline, it is the timer screen', (t) async {
    await _open(t, repo: _Repo()..old = true);
    expect(find.text('HOW TO BEGIN'), findsNothing);
    expect(find.byType(ProgressRing), findsOneWidget);
    expect(find.text("I'm stuck"), findsOneWidget);
    await _tap(t, find.text('Done'));
    expect(_closed, isTrue);
    expect(_result?.end, FocusEnd.done);
  });

  testWidgets('fits a small phone at large text', (t) async {
    await _open(t, size: const Size(320, 640), textScale: 1.5);
    expect(t.takeException(), isNull);
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -900));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Not clear what to do?'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
